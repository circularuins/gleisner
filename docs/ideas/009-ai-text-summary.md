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
