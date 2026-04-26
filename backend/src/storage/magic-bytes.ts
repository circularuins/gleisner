/**
 * Magic-byte (file signature) detection for media uploads.
 *
 * Backend counterpart to `frontend/lib/providers/media_upload_provider.dart`'s
 * `mimeFromBytes`. Both sides MUST agree on which (bytes, declared MIME)
 * combinations are accepted, otherwise an upload that the frontend converts
 * locally will be rejected by the server (or vice versa).
 *
 * The recognised set is the union of every entry in
 * `ALLOWED_CONTENT_TYPES` (see `r2.ts`). Anything outside that set returns
 * `null` and `validateUploadedR2Object` treats the upload as a spoofing
 * attempt.
 *
 * Used by `validateUploadedR2Object` (Issue #269 / ADR 026). Exported helpers
 * are unit-tested in `magic-bytes.test.ts`; do NOT inline-duplicate the
 * detection rules elsewhere.
 */

const JPEG_MAGIC = [0xff, 0xd8, 0xff];
const PNG_MAGIC = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
const RIFF_PREFIX = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
const WEBP_TAG = [0x57, 0x45, 0x42, 0x50]; // "WEBP" at offset 8
const WAVE_TAG = [0x57, 0x41, 0x56, 0x45]; // "WAVE" at offset 8
const GIF_MAGIC = [0x47, 0x49, 0x46]; // "GIF"
const FTYP_MAGIC = [0x66, 0x74, 0x79, 0x70]; // "ftyp" at offset 4
const OGG_MAGIC = [0x4f, 0x67, 0x67, 0x53]; // "OggS"
const WEBM_MAGIC = [0x1a, 0x45, 0xdf, 0xa3]; // EBML header
const ID3_MAGIC = [0x49, 0x44, 0x33]; // "ID3"

/**
 * HEIC/HEIF still-image and image-sequence ftyp brands per ISO 14496-12 /
 * ISO 23008-12. `hevc`/`hevx` are HEVC video sequences and intentionally
 * excluded — they remain `video/mp4`. Mirrors the frontend pinning in
 * PR #253 review.
 */
const HEIC_BRANDS = new Set(["heic", "heif", "heix", "mif1", "msf1", "heis"]);

/**
 * MP4 audio brands. M4A / M4B / M4P all encode AAC audio in an MP4 container
 * and are served as `audio/mp4`. The brand check is prefix-based because
 * `ftyp` brand strings are 4 bytes and may be padded (e.g. `M4A `).
 */
const AUDIO_MP4_BRAND_PREFIXES = ["M4A", "M4B", "M4P"];

/** Buffer position 0..N must equal `pattern`. */
function startsWith(data: Uint8Array, pattern: number[]): boolean {
  if (data.length < pattern.length) return false;
  for (let i = 0; i < pattern.length; i++) {
    if (data[i] !== pattern[i]) return false;
  }
  return true;
}

function matchesAt(
  data: Uint8Array,
  offset: number,
  pattern: number[],
): boolean {
  if (data.length < offset + pattern.length) return false;
  for (let i = 0; i < pattern.length; i++) {
    if (data[offset + i] !== pattern[i]) return false;
  }
  return true;
}

