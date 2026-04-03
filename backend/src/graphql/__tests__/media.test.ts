import { describe, it, expect, beforeEach, afterAll, vi } from "vitest";
import { db, getTestApp, gql, closeTestDb, signupAndGetToken } from "./helpers";
import { sql } from "drizzle-orm";
import { UPLOAD_LIMITS } from "../../storage/r2.js";

// Mock the R2 module to avoid needing real AWS credentials in tests.
// The mock returns fixed values — validation logic is tested in r2.test.ts.
vi.mock("../../storage/r2.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../storage/r2.js")>();
  return {
    ...actual,
    isR2Configured: vi.fn(() => true),
    isR2Url: vi.fn((url: string) =>
      url.startsWith("https://media.gleisner.test/"),
    ),
    isLocalDevUrl: actual.isLocalDevUrl,
    generateUploadUrl: vi.fn(
      async (
        userId: string,
        category: string,
        contentType: string,
        contentLength: number,
      ) => {
        // Minimal validation — mirrors r2.ts contract without duplicating logic
        if (
          !actual.ALLOWED_CONTENT_TYPES[
            category as keyof typeof actual.ALLOWED_CONTENT_TYPES
          ]?.includes(contentType)
        ) {
          throw new actual.R2ValidationError(
            `Content type ${contentType} is not allowed for ${category}`,
          );
        }
        const maxSize =
          actual.UPLOAD_LIMITS[category as keyof typeof actual.UPLOAD_LIMITS]
            ?.maxSize ?? 0;
        if (contentLength <= 0 || contentLength > maxSize) {
          throw new actual.R2ValidationError(
            `File size must be between 1 byte and ${maxSize} bytes for ${category}`,
          );
        }

        return {
          uploadUrl: `https://r2-presigned.test/upload/${category}/${userId}/test-uuid.jpg`,
          publicUrl: `https://media.gleisner.test/${category}/${userId}/test-uuid.jpg`,
          key: `${category}/${userId}/test-uuid.jpg`,
        };
      },
    ),
  };
});

const GET_UPLOAD_URL = `
  mutation GetUploadUrl($category: UploadCategory!, $contentType: String!, $contentLength: Int!) {
    getUploadUrl(category: $category, contentType: $contentType, contentLength: $contentLength) {
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
        contentLength: 1024 * 100,
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
        contentType: "image/jpeg",
        contentLength: 1024 * 500,
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
        contentType: "image/jpeg",
        contentLength: 1024 * 1024 * 10,
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
        contentLength: UPLOAD_LIMITS.avatars.maxSize + 1,
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
});
