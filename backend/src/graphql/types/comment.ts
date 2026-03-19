import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { comments, posts, users } from "../../db/schema/index.js";
import { and, eq } from "drizzle-orm";
import { PostType } from "./post.js";
import { PublicUserType } from "./user.js";

const CommentType = builder.objectRef<{
  id: string;
  postId: string;
  userId: string;
  body: string;
  createdAt: Date;
  updatedAt: Date;
}>("Comment");

CommentType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    body: t.exposeString("body"),
    createdAt: t.string({
      resolve: (comment) => comment.createdAt.toISOString(),
    }),
    updatedAt: t.string({
      resolve: (comment) => comment.updatedAt.toISOString(),
    }),
    user: t.field({
      type: PublicUserType,
      resolve: async (comment) => {
        const [user] = await db
          .select()
          .from(users)
          .where(eq(users.id, comment.userId))
          .limit(1);
        return user;
      },
    }),
    post: t.field({
      type: PostType,
      resolve: async (comment) => {
        const [post] = await db
          .select()
          .from(posts)
          .where(eq(posts.id, comment.postId))
          .limit(1);
        return post;
      },
    }),
  }),
});

function validateBody(body: string): string {
  const trimmed = body.trim();
  if (trimmed.length === 0) {
    throw new GraphQLError("Comment body is required");
  }
  if (trimmed.length > 500) {
    throw new GraphQLError("Comment body must be 500 characters or less");
  }
  return trimmed;
}

builder.mutationFields((t) => ({
  createComment: t.field({
    type: CommentType,
    args: {
      postId: t.arg.string({ required: true }),
      body: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const body = validateBody(args.body);

      // Verify post exists
      const [post] = await db
        .select({ id: posts.id })
        .from(posts)
        .where(eq(posts.id, args.postId))
        .limit(1);
      if (!post) {
        throw new GraphQLError("Post not found");
      }

      try {
        const [comment] = await db
          .insert(comments)
          .values({
            postId: args.postId,
            userId: ctx.authUser.userId,
            body,
          })
          .returning();
        return comment;
      } catch {
        throw new GraphQLError("Failed to create comment");
      }
    },
  }),

  updateComment: t.field({
    type: CommentType,
    args: {
      id: t.arg.string({ required: true }),
      body: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const body = validateBody(args.body);

      // Single query with both id and userId to avoid existence oracle
      const [comment] = await db
        .select()
        .from(comments)
        .where(
          and(
            eq(comments.id, args.id),
            eq(comments.userId, ctx.authUser.userId),
          ),
        )
        .limit(1);
      if (!comment) {
        throw new GraphQLError("Comment not found");
      }

      const [updated] = await db
        .update(comments)
        .set({ body, updatedAt: new Date() })
        .where(eq(comments.id, args.id))
        .returning();

      return updated;
    },
  }),

  deleteComment: t.field({
    type: CommentType,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Single query with both id and userId to avoid existence oracle
      const [comment] = await db
        .select()
        .from(comments)
        .where(
          and(
            eq(comments.id, args.id),
            eq(comments.userId, ctx.authUser.userId),
          ),
        )
        .limit(1);
      if (!comment) {
        throw new GraphQLError("Comment not found");
      }

      const [deleted] = await db
        .delete(comments)
        .where(eq(comments.id, args.id))
        .returning();

      return deleted;
    },
  }),
}));

builder.queryFields((t) => ({
  comments: t.field({
    type: [CommentType],
    args: {
      postId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      return db.select().from(comments).where(eq(comments.postId, args.postId));
    },
  }),
}));

// Add comments field to PostType
builder.objectFields(PostType, (t) => ({
  comments: t.field({
    type: [CommentType],
    resolve: async (post) => {
      return db.select().from(comments).where(eq(comments.postId, post.id));
    },
  }),
}));
