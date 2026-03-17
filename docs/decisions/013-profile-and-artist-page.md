# ADR 013: Profile & Artist Page — User Identity and Creative Identity Separation

## Status

Draft

## Context

The bottom navigation has three tabs: Timeline, Discover, and Profile. As we designed the Profile tab, a fundamental question emerged: an artist-registered user has two identities — a personal identity (fan/user) and a creative identity (artist). Mixing both in a single "Profile" screen creates confusion around:

- What "follow" means (user-to-user vs fan-to-artist)
- What information is displayed (personal bio vs artist portfolio)
- How the page evolves (a user profile is relatively static; an artist page becomes a rich, customizable hub)

This ADR separates the two concepts and defines the relationship system between users and artists.

## Decision

### Two Distinct Concepts

| Concept | Who has it | Purpose | Location |
|---------|-----------|---------|----------|
| **Profile** | Every user | Personal identity and social connections | Bottom nav "Profile" tab |
| **Artist Page** | Artist-registered users only | Creative identity and public-facing artist hub | Navigated from Profile, Discover, or direct link |

### Onboarding: Signup & Artist Registration

The two-identity model requires careful onboarding to avoid confusion. A user who intends to be an artist must first create a personal account, then upgrade — if this isn't communicated upfront, they may feel misled when they discover the personal signup wasn't for artist setup.

#### Signup Flow (Personal Account)

A 4-step wizard: Welcome → Profile Setup → Genre Selection → Complete.

**Step 1 (Welcome)** explicitly explains the account structure with two visual cards:
- **Personal Account**: "Discover artists, follow tracks, build your timeline. This is your personal identity on Gleisner."
- **+ Artist Upgrade**: "Create an Artist Page, set up tracks, and broadcast your work. You can upgrade anytime after signup."

This ensures users understand the two-tier structure before entering any credentials.

**Step 2 (Profile Setup)** collects: display name, username (@-prefixed with URL preview), bio (optional, 160 chars), and avatar. The avatar defaults to a generative image seeded from the display name, with an option to upload a photo. This avatar is the **personal** avatar.

**Step 3 (Genre Selection)** presents interest genres (skippable). These feed the auto-detected Interests on the Profile page.

**Step 4 (Complete)** confirms the personal account, shows what it includes (Timeline, Discover), and presents a prominent CTA card: "Ready to share your work? Become an Artist" — with the explanation: "Your personal account stays — the artist profile is a separate creative identity."

#### Artist Registration Flow (Upgrade)

A 4-step wizard: Intro → Artist Profile → Track Setup → Complete. Accessible from the signup completion screen or later from Profile settings.

**Step 1 (Intro)** shows feature cards (Artist Page, Tracks, Broadcasting) with a note: "Your artist profile is separate from your personal account. It has its own name, avatar, and cover image."

**Step 2 (Artist Profile)** collects: cover image (generative default or upload), artist avatar (separate from personal avatar, generative default or upload), artist name, tagline (80 chars), location, and genre declarations (up to 5, with custom genre creation).

**Step 3 (Track Setup)** starts with a "What are Tracks?" explainer, then presents template selection (see ADR 012) followed by editable track chips.

**Step 4 (Complete)** shows a mini-preview of the Artist Page (cover + avatar + genres + tracks reflecting actual input) with navigation buttons.

#### Separate Avatars

The personal account and artist account each have their own avatar:
- **Personal avatar**: Set during signup. Appears on the Profile tab, in Follow relationships, and in user-to-user contexts.
- **Artist avatar**: Set during artist registration. Appears on the Artist Page, in Tune In contexts, on the timeline avatar rail, and in Discover cards.

Both default to generative art (seeded from the respective display name) with an option to upload a photo. This separation ensures that the personal and creative identities remain visually distinct.

### Profile (Bottom Nav Tab)

The Profile tab displays the user's personal identity:

