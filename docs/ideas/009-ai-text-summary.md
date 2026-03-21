# Idea 009: AI-powered text summary in detail sheet

**Status:** Raw idea
**Date:** 2026-03-21

## Summary

Replace the body excerpt in the text node's detail sheet header with an AI-generated (or rule-based) summary. This would give readers a quick overview of long-form text posts without scrolling.

## Notes

- Currently the detail sheet shows a direct body quote (first ~4 lines) in the media area for text posts
- Could be AI-generated (Claude Haiku, already in the stack per ADR 015) or a simpler extractive summary (first sentence, etc.)
- AI summary has cost implications — need to decide: generate on post creation (one-time cost, stored) vs. on-demand (per-view cost)
- Pre-generating on creation is likely better: lower latency, predictable cost, can be cached as a field on the post
- Could also be useful for search/discovery features later
- Related to existing AI usage: title auto-generation already uses Claude Haiku
- Monetization consideration: this could be a core feature (summary is cheap per-post) or gated behind a word-count threshold (e.g., free for <500 words, AI summary for longer posts)

### Estimated reading time

- Display "6 min read" alongside the summary for long-form text posts
- Could reuse the existing `duration` field on Post — store estimated reading time in seconds (e.g., 360 for "6 min read")
- This aligns with the PR #35 review discussion: `duration` was intentionally left unrestricted by media type, enabling this use case for text posts
- Calculation: ~200-250 words per minute (standard reading speed), auto-computed on post creation
- Validates the architectural decision to not restrict `duration` to audio/video only

### Text sub-genre selection and genre-aware summarization

- At post creation time, let the user choose a **text sub-genre**: poetry, essay, opinion/news, humor, review, fiction, etc.
- The AI summary strategy adapts based on the selected genre:

| Sub-genre | Summary strategy | Rationale |
|-----------|-----------------|-----------|
| Poetry | **Excerpt** (key stanza), not summary | Summarizing a poem destroys its essence; an excerpt preserves the voice |
| Essay | Thesis + key argument summary | Standard summarization works well |
| Opinion/News | Headline-style summary | Quick take on the stance |
| Humor | Punchline tease ("A story about...") | Don't spoil the joke |
| Review | Rating + one-line verdict | Actionable at a glance |
| Fiction | Hook excerpt (opening lines) | Draw the reader in without spoilers |

- Implementation: sub-genre stored as a field on Post (e.g., `textSubGenre` enum or string)
- The AI prompt template varies by sub-genre to produce appropriate output
- Sub-genre also influences the timeline node preview: poetry could show centered italic text, reviews could show a star rating, etc.
- This creates a richer, more intentional text posting experience — the artist consciously frames their writing
