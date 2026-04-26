/**
 * Unit tests for the SSRF guard (Issue #188).
 *
 * `isPrivateIP` is a pure function — exhaustive table-driven coverage is the
 * cheapest way to lock down the boundaries (10/8, 172.16/12, 192.168/16,
 * 127/8, 0/8, 169.254/16, 100.64/10, IPv6 loopback / unique-local /
 * link-local / IPv4-mapped). `resolveAndValidate` is exercised against a
 * mocked `node:dns/promises` so we can drive specific resolver outcomes
 * without touching the real network.
 *
 * `safeFetch` is intentionally not unit-tested here: it composes
 * `resolveAndValidate` with `globalThis.fetch` plus stream/redirect/timeout
 * handling, and a faithful mock would re-implement that composition.
 * `safeFetch`'s DNS-rebinding TOCTOU is acknowledged in `ssrf-guard.ts`
 * (around line 122 — comment block above `safeFetch`); `resolveAndValidate`
 * is invoked at every redirect hop there. The pieces it depends on are
 * covered individually below; the integration surface is exercised by
 * `routes/__tests__/ogp.test.ts`.
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { isPrivateIP, resolveAndValidate, SSRFError } from "../ssrf-guard.js";

vi.mock("node:dns/promises", () => ({
  lookup: vi.fn(),
}));

import { lookup } from "node:dns/promises";
import type { LookupAddress } from "node:dns";

// `lookup` is heavily overloaded in @types/node; the production code calls
// the `{ all: true }` form which returns `LookupAddress[]`. We cast to that
// signature so vitest's typed mock helpers accept array-shaped resolved
// values without TS narrowing to the single-result overload.
const mockedLookup = vi.mocked(lookup) as unknown as ReturnType<
  typeof vi.fn<
    (hostname: string, options: { all: true }) => Promise<LookupAddress[]>
  >
>;

describe("isPrivateIP", () => {
  describe("IPv4 private/reserved ranges", () => {
    it.each([
      // 10.0.0.0/8
      ["10.0.0.0", true],
      ["10.0.0.1", true],
      ["10.255.255.255", true],
      ["11.0.0.0", false],
      // 172.16.0.0/12
      ["172.15.255.255", false],
      ["172.16.0.0", true],
      ["172.20.0.0", true],
      ["172.31.255.255", true],
      ["172.32.0.0", false],
      // 192.168.0.0/16
      ["192.167.255.255", false],
      ["192.168.0.0", true],
      ["192.168.1.1", true],
      ["192.168.255.255", true],
      ["192.169.0.0", false],
      // 127.0.0.0/8 (loopback)
      ["127.0.0.0", true],
      ["127.0.0.1", true],
      ["127.255.255.255", true],
      ["128.0.0.0", false],
      // 0.0.0.0/8 (unspecified / current network)
      ["0.0.0.0", true],
      ["0.1.2.3", true],
      // 169.254.0.0/16 (link-local + AWS/GCP/Azure metadata at 169.254.169.254)
      ["169.253.255.255", false],
      ["169.254.0.0", true],
      ["169.254.169.254", true], // cloud metadata endpoint
      ["169.254.255.255", true],
      ["169.255.0.0", false],
      // 100.64.0.0/10 (carrier-grade NAT)
      ["100.63.255.255", false],
      ["100.64.0.0", true],
      ["100.100.0.0", true],
      ["100.127.255.255", true],
      ["100.128.0.0", false],
      // Public IPs that should pass through
      ["8.8.8.8", false],
      ["1.1.1.1", false],
      ["140.82.121.4", false], // github.com at the time of writing
    ])("isPrivateIP(%s) === %s", (ip, expected) => {
      expect(isPrivateIP(ip)).toBe(expected);
    });
  });

  describe("IPv6 private/reserved ranges", () => {
    it.each([
      ["::1", true], // loopback
      ["::", true], // unspecified
      ["fc00::1", true], // unique-local
      ["fd12:3456:789a::1", true], // unique-local
      ["fe80::1", true], // link-local
      ["fe90::1", true],
      ["fea0::1", true],
      ["feb0::1", true],
      ["fec0::1", false], // site-local was deprecated and is NOT in the guard's list
      ["2001:db8::1", false], // documentation prefix — not blocked (acceptable false-negative)
      ["2606:4700:4700::1111", false], // Cloudflare DNS
      // IPv4-mapped IPv6 — dotted decimal form
      ["::ffff:127.0.0.1", true],
      ["::ffff:192.168.1.1", true],
      ["::ffff:10.0.0.1", true],
      ["::ffff:169.254.169.254", true],
      ["::ffff:8.8.8.8", false],
      // IPv4-mapped IPv6 — hex colon form (e.g. 192.168.1.1 → c0a8:0101)
      ["::ffff:c0a8:0101", true], // 192.168.1.1
      ["::ffff:7f00:0001", true], // 127.0.0.1
      ["::ffff:0808:0808", false], // 8.8.8.8
    ])("isPrivateIP(%s) === %s", (ip, expected) => {
      expect(isPrivateIP(ip)).toBe(expected);
    });
  });

  describe("non-IP / malformed inputs", () => {
    it.each([
      "",
      "not-an-ip",
      "999.999.999.999",
      "1.2.3",
      "1.2.3.4.5",
      "::ffff:nope",
      "example.com",
    ])("rejects %s as private (fail-closed)", (input) => {
      expect(isPrivateIP(input)).toBe(true);
    });
  });
});

describe("resolveAndValidate", () => {
  beforeEach(() => {
    mockedLookup.mockReset();
  });

  it("short-circuits on a public IP literal without resolving DNS", async () => {
    await expect(resolveAndValidate("8.8.8.8")).resolves.toBe("8.8.8.8");
    expect(mockedLookup).not.toHaveBeenCalled();
  });

  it("rejects a private IP literal without resolving DNS", async () => {
    await expect(resolveAndValidate("127.0.0.1")).rejects.toBeInstanceOf(
      SSRFError,
    );
    expect(mockedLookup).not.toHaveBeenCalled();
  });

  it("rejects a public-looking IPv6 literal that maps to private", async () => {
    await expect(
      resolveAndValidate("::ffff:192.168.1.1"),
    ).rejects.toBeInstanceOf(SSRFError);
  });

  it("returns the first resolved address when all are public", async () => {
    mockedLookup.mockResolvedValueOnce([
      { address: "93.184.216.34", family: 4 },
      { address: "2606:2800:220:1:248:1893:25c8:1946", family: 6 },
    ]);
    await expect(resolveAndValidate("example.com")).resolves.toBe(
      "93.184.216.34",
    );
    expect(mockedLookup).toHaveBeenCalledWith("example.com", { all: true });
  });

  it("rejects when ANY resolved address is private (mixed result)", async () => {
    // DNS rebinding mitigation: if even one of the records points to a
    // private range, the whole hostname is unsafe.
    mockedLookup.mockResolvedValueOnce([
      { address: "8.8.8.8", family: 4 },
      { address: "127.0.0.1", family: 4 },
    ]);
    await expect(resolveAndValidate("rebind.example")).rejects.toBeInstanceOf(
      SSRFError,
    );
  });

  it("rejects when the cloud metadata IP is in the result set", async () => {
    mockedLookup.mockResolvedValueOnce([
      { address: "169.254.169.254", family: 4 },
    ]);
    await expect(resolveAndValidate("metadata.example")).rejects.toThrow(
      /private IP/,
    );
  });

  it("wraps DNS resolution failures in SSRFError", async () => {
    mockedLookup.mockRejectedValueOnce(
      Object.assign(new Error("ENOTFOUND nxdomain.example"), {
        code: "ENOTFOUND",
      }),
    );
    await expect(resolveAndValidate("nxdomain.example")).rejects.toBeInstanceOf(
      SSRFError,
    );
  });

  it("DNS-failure SSRFError uses the generic message (no underlying error leak)", async () => {
    // Separate test so the second assertion gets its own mockRejectedValueOnce —
    // calling `await expect(...).rejects` twice consumes the lookup twice and
    // would otherwise hit the real DNS the second time.
    mockedLookup.mockRejectedValueOnce(
      Object.assign(new Error("ENOTFOUND nxdomain.example"), {
        code: "ENOTFOUND",
      }),
    );
    await expect(resolveAndValidate("nxdomain.example")).rejects.toThrow(
      /DNS resolution failed/,
    );
  });

  it("preserves SSRFError thrown from inside the lookup loop (not double-wrapped)", async () => {
    mockedLookup.mockResolvedValueOnce([{ address: "10.0.0.1", family: 4 }]);
    try {
      await resolveAndValidate("internal.example");
      throw new Error("expected SSRFError");
    } catch (err) {
      expect(err).toBeInstanceOf(SSRFError);
      expect((err as Error).message).toMatch(/private IP/);
    }
  });
});

describe("SSRFError", () => {
  it("is an Error subclass with the expected name", () => {
    const err = new SSRFError("blocked");
    expect(err).toBeInstanceOf(Error);
    expect(err).toBeInstanceOf(SSRFError);
    expect(err.name).toBe("SSRFError");
    expect(err.message).toBe("blocked");
  });
});
