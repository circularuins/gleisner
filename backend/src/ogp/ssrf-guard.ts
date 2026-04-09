import { lookup } from "node:dns/promises";
import { isIP } from "node:net";

/**
 * SSRF guard: validate URLs before fetching external content.
 * Rejects private/reserved IP addresses to prevent Server-Side Request Forgery.
 */

/** Check if an IPv4 address is in a private/reserved range. */
function isPrivateIPv4(ip: string): boolean {
  const parts = ip.split(".").map(Number);
  if (parts.length !== 4) return true; // malformed → reject

  const [a, b] = parts;
  return (
    a === 10 || // 10.0.0.0/8
    (a === 172 && b >= 16 && b <= 31) || // 172.16.0.0/12
    (a === 192 && b === 168) || // 192.168.0.0/16
    a === 127 || // 127.0.0.0/8
    a === 0 || // 0.0.0.0/8
    (a === 169 && b === 254) || // 169.254.0.0/16 (link-local + cloud metadata)
    (a === 100 && b >= 64 && b <= 127) // 100.64.0.0/10 (carrier-grade NAT)
  );
}

/** Check if an IPv6 address is private/reserved. */
function isPrivateIPv6(ip: string): boolean {
  const normalized = ip.toLowerCase();

  // Loopback
  if (normalized === "::1") return true;

  // IPv4-mapped IPv6 — dotted decimal (::ffff:192.168.1.1)
  const v4Mapped = normalized.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (v4Mapped) return isPrivateIPv4(v4Mapped[1]);

  // IPv4-mapped IPv6 — hex colon (::ffff:c0a8:0101)
  const v4MappedHex = normalized.match(
    /^::ffff:([0-9a-f]{1,4}):([0-9a-f]{1,4})$/,
  );
  if (v4MappedHex) {
    const hi = parseInt(v4MappedHex[1], 16);
    const lo = parseInt(v4MappedHex[2], 16);
    const dotted = `${hi >> 8}.${hi & 0xff}.${lo >> 8}.${lo & 0xff}`;
    return isPrivateIPv4(dotted);
  }

  // Unique local (fc00::/7)
  if (normalized.startsWith("fc") || normalized.startsWith("fd")) return true;

  // Link-local (fe80::/10)
  if (
    normalized.startsWith("fe8") ||
    normalized.startsWith("fe9") ||
    normalized.startsWith("fea") ||
    normalized.startsWith("feb")
  )
    return true;

  // Unspecified
  if (normalized === "::") return true;

  return false;
}

/** Check if an IP address (v4 or v6) is private/reserved. */
export function isPrivateIP(ip: string): boolean {
  const version = isIP(ip);
  if (version === 4) return isPrivateIPv4(ip);
  if (version === 6) return isPrivateIPv6(ip);
  return true; // not a valid IP → reject
}

/**
 * Resolve hostname and return a validated (non-private) IP address.
 * Throws if all resolved IPs are private/reserved.
 */
export async function resolveAndValidate(hostname: string): Promise<string> {
  // If hostname is already an IP, check directly
  if (isIP(hostname)) {
    if (isPrivateIP(hostname)) {
      throw new SSRFError(`Blocked: private IP address`);
    }
    return hostname;
  }

  try {
    const result = await lookup(hostname, { all: true });
    for (const entry of result) {
      if (isPrivateIP(entry.address)) {
        throw new SSRFError(`Blocked: hostname resolves to private IP`);
      }
    }
    // Return the first resolved address for direct connection
    return result[0].address;
  } catch (err) {
    if (err instanceof SSRFError) throw err;
    throw new SSRFError(`DNS resolution failed for ${hostname}`);
  }
}

/** Error class for SSRF violations. Safe to expose message to clients. */
export class SSRFError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SSRFError";
  }
}

// 5 seconds — generous enough for slow sites, strict enough to prevent abuse
const OGP_FETCH_TIMEOUT = 5000;
// 3 redirects — covers most URL shorteners (t.co, bit.ly)
const OGP_MAX_REDIRECTS = 3;
// 1 MB — more than enough for any <head> section
const OGP_MAX_RESPONSE_SIZE = 1024 * 1024;

/**
 * Fetch a URL with SSRF protection.
 * - Resolves DNS and validates all IPs before connecting
 * - Validates redirect target IPs before following
 * - Enforces timeout, redirect limit, response size limit
 * - Returns response body as string (truncated at </head> if possible)
 *
 * Note: There is a theoretical TOCTOU gap between DNS resolution and
 * fetch(). A DNS rebinding attack would need to flip the DNS record in
 * the milliseconds between resolve and connect. This is impractical for
 * OGP fetching (low-value target, short window). IP-direct connection
 * was attempted but breaks TLS SNI on CDN/vhost domains.
 */
export async function safeFetch(url: string): Promise<string> {
  let currentUrl = url;
  let redirectCount = 0;

  while (redirectCount <= OGP_MAX_REDIRECTS) {
    const parsed = new URL(currentUrl);
    if (!["https:", "http:"].includes(parsed.protocol)) {
      throw new SSRFError("URL must use http or https");
    }

    // Resolve DNS and validate all IPs are non-private.
    // Uses original hostname for fetch to preserve TLS SNI.
    await resolveAndValidate(parsed.hostname);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), OGP_FETCH_TIMEOUT);

    try {
      // Note: http:// is allowed for sites without HTTPS. MITM risk is
      // acceptable for OGP metadata (public, non-sensitive data).
      const response = await fetch(currentUrl, {
        signal: controller.signal,
        redirect: "manual",
        headers: {
          "User-Agent": "Gleisner-OGP-Fetcher/1.0",
          Accept: "text/html",
        },
      });

      // Handle redirects manually to validate each target
      if (response.status >= 300 && response.status < 400) {
        const location = response.headers.get("location");
        if (!location) throw new SSRFError("Redirect without Location header");
        currentUrl = new URL(location, currentUrl).href;
        redirectCount++;
        continue;
      }

      if (!response.ok) {
        throw new SSRFError(`HTTP ${response.status}`);
      }

      // Read response with size limit — stream to avoid loading full body
      const reader = response.body?.getReader();
      if (!reader) throw new SSRFError("Empty response");

      let totalSize = 0;
      const decoder = new TextDecoder();
      let html = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        totalSize += value.byteLength;
        if (totalSize > OGP_MAX_RESPONSE_SIZE) {
          reader.cancel();
          break;
        }

        html += decoder.decode(value, { stream: true });

        // Stop reading after </head> — we only need meta tags
        if (html.includes("</head>") || html.includes("</HEAD>")) {
          reader.cancel();
          break;
        }
      }

      return html;
    } finally {
      clearTimeout(timeoutId);
    }
  }

  throw new SSRFError("Too many redirects");
}
