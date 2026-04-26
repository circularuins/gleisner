import { describe, it, expect } from "vitest";
import {
  detectMimeFromMagicBytes,
  isContentTypeCompatible,
} from "../magic-bytes.js";
import { ALLOWED_CONTENT_TYPES } from "../r2.js";

/**
 * Build a Uint8Array from a heterogeneous spec: numbers (raw bytes), strings
 * (interpreted as ASCII), or nested arrays. Pads to at least 16 bytes with
 * zeros so the 12-byte minimum guard never trips on test fixtures.
 */
function bytes(...parts: Array<number | string | number[]>): Uint8Array {
  const out: number[] = [];
  for (const p of parts) {
    if (typeof p === "number") out.push(p);
    else if (typeof p === "string") {
      for (let i = 0; i < p.length; i++) out.push(p.charCodeAt(i));
    } else {
      out.push(...p);
    }
  }
  while (out.length < 16) out.push(0);
  return Uint8Array.from(out);
}

describe("detectMimeFromMagicBytes", () => {
  it("returns null for buffers shorter than 12 bytes", () => {
    expect(detectMimeFromMagicBytes(Uint8Array.from([0xff, 0xd8]))).toBeNull();
    expect(detectMimeFromMagicBytes(new Uint8Array(11))).toBeNull();
  });

  it("recognises JPEG", () => {
    expect(detectMimeFromMagicBytes(bytes(0xff, 0xd8, 0xff, 0xe0))).toBe(
      "image/jpeg",
    );
  });

  it("recognises PNG", () => {
    expect(
      detectMimeFromMagicBytes(
        bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a),
      ),
    ).toBe("image/png");
  });

  it("recognises WebP via RIFF + WEBP tag", () => {
    expect(detectMimeFromMagicBytes(bytes("RIFF", 0, 0, 0, 0, "WEBP"))).toBe(
      "image/webp",
    );
  });

  it("recognises WAV via RIFF + WAVE tag", () => {
    expect(detectMimeFromMagicBytes(bytes("RIFF", 0, 0, 0, 0, "WAVE"))).toBe(
      "audio/wav",
    );
  });

  it("returns null for RIFF with neither WEBP nor WAVE", () => {
    // RIFF + AVI is a real format but not on our allow-list.
    expect(
      detectMimeFromMagicBytes(bytes("RIFF", 0, 0, 0, 0, "AVI ")),
    ).toBeNull();
  });

  it("recognises GIF", () => {
    expect(detectMimeFromMagicBytes(bytes("GIF89a"))).toBe("image/gif");
    expect(detectMimeFromMagicBytes(bytes("GIF87a"))).toBe("image/gif");
  });

  describe("ftyp box (ISO base media)", () => {
    it.each(["heic", "heif", "heix", "mif1", "msf1", "heis"])(
      "recognises HEIC/HEIF brand %s as image/heic",
      (brand) => {
        expect(
          detectMimeFromMagicBytes(bytes(0, 0, 0, 0x20, "ftyp", brand)),
        ).toBe("image/heic");
      },
    );

    it.each(["M4A ", "M4B ", "M4P "])(
      "recognises audio/mp4 brand %s",
      (brand) => {
        expect(
          detectMimeFromMagicBytes(bytes(0, 0, 0, 0x20, "ftyp", brand)),
        ).toBe("audio/mp4");
      },
    );

    it.each(["isom", "mp41", "mp42", "avc1"])(
      "treats video brand %s as video/mp4",
      (brand) => {
        expect(
          detectMimeFromMagicBytes(bytes(0, 0, 0, 0x20, "ftyp", brand)),
        ).toBe("video/mp4");
      },
    );

    it("treats hevc brand as video/mp4 (HEVC video, not still image)", () => {
      expect(
        detectMimeFromMagicBytes(bytes(0, 0, 0, 0x20, "ftyp", "hevc")),
      ).toBe("video/mp4");
    });
  });

  it("recognises WebM (EBML)", () => {
    expect(detectMimeFromMagicBytes(bytes(0x1a, 0x45, 0xdf, 0xa3))).toBe(
      "video/webm",
    );
  });

  it("recognises Ogg", () => {
    expect(detectMimeFromMagicBytes(bytes("OggS"))).toBe("audio/ogg");
  });

  it("recognises MP3 with ID3 tag", () => {
    expect(detectMimeFromMagicBytes(bytes("ID3", 0x03))).toBe("audio/mpeg");
  });

  it("recognises MP3 frame sync (no ID3 header)", () => {
    expect(detectMimeFromMagicBytes(bytes(0xff, 0xfb))).toBe("audio/mpeg");
    expect(detectMimeFromMagicBytes(bytes(0xff, 0xf3))).toBe("audio/mpeg");
  });

  it("returns null for HTML / SVG / JS payloads (the spoofing attack surface)", () => {
    // <html> — would render as a page if served with a permissive content-type.
    expect(detectMimeFromMagicBytes(bytes("<html><head>"))).toBeNull();
    // <svg>
    expect(detectMimeFromMagicBytes(bytes("<svg xmlns="))).toBeNull();
    // JS prelude
    expect(detectMimeFromMagicBytes(bytes("(function() "))).toBeNull();
  });

  it("returns null for arbitrary noise", () => {
    expect(
      detectMimeFromMagicBytes(
        Uint8Array.from(Array.from({ length: 16 }, (_, i) => i * 7 + 1)),
      ),
    ).toBeNull();
  });

  // Coverage guard: every entry in ALLOWED_CONTENT_TYPES must have at least
  // one fixture in this test file that detects to a compatible MIME.
  // If a future PR adds a new allowed type without adding a magic-byte rule,
  // this test will fail loudly instead of letting the upload path silently
  // accept whatever bytes the client sends.
  describe("ALLOWED_CONTENT_TYPES coverage", () => {
    const fixtures: Record<string, Uint8Array> = {
      "image/jpeg": bytes(0xff, 0xd8, 0xff),
      "image/png": bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a),
      "image/webp": bytes("RIFF", 0, 0, 0, 0, "WEBP"),
      "image/gif": bytes("GIF89a"),
      "image/heic": bytes(0, 0, 0, 0x20, "ftyp", "heic"),
      "image/heif": bytes(0, 0, 0, 0x20, "ftyp", "mif1"),
      "video/mp4": bytes(0, 0, 0, 0x20, "ftyp", "mp42"),
      "video/webm": bytes(0x1a, 0x45, 0xdf, 0xa3),
      "audio/mpeg": bytes("ID3", 0x03),
      "audio/mp4": bytes(0, 0, 0, 0x20, "ftyp", "M4A "),
      "audio/ogg": bytes("OggS"),
      "audio/webm": bytes(0x1a, 0x45, 0xdf, 0xa3), // shares EBML with video/webm
      "audio/wav": bytes("RIFF", 0, 0, 0, 0, "WAVE"),
    };

    for (const [category, allowed] of Object.entries(ALLOWED_CONTENT_TYPES)) {
      for (const declared of allowed) {
        it(`${category} declared ${declared} has a detectable fixture`, () => {
          const fixture = fixtures[declared];
          expect(
            fixture,
            `Add a magic-byte fixture for declared content-type "${declared}"`,
          ).toBeDefined();
          const detected = detectMimeFromMagicBytes(fixture);
          expect(
            detected,
            `Bytes for ${declared} must be recognised by detectMimeFromMagicBytes`,
          ).not.toBeNull();
          expect(
            isContentTypeCompatible(declared, detected!),
            `Detected ${detected} must be compatible with declared ${declared}`,
          ).toBe(true);
        });
      }
    }
  });
});

describe("isContentTypeCompatible", () => {
  it("matches exact MIME equality", () => {
    expect(isContentTypeCompatible("image/jpeg", "image/jpeg")).toBe(true);
  });

  it("is case-insensitive", () => {
    expect(isContentTypeCompatible("Image/JPEG", "image/jpeg")).toBe(true);
    expect(isContentTypeCompatible("image/jpeg", "IMAGE/JPEG")).toBe(true);
  });

  it("treats HEIC and HEIF as interchangeable", () => {
    expect(isContentTypeCompatible("image/heic", "image/heif")).toBe(true);
    expect(isContentTypeCompatible("image/heif", "image/heic")).toBe(true);
  });

  it("accepts detected video/webm for declared audio/webm", () => {
    expect(isContentTypeCompatible("audio/webm", "video/webm")).toBe(true);
  });

  it("rejects mismatched MIMEs that have no equivalence rule", () => {
    expect(isContentTypeCompatible("image/jpeg", "image/png")).toBe(false);
    expect(isContentTypeCompatible("image/jpeg", "video/mp4")).toBe(false);
    // The spoofing case the validator is meant to catch:
    expect(isContentTypeCompatible("image/jpeg", "text/html")).toBe(false);
  });
});