- Avatar, display name, username
- Bio / self-introduction
- User-to-user follow stats (following / followers) + **Tuned In count** (number of artists the user is Tuned In to — shows fan engagement level)
- **Joined date**: Displayed as "Joined Mon YYYY" — serves as a trust signal, especially important for a decentralized platform where account age helps users assess credibility
- **Recent fan activity**: A chronological feed of the user's activity as a fan — comments, reactions, Tune Ins. Shows "what this person has been engaging with" publicly
- **For artist-registered users**: A prominent link to "Your Artist Page"
- **Interests (auto-detected genres)**: Genres are automatically aggregated from the user's Tuned In artists, sorted by frequency. Not manually selected — derived entirely from Tune In behavior. Empty when no artists are Tuned In. Displayed as genre chips (same style as Artist Page genres) in an "INTERESTS" section between the Artist Page link and Recent Activity
- **Self view**: Edit button (inline editing of name, bio, avatar) + Settings link
- **Other's view**: Read-only + Follow button (user-to-user)

#### Messaging

Users who mutually follow each other can exchange direct messages. Messaging is available from the other user's Profile page when a mutual follow exists. This keeps messaging tied to the social (Follow) relationship, not the creative (Tune In) relationship — fans cannot DM artists simply by Tuning In.

### Artist Page

The Artist Page is the public-facing creative identity. The full timeline is accessed via the Timeline tab, but the Artist Page includes a **Recent Posts preview** to give visitors a taste of the artist's activity before Tuning In.

#### MVP Structure (Section-Based)

The page is composed of ordered sections, designed for future plugin extensibility:

```
┌─────────────────────────────┐
│ Cover Image                 │
│  (generative art banner)    │
├─────────────────────────────┤
│ Header                      │
│  Avatar / Name / Username   │
│  [Tune In] button           │
│  Tuned In: 12.4k            │
├─────────────────────────────┤
│ Genres                      │
│  [Music] [Flamenco] [Electronic] │
├─────────────────────────────┤
│ About                       │
│  📍 Location · Active since │
│  Bio (longer introduction)  │
├─────────────────────────────┤
│ Links                       │
│  MUSIC: [Spotify] [Apple Music] │
│  SNS:   [Instagram] [X]    │
├─────────────────────────────┤
│ Tracks                      │
│  "This artist's content streams" │
│  ● Play  ● Compose  ● Life │
├─────────────────────────────┤
│ Recent Posts                │
│  Simplified timeline preview│
│  (latest 3–5 posts, compact)│
└─────────────────────────────┘
```

#### Cover Image

A wide banner image at the top of the Artist Page (similar to X/YouTube headers). The default is a generative art canvas seeded from the artist's name; artists can also upload their own cover image. The choice is made during artist registration and can be changed later. The avatar overlaps the bottom of the cover with a gradient fade.

#### About Section

Expanded beyond a single tagline to include:

- **Location**: Activity base (e.g., "📍 Osaka, Japan")
- **Active since**: Year the artist started (e.g., "Active since 2019")
- **Bio**: A longer introduction text separate from the tagline

Location and active-since are displayed on a single line for compactness.

#### Links Section

External links organized into two categories:

- **MUSIC**: Streaming platforms (Spotify, Apple Music, SoundCloud, Bandcamp, etc.)
- **SNS**: Social media (Instagram, X, YouTube, etc.)

Displayed as chip-style buttons. Each link opens in-browser (in production) or shows a toast (in mockup). Artists without music links (e.g., visual artists, photographers) only show the SNS category.

The Recent Posts section has two subsections:

- **Latest**: The most recent 3–5 posts in chronological order — shows what the artist is currently working on
- **Popular**: The top 3–5 posts by engagement — shows the artist's best/most resonant work

Both are displayed as compact cards (not the full constellation layout). Their purpose is to increase Tune In conversion by letting visitors see both the artist's current activity and their highlights before committing.

#### Future Extensibility

The section-based layout allows plugin sections to be added:

