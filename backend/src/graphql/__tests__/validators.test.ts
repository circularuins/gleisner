import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// Mock R2 so validateMediaUrl accepts localhost URLs.
// Also mock `validateUploadedR2Object` so the
// `assertUploadedR2ObjectsMatch` tests below can drive specific
// pass / fail outcomes per URL without touching the network.
vi.mock("../../storage/r2.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../storage/r2.js")>();
  return {
    ...actual,
    isR2Configured: vi.fn(() => false),
    validateUploadedR2Object: vi.fn(async () => {}),
  };
});

import {
  ageFromBirthYearMonth,
  validateMediaUrls,
  MAX_IMAGES_PER_POST,
  assertUploadedR2ObjectsMatch,
  assertUploadedR2ObjectMatches,
  validateUUID,
} from "../validators.js";
import { GraphQLError } from "graphql";
import {
  validateUploadedR2Object,
  R2ValidationError,
} from "../../storage/r2.js";

const mockedValidate = vi.mocked(validateUploadedR2Object);

describe("ageFromBirthYearMonth", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("calculates age when birthday month has passed", () => {
    // 2026-06-15, birth: 2000-01 → age 26
    vi.setSystemTime(new Date("2026-06-15"));
    expect(ageFromBirthYearMonth("2000-01")).toBe(26);
  });

  it("calculates age when birthday month has not yet passed", () => {
    // 2026-03-15, birth: 2000-06 → age 25 (not yet 26)
    vi.setSystemTime(new Date("2026-03-15"));
    expect(ageFromBirthYearMonth("2000-06")).toBe(25);
  });

  it("calculates age when birthday is current month", () => {
    // 2026-06-15, birth: 2000-06 → age 26 (month matches)
    vi.setSystemTime(new Date("2026-06-15"));
    expect(ageFromBirthYearMonth("2000-06")).toBe(26);
  });

  it("handles December birth tested in January", () => {
    // 2027-01-10, birth: 2014-12 → age 12 (Dec has passed)
    vi.setSystemTime(new Date("2027-01-10"));
    expect(ageFromBirthYearMonth("2014-12")).toBe(12);
  });

  it("handles January birth tested in December", () => {
    // 2026-12-15, birth: 2014-01 → age 12
    vi.setSystemTime(new Date("2026-12-15"));
    expect(ageFromBirthYearMonth("2014-01")).toBe(12);
  });

  it("returns 12 for child just under 13 (COPPA boundary)", () => {
    // 2026-06-15, birth: 2013-07 → age 12 (not yet 13)
    vi.setSystemTime(new Date("2026-06-15"));
    expect(ageFromBirthYearMonth("2013-07")).toBe(12);
  });

  it("returns 13 for child just turned 13 (COPPA boundary)", () => {
    // 2026-06-15, birth: 2013-06 → age 13
    vi.setSystemTime(new Date("2026-06-15"));
    expect(ageFromBirthYearMonth("2013-06")).toBe(13);
  });
});

describe("validateMediaUrls", () => {
  it("accepts a single valid URL", () => {
    expect(() =>
      validateMediaUrls(["http://localhost:4000/img.jpg"]),
    ).not.toThrow();
  });

  it("accepts exactly MAX_IMAGES_PER_POST URLs", () => {
    const urls = Array.from(
      { length: MAX_IMAGES_PER_POST },
      (_, i) => `http://localhost:4000/img${i}.jpg`,
    );
    expect(() => validateMediaUrls(urls)).not.toThrow();
  });

  it("rejects empty array", () => {
    expect(() => validateMediaUrls([])).toThrow("At least one image");
  });

  it("rejects more than MAX_IMAGES_PER_POST URLs", () => {
    const urls = Array.from(
      { length: MAX_IMAGES_PER_POST + 1 },
      (_, i) => `http://localhost:4000/img${i}.jpg`,
    );
    expect(() => validateMediaUrls(urls)).toThrow("at most");
  });

  it("rejects invalid URL in array", () => {
    expect(() => validateMediaUrls(["not-a-url"])).toThrow();
  });
});

