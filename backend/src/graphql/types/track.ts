import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, tracks } from "../../db/schema/index.js";
import { and, eq, sql } from "drizzle-orm";
import { ArtistType } from "./artist.js";
import { checkArtistAccess } from "../access.js";
import { validateUUID } from "../validators.js";

export const TrackType = builder.objectRef<{
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

      // Check for duplicate track name (case-insensitive) within the same artist
      const [existing] = await db
        .select({ id: tracks.id })
        .from(tracks)
        .where(
          and(
            eq(tracks.artistId, artist.id),
            eq(sql`lower(${tracks.name})`, args.name.toLowerCase()),
          ),
        )
        .limit(1);
      if (existing) {
        throw new GraphQLError("A track with this name already exists");
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
      validateUUID(args.id, "track id");

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

      // Check for duplicate track name (case-insensitive) on rename
      if (args.name !== undefined && args.name !== null) {
        const [dup] = await db
          .select({ id: tracks.id })
          .from(tracks)
          .where(
            and(
              eq(tracks.artistId, track.artistId),
              eq(sql`lower(${tracks.name})`, args.name.toLowerCase()),
            ),
          )
          .limit(1);
        if (dup && dup.id !== track.id) {
          throw new GraphQLError("A track with this name already exists");
        }
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
      validateUUID(args.id, "track id");

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
    resolve: async (_parent, args, ctx) => {
      validateUUID(args.id, "track id");
      const [track] = await db
        .select()
        .from(tracks)
        .where(eq(tracks.id, args.id))
        .limit(1);
      if (!track) return null;
      // Hide tracks owned by inaccessible artists (#350).
      // Schema is nullable; null is consistent with `post(id)` (#250) and
      // does not distinguish "missing" from "private" — closes the
      // enumeration oracle on track ids.
      const access = await checkArtistAccess(track.artistId, ctx.authUser);
      if (!access.accessible) return null;
      return track;
    },
  }),

  tracks: t.field({
    type: [TrackType],
    args: {
      artistUsername: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      // Find artist by username, then get their tracks
      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.artistUsername, args.artistUsername))
        .limit(1);
      if (!artist) {
        return [];
      }
      // Gate by artist visibility (sec-3). Inaccessible artists return an
      // empty list, indistinguishable from "exists with no tracks" — same
      // enumeration-oracle posture as `posts(trackId)` (#363).
      const access = await checkArtistAccess(artist.id, ctx.authUser);
      if (!access.accessible) {
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
    resolve: async (artist, _args, ctx) => {
      // Defense-in-depth: top-level `artist(username)` already gates
      // ArtistType visibility, but field-level access keeps the guard
      // intact if a future code path returns ArtistType without a prior
      // check (mirrors `ArtistType.recentPosts` pattern from PR-A / #363).
      //
      // TODO(#372): `checkArtistAccess` issues up to 2 SELECTs per artist
      // (artists + tuneIns). Already triggerable today via
      // `myTuneIns { artist { tracks { id } } }` — N tune-ins fan out to
      // N × 2 SELECTs for the visibility gate. The fix path is a
      // ctx-cached access map or prefetched `_access` embedding (see
      // `.claude/rules/backend-implementation.md` N+1 pattern). Paired
      // with #371 (`checkArtistAccess` overload), the close-out is small.
      const access = await checkArtistAccess(artist.id, ctx.authUser);
      if (!access.accessible) {
        return [];
      }
      return db.select().from(tracks).where(eq(tracks.artistId, artist.id));
    },
  }),
}));
