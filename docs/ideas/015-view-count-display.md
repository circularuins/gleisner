# Idea 015: View count display with artist-controlled visibility

**Status:** Raw idea
**Date:** 2026-03-23

## Summary

Show post view counts (PV) in the detail sheet, but give artists full control over who can see them. Knowing how many people viewed a post is valuable for both artists and fans, but displaying low numbers can discourage posting — especially for low-importance "life log" entries.

## Notes

- **The tension**: view counts are useful feedback, but they can become "tyranny of numbers" — a post with 3 views feels like a failure even when it was never meant for a wide audience
- **Diaspora "self-determination" principle applies**: the artist should decide what metrics are visible, not the platform
- **Proposed default behavior**:
  - View counts visible to the artist only (in artist mode)
  - Optionally publishable to fans (per-post toggle or global setting)
  - When PV is 0 or very low, suppress display rather than showing "0 views"
- **Instagram precedent**: offered "hide like counts" as an option after research showed negative mental health effects of public metrics
- **Implementation considerations**:
  - Backend: PV counting infrastructure needed (per-post counter, deduplication by user/session)
  - Frontend: conditional display in detail sheet based on artist/fan mode and visibility setting
  - Privacy: view counts should not leak viewer identity (aggregate only)
- Related: Idea 003 (artist/fan mode), Idea 014 (post visibility and audience control)
