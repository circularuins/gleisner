import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  type GetObjectCommandOutput,
  DeleteObjectCommand,
  DeleteObjectsCommand,
  ListObjectsV2Command,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { env } from "../env.js";
import {
  detectMimeFromMagicBytes,
  isContentTypeCompatible,
} from "./magic-bytes.js";

let s3Client: S3Client | null = null;

/** Whether R2 storage is configured. False in local dev without R2 credentials. */
export function isR2Configured(): boolean {
  return !!(
    env.R2_ACCOUNT_ID &&
    env.R2_ACCESS_KEY_ID &&
    env.R2_SECRET_ACCESS_KEY &&
    env.R2_PUBLIC_URL
  );
}

function getS3Client(): S3Client {
  if (!s3Client) {
    if (!isR2Configured()) {
      throw new Error(
        "R2 storage is not configured. Set R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, and R2_PUBLIC_URL.",
      );
    }
    s3Client = new S3Client({
      region: "auto",
      endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: env.R2_ACCESS_KEY_ID!,
        secretAccessKey: env.R2_SECRET_ACCESS_KEY!,
      },
    });
  }
  return s3Client;
}

export type UploadCategory = "avatars" | "covers" | "media";

export const UPLOAD_LIMITS: Record<UploadCategory, { maxSize: number }> = {
  avatars: { maxSize: 5 * 1024 * 1024 }, // 5 MB
  covers: { maxSize: 10 * 1024 * 1024 }, // 10 MB
  media: { maxSize: 100 * 1024 * 1024 }, // 100 MB
};

export const ALLOWED_CONTENT_TYPES: Record<UploadCategory, string[]> = {
  avatars: [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
  ],
  covers: ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"],
  media: [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
    "image/heic",
    "image/heif",
    "video/mp4",
    "video/webm",
    "audio/mpeg",
    "audio/mp4",
    "audio/ogg",
    "audio/webm",
    "audio/wav",
  ],
};

/**
 * Derive file extension from content type instead of trusting client filename.
 *
 * Exported (read-only by convention) so tests can assert that every entry in
 * `ALLOWED_CONTENT_TYPES` has a matching extension — guarding against the
 * silent ".bin" fallback that would otherwise hit if a future PR adds a new
 * allowed MIME but forgets to map the extension.
 */
export const CONTENT_TYPE_EXT: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
  "image/heic": "heic",
  "image/heif": "heif",
  "video/mp4": "mp4",
  "video/webm": "webm",
  "audio/mpeg": "mp3",
  "audio/mp4": "m4a",
  "audio/ogg": "ogg",
  "audio/webm": "weba",
  "audio/wav": "wav",
};

export interface PresignedUpload {
  uploadUrl: string;
  publicUrl: string;
  key: string;
}

/** Validation error thrown by R2 upload functions. Safe to expose to clients. */
export class R2ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "R2ValidationError";
  }
}

/**
 * Whether the given content type is allowed for the upload category.
 *
 * Exported so tests can exercise the gate directly (instead of asserting
 * against the raw `ALLOWED_CONTENT_TYPES` array, which only verifies the
 * constant's contents — not that the upload path actually consults it),
 * and so future server-side ingestion paths can call the same predicate.
 *
 * The comparison is case-insensitive: RFC 9110 §8.3.1 makes media types
 * case-insensitive, and some Apple SDKs / camera roll integrations emit
 * `image/HEIC` (upper-case subtype) which a strict `Array.includes` would
 * reject — losing the very interop this PR is meant to add.
 *
 * NOTE: This is a string-level allow-list only. It does **not** verify
 * that the actual file bytes match the declared content type — see
 * Issue #269 for the magic-byte-based defence-in-depth follow-up.
 */
export function isAllowedContentType(
  category: UploadCategory,
  contentType: string,
): boolean {
  return ALLOWED_CONTENT_TYPES[category].includes(contentType.toLowerCase());
}

