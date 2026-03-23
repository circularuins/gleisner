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
}

export const builder = new SchemaBuilder<{ Context: GraphQLContext }>({});
