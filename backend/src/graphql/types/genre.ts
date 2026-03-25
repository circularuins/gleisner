import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, artistGenres, genres } from "../../db/schema/index.js";
import { and, eq } from "drizzle-orm";
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

const ArtistGenreType = builder.objectRef<{
  artistId: string;
  genreId: string;
  position: number;
}>("ArtistGenre");

ArtistGenreType.implement({
  fields: (t) => ({
    position: t.exposeInt("position"),
    genre: t.field({
      type: GenreType,
      resolve: async (ag) => {
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

      // Check genre limit (max 5 per artist)
      const existingGenres = await db
        .select({ genreId: artistGenres.genreId })
        .from(artistGenres)
        .where(eq(artistGenres.artistId, artist.id));
      if (existingGenres.length >= 5) {
        throw new GraphQLError("Maximum 5 genres per artist");
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

      try {
        const [ag] = await db
          .insert(artistGenres)
          .values({
            artistId: artist.id,
            genreId: args.genreId,
            ...(args.position != null ? { position: args.position } : {}),
          })
          .returning();
        return ag;
      } catch {
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

builder.queryFields((t) => ({
  genres: t.field({
    type: [GenreType],
    resolve: async () => {
      return db.select().from(genres);
    },
  }),
}));

// Add genres field to ArtistType
builder.objectFields(ArtistType, (t) => ({
  genres: t.field({
    type: [ArtistGenreType],
    resolve: async (artist) => {
      return db
        .select()
        .from(artistGenres)
        .where(eq(artistGenres.artistId, artist.id));
    },
  }),
}));