// Issue #278 (item 8) — `Promise.allSettled` semantics + universal
// `[SECURITY]` logging. Drives the validator with a mocked R2 helper so
// each URL's outcome is independently controllable.
describe("assertUploadedR2ObjectsMatch", () => {
  let consoleErrorSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    mockedValidate.mockReset();
    mockedValidate.mockResolvedValue(undefined);
    consoleErrorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    consoleErrorSpy.mockRestore();
  });

  it("resolves immediately for an empty URL list (no validator calls)", async () => {
    await expect(assertUploadedR2ObjectsMatch([])).resolves.toBeUndefined();
    expect(mockedValidate).not.toHaveBeenCalled();
  });

  it("calls the per-URL validator for every URL", async () => {
    const urls = [
      "https://r2.example/a.jpg",
      "https://r2.example/b.jpg",
      "https://r2.example/c.jpg",
    ];
    await assertUploadedR2ObjectsMatch(urls);
    expect(mockedValidate).toHaveBeenCalledTimes(3);
    for (const url of urls) {
      expect(mockedValidate).toHaveBeenCalledWith(url);
    }
  });

  it("does not short-circuit on the first failure (all URLs are awaited)", async () => {
    // Sequence: fail / pass / fail. Promise.all would short-circuit after
    // the first; Promise.allSettled awaits all three.
    mockedValidate
      .mockRejectedValueOnce(new R2ValidationError("spoof A"))
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(new R2ValidationError("spoof C"));

    await expect(
      assertUploadedR2ObjectsMatch([
        "https://r2.example/a.jpg",
        "https://r2.example/b.jpg",
        "https://r2.example/c.jpg",
      ]),
    ).rejects.toBeInstanceOf(GraphQLError);

    expect(mockedValidate).toHaveBeenCalledTimes(3);
  });

  it("logs every failure with [SECURITY] prefix (multi-URL forensics)", async () => {
    mockedValidate
      .mockRejectedValueOnce(new R2ValidationError("spoof A"))
      .mockRejectedValueOnce(new R2ValidationError("spoof B"));

    await expect(
      assertUploadedR2ObjectsMatch([
        "https://r2.example/a.jpg",
        "https://r2.example/b.jpg",
      ]),
    ).rejects.toThrow();

    const securityLogs = consoleErrorSpy.mock.calls.filter(
      (args: unknown[]) =>
        typeof args[0] === "string" && args[0].includes("[SECURITY]"),
    );
    expect(securityLogs).toHaveLength(2);
  });

  // Critical fix from PR #282 review: the previous `errors.length > 1`
  // guard suppressed the [SECURITY] log when only one URL failed —
  // exactly the single-file spoof case the validator is meant to catch.
  it("logs even a single-URL failure with [SECURITY] prefix (Critical regression guard)", async () => {
    mockedValidate.mockRejectedValueOnce(new R2ValidationError("solo spoof"));

    await expect(
      assertUploadedR2ObjectsMatch(["https://r2.example/only.jpg"]),
    ).rejects.toThrow();

    const securityLogs = consoleErrorSpy.mock.calls.filter(
      (args: unknown[]) =>
        typeof args[0] === "string" && args[0].includes("[SECURITY]"),
    );
    expect(securityLogs).toHaveLength(1);
  });

  it("re-throws the FIRST error (not the last) so the GraphQL caller's contract is preserved", async () => {
    mockedValidate
      .mockRejectedValueOnce(new R2ValidationError("first"))
      .mockRejectedValueOnce(new R2ValidationError("second"));

    let captured: unknown;
    try {
      await assertUploadedR2ObjectsMatch([
        "https://r2.example/a.jpg",
        "https://r2.example/b.jpg",
      ]);
    } catch (err) {
      captured = err;
    }
    expect(captured).toBeInstanceOf(GraphQLError);
    expect((captured as GraphQLError).message).toBe("first");
  });

  it("preserves GraphQLError type when wrapping internal R2ValidationError", async () => {
    mockedValidate.mockRejectedValueOnce(new R2ValidationError("bad type"));
    await expect(
      assertUploadedR2ObjectMatches("https://r2.example/x.jpg"),
    ).rejects.toBeInstanceOf(GraphQLError);
  });
});

