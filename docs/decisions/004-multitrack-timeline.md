# ADR 004: DAW-Style Multi-Track Timeline UI

## Status

Accepted

## Context

Artists who work across multiple disciplines need a way to present their full creative identity in a unified, navigable format. Existing platforms either:

- Force content into a single-type feed (e.g., only photos, only videos)
- Present a flat, chronological stream that buries the relationships between different activities

We need a UI metaphor that is both powerful enough to represent multi-faceted creative work and intuitive enough for general audiences.

## Decision

Adopt a **DAW (Digital Audio Workstation) style multi-track timeline** as the core UI paradigm.

### The metaphor

In a DAW, a musician layers multiple tracks — vocals, drums, bass, synths — that play simultaneously along a shared timeline. Each track can be:

- **Soloed** — Listen to just this one track in isolation
- **Muted** — Hide this track from the mix
- **Adjusted** — Change the prominence of each track

Applied to an artist's platform:

| DAW concept | Platform equivalent |
|-------------|-------------------|
| Track | An activity stream (e.g., music releases, visual art, blog posts, live events) |
| Timeline | Chronological axis showing all activities |
| Solo | View only one type of activity |
| Mute | Hide a specific activity type |
| Mix | Custom combination of visible tracks |
| Transport controls | Navigate through the artist's history |

### Example track layout (abstract)

```
Timeline ──────────────────────────────────────►
Track A: ████  ██  ████████  ██
Track B: ██  ████  ██  ████████
Track C: ████████  ██  ████  ██████
Track D: ██  ██  ████  ██
```

Each block represents an activity or piece of content. The viewer can solo Track B to see only that stream, mute Track D if they're not interested, or view the full mix.

### Key design principles

1. **Time is the universal axis** — All content is anchored to when it was created or published.
2. **Tracks are artist-defined** — The artist chooses how to categorize their activities.
3. **The mix is audience-controlled** — Viewers customize their experience without affecting others.
4. **Progressive disclosure** — The default view is a simple, appealing mix; power-user controls are available but not required.

## Consequences

- The UI requires careful design work to make the DAW metaphor accessible to non-technical audiences.
- Performance optimization will be important — rendering many tracks with rich media over long timelines is computationally demanding.
- The data model must support flexible, artist-defined track types.
- Mockup-first validation (see ADR 001) is essential before committing to implementation details.
