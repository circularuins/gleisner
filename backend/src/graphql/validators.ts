import { GraphQLError } from "graphql";
import {
  isR2Configured,
  isR2Url,
  isLocalDevUrl,
  validateUploadedR2Object,
  R2ValidationError,
} from "../storage/r2.js";

export const MAX_PASSWORD_LENGTH = 128;
export const MAX_IMAGES_PER_POST = 10;

/** Media duration limits in seconds (ADR 025) */
export const MAX_VIDEO_DURATION_SECONDS = 60; // 1 minute
export const MAX_AUDIO_DURATION_SECONDS = 300; // 5 minutes
export const MAX_GENERIC_DURATION_SECONDS = 86400; // 24 hours (fallback)

/** Validate duration against media-type-specific limits (ADR 025). */
export function validateDuration(duration: number, mediaType: string): void {
  if (duration < 0) {
    throw new GraphQLError("Duration must not be negative");
  }
  const maxDuration =
    mediaType === "video"
      ? MAX_VIDEO_DURATION_SECONDS
      : mediaType === "audio"
        ? MAX_AUDIO_DURATION_SECONDS
        : MAX_GENERIC_DURATION_SECONDS;
  if (duration > maxDuration) {
    throw new GraphQLError(
      `Duration exceeds the ${maxDuration}-second limit for ${mediaType} posts`,
    );
  }
}

/** Validate that a URL uses http or https protocol. Prevents javascript:/data: XSS vectors. */
export function validateUrl(url: string): void {
  try {
    const parsed = new URL(url);
    if (!["https:", "http:"].includes(parsed.protocol)) {
      throw new GraphQLError("URL must use http or https");
    }
  } catch (err) {
    if (err instanceof GraphQLError) throw err;
    throw new GraphQLError("Invalid URL format");
  }
}

/**
 * Validate that a media URL points to an allowed storage domain.
 *
 * - When R2 is configured (production): only R2 public domain URLs are accepted.
 * - When R2 is not configured (local dev): only localhost URLs are accepted.
 *
 * This prevents external URL injection in both environments.
 */
export function validateMediaUrl(url: string): void {
  validateUrl(url);
  if (isR2Configured()) {
    if (!isR2Url(url)) {
      throw new GraphQLError(
        "Media URLs must point to the configured storage domain",
      );
    }
  } else {
    if (!isLocalDevUrl(url)) {
      throw new GraphQLError(
        "Media URLs must point to localhost when storage is not configured",
      );
    }
  }
}

/**
 * Validate an array of media URLs for multi-image posts.
 * Checks count limit and validates each URL against R2 domain.
 */
export function validateMediaUrls(urls: string[]): void {
  if (urls.length === 0) {
    throw new GraphQLError("At least one image is required");
  }
  if (urls.length > MAX_IMAGES_PER_POST) {
    throw new GraphQLError(
      `A post can have at most ${MAX_IMAGES_PER_POST} images`,
    );
  }
  for (const url of urls) {
    validateMediaUrl(url);
  }
}

/**
 * Verify that the bytes already uploaded to R2 at `url` actually match the
 * content-type declared at upload time (Issue #269 / ADR 026 — Option 2).
 *
 * Wraps `validateUploadedR2Object` so the GraphQL layer raises
 * `GraphQLError` (safe to expose) instead of `R2ValidationError`.
 * Internal AWS / SDK errors are logged and surfaced as a generic
 * "Failed to verify uploaded file" so SDK internals don't leak.
 *
 * No-op when R2 is not configured or the URL is not an R2 URL — local dev
 * with localhost-served fixtures bypasses this check the same way
 * `validateMediaUrl` permits localhost URLs.
 *
 * Callers must invoke this AFTER `validateMediaUrl(url)` (so the URL is
 * known to be a same-origin R2 URL) and BEFORE persisting the URL to any
 * user-visible state. On failure, the R2 object is also deleted
 * fire-and-forget by the underlying helper to avoid orphans.
 */
export async function assertUploadedR2ObjectMatches(
  url: string,
): Promise<void> {
  try {
    await validateUploadedR2Object(url);
  } catch (err) {
    if (err instanceof R2ValidationError) {
      throw new GraphQLError(err.message);
    }
    if (err instanceof GraphQLError) throw err;
    console.error("[assertUploadedR2ObjectMatches] internal error:", err);
    throw new GraphQLError("Failed to verify uploaded file");
  }
}

