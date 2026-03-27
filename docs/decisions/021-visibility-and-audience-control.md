# ADR 021: Unified Visibility & Audience Control System

## Status

Draft

## Context

Gleisner needs visibility controls at multiple levels to support:

- Adult artists sharing WIP with a small circle before going public
- Hiding posts without deleting them (aligns with "resistance to erasure" principle)
- Restricting posts after publication (contractual reasons)
- Child safety: guardian-managed audience control (ADR 019)
- Artist-level privacy for users who want to restrict discoverability

Idea 014 identified the need for post-level visibility. This ADR expands the scope to a unified three-layer system covering artist profiles, individual posts, and audience lists. It integrates with the guardian-managed account system (ADR 019) and is compatible with the soft-deletion moderation model (Idea 018).

## Decision

### Four Visibility Layers

```
┌──────────────────────────────────────────────────┐
│  Layer 0: User-Level Visibility                   │
│  public | private                                 │
│  Controls fan-side profile, Follow, DM access     │
├──────────────────────────────────────────────────┤
│  Layer 1: Artist-Level Visibility                 │
│  public | private                                 │
│  Controls discoverability and profile access      │
├──────────────────────────────────────────────────┤
│  Layer 2: Post-Level Visibility                   │
│  public | draft | limited                         │
│  Controls individual post access                  │
├──────────────────────────────────────────────────┤
│  Layer 3: Viewer Lists                            │
│  followers | close_friends | guardian_approved     │
│  + custom lists                                   │
│  Controls "limited" post audience                 │
└──────────────────────────────────────────────────┘
```

Layer 0 and Layer 1 are independent — a user can be a private fan (Layer 0) while having a public artist profile (Layer 1). Layer 2/3 operate within the scope established by Layer 1.

### Layer 0: User-Level Visibility

Controls the fan-side identity: profile visibility, Follow relationships, comments/reactions exposure, and DM access. This layer applies to ALL users regardless of whether they have an artist profile.

#### Why user-level visibility is needed

Users interact as fans through comments, reactions, Follow relationships, and (future) DMs. These interactions expose user identity:
- Comment/reaction → username visible to other users
- Follower list → "this user follows this artist" relationship visible
- DM → direct contact channel to the user
- Profile → bio, displayName, avatarUrl visible

