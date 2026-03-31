import SchemaBuilder from "@pothos/core";
import type { AuthUser } from "../auth/middleware.js";

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
  /** Per-request cache for tune-in artist lookups (avoids N+1 in myTuneIns). */
  tuneInArtistCache?: Map<
    string,
    {
      id: string;
      userId: string;
      artistUsername: string;
      displayName: string | null;
      bio: string | null;
      tagline: string | null;
      location: string | null;
      activeSince: number | null;
      avatarUrl: string | null;
      coverImageUrl: string | null;
      profileVisibility: string;
      tunedInCount: number;
      createdAt: Date;
      updatedAt: Date;
    }
  >;
}

export const builder = new SchemaBuilder<{
  Context: GraphQLContext;
  Scalars: {
    JSON: { Input: unknown; Output: unknown };
  };
}>({});
