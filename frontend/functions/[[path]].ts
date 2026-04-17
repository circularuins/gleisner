// Cloudflare Pages Functions — catch-all handler for OGP bot detection.
// SNS crawlers (Twitter, Facebook, etc.) receive OGP meta tags from the backend.
// Regular browsers receive the Flutter SPA.

interface Env {
  API_URL: string;
  ASSETS: Fetcher;
}

// Keep in sync with backend/src/routes/ogp.ts
const USERNAME_PATTERN = /^[a-zA-Z0-9_]{1,30}$/;

const BOT_USER_AGENTS = [
  "Twitterbot",
  "facebookexternalhit",
  "LinkedInBot",
  "Slackbot",
  "Discordbot",
  "WhatsApp",
  "TelegramBot",
  "Googlebot",
  "bingbot",
];

function isBot(userAgent: string): boolean {
  const ua = userAgent.toLowerCase();
  return BOT_USER_AGENTS.some((bot) => ua.includes(bot.toLowerCase()));
}

export const onRequest: PagesFunction<Env> = async (context) => {
  const url = new URL(context.request.url);
  const path = url.pathname;

  // Only intercept /@username paths
  const match = path.match(/^\/@([^/]+)$/);
  if (!match) {
    return context.env.ASSETS.fetch(context.request);
  }

  const username = match[1];

  // Validate username format (SSRF prevention)
  if (!USERNAME_PATTERN.test(username)) {
    return context.env.ASSETS.fetch(context.request);
  }

  // Check if requester is a bot
  const userAgent = context.request.headers.get("user-agent") ?? "";
  if (!isBot(userAgent)) {
    return context.env.ASSETS.fetch(context.request);
  }

  // Proxy to backend OGP endpoint
  const apiUrl = context.env.API_URL;
  if (!apiUrl) {
    return context.env.ASSETS.fetch(context.request);
  }

  try {
    const ogpResponse = await fetch(`${apiUrl}/ogp/@${username}`, {
      headers: { "User-Agent": userAgent },
      signal: AbortSignal.timeout(5000),
    });

    if (!ogpResponse.ok) {
      return context.env.ASSETS.fetch(context.request);
    }

    return new Response(ogpResponse.body, {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "public, max-age=300",
        // PHASE_0_REVERT: Forward the backend's X-Robots-Tag so SNS bots
        // see noindex. Without this, reconstructing the Response drops
        // the header and the OGP path loses its noindex signal.
        "X-Robots-Tag":
          ogpResponse.headers.get("X-Robots-Tag") ??
          "noindex, nofollow, noarchive, nosnippet",
      },
    });
  } catch {
    // Timeout or network error — fall back to SPA
    return context.env.ASSETS.fetch(context.request);
  }
};
