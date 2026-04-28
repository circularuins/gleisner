import { Parser } from "htmlparser2";
import { safeFetch, SSRFError } from "./ssrf-guard.js";

export interface OgpMetadata {
  ogTitle: string | null;
  ogDescription: string | null;
  ogImage: string | null;
  ogSiteName: string | null;
}

/** Strip HTML tags and control characters, truncate to maxLength. */
function sanitize(value: string | null, maxLength: number): string | null {
  if (!value) return null;
  return (
    value
      .replace(/<[^>]*>/g, "")
      // eslint-disable-next-line no-control-regex
      .replace(/[\u0000-\u001F\u200B-\u200F\u202A-\u202E]/g, "")
      .trim()
      .slice(0, maxLength) || null
  );
}

/** Parse OGP meta tags from HTML string using SAX parser. */
function parseOgpTags(html: string): OgpMetadata {
  const result: Record<string, string> = {};
  let inHead = false;

  const parser = new Parser({
    onopentag(name, attrs) {
      if (name === "head") {
        inHead = true;
        return;
      }
      if (!inHead) return;
      if (name !== "meta") return;

      const property = attrs.property || attrs.name || "";
      const content = attrs.content || "";
      if (!property.startsWith("og:") || !content) return;

      // Only capture first occurrence of each tag
      if (!result[property]) {
        result[property] = content;
      }
    },
    onclosetag(name) {
      // Stop parsing after </head>
      if (name === "head") {
        parser.pause();
      }
    },
  });

  parser.write(html);
  parser.end();

  return {
    ogTitle: sanitize(result["og:title"] ?? null, 200),
    ogDescription: sanitize(result["og:description"] ?? null, 500),
    ogImage: sanitizeImageUrl(result["og:image"] ?? null),
    ogSiteName: sanitize(result["og:site_name"] ?? null, 100),
  };
}

/** Validate og:image URL: must be https to avoid mixed content. */
function sanitizeImageUrl(url: string | null): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    // Only allow https to avoid mixed content in Flutter Web
    if (parsed.protocol !== "https:") return null;
    return parsed.href;
  } catch {
    return null;
  }
}

/**
 * Build the `db.update(posts).set(...)` payload for persisting an OGP
 * fetch outcome. Always sets `ogFetchedAt` (negative cache — prevents
 * the resolver from re-running the fetch on every render). The four
 * og_* fields are only written when the fetcher returned data, so a
 * null response from a temporarily-broken site preserves any
 * previously-cached metadata rather than clearing it.
 *
 * Used by both `createPost` (fire-and-forget) and `fetchOgp` to remove
 * the duplicated `{ ...(ogp ? {...} : {}), ogFetchedAt: new Date() }`
 * literal — Issue #189.
 */
export function ogpUpdateSet(metadata: OgpMetadata | null): {
  ogTitle?: string | null;
  ogDescription?: string | null;
  ogImage?: string | null;
  ogSiteName?: string | null;
  ogFetchedAt: Date;
} {
  return {
    ...(metadata
      ? {
          ogTitle: metadata.ogTitle,
          ogDescription: metadata.ogDescription,
          ogImage: metadata.ogImage,
          ogSiteName: metadata.ogSiteName,
        }
      : {}),
    ogFetchedAt: new Date(),
  };
}

/**
 * Fetch OGP metadata from a URL.
 * Returns null if the URL is unreachable, blocked by SSRF guard,
 * or doesn't contain OGP tags.
 */
export async function fetchOgpMetadata(
  url: string,
): Promise<OgpMetadata | null> {
  try {
    const html = await safeFetch(url);
    const metadata = parseOgpTags(html);

    // Return null if no meaningful OGP data was found
    if (!metadata.ogTitle && !metadata.ogDescription && !metadata.ogImage) {
      return null;
    }

    return metadata;
  } catch (err) {
    if (err instanceof SSRFError) {
      console.warn(`[OGP] SSRF blocked: ${err.message}`);
    } else {
      console.warn(
        `[OGP] fetch failed: ${err instanceof Error ? err.message : "unknown"}`,
      );
    }
    return null;
  }
}