/**
 * Detect MIME type from file magic bytes. Returns `null` when the bytes do
 * not match any allowed format.
 *
 * `buffer` should contain at least the first 12 bytes of the file. Callers
 * typically read 64 bytes via R2 ranged GET to leave room for the ftyp box
 * (which lives at offset 4..12) plus a margin for future detection rules.
 *
 * **Adding a new format (procedure):**
 * 1. Add the new MIME to `ALLOWED_CONTENT_TYPES` in `r2.ts` (and to
 *    `CONTENT_TYPE_EXT` so uploads get a sensible filename suffix).
 * 2. Define the magic-byte constant or `ftyp` brand here (top of file).
 * 3. Add a branch to `detectMimeFromMagicBytes` below — keep image / RIFF /
 *    ftyp / EBML / Ogg / ID3 / MP3 ordering so prefix collisions resolve
 *    correctly (e.g. RIFF must be checked before WebP/WAV sub-tags).
 * 4. Add fixtures to `magic-bytes.test.ts` (the
 *    `ALLOWED_CONTENT_TYPES coverage` table is the safety net — it fails
 *    if a new MIME is added but never produces a recognised detection).
 * 5. If the format has cross-MIME equivalence (HEIC/HEIF, video/webm
 *    accepting audio/webm, etc.), extend `isContentTypeCompatible`
 *    below.
 *
 * **Frontend parity:** `frontend/lib/utils/mime_from_bytes.dart` runs the
 * same detection on the client. Mirror any rule change there as well —
 * Issue #278 (item 6) tracks moving the fixture table to a shared
 * location to make drift CI-detectable.
 */
export function detectMimeFromMagicBytes(buffer: Uint8Array): string | null {
  if (buffer.length < 12) return null;

  // Images
  if (startsWith(buffer, JPEG_MAGIC)) return "image/jpeg";
  if (startsWith(buffer, PNG_MAGIC)) return "image/png";

  if (startsWith(buffer, RIFF_PREFIX)) {
    if (matchesAt(buffer, 8, WEBP_TAG)) return "image/webp";
    if (matchesAt(buffer, 8, WAVE_TAG)) return "audio/wav";
  }

  if (startsWith(buffer, GIF_MAGIC)) return "image/gif";

  // ISO Base Media File Format: MP4 / M4A / HEIC (ftyp box at offset 4)
  if (matchesAt(buffer, 4, FTYP_MAGIC)) {
    const brand = String.fromCharCode(
      buffer[8],
      buffer[9],
      buffer[10],
      buffer[11],
    );
    if (AUDIO_MP4_BRAND_PREFIXES.some((p) => brand.startsWith(p))) {
      return "audio/mp4";
    }
    if (HEIC_BRANDS.has(brand)) return "image/heic";
    // Default: treat remaining ftyp brands (isom, mp41, M4V, f4v, etc.) as
    // video. Audio in MP4 is recognised explicitly above; if the declared
    // content-type is `audio/mp4` for a brand that lands here, the
    // compatibility check downstream will reject it.
    return "video/mp4";
  }

  // WebM (EBML)
  if (startsWith(buffer, WEBM_MAGIC)) return "video/webm";

  // Ogg
  if (startsWith(buffer, OGG_MAGIC)) return "audio/ogg";

  // MP3 (ID3 tag, or raw frame sync)
  if (startsWith(buffer, ID3_MAGIC)) return "audio/mpeg";
  if (buffer[0] === 0xff && (buffer[1] & 0xe0) === 0xe0) return "audio/mpeg";

  return null;
}

/**
 * True if a file whose magic bytes were detected as `detected` is acceptable
 * when the client declared content-type `declared`.
 *
 * Cross-MIME equivalences (see ADR 026 §"Compatibility-equivalence rules"):
 * - HEIC and HEIF share the ftyp encoding; either declared MIME accepts a
 *   detected `image/heic`.
 * - WebM is a single ratified format used for both video and audio, but the
 *   server-side allow-list distinguishes them (`video/webm`, `audio/webm`).
 *   The bytes themselves cannot tell them apart without parsing codecs, so
 *   a detected `video/webm` is accepted for either declared `video/webm`
 *   or `audio/webm`.
 */
export function isContentTypeCompatible(
  declared: string,
  detected: string,
): boolean {
  const d = declared.toLowerCase();
  const x = detected.toLowerCase();
  if (d === x) return true;

  // HEIC / HEIF interchangeable
  if (
    (d === "image/heic" || d === "image/heif") &&
    (x === "image/heic" || x === "image/heif")
  ) {
    return true;
  }

  // WebM video/audio share a container; magic-byte alone can't distinguish
  if (x === "video/webm" && (d === "video/webm" || d === "audio/webm")) {
    return true;
  }

  return false;
}
