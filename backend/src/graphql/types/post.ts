import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, posts, tracks, users } from "../../db/schema/index.js";
import { eq } from "drizzle-orm";
import { TrackType } from "./track.js";
import { PublicUserType, publicUserColumns } from "./user.js";
import { computeContentHash, verifySignature } from "../../auth/signing.js";

const MediaTypeEnum = builder.enumType("MediaType", {
  values: ["text", "image", "video", "audio", "link"] as const,
});

/**
 * Fetch author's publicKey and verify an Ed25519 signature against a contentHash.
 * Throws GraphQLError on missing key, empty key, or invalid signature.
 */
async function verifyPostSignature(
  contentHash: string,
  signature: string,
  userId: string,
): Promise<void> {
  const [author] = await db
    .select({ publicKey: users.publicKey })
    .from(users)
    .where(eq(users.id, userId))
    .limit(1);
  if (!author || !author.publicKey) {
    throw new GraphQLError("Author has no registered public key");
  }
  if (!verifySignature(contentHash, signature, author.publicKey)) {
    throw new GraphQLError("Invalid signature");
  }
}

export const PostType = builder.objectRef<{
  id: string;
  trackId: string;
  authorId: string;
  mediaType: "text" | "image" | "video" | "audio" | "link";
  title: string | null;
  body: string | null;
  mediaUrl: string | null;
  importance: number;
  contentHash: string | null;
  signature: string | null;
  layoutX: number;
  layoutY: number;
  createdAt: Date;
  updatedAt: Date;
}>("Post");

PostType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    mediaType: t.field({
      type: MediaTypeEnum,
      resolve: (post) => post.mediaType,
    }),
    title: t.exposeString("title", { nullable: true }),
    body: t.exposeString("body", { nullable: true }),
    mediaUrl: t.exposeString("mediaUrl", { nullable: true }),
    importance: t.exposeFloat("importance"),
    contentHash: t.exposeString("contentHash", { nullable: true }),
    signature: t.exposeString("signature", { nullable: true }),
    layoutX: t.exposeInt("layoutX"),
    layoutY: t.exposeInt("layoutY"),
    createdAt: t.string({
      resolve: (post) => post.createdAt.toISOString(),
    }),
    updatedAt: t.string({
      resolve: (post) => post.updatedAt.toISOString(),
    }),
    author: t.field({
      type: PublicUserType,
      resolve: async (post) => {
        const [user] = await db
          .select(publicUserColumns)
          .from(users)
          .where(eq(users.id, post.authorId))
          .limit(1);
        if (!user) throw new GraphQLError("User not found");
        return user;
      },
    }),
    track: t.field({
      type: TrackType,
      resolve: async (post) => {
        const [track] = await db
          .select()
          .from(tracks)
          .where(eq(tracks.id, post.trackId))
          .limit(1);
        return track;
      },
    }),
  }),
});

