import SchemaBuilder from "@pothos/core";
import type { SQL } from "drizzle-orm";
import type { AuthUser } from "../auth/middleware.js";
import type { artists } from "../db/schema/index.js";
// `import type` erases at compile time, so this does not create a runtime
// import cycle with `./types/user.ts` (which imports from this file).
import type { PublicUserShape } from "./types/user.js";

/**
 * Drizzle-derived row shape for the `artists` table — kept in sync with
 * the schema automatically. Used as the cache value type below so a column
 * addition to `db/schema/artist.ts` does not silently drift from the
 * cache.
 */
type ArtistRow = typeof artists.$inferSelect;

export interface GraphQLContext {
  authUser?: AuthUser;
  /** Per-request cache for constellation lookups (avoids N+1). */
  constellationCache?: Map<
    string,
    {
      id: string;
      name: string;
      artistId: string;
      anchorPostId: string;
      createdAt: Date;
    } | null
  >;
  /** Promise guard to prevent parallel cache initialization. */
  constellationCachePromise?: Promise<void>;
  /**
   * Per-request cache for tune-in artist lookups. Populated by the
   * `myTuneIns` query (which JOINs `artists`) and read by the
   * `TuneInType.artist` field resolver to avoid a per-row SELECT against
   * the `artists` table.
   */
  tuneInArtistCache?: Map<string, ArtistRow>;
  /**
   * Per-request cache for tune-in follower lookups (avoids N+1 on
   * `TuneInType.user` when resolving the followers list of an artist).
   * Populated by the `tuneIns(artistId)` query and the `Artist.tuneIns`
   * field — both prefetch the user via JOIN and store the
   * `publicUserColumns` shape here.
   */
  tuneInUserCache?: Map<string, PublicUserShape>;
  /**
   * Per-request cache for `Artist.activitySeries` / `Artist.lastPostedAt`
   * authorization checks (Idea 032). Both fields run the same
   * `checkArtistAccess` + Layer-0 author lookup; without this cache, a
   * client querying both fields on N artists (where N = the number of
   * `Artist` rows resolved in the request, typically 1 for an artist
   * page or up to `discoverArtists.limit` for the Discover list) fires
   * 4N round-trips. Key is `${artistId}:${viewerUserId ?? "anon"}`.
   * Stores `null` for authorization denials so we don't re-prove them
   * on the second field.
   */
  activityAccessCache?: Map<string, { baseConditions: SQL[] } | null>;
}

export const builder = new SchemaBuilder<{
  Context: GraphQLContext;
  Scalars: {
    JSON: { Input: unknown; Output: unknown };
  };
}>({});
