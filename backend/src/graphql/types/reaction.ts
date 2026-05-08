import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { posts, reactions, users } from "../../db/schema/index.js";
import { and, eq, sql, desc } from "drizzle-orm";
import { isAuthorVisibleToViewer } from "../access.js";
import { validateEmoji, validateUUID } from "../validators.js";
import { PostType } from "./post.js";
import { PublicUserType, publicUserColumns } from "./user.js";

const ReactionType = builder.objectRef<{
  id: string;
  postId: string;
  userId: string;
  emoji: string;
  createdAt: Date;
}>("Reaction");

ReactionType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    emoji: t.exposeString("emoji"),
    createdAt: t.string({
      resolve: (reaction) => reaction.createdAt.toISOString(),
    }),
    user: t.field({
      type: PublicUserType,
      resolve: async (reaction) => {
        const [user] = await db
          .select(publicUserColumns)
          .from(users)
          .where(eq(users.id, reaction.userId))
          .limit(1);
        if (!user) throw new GraphQLError("User not found");
        return user;
      },
    }),
    post: t.field({
      type: PostType,
      nullable: true,
      resolve: async (reaction, _args, ctx) => {
        // Join users so we can apply isAuthorVisibleToViewer in the same
        // SELECT and avoid leaking child / non-public author posts via
        // ReactionType.post (#250 sec-4).
        const [row] = await db
          .select({
            post: posts,
            authorMeta: {
              userId: users.id,
              guardianId: users.guardianId,
              profileVisibility: users.profileVisibility,
            },
          })
          .from(posts)
          .innerJoin(users, eq(posts.authorId, users.id))
          .where(eq(posts.id, reaction.postId))
          .limit(1);
        if (!row) return null;
        if (
          !isAuthorVisibleToViewer(row.authorMeta, ctx.authUser?.userId ?? null)
        ) {
          return null;
        }
        return row.post;
      },
    }),
  }),
});

builder.mutationFields((t) => ({
  toggleReaction: t.field({
    type: ReactionType,
    nullable: true,
    args: {
      postId: t.arg.string({ required: true }),
      emoji: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }
      validateUUID(args.postId, "post id");
      const emoji = validateEmoji(args.emoji);

      // Verify post exists AND its author is visible to the viewer.
      // Child / non-public authors must not be reachable as reaction targets;
      // returning the same "Post not found" message keeps existence and
      // visibility indistinguishable (no enumeration oracle, #250 sec-4).
      const [postRow] = await db
        .select({
          id: posts.id,
          authorMeta: {
            userId: users.id,
            guardianId: users.guardianId,
            profileVisibility: users.profileVisibility,
          },
        })
        .from(posts)
        .innerJoin(users, eq(posts.authorId, users.id))
        .where(eq(posts.id, args.postId))
        .limit(1);
      if (
        !postRow ||
        !isAuthorVisibleToViewer(
          postRow.authorMeta,
          ctx.authUser?.userId ?? null,
        )
      ) {
        throw new GraphQLError("Post not found");
      }

      // Idempotent toggle: try to INSERT first; on unique-constraint
      // collision the (postId, userId, emoji) row already exists and we
      // DELETE instead. This collapses the previous SELECT → DELETE/INSERT
      // sequence into a single race-safe path: parallel double-clicks no
      // longer race past `existing` and surface as 500 ("Failed to create
      // reaction") on the unique-constraint violation.
      const [inserted] = await db
        .insert(reactions)
        .values({
          postId: args.postId,
          userId: ctx.authUser.userId,
          emoji,
        })
        .onConflictDoNothing({
          target: [reactions.postId, reactions.userId, reactions.emoji],
        })
        .returning();

      if (inserted) {
        // Toggle on: row was newly created.
        return inserted;
      }

      // Row already existed → toggle off. DELETE returns 0 rows iff a
      // concurrent caller has already toggled off in the gap, which is the
      // exact same observable end state we want — so we always return null
      // here without distinguishing the two paths.
      await db
        .delete(reactions)
        .where(
          and(
            eq(reactions.postId, args.postId),
            eq(reactions.userId, ctx.authUser.userId),
            eq(reactions.emoji, emoji),
          ),
        );
      return null;
    },
  }),

  deleteReaction: t.field({
    type: ReactionType,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }
      validateUUID(args.id, "reaction id");

      // Single query with both id and userId to avoid existence oracle
      const [reaction] = await db
        .select()
        .from(reactions)
        .where(
          and(
            eq(reactions.id, args.id),
            eq(reactions.userId, ctx.authUser.userId),
          ),
        )
        .limit(1);
      if (!reaction) {
        throw new GraphQLError("Reaction not found");
      }

      const [deleted] = await db
        .delete(reactions)
        .where(eq(reactions.id, args.id))
        .returning();

      return deleted;
    },
  }),
}));

