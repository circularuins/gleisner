# ADR 001: Project Vision

## Status

Accepted

## Context

Artists who are active across multiple disciplines face a fundamental problem with existing platforms: their creative identity is fragmented across services they do not control. A single platform policy change, algorithmic shift, or unjust ban can erase years of built-up presence overnight. The artist has no recourse and no portability.

Current platforms are designed around the platform's interests, not the creator's. Content is siloed by media type, discovery is driven by opaque algorithms, and the creator's relationship with their audience is mediated (and owned) by a third party.

## Decision

Build **Gleisner** — a decentralized platform where artists own their identity, data, and audience relationships. The core UI metaphor is a **DAW-style multi-track timeline** that unifies an artist's multifaceted activities into a single, navigable experience.

### Key principles

1. **Artist ownership** — The artist controls their identity, content, and connections. No platform can revoke access.
2. **Multi-track expression** — Different creative activities (music, visual art, writing, performance, etc.) coexist as parallel tracks, reflecting the full breadth of the artist's work.
3. **Decentralization** — No single point of failure or control. The artist's presence persists regardless of any single service's decisions.
4. **Audience agency** — Fans can solo, mute, or mix tracks to customize their experience of the artist's output.

### MVP approach

Start with a mockup-first approach to validate the DAW-style timeline concept before committing to specific technical implementations.

## Consequences

- The project requires solving both UX challenges (making multi-track timelines intuitive) and infrastructure challenges (decentralized identity and data ownership).
- Technology stack decisions are deferred until the core interaction patterns are validated through mockups.
- The scope is ambitious; phased delivery will be essential.
