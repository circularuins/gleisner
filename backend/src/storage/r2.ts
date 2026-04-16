import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  DeleteObjectsCommand,
  ListObjectsV2Command,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { env } from "../env.js";

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
  avatars: ["image/jpeg", "image/png", "image/webp"],
  covers: ["image/jpeg", "image/png", "image/webp"],
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

/** Derive file extension from content type instead of trusting client filename. */
const CONTENT_TYPE_EXT: Record<string, string> = {
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
  const allowed = ALLOWED_CONTENT_TYPES[category];

  if (!allowed.includes(contentType)) {
    throw new R2ValidationError(
      `Content type ${contentType} is not allowed for ${category}. Allowed: ${allowed.join(", ")}`,
    );
  }

  if (contentLength <= 0 || contentLength > limits.maxSize) {
    throw new R2ValidationError(
      `File size must be between 1 byte and ${limits.maxSize} bytes for ${category}`,
    );
  }

  const ext = CONTENT_TYPE_EXT[contentType] ?? "bin";
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
 * Delete an object from R2 by its public URL.
 * Extracts the key from the URL and sends a DeleteObjectCommand.
 * No-op if R2 is not configured (local dev) or URL is not an R2 URL.
 * Idempotent: does not throw if the object doesn't exist (S3/R2 spec).
 */
export async function deleteR2Object(publicUrl: string): Promise<void> {
  if (!isR2Configured() || !isR2Url(publicUrl)) return;

  const prefix = env.R2_PUBLIC_URL + "/";
  const key = publicUrl.slice(prefix.length);

  // Path traversal guard: reject keys with .. or leading /
  if (key.includes("..") || key.startsWith("/") || key.length === 0) return;

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
