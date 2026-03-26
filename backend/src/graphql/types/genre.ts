import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, artistGenres, genres } from "../../db/schema/index.js";
import { and, eq, sql } from "drizzle-orm";
import { ArtistType } from "./artist.js";

const GenreType = builder.objectRef<{
  id: string;
  name: string;
  normalizedName: string;
  isPromoted: boolean;
  createdAt: Date;
}>("Genre");

GenreType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    name: t.exposeString("name"),
    normalizedName: t.exposeString("normalizedName"),
    isPromoted: t.exposeBoolean("isPromoted"),
    createdAt: t.string({
      resolve: (genre) => genre.createdAt.toISOString(),
    }),
  }),
});

// Prefetched genre data to avoid N+1 (attached by ArtistType.genres resolver)
interface ArtistGenreRow {
  artistId: string;
  genreId: string;
  position: number;
  _genre?: {
    id: string;
    name: string;
    normalizedName: string;
    isPromoted: boolean;
    createdAt: Date;
  };
}

const ArtistGenreType = builder.objectRef<ArtistGenreRow>("ArtistGenre");

ArtistGenreType.implement({
  fields: (t) => ({
    position: t.exposeInt("position"),
    genre: t.field({
      type: GenreType,
      resolve: async (ag) => {
        // Use prefetched data from ArtistType.genres JOIN if available
        if (ag._genre) return ag._genre;
        // Fallback for mutations (addArtistGenre/removeArtistGenre)
        const [genre] = await db
          .select()
          .from(genres)
          .where(eq(genres.id, ag.genreId))
          .limit(1);
        return genre;
      },
    }),
    artist: t.field({
      type: ArtistType,
      resolve: async (ag) => {
        const [artist] = await db
          .select()
          .from(artists)
          .where(eq(artists.id, ag.artistId))
          .limit(1);
        return artist;
      },
    }),
  }),
});

builder.mutationFields((t) => ({
  addArtistGenre: t.field({
    type: ArtistGenreType,
    args: {
      genreId: t.arg.string({ required: true }),
      position: t.arg.int(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Find own artist
      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      if (!artist) {
        throw new GraphQLError("Artist profile required");
      }

      // Verify genre exists
      const [genre] = await db
        .select({ id: genres.id })
        .from(genres)
        .where(eq(genres.id, args.genreId))
        .limit(1);
      if (!genre) {
        throw new GraphQLError("Genre not found");
      }

      // Check limit + insert atomically to prevent TOCTOU race condition
      try {
        let result:
          | { artistId: string; genreId: string; position: number }
          | undefined;
        await db.transaction(async (tx) => {
          // Lock artist row to serialize concurrent genre additions
          await tx.execute(
            sql`SELECT 1 FROM artists WHERE id = ${artist.id} FOR UPDATE`,
          );
          const existing = await tx
            .select({ genreId: artistGenres.genreId })
            .from(artistGenres)
            .where(eq(artistGenres.artistId, artist.id));
          if (existing.length >= 5) {
            throw new GraphQLError("Maximum 5 genres per artist");
          }
          const [ag] = await tx
            .insert(artistGenres)
            .values({
              artistId: artist.id,
              genreId: args.genreId,
              ...(args.position != null ? { position: args.position } : {}),
            })
            .returning();
          result = ag;
        });
        return result!;
      } catch (e) {
        if (e instanceof GraphQLError) throw e;
        throw new GraphQLError("Genre already added or failed to add");
      }
    },
  }),

  removeArtistGenre: t.field({
    type: ArtistGenreType,
    args: {
      genreId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Find own artist
      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      if (!artist) {
        throw new GraphQLError("Artist profile required");
      }

      // Ownership-safe: include artistId in DELETE WHERE
      const [deleted] = await db
        .delete(artistGenres)
        .where(
          and(
            eq(artistGenres.artistId, artist.id),
            eq(artistGenres.genreId, args.genreId),
          ),
        )
        .returning();

      if (!deleted) {
        throw new GraphQLError("Genre not found in your profile");
      }

      return deleted;
    },
  }),
}));

builder.mutationFields((t) => ({
  createGenre: t.field({
    type: GenreType,
    args: {
      name: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const name = args.name.trim();
      if (name.length < 1 || name.length > 50) {
        throw new GraphQLError("Genre name must be between 1 and 50 characters");
      }

      const normalizedName = name.toLowerCase();

      // Check if already exists
      const [existing] = await db
        .select({ id: genres.id })
        .from(genres)
        .where(eq(genres.normalizedName, normalizedName))
        .limit(1);
      if (existing) {
        // Return existing genre instead of error (idempotent)
        const [genre] = await db
          .select()
          .from(genres)
          .where(eq(genres.normalizedName, normalizedName))
          .limit(1);
        return genre;
      }

      const [genre] = await db
        .insert(genres)
        .values({
          name,
          normalizedName,
          isPromoted: false, // User-created genres are not promoted
        })
        .returning();
      return genre;
    },
  }),
}));

builder.queryFields((t) => ({
  genres: t.field({
    type: [GenreType],
    resolve: async () => {
      return db.select().from(genres);
    },
  }),
}));

// Add genres field to ArtistType — JOIN to avoid N+1 on genre resolver
builder.objectFields(ArtistType, (t) => ({
  genres: t.field({
    type: [ArtistGenreType],
    resolve: async (artist) => {
      const rows = await db
        .select({
          artistId: artistGenres.artistId,
          genreId: artistGenres.genreId,
          position: artistGenres.position,
          genre: genres,
        })
        .from(artistGenres)
        .innerJoin(genres, eq(artistGenres.genreId, genres.id))
        .where(eq(artistGenres.artistId, artist.id));

      // Attach prefetched genre data so ArtistGenreType.genre skips DB query
      return rows.map((r) => ({
        artistId: r.artistId,
        genreId: r.genreId,
        position: r.position,
        _genre: r.genre,
      }));
    },
  }),
}));
