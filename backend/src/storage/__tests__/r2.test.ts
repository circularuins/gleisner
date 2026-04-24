import { describe, it, expect } from "vitest";
import {
  isR2Url,
  isLocalDevUrl,
  ALLOWED_CONTENT_TYPES,
  UPLOAD_LIMITS,
  R2ValidationError,
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
});
