# ADR 012: Track System Redesign — Decoupling Personal Tracks from Discovery Taxonomy

## Status

Draft

## Context

The current track system uses four hardcoded defaults — Play, Compose, Life, English — with up to six additional custom tracks per artist. This design has two problems:

1. **Default tracks are too specific**: Play/Compose/Life/English are tailored to a musician's workflow. A visual artist, writer, or filmmaker would find these meaningless. When Gleisner opens to a broader creative community, these defaults will alienate most new users.

2. **Tracks are personal, not taxonomic**: During the Discover tab design (ADR 009, ADR 011), it became clear that tracks serve as **personal organizational tools** for an artist's own timeline — not as cross-artist filtering axes. A musician's "Play" and a painter's "Play" share a name but not a meaning. Using track names for Discover filtering is a category error.

ADR 011 resolved the cross-artist taxonomy problem by introducing a self-declared genre system. This ADR addresses the track system itself: what defaults should exist, and how should artists configure their tracks?

## Decision

### Tracks Are Personal

Tracks remain a per-artist organizational tool for their timeline. They are not used for Discover filtering or cross-artist comparison. Their purpose is:

- Structuring an artist's own posting activity into meaningful streams
- Enabling Solo/Mute filtering on the timeline (ADR 004)
- Providing visual identity through track colors and the constellation layout

### Default Tracks: To Be Redesigned

The current defaults (Play, Compose, Life, English) are retired as universal defaults. The replacement approach is to be determined, with the following candidates under consideration:

| Approach | Description | Pros | Cons |
|----------|-------------|------|------|
| **No defaults** | Artist creates all tracks from scratch on signup | Maximum freedom | High friction for new users; blank-slate paralysis |
| **Template sets** | Choose from preset bundles (Musician, Visual Artist, Writer, Filmmaker, Custom) | Low friction; audience-appropriate | Platform decides what templates exist; may still feel limiting |
| **Minimal universal defaults** | 1–2 genuinely universal tracks (e.g. "Work" and "Life") + custom | Balance of guidance and freedom | Hard to find tracks that are truly universal |
| **AI-suggested** | Analyze the artist's genre selections (ADR 011) and suggest an initial track set | Personalized; low friction | Adds complexity; depends on genre system being in place |

The specific approach will be decided when the genre system (ADR 011) is implemented, as the genre context may inform which template or suggestion approach works best.

### Track Configuration Rules

Regardless of the default approach, these rules apply:

- **Maximum tracks**: 10 per artist (unchanged)
- **Minimum tracks**: 1 (an artist must have at least one track)
- **Renaming**: Tracks can be renamed at any time; existing posts retain their track association
- **Deletion**: Tracks can be deleted; posts on the deleted track move to a designated fallback track or become untracked
- **Colors**: Each track has an assigned color for visual identity on the timeline; artist can customize
- **Creation**: Artists can add new tracks at any time within the maximum limit

### UI Labeling for Fans

The internal concept name "Track" is retained, but fan-facing UI (e.g., artist page) adds a subtext to make the meaning clear: **"This artist's content streams"**. This avoids the confusion of showing "TRACKS" with opaque names like "Play" or "Compose" without context, while preserving the DAW metaphor for artists who understand it.

## Consequences

- Removing the musician-specific defaults eliminates a significant barrier for non-musician artists joining Gleisner
- The track system becomes a true personal tool, not confused with platform-level taxonomy
- The specific default approach is deferred until the genre system provides context for personalization
- Existing mockups (timeline-v1.html, post-v1.html, post-v2.html) continue to use Play/Compose/Life/English as illustrative examples; these will be updated when the default approach is finalized
- Fan-facing pages show "TRACKS" with the subtext "This artist's content streams" for clarity

## Related

- ADR 011 — Genre system (self-declared genres for cross-artist discovery)
- ADR 004 — Multitrack timeline (Solo/Mute, track-based visual layout)
- ADR 006 — Timeline visual design (track colors, constellation layout)
- ADR 009 — Discover tab (where genre filtering replaces track-based filtering)