```
MVP sections:
  Cover Image / Header / Genres / About / Links / Tracks / Recent Posts

Future plugin sections (examples):
  📦 Merch Store
  🎫 Ticket Sales / Event Calendar
  📰 Newsletter
  🔗 External Links
  🌐 Embedded Website (webview of artist's own HP)
  💬 Community / Fan Wall
  📊 Activity Stats (public)
```

Each section is an independent component. Artists can reorder, show/hide, and configure sections. Third-party plugin sections follow the same interface.

- **Self view**: Edit mode for all sections + section management (reorder, show/hide, add plugins)
- **Other's view**: Read-only

### Relationship System: Follow vs Tune In

Two distinct relationship types with different terminology:

| Relationship | Term | Direction | Meaning |
|-------------|------|-----------|---------|
| User ↔ User | **Follow** | Bidirectional (each direction independent) | Social connection. "I know this person" |
| Fan → Artist | **Tune In** | One-way (fan → artist only) | "I want to receive this artist's timeline" |

#### Why "Tune In"

- Aligns with Gleisner's DAW/broadcast metaphor: the artist broadcasts, the fan tunes in
- Naturally one-directional: a radio station doesn't "tune in" to its listeners
- No ambiguity with user-to-user "follow"
- "Tuned In: 12.4k" reads naturally as a count

#### Tune In Behavior

1. User visits an Artist Page
2. Taps "Tune In"
3. The artist is added to the avatar rail
4. **Automatic navigation**: The app navigates to the Timeline tab with the newly Tuned In artist selected by default — the user immediately sees their timeline
5. Returning to the Artist Page later shows "Tuned In ✓" + a "View Timeline" link
6. "View Timeline" navigates to the Timeline tab with that artist selected
7. "Tune Out" reverses the action (available from Artist Page or settings)

#### Artist-side: No reciprocal Tune In

Artists cannot "Tune In" to fans as artists. The relationship is intentionally asymmetric. An artist who wants to follow another artist's creative work Tunes In like any other fan. An artist who wants a personal social connection with someone uses the standard Follow.

### Timeline Tab: Avatar Rail

When a user has Tuned In to one or more artists, the Timeline tab displays an **avatar rail** below the header — a horizontal row of circular avatars:

```
┌─────────────────────────────────────┐  ← sticky
│ ◉ Yuta        ♪ TUNED IN     LIVE  │  ← avatar(small) + name + status badge
│ [● Play] [● Compose] [● Life] ...  │  ← track chips (Solo/Mute)
├─────────────────────────────────────┤  ← scrolls with content
│ ◉ ◎ ○ ○ ○ ○ ○ →                   │  ← Avatar rail
├─────────────────────────────────────┤
│ Timeline content                    │
│ ...                                 │
```

#### Timeline Header

The sticky header shows context about the currently viewed artist:

- **Small avatar** (24–28px circle) + **artist name**: Immediately communicates whose timeline is being viewed
- **Status badge**: Contextual indicator next to the name
  - "TUNED IN" — viewing another artist's timeline (Fan Mode)
  - "ARTIST" — viewing own timeline in Artist Mode (ADR 008)
  - No badge — when viewing own timeline in Fan Mode (default)
- **Track chips**: Solo/Mute controls for the current artist's tracks, always accessible

This ensures that even when the avatar rail has scrolled out of view, the user always knows whose timeline they are viewing and their relationship to that artist.

#### Avatar Rail Position

The avatar rail is placed **below the sticky header (including track chips)** and **scrolls with the timeline content**. This is a deliberate trade-off:

- **Track chips must remain sticky**: Solo/Mute filtering applies to the currently viewed timeline and should always be accessible
- **Avatar rail should not consume persistent screen space**: the rail is only needed when switching artists, not during timeline browsing. Scrolling it away preserves vertical space for the constellation layout
- **Semantic ordering** (artist selection above track selection) would be more logical, but the sticky/scroll constraint takes priority

#### Avatar Rail Behavior

