import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { connections, posts } from "../../db/schema/index.js";
import { and, eq, or } from "drizzle-orm";
import { PostType } from "./post.js";

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
      resolve: async (conn) => {
        const [post] = await db
          .select()
          .from(posts)
          .where(eq(posts.id, conn.sourceId))
          .limit(1);
        return post;
      },
    }),
    target: t.field({
      type: PostType,
      resolve: async (conn) => {
        const [post] = await db
          .select()
          .from(posts)
          .where(eq(posts.id, conn.targetId))
          .limit(1);
        return post;
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

      // Verify target post exists and is accessible (not draft, unless own)
      const [targetPost] = await db
        .select({ id: posts.id, visibility: posts.visibility, authorId: posts.authorId })
        .from(posts)
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
    resolve: async (_parent, args) => {
      return db
        .select()
        .from(connections)
        .where(
          or(
            eq(connections.sourceId, args.postId),
            eq(connections.targetId, args.postId),
          ),
        )
        .limit(100);
    },
  }),
}));

// Add connection fields to PostType
builder.objectFields(PostType, (t) => ({
  outgoingConnections: t.field({
    type: [ConnectionObjectType],
    resolve: async (post) => {
      return db
        .select()
        .from(connections)
        .where(eq(connections.sourceId, post.id))
        .limit(50);
    },
  }),
  incomingConnections: t.field({
    type: [ConnectionObjectType],
    resolve: async (post) => {
      return db
        .select()
        .from(connections)
        .where(eq(connections.targetId, post.id))
        .limit(50);
    },
  }),
}));
