# Idea 014: Post visibility and audience control

**Status:** Promoted — Superseded by [Idea 021](021-visibility-and-audience-control.md) which adds artist-level visibility and guardian integration
**Date:** 2026-03-22

## Summary

Posts need visibility controls from day one — not just public/private, but fine-grained audience selection. This is especially critical for child artists, who should default to private with guardian-approved viewer lists. Adult artists also need the ability to hide or restrict posts without deleting them.

## Notes

- **Core requirement**: posts should support at least three visibility levels:
  - Public (anyone can see)
  - Limited (only approved/specified users can see)
  - Private/hidden (only the author can see)
- **Child artist default**: when the account holder is a minor (see Idea 012), new posts should default to private. The guardian controls who can view — not the child directly
- **Guardian-approved viewer list**: a guardian-managed allowlist of users permitted to see the child's posts. This ties directly into the parental consent model from Idea 012
- **Adult use cases**: an adult artist may want to:
  - Hide an old post without permanently deleting it (aligns with Diaspora principle: "resistance to erasure" — soft-hide, not hard-delete)
  - Share work-in-progress with a small circle before going public
  - Restrict a post after it was public (e.g., contractual reasons)
- **"Hide" vs "delete"**: deletion should remain available, but hiding/restricting is the gentler default — preserving the artist's timeline history
- **Initial implementation scope is TBD**: could start with public/private toggle and expand to audience lists later
- Related: Idea 012 (age policy), ADR 018 (copyright protection), ADR 019 (age restriction)
