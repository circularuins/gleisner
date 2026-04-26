import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { db } from "../../db/index.js";
import {
  artists,
  posts,
  postMedia,
  tracks,
  users,
} from "../../db/schema/index.js";
import { and, desc, eq, inArray, isNull, sql } from "drizzle-orm";
import { ArtistType } from "./artist.js";
import { TrackType } from "./track.js";
import type { PublicUserShape } from "./user.js";
import { PublicUserType, publicUserColumns } from "./user.js";
import { computeContentHash, verifySignature } from "../../auth/signing.js";
import {
  validatePostVisibility,
  validateMediaUrl,
  validateMediaUrls,
  validateUrl,
  validateDuration,
  assertUploadedR2ObjectMatches,
  assertUploadedR2ObjectsMatch,
} from "../validators.js";
import { checkArtistAccess } from "../access.js";
import { fetchOgpMetadata } from "../../ogp/fetcher.js";
import { deleteR2Object } from "../../storage/r2.js";

/** Media types that require a file upload (mediaUrl must be non-null). */
const MEDIA_FILE_REQUIRED_TYPES = ["image", "video", "audio"];

const MediaTypeEnum = builder.enumType("MediaType", {
  values: ["thought", "article", "image", "video", "audio", "link"] as const,
});

const ArticleGenreEnum = builder.enumType("ArticleGenre", {
  values: [
    "fiction",
    "poetry",
    "essay",
    "technical",
    "opinion",
    "diary",
    "review",
    "travel",
    "other",
  ] as const,
});

/** Maximum body length for thought posts (characters). */
const MAX_THOUGHT_BODY_LENGTH = 280;

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

// Fields prefixed with `_` are resolver-internal prefetch slots and must
// never be exposed via the GraphQL schema. They carry JOIN/batch-loaded
// relations so child resolvers can serve them without triggering N+1.
type PostShape = {
  id: string;
  trackId: string | null;
  authorId: string;
  mediaType: "thought" | "article" | "image" | "video" | "audio" | "link";
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
  ogTitle: string | null;
  ogDescription: string | null;
  ogImage: string | null;
  ogSiteName: string | null;
  ogFetchedAt: Date | null;
  articleGenre: string | null;
  externalPublish: boolean;
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
  _media?: { id: string; mediaUrl: string; position: number }[];
  // Prefetched via INNER JOIN in list resolvers to eliminate N+1 (#180).
  // INNER JOIN is safe: authorId is NOT NULL with ON DELETE CASCADE,
  // so orphan posts cannot exist. Always uses publicUserColumns projection
  // to avoid leaking passwordHash / email / publicKey on JOIN.
  _author?: PublicUserShape;
};

type PostMediaShape = {
  id: string;
  mediaUrl: string;
  position: number;
};

const PostMediaType = builder.objectRef<PostMediaShape>("PostMedia");

PostMediaType.implement({
  fields: (t) => ({
    id: t.exposeID("id"),
    mediaUrl: t.exposeString("mediaUrl"),
    position: t.exposeInt("position"),
  }),
});

/**
 * Batch-load post_media rows for a list of post IDs.
 * Returns a Map from postId to sorted media array.
 * Prevents N+1 queries when resolving the `media` field on multiple posts.
 */
async function batchLoadPostMedia(
  postIds: string[],
): Promise<Map<string, PostMediaShape[]>> {
  if (postIds.length === 0) return new Map();
  const rows = await db
    .select({
      id: postMedia.id,
      postId: postMedia.postId,
      mediaUrl: postMedia.mediaUrl,
      position: postMedia.position,
    })
    .from(postMedia)
    .where(inArray(postMedia.postId, postIds))
    .orderBy(postMedia.position);
  const map = new Map<string, PostMediaShape[]>();
  for (const row of rows) {
    const list = map.get(row.postId) ?? [];
    list.push({ id: row.id, mediaUrl: row.mediaUrl, position: row.position });
    map.set(row.postId, list);
  }
  return map;
}

