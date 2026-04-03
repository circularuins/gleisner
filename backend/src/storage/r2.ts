import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
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

const UPLOAD_LIMITS: Record<UploadCategory, { maxSize: number }> = {
  avatars: { maxSize: 5 * 1024 * 1024 }, // 5 MB
  covers: { maxSize: 10 * 1024 * 1024 }, // 10 MB
  media: { maxSize: 50 * 1024 * 1024 }, // 50 MB
};

const ALLOWED_CONTENT_TYPES: Record<UploadCategory, string[]> = {
  avatars: ["image/jpeg", "image/png", "image/webp"],
  covers: ["image/jpeg", "image/png", "image/webp"],
  media: [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
    "video/mp4",
    "video/webm",
    "audio/mpeg",
    "audio/mp4",
    "audio/ogg",
    "audio/webm",
  ],
};

export interface PresignedUpload {
  uploadUrl: string;
  publicUrl: string;
  key: string;
}

/**
 * Generate a presigned PUT URL for direct R2 upload.
 * The key is structured as: {category}/{userId}/{uuid}.{ext}
 */
export async function generateUploadUrl(
  userId: string,
  category: UploadCategory,
  contentType: string,
  filename: string,
): Promise<PresignedUpload> {
  const limits = UPLOAD_LIMITS[category];
  const allowed = ALLOWED_CONTENT_TYPES[category];

  if (!allowed.includes(contentType)) {
    throw new Error(
      `Content type ${contentType} is not allowed for ${category}. Allowed: ${allowed.join(", ")}`,
    );
  }

  const ext = filename.split(".").pop()?.toLowerCase() ?? "bin";
  const safeExt = ext.replace(/[^a-z0-9]/g, "").slice(0, 10);
  const uuid = crypto.randomUUID();
  const key = `${category}/${userId}/${uuid}.${safeExt}`;

  const command = new PutObjectCommand({
    Bucket: env.R2_BUCKET_NAME,
    Key: key,
    ContentType: contentType,
    ContentLength: limits.maxSize,
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
