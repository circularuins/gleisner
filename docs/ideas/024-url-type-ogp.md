# Idea 024: URL Type OGP Implementation

## Summary

Implement OGP (Open Graph Protocol) for URL-type posts to enable rich display with thumbnails, titles, and descriptions. Per ADR 025, the URL type has strategic importance as an interface to externally hosted media.

## Current State

- URL-type posts store only the mediaUrl link
- Timeline/detail sheet shows domain name text only
- No automatic thumbnail or title fetching

## Scope

### Phase 1: Server-Side OGP Fetch

- Backend: `fetchOgp(url)` endpoint or GraphQL query
- OGP tag extraction: `og:title`, `og:description`, `og:image`, `og:video`, `og:audio`, `og:site_name`
- Cache: Store OGP data in DB or Redis with TTL per URL
- Rate limiting: Prevent excessive requests to external sites

### Phase 2: Frontend Rich Display

- Post creation: Show OGP preview after URL input
- Timeline nodes: Display OGP thumbnail image on nodes
- Detail sheet: Rich card display (thumbnail + title + description + site name)
- YouTube/SoundCloud/Spotify: Consider special treatment (embed players)

### Phase 3: Embed Players

- YouTube: iframe embed
- SoundCloud: embed widget
- Spotify: embed player
- Others: Fall back to OGP card display

## Design Considerations

- OGP fetching must be server-side (CORS restriction bypass)
- Prevent fetching of malicious URLs (SSRF prevention: reject private IPs, etc.)
- Do not cache OGP images on Gleisner side (copyright risk avoidance — reference external URLs directly)

## Dependencies

- ADR 025 (media handling strategy — URL type strategic importance)
