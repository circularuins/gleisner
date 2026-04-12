import { Hono } from "hono";
import { db } from "../db/index.js";
import { artists } from "../db/schema/index.js";
import { eq } from "drizzle-orm";

const ogp = new Hono();

const USERNAME_PATTERN = /^[a-zA-Z0-9_]{1,30}$/;

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

ogp.get("/:atUsername", async (c) => {
  const atUsername = c.req.param("atUsername") as string;

  // Expect /@username format
  if (!atUsername.startsWith("@")) {
    return c.notFound();
  }
  const username = atUsername.slice(1);

  if (!USERNAME_PATTERN.test(username)) {
    return c.notFound();
  }

  const [artist] = await db
    .select({
      artistUsername: artists.artistUsername,
      displayName: artists.displayName,
      bio: artists.bio,
      tagline: artists.tagline,
      avatarUrl: artists.avatarUrl,
      profileVisibility: artists.profileVisibility,
    })
    .from(artists)
    .where(eq(artists.artistUsername, username))
    .limit(1);

  if (!artist || artist.profileVisibility !== "public") {
    return c.notFound();
  }

  const title = escapeHtml(artist.displayName ?? artist.artistUsername);
  const description = escapeHtml(
    artist.bio ?? artist.tagline ?? "Artist on Gleisner",
  );
  const rawImage = artist.avatarUrl ?? "";
  const image = /^https:\/\//.test(rawImage) ? rawImage : "";
  const url = `https://gleisner.app/@${escapeHtml(artist.artistUsername)}`;

  const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta property="og:type" content="profile">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
${image ? `<meta property="og:image" content="${escapeHtml(image)}">` : ""}
<meta property="og:url" content="${url}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${description}">
${image ? `<meta name="twitter:image" content="${escapeHtml(image)}">` : ""}
</head>
<body></body>
</html>`;

  return c.html(html);
});

export { ogp };
