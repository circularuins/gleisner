import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, posts, tuneIns, users } from "../../db/schema/index.js";
import { and, asc, eq, sql } from "drizzle-orm";
import { ArtistType } from "./artist.js";
import { PublicUserType, publicUserColumns } from "./user.js";

const TuneInType = builder.objectRef<{
  userId: string;
  artistId: string;
  createdAt: Date;
  // Computed: MAX(posts.updated_at) for the followed artist's public posts.
  // null when the artist has never posted (or only has draft posts). Used by
  // the avatar rail to sort by recent activity. See ADR / Issue link in PR.
  lastPostActivityAt: Date | null;
}>("TuneIn");

TuneInType.implement({
  fields: (t) => ({
    createdAt: t.string({
      resolve: (tuneIn) => tuneIn.createdAt.toISOString(),
    }),
    lastPostActivityAt: t.string({
      nullable: true,
      resolve: (tuneIn) => tuneIn.lastPostActivityAt?.toISOString() ?? null,
    }),
    user: t.field({
      type: PublicUserType,
      resolve: async (tuneIn) => {
        const [user] = await db
          .select(publicUserColumns)
          .from(users)
          .where(eq(users.id, tuneIn.userId))
          .limit(1);
        if (!user) throw new GraphQLError("User not found");
        return user;
      },
    }),
    artist: t.field({
      type: ArtistType,
      resolve: async (tuneIn, _args, ctx) => {
        // Use prefetched cache from myTuneIns if available
        const cached = ctx.tuneInArtistCache?.get(tuneIn.artistId);
        if (cached) return cached;
        const [artist] = await db
          .select()
          .from(artists)
          .where(eq(artists.id, tuneIn.artistId))
          .limit(1);
        return artist;
      },
    }),
  }),
});

builder.mutationFields((t) => ({
  toggleTuneIn: t.field({
    type: TuneInType,
    nullable: true,
    args: {
      artistId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Verify artist exists
      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.id, args.artistId))
        .limit(1);
      if (!artist) {
        throw new GraphQLError("Artist not found");
      }

      // Check if already tuned in
      const [existing] = await db
        .select()
        .from(tuneIns)
        .where(
          and(
            eq(tuneIns.userId, ctx.authUser.userId),
            eq(tuneIns.artistId, args.artistId),
          ),
        )
        .limit(1);

      if (existing) {
        // Tune out — use transaction for count consistency
        await db.transaction(async (tx) => {
          await tx
            .delete(tuneIns)
            .where(
              and(
                eq(tuneIns.userId, ctx.authUser!.userId),
                eq(tuneIns.artistId, args.artistId),
              ),
            );
          await tx
            .update(artists)
            .set({ tunedInCount: sql`${artists.tunedInCount} - 1` })
            .where(eq(artists.id, args.artistId));
        });
        return null;
      }

      // Tune in — use transaction for count consistency
      try {
        let result:
          | {
              userId: string;
              artistId: string;
              createdAt: Date;
              lastPostActivityAt: Date | null;
            }
          | undefined;
        await db.transaction(async (tx) => {
          const [tuneIn] = await tx
            .insert(tuneIns)
            .values({
              userId: ctx.authUser!.userId,
              artistId: args.artistId,
            })
            .returning();
          await tx
            .update(artists)
            .set({ tunedInCount: sql`${artists.tunedInCount} + 1` })
            .where(eq(artists.id, args.artistId));
          // Newly created tune-in has no aggregated activity yet — clients
          // should refetch myTuneIns to pick up the sorted state.
          result = { ...tuneIn, lastPostActivityAt: null };
        });
        return result!;
      } catch {
        throw new GraphQLError("Failed to tune in");
      }
    },
  }),
}));

/**
 * Authorization helper for the artist-followers list. The followers of an
 * artist are private to the artist owner (Phase 0 family lifelog policy):
 * exposing this list publicly would leak who is connected to whom across
 * unrelated households. Returns the artist row when the caller owns it,
 * otherwise throws.
 *
 * Both "artist does not exist" and "you are not the owner" surface the same
 * "Forbidden" error so that an authenticated attacker cannot enumerate
 * artist IDs by probing for differentiated error messages.
 */
