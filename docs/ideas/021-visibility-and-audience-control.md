# Idea 021: Unified Visibility & Audience Control System

**Status:** Promoted — ADR 021
**Date:** 2026-03-27

## Summary

A three-layer visibility system governing who can see content on Gleisner: post-level visibility (public/draft/limited), artist-level visibility (public/private), and limited audience lists (viewer allowlists). Designed to integrate with the guardian-managed account system (ADR 019) for child safety, and compatible with Idea 018's soft-deletion moderation model.

## Three Visibility Layers

### Layer 1: Artist-Level Visibility

Controls whether an artist profile is discoverable and publicly accessible.

- **Public**: Visible in Discover, searchable, timeline accessible via `/@username`
- **Private**: Not in Discover, not searchable. Only approved followers can see the profile and content
- Default for guardian-managed accounts (<13): always private (locked by guardian, per ADR 019)
- Default for 13-15: private (guardian can unlock)
- Default for 16+/adults: public (user's choice)

### Layer 2: Post-Level Visibility

Controls individual post access within the artist's audience.

- **Public**: Visible to everyone who can see the artist (respects Layer 1)
- **Draft**: Visible only to the author. Stored, timestamped, content-hashed, but not displayed on the timeline
- **Limited**: Visible only to users on the post's viewer list (Layer 3)
- Default for all tiers: public (within the artist's visibility scope)
- Guardian-managed accounts (<13): all posts effectively limited to guardian-approved viewers, even if "public" within that scope

### Layer 3: Limited Audience (Viewer Lists)

For "limited" posts, specifies who can see them.

- **Per-post viewer list**: Author selects specific users or groups
- **Predefined lists**: "Followers only", "Close friends" (custom list), "Guardian-approved" (auto-managed by guardian for minors)
- Guardian-managed accounts: viewer list is managed by guardian, not the child
- Use case: sharing WIP with trusted collaborators, child safety (guardian controls audience), contractual restrictions

## Integration Points

### ADR 019 (Age Policy / Guardian Accounts)

| Age Tier | Artist Visibility | Post Default | Audience Control |
|----------|------------------|-------------|-----------------|
| <13 | Private (locked) | Limited to guardian-approved list | Guardian manages viewer list |
| 13-15 | Private (guardian can unlock) | Public (within artist scope) | Guardian can restrict |
| 16-17 | User's choice | User's choice | Self-managed |
| 18+ | User's choice | User's choice | Self-managed |

### Idea 018 (Content Moderation)

- Moderation soft-deletion (`moderation_status: hidden`) is orthogonal to visibility — a hidden post is invisible regardless of its visibility setting
- Visibility setting is preserved during moderation (restored if appeal succeeds)
- `visible: false` from moderation vs `visibility: draft` from author intent are distinct states

### ADR 017 (Content Hash & Signature)

- Draft posts are still content-hashed and timestamped (the "lifelong creative log" includes drafts)
- Visibility changes don't alter contentHash (visibility is metadata, not content)

## Data Model Considerations

```
-- On posts table
visibility       VARCHAR  -- 'public' | 'draft' | 'limited'

-- On artists table
profile_visibility  VARCHAR  -- 'public' | 'private'

-- New table: viewer lists
CREATE TABLE viewer_lists (
  id UUID PRIMARY KEY,
  artist_id UUID REFERENCES artists(id),
  name VARCHAR(50),  -- 'followers' | 'close_friends' | 'guardian_approved' | custom
  list_type VARCHAR  -- 'predefined' | 'custom'
);

CREATE TABLE viewer_list_members (
  viewer_list_id UUID REFERENCES viewer_lists(id),
  user_id UUID REFERENCES users(id),
  added_by UUID,  -- who added this member (artist or guardian)
  PRIMARY KEY (viewer_list_id, user_id)
);

CREATE TABLE post_audience (
  post_id UUID REFERENCES posts(id),
  viewer_list_id UUID REFERENCES viewer_lists(id),
  PRIMARY KEY (post_id, viewer_list_id)
);
```

## Open Questions

1. **Can a limited post have multiple viewer lists?** (e.g., "close friends" + specific collaborators) — probably yes
2. **Should "Followers only" be a visibility level or a viewer list?** Leaning toward viewer list for consistency
3. **Artist private mode: what about existing Tune In relationships?** Need to decide if going private un-tunes existing fans
4. **Performance**: Visibility checks on every post query could be expensive. Need indexing strategy
5. **Federation (ADR 014)**: How do visibility restrictions propagate to federated nodes?

## Implementation Priority

1. **MVP**: `posts.visibility` column (public/draft) + artist `profile_visibility` (public/private)
2. **Phase 2**: Limited visibility + viewer lists
3. **Phase 3**: Guardian-managed audience control integration

## Related

- [Idea 014](014-post-visibility-and-audience-control.md) — Original idea (superseded by this unified design)
- [Idea 018](018-content-moderation.md) — Content moderation (orthogonal but compatible)
- [ADR 019](../decisions/019-age-policy.md) — Age policy / guardian accounts
- [ADR 017](../decisions/017-content-hash-signature.md) — Content hash & signature
- [ADR 014](../decisions/014-decentralization-roadmap.md) — Decentralization roadmap
