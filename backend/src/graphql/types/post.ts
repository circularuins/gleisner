import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import { artists, posts, tracks, users } from "../../db/schema/index.js";
import { and, desc, eq, isNull, sql } from "drizzle-orm";
import { ArtistType } from "./artist.js";
import { TrackType } from "./track.js";
import { PublicUserType, publicUserColumns } from "./user.js";
import { computeContentHash, verifySignature } from "../../auth/signing.js";
import {
  validatePostVisibility,
  validateMediaUrl,
  validateUrl,
} from "../validators.js";
import { checkArtistAccess } from "../access.js";

/** Media types that require a file upload (mediaUrl must be non-null). */
const MEDIA_FILE_REQUIRED_TYPES = ["image", "video", "audio"];

const MediaTypeEnum = builder.enumType("MediaType", {
  values: ["text", "image", "video", "audio", "link"] as const,
});

/**
 * Fetch author's publicKey and verify an Ed25519 signature against a contentHash.
 * Ensures the signer is the post's author to prevent signature spoofing.
 * Throws GraphQLError on author mismatch, missing key, or invalid signature.
 */
async function verifyPostSignature(
  contentHash: string,
  signature: string,
  signerId: string,
  postAuthorId: string,
): Promise<void> {
  if (signerId !== postAuthorId) {
    throw new GraphQLError("Only the post author can sign this post");
  }
  // Ed25519 signatures are 64 bytes = 88 chars in base64
  if (signature.length !== 88) {
    throw new GraphQLError("Invalid signature format");
  }
  const [author] = await db
    .select({ publicKey: users.publicKey })
    .from(users)
    .where(eq(users.id, signerId))
    .limit(1);
  if (!author || !author.publicKey) {
    throw new GraphQLError("Author has no registered public key");
  }
  if (!verifySignature(contentHash, signature, author.publicKey)) {
    throw new GraphQLError("Invalid signature");
  }
}

type PostShape = {
  id: string;
  trackId: string | null;
  authorId: string;
  mediaType: "text" | "image" | "video" | "audio" | "link";
  title: string | null;
  body: unknown; // jsonb: string (plain) or Delta ops array (delta)
  bodyFormat: string;
  mediaUrl: string | null;
  thumbnailUrl: string | null;
  duration: number | null;
  importance: number;
  visibility: string;
  contentHash: string | null;
  signature: string | null;
  eventAt: Date | null;
  layoutX: number;
  layoutY: number;
  createdAt: Date;
  updatedAt: Date;
  _track?: {
    id: string;
    name: string;
    color: string;
    artistId: string;
    createdAt: Date;
    updatedAt: Date;
  } | null;
};

export const PostType = builder.objectRef<PostShape>("Post");

