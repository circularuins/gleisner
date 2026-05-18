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
 * the `(isSelf, baseConditions)` pair otherwise — `baseConditions` is an
 * array of `SQL` predicates already including the visibility gate when
 * applicable. Callers spread it into `and(...)` alongside their own
 * conditions, avoiding the `and(undefined)` pattern (relies on a Drizzle
 * implementation detail and degrades gracefully but silently if it ever
 * changes). Same authorization chain as `recentPosts`.
 */
async function resolveActivityAccess(
  artistId: string,
  artistUserId: string,
  authUser: GraphQLContext["authUser"],
): Promise<{
  isSelf: boolean;
  baseConditions: SQL[];
} | null> {
  const access = await checkArtistAccess(artistId, authUser);
  if (!access.accessible) return null;

  // Layer 0: hide child / non-public-user authors from non-self viewers.
  // checkArtistAccess only inspects `artists.profileVisibility` (Layer 1) so
  // an explicit users-row lookup is required here.
  const [author] = await db
    .select({
      userId: users.id,
      guardianId: users.guardianId,
      profileVisibility: users.profileVisibility,
    })
    .from(users)
    .where(eq(users.id, artistUserId))
    .limit(1);
  if (!author) return null;
  if (!isAuthorVisibleToViewer(author, authUser?.userId ?? null)) return null;

  const baseConditions: SQL[] = [eq(posts.authorId, artistUserId)];
  if (!access.isSelf) {
    baseConditions.push(eq(posts.visibility, "public"));
  }
  return { isSelf: access.isSelf, baseConditions };
}

builder.objectFields(ArtistType, (t) => ({
  activitySeries: t.field({
    type: [ActivityDayType],
    description:
      "Daily post counts for the activity heatmap (Idea 032). Returns " +
      "only days with at least one matching post, from the later of " +
      "`artist.createdAt` or 365 days ago to today.",
    resolve: async (artist, _args, ctx) => {
      const access = await resolveActivityAccess(
        artist.id,
        artist.userId,
        ctx.authUser,
      );
      if (!access) return [];

      const horizon = new Date(Date.now() - ACTIVITY_PERIOD_DAYS * 86_400_000);
      const fromDate =
        artist.createdAt.getTime() > horizon.getTime()
          ? artist.createdAt
          : horizon;

      // Bucket key is reused in SELECT / GROUP BY / ORDER BY — define once
      // as a SELECT alias and reference the alias to avoid silent drift if
      // the expression ever changes (matches tune-in.ts MAX(updatedAt)
      // alias pattern).
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
      // Discover prefetch path: `_lastPostedAt` is already filtered to
      // public posts + non-null trackId + public author + public artist.
      // Even when the viewer is the artist owner, the discover surface
      // clamps the pulse to public posts on purpose — the beacon should
      // mean the same thing to everyone, and drafts belong on the artist
      // page heatmap (where `resolveActivityAccess` adds the self
      // exemption). `null` is a legitimate prefetch result (no matching
      // posts), so we check for `undefined` rather than truthy.
      if (artist._lastPostedAt !== undefined) {
        return artist._lastPostedAt
          ? new Date(artist._lastPostedAt).toISOString()
          : null;
      }

      const access = await resolveActivityAccess(
        artist.id,
        artist.userId,
        ctx.authUser,
      );
      if (!access) return null;

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