// PR-B G5: stop malformed UUIDs from reaching `eq(..., args.id)` so Postgres'
// `invalid input syntax for type uuid` cannot leak as a GraphQL error message,
// and so basic enumeration probes that engage DB error paths are short-circuited.
describe("validateUUID", () => {
  // Lower-case canonical, the form Postgres emits.
  it("accepts a lowercase RFC 4122 UUID (v4 canonical)", () => {
    expect(() =>
      validateUUID("550e8400-e29b-41d4-a716-446655440000", "post id"),
    ).not.toThrow();
  });

  // Postgres returns lowercase, but clients may pass either case; both must pass.
  it("accepts an uppercase UUID (case-insensitive)", () => {
    expect(() =>
      validateUUID("550E8400-E29B-41D4-A716-446655440000", "post id"),
    ).not.toThrow();
  });

  // PG accepts any UUID variant — v1, v4, v7 — so the check must be
  // version-agnostic. Drizzle stores them all as `uuid` regardless of variant.
  it.each([
    ["v1", "6fa459ea-ee8a-11de-9264-0800200c9a66"],
    ["v4", "f47ac10b-58cc-4372-a567-0e02b2c3d479"],
    ["v7", "01890c6f-9c8b-7c5e-9f3a-3a2b1c0d4e5f"],
  ])("accepts a valid UUID%s", (_, uuid) => {
    expect(() => validateUUID(uuid, "post id")).not.toThrow();
  });

  it("rejects empty string", () => {
    expect(() => validateUUID("", "post id")).toThrow(GraphQLError);
    expect(() => validateUUID("", "post id")).toThrow("Invalid post id");
  });

  it("rejects strings missing dashes (no group separators)", () => {
    expect(() =>
      validateUUID("550e8400e29b41d4a716446655440000", "post id"),
    ).toThrow(GraphQLError);
  });

  it("rejects strings shorter than 36 chars", () => {
    expect(() =>
      validateUUID("550e8400-e29b-41d4-a716-44665544000", "post id"),
    ).toThrow(GraphQLError);
  });

  it("rejects strings longer than 36 chars", () => {
    expect(() =>
      validateUUID("550e8400-e29b-41d4-a716-4466554400000", "post id"),
    ).toThrow(GraphQLError);
  });

  it("rejects strings with non-hex characters", () => {
    expect(() =>
      validateUUID("zzzzzzzz-e29b-41d4-a716-446655440000", "post id"),
    ).toThrow(GraphQLError);
  });

  it("rejects strings with wrong group lengths (8-4-4-4-12 violation)", () => {
    expect(() =>
      validateUUID("550e840-e29b-41d4-a716-4466554400000", "post id"),
    ).toThrow(GraphQLError);
  });

  // Belt-and-braces — GraphQL's `String!` schema check rejects non-strings
  // before the resolver runs, but the validator is also called from internal
  // helpers that don't share that contract.
  it("rejects non-string values (defensive)", () => {
    expect(() => validateUUID(42 as unknown, "post id")).toThrow(GraphQLError);
    expect(() => validateUUID(null as unknown, "post id")).toThrow(
      GraphQLError,
    );
    expect(() => validateUUID(undefined as unknown, "post id")).toThrow(
      GraphQLError,
    );
    expect(() => validateUUID({} as unknown, "post id")).toThrow(GraphQLError);
  });

  // fieldName interpolation matters because `createConnection` passes both
  // `sourceId` and `targetId` through validateUUID — a generic message would
  // not tell the client which arg was rejected.
  it("interpolates fieldName into the error message", () => {
    expect(() => validateUUID("not-a-uuid", "track id")).toThrow(
      "Invalid track id",
    );
    expect(() => validateUUID("not-a-uuid", "source post id")).toThrow(
      "Invalid source post id",
    );
  });

  it("does NOT include the rejected value in the error message", () => {
    // Don't echo unverified input back — keeps log lines from carrying
    // attacker-controlled bytes and avoids reflected-XSS-shaped surface in
    // any client that renders error messages without escaping.
    const evil = "<script>alert(1)</script>";
    try {
      validateUUID(evil, "post id");
      throw new Error("expected validateUUID to throw");
    } catch (err) {
      expect(err).toBeInstanceOf(GraphQLError);
      expect((err as GraphQLError).message).toBe("Invalid post id");
      expect((err as GraphQLError).message).not.toContain(evil);
    }
  });

  // Code-based discrimination is the contract clients should rely on, not
  // the human-readable message. Without this assertion a future fieldName
  // rename would silently change the wire surface for every consumer.
  it("emits extensions.code = BAD_USER_INPUT", () => {
    try {
      validateUUID("not-a-uuid", "post id");
      throw new Error("expected validateUUID to throw");
    } catch (err) {
      expect(err).toBeInstanceOf(GraphQLError);
      expect((err as GraphQLError).extensions?.code).toBe("BAD_USER_INPUT");
    }
  });
});
