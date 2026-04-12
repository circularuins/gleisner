import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { constellations, artists, posts } from "../../db/schema/index.js";
import { and, eq, inArray } from "drizzle-orm";
import { PostType } from "./post.js";
import {
  findConstellationPostIds,
  findAllConstellations,
} from "../../utils/constellation-graph.js";

const ConstellationType = builder.objectRef<{
  id: string;
  name: string;
  artistId: string;
  anchorPostId: string;
  createdAt: Date;
}>("Constellation");

ConstellationType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    name: t.exposeString("name"),
    anchorPostId: t.exposeID("anchorPostId"),
    createdAt: t.string({
      resolve: (c) => c.createdAt.toISOString(),
    }),
  }),
});

builder.mutationFields((t) => ({
  nameConstellation: t.field({
    type: ConstellationType,
    args: {
      postId: t.arg.string({ required: true }),
      name: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const trimmedName = args.name.trim();
      if (trimmedName.length === 0 || trimmedName.length > 100) {
        throw new GraphQLError("Constellation name must be 1-100 characters");
      }

      // Verify the post exists and user owns it
      const [post] = await db
        .select({ id: posts.id, authorId: posts.authorId })
        .from(posts)
        .where(eq(posts.id, args.postId))
        .limit(1);
      if (!post || post.authorId !== ctx.authUser.userId) {
        throw new GraphQLError("Post not found");
      }

      // Get artist
      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      if (!artist) {
        throw new GraphQLError("Artist profile required");
      }

      // Find all posts in this constellation via BFS
      const memberIds = await findConstellationPostIds(args.postId);
      const memberArray = Array.from(memberIds);

      // Transaction: check existing + create/update atomically
      return await db.transaction(async (tx) => {
        const existing = await tx
          .select()
          .from(constellations)
          .where(inArray(constellations.anchorPostId, memberArray))
          .limit(2);

        if (existing.length > 0) {
          const owned = existing
            .filter((c) => c.artistId === artist.id)
            .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
          if (owned.length > 0) {
            const [updated] = await tx
              .update(constellations)
              .set({ name: trimmedName })
              .where(eq(constellations.id, owned[0].id))
              .returning();
            return updated;
          }
        }

        // Create new constellation. The anchor is args.postId, which is
        // verified above as owned by the authenticated user. BFS members
        // may include other artists' posts (via cross-artist connections),
        // but the constellation is owned by the anchor's artist.
        try {
          const [created] = await tx
            .insert(constellations)
            .values({
              name: trimmedName,
              artistId: artist.id,
              anchorPostId: args.postId,
            })
            .returning();
          return created;
        } catch {
          throw new GraphQLError("Failed to create constellation");
        }
      });
    },
  }),

  renameConstellation: t.field({
    type: ConstellationType,
    args: {
      id: t.arg.string({ required: true }),
      name: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const trimmedName = args.name.trim();
      if (trimmedName.length === 0 || trimmedName.length > 100) {
        throw new GraphQLError("Constellation name must be 1-100 characters");
      }

      // Verify ownership via artist
      const [constellation] = await db
        .select()
        .from(constellations)
        .where(eq(constellations.id, args.id))
        .limit(1);
      if (!constellation) {
        throw new GraphQLError("Constellation not found");
      }

      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      if (!artist || artist.id !== constellation.artistId) {
        throw new GraphQLError("Constellation not found");
      }

      const [updated] = await db
        .update(constellations)
        .set({ name: trimmedName })
        .where(eq(constellations.id, args.id))
        .returning();
      return updated;
    },
  }),

  deleteConstellation: t.field({
    type: "Boolean",
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Auth + existence check in a single JOIN query
      const [result] = await db
        .select({ constellationId: constellations.id })
        .from(constellations)
        .innerJoin(artists, eq(constellations.artistId, artists.id))
        .where(
          and(
            eq(constellations.id, args.id),
            eq(artists.userId, ctx.authUser.userId),
          ),
        )
        .limit(1);

      if (!result) {
        throw new GraphQLError("Constellation not found or not authorized");
      }

      await db.delete(constellations).where(eq(constellations.id, args.id));
      return true;
    },
  }),
}));

// Per-request cache for constellation lookups (avoids N+1).
// Uses a Promise guard to prevent duplicate DB fetches when resolvers
// run in parallel within the same GraphQL request.
async function ensureConstellationCache(
  ctx: import("../builder.js").GraphQLContext,
) {
  if (!ctx.constellationCachePromise) {
    ctx.constellationCachePromise = (async () => {
      ctx.constellationCache = new Map();

      const allConstellationRows = await db
        .select()
        .from(constellations)
        .orderBy(constellations.createdAt);
      if (allConstellationRows.length > 0) {
        const anchorIds = allConstellationRows.map((c) => c.anchorPostId);
        const componentMap = await findAllConstellations(anchorIds);

        for (const row of allConstellationRows) {
          const component = componentMap.get(row.anchorPostId);
          if (component) {
            for (const memberId of component) {
              if (!ctx.constellationCache!.has(memberId)) {
                ctx.constellationCache!.set(memberId, row);
              }
            }
          }
        }
      }
    })();
  }
  await ctx.constellationCachePromise;
}

// Public field: constellation topology is non-sensitive.
// artistId is not exposed in ConstellationType.
builder.objectFields(PostType, (t) => ({
  constellation: t.field({
    type: ConstellationType,
    nullable: true,
    resolve: async (post, _args, ctx) => {
      await ensureConstellationCache(ctx);
      return ctx.constellationCache?.get(post.id) ?? null;
    },
  }),
}));
