import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { connections, posts, users } from "../../db/schema/index.js";
import { and, eq, or } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import { isAuthorVisibleToViewer } from "../access.js";
import { PostType } from "./post.js";

/**
 * Drop connection rows where either endpoint's author is hidden from the
 * viewer (child / non-public). Hides the existence and IDs (sourceId /
 * targetId) of those endpoints in list resolvers (#250 review C2).
 *
 * Two aliases on `posts` and `users` allow joining both endpoints in one
 * query — the field resolvers (`source` / `target`) still re-check visibility
 * as defense-in-depth in case a row reaches them from another path.
 */
async function selectVisibleConnections(args: {
  whereClause: ReturnType<typeof or>;
  viewerUserId: string | null;
  limit: number;
}) {
  const srcPosts = alias(posts, "src_posts");
  const srcUsers = alias(users, "src_users");
  const tgtPosts = alias(posts, "tgt_posts");
  const tgtUsers = alias(users, "tgt_users");
  const rows = await db
    .select({
      conn: connections,
      srcAuthorMeta: {
        userId: srcUsers.id,
        guardianId: srcUsers.guardianId,
        profileVisibility: srcUsers.profileVisibility,
      },
      tgtAuthorMeta: {
        userId: tgtUsers.id,
        guardianId: tgtUsers.guardianId,
        profileVisibility: tgtUsers.profileVisibility,
      },
    })
    .from(connections)
    .innerJoin(srcPosts, eq(connections.sourceId, srcPosts.id))
    .innerJoin(srcUsers, eq(srcPosts.authorId, srcUsers.id))
    .innerJoin(tgtPosts, eq(connections.targetId, tgtPosts.id))
    .innerJoin(tgtUsers, eq(tgtPosts.authorId, tgtUsers.id))
    .where(args.whereClause)
    .limit(args.limit);
  return rows
    .filter(
      (r) =>
        isAuthorVisibleToViewer(r.srcAuthorMeta, args.viewerUserId) &&
        isAuthorVisibleToViewer(r.tgtAuthorMeta, args.viewerUserId),
    )
    .map((r) => r.conn);
}

const ConnectionTypeEnum = builder.enumType("ConnectionType", {
  values: ["reply", "remix", "reference", "evolution"] as const,
});

const ConnectionObjectType = builder.objectRef<{
  id: string;
  sourceId: string;
  targetId: string;
  connectionType: "reply" | "remix" | "reference" | "evolution";
  groupId: string | null;
  createdAt: Date;
}>("Connection");