/**
 * Apply `assertUploadedR2ObjectMatches` to each URL in parallel.
 *
 * No-op (resolves immediately) when `urls` is empty.
 *
 * Per-URL checks run concurrently (serial form was up to 10× the round-trip
 * latency at MAX_IMAGES_PER_POST = 10, with no ordering dependency).
 * `Promise.allSettled` is used instead of `Promise.all` so we collect EVERY
 * failure rather than only the first — under a coordinated multi-file
 * spoofing attempt this turns one log line into N, which makes forensics
 * (Issue #230 R2 orphan sweeper) much easier (Issue #278 item 8).
 *
 * The first encountered error is re-thrown so the GraphQL caller still gets
 * a single rejection. EVERY failure is logged with [SECURITY] prefix
 * server-side — including single-URL failures, since a one-file spoof
 * attempt is just as worth flagging as a multi-file one.
 *
 * Latency: in the all-success case, bounded by the slowest URL (same as
 * `Promise.all`). In the failure case, `Promise.allSettled` waits for ALL
 * in-flight checks rather than short-circuiting on the first rejection —
 * at MAX_IMAGES_PER_POST = 10 this can multiply the failure-case response
 * time by up to 10×. The trade-off is acceptable because (a) failed
 * mutations don't write any DB state, and (b) the full failure log set
 * is the primary forensic output. If this becomes an availability
 * problem (it shouldn't — round-trips target R2's same-AZ HEAD/range
 * latency), Issue #278 item 4 (per-URL AbortSignal timeout) is the
 * natural follow-up.
 *
 * Partial-failure consequence: each failing URL's R2 object is deleted
 * fire-and-forget by `validateUploadedR2Object`. Successful URLs that
 * complete before the mutation aborts remain in R2 — these orphans rely
 * on the future R2-orphan batch job (Issue #230).
 */
export async function assertUploadedR2ObjectsMatch(
  urls: string[],
): Promise<void> {
  if (urls.length === 0) return;
  const results = await Promise.allSettled(
    urls.map((url) => assertUploadedR2ObjectMatches(url)),
  );
  const errors = results.filter(
    (r): r is PromiseRejectedResult => r.status === "rejected",
  );
  if (errors.length === 0) return;

  // Log every failure (including the single-error case) so a one-file
  // spoof attempt still leaves a forensic trail.
  for (const err of errors) {
    console.error(
      "[SECURITY][assertUploadedR2ObjectsMatch] validation failure:",
      err.reason,
    );
  }
  // Re-throw the first error so the caller's contract (single rejection)
  // is preserved. GraphQLError vs other types is preserved via re-throw.
  throw errors[0].reason;
}

/**
 * RFC 4122 UUID format: 8-4-4-4-12 hex digits.
 * Accepts any version (v1/v4/v7) and both upper/lower case hex.
 *
 * Strict format check before passing untrusted input to `eq(..., args.id)` /
 * Drizzle parameter binding. Without this, malformed strings reach Postgres
 * and trigger `invalid input syntax for type uuid` errors that surface raw DB
 * details (driver name, query fragments) through GraphQL errors. The check
 * also stops basic enumeration probes that rely on engaging DB error paths.
 *
 * @internal Internal to validators.ts — call `validateUUID` instead. Kept
 * file-private (no `export`) so future refactors can move to a more
 * targeted regex (e.g. version-specific) without breaking call sites.
 */
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Validate that a value is a well-formed RFC 4122 UUID.
 *
 * `fieldName` is rendered into the error message so multi-arg resolvers
 * (e.g. `createConnection(sourceId, targetId)`) tell the client which
 * argument is malformed without exposing the rejected value itself.
 *
 * Convention: pass a human-readable, lower-case, space-separated phrase
 * (`"post id"`, `"track id"`, `"source post id"`). The substring is used
 * verbatim as `Invalid <fieldName>`, and is asserted by tests
 * (`__tests__/validators.test.ts`, `__tests__/track-author-visibility.test.ts`),
 * so renaming a field name is a contract change — match the existing tone.
 */
export function validateUUID(value: unknown, fieldName: string): void {
  if (typeof value !== "string" || !UUID_REGEX.test(value)) {
    // `extensions.code: BAD_USER_INPUT` lets clients (Apollo / urql /
    // graphql-request) match on the code rather than the message string —
    // important because `validateUUID` is now applied to ~20 resolvers and
    // any future `fieldName` rename would be a silent contract break for
    // anyone parsing `error.message`.
    throw new GraphQLError(`Invalid ${fieldName}`, {
      extensions: { code: "BAD_USER_INPUT" },
    });
  }
}

const VALID_POST_VISIBILITY = ["public", "draft"] as const;
const VALID_PROFILE_VISIBILITY = ["public", "private"] as const;

/** Validate post visibility value. Throws GraphQLError if invalid. */
export function validatePostVisibility(value: string): void {
  if (!(VALID_POST_VISIBILITY as readonly string[]).includes(value)) {
    throw new GraphQLError("visibility must be 'public' or 'draft'");
  }
}

/** Validate profile visibility value. Throws GraphQLError if invalid. */
export function validateProfileVisibility(value: string): void {
  if (!(VALID_PROFILE_VISIBILITY as readonly string[]).includes(value)) {
    throw new GraphQLError("profileVisibility must be 'public' or 'private'");
  }
}

const BIRTH_YEAR_MONTH_REGEX = /^\d{4}-(0[1-9]|1[0-2])$/;

/** Validate birthYearMonth format (YYYY-MM). Throws GraphQLError if invalid. */
export function validateBirthYearMonth(value: string): void {
  if (!BIRTH_YEAR_MONTH_REGEX.test(value)) {
    throw new GraphQLError("birthYearMonth must be in YYYY-MM format");
  }
  const year = parseInt(value.split("-")[0]);
  const currentYear = new Date().getFullYear();
  if (year < 1900 || year > currentYear) {
    throw new GraphQLError("Invalid birth year");
  }
}

