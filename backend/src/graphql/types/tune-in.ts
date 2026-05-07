import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, posts, tuneIns, users } from "../../db/schema/index.js";
import { and, asc, eq, sql } from "drizzle-orm";
import { ArtistType } from "./artist.js";
import { validateUUID } from "../validators.js";
import { PublicUserType, publicUserColumns } from "./user.js";

const TuneInType = builder.objectRef<{
  userId: string;
  artistId: string;
  createdAt: Date;
  // Computed: MAX(posts.updated_at) for the followed artist's public posts.
  // Used by the avatar rail (`myTuneIns`) to sort by recent activity.
  //
  // Semantics of null:
  //   - In `myTuneIns`: the followed artist has no public posts (yet, or
  //     only has drafts). Sort places these last (NULLS LAST + tunedInAt).
  //   - In `tuneIns(artistId)` and `Artist.tuneIns` (followers list): the
  //     field is meaningless in this context — those resolvers return
  //     followers of an artist, not artists being followed — so the value
  //     is *always* null. Clients SHOULD omit the field from those
  //     selections; it remains exposed only because GraphQL field shapes
  //     are typed once per object type. A future split into `MyTuneIn`
  //     vs `ArtistFollower` is tracked in a follow-up issue if/when this
  //     becomes a real source of confusion.
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
      resolve: async (tuneIn, _args, ctx) => {
        // Use prefetched cache from the followers-list resolvers (tuneIns,
        // Artist.tuneIns) when available — avoids N+1 SELECTs.
        const cached = ctx.tuneInUserCache?.get(tuneIn.userId);
        if (cached) return cached;
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
      validateUUID(args.artistId, "artist id");

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

/**
 * Variant of {@link assertArtistOwnership} for callers that already hold the
 * artist row (e.g. the `Artist.tuneIns` field resolver receives `artist`
 * from its parent). Avoids a redundant DB roundtrip while preserving the
 * same uniform "Forbidden" semantics.
 */
function assertArtistOwnerByUserId(
  artistUserId: string,
  authUserId: string | undefined,
): void {
  if (!authUserId) {
    throw new GraphQLError("Authentication required");
  }
  if (artistUserId !== authUserId) {
    throw new GraphQLError("Forbidden");
  }
}

/**
 * Common shape returned by the followers-list resolvers (`tuneIns(artistId)`
 * and `Artist.tuneIns`). They both fetch tune-in rows joined with the
 * follower's public-user columns and populate the per-request cache so
 * `TuneInType.user` does not re-issue SELECTs for each follower.
 */
async function fetchFollowersWithUsers(
  artistId: string,
  ctx: import("../builder.js").GraphQLContext,
): Promise<
  {
    userId: string;
    artistId: string;
    createdAt: Date;
    lastPostActivityAt: null;
  }[]
> {
  const rows = await db
    .select({
      userId: tuneIns.userId,
      artistId: tuneIns.artistId,
      createdAt: tuneIns.createdAt,
      user: publicUserColumns,
    })
    .from(tuneIns)
    .innerJoin(users, eq(users.id, tuneIns.userId))
    .where(eq(tuneIns.artistId, artistId));

  if (!ctx.tuneInUserCache) {
    ctx.tuneInUserCache = new Map();
  }
  for (const row of rows) {
    ctx.tuneInUserCache.set(row.userId, row.user);
  }

  // The followers list does not need lastPostActivityAt — that field is
  // about the followed artist's activity, not about each follower.
  return rows.map((r) => ({
    userId: r.userId,
    artistId: r.artistId,
    createdAt: r.createdAt,
    lastPostActivityAt: null,
  }));
}

builder.queryFields((t) => ({
  tuneIns: t.field({
    type: [TuneInType],
    args: {
      artistId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      validateUUID(args.artistId, "artist id");
      // Followers list is private to the artist owner. See
      // assertArtistOwnership() for rationale.
      await assertArtistOwnership(args.artistId, ctx.authUser?.userId);
      return fetchFollowersWithUsers(args.artistId, ctx);
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
        // Reuse the SELECT alias rather than repeating the MAX(...)
        // expression so the two stay in sync if the aggregate changes.
        .orderBy(
          sql`last_post_activity_at DESC NULLS LAST`,
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
      // Parent already provides artist.userId, so we can authorize with a
      // direct comparison instead of re-fetching the artist row.
      assertArtistOwnerByUserId(artist.userId, ctx.authUser?.userId);
      return fetchFollowersWithUsers(artist.id, ctx);
    },
  }),
}));
