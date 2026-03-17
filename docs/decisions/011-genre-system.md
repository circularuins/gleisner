# ADR 011: Genre System — Self-Declared Genres with Community Normalization

## Status

Draft

## Context

The Discover tab (ADR 009) needs a way to filter and browse artists. The obvious approach — platform-defined genre categories — conflicts with Gleisner's core principles: centralized categories remove self-determination, and fixed taxonomies cannot represent the full diversity of creative activity.

Several alternatives were evaluated and rejected:

- **Platform-defined categories** (e.g. Music / Visual Art / Film): Central authority decides what genres exist. Cannot evolve with the community.
- **Fully free-form tags**: Leads to fragmentation (`Music`, `music`, `音楽`, `MUSIC`) and becomes unusable for filtering.
- **Track-based filtering**: Tracks are personal organizational tools for an artist's own timeline. A musician's "Play" track and a painter's "Play" track share a name but not a meaning. Filtering across artists by track name is a category error.
- **Media-type filtering** (Audio / Video / Image / Text): Technically objective, but misaligned with Gleisner's experience. Users come to explore an artist's multifaceted mind, not to consume a specific media format.

The challenge: genres are valuable for both **artist identity expression** ("I am a flamenco guitarist") and **platform diversity visibility** ("Gleisner has musicians, painters, filmmakers, and more"). The question is not whether to have genres, but how to implement them without centralized control.

## Decision

### Self-Declaration with Community Normalization

Artists declare their own genres. The platform normalizes input through suggestion, and the community collectively determines which genres appear in Discover.

### Genre Input Flow

1. Artist enters free text in a genre field
2. The system suggests existing genres that match the input (fuzzy match, alias resolution)
3. If a matching genre exists, the artist selects it
4. If no match exists, the artist may propose a new genre name
5. The proposed genre is immediately visible on the artist's profile
6. When N or more artists use the same genre, it is promoted to a Discover filter chip

### Rules

- **Structure**: Flat (no hierarchy). `Music` and `Flamenco` coexist at the same level. Artists use multiple genres to express both broad and specific identity.
- **Multiple selection**: Allowed, with a cap (e.g. max 5 per artist) to prevent search optimization abuse.
- **Promotion threshold**: A genre appears as a Discover chip only when N artists (exact value TBD, likely 3–5) have selected it. Below that threshold, it exists only on individual profiles.
- **No forced removal**: Genres are never unilaterally removed or merged by the platform. Even if usage drops below the threshold, the genre remains on profiles — it simply stops appearing as a Discover chip.

### Suggestion & Normalization (AI-Assisted)

The suggestion logic resolves near-duplicates and aliases:

- Fuzzy text matching (typo tolerance)
- Language alias resolution (`Flamenco` ↔ `フラメンコ`)
- Semantic similarity detection (`Digital Art` ↔ `デジタルアート`)

This may be implemented as a simple coded algorithm initially, with AI-powered normalization as a future enhancement. Regardless of implementation, the suggestion is always a **proposal** — the artist makes the final choice.

### Transparency & Disclosure

The entire mechanism must be disclosed to users. Specifically:

- **Genres are self-declared**: "Genres are chosen by artists themselves, not assigned by the platform or an algorithm."
- **Discover visibility criteria**: "Genres appear in Discover when N or more artists identify with them."
- **Suggestion mechanism**: "Genre suggestions are based on similarity to existing genres."
- **HIGH SIGNAL criteria**: "Trending status is based on engagement volume."

A "How discovery works" link in the Discover UI provides access to this explanation — not intrusive, but never hidden.

### Discover Display

```
Discover filter chips (dynamic, based on community usage):

[All (142)] [Music (38)] [Flamenco (5)] [Digital Art (22)] [Photography (17)] ...

Each chip shows the number of artists in that genre.
New genres appear and disappear organically as artists join and evolve.
```

## Consequences

- Artists have full control over their genre identity — no external classification
- The genre taxonomy evolves with the community, not by platform decree
- The promotion threshold prevents empty or spam genres from cluttering Discover
- Flat structure with multiple selection allows nuanced self-description (e.g. `Music, Flamenco, Heavy Metal, Gadget`)
- The suggestion system reduces fragmentation without removing creative freedom
- Transparency builds trust and aligns with the Diaspora principle that systems should be understandable by their participants
- Initial implementation can be simple (string matching); AI normalization can be layered in later

## Related

- ADR 009 — Discover tab (interaction patterns)
- ADR 012 — Track system redesign (separating personal tracks from cross-artist taxonomy)
- ADR 001 — Project vision (self-determination, transparency principles)