/**
 * Generate a presigned PUT URL for direct R2 upload.
 * The key is structured as: {category}/{userId}/{uuid}.{ext}
 *
 * @param contentLength - Actual file size in bytes declared by the client.
 *   Validated against category max size and included in the presigned signature
 *   so R2 rejects uploads that don't match the declared size.
 * @throws R2ValidationError for client input issues (safe to expose)
 * @throws Error for infrastructure issues (must NOT be exposed)
 */
export async function generateUploadUrl(
  userId: string,
  category: UploadCategory,
  contentType: string,
  contentLength: number,
): Promise<PresignedUpload> {
  const limits = UPLOAD_LIMITS[category];

  if (!isAllowedContentType(category, contentType)) {
    const allowed = ALLOWED_CONTENT_TYPES[category];
    throw new R2ValidationError(
      `Content type ${contentType} is not allowed for ${category}. Allowed: ${allowed.join(", ")}`,
    );
  }

  if (contentLength <= 0 || contentLength > limits.maxSize) {
    throw new R2ValidationError(
      `File size must be between 1 byte and ${limits.maxSize} bytes for ${category}`,
    );
  }

  // Lower-case the lookup key for the same case-insensitive reasons as
  // `isAllowedContentType`. The signed `ContentType` below stays as the
  // client sent it so the PUT signature stays consistent with whatever
  // header the client uploads with.
  const ext = CONTENT_TYPE_EXT[contentType.toLowerCase()] ?? "bin";
  const uuid = crypto.randomUUID();
  const key = `${category}/${userId}/${uuid}.${ext}`;

  const command = new PutObjectCommand({
    Bucket: env.R2_BUCKET_NAME,
    Key: key,
    ContentType: contentType,
    ContentLength: contentLength,
  });

  const uploadUrl = await getSignedUrl(getS3Client(), command, {
    expiresIn: 600, // 10 minutes
  });

  const publicUrl = `${env.R2_PUBLIC_URL}/${key}`;

  return { uploadUrl, publicUrl, key };
}

/** Check if a URL points to the configured R2 public domain. */
export function isR2Url(url: string): boolean {
  if (!env.R2_PUBLIC_URL) return false;
  return url.startsWith(env.R2_PUBLIC_URL + "/");
}

/** Reset singleton S3 client. For testing and credential rotation. */
export function _resetS3ClientForTesting(): void {
  s3Client = null;
}

/**
 * Check if a URL is allowed for media fields in local dev (R2 not configured).
 * Only localhost URLs are permitted to prevent external URL injection.
 */
export function isLocalDevUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return parsed.hostname === "localhost" || parsed.hostname === "127.0.0.1";
  } catch {
    return false;
  }
}

/**
 * Extract the R2 object key from a public URL. Returns `null` when the URL
 * is not an R2 public URL or the derived key fails the path-traversal guard.
 */
function extractR2Key(publicUrl: string): string | null {
  if (!isR2Configured() || !isR2Url(publicUrl)) return null;
  const prefix = env.R2_PUBLIC_URL + "/";
  const key = publicUrl.slice(prefix.length);
  // Path traversal guard: reject keys with .. or leading /
  if (key.includes("..") || key.startsWith("/") || key.length === 0) {
    return null;
  }
  return key;
}

/**
 * Read at most `maxBytes` from an AWS SDK `Body`. The body shape is loose:
 *
 * - Node.js path: `SdkStreamMixin.transformToByteArray()` is monkey-patched
 *   onto Readable streams by the SDK and is the fast path.
 * - Edge / future-SDK path: the body is a raw `ReadableStream<Uint8Array>`
 *   without the mixin. We fall back to a hand-rolled reader and stop as soon
 *   as the budget is met (cancel the stream so R2 stops sending bytes).
 *
 * In both branches we slice to `maxBytes` defensively, so a stream that
 * delivers more than the requested window can never produce a buffer larger
 * than the cap. This keeps the worst-case allocation bounded even if the
 * Range header is dropped or ignored.
 *
 * Issue #278 (items 1, 2).
 */
