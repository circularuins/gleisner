# Idea 017: Public timeline sharing for unauthenticated viewers

**Status:** Raw idea
**Date:** 2026-03-24

## Summary

Allow artists to share their timeline URL on external SNS. Unauthenticated visitors can view the shared timeline (read-only) with a login prompt. This is critical for MVP beta user acquisition — artists share links, fans discover Gleisner.

## Notes

- **Primary use case**: artist posts their Gleisner timeline URL on Twitter/Instagram/etc. → fan clicks → sees the constellation timeline without needing an account
- **Unauthenticated access scope**:
  - Can view: timeline, nodes, synapse connections, constellations, post detail sheets
  - Cannot: react (reactions require account)
  - Maybe: comment? (TBD — allowing comments from unauthenticated users has spam/moderation implications)
- **Login prompt**: show a non-intrusive banner or CTA encouraging signup, positioned so it doesn't block content viewing
- **URL structure**: something like `gleisner.app/@artistUsername` — clean, shareable, recognizable
- **MVP priority**: this is essential for beta user growth. Without it, there's no way for potential users to see what Gleisner looks like before creating an account
- **Implementation timing**: could be bundled with auth screen improvements (login/signup flow), since both involve unauthenticated user state handling
- **Backend consideration**: `posts` query and `artist` query currently don't require authentication, so the data layer may already support this. The frontend router needs a public route that doesn't redirect to login
- **Privacy interaction**: must respect post visibility settings (Idea 014) once implemented — hidden/restricted posts should not appear on public timelines
## Evaluation

- **ROI**: One of the highest-ROI features for MVP. No matter how good the product is, new users won't come if everything is behind a login wall. "Click a URL and experience it immediately" is the lifeblood of SNS growth. Bluesky grew early using this exact pattern
- **Implementation cost**: Low. Backend already has public queries (`artist`, `posts`). Main work is adding a public route on the frontend
- **Gleisner's biggest weapon**: The constellation layout, synapses, and named constellations are visually unique — they communicate "this is different" instantly. Letting potential users interact with the real thing beats any screenshot or description
- **Watch out — OGP/meta tags**: When a URL is shared on Twitter/Instagram, a preview card (OGP image + title + description) is critical for click-through rate. Flutter Web is an SPA, so the server must return OGP meta tags for shared URLs. Easy to overlook
- **Watch out — first-impression performance**: The first few seconds matter for first-time visitors. Google Fonts HTTP fetch + GraphQL data load could result in a long white screen. Consider font preloading and skeleton UI

## Priority recommendation

Implement immediately after ADR 020 security fixes (which are small). This is the growth engine for beta launch.

## Related

- Idea 002 (profile as homepage), Idea 003 (artist/fan mode), Idea 014 (post visibility)