/**
 * Attach pre-fetched post_media to an array of posts.
 * Mutates the posts in-place by setting `_media`.
 */
async function attachPostMedia(results: PostShape[]): Promise<void> {
  const postIds = results.map((p) => p.id);
  const mediaMap = await batchLoadPostMedia(postIds);
  for (const post of results) {
    post._media = mediaMap.get(post.id) ?? [];
  }
}

/**
 * Base query for post list resolvers that need author prefetch (#180).
 * Projects `posts` + `publicUserColumns` only, so passwordHash / email /
 * publicKey can never leak through list paths. Callers chain `.where(...)`
 * and friends, then map `(r) => ({ ...r.post, _author: r.author })`.
 */
function selectPostsWithAuthor() {
  return db
    .select({ post: posts, author: publicUserColumns })
    .from(posts)
    .innerJoin(users, eq(posts.authorId, users.id));
}

/**
 * Same as `selectPostsWithAuthor` but also joins `tracks` for resolvers
 * that return track-bound posts. Kept separate from the track-less variant
 * to preserve row-shape typing on the Drizzle builder.
 *
 * `posts.trackId` is nullable, so the tracks join uses `sql` templating
 * rather than `eq()` (see backend-implementation.md Drizzle rule).
 */
function selectPostsWithTrackAndAuthor() {
  return db
    .select({ post: posts, track: tracks, author: publicUserColumns })
    .from(posts)
    .innerJoin(tracks, sql`${posts.trackId} = ${tracks.id}`)
    .innerJoin(users, eq(posts.authorId, users.id));
}

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
    ogTitle: t.exposeString("ogTitle", { nullable: true }),
    ogDescription: t.exposeString("ogDescription", { nullable: true }),
    ogImage: t.exposeString("ogImage", { nullable: true }),
    ogSiteName: t.exposeString("ogSiteName", { nullable: true }),
    articleGenre: t.field({
      type: ArticleGenreEnum,
      nullable: true,
      resolve: (post) =>
        post.articleGenre as (typeof ArticleGenreEnum)["$inferType"] | null,
    }),
    externalPublish: t.exposeBoolean("externalPublish"),
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
    media: t.field({
      type: [PostMediaType],
      resolve: async (post) => {
        // Use pre-fetched media from batch-load if available (N+1 prevention)
        if (post._media) return post._media;
        // Fallback: query individually (mutation return paths)
        const rows = await db
          .select({
            id: postMedia.id,
            mediaUrl: postMedia.mediaUrl,
            position: postMedia.position,
          })
          .from(postMedia)
          .where(eq(postMedia.postId, post.id))
          .orderBy(postMedia.position);
        return rows;
      },
    }),
    author: t.field({
      type: PublicUserType,
      resolve: async (post) => {
        // Use pre-fetched author from JOIN if available (N+1 prevention)
        if (post._author) return post._author;
        // Fallback for mutation return paths (createPost/updatePost/deletePost)
        // where the post is fetched without a users JOIN. authorId is NOT NULL
        // with ON DELETE CASCADE, so orphan rows are not expected in practice.
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
      mediaUrls: t.arg.stringList({ required: false }), // Multi-image: array of R2 URLs
      thumbnailUrl: t.arg.string(),
      duration: t.arg.int(),
      importance: t.arg.float(),
      visibility: t.arg.string(),
      eventAt: t.arg.string(),
      articleGenre: t.arg({ type: ArticleGenreEnum }),
      externalPublish: t.arg.boolean(),
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

      // Thought-specific validation
      if (args.mediaType === "thought") {
        if (args.title != null && args.title.trim() !== "") {
          throw new GraphQLError("Thought posts cannot have a title");
        }
        if (args.bodyFormat === "delta") {
          throw new GraphQLError(
            "Thought posts use plain text only (no rich text)",
          );
        }
        if (args.articleGenre != null) {
          throw new GraphQLError("articleGenre is only for article posts");
        }
      }

      // Article-specific: externalPublish only when visibility is public
      if (args.externalPublish && args.mediaType !== "article") {
        throw new GraphQLError("externalPublish is only for article posts");
      }
      const effectiveVisibility = args.visibility ?? "public";
      if (args.externalPublish && effectiveVisibility !== "public") {
        throw new GraphQLError(
          "externalPublish requires visibility to be public",
        );
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
          const maxBody =
            args.mediaType === "thought" ? MAX_THOUGHT_BODY_LENGTH : 10000;
          if (args.body.length > maxBody) {
            throw new GraphQLError(
              `Body must be ${maxBody} characters or less`,
            );
          }
          bodyValue = args.body;
        }
      }

      // Multi-image: resolve effective media URLs for image type
      // Image type uses mediaUrls (array); falls back to mediaUrl for backward compat
      let resolvedMediaUrls: string[] | undefined;
      if (args.mediaType === "image") {
        if (args.mediaUrls && args.mediaUrls.length > 0) {
          resolvedMediaUrls = args.mediaUrls;
        } else if (args.mediaUrl != null && args.mediaUrl.trim() !== "") {
          // Backward compat: single mediaUrl → 1-element array
          resolvedMediaUrls = [args.mediaUrl];
        }
        if (!resolvedMediaUrls || resolvedMediaUrls.length === 0) {
          throw new GraphQLError("Media file is required for this post type");
        }
        validateMediaUrls(resolvedMediaUrls);
        // Issue #269 / ADR 026: verify each uploaded object's bytes against
        // its declared content-type before persisting the URL list.
        await assertUploadedR2ObjectsMatch(resolvedMediaUrls);
      } else if (args.mediaUrls && args.mediaUrls.length > 0) {
        throw new GraphQLError("mediaUrls is only valid for image type posts");
      } else {
        // Non-image types: require mediaUrl for video/audio
        if (
          MEDIA_FILE_REQUIRED_TYPES.includes(args.mediaType) &&
          (args.mediaUrl == null || args.mediaUrl.trim() === "")
        ) {
          throw new GraphQLError("Media file is required for this post type");
        }
      }

      // Validate mediaUrl: link type accepts any URL, others require R2 domain
      if (args.mediaUrl != null && args.mediaType !== "image") {
        if (args.mediaType === "link") {
          validateUrl(args.mediaUrl);
        } else {
          validateMediaUrl(args.mediaUrl);
          // Issue #269 / ADR 026: magic-byte check for video/audio uploads.
          await assertUploadedR2ObjectMatches(args.mediaUrl);
        }
      }
      // thumbnailUrl is currently always supplied by the client (frontend
      // generates it via Canvas / video.captureStream and uploads to R2 via
      // the same presigned URL flow as mediaUrl), so it goes through the
      // magic-byte check too. If a future codepath has the backend
      // synthesise the thumbnail itself (e.g. server-side ffmpeg), that
      // codepath should write directly into the row and bypass this
      // resolver — the validator here is for client-supplied URLs only.
      if (args.thumbnailUrl != null) {
        validateMediaUrl(args.thumbnailUrl);
        await assertUploadedR2ObjectMatches(args.thumbnailUrl);
      }

      // Validate duration (media-type-specific limits per ADR 025)
      if (args.duration != null) {
        validateDuration(args.duration, args.mediaType);
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
        mediaUrl: args.mediaType === "image" ? null : (args.mediaUrl ?? null),
        mediaUrls: resolvedMediaUrls,
        mediaType: args.mediaType,
        importance: args.importance ?? 0.5,
        duration: args.duration ?? null,
        articleGenre: args.articleGenre ?? null,
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

      const postValues = {
        trackId: args.trackId,
        authorId: ctx.authUser.userId,
        mediaType: args.mediaType,
        title: args.title ?? null,
        body: bodyValue,
        bodyFormat,
        // Image type: mediaUrl is null (images live in post_media)
        mediaUrl: args.mediaType === "image" ? null : (args.mediaUrl ?? null),
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
        ...(args.articleGenre != null
          ? { articleGenre: args.articleGenre }
          : {}),
        ...(args.externalPublish != null
          ? { externalPublish: args.externalPublish }
          : {}),
      };

      // Use transaction for image type (multi-table write: post + post_media)
      let post: PostShape;
      if (resolvedMediaUrls && resolvedMediaUrls.length > 0) {
        post = await db.transaction(async (tx) => {
          const [created] = await tx
            .insert(posts)
            .values(postValues)
            .returning();
          await tx.insert(postMedia).values(
            resolvedMediaUrls.map((url, i) => ({
              postId: created.id,
              mediaUrl: url,
              position: i,
            })),
          );
          return created;
        });
      } else {
        const [created] = await db.insert(posts).values(postValues).returning();
        post = created;
      }

      // Fire-and-forget OGP fetch for link-type posts.
      // Always update ogFetchedAt (even on null) to prevent repeated fetches.
      if (args.mediaType === "link" && args.mediaUrl) {
        const postId = post.id;
        const mediaUrl = args.mediaUrl;
        fetchOgpMetadata(mediaUrl)
          .then(async (ogp) => {
            await db
              .update(posts)
              .set({
                ...(ogp
                  ? {
                      ogTitle: ogp.ogTitle,
                      ogDescription: ogp.ogDescription,
                      ogImage: ogp.ogImage,
                      ogSiteName: ogp.ogSiteName,
                    }
                  : {}),
                ogFetchedAt: new Date(),
              })
              .where(eq(posts.id, postId));
          })
          .catch((err) => {
            console.error(`[OGP] fire-and-forget failed for ${mediaUrl}:`, err);
          });
      }

      // Attach post_media for the response (avoids N+1 fallback query)
      await attachPostMedia([post]);
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
      mediaUrls: t.arg.stringList({ required: false }), // Multi-image: array of R2 URLs
      thumbnailUrl: t.arg.string(),
      duration: t.arg.int(),
      importance: t.arg.float(),
      visibility: t.arg.string(),
      eventAt: t.arg.string(),
      articleGenre: t.arg({ type: ArticleGenreEnum }),
      clearArticleGenre: t.arg.boolean(),
      externalPublish: t.arg.boolean(),
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

      // Effective media type (args override or existing)
      const effectiveMediaType =
        (args.mediaType as string | undefined) ?? post.mediaType;

      // Validate title
      if (args.title != null && args.title.length > 100) {
        throw new GraphQLError("Title must be 100 characters or less");
      }

      // Thought-specific validation (effective value pattern)
      if (effectiveMediaType === "thought") {
        // Title: check both args and existing
        const effectiveTitle =
          args.title !== undefined ? args.title : post.title;
        if (effectiveTitle != null && effectiveTitle.trim() !== "") {
          throw new GraphQLError("Thought posts cannot have a title");
        }
        if ((args.bodyFormat ?? post.bodyFormat) === "delta") {
          throw new GraphQLError(
            "Thought posts use plain text only (no rich text)",
          );
        }
        // articleGenre: check both args and existing
        const effectiveGenre = args.clearArticleGenre
          ? null
          : args.articleGenre !== undefined
            ? args.articleGenre
            : post.articleGenre;
        if (effectiveGenre != null) {
          throw new GraphQLError("articleGenre is only for article posts");
        }
        // Body length: check effective value (existing body may exceed 280 chars
        // when mediaType is changed from article to thought without updating body)
        const effectiveBody =
          args.body !== undefined ? args.body : (post.body as string | null);
        if (
          effectiveBody != null &&
          typeof effectiveBody === "string" &&
          effectiveBody.length > MAX_THOUGHT_BODY_LENGTH
        ) {
          throw new GraphQLError(
            `Body must be ${MAX_THOUGHT_BODY_LENGTH} characters or less`,
          );
        }
      }

      // externalPublish: effective value pattern
      const effectiveExternalPublish =
        args.externalPublish !== undefined
          ? args.externalPublish
          : post.externalPublish;
      const effectiveVisibility =
        (args.visibility as string | undefined) ?? post.visibility;
      if (effectiveExternalPublish && effectiveMediaType !== "article") {
        throw new GraphQLError("externalPublish is only for article posts");
      }
      if (effectiveExternalPublish && effectiveVisibility !== "public") {
        throw new GraphQLError(
          "externalPublish requires visibility to be public",
        );
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
              const maxBody =
                effectiveMediaType === "thought"
                  ? MAX_THOUGHT_BODY_LENGTH
                  : 10000;
              if (args.body.length > maxBody) {
                throw new GraphQLError(
                  `Body must be ${maxBody} characters or less`,
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

      // Multi-image validation for image type (effective value pattern)
      let updateMediaUrls: string[] | undefined;
      if (effectiveMediaType === "image") {
        if (args.mediaUrls != null && args.mediaUrls.length > 0) {
          validateMediaUrls(args.mediaUrls);
          // Issue #269 / ADR 026: only magic-byte-check URLs that aren't
          // already attached to this post. The frontend resends the entire
          // ordered list on any reorder/replace, so the unchanged subset
          // would otherwise eat one R2 GET per existing image.
          //
          // existingMediaUrls is intentionally empty when the post is
          // changing INTO image type (post.mediaType !== "image"): every
          // URL is genuinely new for this post, so all of them must be
          // validated. The empty-Set diff falls through to that case
          // without a special branch.
          //
          // Skip-when-unchanged is sound only because every persisted URL
          // was validated by ADR 026 at write time — see ADR §"Negative
          // consequences" (skip-when-unchanged paragraph).
          let existingMediaUrls: string[] = [];
          if (post.mediaType === "image") {
            const existing = await db
              .select({ mediaUrl: postMedia.mediaUrl })
              .from(postMedia)
              .where(eq(postMedia.postId, post.id));
            existingMediaUrls = existing.map((m) => m.mediaUrl);
          }
          const existingSet = new Set(existingMediaUrls);
          // Dedupe with Set: a malicious or buggy client can submit the
          // same URL multiple times in mediaUrls; without dedup each
          // duplicate would issue its own R2 GET (cost waste + slightly
          // wider TOCTOU window for spoof-and-race). The DB column has
          // no unique constraint on (postId, mediaUrl), so we have to
          // dedupe here.
          const newUrls = [
            ...new Set(args.mediaUrls.filter((url) => !existingSet.has(url))),
          ];
          if (newUrls.length > 0) {
            await assertUploadedR2ObjectsMatch(newUrls);
          }
          updateMediaUrls = args.mediaUrls;
        } else if (args.mediaUrls != null && args.mediaUrls.length === 0) {
          throw new GraphQLError("At least one image is required");
        }
        // If mediaType is changing TO image, mediaUrls is required
        if (
          args.mediaType === "image" &&
          post.mediaType !== "image" &&
          !updateMediaUrls
        ) {
          throw new GraphQLError(
            "mediaUrls is required when changing to image type",
          );
        }
      } else if (args.mediaUrls && args.mediaUrls.length > 0) {
        throw new GraphQLError("mediaUrls is only valid for image type posts");
      }

      // Validate mediaUrl for non-image types. Skip-when-unchanged is sound
      // because every URL persisted on the row was validated when first
      // stored — see ADR 026 §"Negative consequences".
      if (args.mediaUrl != null && effectiveMediaType !== "image") {
        if (effectiveMediaType === "link") {
          validateUrl(args.mediaUrl);
        } else {
          validateMediaUrl(args.mediaUrl);
          if (args.mediaUrl !== post.mediaUrl) {
            await assertUploadedR2ObjectMatches(args.mediaUrl);
          }
        }
      }
      if (args.thumbnailUrl != null) {
        validateMediaUrl(args.thumbnailUrl);
        if (args.thumbnailUrl !== post.thumbnailUrl) {
          await assertUploadedR2ObjectMatches(args.thumbnailUrl);
        }
      }

      // Ensure video/audio posts always have a media file.
      if (
        effectiveMediaType !== "image" &&
        MEDIA_FILE_REQUIRED_TYPES.includes(effectiveMediaType) &&
        (() => {
          const newMediaUrl =
            args.mediaUrl !== undefined ? args.mediaUrl : post.mediaUrl;
          return newMediaUrl == null || newMediaUrl.trim() === "";
        })()
      ) {
        throw new GraphQLError("Media file is required for this post type");
      }

      // Validate duration (media-type-specific limits per ADR 025)
      // Re-check when mediaType changes even if duration is not updated,
      // because the existing duration may violate the new type's limit.
      {
        const effectiveType =
          (args.mediaType as string | undefined) ?? post.mediaType;
        const effectiveDuration =
          args.duration ?? (post.duration as number | null);
        if (effectiveDuration != null) {
          validateDuration(effectiveDuration, effectiveType);
        }
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
      if (args.articleGenre !== undefined)
        updateData.articleGenre = args.articleGenre;
      if (args.clearArticleGenre) updateData.articleGenre = null;
      if (args.externalPublish !== undefined)
        updateData.externalPublish = args.externalPublish;

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
        args.mediaUrls !== undefined ||
        args.mediaType !== undefined ||
        args.importance !== undefined ||
        args.duration !== undefined ||
        args.articleGenre !== undefined ||
        args.clearArticleGenre;

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
        const effectiveType = effectiveMediaType;

        // Resolve effective mediaUrls for hash computation
        let hashMediaUrls: string[] | undefined;
        if (effectiveType === "image") {
          if (updateMediaUrls) {
            hashMediaUrls = updateMediaUrls;
          } else {
            // Fallback: fetch existing post_media URLs for accurate hash recomputation.
            // This runs when content fields (title, body, etc.) change on an image post
            // without mediaUrls being updated. Acceptable cost for correctness;
            // could be optimized by pre-fetching _media on the post object.
            const existingMedia = await db
              .select({ mediaUrl: postMedia.mediaUrl })
              .from(postMedia)
              .where(eq(postMedia.postId, args.id))
              .orderBy(postMedia.position);
            hashMediaUrls = existingMedia.map((m) => m.mediaUrl);
          }
        }

        const newHash = computeContentHash({
          title: args.title !== undefined ? args.title : post.title,
          body: effectiveBody,
          bodyFormat: effectiveBodyFormat,
          mediaUrl:
            effectiveType === "image"
              ? null
              : args.mediaUrl !== undefined
                ? args.mediaUrl
                : post.mediaUrl,
          mediaUrls: hashMediaUrls,
          mediaType: effectiveType,
          importance:
            args.importance != null ? args.importance : post.importance,
          duration: args.duration !== undefined ? args.duration : post.duration,
          articleGenre: args.clearArticleGenre
            ? null
            : args.articleGenre !== undefined
              ? args.articleGenre
              : post.articleGenre,
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

      // If mediaType changes FROM image to non-image, clear post_media + set mediaUrl
      if (
        args.mediaType !== undefined &&
        post.mediaType === "image" &&
        args.mediaType !== "image"
      ) {
        updateData.mediaUrl = args.mediaUrl ?? null;
      }
      // If mediaType is image, ensure posts.mediaUrl is null
      if (effectiveMediaType === "image") {
        updateData.mediaUrl = null;
      }

      // Use transaction when post_media needs updating
      let updated: PostShape;
      let removedMediaUrls: string[] = [];
      if (
        updateMediaUrls ||
        (args.mediaType !== undefined &&
          post.mediaType === "image" &&
          args.mediaType !== "image")
      ) {
        updated = await db.transaction(async (tx) => {
          // Fetch old media URLs for R2 cleanup diff
          const oldMedia = await tx
            .select({ mediaUrl: postMedia.mediaUrl })
            .from(postMedia)
            .where(eq(postMedia.postId, args.id));

          // Delete old post_media rows
          if (oldMedia.length > 0) {
            await tx.delete(postMedia).where(eq(postMedia.postId, args.id));
          }

          // Insert new post_media rows if image type
          if (updateMediaUrls && updateMediaUrls.length > 0) {
            await tx.insert(postMedia).values(
              updateMediaUrls.map((url, i) => ({
                postId: args.id,
                mediaUrl: url,
                position: i,
              })),
            );
          }

          const [result] = await tx
            .update(posts)
            .set(updateData)
            .where(eq(posts.id, args.id))
            .returning();

          // Collect removed URLs for R2 cleanup after transaction commits
          const newUrlSet = new Set(updateMediaUrls ?? []);
          removedMediaUrls = oldMedia
            .filter((m) => !newUrlSet.has(m.mediaUrl))
            .map((m) => m.mediaUrl);

          return result;
        });

        // R2 cleanup AFTER transaction commit (fire-and-forget).
        // Moved outside transaction to prevent data loss if DB commit fails
        // after R2 files are already deleted.
        for (const url of removedMediaUrls) {
          deleteR2Object(url).catch((err) =>
            console.error("[updatePost] R2 media cleanup failed:", err),
          );
        }
      } else {
        const [result] = await db
          .update(posts)
          .set(updateData)
          .where(eq(posts.id, args.id))
          .returning();
        updated = result;
      }

      // Attach post_media for the response (avoids N+1 fallback query)
      await attachPostMedia([updated]);
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
        .select({
          authorId: posts.authorId,
          mediaUrl: posts.mediaUrl,
          thumbnailUrl: posts.thumbnailUrl,
        })
        .from(posts)
        .where(eq(posts.id, args.id))
        .limit(1);
      if (!post) {
        throw new GraphQLError("Post not found");
      }

      if (post.authorId !== ctx.authUser.userId) {
        throw new GraphQLError("Not authorized to delete this post");
      }

      // Fetch post_media URLs before deletion (CASCADE will remove rows)
      const mediaRows = await db
        .select({ mediaUrl: postMedia.mediaUrl })
        .from(postMedia)
        .where(eq(postMedia.postId, args.id));

      const [deleted] = await db
        .delete(posts)
        .where(eq(posts.id, args.id))
        .returning();

      // R2 fire-and-forget: DB deletion takes priority, R2 orphans are acceptable
      if (post.mediaUrl) {
        deleteR2Object(post.mediaUrl).catch((err) =>
          console.error("[deletePost] R2 media cleanup failed:", err),
        );
      }
      if (post.thumbnailUrl) {
        deleteR2Object(post.thumbnailUrl).catch((err) =>
          console.error("[deletePost] R2 thumbnail cleanup failed:", err),
        );
      }
      // Clean up post_media files from R2
      for (const m of mediaRows) {
        deleteR2Object(m.mediaUrl).catch((err) =>
          console.error("[deletePost] R2 post_media cleanup failed:", err),
        );
      }

      return deleted;
    },
  }),

  fetchOgp: t.field({
    type: PostType,
    nullable: true,
    args: {
      postId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      const [post] = await db
        .select()
        .from(posts)
        .where(eq(posts.id, args.postId))
        .limit(1);
      if (!post) {
        throw new GraphQLError("Post not found");
      }

      // Only the author can trigger OGP fetch (prevents SSRF via other users' posts)
      if (post.authorId !== ctx.authUser.userId) {
        throw new GraphQLError("Not authorized");
      }

      if (post.mediaType !== "link" || !post.mediaUrl) {
        throw new GraphQLError(
          "OGP fetch is only available for link-type posts with a URL",
        );
      }

      // Rate limit: skip if fetched within 24 hours
      if (
        post.ogFetchedAt &&
        Date.now() - post.ogFetchedAt.getTime() < 24 * 60 * 60 * 1000
      ) {
        return post;
      }

      // Rate limit: max 10 fetches per user per minute (DB-based).
      // Excludes the target post itself so re-fetching a post that already
      // has og_fetched_at set doesn't double-count toward the limit.
      const [{ count }] = await db
        .select({ count: sql<number>`count(*)::int` })
        .from(posts)
        .where(
          and(
            eq(posts.authorId, ctx.authUser.userId),
            sql`${posts.ogFetchedAt} > NOW() - INTERVAL '1 minute'`,
            sql`${posts.id} <> ${args.postId}::uuid`,
          ),
        );
      if (count >= 10) {
        throw new GraphQLError("Rate limit exceeded. Please try again later.");
      }

      // Check for existing OGP data for the same URL (reuse from this user's
      // other posts). Per-user scope avoids any cross-user data reuse — the
      // OGP fetcher is unauthenticated so the cached metadata is technically
      // identical for everyone, but constraining the cache to the calling
      // user keeps the audit trail clean and removes any "your fetch hit my
      // cached row" surprise. Self-exclusion (`id <> args.postId`) protects
      // against pathological cache hits if the 24h skip above is ever
      // refactored away.
      const [existing] = await db
        .select()
        .from(posts)
        .where(
          and(
            eq(posts.authorId, ctx.authUser.userId),
            eq(posts.mediaUrl, post.mediaUrl!),
            sql`${posts.id} <> ${args.postId}::uuid`,
            sql`${posts.ogFetchedAt} > NOW() - INTERVAL '24 hours'`,
            sql`(${posts.ogTitle} IS NOT NULL OR ${posts.ogImage} IS NOT NULL)`,
          ),
        )
        .limit(1);

      let ogData;
      if (existing) {
        ogData = {
          ogTitle: existing.ogTitle,
          ogDescription: existing.ogDescription,
          ogImage: existing.ogImage,
          ogSiteName: existing.ogSiteName,
        };
      } else {
        ogData = await fetchOgpMetadata(post.mediaUrl!);
      }

      const [updated] = await db
        .update(posts)
        .set({
          ...(ogData
            ? {
                ogTitle: ogData.ogTitle,
                ogDescription: ogData.ogDescription,
                ogImage: ogData.ogImage,
                ogSiteName: ogData.ogSiteName,
              }
            : {}),
          ogFetchedAt: new Date(),
        })
        .where(eq(posts.id, args.postId))
        .returning();

      return updated;
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
      await attachPostMedia([post]);
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

      const rows = await selectPostsWithTrackAndAuthor().where(
        and(eq(tracks.id, args.trackId), visibilityFilter),
      );
      const results = rows.map((r) => ({
        ...r.post,
        _track: r.track,
        _author: r.author,
      }));
      await attachPostMedia(results);
      return results;
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
      const rows = await selectPostsWithAuthor()
        .where(
          and(eq(posts.authorId, ctx.authUser.userId), isNull(posts.trackId)),
        )
        .orderBy(desc(posts.createdAt))
        .limit(limit);
      const results = rows.map((r) => ({ ...r.post, _author: r.author }));
      await attachPostMedia(results);
      return results;
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
      const rows = await selectPostsWithTrackAndAuthor()
        .where(and(eq(tracks.artistId, args.artistId), visibilityFilter))
        .orderBy(desc(posts.createdAt))
        .limit(limit);
      const results = rows.map((r) => ({
        ...r.post,
        _track: r.track,
        _author: r.author,
      }));
      await attachPostMedia(results);
      return results;
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
      const rows = await selectPostsWithTrackAndAuthor()
        .where(and(eq(tracks.artistId, artist.id), visibilityFilter))
        .orderBy(desc(posts.createdAt))
        .limit(limit);
      const results = rows.map((r) => ({
        ...r.post,
        _track: r.track,
        _author: r.author,
      }));
      await attachPostMedia(results);
      return results;
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

      const rows = await selectPostsWithAuthor().where(
        and(sql`${posts.trackId} = ${track.id}`, visibilityFilter),
      );
      const results = rows.map((r) => ({
        ...r.post,
        _track: track,
        _author: r.author,
      }));
      await attachPostMedia(results);
      return results;
    },
  }),
}));
