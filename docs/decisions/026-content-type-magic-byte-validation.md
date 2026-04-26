# ADR 026: Content-Type Spoofing Mitigation via Magic-Byte Validation

## Status

Accepted

## Context

`backend/src/storage/r2.ts` issues presigned upload URLs to clients. The client declares a `contentType` argument, the backend validates it against a per-category allow-list (`ALLOWED_CONTENT_TYPES`), and the value is passed through to `PutObjectCommand.ContentType`. R2 stores that header verbatim and serves it back on `GET`.

A caller can therefore:

1. Declare `contentType: "image/heic"` (passes the allow-list).
2. Upload a payload whose actual bytes are SVG, HTML, or JavaScript.
3. R2 serves the bytes with `Content-Type: image/heic` — but with browser-side content sniffing, an embed in another origin, or a curated public URL, the file can be coerced into rendering / executing as something else (stored XSS).

PR #253 extended HEIC/HEIF acceptance to all three categories (`avatars`, `covers`, `media`). The review (signal 82 / Critical) flagged that the broader allow-list slightly enlarges the attack surface and asked that this gap be closed before any production launch (Phase 0 family release on GW).

The frontend currently mitigates the worst case by re-encoding HEIC → JPEG before upload via `heic_converter.dart`, but only on Web. Direct API calls and any future native upload path skip that mitigation entirely. We need a server-side defence that does not depend on a particular client.

## Considered options

### Option 1 — Server-side re-encode

Pull the uploaded image, decode + re-encode (Sharp / libvips), re-upload with the canonical content-type.

- ✅ Strongest guarantee — output bytes are produced by our encoder, not the client
- ❌ Adds `sharp` (libvips) native dependency to the Railway build, increasing image size + cold-start
- ❌ Costs CPU per upload (Phase 0 traffic is family-scale, but Phase 1 budget is uncertain)
- ❌ Lossy for already-optimised images
- ❌ Doesn't help video/audio categories

### Option 2 — Magic-byte verification on upload completion (chosen)

When the client confirms an upload via the existing GraphQL mutation that stores the URL (`createPost`, `updatePost`, `updateMe`, `updateMyArtist`), fetch the object's first ~64 bytes from R2 (`Range: bytes=0-63`), validate the magic bytes against the declared content-type, and `DeleteObject` + reject if they do not match.

- ✅ Smallest scope: one new helper, one new test file, ~5 mutation callsites
- ✅ Reuses existing infrastructure (R2 SDK, presigned upload flow, content-type allow-list)
- ✅ Covers every category (image/video/audio) uniformly — magic bytes exist for all of them
- ✅ Adds one HEAD-equivalent + range GET per upload (negligible at Phase 0 scale; cheap even at Phase 1 because R2 egress is free)
- ⚠️ TOCTOU window between upload and validation — acceptable because the URL is not persisted to any user-visible state until validation passes
- ⚠️ Does not protect against polyglot files where the same prefix is valid for multiple types — but image/audio/video format families have non-overlapping magic prefixes in practice

### Option 3 — CDN policy (X-Content-Type-Options: nosniff + Content-Disposition: attachment)

Use Cloudflare Transform Rules to add `X-Content-Type-Options: nosniff` to all media responses (and optionally `Content-Disposition: attachment` on user-content domains).

- ✅ Cheap, no application code changes
- ✅ Defence-in-depth value retained even if validation is added
- ❌ Doesn't prevent the bad bytes from being served — only prevents browser sniffing on direct navigation
- ❌ Doesn't help when the file is embedded by a malicious page that controls its own headers
- ❌ Doesn't help downstream consumers (e.g. native apps, third-party clients, federation peers in a Phase 2+ world)

## Decision

Adopt **Option 2 (magic-byte validation)** for Phase 0.

Option 3 (`X-Content-Type-Options: nosniff` Transform Rule) is also worth setting up at the same time as a no-cost belt-and-braces measure, but it is documented under `docs/infrastructure.md` rather than tracked here — it's a Cloudflare-side change, not application code.

Option 1 (re-encode) is deferred to a future Issue if and when polyglot or malformed-but-valid-prefix files become an observed problem. Magic-byte validation is sufficient for the realistic threat model (a careless or hostile client trying to upload arbitrary bytes labelled as a known image/audio/video MIME).

### Implementation