/** Calculate age from YYYY-MM birth date. Uses year+month for accuracy. */
export function ageFromBirthYearMonth(value: string): number {
  const [year, month] = value.split("-").map(Number);
  const now = new Date();
  let age = now.getFullYear() - year;
  // If birth month hasn't occurred yet this year, subtract 1
  if (now.getMonth() + 1 < month) {
    age--;
  }
  return age;
}

/**
 * Maximum UTF-16 code-unit length permitted for a reaction emoji string
 * after trimming. Long enough to accommodate ZWJ sequences such as
 * 👨‍👩‍👧‍👦 (11 code units), 👨🏻‍❤️‍💋‍👨🏿 (17), the longest
 * RGI sequences in current Unicode emoji data (~24), and a small headroom
 * for future Unicode revisions, while still bounding storage on the
 * unique-keyed `(post_id, user_id, emoji)` row. Must match `varchar(64)`
 * on `reactions.emoji` and `milestone_reactions.emoji` (see
 * `db/schema/reaction.ts` / `milestone-reaction.ts`).
 *
 * Note on units: this limit counts JavaScript `String.length` (UTF-16
 * code units), whereas PostgreSQL `varchar(64)` counts Unicode
 * codepoints. A single 4-byte emoji (e.g. 🔥, U+1F525) is 2 code units
 * here but 1 codepoint in Postgres, so anything we accept always fits
 * the column. There is no input we reject that the DB would accept,
 * and no input we accept that the DB would truncate. Future allowlist
 * work (Idea 004 paid packs) should keep this asymmetry in mind when
 * picking a stricter bound.
 */
export const MAX_EMOJI_LENGTH = 64;

/**
 * Reject Unicode control and bidirectional / format characters that have no
 * place in a reaction emoji string. The picker UI (emoji_picker_flutter)
 * cannot produce these, so any input containing them is either a non-picker
 * client or an attempt to embed invisible payload. Specifically:
 *
 * - U+0000-U+001F, U+007F-U+009F: C0 / C1 control chars (NUL, LF,
 *   DEL, etc.). Break logs, JSON, and screen reader output.
 * - U+200B (ZWSP), U+200C (ZWNJ), U+200E (LRM), U+200F (RLM):
 *   zero-width space / non-joiner and bidirectional marks. Hide payload
 *   inside what looks like a single emoji and can flip line direction in
 *   adjacent UI text. ZWJ (U+200D) is INTENTIONALLY EXCLUDED —
 *   family / profession emoji depend on it (e.g. man + ZWJ + woman + ZWJ
 *   + girl + ZWJ + boy renders as a single family glyph).
 * - U+202A-U+202E, U+2066-U+2069: bidi override / isolate. Allow an
 *   attacker to render reaction text as right-to-left or override visual
 *   ordering of surrounding labels (Trojan Source family).
 * - U+FEFF: byte-order mark / ZWNBSP. Same hiding-payload concern as ZWSP.
 *
 * Variation selectors (U+FE00-U+FE0F) are kept (e.g. heart + VS-16 = ❤️).
 */
const REACTION_EMOJI_FORBIDDEN_RE =
  // eslint-disable-next-line no-control-regex
  /[\u0000-\u001F\u007F-\u009F\u200B\u200C\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]/;

/**
 * Validate a reaction emoji string.
 *
 * Returns the trimmed value so callers can persist exactly what was checked
 * (avoid the accidental "validate trimmed, store untrimmed" footgun).
 *
 * Phase 0 keeps the value space free-form within the length / forbidden-char
 * envelope: the picker constrains the input on the client, and the family
 * Phase 0 deployment has no need for a server-side allowlist. Phase 1's
 * default-set / paid-pack model (Idea 004) is the natural place to add an
 * allowlist; this helper is the single point that needs to change.
 */
export function validateEmoji(value: unknown): string {
  if (typeof value !== "string") {
    throw new GraphQLError("Emoji is required");
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw new GraphQLError("Emoji is required");
  }
  if (trimmed.length > MAX_EMOJI_LENGTH) {
    throw new GraphQLError(
      `Emoji must be ${MAX_EMOJI_LENGTH} characters or less`,
    );
  }
  if (REACTION_EMOJI_FORBIDDEN_RE.test(trimmed)) {
    throw new GraphQLError("Emoji contains disallowed characters");
  }
  return trimmed;
}

const COPPA_MIN_AGE = 13;

/**
 * Validate that a self-signup user is at least 13 (COPPA).
 * Under-13 users must be created via guardian's createChildAccount.
 */
export function validateSignupAge(birthYearMonth: string): void {
  const age = ageFromBirthYearMonth(birthYearMonth);
  if (age < COPPA_MIN_AGE) {
    throw new GraphQLError(
      "You must be at least 13 to create an account. " +
        "Please ask your parent or guardian to create an account for you.",
    );
  }
}
