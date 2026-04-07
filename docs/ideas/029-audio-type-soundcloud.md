# Idea 029: Audio Type — SoundCloud-Inspired Music Player

**Status:** Validated
**Date:** 2026-04-07

## Summary

Polish the audio media type with a SoundCloud-inspired experience: waveform visualization, inline playback, and music-SNS-style presentation. Target use cases: original music, demos, podcasts, voice memos.

## Notes

- **Creation screen:**
  - Audio file selection/upload as the primary step
  - Media file must be **required** (currently optional — fix needed)
  - Title is important for audio (song name) — keep prominent
  - Duration limit enforcement: 5 min for Phase 1 (Issue #145)
- **Detail bottom sheet / player:**
  - Waveform visualization with playback progress
  - Play/pause, seek, duration display
  - Cover art area (could use seed art or uploaded image)
- **Timeline node:**
  - Horizontal oval shape (already distinct from other types)
  - Waveform-like visualization (already partially implemented)
  - Inline play button — tap to play without opening detail sheet
  - Title and duration visible on node
- **References:**
  - SoundCloud's player UI for waveform + progress
  - Spotify's card layout for compact representation
- Related: Idea 025 (umbrella strategy), Issue #145 (5-min limit), ADR 025 (media handling)
