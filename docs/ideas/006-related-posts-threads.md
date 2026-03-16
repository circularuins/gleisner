# Idea 006: Related Posts & Thread View

**Status:** Raw idea
**Date:** 2026-03-16

## Summary

Posts can be explicitly linked to a "related post" by the artist, forming visible chains (threads) on the timeline. AI also auto-detects relationships. The timeline gains a new view mode to isolate and follow a single thread of connected posts.

## Design

### Posting

- Optional "Related Post" field when creating a new post
- Artist can search/browse their own recent posts and select one as the parent
- Creates an explicit directional link: new post → related post
- Multiple posts can link to the same parent (branching threads)

### Connection Types (layered)

1. **Explicit (artist-set)** — strongest visual connection. Solid glowing line.
2. **AI-detected** — medium. Based on title/content/tag analysis. Dashed line.
3. **Audience-correlated** — weakest. Shared engagement patterns. Subtle line.

Explicit links override AI classification — the artist can connect posts that AI might not associate.

### Thread View Mode

In addition to Solo/Mute per track, the timeline gains a "Thread" mode:
- Tap a connected node → option to "Follow this thread"
- Timeline filters to show only the chain of connected posts
- Posts outside the thread fade out (like Mute, but for non-thread items)
- The connection line becomes prominent, tracing the creative journey
- Thread can span multiple tracks (e.g., a song idea in Compose → rehearsal in Play → live performance in Play → fan reaction video in English)

### Use Cases

- Composition journey: sketch → WIP → mix → master → release
- Skill progression: practice session 1 → 2 → 3 → breakthrough
- Project arc: idea → preparation → event → aftermath
- Cross-track narratives: inspiration (Life) → creation (Compose) → performance (Play)

## Related

- ADR 006 (synapse connections — this formalizes the connection types)
- Idea 005 (synapse/neural network metaphor — threads are explicit neural pathways)
