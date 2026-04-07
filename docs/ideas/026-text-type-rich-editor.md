# Idea 026: Text Type — Rich Long-Form Editor

**Status:** Validated
**Date:** 2026-04-07

## Summary

Transform the text media type into a best-in-class writing experience that combines the long-form depth of note/Medium with the casual accessibility of X/Twitter. Target use cases: diary, blog, tech blog, fiction, essay. Support inline images with captions within the text body.

## Notes

- **Ambition:** Compete with note.com and similar platforms on writing experience
- **Inline images:**
  - Allow inserting images between text paragraphs with optional captions
  - Images should be significantly compressed (to differentiate from image-type posts which are high-quality)
  - Data model impact: current `body` (plain text) may need to become structured content (e.g. Markdown, or a block-based format like `[{type: "text", content: "..."}, {type: "image", url: "...", caption: "..."}]`)
  - Need to decide: Markdown vs custom block format vs rich text editor
- **Creation screen:**
  - Must remain low-friction — opening the editor should feel as easy as tweeting
  - Rich toolbar for formatting (bold, italic, headings, image insert, quote)
  - Live preview or WYSIWYG
- **Detail bottom sheet:**
  - Full article reading experience with proper typography
  - Inline images rendered at appropriate size with captions
- **Timeline node:**
  - Text preview (first few lines or title) with reading-time indicator
  - Distinct visual style from other media types (already has `BorderRadius.circular(radiusMd)`)
- **Short vs long form:**
  - No artificial distinction — same editor for both
  - Short posts (< 280 chars?) could render differently on the timeline (more like tweets)
  - Long posts show a "Read more" affordance
- Related: Idea 025 (umbrella strategy), ADR 006 (visual design)
