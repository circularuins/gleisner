import { Parser } from "htmlparser2";
import { safeFetch, SSRFError } from "./ssrf-guard.js";

export interface OgpMetadata {
  ogTitle: string | null;
  ogDescription: string | null;
  ogImage: string | null;
  ogSiteName: string | null;
}

/**
 * Detect a YouTube URL and return its canonical watch URL, or null
 * if the input isn't recognised. Covers the four shapes we see in
 * practice: youtube.com/watch?v=, youtu.be/<id>, youtube.com/shorts/<id>,
 * and m./music. subdomains.
 *
 * Used to trigger the oEmbed branch (see `fetchYouTubeOembed`) — the
 * default HTML-scrape path does not work for YouTube from data-center
 * IPs (Railway / AWS) because YouTube serves a stripped page that
 * lacks `<meta property="og:image">`.
 */
function youtubeWatchUrl(url: string): string | null {
  try {
    const u = new URL(url);
    const host = u.hostname.replace(/^www\./, "").replace(/^m\./, "");
    if (host === "youtu.be") {
      const id = u.pathname.slice(1).split("/")[0];
      return /^[A-Za-z0-9_-]{6,20}$/.test(id)
        ? `https://www.youtube.com/watch?v=${id}`
        : null;
    }
    if (host === "youtube.com" || host === "music.youtube.com") {
      if (u.pathname === "/watch") {
        const id = u.searchParams.get("v") ?? "";
        return /^[A-Za-z0-9_-]{6,20}$/.test(id)
          ? `https://www.youtube.com/watch?v=${id}`
          : null;
      }
      const shortsMatch = u.pathname.match(/^\/shorts\/([A-Za-z0-9_-]+)/);
      if (shortsMatch) {
        return `https://www.youtube.com/watch?v=${shortsMatch[1]}`;
      }
    }
    return null;
  } catch {
    return null;
  }
}

interface YouTubeOembed {
  title?: unknown;
  author_name?: unknown;
  thumbnail_url?: unknown;
  provider_name?: unknown;
}

/**
 * Fetch YouTube link metadata via the public oEmbed endpoint
 * (`https://www.youtube.com/oembed?url=...&format=json`). YouTube's
 * oEmbed always returns JSON with the title and a thumbnail URL —
 * unlike OGP scraping, it doesn't depend on the requester's IP or UA.
 *
 * Maps to OgpMetadata so the rest of the pipeline (storage, schema,
 * UI) doesn't need to know about oEmbed at all.
 */
async function fetchYouTubeOembed(
  watchUrl: string,
): Promise<OgpMetadata | null> {
  const oembedUrl = `https://www.youtube.com/oembed?url=${encodeURIComponent(
    watchUrl,
  )}&format=json`;
  const body = await safeFetch(oembedUrl);
  let parsed: YouTubeOembed;
  try {
    parsed = JSON.parse(body) as YouTubeOembed;
  } catch {
    return null;
  }
  const title = typeof parsed.title === "string" ? parsed.title : null;
  const author =
    typeof parsed.author_name === "string" ? parsed.author_name : null;
  const thumbnail =
    typeof parsed.thumbnail_url === "string" ? parsed.thumbnail_url : null;
  if (!title && !thumbnail) return null;
  return {
    ogTitle: sanitize(title, 200),
    ogDescription: author ? sanitize(`by ${author}`, 500) : null,
    ogImage: sanitizeImageUrl(thumbnail),
    ogSiteName: "YouTube",
  };
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
    // YouTube serves a stripped HTML page to data-center IPs (Railway,
    // AWS, etc.) without OGP meta tags — fall back to the public
    // oEmbed endpoint which is IP/UA-agnostic by design.
    const ytWatch = youtubeWatchUrl(url);
    if (ytWatch) {
      const metadata = await fetchYouTubeOembed(ytWatch);
      if (metadata) return metadata;
      // oEmbed failed (rare — usually means the video is private or
      // removed). Don't fall back to HTML scrape; YouTube's HTML path
      // is broken from data-center IPs anyway.
      return null;
    }

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
