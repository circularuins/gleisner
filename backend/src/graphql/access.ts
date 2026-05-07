import { db } from "../db/index.js";
import { artists, tuneIns } from "../db/schema/index.js";
import { and, eq } from "drizzle-orm";
import type { GraphQLContext } from "./builder.js";

/**
 * Check if an artist is accessible to the current user.
 * Returns { accessible: true, isSelf } if allowed, { accessible: false } otherwise.
 * Public artists are always accessible. Private artists require self or tuned-in.
 */
export async function checkArtistAccess(
  artistId: string,
  authUser: GraphQLContext["authUser"],
): Promise<{ accessible: true; isSelf: boolean } | { accessible: false }> {
  const [artist] = await db
    .select({
      profileVisibility: artists.profileVisibility,
      userId: artists.userId,
    })
    .from(artists)
    .where(eq(artists.id, artistId))
    .limit(1);
  if (!artist) return { accessible: false };

  const isSelf = !!(authUser && artist.userId === authUser.userId);

  if (artist.profileVisibility === "public") {
    return { accessible: true, isSelf };
  }

  // Private: self always has access
  if (isSelf) return { accessible: true, isSelf };

  // Private: check tuned-in
  if (authUser) {
    const [tunedIn] = await db
      .select()
      .from(tuneIns)
      .where(
        and(
          eq(tuneIns.userId, authUser.userId),
          eq(tuneIns.artistId, artistId),
        ),
      )
      .limit(1);
    if (tunedIn) return { accessible: true, isSelf: false };
  }

  return { accessible: false };
}

/**
 * Decide whether a post's author can be exposed to the viewer.
 *
 * Used to hide posts authored by child accounts (`guardianId !== null`) or by
 * users with non-public `users.profileVisibility` from third parties. Applied
 * in every post-returning resolver to keep the authorization filter uniform
 * (see `.claude/rules/backend-implementation.md` 「認可フィルタの全経路統一」).
 *
 * Note: `profileVisibility` here MUST refer to `users.profileVisibility`
 * (Layer 0 — human existence visibility, ADR 021), NOT
 * `artists.profileVisibility` (Layer 1 — artist persona visibility).
 *
 * - viewer is the author themselves → always visible
 * - author has a guardian (child account, ADR 019) → not visible
 * - author's profileVisibility is not "public" → not visible
 * - otherwise → visible
 */
export function isAuthorVisibleToViewer(
  author: {
    userId: string;
    guardianId: string | null;
    profileVisibility: string;
  },
  viewerUserId: string | null,
): boolean {
  if (viewerUserId !== null && viewerUserId === author.userId) return true;
  if (author.guardianId !== null) return false;
  if (author.profileVisibility !== "public") return false;
  return true;
}
