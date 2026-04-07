# Idea 025: Media Type Polish Strategy — Per-Type UX Overhaul

**Status:** Validated
**Date:** 2026-04-07

## Summary

Overhaul each media type (text, image, video, audio, URL) with distinct creation, detail, and timeline node UX. The goal is to make each media type feel like a best-in-class dedicated tool while keeping post creation frictionless. This is a core differentiator and should be prioritized before Phase 0 launch.

## Notes

- This is an umbrella strategy document. Each media type has its own Idea for detailed design.
  - **Text**: Idea 026
  - **Image**: Idea 027
  - **Video**: Idea 028
  - **Audio**: Idea 029
  - **URL**: Idea 024 (existing)
- **Cross-cutting principles:**
  - Each media type should feel visually distinct on the timeline (shape, color, layout already partially implemented — see ADR 006)
  - Post creation must remain low-friction — minimize required steps
  - Media file should be **required** for image/video/audio types (currently optional — bug fix needed)
  - Future: AI-assisted content suggestion (e.g. auto-generate title/body from uploaded media) — later phase
- **Data structure impact:** Text type may need rich content model (inline images with captions). Evaluate whether current `body` text field is sufficient or if a structured content format is needed.
- See ADR 004 (DAW-style timeline), ADR 006 (constellation visual design), ADR 025 (media handling strategy)
