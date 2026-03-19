import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists } from "../../db/schema/index.js";
import { eq } from "drizzle-orm";

export const ArtistType = builder.objectRef<{
  id: string;
  userId: string;
  artistUsername: string;
  displayName: string | null;
  bio: string | null;
  tagline: string | null;
  location: string | null;
  activeSince: number | null;
  avatarUrl: string | null;
  coverImageUrl: string | null;
  tunedInCount: number;
  createdAt: Date;
  updatedAt: Date;
}>("Artist");

ArtistType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    artistUsername: t.exposeString("artistUsername"),
    displayName: t.exposeString("displayName", { nullable: true }),
    bio: t.exposeString("bio", { nullable: true }),
    tagline: t.exposeString("tagline", { nullable: true }),
    location: t.exposeString("location", { nullable: true }),
    activeSince: t.exposeInt("activeSince", { nullable: true }),
    avatarUrl: t.exposeString("avatarUrl", { nullable: true }),
    coverImageUrl: t.exposeString("coverImageUrl", { nullable: true }),
    tunedInCount: t.exposeInt("tunedInCount"),
    createdAt: t.string({
      resolve: (artist) => artist.createdAt.toISOString(),
    }),
    updatedAt: t.string({
      resolve: (artist) => artist.updatedAt.toISOString(),
    }),
  }),
});

builder.mutationFields((t) => ({
  registerArtist: t.field({
    type: ArtistType,
    args: {
      artistUsername: t.arg.string({ required: true }),
      displayName: t.arg.string({ required: true }),
      tagline: t.arg.string(),
      location: t.arg.string(),
      activeSince: t.arg.int(),
      avatarUrl: t.arg.string(),
      coverImageUrl: t.arg.string(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Validate artistUsername
      if (args.artistUsername.length < 2 || args.artistUsername.length > 30) {
        throw new GraphQLError(
          "Artist username must be between 2 and 30 characters",
        );
      }
      if (!/^[a-zA-Z0-9_]+$/.test(args.artistUsername)) {
        throw new GraphQLError(
          "Artist username can only contain letters, numbers, and underscores",
        );
      }

      // Validate displayName
      if (args.displayName.length < 1 || args.displayName.length > 50) {
        throw new GraphQLError(
          "Display name must be between 1 and 50 characters",
        );
      }

      // Validate optional fields
      if (args.tagline && args.tagline.length > 80) {
        throw new GraphQLError("Tagline must be 80 characters or less");
      }
      if (args.location && args.location.length > 100) {
        throw new GraphQLError("Location must be 100 characters or less");
      }
      if (args.activeSince != null) {
        const currentYear = new Date().getFullYear();
        if (args.activeSince < 1900 || args.activeSince > currentYear) {
          throw new GraphQLError(
            `Active since must be between 1900 and ${currentYear}`,
          );
        }
      }

      // Check if user is already an artist
      const existingArtist = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      if (existingArtist.length > 0) {
        throw new GraphQLError("User is already registered as an artist");
      }

      // Check username uniqueness
      const existingUsername = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.artistUsername, args.artistUsername))
        .limit(1);
      if (existingUsername.length > 0) {
        throw new GraphQLError("Artist username already taken");
      }

      const [artist] = await db
        .insert(artists)
        .values({
          userId: ctx.authUser.userId,
          artistUsername: args.artistUsername,
          displayName: args.displayName,
          tagline: args.tagline ?? null,
          location: args.location ?? null,
          activeSince: args.activeSince ?? null,
          avatarUrl: args.avatarUrl ?? null,
          coverImageUrl: args.coverImageUrl ?? null,
        })
        .returning();

      return artist;
    },
  }),

  updateArtist: t.field({
    type: ArtistType,
    args: {
      displayName: t.arg.string(),
      bio: t.arg.string(),
      tagline: t.arg.string(),
      location: t.arg.string(),
      activeSince: t.arg.int(),
      avatarUrl: t.arg.string(),
      coverImageUrl: t.arg.string(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const [existing] = await db
        .select()
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      if (!existing) {
        throw new GraphQLError("Artist profile not found");
      }

      // Validate provided values (null = clear, so skip validation for null)
      if (
        args.displayName &&
        (args.displayName.length < 1 || args.displayName.length > 50)
      ) {
        throw new GraphQLError(
          "Display name must be between 1 and 50 characters",
        );
      }
      if (args.bio != null && args.bio.length > 1000) {
        throw new GraphQLError("Bio must be 1000 characters or less");
      }
      if (args.tagline && args.tagline.length > 80) {
        throw new GraphQLError("Tagline must be 80 characters or less");
      }
      if (args.location && args.location.length > 100) {
        throw new GraphQLError("Location must be 100 characters or less");
      }
      if (args.activeSince != null) {
        const currentYear = new Date().getFullYear();
        if (args.activeSince < 1900 || args.activeSince > currentYear) {
          throw new GraphQLError(
            `Active since must be between 1900 and ${currentYear}`,
          );
        }
      }

      // undefined = not provided (skip), null = clear field, value = update
      const updateData: Record<string, unknown> = { updatedAt: new Date() };
      if (args.displayName !== undefined)
        updateData.displayName = args.displayName;
      if (args.bio !== undefined) updateData.bio = args.bio;
      if (args.tagline !== undefined) updateData.tagline = args.tagline;
      if (args.location !== undefined) updateData.location = args.location;
      if (args.activeSince !== undefined)
        updateData.activeSince = args.activeSince;
      if (args.avatarUrl !== undefined) updateData.avatarUrl = args.avatarUrl;
      if (args.coverImageUrl !== undefined)
        updateData.coverImageUrl = args.coverImageUrl;

      const [updated] = await db
        .update(artists)
        .set(updateData)
        .where(eq(artists.id, existing.id))
        .returning();

      return updated;
    },
  }),
}));

builder.queryFields((t) => ({
  artist: t.field({
    type: ArtistType,
    nullable: true,
    args: {
      username: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      const [artist] = await db
        .select()
        .from(artists)
        .where(eq(artists.artistUsername, args.username))
        .limit(1);
      return artist ?? null;
    },
  }),
}));