- Avatars are ordered by **most recent update** (artists with new posts first)
- Avatars with **unread posts** have a colored ring (using the artist's primary genre color)
- Tapping an avatar switches the timeline to that artist's content (header updates accordingly)
- The currently selected avatar is highlighted (larger or different border style)
- If the user is an artist-registered user, their own avatar appears in the rail for switching to Artist Mode (ADR 008)
- Inspired by Instagram Stories UX but adapted for Gleisner's context: these are not ephemeral stories but persistent timeline switches
- **Persistence**: The currently selected artist is persisted locally (ADR 009). On app restart, the Timeline tab restores the last viewed artist — the user always returns to exactly where they left off

#### Rail Population

- Shows all Tuned In artists + self (if artist-registered)
- Scrollable horizontally when many artists are Tuned In

#### Empty State (No Tune Ins)

When the user has not Tuned In to any artist, the Timeline tab shows:

- No avatar rail (nothing to show)
- An empty state screen with a prompt: "Tune In to artists to see their timelines here" + a prominent link to the Discover tab
- No default timeline content is shown (the user has no content to display until they Tune In or create their own as an artist)

Future enhancement (post-MVP): A tutorial/onboarding flow that guides first-time users through Discover → first Tune In → Timeline, reducing the cold-start problem. The signup and artist registration flows (described above) address the initial account creation onboarding.

### Navigation Flow

```
Bottom Nav: Profile
  → Self Profile
    → Recent fan activity (comments, reactions, Tune Ins)
    → [Your Artist Page] → Self Artist Page (edit mode)
    → [Settings] → Settings screen
    → [Message] (on other's Profile, if mutual follow)
  → Other's Profile (via search, follower list, etc.)
    → [Follow] / [Unfollow]

Bottom Nav: Discover
  → Tap artist card → Artist Page (other's, read-only)
    → [Tune In] → auto-navigate to Timeline tab (artist selected)
    → (if already Tuned In) [View Timeline] → Timeline tab (artist selected)
    → Also shows link to user's Profile

Bottom Nav: Timeline
  → Avatar rail → tap avatar → switch to that artist's timeline
  → Avatar rail → tap self → Artist Mode (ADR 008)
  → Empty state (no Tune Ins) → prompt to Discover tab
```

## Consequences

- Onboarding explicitly communicates the two-tier account structure before credentials are entered, preventing the "I thought this was for artist setup" surprise
- Separate avatars for personal and artist accounts reinforce the identity separation visually
- Cover image and artist avatar offer both generative defaults and upload options, giving artists control without requiring effort
- "Follow" and "Tune In" are unambiguous — no user confusion about what each action does
- The avatar rail provides a lightweight, performant alternative to tabs for timeline switching
- Section-based Artist Page architecture supports future plugin extensibility without redesigning the page
- Recent Posts preview on Artist Page increases Tune In conversion without duplicating the full timeline
- Tune In → auto-navigate to Timeline creates an immediate "reward" for the action, reinforcing the value of Tuning In
- Artist-registered users manage two pages (Profile + Artist Page), which adds complexity but accurately reflects the dual identity
- The asymmetric Tune In model aligns with the Egan principle of self-determination: artists broadcast, fans choose what to receive
- Messaging tied to mutual Follow (not Tune In) protects artists from unsolicited fan DMs while enabling social connections
- Fan activity feed on Profile adds a social layer without cluttering the creative-focused Artist Page

## Related

- ADR 008 — Artist Mode & content management (mode switching, now triggered via avatar rail)
- ADR 009 — Discover tab (artist selection now navigates to Artist Page instead of directly to Timeline)
- ADR 011 — Genre system (genres displayed on Artist Page; custom genre creation in artist registration)
- ADR 012 — Track system redesign (tracks displayed on Artist Page; template sets chosen for onboarding)
- Mockup: `docs/mockups/signup-v1.html` (personal account signup flow)
- Mockup: `docs/mockups/artist-registration-v1.html` (artist upgrade flow)
