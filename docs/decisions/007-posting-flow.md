# ADR 007: Posting Flow — Quick Post with Optional Details

## Status

Accepted

## Context

Artists need to post frequently to maintain an active timeline. The posting experience must minimize friction — ideally just 2 taps to publish — while still offering rich metadata controls (importance, related posts, descriptions) for artists who want to curate their timeline carefully.

## Decision

### 3-Step Quick Flow

The posting flow is a 3-step sequence optimized for speed:

1. **Track selection** — tap a track chip, auto-advance to step 2
2. **Media selection** — tap media type (Video/Audio/Image/Text), auto-advance to step 3
3. **Review & Post** — media preview displayed prominently, Post button immediately available

Steps 1 and 2 are single-tap decisions. The artist can post in under 3 seconds.

### Optional Details (Accordion)

On the review screen, additional fields are collapsed into accordions. The artist can open any of them before posting, or skip all:

| Field | Default if skipped | Required? |
|-------|-------------------|-----------|
| Title | AI auto-generates from media content | Optional (all types) |
| Description | Empty | Required for TEXT only, optional otherwise |
| Importance | 0.50 (middle) | Optional |
| Related Post | None (AI auto-detects separately) | Optional |

All fields are editable after posting.

### Title Auto-Generation

When the artist doesn't provide a title:
- **Video/Audio** — AI analyzes content and suggests a title
- **Image** — AI image recognition generates a description-based title
- **Text** — First N characters of the body text

The auto-generated title is always overridable by the artist.

### Importance Slider with Live Preview

The importance slider (0.00–1.00) includes a real-time preview showing the node as it will appear on the timeline:
- Node size, shape (track-specific border radius), and glow intensity update live
- Labels: "quiet note" (0.0) ↔ "hero moment" (1.0)
- Helps artists understand the visual impact of their choice

### Related Post Linking

- Optional field to link the new post to a previous post
- Opens a searchable picker (bottom sheet) with track filter
- Creates an explicit connection displayed as a synapse line on the timeline
- See Idea 006 for full thread/connection design

### Track Management

- Artists define their own tracks (up to ~10), each with a name and color
- Tracks can be created in advance (settings) or on the spot during posting
- Color picker excludes already-used colors to maintain visual distinction

### Post Completion

- On successful post → navigate to timeline
- New node appears with an entrance animation (glow-in effect)
- Provides immediate visual feedback that the post is live

### Artist Mode Indicator

A persistent "Artist Mode" badge at the bottom of the posting screens makes it clear that posting capabilities are an artist-mode action (see Idea 003).

## Consequences

- Posting friction is minimized to 2 taps + Post button
- Power users can add rich metadata without slowing down casual posters
- AI auto-generation reduces the cognitive load of metadata entry
- The importance preview educates artists about the timeline's visual system
- Related post linking gives artists explicit control over their timeline's narrative connections
- All metadata is post-editable, so nothing is permanently "missed"

## Related

- ADR 006 — Timeline visual design (importance → size, synapse connections)
- Idea 003 — Artist/Fan mode
- Idea 006 — Related posts & thread view
- Mockups: `docs/mockups/post-v1.html` (form style), `docs/mockups/post-v2.html` (quick flow, adopted)