For minor accounts, this exposure creates legal risk (COPPA data exposure, UK Children's Code privacy-by-default) and safety risk (unwanted contact).

#### Visibility modes

| Setting | Public user | Private user |
|---------|-----------|-------------|
| Profile viewing | Anyone | Mutual followers only |
| Comment/reaction display | username + avatar shown | username only (semi-anonymous) |
| Follower list visibility | Visible | Hidden |
| DM receiving (future) | From followers | Mutual followers only |
| Search | Discoverable | Not discoverable |

#### Age tier defaults (user-level)

| Tier | User Visibility Default | Can change? |
|------|------------------------|-------------|
| <13 | Private (**locked**) | **No** — not even guardian can unlock |
| 13-15 | Private | Guardian can unlock |
| 16-17 | Private | Self-changeable |
| 18+ | Public | Self-changeable |

**Critical design decision**: <13 user visibility is **locked to private**, unlike artist visibility which guardians can unlock. Rationale:
- Making an artist public = guardian's deliberate choice to promote the child's creative work (clear benefit)
- Making a fan profile public = no promotional benefit, only increased exposure risk
- UK Children's Code "privacy by default" principle: fan-side identity should be protected by architecture, not policy
- Even if the child has a public artist profile, their fan-side interactions (reactions on other artists' posts, Follow relationships) remain private

#### Follow relationship restrictions by age

| Tier | Follow others | Be followed | Tune In |
|------|-------------|------------|---------|
| <13 | Not allowed | Not allowed | Guardian-approved artists only |
| 13-15 | Allowed (guardian notified) | Allowed (guardian notified) | Allowed (guardian notified) |
| 16-17 | Allowed | Allowed | Allowed |
| 18+ | Allowed | Allowed | Allowed |

#### Data model (user-level)

```sql
-- On users table (new column)
profile_visibility  VARCHAR NOT NULL DEFAULT 'public'
  -- 'public' | 'private'
```

### Layer 1: Artist-Level Visibility

Controls whether an artist profile is discoverable and publicly accessible.

| Mode | Discover | Search | `/@username` | Tune In |
|------|----------|--------|-------------|---------|
| **Public** | Visible | Indexed | Accessible | Anyone can Tune In |
| **Private** | Hidden | Not indexed | Requires approval | Approval required |

- Switching to private **preserves existing Tune In relationships** (existing fans keep access)
- New Tune In requests require artist approval (like Instagram's private follow request)
- Default: public for adults (18+), private for minors (guardian-controlled per ADR 019)
- Guardian can unlock to public for any age tier — child artists actively promoting their work under parental supervision need full discoverability. Gleisner's value as a promotion platform must not be undermined by overly restrictive defaults

### Layer 2: Post-Level Visibility

Controls individual post access within the artist's audience scope.

| Visibility | Who can see | Timeline | contentHash |
|-----------|------------|---------|-------------|
| **Public** | Everyone within artist scope (Layer 1) | Displayed | Computed |
| **Draft** | Author only | Hidden | Computed (lifelong log includes drafts) |
| **Limited** | Users on attached viewer lists (Layer 3) | Displayed to authorized viewers only | Computed |

- Default for all users: public (within the artist's visibility scope)
- Guardian-managed accounts (<13): if the guardian keeps the artist private, posts are effectively limited to approved viewers (Layer 1 enforces this). If the guardian unlocks to public, posts follow normal public visibility
- Visibility changes do not alter contentHash (visibility is metadata, not content)

### Layer 3: Viewer Lists

Viewer lists define the audience for "limited" posts.

| List type | Management | Description |
|-----------|-----------|-------------|
| **followers** | Automatic | All users who follow/Tune In to the artist |
| **close_friends** | Artist-managed | Custom list of trusted users |
| **guardian_approved** | Guardian-managed | Allowlist for minor accounts (ADR 019) |
| **custom** | Artist-managed | Any named group (e.g., "collaborators", "label contacts") |

- "Followers only" is a predefined viewer list, not a separate visibility level — this keeps the model consistent
- A limited post can have **multiple viewer lists** (OR union — visible if user is on any attached list)
- Guardian-managed accounts (<13): `guardian_approved` list is managed by guardian. When artist is private, this is the effective audience. When guardian unlocks to public, viewer lists are still available for individual limited posts

### Integration with ADR 019 (Age Policy)

| Age Tier | User Visibility | Artist Visibility | Post Default | Follow | Audience Control |
|----------|----------------|------------------|-------------|--------|-----------------|
| <13 | Private (locked) | Private (guardian can unlock) | Public (within scope) | Disabled | Guardian manages |
| 13-15 | Private (guardian can unlock) | Private (guardian can unlock) | Public (within scope) | Allowed (notified) | Guardian can restrict |
| 16-17 | User's choice | User's choice | User's choice | Allowed | Self-managed |
| 18+ | User's choice | User's choice | User's choice | Allowed | Self-managed |

Key design principles:
- **User (fan) visibility for <13 is locked to private** — no promotional benefit to exposing fan identity, only risk. Not even guardian can unlock. This is the strictest layer.
- **Artist visibility for <13 can be unlocked by guardian** — deliberate choice to promote creative work under supervision. COPPA requires parental consent, not a ban on public presence.
- A <13 child can have a public artist profile (guardian-approved) while their fan-side interactions (reactions, comments on other artists' posts) remain private and semi-anonymous.

### Integration with Idea 018 (Content Moderation)

- Moderation soft-deletion (`moderation_status: hidden`) is **orthogonal** to visibility
- A moderated post is invisible regardless of its visibility setting
- Visibility setting is preserved during moderation and restored if appeal succeeds
- `moderation_status: hidden` (system action) vs `visibility: draft` (author action) are distinct states

### Data Model

```sql
-- On users table (new column)
profile_visibility  VARCHAR NOT NULL DEFAULT 'public'
  -- 'public' | 'private'

-- On posts table (new column)
visibility  VARCHAR NOT NULL DEFAULT 'public'
  -- 'public' | 'draft' | 'limited'

-- On artists table (new column)
profile_visibility  VARCHAR NOT NULL DEFAULT 'public'
  -- 'public' | 'private'

-- Viewer lists
CREATE TABLE viewer_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id UUID NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  list_type VARCHAR NOT NULL,  -- 'predefined' | 'custom'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  UNIQUE (artist_id, name)
);

-- Viewer list members
CREATE TABLE viewer_list_members (
  viewer_list_id UUID NOT NULL REFERENCES viewer_lists(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  added_by UUID REFERENCES users(id),  -- artist or guardian
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  PRIMARY KEY (viewer_list_id, user_id)
);

-- Post ↔ viewer list junction (for limited posts)
CREATE TABLE post_audience (
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  viewer_list_id UUID NOT NULL REFERENCES viewer_lists(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, viewer_list_id)
);
```

### Query Strategy (Performance)

- Add index on `posts.visibility` — most queries filter `WHERE visibility = 'public'`
- Public posts: simple index scan, no join needed
- Draft posts: filtered by `author_id = current_user AND visibility = 'draft'` — author-specific index
- Limited posts: require JOIN through `post_audience` → `viewer_list_members` — only executed when listing limited posts for a specific viewer
- Artist `profile_visibility` check is a single column read on the artist row (already fetched)

### Implementation Phases

#### Phase 1 (MVP): Post visibility + Artist visibility + User visibility

- Add `users.profile_visibility` column (`public` / `private`)
- Add `posts.visibility` column (`public` / `draft`)
- Add `artists.profile_visibility` column (`public` / `private`)
- Filter non-public posts from all public queries (`posts`, `artistPosts`, `recentPosts`)
- Author can toggle post between public/draft
- Artist can toggle profile between public/private
- User can toggle their profile between public/private
- Private artist: Tune In requires approval (new `tune_in_requests` table or `pending` status)
- Private user: profile only visible to mutual followers, comments show username only
- Resolve #62 (`artistPosts` visibility filter)

#### Phase 2: Limited visibility + Viewer lists

- Add `limited` visibility option
- Create `viewer_lists`, `viewer_list_members`, `post_audience` tables
- Predefined lists: `followers`, `close_friends`
- UI for managing viewer lists and assigning to posts

#### Phase 3: Guardian integration

- `guardian_approved` viewer list auto-created for minor accounts
- Guardian UI for managing the list
- Enforce user profile private-locked for Tier 1 (<13) accounts
- Enforce Follow disabled for Tier 1 (<13) accounts
- Guardian notification system for Tier 2 (13-15) Follow/Tune In activity
- Integrate with ADR 019 tier transitions (auto-unlock at age boundaries)

## Consequences

- Users (fans) gain control over their profile exposure — critical for minors and privacy-conscious users
- Artists gain fine-grained control over who sees their content and profile
- The separation of user (fan) visibility and artist visibility allows a child to have a public artist page while keeping their fan identity private — solving the tension between promotion and protection
- Draft support enables WIP workflow without cluttering the public timeline
- Private artists can use Gleisner without public exposure (important for minors and cautious users)
- Guardian can unlock artist visibility for promotion while user visibility remains locked — architecturally enforced child safety
- Guardian integration provides child safety at the architecture level, not as an afterthought
- Follow restrictions for <13 eliminate direct contact risk at the protocol level
- Viewer list model is extensible — new list types can be added without schema changes
- Performance impact is minimal for public content (index scan), higher for limited content (JOIN required but limited in scope)
- Federation (ADR 014): visibility metadata will need to propagate to federated nodes — deferred to federation implementation phase

## Related

- [Idea 014](../ideas/014-post-visibility-and-audience-control.md) — Original idea (superseded)
- [Idea 018](../ideas/018-content-moderation.md) — Content moderation (orthogonal)
- [Idea 021](../ideas/021-visibility-and-audience-control.md) — Detailed idea exploration
- [ADR 019](019-age-policy.md) — Age policy / guardian accounts
- [ADR 017](017-content-hash-signature.md) — Content hash & signature
- [ADR 014](014-decentralization-roadmap.md) — Decentralization roadmap
- [Issue #62](https://github.com/circularuins/gleisner/issues/62) — artistPosts visibility check
