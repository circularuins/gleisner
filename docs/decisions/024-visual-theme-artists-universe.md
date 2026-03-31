# ADR 024: Visual Theme — The Artist's Universe

## Status

Accepted

## Context

ADR 006 established the constellation model as Gleisner's timeline visual metaphor — content items as luminous nodes, connected by glowing synapse lines. As development progressed, we needed to visually differentiate four connection types (reference, evolution, remix, reply).

Initial attempts used **shape-based differentiation** — zigzag lines for evolution, double helix for remix, dotted lines for reply, etc. These failed: the varying shapes looked visually noisy and inconsistent on the dark canvas, degrading the elegant simplicity of the constellation.

The breakthrough came from shifting to **motion-based differentiation**: glowing dots that travel along the synapse curves, with each connection type expressed through distinct movement patterns rather than line geometry. This approach preserves the clean visual aesthetic while adding meaningful, discoverable information.

This success crystallized a broader visual theme that unifies all of Gleisner's visual language.

## Decision

### The Artist's Universe

Gleisner's visual identity is built on a three-layer spatial metaphor:

| UI Element | Metaphor | Meaning |
|------------|----------|---------|
| **Posts** | Stars | Each piece of creative work is a point of light in the artist's universe |
| **Connections** | Constellations | Relationships between works form patterns — the artist's creative constellations |
| **Travelling dots** | Starships | Living energy flowing between stars, revealing the nature of each connection |

This metaphor frames two complementary experiences:

- **Fans** peer into another person's creative universe — exploring constellations, watching starships trace the hidden links between ideas
- **Artists** cultivate their own universe — each new post adds a star, each connection draws a new constellation, and the whole grows richer over time

### Connection Type Expression Through Motion

Each connection type has a distinct movement signature. The differences are subtle enough to be ambient, but discoverable when a user pays attention:

| Type | Dots | Motion | Metaphor |
|------|------|--------|----------|
| **reference** | 1 | Constant speed, source → target | A quiet pointer — one ship on a known route |
| **evolution** | 2 | Ease-in acceleration (t²) | Growth picking up momentum — ships accelerating into the future |
| **remix** | 4 (2+2) | Bidirectional, source ⇄ target simultaneously | Material mixing — ships carrying cargo both ways |
| **reply** | 3 | Pulsing alpha (sinusoidal oscillation) | Call and response — ships blinking in rhythmic dialogue |

### Design Principles

1. **Motion over shape** — Express meaning through how things move, not how they look. Static shape variation adds visual noise; motion variation adds life.
2. **Ambient discovery** — Type differences should be noticeable to an attentive viewer, not require a legend. The timeline should feel alive first, informative second.
3. **Viewport-aware animation** — Only connections visible on screen are animated. This is both a performance optimization and a design choice: the universe comes alive where you look.
4. **Consistent cosmic vocabulary** — New visual features should extend the star/constellation/starship metaphor. When in doubt, ask: "What would this be in the artist's universe?"

### Technical Implementation

- Dots are rendered in `ConstellationPainter` using cubic Bézier evaluation at parametric positions
- Each dot is a three-layer glow: outer blur (α 0.3, r=8), mid blur (α 0.6, r=4), core (α 0.9, r=2)
- Trailing particles (4 behind each dot) create a comet-like wake
- A single `AnimationController` (35s cycle) drives all dots via phase offsets
- Connection color interpolates from source track color to target track color along the curve

## Consequences

- Gleisner has a coherent visual identity that extends naturally from individual elements to the whole experience
- The "artist's universe" metaphor provides a design vocabulary for future features (e.g., profile = "universe overview", discovery = "telescope", collaboration = "docking")
- Connection types are meaningfully differentiated without the visual noise of shape variation
- The motion-based approach is GPU-friendly — no complex path geometry, just circle draws with blur
- The metaphor aligns with the Egan/Diaspora philosophical foundation: each artist's timeline is their own polis, a self-governed space of digital existence

## Related

- ADR 002 — Naming: Gleisner (physical-digital bridge)
- ADR 004 — DAW-style multi-track timeline
- ADR 006 — Timeline visual design: constellation model (predecessor, still valid for layout/sizing/interaction)
- yatima CLAUDE.md — Greg Egan "Diaspora" design philosophy
