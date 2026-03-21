# Idea 010: AI Coach — "Ask AI Sensei"

**Status:** Raw idea
**Date:** 2026-03-21

## Summary

Allow artists to select one or more video/audio posts on their timeline and request AI-powered feedback: impressions, advice, scoring, practice suggestions. Results can be posted to the timeline or saved to a private notes area.

## Notes

### Use cases

- A guitarist attends a jam session, posts several videos quickly on-site. Later at home, selects them on the timeline and gets AI feedback on technique, timing, musicality
- A practice track where daily practice videos accumulate. AI reviews progress over time, suggests exercises, identifies patterns
- Multi-post analysis: "Compare my playing in these 3 sessions — what improved?"

### UX flow (rough)

1. Enter "selection mode" on the timeline (long-press or button)
2. Tap multiple video/audio nodes to select
3. "Ask AI Sensei" button appears
4. AI processes the selected media and returns feedback
5. Artist chooses to: post feedback as a new text post on a track, or save to private notes

### Technical considerations

- Requires video/audio analysis — likely multimodal AI (Claude vision for video frames, or Whisper + Claude for audio transcription + analysis)
- Significantly higher cost per request than text operations
- Latency: video analysis may take 30s+ — need async processing with notification
- Storage: AI feedback could be a new entity type (not just a post) or a special post mediaType

### Monetization

- This is likely a **paid plugin/feature** due to high per-request AI cost
- Need careful free/paid line drawing:
  - Free tier: maybe 1-2 AI reviews per month, text-only analysis
  - Paid tier: unlimited reviews, video/audio analysis, multi-post comparison, progress tracking
- Core features should remain free where possible — the question is where "core" ends and "premium AI" begins
- Consider: summary (Idea 009) as core, deep analysis (this idea) as premium

### Related

- Related: Idea 009 (AI text summary — lighter-weight AI feature, potentially core)
- Related: ADR 015 (tech stack — Claude Haiku already in stack for title generation)
- The private notes area mentioned here doesn't exist yet — would be a new feature
