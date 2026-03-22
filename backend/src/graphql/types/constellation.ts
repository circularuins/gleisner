import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { constellations, artists, posts } from "../../db/schema/index.js";
import { eq, inArray } from "drizzle-orm";
import { PostType } from "./post.js";
import { findConstellationPostIds } from "../../utils/constellation-graph.js";

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

      // Check if any member is already an anchor of a named constellation
      const memberArray = Array.from(memberIds);
      const existing = await db
        .select()
        .from(constellations)
        .where(inArray(constellations.anchorPostId, memberArray))
        .limit(2);

      if (existing.length > 0) {
        // Update the oldest existing constellation's name
        const oldest = existing.sort(
          (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
        )[0];
        const [updated] = await db
          .update(constellations)
          .set({ name: trimmedName })
          .where(eq(constellations.id, oldest.id))
          .returning();
        return updated;
      }

      // Create new constellation with this post as anchor
      try {
        const [created] = await db
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
}));

// Add constellation field to PostType
builder.objectFields(PostType, (t) => ({
  constellation: t.field({
    type: ConstellationType,
    nullable: true,
    resolve: async (post) => {
      // Find the constellation this post belongs to by BFS + anchor lookup
      const memberIds = await findConstellationPostIds(post.id);
      const memberArray = Array.from(memberIds);

      const [found] = await db
        .select()
        .from(constellations)
        .where(inArray(constellations.anchorPostId, memberArray))
        .limit(1);

      return found ?? null;
    },
  }),
}));
