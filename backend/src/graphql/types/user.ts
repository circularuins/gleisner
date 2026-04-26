import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { users } from "../../db/schema/index.js";
import { eq } from "drizzle-orm";
import {
  validateProfileVisibility,
  validateMediaUrl,
  assertUploadedR2ObjectMatches,
} from "../validators.js";

export interface UserShape {
  id: string;
  did: string;
  email: string;
  username: string;
  displayName: string | null;
  bio: string | null;
  avatarUrl: string | null;
  profileVisibility: string;
  publicKey: string;
  birthYearMonth: string | null;
  guardianId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface PublicUserShape {
  id: string;
  did: string;
  username: string;
  displayName: string | null;
  bio: string | null;
  avatarUrl: string | null;
  createdAt: Date;
}

/** Column selection for UserType resolvers — avoids fetching passwordHash/encryptedPrivateKey */
export const userColumns = {
  id: users.id,
  did: users.did,
  email: users.email,
  username: users.username,
  displayName: users.displayName,
  bio: users.bio,
  avatarUrl: users.avatarUrl,
  profileVisibility: users.profileVisibility,
  publicKey: users.publicKey,
  birthYearMonth: users.birthYearMonth,
  guardianId: users.guardianId,
  createdAt: users.createdAt,
  updatedAt: users.updatedAt,
} as const;

/** Column selection for PublicUserType resolvers — avoids fetching email/publicKey */
export const publicUserColumns = {
  id: users.id,
  did: users.did,
  username: users.username,
  displayName: users.displayName,
  bio: users.bio,
  avatarUrl: users.avatarUrl,
  createdAt: users.createdAt,
} as const;

export const UserType = builder.objectRef<UserShape>("User");

UserType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    did: t.exposeString("did"),
    // Child accounts use internal placeholder emails — hide them
    email: t.string({
      nullable: true,
      resolve: (user) => (user.guardianId ? null : user.email),
    }),
    username: t.exposeString("username"),
    displayName: t.exposeString("displayName", { nullable: true }),
    bio: t.exposeString("bio", { nullable: true }),
    avatarUrl: t.exposeString("avatarUrl", { nullable: true }),
    profileVisibility: t.exposeString("profileVisibility"),
    publicKey: t.exposeString("publicKey"),
    birthYearMonth: t.exposeString("birthYearMonth", { nullable: true }),
    // Expose boolean instead of raw guardian UUID (ADR 019 data minimization)
    isChildAccount: t.boolean({
      resolve: (user) => user.guardianId !== null,
    }),
    createdAt: t.string({ resolve: (user) => user.createdAt.toISOString() }),
    updatedAt: t.string({ resolve: (user) => user.updatedAt.toISOString() }),
  }),
});

export const PublicUserType = builder.objectRef<PublicUserShape>("PublicUser");

PublicUserType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    did: t.exposeString("did"),
    username: t.exposeString("username"),
    displayName: t.exposeString("displayName", { nullable: true }),
    bio: t.exposeString("bio", { nullable: true }),
    avatarUrl: t.exposeString("avatarUrl", { nullable: true }),
    createdAt: t.string({ resolve: (user) => user.createdAt.toISOString() }),
  }),
});

builder.mutationFields((t) => ({
  updateMe: t.field({
    type: UserType,
    args: {
      displayName: t.arg.string(),
      bio: t.arg.string(),
      avatarUrl: t.arg.string(),
      profileVisibility: t.arg.string(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      if (args.displayName != null && args.displayName.length > 50) {
        throw new GraphQLError("Display name must be 50 characters or less");
      }
      if (args.bio != null && args.bio.length > 1000) {
        throw new GraphQLError("Bio must be 1000 characters or less");
      }
      if (args.avatarUrl != null) {
        validateMediaUrl(args.avatarUrl);
        // Issue #269 / ADR 026: magic-byte check for avatar uploads. Skip
        // when the URL is unchanged so re-saving the profile without
        // touching the avatar doesn't re-fetch from R2.
        const [existing] = await db
          .select({ avatarUrl: users.avatarUrl })
          .from(users)
          .where(eq(users.id, ctx.authUser.userId))
          .limit(1);
        if (args.avatarUrl !== existing?.avatarUrl) {
          await assertUploadedR2ObjectMatches(args.avatarUrl);
        }
      }

      // undefined = not provided (skip), null = clear field, value = update
      // Validation above uses != null so null (clear) skips validation intentionally
      const updateData: Record<string, unknown> = { updatedAt: new Date() };
      if (args.displayName !== undefined)
        updateData.displayName = args.displayName;
      if (args.bio !== undefined) updateData.bio = args.bio;
      if (args.avatarUrl !== undefined) updateData.avatarUrl = args.avatarUrl;
      if (args.profileVisibility !== undefined) {
        // Child accounts cannot change profile visibility (Phase 0 Tier 1: private fixed)
        if (ctx.authUser.guardianId) {
          throw new GraphQLError(
            "Child accounts cannot change profile visibility",
          );
        }
        validateProfileVisibility(args.profileVisibility as string);
        updateData.profileVisibility = args.profileVisibility;
      }

      const [updated] = await db
        .update(users)
        .set(updateData)
        .where(eq(users.id, ctx.authUser.userId))
        .returning(userColumns);

      return updated;
    },
  }),
}));
