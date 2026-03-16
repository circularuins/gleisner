# ADR 006: Timeline Visual Design — Constellation Model

## Status

Accepted

## Context

ADR 004 established the DAW-style multi-track timeline as Gleisner's core UI paradigm. Through iterative mockup development, we explored several visual approaches to realize this concept on mobile devices. Key requirements emerged:

1. The timeline must feel **organic and alive** — not a rigid grid or generic feed
2. Every item must be **visible and accessible** regardless of density
3. The design must be **performant** even with thousands of items
4. Artists need meaningful **control** over how their content appears
5. Fan engagement should **visibly shape** the timeline over time

## Decision

### Visual Metaphor: Constellation

The timeline is visualized as a **constellation map** — content items are luminous nodes scattered across a dark canvas, connected by glowing synapse-like lines. The overall effect resembles a living neural network or star chart of the artist's creative activity.

This metaphor was chosen over literal biological representations (amoeba/neuron shapes), which proved visually unappealing when directly translated to UI elements. The constellation approach captures the same "organic network" concept through light, glow, and spatial relationships rather than shape distortion.

### Layout

- **Vertical scroll, top = newest** — follows established SNS conventions
- **Left date spine** — minimal date markers connected by a vertical line
- **Free scatter placement** — items are positioned across the full width, not in columns or rows
- **Time-accurate vertical position** — Y position corresponds to posting time within each day
- **Dynamic day height** — days with more content get proportionally more vertical space; empty days are compressed. Two-pass layout: generous initial placement, then compaction to eliminate excess whitespace
- **Collision avoidance** — items are placed with overlap minimization (28 placement attempts per item, largest items placed first to claim optimal positions)

### Item Appearance

- **Rounded card shapes** with track-specific border radius variation (not identical rectangles, but not blob/clip-path distortion either)
- **Track color glow aura** — items emit a soft glow in their track's color, intensity proportional to engagement
- **Thumbnail + metadata** always fully visible — no content clipping
- **Reaction pills** displayed below the card (outside the clipping boundary)
- **Genre icon** (top-left), duration badge, comment count badge

### Item Sizing

Size is determined by two factors combined:

1. **Importance** (0.0–1.0) — set by the artist, controls base size. This gives artists meaningful curation power over their timeline's visual hierarchy.
2. **Engagement boost** — logarithmic function of `reactions + comments×3 + views×0.01`. Capped at +35% boost. This allows fan activity to organically "grow" items over time.

Size range: 46px (tiny note) to 170px (hero content). Items above a threshold become wider (landscape aspect ratio).

### Synapse Connections

SVG curves connect related items, creating the neural network / constellation effect:

- **Same-track temporal connections** — solid lines in the track's color with glow filter. Thickness and opacity scale with the average engagement of the connected pair.
- **Cross-track thematic connections** — dashed lines in a blended color of both tracks. Represent AI-detected thematic similarity and shared audience correlation. Always subtler than same-track connections.
- **Glow filter** — SVG feGaussianBlur creates a soft light effect on connection lines.

### Z-Order and "Peek" Interaction

- Default z-order: **engagement-based** (higher engagement = closer to viewer)
- **Peek interaction** for occluded items: tapping a partially hidden item brings it to the foreground temporarily without opening the detail view. Second tap opens details. Tap elsewhere or timeout returns it to its original z-position.

### Reactions

- Multiple emoji/stamp types (not just likes) — fans choose from a set of reactions
- Reaction variety influences visual effects (different emoji → different glow color shifts)
- Total engagement (reactions + comments + views) collectively shapes item appearance
- Paid expansion packs for additional emoji/stamps (see Idea 004)

### Detail View

Bottom-sheet style expansion on tap, showing:
- Large media preview
- Full reaction breakdown (all emoji types with counts)
- Comment count and view count
- Track label, date, content type, duration

## Performance Strategy

This visual design is more complex than a standard feed. The following architectural decisions ensure acceptable performance:

| Concern | Decision |
|---------|----------|
| Layout computation (collision avoidance) | **Server-side pre-calculation**. API returns `{x, y, width, height}` per item. Client just renders. |
| Connection line rendering | **Canvas2D or WebGL** (not SVG) in production. Only draw connections for visible items. |
| Glow effects | GPU-composited layers. Limit simultaneous glows to items in viewport. |
| Large item counts (1000+) | **Virtual scrolling** — only render items in/near the viewport. |
| Engagement-driven re-layout | **Batched server-side recalculation** (e.g., every 5 minutes), not real-time on every reaction. |
| Thumbnails | Lazy loading with Intersection Observer, appropriately sized. |

### Tech Stack Implications

This design favors frameworks with strong custom rendering capabilities:
- **Flutter** — CustomPainter + SliverList, GPU acceleration, strongest fit
- **Web (React)** — viable with react-virtuoso + Canvas layer, but mobile browser performance is a concern
- **Native (Swift/Kotlin)** — best raw performance, highest development cost

## Consequences

- The timeline has a distinctive visual identity unlike any existing platform
- Engineering cost is meaningfully higher than a standard feed
- Server-side layout computation adds backend complexity but dramatically improves client performance
- The constellation metaphor provides a coherent design language that can extend to other features (profile pages, discovery, etc.)
- Artists have real curation power through the importance slider without needing design skills

## Related

- ADR 004 — DAW-style multi-track timeline (concept)
- ADR 005 — Open-core model (reaction packs as premium feature)
- Idea 001 — Theme customization
- Idea 004 — Emoji/stamp reactions
- Idea 005 — Synapse timeline neural network metaphor
- Mockup: `docs/mockups/timeline-v1.html`
