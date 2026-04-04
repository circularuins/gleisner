# ADR 025: Media Handling Strategy

## Status

Accepted

## Context

Gleisner is a lifelog service, not a high-quality unlimited media hosting service like YouTube or Instagram. A strategic policy for media file handling is needed, grounded in the service concept.

### Problems

1. Unlimited video/audio uploads would result in massive storage costs
2. Competing on the same playing field as major platforms is irrational
3. Differentiation as a lifelog must be clearly defined

## Decision

### Per-Media-Type Limits

| Media Type | Duration Limit | Size Cap (safety net) | Notes |
|-----------|---------------|----------------------|-------|
| Text | - | - | No storage limits |
| Image | - | - | HEIC support required |
| Video | **1 minute max** | 200 MB | Short video only |
| Audio | **5 minutes max** | 200 MB | Voice memos, demos |
| URL | - | - | OGP implementation for rich display |

### Per-User Storage Quota

- Image: 1 GB / user
- Video: 1 GB / user
- Audio: 1 GB / user
- Total: **3 GB / user (free tier)**
- Text & URL: No storage limits

When exceeded, users are guided to a paid plan (plan design TBD).

**Phase 0 (family only) does not enforce quota limits.**

### Strategic Positioning of URL Type

URL type is not mere link sharing — it is positioned as **an interface to externally hosted media data**.

- Videos over 1 minute → Post on YouTube, connect via URL
- Audio over 5 minutes → Post on SoundCloud, connect via URL
- OGP implementation enables rich display with thumbnail, title, and description

User guidance message:
> "For videos over 1 minute or audio over 5 minutes, post them on YouTube or SoundCloud, then share the link as a URL-type post on Gleisner."

### Phase Evolution

| Phase | Media Limits | Quota | Notes |
|-------|-------------|-------|-------|
| Phase 0 | Duration limits enforced, no quota | Not enforced | Family test |
| Phase 1 | Duration limits enforced | 3 GB / user | Invite-only |
| Phase 2 | Same + paid plan relaxation | Expandable via paid plan | Public launch |
| Future | Native apps may relax limits | Decentralized storage | Users choose their own storage |

## Consequences

### Positive

- Storage costs become predictable and controllable
- Clear differentiation from YouTube/Instagram
- URL type enables free users to build complete lifelogs
- Clear migration path to future decentralization

### Negative

- Users wanting to directly upload long-form video will be constrained
- External content via URL type is outside Gleisner's "resistance to annihilation" guarantee
- Paid plan design is required (separate consideration)

### Dependencies

- ADR 015 (R2 storage selection)
- Idea 023 (media storage cost optimization)
- Idea 024 (URL type OGP implementation)
