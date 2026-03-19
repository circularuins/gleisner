import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, artistLinks } from "../../db/schema/index.js";
import { and, eq } from "drizzle-orm";
import { ArtistType } from "./artist.js";

const LinkCategoryEnum = builder.enumType("LinkCategory", {
  values: ["social", "music", "video", "website", "store", "other"] as const,
});

const ArtistLinkType = builder.objectRef<{
  id: string;
  artistId: string;
  linkCategory: "social" | "music" | "video" | "website" | "store" | "other";
  platform: string;
  url: string;
  position: number;
  createdAt: Date;
}>("ArtistLink");

ArtistLinkType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    linkCategory: t.field({
      type: LinkCategoryEnum,
      resolve: (link) => link.linkCategory,
    }),
    platform: t.exposeString("platform"),
    url: t.exposeString("url"),
    position: t.exposeInt("position"),
    createdAt: t.string({
      resolve: (link) => link.createdAt.toISOString(),
    }),
    artist: t.field({
      type: ArtistType,
      resolve: async (link) => {
        const [artist] = await db
          .select()
          .from(artists)
          .where(eq(artists.id, link.artistId))
          .limit(1);
        return artist;
      },
    }),
  }),
});

function validateUrl(url: string): void {
  try {
    const parsed = new URL(url);
    if (!["https:", "http:"].includes(parsed.protocol)) {
      throw new GraphQLError("URL must use http or https");
    }
  } catch (e) {
    if (e instanceof GraphQLError) throw e;
    throw new GraphQLError("Invalid URL format");
  }
}

async function getOwnArtistId(userId: string): Promise<string> {
  const [artist] = await db
    .select({ id: artists.id })
    .from(artists)
    .where(eq(artists.userId, userId))
    .limit(1);
  if (!artist) {
    throw new GraphQLError("Artist profile required");
  }
  return artist.id;
}

builder.mutationFields((t) => ({
  createArtistLink: t.field({
    type: ArtistLinkType,
    args: {
      linkCategory: t.arg({ type: LinkCategoryEnum, required: true }),
      platform: t.arg.string({ required: true }),
      url: t.arg.string({ required: true }),
      position: t.arg.int(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const artistId = await getOwnArtistId(ctx.authUser.userId);

      // Validate platform
      const platform = args.platform.trim();
      if (platform.length === 0 || platform.length > 50) {
        throw new GraphQLError("Platform must be between 1 and 50 characters");
      }

      // Validate URL
      validateUrl(args.url);

      try {
        const [link] = await db
          .insert(artistLinks)
          .values({
            artistId,
            linkCategory: args.linkCategory,
            platform,
            url: args.url,
            ...(args.position != null ? { position: args.position } : {}),
          })
          .returning();
        return link;
      } catch {
        throw new GraphQLError("Failed to create link");
      }
    },
  }),

  updateArtistLink: t.field({
    type: ArtistLinkType,
    args: {
      id: t.arg.string({ required: true }),
      linkCategory: t.arg({ type: LinkCategoryEnum }),
      platform: t.arg.string(),
      url: t.arg.string(),
      position: t.arg.int(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const artistId = await getOwnArtistId(ctx.authUser.userId);

      // Ownership-safe: include artistId in WHERE
      const [link] = await db
        .select()
        .from(artistLinks)
        .where(
          and(eq(artistLinks.id, args.id), eq(artistLinks.artistId, artistId)),
        )
        .limit(1);
      if (!link) {
        throw new GraphQLError("Link not found");
      }

      // Validate platform if provided
      if (args.platform != null) {
        const platform = args.platform.trim();
        if (platform.length === 0 || platform.length > 50) {
          throw new GraphQLError(
            "Platform must be between 1 and 50 characters",
          );
        }
      }

      // Validate URL if provided
      if (args.url != null) {
        validateUrl(args.url);
      }

      const updateData: Record<string, unknown> = {};
      if (args.linkCategory !== undefined)
        updateData.linkCategory = args.linkCategory;
      if (args.platform !== undefined) updateData.platform = args.platform;
      if (args.url !== undefined) updateData.url = args.url;
      if (args.position !== undefined) updateData.position = args.position;

      const [updated] = await db
        .update(artistLinks)
        .set(updateData)
        .where(
          and(eq(artistLinks.id, args.id), eq(artistLinks.artistId, artistId)),
        )
        .returning();

      return updated;
    },
  }),

  deleteArtistLink: t.field({
    type: ArtistLinkType,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const artistId = await getOwnArtistId(ctx.authUser.userId);

      // Ownership-safe: include artistId in DELETE WHERE
      const [deleted] = await db
        .delete(artistLinks)
        .where(
          and(eq(artistLinks.id, args.id), eq(artistLinks.artistId, artistId)),
        )
        .returning();

      if (!deleted) {
        throw new GraphQLError("Link not found");
      }

      return deleted;
    },
  }),
}));

builder.queryFields((t) => ({
  artistLinks: t.field({
    type: [ArtistLinkType],
    args: {
      artistId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      return db
        .select()
        .from(artistLinks)
        .where(eq(artistLinks.artistId, args.artistId));
    },
  }),
}));

// Add links field to ArtistType
builder.objectFields(ArtistType, (t) => ({
  links: t.field({
    type: [ArtistLinkType],
    resolve: async (artist) => {
      return db
        .select()
        .from(artistLinks)
        .where(eq(artistLinks.artistId, artist.id));
    },
  }),
}));
