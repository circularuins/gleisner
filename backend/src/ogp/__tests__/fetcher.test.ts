/**
 * Unit tests for the OGP fetcher (Issue #188).
 *
 * `fetchOgpMetadata` is the public entry point. We mock `safeFetch` so the
 * tests stay deterministic — `safeFetch`'s own behaviour (DNS resolution,
 * redirects, timeouts, size limit) is covered separately in
 * `ssrf-guard.test.ts` and the integration tests under `routes/__tests__`.
 *
 * The tests below cover:
 * - Happy-path tag extraction (og:title / og:description / og:image / og:site_name)
 * - First-occurrence-wins for duplicate tags
 * - Sanitization (HTML stripping, control characters, length truncation)
 * - og:image https-only enforcement (mixed-content guard for Flutter Web)
 * - Tags outside <head> are ignored
 * - Errors from safeFetch surface as `null` (caller can fall back gracefully)
 */
import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("../ssrf-guard.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../ssrf-guard.js")>();
  return {
    ...actual,
    safeFetch: vi.fn(),
  };
});

import { fetchOgpMetadata } from "../fetcher.js";
import { safeFetch, SSRFError } from "../ssrf-guard.js";

const mockedSafeFetch = vi.mocked(safeFetch);

function html(...metas: string[]): string {
  return `<!doctype html><html><head>${metas.join("")}</head><body></body></html>`;
}