1. New helper `backend/src/storage/magic-bytes.ts` — `detectMimeFromMagicBytes(buffer: Uint8Array): string | null`. Recognises every entry in `ALLOWED_CONTENT_TYPES` (JPEG, PNG, GIF, WebP, HEIC/HEIF brand variants, MP4 brand variants for video and audio, WebM, MP3 with or without ID3, OGG, WAV).
2. New helper `validateUploadedR2Object(url, declaredContentType)` in `backend/src/storage/r2.ts`. Fetches `bytes=0-63`, runs `detectMimeFromMagicBytes`, raises `R2ValidationError` if the detected type is incompatible with the declared one. On error, `DeleteObject` is invoked fire-and-forget so failed uploads are not orphaned.
3. Wire the validator into the five mutation callsites that persist a URL: `createPost.mediaUrl`, `createPost.mediaUrls[*]`, `updatePost.mediaUrl`, `updateMe.avatarUrl`, `updateMyArtist.{avatarUrl,coverUrl}`. (`generateUploadUrl` itself stays untouched — validation happens at completion, not at signing.)
4. Tests:
   - `magic-bytes.test.ts` — every entry in `ALLOWED_CONTENT_TYPES` produces a recognised detection; SVG/HTML/JS payloads labelled as `image/jpeg` produce a mismatch.
   - `r2.test.ts` — covers the no-op paths (R2 unconfigured, non-R2 URLs). Full SDK glue (ranged `GetObject` round-trip, `ContentType` / `Body` parsing, fire-and-forget `DeleteObject` on mismatch) is **deferred to Issue #278** because mocking the singleton `S3Client` requires either `aws-sdk-client-mock` or a DI seam — both expand scope beyond the security fix. The no-op paths and the magic-byte rules are covered here; the SDK glue itself is small and will be exercised end-to-end on Phase 0 deploy.
   - `post.test.ts` (and equivalent for artist/user mutations) — existing mutation tests pass unchanged because the test env has R2 unconfigured, which short-circuits the new check.

### Compatibility-equivalence rules

- `image/heic` and `image/heif` share the ftyp box format. Detected ftyp brands `heic`, `heif`, `heix`, `mif1`, `msf1`, `heis` are all classified as `image/heic` and accepted under either declared MIME (mirrors the frontend `mimeFromBytes` rule pinned by PR #253). The HEVC video brands `hevc` / `hevx` are intentionally classified as `video/mp4`, **not** as still images, and are therefore rejected when the declared MIME is `image/heic` or `image/heif` — uploading HEVC video into an image slot is exactly the spoofing case this validator is meant to catch.
- `audio/mp4` and `video/mp4` share ftyp; we distinguish them by accepted brand prefix. M4A / M4B / M4P brands are classified as `audio/mp4`; `isom`, `mp41`, `mp42`, `avc1`, etc. are classified as `video/mp4`.
- WebP is detected as `RIFF....WEBP`; declared content-type must be exactly `image/webp`. RIFF + `WAVE` is `audio/wav`. RIFF with any other tag (e.g. AVI) is rejected.
- WebM / EBML cannot be split into video vs audio without parsing codecs. A detected `video/webm` is therefore accepted under either declared `video/webm` or `audio/webm`.

## Consequences

### Positive

- Eliminates the spoofing class of attack at upload time, before any client (browser, native, federation peer) is exposed to mismatched content.
- All allowed media types are covered uniformly — adding a new entry to `ALLOWED_CONTENT_TYPES` requires adding a magic-byte rule, which surfaces the security consideration in code review.
- Failed uploads are deleted from R2 immediately, so the orphan-cleanup batch (Issue #230) doesn't need to handle this case.

### Negative

- Adds one R2 read per upload. At Phase 0 scale (family of 5, < 100 uploads / day), the cost is rounding error. At Phase 1 scale, R2 reads are still cheap (free egress, $0.36 per million Class B requests). Update mutations skip the GET when the URL is unchanged from the DB row, so re-saving a profile or post without touching media doesn't pay the cost again.
- `magic-bytes.ts` becomes a parallel implementation of the same rules in `frontend/lib/utils/mime_from_bytes.dart`. The two must be kept in sync; the test suite makes drift loud.
- The TOCTOU window between PUT-complete and validation is small but non-zero. Mitigated by not persisting the URL until validation passes — the worst that can happen is a race within a single mutation, where both the validator and an attacker race for the same key. The attacker would need credentials for the user's presigned URL and would gain nothing by replacing valid bytes with invalid ones (the validator would then delete both).
- **Partial-failure orphans.** `assertUploadedR2ObjectsMatch` runs per-URL checks in parallel with `Promise.all`. If one URL fails magic-byte validation, the failing object is deleted fire-and-forget, but other URLs that already passed (or were still in flight and complete after the rejection) remain in R2 — the mutation aborts so no DB row references them. These orphans are not cleaned up by this validator; they rely on the future R2-orphan batch job (Issue #230). For Phase 0 this is acceptable because partial failures from a normal client are rare (the frontend uploads all images before issuing the mutation, so either all are well-formed or the client itself was misbehaving).

## References

- Issue #269 — request to close the spoofing gap before launch
- PR #253 — HEIC/HEIF allow-list extension that prompted this ADR
- ADR 020 — security architecture (high-level posture)
- ADR 025 — media handling strategy (the allow-list itself)
- `frontend/lib/utils/mime_from_bytes.dart` — frontend counterpart
