import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, tracks } from "../../db/schema/index.js";
import { eq } from "drizzle-orm";
import { ArtistType } from "./artist.js";

const TrackType = builder.objectRef<{
  id: string;
  artistId: string;
  name: string;
  color: string;
  createdAt: Date;
  updatedAt: Date;
}>("Track");

TrackType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    name: t.exposeString("name"),
    color: t.exposeString("color"),
    createdAt: t.string({
      resolve: (track) => track.createdAt.toISOString(),
    }),
    updatedAt: t.string({
      resolve: (track) => track.updatedAt.toISOString(),
    }),
  }),
});

const HEX_COLOR_RE = /^#[0-9A-Fa-f]{6}$/;

builder.mutationFields((t) => ({
  createTrack: t.field({
    type: TrackType,
    args: {
      name: t.arg.string({ required: true }),
      color: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Find artist for this user
      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      if (!artist) {
        throw new GraphQLError("Artist profile required to create a track");
      }

      // Validate name
      if (args.name.length < 1 || args.name.length > 30) {
        throw new GraphQLError(
          "Track name must be between 1 and 30 characters",
        );
      }

      // Validate color
      if (!HEX_COLOR_RE.test(args.color)) {
        throw new GraphQLError(
          "Color must be a valid hex color (e.g. #FF0000)",
        );
      }

      const [track] = await db
        .insert(tracks)
        .values({
          artistId: artist.id,
          name: args.name,
          color: args.color,
        })
        .returning();

      return track;
    },
  }),

  updateTrack: t.field({
    type: TrackType,
    args: {
      id: t.arg.string({ required: true }),
      name: t.arg.string(),
      color: t.arg.string(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Fetch the track
      const [track] = await db
        .select()
        .from(tracks)
        .where(eq(tracks.id, args.id))
        .limit(1);
      if (!track) {
        throw new GraphQLError("Track not found");
      }

      // Ownership check: track.artistId → artist.userId
      const [artist] = await db
        .select({ userId: artists.userId })
        .from(artists)
        .where(eq(artists.id, track.artistId))
        .limit(1);
      if (!artist || artist.userId !== ctx.authUser.userId) {
        throw new GraphQLError("Not authorized to update this track");
      }

      // Validate provided values
      if (
        args.name !== undefined &&
        args.name !== null &&
        (args.name.length < 1 || args.name.length > 30)
      ) {
        throw new GraphQLError(
          "Track name must be between 1 and 30 characters",
        );
      }
      if (
        args.color !== undefined &&
        args.color !== null &&
        !HEX_COLOR_RE.test(args.color)
      ) {
        throw new GraphQLError(
          "Color must be a valid hex color (e.g. #FF0000)",
        );
      }

      const updateData: Record<string, unknown> = { updatedAt: new Date() };
      if (args.name !== undefined) updateData.name = args.name;
      if (args.color !== undefined) updateData.color = args.color;

      const [updated] = await db
        .update(tracks)
        .set(updateData)
        .where(eq(tracks.id, args.id))
        .returning();

      return updated;
    },
  }),

  deleteTrack: t.field({
    type: TrackType,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const [track] = await db
        .select()
        .from(tracks)
        .where(eq(tracks.id, args.id))
        .limit(1);
      if (!track) {
        throw new GraphQLError("Track not found");
      }

      // Ownership check
      const [artist] = await db
        .select({ userId: artists.userId })
        .from(artists)
        .where(eq(artists.id, track.artistId))
        .limit(1);
      if (!artist || artist.userId !== ctx.authUser.userId) {
        throw new GraphQLError("Not authorized to delete this track");
      }

      const [deleted] = await db
        .delete(tracks)
        .where(eq(tracks.id, args.id))
        .returning();

      return deleted;
    },
  }),
}));

builder.queryFields((t) => ({
  track: t.field({
    type: TrackType,
    nullable: true,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      const [track] = await db
        .select()
        .from(tracks)
        .where(eq(tracks.id, args.id))
        .limit(1);
      return track ?? null;
    },
  }),

  tracks: t.field({
    type: [TrackType],
    args: {
      artistUsername: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      // Find artist by username, then get their tracks
      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.artistUsername, args.artistUsername))
        .limit(1);
      if (!artist) {
        return [];
      }

      return db.select().from(tracks).where(eq(tracks.artistId, artist.id));
    },
  }),
}));

// Add tracks field to ArtistType (avoids circular import by extending here)
builder.objectFields(ArtistType, (t) => ({
  tracks: t.field({
    type: [TrackType],
    resolve: async (artist) => {
      return db.select().from(tracks).where(eq(tracks.artistId, artist.id));
    },
  }),
}));