builder.mutationFields((t) => ({
  createPost: t.field({
    type: PostType,
    args: {
      trackId: t.arg.string({ required: true }),
      mediaType: t.arg({ type: MediaTypeEnum, required: true }),
      title: t.arg.string(),
      body: t.arg.string(),
      mediaUrl: t.arg.string(),
      importance: t.arg.float(),
      layoutX: t.arg.int(),
      layoutY: t.arg.int(),
      signature: t.arg.string(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Find artist for this user
      const [artist] = await db
        .select({ id: artists.id })
        .from(artists)
        .where(eq(artists.userId, ctx.authUser.userId))
        .limit(1);
      if (!artist) {
        throw new GraphQLError("Artist profile required to create a post");
      }

      // Fetch the track and verify ownership
      const [track] = await db
        .select({ id: tracks.id, artistId: tracks.artistId })
        .from(tracks)
        .where(eq(tracks.id, args.trackId))
        .limit(1);
      if (!track) {
        throw new GraphQLError("Track not found");
      }
      if (track.artistId !== artist.id) {
        throw new GraphQLError("Not authorized to post to this track");
      }

      // Validate title
      if (args.title != null && args.title.length > 100) {
        throw new GraphQLError("Title must be 100 characters or less");
      }

      // Validate importance
      if (
        args.importance != null &&
        (args.importance < 0.0 || args.importance > 1.0)
      ) {
        throw new GraphQLError("Importance must be between 0.0 and 1.0");
      }

      // contentHash is always computed, even without a signature, to enable:
      // 1. Content integrity checks (detect DB-level corruption or bugs)
      // 2. Future signature addition without re-processing existing posts
      const contentHash = computeContentHash({
        title: args.title ?? null,
        body: args.body ?? null,
        mediaUrl: args.mediaUrl ?? null,
        importance: args.importance ?? 0.5,
      });

      // Signature is optional for MVP: clients that support Ed25519 signing
      // send it for tamper-detection; unsigned posts are stored with signature=null.
      let signatureValue: string | null = null;
      if (args.signature) {
        await verifyPostSignature(
          contentHash,
          args.signature,
          ctx.authUser.userId,
        );
        signatureValue = args.signature;
      }

      const [post] = await db
        .insert(posts)
        .values({
          trackId: args.trackId,
          authorId: ctx.authUser.userId,
          mediaType: args.mediaType,
          title: args.title ?? null,
          body: args.body ?? null,
          mediaUrl: args.mediaUrl ?? null,
          contentHash,
          signature: signatureValue,
          ...(args.importance != null ? { importance: args.importance } : {}),
          ...(args.layoutX != null ? { layoutX: args.layoutX } : {}),
          ...(args.layoutY != null ? { layoutY: args.layoutY } : {}),
        })
        .returning();

      return post;
    },
  }),

  updatePost: t.field({
    type: PostType,
    args: {
      id: t.arg.string({ required: true }),
      mediaType: t.arg({ type: MediaTypeEnum }),
      title: t.arg.string(),
      body: t.arg.string(),
      mediaUrl: t.arg.string(),
      importance: t.arg.float(),
      layoutX: t.arg.int(),
      layoutY: t.arg.int(),
      signature: t.arg.string(),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const [post] = await db
        .select()
        .from(posts)
        .where(eq(posts.id, args.id))
        .limit(1);
      if (!post) {
        throw new GraphQLError("Post not found");
      }

      if (post.authorId !== ctx.authUser.userId) {
        throw new GraphQLError("Not authorized to update this post");
      }

      // Validate title
      if (args.title != null && args.title.length > 100) {
        throw new GraphQLError("Title must be 100 characters or less");
      }

      // Validate importance
      if (
        args.importance != null &&
        (args.importance < 0.0 || args.importance > 1.0)
      ) {
        throw new GraphQLError("Importance must be between 0.0 and 1.0");
      }

      const updateData: Record<string, unknown> = { updatedAt: new Date() };
      if (args.mediaType !== undefined) updateData.mediaType = args.mediaType;
      if (args.title !== undefined) updateData.title = args.title;
      if (args.body !== undefined) updateData.body = args.body;
      if (args.mediaUrl !== undefined) updateData.mediaUrl = args.mediaUrl;
      if (args.importance !== undefined)
        updateData.importance = args.importance;
      if (args.layoutX !== undefined) updateData.layoutX = args.layoutX;
      if (args.layoutY !== undefined) updateData.layoutY = args.layoutY;

      // Recompute contentHash if content fields changed
      const contentChanged =
        args.title !== undefined ||
        args.body !== undefined ||
        args.mediaUrl !== undefined ||
        args.importance !== undefined;

      if (!contentChanged && args.signature !== undefined) {
        throw new GraphQLError(
          "Signature can only be updated when content fields are changed.",
        );
      }

      // Recompute contentHash and re-verify signature when content changes.
      // Signature is optional for MVP (see createPost comment).
      if (contentChanged) {
        // Signed posts require a new signature when content changes,
        // preventing silent removal of tamper-detection.
        if (post.signature !== null && !args.signature) {
          throw new GraphQLError(
            "This post was signed. A new signature is required when updating content.",
          );
        }

        const newHash = computeContentHash({
          title: args.title !== undefined ? args.title : post.title,
          body: args.body !== undefined ? args.body : post.body,
          mediaUrl: args.mediaUrl !== undefined ? args.mediaUrl : post.mediaUrl,
          importance:
            args.importance != null ? args.importance : post.importance,
        });

        // Verify signature before committing any hash/signature to updateData
        let newSignature: string | null = null;
        if (args.signature) {
          await verifyPostSignature(
            newHash,
            args.signature,
            ctx.authUser.userId,
          );
          newSignature = args.signature;
        }

        updateData.contentHash = newHash;
        updateData.signature = newSignature;
      }

      const [updated] = await db
        .update(posts)
        .set(updateData)
        .where(eq(posts.id, args.id))
        .returning();

      return updated;
    },
  }),

  deletePost: t.field({
    type: PostType,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const [post] = await db
        .select()
        .from(posts)
        .where(eq(posts.id, args.id))
        .limit(1);
      if (!post) {
        throw new GraphQLError("Post not found");
      }

      if (post.authorId !== ctx.authUser.userId) {
        throw new GraphQLError("Not authorized to delete this post");
      }

      const [deleted] = await db
        .delete(posts)
        .where(eq(posts.id, args.id))
        .returning();

      return deleted;
    },
  }),
}));

builder.queryFields((t) => ({
  post: t.field({
    type: PostType,
    nullable: true,
    args: {
      id: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      const [post] = await db
        .select()
        .from(posts)
        .where(eq(posts.id, args.id))
        .limit(1);
      return post ?? null;
    },
  }),

  posts: t.field({
    type: [PostType],
    args: {
      trackId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args) => {
      return db.select().from(posts).where(eq(posts.trackId, args.trackId));
    },
  }),
}));

// Add posts field to TrackType (avoids circular import by extending here)
builder.objectFields(TrackType, (t) => ({
  posts: t.field({
    type: [PostType],
    resolve: async (track) => {
      return db.select().from(posts).where(eq(posts.trackId, track.id));
    },
  }),
}));
