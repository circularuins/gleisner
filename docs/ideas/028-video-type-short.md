# Idea 028: Video Type — Short-Form Video (Reels/Shorts Style)

**Status:** Validated
**Date:** 2026-04-07

## Summary

Polish the video media type with a Reels/Shorts-inspired creation and viewing experience. Vertical video-first, swipeable playback, minimal UI chrome during viewing.

## Notes

- **Creation screen:**
  - Video file selection/upload as the primary step
  - Media file must be **required** (currently optional — fix needed)
  - Title/caption fields secondary
  - Duration limit enforcement: 1 min for Phase 1 (Issue #144), relaxed in Phase 2
- **Detail bottom sheet / viewer:**
  - Near-full-screen video playback
  - Title, caption, reactions overlaid or below
  - Auto-play consideration (muted by default?)
- **Timeline node:**
  - Thumbnail with play button overlay
  - Cinematic aspect ratio (already has letterbox bars in current design)
  - Duration badge visible on node
- **Thumbnail:**
  - Currently required for video posts — keep this requirement
  - Consider auto-generating thumbnails from video in a future phase
- Related: Idea 025 (umbrella strategy), Issue #144 (1-min limit), ADR 025 (media handling)