async function readFirstBytes(
  body: unknown,
  maxBytes: number,
): Promise<Uint8Array> {
  // Fast path: SDK v3 SdkStreamMixin
  if (
    body !== null &&
    typeof body === "object" &&
    typeof (body as { transformToByteArray?: unknown }).transformToByteArray ===
      "function"
  ) {
    const all = await (
      body as { transformToByteArray: () => Promise<Uint8Array> }
    ).transformToByteArray();
    return all.subarray(0, maxBytes);
  }

  // Fallback: raw ReadableStream — accumulate until we hit maxBytes, then
  // cancel so the producer stops sending.
  if (
    body !== null &&
    typeof body === "object" &&
    typeof (body as { getReader?: unknown }).getReader === "function"
  ) {
    const reader = (body as ReadableStream<Uint8Array>).getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    try {
      while (total < maxBytes) {
        const { done, value } = await reader.read();
        if (done) break;
        if (!value) continue;
        chunks.push(value);
        total += value.byteLength;
      }
    } finally {
      // Cancel + release so the SDK doesn't hold the connection open
      try {
        await reader.cancel();
      } catch {
        // ignore — best-effort cleanup
      }
      reader.releaseLock();
    }
    const buf = new Uint8Array(Math.min(total, maxBytes));
    let offset = 0;
    for (const chunk of chunks) {
      const remaining = maxBytes - offset;
      if (remaining <= 0) break;
      const slice = chunk.subarray(0, remaining);
      buf.set(slice, offset);
      offset += slice.byteLength;
    }
    return buf;
  }

  throw new R2ValidationError(
    "Uploaded file body is in an unsupported stream shape",
  );
}

/**
 * Validate that the object at `publicUrl` actually contains bytes that
 * match its declared `Content-Type`. See ADR 026 / Issue #269.
 *
 * Reads the first 64 bytes via a ranged GET (one R2 round-trip), which also
 * returns the stored `Content-Type` metadata. If the magic bytes don't match
 * the declared MIME (per `magic-bytes.ts` rules), the object is deleted from
 * R2 fire-and-forget and an `R2ValidationError` is thrown — this prevents
 * persisting a content-type-spoofed URL anywhere user-visible.
 *
 * No-op (resolves) when R2 is not configured or `publicUrl` is not an R2 URL
 * (local dev with localhost-served fixtures uses `isLocalDevUrl`).
 */
