# Gleisner MVP Requirements

> **Version:** 1.0
> **Date:** 2026-03-18
> **Status:** Draft
> **Source:** ADR 001–013, Idea 001–008, Mockups (8 screens)

---

## Table of Contents

1. [Context](#1-context)
2. [Entity Model](#2-entity-model)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [Post-MVP Features](#5-post-mvp-features)
6. [Appendices](#6-appendices)

---

## 1. Context

### 1.1 Problem Statement

Artists who work across multiple disciplines face a fundamental problem: their creative identity is fragmented across platforms they do not control. A single policy change, algorithmic shift, or unjust ban can erase years of presence overnight. Content is siloed by media type, discovery is driven by opaque algorithms, and the artist's relationship with their audience is mediated — and owned — by a third party.

### 1.2 Solution Overview

**Gleisner** is a decentralized platform where artists own their identity, data, and audience relationships. The core UI metaphor is a **DAW-style multi-track timeline** — a constellation map where content items are luminous nodes scattered across a dark canvas, connected by glowing synapse-like lines. Artists organize their multifaceted creative work into parallel tracks, and fans customize their experience by Soloing, Muting, or mixing tracks.

The name comes from Greg Egan's *Diaspora* — Gleisner robots bridge the digital and physical worlds, just as this platform bridges an artist's physical-world creative activities to their digital presence.

### 1.3 Target Users

| User Type | Description |
|-----------|-------------|
| **Artist** | Multi-disciplinary creators who want a unified presence they own. Primary actions: post, curate timeline, manage tracks, build Artist Page |
| **Fan** | Audiences who want to explore and engage with artists' full creative output. Primary actions: discover artists, Tune In, react, comment, follow users |

### 1.4 MVP Scope

**Single-instance deployment** — federation and decentralization protocol are deferred to post-MVP. The MVP validates the core UX: constellation timeline, multi-track model, posting flow, discovery, and the dual identity system (Profile + Artist Page).

| Priority | Meaning | Criteria |
|----------|---------|----------|
| **P0** | Must have | Core experience cannot function without it |
| **P1** | Should have | Significantly improves experience but not blocking |
| **P2** | Nice to have | Can be deferred without impacting core validation |

### 1.5 License

AGPL v3 — ensures all network deployments share modifications. Premium features offered separately under the open-core model (ADR 003, ADR 005).

---

## 2. Entity Model

### 2.1 User

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| email | string | unique, not null | — |
| password_hash | string | not null | — |
| display_name | string | not null, max 50 chars | — |
| username | string | unique, not null, `^[a-zA-Z0-9_]+$` | — |
| bio | text | max 160 chars | null |
| avatar_url | string | — | generative art (seeded from display_name) |
| is_artist | boolean | not null | false |
| interest_genres | derived | auto-aggregated from Tune In artists' genres | [] |
| created_at | timestamp | not null | now() |
| updated_at | timestamp | not null | now() |

### 2.2 Artist

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| user_id | UUID | FK → User, unique, not null | — |
| artist_name | string | not null, max 50 chars | — |
| artist_username | string | unique, not null | — |
| tagline | string | max 80 chars | null |
| bio | text | — | null |
| location | string | — | null |
| active_since | integer | year (e.g. 2019) | null |
| avatar_url | string | — | generative art (seeded from artist_name) |
| cover_image_url | string | — | generative art (seeded from artist_name) |
| tuned_in_count | integer | not null, >= 0 | 0 |
| created_at | timestamp | not null | now() |
| updated_at | timestamp | not null | now() |

### 2.3 Genre

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| name | string | unique, not null | — |
| normalized_name | string | unique, not null, lowercase | — |
| color | string | hex color | deterministic hash from name |
| artist_count | integer | not null, >= 0 | 0 |
| is_promoted | boolean | not null | false (promoted when artist_count >= N) |
| created_at | timestamp | not null | now() |

### 2.4 ArtistGenre

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| artist_id | UUID | FK → Artist, composite PK | — |
| genre_id | UUID | FK → Genre, composite PK | — |
| position | integer | ordering within artist's genres | 0 |

**Constraint:** Max 5 genres per artist.

### 2.5 Track

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| artist_id | UUID | FK → Artist, not null | — |
| name | string | not null, max 30 chars | — |
| color | string | hex color, not null | TBD (color picker or palette rotation) |
| position | integer | ordering within artist's tracks | 0 |
| created_at | timestamp | not null | now() |

**Constraints:** Min 1, max 10 tracks per artist.

### 2.6 Post

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| artist_id | UUID | FK → Artist, not null | — |
| track_id | UUID | FK → Track, not null | — |
| media_type | enum | VIDEO, AUDIO, IMAGE, TEXT | — |
| title | string | max 100 chars | AI auto-generated |
| description | text | — | null (required for TEXT type) |
| media_url | string | — | null |
| thumbnail_url | string | — | null |
| importance | float | 0.00–1.00 | 0.50 |
| duration_seconds | integer | — | null (VIDEO/AUDIO only) |
| view_count | integer | not null, >= 0 | 0 |
| layout_x | float | server-computed | — |
| layout_y | float | server-computed | — |
| layout_width | float | server-computed (46–170px) | — |
| layout_height | float | server-computed | — |
| layout_z | integer | engagement-based | — |
| created_at | timestamp | not null | now() |
| updated_at | timestamp | not null | now() |

### 2.7 Connection

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| source_post_id | UUID | FK → Post, not null | — |
| target_post_id | UUID | FK → Post, not null | — |
| connection_type | enum | AI_DETECTED, USER_EXPLICIT | — |
| group_id | UUID | nullable, for AI-detected group membership | null |
| created_at | timestamp | not null | now() |

**Constraint:** `source_post_id != target_post_id`

AI-detected connections use a group model (full mesh internally, displayed as temporal chain). User-explicit connections are point-to-point.

### 2.8 Reaction

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| post_id | UUID | FK → Post, not null | — |
| user_id | UUID | FK → User, not null | — |
| emoji | string | from preset palette | — |
| created_at | timestamp | not null | now() |

**Constraint:** Unique per (post_id, user_id, emoji) — toggle behavior.

### 2.9 Comment

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| post_id | UUID | FK → Post, not null | — |
| user_id | UUID | FK → User, not null | — |
| body | text | not null, max 500 chars | — |
| created_at | timestamp | not null | now() |

### 2.10 TuneIn

Fan → Artist relationship (one-way).

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| user_id | UUID | FK → User, composite PK | — |
| artist_id | UUID | FK → Artist, composite PK | — |
| created_at | timestamp | not null | now() |

### 2.11 Follow

User ↔ User relationship (each direction independent).

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| follower_id | UUID | FK → User, composite PK | — |
| following_id | UUID | FK → User, composite PK | — |
| created_at | timestamp | not null | now() |

**Constraint:** `follower_id != following_id`

### 2.12 ArtistLink

| Attribute | Type | Constraints | Default |
|-----------|------|-------------|---------|
| id | UUID | PK | auto |
| artist_id | UUID | FK → Artist, not null | — |
| category | enum | MUSIC, SNS | — |
| platform | string | e.g. "Spotify", "Instagram" | — |
| url | string | valid URL | — |
| position | integer | ordering within category | 0 |

### 2.13 ER Summary

```
User 1──1? Artist          (a user may optionally be an artist)
Artist 1──* Track           (an artist has 1–10 tracks)
Artist *──* Genre           (via ArtistGenre, max 5 per artist)
Artist 1──* Post            (an artist creates posts)
Artist 1──* ArtistLink      (an artist has external links)
Track  1──* Post            (each post belongs to one track)
Post   1──* Reaction        (fans react to posts)
Post   1──* Comment         (fans comment on posts)
Post   *──* Post            (via Connection: AI-detected or user-explicit)
User   *──* Artist          (via TuneIn: fan tunes in to artist)
User   *──* User            (via Follow: bidirectional social connection)
```

---

## 3. Functional Requirements

### 3.1 Authentication & Accounts

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-AUTH-001 | Users can sign up with email and password via a 4-step wizard (Welcome → Profile Setup → Genre Selection → Complete) | P0 |
| FR-AUTH-002 | Welcome step explicitly explains the two-tier account structure (Personal Account + Artist Upgrade) with visual cards | P0 |
| FR-AUTH-003 | Profile Setup collects display name, username (@-prefixed with URL preview), bio (optional, 160 chars), and avatar | P0 |
| FR-AUTH-004 | Avatar defaults to generative art seeded from display name; users can upload a photo | P1 |
| FR-AUTH-005 | Genre Selection step presents interest genres as tappable chips (skippable) | P1 |
| FR-AUTH-006 | Completion step shows CTA card for artist upgrade ("Ready to share your work? Become an Artist") | P0 |
| FR-AUTH-007 | Artist registration is a 4-step wizard (Intro → Artist Profile → Track Setup → Complete) accessible from signup completion or Profile settings | P0 |
| FR-AUTH-008 | Artist Profile step collects: cover image, artist avatar (separate from personal), artist name, tagline (80 chars), location, genres (up to 5) | P0 |
| FR-AUTH-009 | Completion step shows mini-preview of Artist Page reflecting actual input | P1 |
| FR-AUTH-010 | Personal and artist accounts have separate avatars, both with generative defaults | P0 |

### 3.2 Timeline

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-TIME-001 | Timeline displays posts as a constellation map — luminous nodes on a dark canvas connected by synapse lines | P0 |
| FR-TIME-002 | Vertical scroll, top = newest; left date spine with minimal date markers | P0 |
| FR-TIME-003 | Free scatter placement with collision avoidance (28 placement attempts per item, largest first) | P0 |
| FR-TIME-004 | Time-accurate vertical position within each day | P0 |
| FR-TIME-005 | Dynamic day height — days with more content get proportionally more vertical space; empty days compressed | P0 |
| FR-TIME-006 | Node size determined by importance (artist-set, 0.0–1.0) + engagement boost (log scale, capped at +35%). Range: 46–170px | P0 |
| FR-TIME-007 | Items above a size threshold become wider (landscape aspect ratio) | P1 |
| FR-TIME-008 | Track color glow aura on each node, intensity proportional to engagement | P0 |
| FR-TIME-009 | Rounded card shapes with track-specific border radius variation | P1 |
| FR-TIME-010 | Solo: view only one track. Mute: hide a specific track. Controls via track chips in sticky header | P0 |
| FR-TIME-011 | Peek interaction: tapping a partially hidden item brings it to foreground temporarily; second tap opens detail view | P1 |
| FR-TIME-012 | Z-order is engagement-based (higher engagement = closer to viewer) | P1 |
| FR-TIME-013 | Synapse connections: solid lines (same-track temporal), dashed lines (cross-track thematic/AI-detected) | P0 |
| FR-TIME-014 | Connection lines have glow filter; thickness/opacity scale with engagement | P1 |
| FR-TIME-015 | Layout computation is server-side; API returns {x, y, width, height} per item | P0 |
| FR-TIME-016 | Virtual scrolling — only render items in/near the viewport | P0 |
| FR-TIME-017 | Thumbnails lazy-loaded with Intersection Observer | P1 |
| FR-TIME-018 | Batched server-side layout recalculation (e.g. every 5 minutes), not real-time | P1 |

### 3.3 Detail View

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-DETL-001 | Bottom-sheet (85dvh, internal scroll) preserving timeline context | P0 |
| FR-DETL-002 | Handle + media area: 16:9 media display, play button (VID/AUD), duration badge, track tag (top-left), media type badge (top-right) | P0 |
| FR-DETL-003 | Meta info: track color tag, title, description, date + type + duration | P0 |
| FR-DETL-004 | Reaction area: tappable emoji pills (+1 toggle with scale bounce), "Add reaction" button with 8-emoji preset palette popover | P0 |
| FR-DETL-005 | Stats bar: comment count, view count | P0 |
| FR-DETL-006 | Comments section: up to 3 inline comments, "View all N comments" link, sticky bottom input with track-colored send button | P0 |
| FR-DETL-007 | Connected Posts: horizontal-scroll mini cards with connection-type badges (Linked / Related / Audience) | P1 |

### 3.4 Posting

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-POST-001 | 3-step quick flow: Track selection → Media selection → Review & Post. Each step is single-tap auto-advance | P0 |
| FR-POST-002 | Media types: Video, Audio, Image, Text | P0 |
| FR-POST-003 | Review screen shows media preview prominently with Post button immediately available | P0 |
| FR-POST-004 | Optional accordion fields: Title, Description, Importance, Related Post | P0 |
| FR-POST-005 | Title auto-generated by AI when skipped (Video/Audio: content analysis; Image: recognition; Text: first N chars) | P1 |
| FR-POST-006 | Importance slider (0.00–1.00) with live preview showing node appearance | P1 |
| FR-POST-007 | Related Post picker: searchable bottom sheet with track filter, creates explicit connection | P1 |
| FR-POST-008 | Description required for TEXT type only, optional for others | P0 |
| FR-POST-009 | All fields editable after posting | P0 |
| FR-POST-010 | On successful post → navigate to timeline with entrance animation (glow-in) | P1 |

### 3.5 Artist Mode

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ARTM-001 | Mode determined implicitly: viewing own timeline → Artist Mode; viewing another's → Fan Mode | P0 |
| FR-ARTM-002 | Quick-switch: circular avatar button in header switches to own timeline (Artist Mode) | P0 |
| FR-ARTM-003 | FAB (56px, "+" icon) appears at bottom-right in Artist Mode only; tapping opens posting flow | P0 |
| FR-ARTM-004 | "ARTIST" badge in header (monospace pill) + "Your Timeline" label in Artist Mode | P1 |
| FR-ARTM-005 | Long press (500ms) on node → context menu: Edit / Delete / Change Importance | P0 |
| FR-ARTM-006 | "⋮" menu inside detail bottom sheet with same operations | P0 |
| FR-ARTM-007 | Edit: title and description become inline-editable in bottom sheet with Save/Cancel | P0 |
| FR-ARTM-008 | Delete: confirmation dialog → fade out animation → remove from data → re-render timeline → toast | P0 |
| FR-ARTM-009 | Timeline tab persists last selected artist via localStorage | P0 |

### 3.6 Discover

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-DISC-001 | Genre filter chips displayed dynamically based on community usage (promoted genres with artist_count >= N) | P0 |
| FR-DISC-002 | Each chip shows the number of artists in that genre | P0 |
| FR-DISC-003 | "All" chip shows total artist count | P0 |
| FR-DISC-004 | Artist cards showing preview information; tapping navigates to Artist Page | P0 |
| FR-DISC-005 | Selecting an artist from Discover → navigating to Artist Page (not directly to Timeline) | P0 |
| FR-DISC-006 | Self-selection from Discover → Artist Mode on own Timeline | P1 |
| FR-DISC-007 | Artist search and filtering mechanism | P1 |
| FR-DISC-008 | "How discovery works" transparency link explaining genre promotion and engagement criteria | P1 |

### 3.7 Profile

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-PROF-001 | Display: avatar, display name, username, bio | P0 |
| FR-PROF-002 | Follow stats: following / followers count + Tuned In count (number of artists the user is Tuned In to) | P0 |
| FR-PROF-003 | Joined date displayed as "Joined Mon YYYY" (trust signal) | P1 |
| FR-PROF-004 | Recent fan activity feed: chronological list of comments, reactions, Tune Ins | P1 |
| FR-PROF-005 | For artist-registered users: prominent "Your Artist Page" link | P0 |
| FR-PROF-006 | Interests section: auto-detected genre chips aggregated from Tuned In artists, sorted by frequency | P1 |
| FR-PROF-007 | Self view: edit button (inline editing of name, bio, avatar) + Settings link | P0 |
| FR-PROF-008 | Other's view: read-only + Follow/Unfollow button | P0 |

### 3.8 Artist Page

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ARTP-001 | Section-based layout: Cover Image / Header / Genres / About / Links / Tracks / Recent Posts | P0 |
| FR-ARTP-002 | Cover image: generative art default or upload; avatar overlaps bottom of cover with gradient fade | P0 |
| FR-ARTP-003 | Header: artist avatar, name, username, [Tune In] button, Tuned In count | P0 |
| FR-ARTP-004 | Genre chips (same style as Discover chips) | P0 |
| FR-ARTP-005 | About section: location, active since, bio text | P0 |
| FR-ARTP-006 | Links section: MUSIC category (Spotify, Apple Music, etc.) + SNS category (Instagram, X, etc.) as chip buttons | P1 |
| FR-ARTP-007 | Tracks section with subtext "This artist's content streams" + track chips with colors | P0 |
| FR-ARTP-008 | Recent Posts: Latest (3–5 posts chronological) + Popular (3–5 posts by engagement) as compact cards | P0 |
| FR-ARTP-009 | Self view: edit mode for all sections | P0 |
| FR-ARTP-010 | Other's view: read-only | P0 |

### 3.9 Genre System

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-GENR-001 | Artists self-declare genres via tappable chips + inline text input for custom genres | P0 |
| FR-GENR-002 | Custom genres get auto-generated color via deterministic hash | P0 |
| FR-GENR-003 | Flat structure (no hierarchy); multiple selection, max 5 per artist | P0 |
| FR-GENR-004 | Genre suggestion with fuzzy matching when creating custom genres | P1 |
| FR-GENR-005 | Language alias resolution (e.g. "Flamenco" ↔ "フラメンコ") | P2 |
| FR-GENR-006 | Genre promoted to Discover chip when N or more artists use it (N = TBD, likely 3–5) | P0 |
| FR-GENR-007 | Genres never unilaterally removed; below-threshold genres remain on profiles but not in Discover | P0 |
| FR-GENR-008 | Transparency disclosure: "Genres are chosen by artists themselves, not assigned by the platform" | P1 |

### 3.10 Track System

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-TRCK-001 | Tracks are per-artist organizational tools (not used for cross-artist filtering) | P0 |
| FR-TRCK-002 | Template sets for onboarding: Musician, Visual Artist, Writer, Filmmaker, Custom (empty) | P0 |
| FR-TRCK-003 | Template selector: horizontal card UI in artist registration | P0 |
| FR-TRCK-004 | "What are Tracks?" explainer at top of track setup step | P0 |
| FR-TRCK-005 | Max 10 tracks per artist, min 1 | P0 |
| FR-TRCK-006 | Tracks can be renamed at any time; existing posts retain association | P0 |
| FR-TRCK-007 | Tracks can be deleted; posts on deleted track move to fallback or become untracked | P1 |
| FR-TRCK-008 | Artists can add new tracks at any time within the limit | P0 |
| FR-TRCK-009 | Each track has a color for visual identity | P0 |
| FR-TRCK-010 | Color assignment method: TBD (color picker or palette rotation) | P1 |

### 3.11 Connections

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-CONN-001 | AI-detected connections: system detects thematic similarity and audience correlation between posts | P1 |
| FR-CONN-002 | AI-detected connections use group model: full mesh internally, displayed as temporal chain (predecessor by timestamp) | P1 |
| FR-CONN-003 | User-explicit connections: artist links posts during creation via Related Post picker | P0 |
| FR-CONN-004 | User-explicit connections are point-to-point; deleting either end removes the connection | P0 |
| FR-CONN-005 | Group integrity: deleting a middle node in an AI-detected group never splits the group | P1 |
| FR-CONN-006 | Visual distinction: AI-detected = dashed synapse; user-explicit = solid synapse | P1 |
| FR-CONN-007 | Both connection types can coexist on the same post | P1 |

### 3.12 Reactions & Comments

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-REAC-001 | Multiple emoji reaction types (not just likes); 8-emoji preset palette | P0 |
| FR-REAC-002 | Reactions are toggle-based: tap to add, tap again to remove | P0 |
| FR-REAC-003 | Reaction pills displayed below each node on timeline and in detail view | P0 |
| FR-REAC-004 | Reaction variety influences visual effects (glow color shifts) | P2 |
| FR-REAC-005 | Comments: text input in detail bottom sheet with avatar + username + timestamp | P0 |
| FR-REAC-006 | Inline preview of up to 3 comments in detail view; "View all N comments" link for more | P0 |
| FR-REAC-007 | Total engagement (reactions + comments + views) shapes node size and glow on timeline | P0 |

### 3.13 Relationships

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-RELS-001 | Follow: user-to-user bidirectional social connection (each direction independent) | P0 |
| FR-RELS-002 | Tune In: fan-to-artist one-way relationship ("I want to receive this artist's timeline") | P0 |
| FR-RELS-003 | Tune In button on Artist Page; tapping adds artist to avatar rail and auto-navigates to Timeline tab | P0 |
| FR-RELS-004 | Returning to a Tuned In artist's page shows "Tuned In ✓" + "View Timeline" link | P0 |
| FR-RELS-005 | Tune Out available from Artist Page or settings | P0 |
| FR-RELS-006 | Artists cannot "Tune In" to fans as artists; relationship is intentionally asymmetric | P0 |
| FR-RELS-007 | Messaging available between mutual-Follow users only (not via Tune In) | P2 |

### 3.14 Navigation

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-NAVG-001 | Bottom navigation: Timeline, Discover, Profile (3 tabs) | P0 |
| FR-NAVG-002 | Avatar rail on Timeline tab: horizontal row of Tuned In artists' circular avatars below sticky header | P0 |
| FR-NAVG-003 | Avatar rail ordered by most recent update; unread posts indicated by colored ring | P0 |
| FR-NAVG-004 | Tapping avatar switches timeline to that artist; currently selected avatar highlighted | P0 |
| FR-NAVG-005 | Self avatar in rail for switching to Artist Mode (artist-registered users) | P0 |
| FR-NAVG-006 | Avatar rail scrolls with content (not sticky); track chips in header remain sticky | P0 |
| FR-NAVG-007 | Sticky header: small avatar + artist name + status badge (TUNED IN / ARTIST / none) + track chips | P0 |
| FR-NAVG-008 | Currently selected artist persisted to localStorage; restored on app restart | P0 |
| FR-NAVG-009 | Empty state (no Tune Ins): prompt "Tune In to artists to see their timelines here" + link to Discover | P0 |

---

## 4. Non-Functional Requirements

### 4.1 Performance

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-PERF-001 | Layout computation (collision avoidance) must be server-side; client renders pre-computed positions | P0 |
| NFR-PERF-002 | Connection line rendering via Canvas2D or WebGL (not SVG) in production; only draw visible connections | P0 |
| NFR-PERF-003 | Glow effects on GPU-composited layers; limit simultaneous glows to items in viewport | P1 |
| NFR-PERF-004 | Support 1000+ items per timeline via virtual scrolling | P0 |
| NFR-PERF-005 | Engagement-driven re-layout batched server-side (e.g. every 5 minutes) | P1 |
| NFR-PERF-006 | Thumbnail lazy loading with appropriate sizing | P0 |

### 4.2 Security

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-SEC-001 | Password hashing with modern algorithm (bcrypt/argon2) | P0 |
| NFR-SEC-002 | Input validation and sanitization on all user-generated content | P0 |
| NFR-SEC-003 | CSRF protection on all state-changing endpoints | P0 |
| NFR-SEC-004 | Rate limiting on authentication endpoints | P0 |
| NFR-SEC-005 | Media upload validation (type, size limits) | P0 |

### 4.3 Licensing

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-LIC-001 | Core platform licensed under AGPL v3 | P0 |
| NFR-LIC-002 | Open-core boundary test: "Can an artist fully own and control their creative presence without this feature?" — if no, must be in open core | P0 |

### 4.4 Architecture

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-ARCH-001 | API-first design: backend and frontend communicate only via API | P0 |
| NFR-ARCH-002 | Monorepo structure: `backend/` and `frontend/` co-located | P0 |
| NFR-ARCH-003 | Tech stack favoring strong custom rendering: Flutter (strongest fit), Web+Canvas, or Native (decision pending) | P0 |
| NFR-ARCH-004 | Section-based Artist Page architecture supporting future plugin extensibility | P1 |

### 4.5 Scalability

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-SCAL-001 | Single-instance deployment for MVP (no federation) | P0 |
| NFR-SCAL-002 | Architecture must not preclude future federation/decentralization | P1 |

### 4.6 Accessibility

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-A11Y-001 | All interactive elements keyboard/screen-reader accessible | P1 |
| NFR-A11Y-002 | Sufficient color contrast for text and UI controls (track colors used decoratively, not as sole information carrier) | P1 |

### 4.7 Internationalization

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-I18N-001 | UI strings externalized for future localization | P1 |
| NFR-I18N-002 | Support for Unicode in all user-generated content (display names, bios, posts, genres) | P0 |
| NFR-I18N-003 | Genre alias resolution across languages (e.g. "Flamenco" ↔ "フラメンコ") | P2 |

---

## 5. Post-MVP Features

Features identified in Ideas 001–008 and ADR TBD sections, explicitly deferred from MVP.

| Feature | Source | Description |
|---------|--------|-------------|
| Theme customization | Idea 001 | Artists customize timeline visual theme (colors, appearance). Premium feature candidate |
| Profile as homepage (Plugin system) | Idea 002 | Rich, customizable profile pages with plugin blocks (merch, events, links). Artists and fans alike |
| Reaction packs | Idea 004 | Paid emoji/stamp expansion packs for fan expression. Revenue model: user-side monetization |
| Thread view | Idea 006 | "Follow this thread" mode: filter timeline to show only a chain of connected posts |
| Live streaming | Idea 007 | Premium plugin: dedicated Live tab, auto-post recording to timeline, super chat |
| Auto-translation | Idea 008 | "Translate" button for cross-language content. Cache + on-demand for cost optimization |
| Desktop client | — | Full desktop experience (responsive or native) |
| Messaging | ADR 013 | Direct messages between mutual-Follow users (P2 in MVP scope) |
| Federation / decentralization | ADR 001 | Multi-instance protocol enabling cross-instance discovery and data portability |
| AI connection detection | ADR 010 | System-level thematic similarity and audience correlation analysis (P1 in MVP but complex) |
| Advanced analytics | ADR 005 | Premium: audience engagement metrics, trend analysis |
| Collaboration tools | ADR 005 | Premium: multi-artist features, guest appearances on timelines |
| Custom domain support | ADR 005 | Premium: managed SSL with custom domain |
| Tutorial/onboarding flow | ADR 013 | Guided first-use: Discover → first Tune In → Timeline (reduce cold-start problem) |

---

## 6. Appendices

### Appendix A: ADR Cross-Reference

| FR Domain | Primary ADR Sources |
|-----------|-------------------|
| Authentication & Accounts | ADR 013 (onboarding, signup/artist registration, avatar separation) |
| Timeline | ADR 004 (multi-track concept), ADR 006 (constellation visual, sizing, performance) |
| Detail View | ADR 006 (bottom sheet, reactions, connected posts) |
| Posting | ADR 007 (3-step flow, optional details, AI title, importance slider) |
| Artist Mode | ADR 008 (implicit mode, FAB, CRUD, localStorage persistence) |
| Discover | ADR 009 (artist selection flow), ADR 011 (genre chips), ADR 013 (navigation update) |
| Profile | ADR 013 (personal identity, fan activity, follow stats, interests) |
| Artist Page | ADR 013 (section-based layout, cover image, recent posts, Tune In) |
| Genre System | ADR 011 (self-declaration, normalization, promotion threshold, transparency) |
| Track System | ADR 012 (template sets, personal-only, color TBD, "What are Tracks?" explainer) |
| Connections | ADR 010 (AI-detected group model, user-explicit point-to-point, resilience) |
| Reactions & Comments | ADR 006 (emoji pills, engagement effects), Idea 004 (expansion concept) |
| Relationships | ADR 013 (Follow vs Tune In, avatar rail, asymmetric model) |
| Navigation | ADR 013 (bottom nav, avatar rail, sticky header, empty state, persistence) |

### Appendix B: Glossary

| Term | Definition |
|------|-----------|
| **Node** | A content item (post) on the timeline, displayed as a luminous card in the constellation |
| **Track** | An artist-defined content stream (e.g. "Play", "Compose", "Life"). Used for timeline organization and Solo/Mute filtering |
| **Solo** | View only one track on the timeline, hiding all others |
| **Mute** | Hide a specific track from the timeline |
| **Tune In** | A fan subscribing to an artist's timeline. One-way, fan → artist. Inspired by radio broadcast metaphor |
| **Follow** | A bidirectional social connection between two users (user ↔ user) |
| **Constellation** | The visual layout metaphor — content items as stars/neurons on a dark canvas |
| **Synapse** | SVG/Canvas curves connecting related items on the timeline, creating the neural network effect |
| **Importance** | An artist-set value (0.0–1.0) controlling a post's base visual size on the timeline |
| **Engagement boost** | Logarithmic function of (reactions + comments×3 + views×0.01), capping at +35% size increase |
| **Peek** | Interaction for occluded items: first tap brings to foreground temporarily, second tap opens detail |
| **Artist Mode** | Implicit mode activated when viewing own timeline; enables posting, editing, deletion |
| **Fan Mode** | Implicit mode when viewing another artist's timeline; enables reactions and comments only |
| **FAB** | Floating Action Button — the "+" button for creating posts, visible only in Artist Mode |
| **Avatar Rail** | Horizontal row of Tuned In artists' circular avatars on the Timeline tab |
| **Genre** | Self-declared creative category. Flat, no hierarchy. Promoted to Discover when N+ artists use it |
| **Promotion threshold** | The minimum number of artists using a genre before it appears as a Discover filter chip |
| **Group (Connection)** | Internal model for AI-detected connections: full mesh for resilience, displayed as temporal chain |
| **Template set** | Pre-defined track configurations for different artist types (Musician, Visual Artist, etc.) |
| **Detail view** | Bottom sheet (85dvh) showing full post content, reactions, comments, and connected posts |
| **Open-core** | Business model: core platform is AGPL, premium features offered separately |

### Appendix C: Open Questions

Items marked as TBD or "To Be Decided" across ADRs that require resolution before or during implementation.

| # | Topic | Source | Description |
|---|-------|--------|-------------|
| OQ-001 | Genre promotion threshold | ADR 011 | Exact value of N for genre promotion to Discover chip (likely 3–5, not finalized) |
| OQ-002 | Track color assignment | ADR 012 | Color picker vs palette rotation — deferred to implementation |
| OQ-003 | Track deletion behavior | ADR 012 | Posts on deleted track: move to fallback track or become "untracked"? |
| OQ-004 | User-explicit connection visual | ADR 010 | Solid synapse line detail: "potentially with a subtle link icon or different stroke pattern (detail TBD)" |
| OQ-005 | Technology stack | Gleisner CLAUDE.md | Backend, frontend, database, protocol all TBD. ADR 006 favors Flutter > Web+Canvas > Native |
| OQ-006 | Discover UI layout | ADR 009 | List, grid, search, categories, recommendations — all TBD |
| OQ-007 | Artist preview cards | ADR 009 | What information is shown on artist cards in Discover before tapping |
| OQ-008 | New/trending surfacing | ADR 009 | How new, trending, or recommended artists are surfaced in Discover |
| OQ-009 | First-time user onboarding | ADR 009, 013 | Onboarding flow guiding first-time users through Discover → first Tune In → Timeline |
| OQ-010 | Cross-instance discovery | ADR 009 | Relationship between Discover and the federated/distributed protocol |
| OQ-011 | CLA requirement | ADR 003, 005 | Whether a Contributor License Agreement is needed for dual-licensing premium components |
| OQ-012 | AI title generation impl | ADR 007 | Specific AI model/service for auto-generating titles from media content |
| OQ-013 | AI connection detection impl | ADR 006, 010 | Specific approach for detecting thematic similarity and audience correlation |
| OQ-014 | HIGH SIGNAL criteria | ADR 011 | "Trending status is based on engagement volume" — exact algorithm TBD |
| OQ-015 | Reaction palette content | ADR 006 | Which 8 emoji are in the default preset palette |
| OQ-016 | Initial language support | Idea 008 | Auto-translation initial language pairs (日英 only, or broader?) |
| OQ-017 | Generative art algorithm | ADR 013 | Specific algorithm for seed-based generative art (avatars, covers) |
| OQ-018 | Media storage | — | File storage strategy for uploaded media (S3-compatible, CDN, size limits) |
