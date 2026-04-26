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