export async function validateUploadedR2Object(
  publicUrl: string,
): Promise<void> {
  const key = extractR2Key(publicUrl);
  if (key === null) return;

  let response: GetObjectCommandOutput;
  try {
    response = await getS3Client().send(
      new GetObjectCommand({
        Bucket: env.R2_BUCKET_NAME,
        Key: key,
        Range: "bytes=0-63",
      }),
    );
  } catch (err) {
    // Failure to fetch the just-uploaded object is itself suspicious — could
    // indicate the upload never landed or was already removed. We do NOT
    // attempt a delete here because there's no proof the object exists; just
    // surface a generic failure so the mutation rejects.
    console.error("[validateUploadedR2Object] fetch failed:", err);
    throw new R2ValidationError("Could not verify uploaded file");
  }

  const declared = (response.ContentType ?? "").toLowerCase();
  if (!declared) {
    deleteR2Object(publicUrl).catch((err) =>
      // [SECURITY] tag flags this for the R2 orphan sweeper (Issue #230) —
      // a delete failure here means a content-type-spoofed object is still
      // sitting in R2 and needs out-of-band cleanup.
      console.error(
        "[SECURITY][validateUploadedR2Object] cleanup failed for spoofed upload:",
        err,
      ),
    );
    throw new R2ValidationError("Uploaded file has no content-type");
  }

  // AWS SDK v3 streams the body. Buffer the first 64 bytes for inspection.
  const body = response.Body;
  if (!body) {
    deleteR2Object(publicUrl).catch((err) =>
      // [SECURITY] tag flags this for the R2 orphan sweeper (Issue #230) —
      // a delete failure here means a content-type-spoofed object is still
      // sitting in R2 and needs out-of-band cleanup.
      console.error(
        "[SECURITY][validateUploadedR2Object] cleanup failed for spoofed upload:",
        err,
      ),
    );
    throw new R2ValidationError("Uploaded file is empty");
  }

  // Buffer the first 64 bytes for magic-byte inspection. The Range header
  // (`bytes=0-63` above) should keep R2 from sending more than that, but we
  // also enforce a hard 64-byte cap downstream to keep the worst case bounded
  // even if R2 ignores Range or the SDK buffers more than expected.
  //
  // The SDK's `SdkStreamMixin` adds `transformToByteArray` to `Body`, but the
  // type is declared loosely (`StreamingBlobPayloadOutputTypes`) and Edge
  // Runtime / future SDK refactors may surface a raw `ReadableStream`
  // instead. We runtime-detect the helper and fall back to a hand-rolled
  // ReadableStream reader, which short-circuits as soon as 64 bytes are
  // collected (guards against pathological large bodies bypassing the
  // ranged GET).
  const bytes = await readFirstBytes(body, 64);

  const detected = detectMimeFromMagicBytes(bytes);
  if (!detected || !isContentTypeCompatible(declared, detected)) {
    // Log the (declared, detected, key) triple server-side for forensics.
    // The client-facing message intentionally omits both values: returning
    // `declared` would let an attacker probe what content-type a given key
    // is stored under (a small but free oracle), and returning `detected`
    // would let them probe what actual bytes are at a given key.
    console.error(
      "[validateUploadedR2Object] content-type mismatch: key=%s declared=%s detected=%s",
      key,
      declared,
      detected ?? "unrecognised",
    );
    deleteR2Object(publicUrl).catch((err) =>
      // [SECURITY] tag flags this for the R2 orphan sweeper (Issue #230) —
      // a delete failure here means a content-type-spoofed object is still
      // sitting in R2 and needs out-of-band cleanup.
      console.error(
        "[SECURITY][validateUploadedR2Object] cleanup failed for spoofed upload:",
        err,
      ),
    );
    throw new R2ValidationError(
      "Uploaded file does not match its declared type",
    );
  }
}

/**
 * Delete an object from R2 by its public URL.
 * Extracts the key from the URL and sends a DeleteObjectCommand.
 * No-op if R2 is not configured (local dev) or URL is not an R2 URL.
 * Idempotent: does not throw if the object doesn't exist (S3/R2 spec).
 */
export async function deleteR2Object(publicUrl: string): Promise<void> {
  const key = extractR2Key(publicUrl);
  if (key === null) return;

  await getS3Client().send(
    new DeleteObjectCommand({
      Bucket: env.R2_BUCKET_NAME,
      Key: key,
    }),
  );
}

/**
 * Delete all R2 objects under a prefix (e.g. "media/{userId}/").
 * Used for account deletion to clean up all user's media files.
 * Prefix must end with "/" to prevent cross-user prefix matching.
 */
export async function deleteR2ObjectsByPrefix(prefix: string): Promise<number> {
  if (!isR2Configured()) return 0;
  if (!prefix.endsWith("/")) {
    throw new Error("prefix must end with '/' to prevent cross-user matching");
  }

  let deleted = 0;
  let continuationToken: string | undefined;

  do {
    const list = await getS3Client().send(
      new ListObjectsV2Command({
        Bucket: env.R2_BUCKET_NAME,
        Prefix: prefix,
        ContinuationToken: continuationToken,
      }),
    );

    const keys = (list.Contents ?? [])
      .filter((obj) => obj.Key)
      .map((obj) => ({ Key: obj.Key! }));

    if (keys.length > 0) {
      const response = await getS3Client().send(
        new DeleteObjectsCommand({
          Bucket: env.R2_BUCKET_NAME,
          Delete: { Objects: keys },
        }),
      );
      const errorCount = response.Errors?.length ?? 0;
      if (errorCount > 0) {
        console.error(
          `[deleteR2ObjectsByPrefix] ${errorCount} objects failed to delete`,
        );
      }
      deleted += keys.length - errorCount;
    }

    continuationToken = list.NextContinuationToken;
  } while (continuationToken);

  return deleted;
}
