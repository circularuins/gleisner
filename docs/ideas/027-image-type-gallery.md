# Idea 027: Image Type — Instagram-Style Gallery

**Status:** Validated
**Date:** 2026-04-07

## Summary

Polish the image media type with multi-image support (already planned in #139), Instagram-like image-first display, and minimal text overlay. Images are the hero; title and caption are secondary.

## Notes

- **Multi-image:** Already planned in Issue #139 — carousel/gallery with swipe
- **Creation screen:**
  - Image selection/upload as the first and primary step
  - Title and caption fields visible but non-prominent
  - Media file must be **required** (currently optional — fix needed)
- **Detail bottom sheet:**
  - Full-screen image viewer with swipe for multi-image
  - Title, caption, metadata below the image
- **Timeline node:**
  - Image fills most of the node area (already implemented with warm gradient fill)
  - Title overlaid at bottom with subtle gradient backdrop
  - Multi-image indicator (dot pagination) when applicable
- Related: Idea 025 (umbrella strategy), Issue #139 (multi-image), ADR 025 (media handling)
