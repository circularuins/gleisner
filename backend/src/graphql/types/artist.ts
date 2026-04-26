import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, artistGenres } from "../../db/schema/index.js";
import { and, eq, desc, asc, sql } from "drizzle-orm";
import {
  validateProfileVisibility,
  validateMediaUrl,
  assertUploadedR2ObjectMatches,
} from "../validators.js";
import { checkArtistAccess } from "../access.js";
import { deleteR2Object } from "../../storage/r2.js";

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
  profileVisibility: string;
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
    profileVisibility: t.exposeString("profileVisibility"),
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

      // Validate URLs
      if (args.avatarUrl != null) {
        validateMediaUrl(args.avatarUrl);
        // Issue #269 / ADR 026: magic-byte check for avatar uploads.
        await assertUploadedR2ObjectMatches(args.avatarUrl);
      }
      if (args.coverImageUrl != null) {
        validateMediaUrl(args.coverImageUrl);
        await assertUploadedR2ObjectMatches(args.coverImageUrl);
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
          // Child accounts: default private (ADR 019 Tier 1)
          // Guardian can change to public via updateArtist
          ...(ctx.authUser.guardianId ? { profileVisibility: "private" } : {}),
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
      clearAvatarUrl: t.arg.boolean(),
      coverImageUrl: t.arg.string(),
      clearCoverImageUrl: t.arg.boolean(),
      profileVisibility: t.arg.string(),
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

      // Validate URLs (null = clear, so only validate non-null strings).
      // Issue #269 / ADR 026: skip the magic-byte R2 GET when the URL
      // already matches the row in DB — every persisted URL was validated
      // when first stored, so re-validating buys nothing. See ADR
      // §"Negative consequences" (skip-when-unchanged paragraph) for why
      // strict equality is the correct primitive here.
      if (args.avatarUrl != null) {
        validateMediaUrl(args.avatarUrl);
        if (args.avatarUrl !== existing.avatarUrl) {
          await assertUploadedR2ObjectMatches(args.avatarUrl);
        }
      }
      if (args.coverImageUrl != null) {
        validateMediaUrl(args.coverImageUrl);
        if (args.coverImageUrl !== existing.coverImageUrl) {
          await assertUploadedR2ObjectMatches(args.coverImageUrl);
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
      if (args.clearAvatarUrl && args.avatarUrl != null) {
        throw new GraphQLError("Cannot set and clear avatarUrl simultaneously");
      }
      if (args.clearCoverImageUrl && args.coverImageUrl != null) {
        throw new GraphQLError(
          "Cannot set and clear coverImageUrl simultaneously",
        );
      }
      if (args.clearAvatarUrl) {
        updateData.avatarUrl = null;
      } else if (args.avatarUrl !== undefined) {
        updateData.avatarUrl = args.avatarUrl;
      }
      if (args.clearCoverImageUrl) {
        updateData.coverImageUrl = null;
      } else if (args.coverImageUrl !== undefined) {
        updateData.coverImageUrl = args.coverImageUrl;
      }
      if (args.profileVisibility !== undefined) {
        validateProfileVisibility(args.profileVisibility as string);
        updateData.profileVisibility = args.profileVisibility;
      }

      const [updated] = await db
        .update(artists)
        .set(updateData)
        .where(eq(artists.id, existing.id))
        .returning();

      // R2 fire-and-forget: clean up old files when avatar/cover changes.
      // Auth confirmed: existing is the current user's artist (userId check above).
      // updateData.avatarUrl !== undefined means the field was explicitly sent
      // (null = clear via clearAvatarUrl, value = new upload). Either way, the old
      // R2 file is no longer referenced and should be cleaned up.
      if (updateData.avatarUrl !== undefined && existing.avatarUrl) {
        deleteR2Object(existing.avatarUrl).catch((err) =>
          console.error("[updateArtist] R2 avatar cleanup failed:", err),
        );
      }
      if (updateData.coverImageUrl !== undefined && existing.coverImageUrl) {
        deleteR2Object(existing.coverImageUrl).catch((err) =>
          console.error("[updateArtist] R2 cover cleanup failed:", err),
        );
      }

      return updated;
    },
  }),
}));

