import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { follows, users } from "../../db/schema/index.js";
import { and, eq } from "drizzle-orm";
import { PublicUserType, UserType } from "./user.js";

const FollowType = builder.objectRef<{
  followerId: string;
  followingId: string;
  createdAt: Date;
}>("Follow");

FollowType.implement({
  fields: (t) => ({
    createdAt: t.string({
      resolve: (follow) => follow.createdAt.toISOString(),
    }),
    follower: t.field({
      type: PublicUserType,
      resolve: async (follow) => {
        const [user] = await db
          .select()
          .from(users)
          .where(eq(users.id, follow.followerId))
          .limit(1);
        return user;
      },
    }),
    following: t.field({
      type: PublicUserType,
      resolve: async (follow) => {
        const [user] = await db
          .select()
          .from(users)
          .where(eq(users.id, follow.followingId))
          .limit(1);
        return user;
      },
    }),
  }),
});

builder.mutationFields((t) => ({
  toggleFollow: t.field({
    type: FollowType,
    nullable: true,
    args: {
      userId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      if (args.userId === ctx.authUser.userId) {
        throw new GraphQLError("Cannot follow yourself");
      }

      // Check if already following
      const [existing] = await db
        .select()
        .from(follows)
        .where(
          and(
            eq(follows.followerId, ctx.authUser.userId),
            eq(follows.followingId, args.userId),
          ),
        )
        .limit(1);

      if (existing) {
        // Unfollow
        await db
          .delete(follows)
          .where(
            and(
              eq(follows.followerId, ctx.authUser.userId),
              eq(follows.followingId, args.userId),
            ),
          );
        return null;
      }

      // Follow
      try {
        const [follow] = await db
          .insert(follows)
          .values({
            followerId: ctx.authUser.userId,
            followingId: args.userId,
          })
          .returning();
        return follow;
      } catch {
        throw new GraphQLError("Failed to follow user");
      }
    },
  }),
}));

builder.queryFields((t) => ({
  followers: t.field({
    type: [FollowType],
    args: {
      userId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      return db
        .select()
        .from(follows)
        .where(eq(follows.followingId, args.userId));
    },
  }),

  following: t.field({
    type: [FollowType],
    args: {
      userId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      return db
        .select()
        .from(follows)
        .where(eq(follows.followerId, args.userId));
    },
  }),
}));

// Add followers/following fields to UserType (for me query)
builder.objectFields(UserType, (t) => ({
  followers: t.field({
    type: [FollowType],
    resolve: async (user) => {
      return db.select().from(follows).where(eq(follows.followingId, user.id));
    },
  }),
  following: t.field({
    type: [FollowType],
    resolve: async (user) => {
      return db.select().from(follows).where(eq(follows.followerId, user.id));
    },
  }),
}));
