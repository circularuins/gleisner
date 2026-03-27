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
