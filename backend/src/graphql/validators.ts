import { GraphQLError } from "graphql";

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
