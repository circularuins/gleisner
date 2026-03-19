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

### Default Tracks: Template Sets (Decided)

The current defaults (Play, Compose, Life, English) are retired as universal defaults. After evaluating four candidates, the **Template sets** approach was chosen based on the artist registration mockup implementation:

| Template | Default Tracks |
|----------|---------------|
| **Musician** | Play, Compose, Life |
| **Visual Artist** | Works, Process, Thoughts |
| **Writer** | Writing, Notes, Life |
| **Filmmaker** | Films, BTS, Stills |
| **Custom** | (empty — artist creates from scratch) |

The artist registration flow presents these as a horizontal card selector. Selecting a template populates the track list, which the artist can then freely edit (rename, add, remove) before completing registration.

The other candidates considered but not adopted:

| Approach | Why not |
|----------|---------|
| **No defaults** | High friction; blank-slate paralysis for new users |
| **Minimal universal defaults** | No truly universal track names exist across disciplines |
| **AI-suggested** | Adds unnecessary complexity at this stage |

#### Track Onboarding UX

The track setup step in artist registration includes a **"What are Tracks?"** explainer at the top of the page. This is critical because users encountering Tracks for the first time have no mental model for the concept. The explainer describes Tracks as "themed channels within your Artist Page" where "fans can follow individual Tracks to only see what interests them," with a concrete example (Play / Compose / Life for a musician).

#### Track Color Assignment (Implemented)

Artists specify a 6-digit HEX color (e.g., `#FF0000`) when creating or updating a track. The server validates the format (`/^#[0-9A-Fa-f]{6}$/`) and stores it as-is. No server-side palette rotation or collision prevention — artists have full color choice freedom.

This approach was chosen for simplicity (solo developer, MVP scope) and artist autonomy. If visual distinction across tracks becomes a UX issue, client-side palette suggestions or server-side constraints can be added later without schema changes.

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
- Template sets provide low-friction onboarding while respecting creative diversity across disciplines
- The "What are Tracks?" explainer in artist registration ensures first-time users understand the concept before configuring
- Existing mockups (timeline-v1.html, post-v1.html, post-v2.html) continue to use Play/Compose/Life/English as illustrative examples for a musician persona
- Fan-facing pages show "TRACKS" with the subtext "This artist's content streams" for clarity
- Track color is client-specified HEX (see "Track Color Assignment" section above)

## Related

- ADR 011 — Genre system (self-declared genres for cross-artist discovery)
- ADR 004 — Multitrack timeline (Solo/Mute, track-based visual layout)
- ADR 006 — Timeline visual design (track colors, constellation layout)
- ADR 009 — Discover tab (where genre filtering replaces track-based filtering)
- ADR 013 — Profile & Artist Page (onboarding flow, artist registration)
- Mockup: `docs/mockups/artist-registration-v1.html` (track template selection and setup)
