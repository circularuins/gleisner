import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { posts, reactions, users } from "../../db/schema/index.js";
import { and, eq, sql, desc } from "drizzle-orm";
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
      resolve: async (reaction) => {
        const [post] = await db
          .select()
          .from(posts)
          .where(eq(posts.id, reaction.postId))
          .limit(1);
        return post;
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

      // Validate emoji
      const emoji = args.emoji.trim();
      if (emoji.length === 0) {
        throw new GraphQLError("Emoji is required");
      }
      if (emoji.length > 10) {
        throw new GraphQLError("Emoji must be 10 characters or less");
      }

      // Verify post exists
      const [post] = await db
        .select({ id: posts.id })
        .from(posts)
        .where(eq(posts.id, args.postId))
        .limit(1);
      if (!post) {
        throw new GraphQLError("Post not found");
      }

      // Check if reaction already exists
      const [existing] = await db
        .select()
        .from(reactions)
        .where(
          and(
            eq(reactions.postId, args.postId),
            eq(reactions.userId, ctx.authUser.userId),
            eq(reactions.emoji, emoji),
          ),
        )
        .limit(1);

      if (existing) {
        // Toggle off: delete and return null
        await db.delete(reactions).where(eq(reactions.id, existing.id));
        return null;
      }

      // Toggle on: create
      try {
        const [reaction] = await db
          .insert(reactions)
          .values({
            postId: args.postId,
            userId: ctx.authUser.userId,
            emoji,
          })
          .returning();
        return reaction;
      } catch {
        throw new GraphQLError("Failed to create reaction");
      }
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
  // Aggregated counts only (no user info) — intentionally public
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
