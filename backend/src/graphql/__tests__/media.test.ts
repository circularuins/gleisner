import { describe, it, expect, beforeEach, afterAll, vi } from "vitest";
import { db, getTestApp, gql, closeTestDb, signupAndGetToken } from "./helpers";
import { sql } from "drizzle-orm";
import { ALLOWED_CONTENT_TYPES } from "../../storage/r2.js";

// Mock the R2 module to avoid needing real AWS credentials in tests
vi.mock("../../storage/r2.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../storage/r2.js")>();
  return {
    ...actual,
    isR2Configured: vi.fn(() => true),
    isR2Url: vi.fn((url: string) =>
      url.startsWith("https://media.gleisner.test/"),
    ),
    generateUploadUrl: vi.fn(
      async (
        userId: string,
        category: string,
        contentType: string,
        filename: string,
        contentLength: number,
      ) => {
        const ext = filename.split(".").pop()?.toLowerCase() ?? "bin";
        const allowed = actual.ALLOWED_CONTENT_TYPES;

        if (!allowed[category as keyof typeof allowed]?.includes(contentType)) {
          throw new Error(
            `Content type ${contentType} is not allowed for ${category}. Allowed: ${allowed[category as keyof typeof allowed]?.join(", ")}`,
          );
        }

        const maxSizes: Record<string, number> = {
          avatars: 5 * 1024 * 1024,
          covers: 10 * 1024 * 1024,
          media: 50 * 1024 * 1024,
        };
        if (contentLength <= 0 || contentLength > maxSizes[category]!) {
          throw new Error(
            `File size must be between 1 byte and ${maxSizes[category]} bytes for ${category}`,
          );
        }

        return {
          uploadUrl: `https://r2-presigned.test/upload/${category}/${userId}/test-uuid.${ext}?signature=abc`,
          publicUrl: `https://media.gleisner.test/${category}/${userId}/test-uuid.${ext}`,
          key: `${category}/${userId}/test-uuid.${ext}`,
        };
      },
    ),
  };
});

const GET_UPLOAD_URL = `
  mutation GetUploadUrl($category: UploadCategory!, $contentType: String!, $filename: String!, $contentLength: Int!) {
    getUploadUrl(category: $category, contentType: $contentType, filename: $filename, contentLength: $contentLength) {
      uploadUrl
      publicUrl
      key
    }
  }
`;

const UPDATE_ME = `
  mutation UpdateMe($avatarUrl: String) {
    updateMe(avatarUrl: $avatarUrl) { id avatarUrl }
  }
`;

describe("Media Upload", () => {
  beforeEach(async () => {
    await db.execute(sql`TRUNCATE users CASCADE`);
  });

  afterAll(async () => {
    await closeTestDb();
  });

  it("should generate presigned upload URL for avatar", async () => {
    const app = await getTestApp();
    const token = await signupAndGetToken(app, "test@test.com", "testuser");

    const result = await gql(
      app,
      GET_UPLOAD_URL,
      {
        category: "avatars",
        contentType: "image/jpeg",
        filename: "avatar.jpg",
        contentLength: 1024 * 100, // 100 KB
      },
      token,
    );

    expect(result.errors).toBeUndefined();
    expect(result.data?.getUploadUrl).toMatchObject({
      uploadUrl: expect.stringContaining("r2-presigned.test/upload/avatars/"),
      publicUrl: expect.stringContaining("media.gleisner.test/avatars/"),
      key: expect.stringContaining("avatars/"),
    });
  });

  it("should generate presigned upload URL for cover", async () => {
    const app = await getTestApp();
    const token = await signupAndGetToken(app, "test@test.com", "testuser");

    const result = await gql(
      app,
      GET_UPLOAD_URL,
      {
        category: "covers",
        contentType: "image/png",
        filename: "cover.png",
        contentLength: 1024 * 500, // 500 KB
      },
      token,
    );

    expect(result.errors).toBeUndefined();
    expect(result.data?.getUploadUrl).toMatchObject({
      publicUrl: expect.stringContaining("media.gleisner.test/covers/"),
    });
  });

  it("should generate presigned upload URL for media", async () => {
    const app = await getTestApp();
    const token = await signupAndGetToken(app, "test@test.com", "testuser");

    const result = await gql(
      app,
      GET_UPLOAD_URL,
      {
        category: "media",
        contentType: "video/mp4",
        filename: "video.mp4",
        contentLength: 1024 * 1024 * 10, // 10 MB
      },
      token,
    );

    expect(result.errors).toBeUndefined();
    expect(result.data?.getUploadUrl).toMatchObject({
      publicUrl: expect.stringContaining("media.gleisner.test/media/"),
    });
  });

  it("should reject unauthenticated requests", async () => {
    const app = await getTestApp();

    const result = await gql(app, GET_UPLOAD_URL, {
      category: "avatars",
      contentType: "image/jpeg",
      filename: "avatar.jpg",
      contentLength: 1024,
    });

    expect(result.errors?.[0]?.message).toBe("Authentication required");
  });

  it("should reject disallowed content types", async () => {
    const app = await getTestApp();
    const token = await signupAndGetToken(app, "test@test.com", "testuser");

    const result = await gql(
      app,
      GET_UPLOAD_URL,
      {
        category: "avatars",
        contentType: "application/pdf",
        filename: "doc.pdf",
        contentLength: 1024,
      },
      token,
    );

    expect(result.errors?.[0]?.message).toContain("not allowed for avatars");
  });

  it("should reject files exceeding size limit", async () => {
    const app = await getTestApp();
    const token = await signupAndGetToken(app, "test@test.com", "testuser");

    const result = await gql(
      app,
      GET_UPLOAD_URL,
      {
        category: "avatars",
        contentType: "image/jpeg",
        filename: "huge.jpg",
        contentLength: 6 * 1024 * 1024, // 6 MB > 5 MB limit
      },
      token,
    );

    expect(result.errors?.[0]?.message).toContain("File size must be between");
  });

  it("should accept R2 URLs for avatarUrl", async () => {
    const app = await getTestApp();
    const token = await signupAndGetToken(app, "test@test.com", "testuser");

    const result = await gql(
      app,
      UPDATE_ME,
      { avatarUrl: "https://media.gleisner.test/avatars/user1/test.jpg" },
      token,
    );

    expect(result.errors).toBeUndefined();
    expect((result.data?.updateMe as { avatarUrl: string }).avatarUrl).toBe(
      "https://media.gleisner.test/avatars/user1/test.jpg",
    );
  });

  it("should reject non-R2 URLs for avatarUrl when R2 is configured", async () => {
    const app = await getTestApp();
    const token = await signupAndGetToken(app, "test@test.com", "testuser");

    const result = await gql(
      app,
      UPDATE_ME,
      { avatarUrl: "https://example.com/avatar.jpg" },
      token,
    );

    expect(result.errors?.[0]?.message).toContain("configured storage domain");
  });

  it("should use same content type allowlist as r2.ts", () => {
    expect(ALLOWED_CONTENT_TYPES.avatars).toContain("image/jpeg");
    expect(ALLOWED_CONTENT_TYPES.media).toContain("video/mp4");
    expect(ALLOWED_CONTENT_TYPES.media).toContain("audio/mpeg");
  });
});
