import { describe, it, expect } from "vitest";
import {
  isR2Url,
  isLocalDevUrl,
  ALLOWED_CONTENT_TYPES,
  CONTENT_TYPE_EXT,
  UPLOAD_LIMITS,
  R2ValidationError,
  isAllowedContentType,
  validateUploadedR2Object,
  _readFirstBytesForTesting,
  type UploadCategory,
} from "../r2.js";
import { env } from "../../env.js";

describe("r2 utility functions", () => {
  describe("isR2Url", () => {
    it("should return false when R2_PUBLIC_URL is not set", () => {
      // R2_PUBLIC_URL is not set in test env
      expect(isR2Url("https://example.com/file.jpg")).toBe(false);
    });

    it("should accept URLs matching R2_PUBLIC_URL", () => {
      const original = env.R2_PUBLIC_URL;
      Object.defineProperty(env, "R2_PUBLIC_URL", {
        value: "https://media.gleisner.app",
        writable: true,
        configurable: true,
      });
      try {
        expect(
          isR2Url("https://media.gleisner.app/avatars/user1/test.jpg"),
        ).toBe(true);
        expect(isR2Url("https://evil.com/avatars/test.jpg")).toBe(false);
        // Must have trailing slash after domain to prevent prefix attacks
        expect(isR2Url("https://media.gleisner.app.evil.com/test.jpg")).toBe(
          false,
        );
      } finally {
        Object.defineProperty(env, "R2_PUBLIC_URL", {
          value: original,
          writable: true,
          configurable: true,
        });
      }
    });
  });

  describe("isLocalDevUrl", () => {
    it("should accept localhost URLs", () => {
      expect(isLocalDevUrl("http://localhost:4000/file.jpg")).toBe(true);
      expect(isLocalDevUrl("http://localhost/file.jpg")).toBe(true);
      expect(isLocalDevUrl("https://localhost:3000/file.jpg")).toBe(true);
    });

    it("should accept 127.0.0.1 URLs", () => {
      expect(isLocalDevUrl("http://127.0.0.1:4000/file.jpg")).toBe(true);
    });

    it("should reject external URLs", () => {
      expect(isLocalDevUrl("https://example.com/file.jpg")).toBe(false);
      expect(isLocalDevUrl("https://evil.localhost.com/file.jpg")).toBe(false);
    });

    it("should reject invalid URLs", () => {
      expect(isLocalDevUrl("not-a-url")).toBe(false);
      expect(isLocalDevUrl("")).toBe(false);
    });
  });

  describe("ALLOWED_CONTENT_TYPES", () => {
    it("should only allow images for avatars", () => {
      for (const ct of ALLOWED_CONTENT_TYPES.avatars) {
        expect(ct).toMatch(/^image\//);
      }
    });

    it("should only allow images for covers", () => {
      for (const ct of ALLOWED_CONTENT_TYPES.covers) {
        expect(ct).toMatch(/^image\//);
      }
    });

    it("should allow images, video, and audio for media", () => {
      const types = new Set(
        ALLOWED_CONTENT_TYPES.media.map((ct) => ct.split("/")[0]),
      );
      expect(types).toContain("image");
      expect(types).toContain("video");
      expect(types).toContain("audio");
    });

    it("should not allow dangerous content types", () => {
      const allTypes = Object.values(ALLOWED_CONTENT_TYPES).flat();
      for (const ct of allTypes) {
        expect(ct).not.toMatch(/^(text|application)\//);
      }
    });

    // ADR 025: HEIC/HEIF support (#146). Apple devices commonly produce HEIC
    // by default. Even though the frontend normalises HEIC to JPEG before
    // upload on Web, the backend must accept the raw content type across all
    // three categories so any pre-converted or direct upload is not rejected.
    it("should allow HEIC and HEIF in all three categories", () => {
      for (const category of [
        "avatars",
        "covers",
        "media",
      ] as const satisfies readonly (keyof typeof ALLOWED_CONTENT_TYPES)[]) {
        expect(ALLOWED_CONTENT_TYPES[category]).toContain("image/heic");
        expect(ALLOWED_CONTENT_TYPES[category]).toContain("image/heif");
      }
    });
  });

  // Going through `isAllowedContentType` (instead of asserting the constant
  // directly) verifies that the upload pipeline actually consults the gate —
  // a constant-only test passes even if a future refactor stops calling it.
  describe("isAllowedContentType", () => {
    const categories = [
      "avatars",
      "covers",
      "media",
    ] as const satisfies readonly UploadCategory[];

    it("accepts HEIC/HEIF across every category", () => {
      for (const category of categories) {
        expect(isAllowedContentType(category, "image/heic")).toBe(true);
        expect(isAllowedContentType(category, "image/heif")).toBe(true);
      }
    });

    // image/svg+xml is the canonical content-type-spoofing payload because
    // SVG can host scripts. It must never be allowed even though it starts
    // with `image/`. Issue #269 tracks the broader magic-byte verification.
    it("rejects image/svg+xml across every category", () => {
      for (const category of categories) {
        expect(isAllowedContentType(category, "image/svg+xml")).toBe(false);
      }
    });

    it("rejects executable / document content types", () => {
      const dangerous = [
        "application/javascript",
        "application/x-sh",
        "text/html",
        "text/javascript",
      ];
      for (const category of categories) {
        for (const ct of dangerous) {
          expect(isAllowedContentType(category, ct)).toBe(false);
        }
      }
    });

    it("rejects video/audio for avatars and covers", () => {
      for (const category of ["avatars", "covers"] as const) {
        expect(isAllowedContentType(category, "video/mp4")).toBe(false);
        expect(isAllowedContentType(category, "audio/mpeg")).toBe(false);
      }
    });

    // RFC 9110 §8.3.1: media types are case-insensitive. Some Apple SDKs
    // emit `image/HEIC` (upper-case subtype). Strict `Array.includes` would
    // reject those uploads — losing the very interop this PR adds.
    it("normalises case so image/HEIC and Image/Heif still match", () => {
      for (const category of categories) {
        expect(isAllowedContentType(category, "image/HEIC")).toBe(true);
        expect(isAllowedContentType(category, "Image/Heif")).toBe(true);
        expect(isAllowedContentType(category, "IMAGE/JPEG")).toBe(true);
      }
    });
  });

  // The upload key naming relies on `CONTENT_TYPE_EXT[contentType]` to pick
  // a sensible suffix. If a future PR adds a new MIME to ALLOWED_CONTENT_TYPES
  // but forgets to extend CONTENT_TYPE_EXT, the upload silently gets stored
  // as ".bin". This guard catches that drift at test time.
  describe("CONTENT_TYPE_EXT consistency", () => {
    it("covers every entry in ALLOWED_CONTENT_TYPES", () => {
      const allAllowed = new Set(Object.values(ALLOWED_CONTENT_TYPES).flat());
      for (const ct of allAllowed) {
        expect(
          CONTENT_TYPE_EXT,
          `missing ext mapping for ${ct}`,
        ).toHaveProperty(ct);
        expect(CONTENT_TYPE_EXT[ct].length).toBeGreaterThan(0);
      }
    });

    it("uses lower-case keys so case-insensitive lookup hits", () => {
      // `generateUploadUrl` lower-cases the lookup; the table itself must be
      // lower-case to make that work.
      for (const key of Object.keys(CONTENT_TYPE_EXT)) {
        expect(key).toBe(key.toLowerCase());
      }
    });
  });

  describe("UPLOAD_LIMITS", () => {
    it("should have reasonable size limits", () => {
      expect(UPLOAD_LIMITS.avatars.maxSize).toBeLessThanOrEqual(
        10 * 1024 * 1024,
      );
      expect(UPLOAD_LIMITS.covers.maxSize).toBeLessThanOrEqual(
        20 * 1024 * 1024,
      );
      expect(UPLOAD_LIMITS.media.maxSize).toBeLessThanOrEqual(
        100 * 1024 * 1024,
      );
    });

    it("should have limits for all categories", () => {
      const categories: UploadCategory[] = ["avatars", "covers", "media"];
      for (const cat of categories) {
        expect(UPLOAD_LIMITS[cat].maxSize).toBeGreaterThan(0);
      }
    });
  });

  describe("R2ValidationError", () => {
    it("should be an instance of Error", () => {
      const err = new R2ValidationError("test");
      expect(err).toBeInstanceOf(Error);
      expect(err).toBeInstanceOf(R2ValidationError);
      expect(err.name).toBe("R2ValidationError");
      expect(err.message).toBe("test");
    });
  });

  // Issue #269 / ADR 026: full integration coverage (S3 SDK round-trip,
  // ContentType / Body parsing, fire-and-forget DeleteObject on mismatch)
  // is intentionally not in this unit test file — it requires either an
  // aws-sdk-client-mock dependency or refactoring the singleton client to
  // accept dependency injection. Tracked in Issue #278 (item 5). The no-op
  // paths are covered here because they are reachable in normal test envs
  // (R2 not configured, non-R2 URLs).
  describe("validateUploadedR2Object (no-op paths)", () => {
    it("resolves without throwing when R2 is not configured", async () => {
      // Test env does not set R2_PUBLIC_URL etc., so isR2Configured() is false.
      await expect(
        validateUploadedR2Object("https://media.gleisner.app/foo.jpg"),
      ).resolves.toBeUndefined();
    });

    it("resolves without throwing for non-R2 URLs even when R2 is configured", async () => {
      const original = env.R2_PUBLIC_URL;
      Object.defineProperty(env, "R2_PUBLIC_URL", {
        value: "https://media.gleisner.app",
        writable: true,
        configurable: true,
      });
      try {
        await expect(
          validateUploadedR2Object("https://evil.com/exploit.jpg"),
        ).resolves.toBeUndefined();
      } finally {
        Object.defineProperty(env, "R2_PUBLIC_URL", {
          value: original,
          writable: true,
          configurable: true,
        });
      }
    });
  });

  // Issue #278 (items 1, 2): the runtime-detected helper that buffers
  // the first ~64 bytes of an SDK response body for magic-byte
  // inspection. The fast path uses SdkStreamMixin's
  // `transformToByteArray`, the fallback uses raw ReadableStream.
  // Both must enforce the byte cap defensively (the Range header
  // request is not always honoured by intermediaries).
  describe("readFirstBytes", () => {
    it("uses transformToByteArray fast path when available and slices to maxBytes", async () => {
      // 256 bytes returned (server / SDK ignores Range)
      const fullBytes = new Uint8Array(256);
      for (let i = 0; i < fullBytes.length; i++) fullBytes[i] = i;
      const body = {
        transformToByteArray: async () => fullBytes,
      };
      const result = await _readFirstBytesForTesting(body, 64);
      expect(result.byteLength).toBe(64);
      expect(result[0]).toBe(0);
      expect(result[63]).toBe(63);
    });

    it("falls back to ReadableStream reader when transformToByteArray is missing", async () => {
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]));
          controller.enqueue(new Uint8Array([9, 10, 11, 12]));
          controller.close();
        },
      });
      const result = await _readFirstBytesForTesting(stream, 64);
      // Stream had only 12 bytes total; we shouldn't pad.
      expect(result.byteLength).toBe(12);
      expect(Array.from(result)).toEqual([
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
      ]);
    });

    it("trims a ReadableStream chunk that exceeds the remaining budget", async () => {
      // Single 1024-byte chunk — proxies / SDK chunkers can deliver
      // far more than the Range request asked for. The fallback must
      // truncate this to maxBytes without ever holding the full chunk
      // in the assembled buffer.
      const oversized = new Uint8Array(1024);
      for (let i = 0; i < oversized.length; i++) oversized[i] = i & 0xff;
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(oversized);
          controller.close();
        },
      });
      const result = await _readFirstBytesForTesting(stream, 64);
      expect(result.byteLength).toBe(64);
      expect(result[0]).toBe(0);
      expect(result[63]).toBe(63);
    });

    it("stops reading once maxBytes is reached even if the stream has more", async () => {
      let chunksDelivered = 0;
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(new Uint8Array(40));
          chunksDelivered++;
          controller.enqueue(new Uint8Array(40));
          chunksDelivered++;
          controller.enqueue(new Uint8Array(40)); // would push us to 120 > 64
          chunksDelivered++;
          controller.close();
        },
      });
      const result = await _readFirstBytesForTesting(stream, 64);
      expect(result.byteLength).toBe(64);
      // All chunks were enqueued at start time, so the counter advances
      // — but the helper only consumed enough to reach the 64-byte cap.
      expect(chunksDelivered).toBe(3);
    });

    it("rejects bodies that are neither SdkStreamMixin nor ReadableStream", async () => {
      await expect(_readFirstBytesForTesting({}, 64)).rejects.toBeInstanceOf(
        R2ValidationError,
      );
      await expect(_readFirstBytesForTesting(null, 64)).rejects.toBeInstanceOf(
        R2ValidationError,
      );
    });
  });
});