builder.queryFields((t) => ({
  // Individual reactions (includes user info) — requires authentication
  reactions: t.field({
    type: [ReactionType],
    args: {
      postId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }
      validateUUID(args.postId, "post id");
      // Refuse to surface reactions for posts whose author is a child /
      // non-public user. Without this guard, a viewer who knows a child
      // author's post id can enumerate its reactions even though
      // toggleReaction / ReactionType.post block direct access (#250 sec-3).
      const [postRow] = await db
        .select({
          id: posts.id,
          authorMeta: {
            userId: users.id,
            guardianId: users.guardianId,
            profileVisibility: users.profileVisibility,
          },
        })
        .from(posts)
        .innerJoin(users, eq(posts.authorId, users.id))
        .where(eq(posts.id, args.postId))
        .limit(1);
      if (
        !postRow ||
        !isAuthorVisibleToViewer(
          postRow.authorMeta,
          ctx.authUser?.userId ?? null,
        )
      ) {
        return [];
      }
      return db
        .select()
        .from(reactions)
        .where(eq(reactions.postId, args.postId));
    },
  }),
}));

// Reaction count summary type
const ReactionCountType = builder.objectRef<{
  emoji: string;
  count: number;
}>("ReactionCount");

ReactionCountType.implement({
  fields: (t) => ({
    emoji: t.exposeString("emoji"),
    count: t.exposeInt("count"),
  }),
});

// Add reactions and reactionCounts fields to PostType
builder.objectFields(PostType, (t) => ({
  // Individual reactions (includes user info) — requires authentication
  reactions: t.field({
    type: [ReactionType],
    resolve: async (post, _args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }
      // Defense-in-depth (#250 review C1): even if a future resolver path
      // reaches PostType without going through post(id) / list filtering,
      // never reveal reactions when the parent post's author is hidden
      // (child / non-public). The viewer's own posts are still visible
      // because isAuthorVisibleToViewer returns true for self.
      const [authorMeta] = await db
        .select({
          userId: users.id,
          guardianId: users.guardianId,
          profileVisibility: users.profileVisibility,
        })
        .from(users)
        .where(eq(users.id, post.authorId))
        .limit(1);
      if (
        !authorMeta ||
        !isAuthorVisibleToViewer(authorMeta, ctx.authUser.userId)
      ) {
        return [];
      }
      return db.select().from(reactions).where(eq(reactions.postId, post.id));
    },
  }),
  myReactions: t.field({
    type: ["String"],
    resolve: async (post, _args, ctx) => {
      if (!ctx.authUser) return [];
      const rows = await db
        .select({ emoji: reactions.emoji })
        .from(reactions)
        .where(
          and(
            eq(reactions.postId, post.id),
            eq(reactions.userId, ctx.authUser.userId),
          ),
        );
      return rows.map((r) => r.emoji);
    },
  }),
  // Aggregated counts only (no user info) — intentionally public.
  //
  // Phase 0 trade-off: this resolver does NOT apply
  // `isAuthorVisibleToViewer`. With everyone in the family-launch tier
  // running `profileVisibility: "public"`, the only emoji content
  // surfaced here is from authors that are already visible elsewhere.
  // Phase 1 SNS expansion needs to plug this — once child / private
  // authors become routinely reachable through public bots and feed
  // links, leaking their reaction emoji set turns into a
  // micro-enumeration oracle. Tracked as a separate Issue (linked from
  // this PR's description); the surrounding `Post.reactions` and
  // `reactions(postId)` already enforce the same guard so the upgrade
  // is mechanical.
  reactionCounts: t.field({
    type: [ReactionCountType],
    resolve: async (post) => {
      const rows = await db
        .select({
          emoji: reactions.emoji,
          count: sql<number>`count(*)::int`,
        })
        .from(reactions)
        .where(eq(reactions.postId, post.id))
        .groupBy(reactions.emoji)
        .orderBy(desc(sql`count(*)`))
        .limit(5);
      return rows;
    },
  }),
}));
