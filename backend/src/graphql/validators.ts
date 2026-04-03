import { GraphQLError } from "graphql";
import { isR2Configured, isR2Url, isLocalDevUrl } from "../storage/r2.js";

export const MAX_PASSWORD_LENGTH = 128;

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