ConnectionObjectType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    sourceId: t.exposeID("sourceId"),
    targetId: t.exposeID("targetId"),
    connectionType: t.field({
      type: ConnectionTypeEnum,
      resolve: (conn) => conn.connectionType,
    }),
    groupId: t.exposeString("groupId", { nullable: true }),
    createdAt: t.string({
      resolve: (conn) => conn.createdAt.toISOString(),
    }),
    source: t.field({
      type: PostType,
      nullable: true,
      resolve: async (conn, _args, ctx) => {
        // Hide posts whose author is a child / non-public user (#250 sec-2).
        // INNER JOIN users so we can apply isAuthorVisibleToViewer in the
        // same query and avoid leaking the source post's existence.
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
          .where(eq(posts.id, conn.sourceId))
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
    target: t.field({
      type: PostType,
      nullable: true,
      resolve: async (conn, _args, ctx) => {
        // Hide posts whose author is a child / non-public user (#250 sec-2).
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
          .where(eq(posts.id, conn.targetId))
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
  createConnection: t.field({
    type: ConnectionObjectType,
    args: {
      sourceId: t.arg.string({ required: true }),
      targetId: t.arg.string({ required: true }),
      connectionType: t.arg({ type: ConnectionTypeEnum, required: true }),
      groupId: t.arg.string(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Self-reference check
      if (args.sourceId === args.targetId) {
        throw new GraphQLError("Source and target posts must be different");
      }

      // Verify source post exists and user owns it
      const [sourcePost] = await db
        .select({ id: posts.id })
        .from(posts)
        .where(
          and(
            eq(posts.id, args.sourceId),
            eq(posts.authorId, ctx.authUser.userId),
          ),
        )
        .limit(1);
      if (!sourcePost) {
        throw new GraphQLError("Source post not found");
      }

      // Verify target post exists and is accessible (not draft, not authored
      // by a child / non-public user — same enumeration-oracle guard as
      // toggleReaction; see #250 sec-2).
      const [targetPost] = await db
        .select({
          id: posts.id,
          visibility: posts.visibility,
          authorId: posts.authorId,
          authorMeta: {
            userId: users.id,
            guardianId: users.guardianId,
            profileVisibility: users.profileVisibility,
          },
        })
        .from(posts)
        .innerJoin(users, eq(posts.authorId, users.id))
        .where(eq(posts.id, args.targetId))
        .limit(1);
      if (!targetPost) {
        throw new GraphQLError("Target post not found");
      }
      if (
        targetPost.visibility === "draft" &&
        targetPost.authorId !== ctx.authUser.userId
      ) {
        throw new GraphQLError("Target post not found");
      }
      if (
        !isAuthorVisibleToViewer(
          targetPost.authorMeta,
          ctx.authUser?.userId ?? null,
        )
      ) {
        throw new GraphQLError("Target post not found");
      }

      try {
        const [connection] = await db
          .insert(connections)
          .values({
            sourceId: args.sourceId,
            targetId: args.targetId,
            connectionType: args.connectionType,
            groupId: args.groupId ?? null,
          })
          .returning();
        return connection;
      } catch {
        throw new GraphQLError("Failed to create connection");
      }
    },
  }),

  deleteConnection: t.field({
    type: ConnectionObjectType,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Fetch connection
      const [connection] = await db
        .select()
        .from(connections)
        .where(eq(connections.id, args.id))
        .limit(1);
      if (!connection) {
        throw new GraphQLError("Connection not found");
      }

      // Verify user owns the source post
      const [sourcePost] = await db
        .select({ id: posts.id })
        .from(posts)
        .where(
          and(
            eq(posts.id, connection.sourceId),
            eq(posts.authorId, ctx.authUser.userId),
          ),
        )
        .limit(1);
      if (!sourcePost) {
        throw new GraphQLError("Connection not found");
      }

      const [deleted] = await db
        .delete(connections)
        .where(eq(connections.id, args.id))
        .returning();

      return deleted;
    },
  }),
}));

builder.queryFields((t) => ({
  connections: t.field({
    type: [ConnectionObjectType],
    args: {
      postId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      // Drop rows where either endpoint's author is hidden — without this,
      // sourceId / targetId leak in plaintext for connections involving a
      // child / private author's post (#250 review C2).
      return selectVisibleConnections({
        whereClause: or(
          eq(connections.sourceId, args.postId),
          eq(connections.targetId, args.postId),
        ),
        viewerUserId: ctx.authUser?.userId ?? null,
        limit: 100,
      });
    },
  }),
}));

// Add connection fields to PostType
builder.objectFields(PostType, (t) => ({
  outgoingConnections: t.field({
    type: [ConnectionObjectType],
    resolve: async (post, _args, ctx) => {
      return selectVisibleConnections({
        whereClause: eq(connections.sourceId, post.id),
        viewerUserId: ctx.authUser?.userId ?? null,
        limit: 50,
      });
    },
  }),
  incomingConnections: t.field({
    type: [ConnectionObjectType],
    resolve: async (post, _args, ctx) => {
      return selectVisibleConnections({
        whereClause: eq(connections.targetId, post.id),
        viewerUserId: ctx.authUser?.userId ?? null,
        limit: 50,
      });
    },
  }),
}));