PostType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    mediaType: t.field({
      type: MediaTypeEnum,
      resolve: (post) => post.mediaType,
    }),
    title: t.exposeString("title", { nullable: true }),
    body: t.string({
      nullable: true,
      resolve: (post) => {
        if (post.body == null) return null;
        // Delta format: serialize JSON to string for client
        if (post.bodyFormat === "delta") return JSON.stringify(post.body);
        // Plain format: return as-is (string)
        return typeof post.body === "string" ? post.body : null;
      },
    }),
    bodyFormat: t.exposeString("bodyFormat"),
    mediaUrl: t.exposeString("mediaUrl", { nullable: true }),
    thumbnailUrl: t.exposeString("thumbnailUrl", { nullable: true }),
    duration: t.exposeInt("duration", { nullable: true }),
    importance: t.exposeFloat("importance"),
    visibility: t.exposeString("visibility"),
    contentHash: t.exposeString("contentHash", { nullable: true }),
    signature: t.exposeString("signature", { nullable: true }),
    eventAt: t.string({
      nullable: true,
      resolve: (post) => post.eventAt?.toISOString() ?? null,
    }),
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
      nullable: true,
      resolve: async (post) => {
        // Use pre-fetched track from JOIN if available (N+1 prevention)
        if (post._track) return post._track;
        if (!post.trackId) return null;
        const [track] = await db
          .select()
          .from(tracks)
          .where(eq(tracks.id, post.trackId))
          .limit(1);
        return track ?? null;
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
      bodyFormat: t.arg.string(), // 'plain' (default) or 'delta'
      mediaUrl: t.arg.string(),
      thumbnailUrl: t.arg.string(),
      duration: t.arg.int(),
      importance: t.arg.float(),
      visibility: t.arg.string(),
      eventAt: t.arg.string(),
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

      // Validate body + bodyFormat
      const bodyFormat = args.bodyFormat ?? "plain";
      if (bodyFormat !== "plain" && bodyFormat !== "delta") {
        throw new GraphQLError("bodyFormat must be 'plain' or 'delta'");
      }

      let bodyValue: unknown = null;
      if (args.body != null) {
        if (bodyFormat === "delta") {
          // Size check before parse to prevent DoS via large payload
          if (args.body.length > 102400) {
            throw new GraphQLError("Body must be 100KB or less");
          }
          // Parse and validate Delta JSON
          let ops: unknown[];
          try {
            ops = JSON.parse(args.body);
          } catch {
            throw new GraphQLError("Invalid Delta JSON");
          }
          if (!Array.isArray(ops)) {
            throw new GraphQLError("Delta must be a JSON array");
          }
          if (ops.length > 10000) {
            throw new GraphQLError("Delta ops limit exceeded");
          }
          // Validate image URLs in embeds
          for (const op of ops) {
            if (
              typeof op === "object" &&
              op !== null &&
              "insert" in op &&
              typeof (op as Record<string, unknown>).insert === "object"
            ) {
              const embed = (op as Record<string, unknown>).insert as Record<
                string,
                unknown
              >;
              if (typeof embed.image === "string") {
                validateMediaUrl(embed.image);
              }
            }
          }
          bodyValue = ops;
        } else {
          if (args.body.length > 10000) {
            throw new GraphQLError("Body must be 10000 characters or less");
          }
          bodyValue = args.body;
        }
      }

      // Require mediaUrl for image, video, audio types (not text or link)
      const mediaFileTypes = MEDIA_FILE_REQUIRED_TYPES;
      if (
        mediaFileTypes.includes(args.mediaType) &&
        (args.mediaUrl == null || args.mediaUrl.trim() === "")
      ) {
        throw new GraphQLError("Media file is required for this post type");
      }

      // Validate mediaUrl: link type accepts any URL, others require R2 domain
      if (args.mediaUrl != null) {
        if (args.mediaType === "link") {
          validateUrl(args.mediaUrl);
        } else {
          validateMediaUrl(args.mediaUrl);
        }
      }
      if (args.thumbnailUrl != null) {
        validateMediaUrl(args.thumbnailUrl);
      }

      // Validate duration
      if (
        args.duration != null &&
        (args.duration < 0 || args.duration > 86400)
      ) {
        throw new GraphQLError("Duration must be between 0 and 86400 seconds");
      }

      // Validate importance
      if (
        args.importance != null &&
        (args.importance < 0.0 || args.importance > 1.0)
      ) {
        throw new GraphQLError("Importance must be between 0.0 and 1.0");
      }

      // Validate visibility
      if (args.visibility != null) validatePostVisibility(args.visibility);

      // contentHash is always computed, even without a signature, to enable:
      // 1. Content integrity checks (detect DB-level corruption or bugs)
      // 2. Future signature addition without re-processing existing posts
      const contentHash = computeContentHash({
        title: args.title ?? null,
        body: bodyValue,
        bodyFormat,
        mediaUrl: args.mediaUrl ?? null,
        mediaType: args.mediaType,
        importance: args.importance ?? 0.5,
        duration: args.duration ?? null,
      });

      // Signature is optional for MVP: clients that support Ed25519 signing
      // send it for tamper-detection; unsigned posts are stored with signature=null.
      let signatureValue: string | null = null;
      if (args.signature && args.signature.length > 0) {
        await verifyPostSignature(
          contentHash,
          args.signature,
          ctx.authUser.userId,
          ctx.authUser.userId, // createPost: author is always the current user
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
          body: bodyValue,
          bodyFormat,
          mediaUrl: args.mediaUrl ?? null,
          thumbnailUrl: args.thumbnailUrl ?? null,
          duration: args.duration ?? null,
          ...(args.eventAt != null && args.eventAt !== ""
            ? (() => {
                const parsed = new Date(args.eventAt as string);
                if (isNaN(parsed.getTime())) {
                  throw new GraphQLError("Invalid eventAt: not a valid date");
                }
                return { eventAt: parsed };
              })()
            : {}),
          contentHash,
          signature: signatureValue,
          ...(args.visibility != null ? { visibility: args.visibility } : {}),
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
      trackId: t.arg.string(),
      mediaType: t.arg({ type: MediaTypeEnum }),
      title: t.arg.string(),
      body: t.arg.string(),
      bodyFormat: t.arg.string(),
      mediaUrl: t.arg.string(),
      thumbnailUrl: t.arg.string(),
      duration: t.arg.int(),
      importance: t.arg.float(),
      visibility: t.arg.string(),
      eventAt: t.arg.string(),
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

      // Validate body + bodyFormat
      let updateBodyValue: unknown | undefined;
      let updateBodyFormat: string | undefined;
      if (args.body !== undefined || args.bodyFormat !== undefined) {
        const effectiveFormat = args.bodyFormat ?? post.bodyFormat ?? "plain";
        if (effectiveFormat !== "plain" && effectiveFormat !== "delta") {
          throw new GraphQLError("bodyFormat must be 'plain' or 'delta'");
        }
        // Changing bodyFormat without body would leave DB in inconsistent state
        if (
          args.bodyFormat !== undefined &&
          args.bodyFormat !== (post.bodyFormat ?? "plain") &&
          args.body === undefined
        ) {
          throw new GraphQLError(
            "body must be provided when changing bodyFormat",
          );
        }
        if (args.body !== undefined) {
          if (args.body != null) {
            if (effectiveFormat === "delta") {
              if (args.body.length > 102400) {
                throw new GraphQLError("Body must be 100KB or less");
              }
              let ops: unknown[];
              try {
                ops = JSON.parse(args.body);
              } catch {
                throw new GraphQLError("Invalid Delta JSON");
              }
              if (!Array.isArray(ops)) {
                throw new GraphQLError("Delta must be a JSON array");
              }
              if (ops.length > 10000) {
                throw new GraphQLError("Delta ops limit exceeded");
              }
              for (const op of ops) {
                if (
                  typeof op === "object" &&
                  op !== null &&
                  "insert" in op &&
                  typeof (op as Record<string, unknown>).insert === "object"
                ) {
                  const embed = (op as Record<string, unknown>)
                    .insert as Record<string, unknown>;
                  if (typeof embed.image === "string") {
                    validateMediaUrl(embed.image);
                  }
                }
              }
              updateBodyValue = ops;
            } else {
              if (args.body.length > 10000) {
                throw new GraphQLError(
                  "Body must be 10000 characters or less",
                );
              }
              updateBodyValue = args.body;
            }
          } else {
            updateBodyValue = null; // explicit clear
          }
        }
        // Only update bodyFormat if explicitly sent
        if (args.bodyFormat !== undefined) {
          updateBodyFormat = effectiveFormat;
        }
      }

      // Validate mediaUrl: link type accepts any URL, others require R2 domain.
      // Use effective media type (args override, fallback to existing post).
      if (args.mediaUrl != null) {
        const effectiveType =
          (args.mediaType as string | undefined) ?? post.mediaType;
        if (effectiveType === "link") {
          validateUrl(args.mediaUrl);
        } else {
          validateMediaUrl(args.mediaUrl);
        }
      }
      if (args.thumbnailUrl != null) {
        validateMediaUrl(args.thumbnailUrl);
      }

      // Ensure image/video/audio posts always have a media file.
      // Check both explicit mediaUrl changes and mediaType changes.
      {
        const newType =
          (args.mediaType as string | undefined) ?? post.mediaType;
        const newMediaUrl =
          args.mediaUrl !== undefined ? args.mediaUrl : post.mediaUrl;
        const mediaFileTypes = MEDIA_FILE_REQUIRED_TYPES;
        if (
          mediaFileTypes.includes(newType) &&
          (newMediaUrl == null || newMediaUrl.trim() === "")
        ) {
          throw new GraphQLError("Media file is required for this post type");
        }
      }

      // Validate duration
      if (
        args.duration != null &&
        (args.duration < 0 || args.duration > 86400)
      ) {
        throw new GraphQLError("Duration must be between 0 and 86400 seconds");
      }

      // Validate importance
      if (
        args.importance != null &&
        (args.importance < 0.0 || args.importance > 1.0)
      ) {
        throw new GraphQLError("Importance must be between 0.0 and 1.0");
      }

      // Validate visibility
      if (args.visibility != null) validatePostVisibility(args.visibility);

      // Validate trackId — must belong to the author's artist profile
      if (args.trackId != null) {
        const [track] = await db
          .select({ id: tracks.id, artistId: tracks.artistId })
          .from(tracks)
          .where(eq(tracks.id, args.trackId))
          .limit(1);
        if (!track) {
          throw new GraphQLError("Track not found");
        }
        const [myArtist] = await db
          .select({ id: artists.id })
          .from(artists)
          .where(eq(artists.userId, ctx.authUser.userId))
          .limit(1);
        if (!myArtist || track.artistId !== myArtist.id) {
          throw new GraphQLError("Not authorized to move post to this track");
        }
      }

      const updateData: Record<string, unknown> = { updatedAt: new Date() };
      if (args.trackId !== undefined) updateData.trackId = args.trackId;
      if (args.mediaType !== undefined) updateData.mediaType = args.mediaType;
      if (args.title !== undefined) updateData.title = args.title;
      if (updateBodyValue !== undefined) updateData.body = updateBodyValue;
      if (updateBodyFormat !== undefined)
        updateData.bodyFormat = updateBodyFormat;
      if (args.mediaUrl !== undefined) updateData.mediaUrl = args.mediaUrl;
      if (args.thumbnailUrl !== undefined)
        updateData.thumbnailUrl = args.thumbnailUrl;
      if (args.duration !== undefined) updateData.duration = args.duration;
      if (args.eventAt !== undefined) {
        if (args.eventAt != null && args.eventAt !== "") {
          const parsed = new Date(args.eventAt);
          if (isNaN(parsed.getTime())) {
            throw new GraphQLError("Invalid eventAt: not a valid date");
          }
          updateData.eventAt = parsed;
        } else {
          updateData.eventAt = null; // explicit clear
        }
      }
      if (args.importance !== undefined)
        updateData.importance = args.importance;
      if (args.visibility !== undefined)
        updateData.visibility = args.visibility;
      if (args.layoutX !== undefined) updateData.layoutX = args.layoutX;
      if (args.layoutY !== undefined) updateData.layoutY = args.layoutY;

      // Recompute contentHash if content fields changed.
      // layoutX/Y are presentation-only and intentionally excluded from the
      // content hash — moving a post on the timeline does not alter its content.
      // thumbnailUrl is a display-optimization field (auto-generated from video),
      // not part of the content signature — changing thumbnail does not alter content.
      const contentChanged =
        args.title !== undefined ||
        args.body !== undefined ||
        args.bodyFormat !== undefined ||
        args.mediaUrl !== undefined ||
        args.mediaType !== undefined ||
        args.importance !== undefined ||
        args.duration !== undefined;

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
        if (
          post.signature !== null &&
          !(args.signature && args.signature.length > 0)
        ) {
          throw new GraphQLError(
            "This post was signed. A new signature is required when updating content.",
          );
        }

        const effectiveBody =
          updateBodyValue !== undefined ? updateBodyValue : post.body;
        const effectiveBodyFormat =
          updateBodyFormat ?? (post.bodyFormat as string) ?? "plain";
        const newHash = computeContentHash({
          title: args.title !== undefined ? args.title : post.title,
          body: effectiveBody,
          bodyFormat: effectiveBodyFormat,
          mediaUrl: args.mediaUrl !== undefined ? args.mediaUrl : post.mediaUrl,
          mediaType: args.mediaType != null ? args.mediaType : post.mediaType,
          importance:
            args.importance != null ? args.importance : post.importance,
          duration: args.duration !== undefined ? args.duration : post.duration,
        });

        // Verify signature before committing any hash/signature to updateData
        let newSignature: string | null = null;
        if (args.signature && args.signature.length > 0) {
          await verifyPostSignature(
            newHash,
            args.signature,
            ctx.authUser.userId,
            post.authorId,
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
    resolve: async (_parent, args, ctx) => {
      const [post] = await db
        .select()
        .from(posts)
        .where(eq(posts.id, args.id))
        .limit(1);
      if (!post) return null;
      // Draft posts are only visible to the author
      if (
        post.visibility === "draft" &&
        (!ctx.authUser || post.authorId !== ctx.authUser.userId)
      ) {
        return null;
      }
      // Check artist visibility for posts belonging to a track
      if (post.trackId) {
        const [track] = await db
          .select({ artistId: tracks.artistId })
          .from(tracks)
          .where(eq(tracks.id, post.trackId))
          .limit(1);
        if (track) {
          const access = await checkArtistAccess(track.artistId, ctx.authUser);
          if (!access.accessible) return null;
        }
      }
      return post;
    },
  }),

  posts: t.field({
    type: [PostType],
    args: {
      trackId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      // Verify track's artist is accessible
      const [track] = await db
        .select({ artistId: tracks.artistId })
        .from(tracks)
        .where(eq(tracks.id, args.trackId))
        .limit(1);

      let isSelf = false;
      if (track) {
        const access = await checkArtistAccess(track.artistId, ctx.authUser);
        if (!access.accessible) return [];
        isSelf = access.isSelf;
      }

      // Self sees all posts (including drafts); others see only public
      const visibilityFilter = isSelf
        ? undefined
        : eq(posts.visibility, "public");

      const rows = await db
        .select({ post: posts, track: tracks })
        .from(posts)
        .innerJoin(tracks, sql`${posts.trackId} = ${tracks.id}`)
        .where(and(eq(tracks.id, args.trackId), visibilityFilter));
      return rows.map((r) => ({ ...r.post, _track: r.track }));
    },
  }),

  // Posts where trackId IS NULL (unassigned after track deletion).
  // Only returns the authenticated user's own unassigned posts.
  myUnassignedPosts: t.field({
    type: [PostType],
    args: {
      limit: t.arg.int({ defaultValue: 50 }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const limit = Math.max(1, Math.min(args.limit ?? 50, 100));
      const rows = await db
        .select()
        .from(posts)
        .where(
          and(eq(posts.authorId, ctx.authUser.userId), isNull(posts.trackId)),
        )
        .orderBy(desc(posts.createdAt))
        .limit(limit);
      return rows;
    },
  }),

  // INNER JOIN intentionally excludes trackId=NULL posts (unassigned after
  // track deletion). They are managed separately via Profile screen (#67).
  artistPosts: t.field({
    type: [PostType],
    args: {
      artistId: t.arg.string({ required: true }),
      limit: t.arg.int(),
    },
    resolve: async (_parent, args, ctx) => {
      const access = await checkArtistAccess(args.artistId, ctx.authUser);
      if (!access.accessible) return [];

      // Self sees all posts (including drafts); others see only public
      const visibilityFilter = access.isSelf
        ? undefined
        : eq(posts.visibility, "public");

      const limit = Math.max(1, Math.min(args.limit ?? 5, 10));
      const rows = await db
        .select({ post: posts, track: tracks })
        .from(posts)
        .innerJoin(tracks, sql`${posts.trackId} = ${tracks.id}`)
        .where(and(eq(tracks.artistId, args.artistId), visibilityFilter))
        .orderBy(desc(posts.createdAt))
        .limit(limit);
      return rows.map((r) => ({ ...r.post, _track: r.track }));
    },
  }),
}));

// Add recentPosts field to ArtistType (eliminates 2nd RTT on Artist Page, #63)
builder.objectFields(ArtistType, (t) => ({
  recentPosts: t.field({
    type: [PostType],
    args: {
      limit: t.arg.int({ defaultValue: 5 }),
    },
    // INNER JOIN intentionally excludes trackId=NULL posts (#67)
    resolve: async (artist, args, ctx) => {
      const isSelf = !!(ctx.authUser && artist.userId === ctx.authUser.userId);
      const visibilityFilter = isSelf
        ? undefined
        : eq(posts.visibility, "public");

      const limit = Math.max(1, Math.min(args.limit ?? 5, 10));
      const rows = await db
        .select({ post: posts, track: tracks })
        .from(posts)
        .innerJoin(tracks, sql`${posts.trackId} = ${tracks.id}`)
        .where(and(eq(tracks.artistId, artist.id), visibilityFilter))
        .orderBy(desc(posts.createdAt))
        .limit(limit);
      return rows.map((r) => ({ ...r.post, _track: r.track }));
    },
  }),
}));

// Add posts field to TrackType (avoids circular import by extending here)
builder.objectFields(TrackType, (t) => ({
  posts: t.field({
    type: [PostType],
    resolve: async (track, _args, ctx) => {
      const access = await checkArtistAccess(track.artistId, ctx.authUser);
      if (!access.accessible) return [];
      const visibilityFilter = access.isSelf
        ? undefined
        : eq(posts.visibility, "public");

      const rows = await db
        .select()
        .from(posts)
        .where(and(sql`${posts.trackId} = ${track.id}`, visibilityFilter));
      return rows.map((r) => ({ ...r, _track: track }));
    },
  }),
}));
