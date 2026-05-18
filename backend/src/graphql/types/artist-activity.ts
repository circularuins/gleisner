/**
 * Activity heatmap fields on `Artist` (Idea 032).
 *
 * Exposes two read-only derived metrics that drive the artist page's "star
 * calendar" heatmap and the discover card's pulse beacon:
 *
 * - `activitySeries: [ActivityDay!]!` — daily post count from the artist's
 *   registration date (or `today - 365d`, whichever is later) up to today.
 *   Only days with at least one matching post are returned.
 * - `lastPostedAt: String` — ISO 8601 timestamp of the most recent matching
 *   post, or null if none.
 *
 * Authorization mirrors `recentPosts` exactly so that activity counts cannot
 * leak information that the post resolvers would hide:
 *   1. `checkArtistAccess` (Layer 1: `artists.profileVisibility`) — re-run
 *      inside the field resolver even on deep paths (see #250 sec-1).
 *   2. `isAuthorVisibleToViewer` (Layer 0: `users.profileVisibility`) — child
 *      / non-public author rows are hidden from non-self viewers.
 *   3. `posts.visibility = 'public'` — for non-self viewers (incl. tuned-in
 *      followers, matching `recentPosts` / `artistPosts` behaviour).
 *   4. `posts.trackId IS NOT NULL` — unassigned posts are excluded so the
 *      heatmap reflects the same scope as the artist's track timeline (#67).
 *
 * The 365-day window is hardcoded; clients trim further if the artist is
 * newer. Future `periodDays` argument should be clamped with
 * `Math.max(1, Math.min(args.periodDays ?? 365, 365))` to prevent DoS.
 */
import { builder, type GraphQLContext } from "../builder.js";
import { db } from "../../db/index.js";
import { posts, users } from "../../db/schema/index.js";
import { and, eq, gte, sql, type SQL } from "drizzle-orm";
import { ArtistType } from "./artist.js";
import { checkArtistAccess, isAuthorVisibleToViewer } from "../access.js";

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const ACTIVITY_PERIOD_DAYS = 365;

/** Internal shape used for the GROUP BY result. */
interface ActivityDayShape {
  date: string;
  count: number;
}

export const ActivityDayType = builder
  .objectRef<ActivityDayShape>("ActivityDay")
  .implement({
    description:
      "A single day of artist posting activity. `date` is the UTC date " +
      "portion in ISO 8601 short form (YYYY-MM-DD). `count` includes only " +
      "posts the viewer is permitted to see (Idea 032).",
    fields: (t) => ({
      date: t.exposeString("date"),
      count: t.exposeInt("count"),
    }),
  });

/**
 * Resolve the viewer's authorization view of an artist's activity.
 *
 * Returns `null` when the viewer is forbidden from seeing any activity at
 * all (private artist + non-tuned-in, or Layer-0 hidden author). Returns
 * `{ baseConditions }` — an array of `SQL` predicates already including the
 * visibility gate when applicable — otherwise. Callers spread it into
 * `and(...)` alongside their own conditions, avoiding `and(undefined)`
 * (Drizzle implementation detail). Same authorization chain as
 * `recentPosts`.
 *
 * Cached per-request on `ctx.activityAccessCache` so the two activity
 * fields don't double the auth round-trips on the same artist. Cache
 * stores `null` for denials so a second field on the same artist doesn't
 * re-prove access.
 */
async function resolveActivityAccess(
  artist: { id: string; userId: string },
  ctx: GraphQLContext,
): Promise<{ baseConditions: SQL[] } | null> {
  ctx.activityAccessCache ??= new Map();
  const cacheKey = `${artist.id}:${ctx.authUser?.userId ?? "anon"}`;
  const cached = ctx.activityAccessCache.get(cacheKey);
  if (cached !== undefined) return cached;

  const access = await checkArtistAccess(artist.id, ctx.authUser);
  if (!access.accessible) {
    ctx.activityAccessCache.set(cacheKey, null);
    return null;
  }

  // Layer 0: hide child / non-public-user authors from non-self viewers.
  // checkArtistAccess only inspects `artists.profileVisibility` (Layer 1)
  // so an explicit users-row lookup is required here.
  const [author] = await db
    .select({
      userId: users.id,
      guardianId: users.guardianId,
      profileVisibility: users.profileVisibility,
    })
    .from(users)
    .where(eq(users.id, artist.userId))
    .limit(1);
  if (
    !author ||
    !isAuthorVisibleToViewer(author, ctx.authUser?.userId ?? null)
  ) {
    ctx.activityAccessCache.set(cacheKey, null);
    return null;
  }

  const baseConditions: SQL[] = [eq(posts.authorId, artist.userId)];
  if (!access.isSelf) {
    baseConditions.push(eq(posts.visibility, "public"));
  }
  const result = { baseConditions };
  ctx.activityAccessCache.set(cacheKey, result);
  return result;
}