async function assertArtistOwnership(
  artistId: string,
  authUserId: string | undefined,
): Promise<{ id: string; userId: string }> {
  if (!authUserId) {
    throw new GraphQLError("Authentication required");
  }
  const [artist] = await db
    .select({ id: artists.id, userId: artists.userId })
    .from(artists)
    .where(and(eq(artists.id, artistId), eq(artists.userId, authUserId)))
    .limit(1);
  if (!artist) {
    throw new GraphQLError("Forbidden");
  }
  return artist;
}

builder.queryFields((t) => ({
  tuneIns: t.field({
    type: [TuneInType],
    args: {
      artistId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      // Followers list is private to the artist owner. See
      // assertArtistOwnership() for rationale.
      await assertArtistOwnership(args.artistId, ctx.authUser?.userId);
      const rows = await db
        .select()
        .from(tuneIns)
        .where(eq(tuneIns.artistId, args.artistId));
      // The followers list does not need lastPostActivityAt — that field is
      // about the followed artist's activity, not about each follower.
      return rows.map((r) => ({
        userId: r.userId,
        artistId: r.artistId,
        createdAt: r.createdAt,
        lastPostActivityAt: null,
      }));
    },
  }),

  myTuneIns: t.field({
    type: [TuneInType],
    resolve: async (_parent, _args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }
      // JOIN to prefetch artist data — avoids N+1 on TuneInType.artist resolver.
      // LEFT JOIN posts on the followed artist's public posts so we can sort
      // the avatar rail by recent activity. visibility='public' is critical:
      // without it, draft posts' updated_at would leak the artist's editing
      // activity to their followers.
      const rows = await db
        .select({
          userId: tuneIns.userId,
          artistId: tuneIns.artistId,
          createdAt: tuneIns.createdAt,
          artist: artists,
          // postgres.js does not auto-parse aggregate results to Date — keep
          // it as the raw `string | null` here and normalize below.
          lastPostActivityAt: sql<string | null>`MAX(${posts.updatedAt})`.as(
            "last_post_activity_at",
          ),
        })
        .from(tuneIns)
        .innerJoin(artists, eq(tuneIns.artistId, artists.id))
        .leftJoin(
          posts,
          and(
            eq(posts.authorId, artists.userId),
            eq(posts.visibility, "public"),
          ),
        )
        .where(eq(tuneIns.userId, ctx.authUser.userId))
        // GROUP BY tune-in PK + artist PK — PostgreSQL's functional
        // dependency analysis lets us SELECT artists.* and ti.created_at
        // without listing them here.
        .groupBy(tuneIns.userId, tuneIns.artistId, artists.id)
        .orderBy(
          sql`MAX(${posts.updatedAt}) DESC NULLS LAST`,
          asc(tuneIns.createdAt),
        );

      // Attach prefetched artist to context cache so TuneInType.artist resolver
      // can use it instead of issuing another query
      if (!ctx.tuneInArtistCache) {
        ctx.tuneInArtistCache = new Map();
      }
      for (const row of rows) {
        ctx.tuneInArtistCache.set(row.artistId, row.artist);
      }

      return rows.map((r) => ({
        userId: r.userId,
        artistId: r.artistId,
        createdAt: r.createdAt,
        // Normalize the aggregate result back to Date (or null when the
        // artist has no public posts).
        lastPostActivityAt: r.lastPostActivityAt
          ? new Date(r.lastPostActivityAt)
          : null,
      }));
    },
  }),
}));

// Add tuneIns field to ArtistType — same authorization as the top-level
// tuneIns(artistId) query: only the artist owner can list their followers.
builder.objectFields(ArtistType, (t) => ({
  tuneIns: t.field({
    type: [TuneInType],
    resolve: async (artist, _args, ctx) => {
      await assertArtistOwnership(artist.id, ctx.authUser?.userId);
      const rows = await db
        .select()
        .from(tuneIns)
        .where(eq(tuneIns.artistId, artist.id));
      return rows.map((r) => ({
        userId: r.userId,
        artistId: r.artistId,
        createdAt: r.createdAt,
        lastPostActivityAt: null,
      }));
    },
  }),
}));
