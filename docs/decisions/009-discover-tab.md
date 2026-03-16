# ADR 009: Discover Tab — Artist Discovery & Timeline Integration

## Status

Draft

## Context

The bottom navigation includes a Discover tab alongside Timeline and Profile. ADR 008 established that selecting an artist from Discover updates the Timeline tab and triggers Fan Mode. This ADR captures the confirmed interaction patterns while leaving detailed UI/UX for future decisions.

## Decision

### Confirmed Behavior

- **Artist selection**: Tapping an artist in the Discover tab navigates to the Timeline tab, which updates to display that artist's timeline
- **Mode integration**: Selecting another artist always results in Fan Mode (see ADR 008)
- **Persistence**: The Timeline tab remembers the last selected artist via `localStorage`, so returning to the app resumes where the user left off
- **Self-selection**: If the user selects their own profile from Discover, the Timeline switches to Artist Mode (same as the Quick-Switch button in the header)

### To Be Decided

- Discovery UI layout (list, grid, search, categories, recommendations)
- Artist search and filtering mechanisms
- How new/trending/recommended artists are surfaced
- Artist preview cards — what information is shown before tapping
- Onboarding flow for first-time users (how they find their first artists to follow)
- Follow/subscribe mechanics and their relationship to the Discover tab
- Relationship to the federated/distributed protocol (cross-instance discovery)

## Consequences

- The Discover → Timeline → Mode flow is established as the primary artist navigation pattern
- localStorage persistence reduces friction when returning to the app
- Detailed Discover UI design can proceed independently without affecting the established integration points

## Related

- ADR 008 — Artist Mode & content management (mode switching rules)
- ADR 004 — Multitrack timeline
- Idea 003 — Artist/Fan mode concept