builder.objectFields(ArtistType, (t) => ({
  activitySeries: t.field({
    type: [ActivityDayType],
    description:
      "Daily post counts for the activity heatmap (Idea 032). Returns " +
      "only days with at least one matching post, from the later of " +
      "`artist.createdAt` or `days` days ago to today. `days` defaults " +
      "to 365 (the heatmap window) and clamps to [1, 365] — the smaller " +
      "value is for surfaces that only need a short recent window " +
      "(e.g. Discover sparkline at 14 days).",
    args: { days: t.arg.int() },
    resolve: async (artist, args, ctx) => {
      const access = await resolveActivityAccess(artist, ctx);
      if (!access) return [];

      // Clamp to [1, 365] — protects against DoS-by-huge-window if a
      // future caller misuses the arg, and against zero / negative
      // values that would invert the WHERE clause.
      const days = Math.max(
        1,
        Math.min(args.days ?? ACTIVITY_PERIOD_DAYS, ACTIVITY_PERIOD_DAYS),
      );
      const horizon = new Date(Date.now() - days * MS_PER_DAY);
      const fromDate =
        artist.createdAt.getTime() > horizon.getTime()
          ? artist.createdAt
          : horizon;

      // Bucket key is reused across SELECT / GROUP BY / ORDER BY — define
      // once as a SELECT alias to keep the three call sites in sync
      // (tune-in.ts MAX(updatedAt) pattern).
      const bucketExpr = sql<string>`to_char((${posts.createdAt} AT TIME ZONE 'UTC')::date, 'YYYY-MM-DD')`;
      const rows = await db
        .select({
          date: bucketExpr.as("activity_date"),
          count: sql<number>`count(*)::int`,
        })
        .from(posts)
        .where(
          and(
            ...access.baseConditions,
            sql`${posts.trackId} IS NOT NULL`,
            gte(posts.createdAt, fromDate),
          ),
        )
        .groupBy(sql`activity_date`)
        .orderBy(sql`activity_date`);

      return rows;
    },
  }),

  lastPostedAt: t.string({
    nullable: true,
    description:
      "ISO 8601 timestamp of the most recent post visible to the viewer " +
      "(Idea 032). Drives the discover-card pulse beacon. Prefetched by " +
      "`discoverArtists` to avoid N+1; falls back to a per-artist query " +
      "on other Artist paths. Intentionally NOT clamped to the 365-day " +
      "heatmap window — the pulse should still surface artists who " +
      "posted >1y ago, even when the heatmap shows nothing.",
    resolve: async (artist, _args, ctx) => {
      // Run authorization first — even when `_lastPostedAt` is prefetched
      // — so any caller who attaches the prefetch field on a different
      // Artist path (e.g. a future TuneInType.artist that JOINs the same
      // aggregate) cannot bypass Layer 0/1 checks. The auth result is
      // cached per request, so this stays cheap when `activitySeries`
      // also queried.
      const access = await resolveActivityAccess(artist, ctx);
      if (!access) return null;

      // Discover prefetch path: `_lastPostedAt` is filtered inside the
      // outer query to public posts + non-null trackId + public author +
      // public artist. The same value is the right answer for non-self
      // and self viewers on Discover by design — the beacon should mean
      // the same thing to everyone, and drafts belong on the artist
      // page heatmap (where the fallback below + auth-side baseConditions
      // add the self exemption). `null` is a legitimate prefetch result,
      // so we check `undefined`.
      if (artist._lastPostedAt !== undefined) {
        return artist._lastPostedAt
          ? new Date(artist._lastPostedAt).toISOString()
          : null;
      }

      // Fallback path (artist / myArtist / featuredArtist / TuneInType.artist).
      // No 365-day clamp here — see field description. The
      // `posts_author_visibility_created_idx` covers most of the WHERE
      // clause; `trackId IS NOT NULL` still costs a heap fetch per
      // candidate row, which is bounded by posts-per-author. Issue #430
      // tracks switching to a partial index that drops the heap fetch.
      //
      // postgres.js does not auto-parse aggregate (MAX) results to Date;
      // keep the raw `string | null` and normalize via `new Date(...)`.
      const [row] = await db
        .select({
          lastPostedAt: sql<string | null>`MAX(${posts.createdAt})`,
        })
        .from(posts)
        .where(
          and(...access.baseConditions, sql`${posts.trackId} IS NOT NULL`),
        );

      return row?.lastPostedAt
        ? new Date(row.lastPostedAt).toISOString()
        : null;
    },
  }),
}));
