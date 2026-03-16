# ADR 008: Artist Mode & Content Management

## Status

Accepted

## Context

Idea 003 introduced the concept of Artist/Fan modes, and ADR 007 defined the posting flow. However, the specific mechanism for mode switching, the posting entry point (FAB), and content editing/deletion UX remained undefined. This ADR formalizes these decisions.

## Decision

### Mode Determination (Implicit)

Mode is determined automatically based on context — there is no explicit toggle:

- **Viewing your own timeline** → Artist Mode (automatic)
- **Viewing another artist's timeline** → Fan Mode (always)
- The Timeline tab persists the last selected artist via `localStorage`

### Quick-Switch

- After artist registration, a circular avatar button appears in the header (right side)
- Tapping it switches to the user's own timeline → automatically enters Artist Mode
- Selecting an artist from the Discover tab updates the Timeline tab → Fan Mode

### Post Creation Entry Point (FAB)

- In Artist Mode only, a 56px floating action button ("+" icon) appears at bottom-right
- Tapping the FAB navigates to the posting flow (`post-v2.html`)
- The FAB's presence itself serves as a mode indicator

### Node Editing

- **Long press (500ms)** on a node → context menu appears near the node (Edit / Delete / Change Importance)
- **"⋮" menu** inside the bottom sheet → same operations (Edit / Delete / Change Importance)
- **Edit** → title and description become inline-editable within the bottom sheet, with Save/Cancel controls
- All editing is Artist Mode only

### Node Deletion

- Selecting "Delete" shows a confirmation dialog ("この投稿を削除しますか？" + Cancel / Delete)
- On confirmation: node fades out, item is removed from DATA, timeline re-renders, toast notification shown

### Visual Indicators

- **"ARTIST" badge** in the header (monospace, small pill shape)
- **Artist name** changes to "Your Timeline" in Artist Mode
- **FAB visibility** — present only in Artist Mode

## Consequences

- Mode switching is frictionless and context-driven — no manual toggle needed
- Artists have full CRUD capabilities on their own timeline
- Long press provides quick access without opening the full detail sheet
- The bottom sheet "⋮" menu provides discoverability for the same operations
- Confirmation dialog prevents accidental deletion
- Fan Mode is clean and distraction-free — no editing UI visible
- localStorage persistence means the experience continues across page reloads

## Related

- Idea 003 — Artist/Fan mode concept
- ADR 007 — Posting flow (quick post with optional details)
- ADR 006 — Timeline visual design
- Mockup: `docs/mockups/timeline-v1.html`