builder.queryFields((t) => ({
  featuredArtist: t.field({
    type: ArtistType,
    nullable: true,
    resolve: async () => {
      const [artist] = await db
        .select({
          id: artists.id,
          userId: artists.userId,
          artistUsername: artists.artistUsername,
          displayName: artists.displayName,
          bio: artists.bio,
          tagline: artists.tagline,
          location: artists.location,
          activeSince: artists.activeSince,
          avatarUrl: artists.avatarUrl,
          coverImageUrl: artists.coverImageUrl,
          profileVisibility: artists.profileVisibility,
          tunedInCount: artists.tunedInCount,
          createdAt: artists.createdAt,
          updatedAt: artists.updatedAt,
        })
        .from(artists)
        .where(
          and(
            eq(artists.isFeatured, true),
            eq(artists.profileVisibility, "public"),
          ),
        )
        .orderBy(asc(artists.createdAt))
        .limit(1);
      return artist ?? null;
    },
  }),

  artist: t.field({
    type: ArtistType,
    nullable: true,
    args: {
      username: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      const [artist] = await db
        .select()
        .from(artists)
        .where(eq(artists.artistUsername, args.username))
        .limit(1);
      if (!artist) return null;

      const access = await checkArtistAccess(artist.id, ctx.authUser);
      return access.accessible ? artist : null;
    },
  }),

  myArtist: t.field({
    type: ArtistType,
    nullable: true,
    resolve: async (_parent, _args, ctx) => {
      if (!ctx.authUser) return null;
      const [artist] = await db
        .select()
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      return artist ?? null;
    },
  }),

  discoverArtists: t.field({
    type: [ArtistType],
    args: {
      genreId: t.arg.string(),
      query: t.arg.string(),
      limit: t.arg.int(),
      offset: t.arg.int(),
    },
    resolve: async (_parent, args) => {
      const limit = Math.min(args.limit ?? 20, 50);
      const offset = args.offset ?? 0;
      const pattern = args.query?.trim() ? `%${args.query.trim()}%` : null;

      const publicOnly = eq(artists.profileVisibility, "public");

      // Genre filter: single JOIN query instead of 2-query split
      if (args.genreId) {
        const textFilter = pattern
          ? sql` AND (${artists.displayName} ILIKE ${pattern} OR ${artists.artistUsername} ILIKE ${pattern} OR ${artists.tagline} ILIKE ${pattern})`
          : sql``;

        return db
          .select({
            id: artists.id,
            userId: artists.userId,
            artistUsername: artists.artistUsername,
            displayName: artists.displayName,
            bio: artists.bio,
            tagline: artists.tagline,
            location: artists.location,
            activeSince: artists.activeSince,
            avatarUrl: artists.avatarUrl,
            coverImageUrl: artists.coverImageUrl,
            profileVisibility: artists.profileVisibility,
            tunedInCount: artists.tunedInCount,
            createdAt: artists.createdAt,
            updatedAt: artists.updatedAt,
          })
          .from(artists)
          .innerJoin(
            artistGenres,
            sql`${artistGenres.artistId} = ${artists.id} AND ${artistGenres.genreId} = ${args.genreId}`,
          )
          .where(sql`${artists.profileVisibility} = 'public'${textFilter}`)
          .orderBy(desc(artists.tunedInCount))
          .limit(limit)
          .offset(offset);
      }

      // Text search only
      if (pattern) {
        return db
          .select()
          .from(artists)
          .where(
            and(
              publicOnly,
              sql`(${artists.displayName} ILIKE ${pattern} OR ${artists.artistUsername} ILIKE ${pattern} OR ${artists.tagline} ILIKE ${pattern})`,
            ),
          )
          .orderBy(desc(artists.tunedInCount))
          .limit(limit)
          .offset(offset);
      }

      // No filters — all public artists by popularity
      return db
        .select()
        .from(artists)
        .where(publicOnly)
        .orderBy(desc(artists.tunedInCount))
        .limit(limit)
        .offset(offset);
    },
  }),
}));