describe("fetchOgpMetadata", () => {
  beforeEach(() => {
    mockedSafeFetch.mockReset();
  });

  it("extracts all four OGP fields from a well-formed page", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        '<meta property="og:title" content="Hello World" />',
        '<meta property="og:description" content="A friendly greeting." />',
        '<meta property="og:image" content="https://example.com/img.png" />',
        '<meta property="og:site_name" content="Example" />',
      ),
    );

    const result = await fetchOgpMetadata("https://example.com/post");
    expect(result).toEqual({
      ogTitle: "Hello World",
      ogDescription: "A friendly greeting.",
      ogImage: "https://example.com/img.png",
      ogSiteName: "Example",
    });
  });

  it("accepts the `name` attribute as a fallback for `property`", async () => {
    // OGP spec uses `property=`, but a non-trivial number of pages emit
    // `name=` (Twitter-style). The fetcher accepts both.
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        '<meta name="og:title" content="From name attr" />',
        '<meta name="og:description" content="…" />',
      ),
    );

    const result = await fetchOgpMetadata("https://example.com/x");
    expect(result?.ogTitle).toBe("From name attr");
    expect(result?.ogDescription).toBe("…");
  });

  it("returns null when none of the meaningful tags are present", async () => {
    // Only og:site_name is present — not enough on its own to be considered
    // "a successful OGP read", per the fetcher's threshold.
    mockedSafeFetch.mockResolvedValueOnce(
      html('<meta property="og:site_name" content="Just a Site" />'),
    );
    expect(await fetchOgpMetadata("https://example.com/y")).toBeNull();
  });

  it("returns null on entirely empty <head>", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      "<html><head></head><body></body></html>",
    );
    expect(await fetchOgpMetadata("https://example.com/z")).toBeNull();
  });

  it("keeps the first occurrence when a tag is repeated", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        '<meta property="og:title" content="First" />',
        '<meta property="og:title" content="Second" />',
      ),
    );
    const result = await fetchOgpMetadata("https://example.com/dup");
    expect(result?.ogTitle).toBe("First");
  });

  it("ignores OGP-looking meta tags that appear OUTSIDE <head>", async () => {
    // The parser flips inHead off after </head>, so tags in <body> must not
    // poison the result. (HTML injection via user-controlled body content.)
    const trickHtml =
      "<html><head>" +
      '<meta property="og:title" content="From head" />' +
      "</head><body>" +
      '<meta property="og:title" content="Injected" />' +
      '<meta property="og:image" content="https://attacker.example/exploit.png" />' +
      "</body></html>";
    mockedSafeFetch.mockResolvedValueOnce(trickHtml);

    const result = await fetchOgpMetadata("https://example.com/inj");
    expect(result?.ogTitle).toBe("From head");
    // og:image was only present in body and should have been ignored
    expect(result?.ogImage).toBeNull();
  });

  it("strips HTML tags and zero-width / bidi control characters", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        // Embedded <script> (would not actually execute via meta content,
        // but the sanitizer strips it defensively)
        '<meta property="og:title" content="Hello <script>alert(1)</script> world" />',
        // Zero-width space (U+200B) and right-to-left override (U+202E)
        '<meta property="og:description" content="safe​‮text" />',
      ),
    );
    const result = await fetchOgpMetadata("https://example.com/sani");
    expect(result?.ogTitle).toBe("Hello alert(1) world");
    expect(result?.ogDescription).toBe("safetext");
  });

  it("truncates overlong values to their per-field maximum", async () => {
    const longTitle = "A".repeat(500); // > 200 limit
    const longDesc = "B".repeat(800); // > 500 limit
    const longSite = "C".repeat(300); // > 100 limit
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        `<meta property="og:title" content="${longTitle}" />`,
        `<meta property="og:description" content="${longDesc}" />`,
        `<meta property="og:site_name" content="${longSite}" />`,
      ),
    );
    const result = await fetchOgpMetadata("https://example.com/long");
    expect(result?.ogTitle).toHaveLength(200);
    expect(result?.ogDescription).toHaveLength(500);
    expect(result?.ogSiteName).toHaveLength(100);
  });

  it("rejects http:// og:image to prevent mixed-content blocks", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        '<meta property="og:title" content="ok" />',
        '<meta property="og:image" content="http://insecure.example/img.png" />',
      ),
    );
    const result = await fetchOgpMetadata("https://example.com/mixed");
    expect(result?.ogTitle).toBe("ok");
    expect(result?.ogImage).toBeNull();
  });

  it("rejects malformed og:image URLs", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        '<meta property="og:title" content="ok" />',
        '<meta property="og:image" content="not a url" />',
      ),
    );
    const result = await fetchOgpMetadata("https://example.com/bad-img");
    expect(result?.ogImage).toBeNull();
  });

  it("rejects non-http(s) og:image schemes (javascript:, data:)", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        '<meta property="og:title" content="ok" />',
        '<meta property="og:image" content="javascript:alert(1)" />',
      ),
    );
    const result1 = await fetchOgpMetadata("https://example.com/js");
    expect(result1?.ogImage).toBeNull();

    mockedSafeFetch.mockResolvedValueOnce(
      html(
        '<meta property="og:title" content="ok" />',
        '<meta property="og:image" content="data:image/png;base64,AAAA" />',
      ),
    );
    const result2 = await fetchOgpMetadata("https://example.com/data");
    expect(result2?.ogImage).toBeNull();
  });

  it("returns null when safeFetch throws SSRFError (caller falls back gracefully)", async () => {
    mockedSafeFetch.mockRejectedValueOnce(new SSRFError("Blocked: private IP"));
    const result = await fetchOgpMetadata("https://internal.example/x");
    expect(result).toBeNull();
  });

  it("returns null when safeFetch throws a generic error (timeout, parse failure, etc.)", async () => {
    mockedSafeFetch.mockRejectedValueOnce(new Error("aborted"));
    const result = await fetchOgpMetadata("https://slow.example/x");
    expect(result).toBeNull();
  });

  it("returns null on completely malformed HTML (parser tolerance check)", async () => {
    // htmlparser2 is lenient — this should just yield zero meta tags rather
    // than throwing. The fetcher should treat it as "no OGP data".
    mockedSafeFetch.mockResolvedValueOnce("<<<not-html>>>");
    expect(await fetchOgpMetadata("https://example.com/garbage")).toBeNull();
  });

  it("does not throw on attribute-less <meta> tags", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        "<meta />",
        "<meta>",
        '<meta charset="utf-8" />',
        '<meta property="og:title" content="ok" />',
      ),
    );
    const result = await fetchOgpMetadata("https://example.com/empty-meta");
    expect(result?.ogTitle).toBe("ok");
  });

  it("trims whitespace before truncating", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html('<meta property="og:title" content="   hello   " />'),
    );
    const result = await fetchOgpMetadata("https://example.com/trim");
    expect(result?.ogTitle).toBe("hello");
  });

  it("ignores meta tags whose content is empty", async () => {
    mockedSafeFetch.mockResolvedValueOnce(
      html(
        '<meta property="og:title" content="" />',
        '<meta property="og:description" content="real desc" />',
      ),
    );
    const result = await fetchOgpMetadata("https://example.com/empty");
    expect(result?.ogTitle).toBeNull();
    expect(result?.ogDescription).toBe("real desc");
  });
});
