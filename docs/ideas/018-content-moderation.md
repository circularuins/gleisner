# Idea 018: Content moderation — balancing deletion policy with Gleisner's philosophy

**Status:** Exploring
**Date:** 2026-03-26

## Summary

Define how Gleisner handles content that violates legal requirements or platform policies, while honoring the core principle of "resistance to unreasonable deletion" (消滅への抵抗). The goal is to build a moderation system that is transparent, accountable, and compatible with future decentralization.

## The tension

Gleisner's founding philosophy (from Greg Egan's *Diaspora*):

> デジタル市民は「削除」されない — 分散型アーキテクチャによる永続性。理不尽な消去からの解放

But real-world operation requires content removal in certain cases. The question is not *whether* to moderate, but *how* to do it without betraying user trust or replicating the arbitrary moderation patterns of existing platforms.

## Three tiers of content removal

### Tier 1: Legal obligation (non-negotiable)

Content that **must** be removed by law, regardless of philosophy:

| Category | Requirement | Response time |
|----------|------------|---------------|
| CSAM | Immediate removal + law enforcement report | Immediate |
| Court orders | Comply with valid judicial orders | Per order timeline |
| DMCA takedowns | Remove or disable access (safe harbor) | Within "expeditious" timeframe |
| EU DSA / national hate speech laws | Region-specific compliance | Per regulation |

**Design implication**: These cases require hard deletion or irreversible access removal. No philosophical override.

### Tier 2: Platform policy violations (discretionary)

Content that violates Gleisner's terms but isn't illegal:

- Spam / automated abuse
- Impersonation / identity fraud
- Targeted harassment
- Graphic violence without artistic context
- Deliberately misleading content

**Design implication**: These should use **soft deletion** (invisibility), not permanent removal.

### Tier 3: Edge cases (requires human judgment)

- Parody vs impersonation
- Artistic expression vs harmful content
- Cultural context differences across regions
- AI-generated content attribution

**Design implication**: These need a clear appeals process and human review.

## Proposed approach: transparency-first moderation

### Core principle

**"Make invisible, not extinct"** — Content is hidden from public view but not permanently destroyed. The creator retains proof that it existed and can understand why it was hidden.

### Soft deletion model

```
┌─────────────────────────────────┐
│ Post (normal state)             │
│  visible: true                  │
│  contentHash: abc123            │
│  signature: (Ed25519)           │
├─────────────────────────────────┤
│ Post (moderated state)          │
│  visible: false                 │
│  moderationReason: "..."        │
│  moderatedAt: 2026-03-26        │
│  moderatedBy: "system" | "dmca" │
│  appealStatus: pending|denied|  │
│                restored         │
│  contentHash: abc123 (preserved)│
│  signature: (preserved)         │
└─────────────────────────────────┘
```

Key properties:
- **contentHash preserved**: Proves the content existed and was not tampered with
- **Ed25519 signature preserved**: Proves authorship even after moderation
- **Reason recorded**: Creator always knows *why* their content was moderated
- **Appeal status tracked**: Built-in mechanism for dispute resolution

### What the creator sees

When their content is moderated:
1. **Notification** with specific reason and policy reference
2. **Appeal button** — opens a structured form (not a black box)
3. **Timeline shows tombstone**: "This post was hidden on [date] — [reason]" (visible only to the creator)
4. **Content hash** remains accessible for proof of existence

### What the public sees

- Nothing (post is invisible)
- Or a tombstone: "Content removed: [policy violation | legal request]" (configurable per moderation type)

### What other platforms get wrong (and Gleisner should fix)

| Problem on existing SNS | Gleisner's approach |
|------------------------|---------------------|
| Silent deletion — no explanation | Always provide reason |
| No appeal, or appeal is a black hole | Structured appeal with timeline commitment |
| Inconsistent enforcement | Published policy + moderation log (anonymized) |
| Account-level bans for single violations | Graduated response (warn → restrict → suspend) |
| No proof content existed | contentHash + signature preserved |

## Graduated response model

```
1st violation  → Warning + content hidden + appeal available
2nd violation  → Content hidden + posting restricted (cooldown period)
3rd violation  → Account restricted (read-only mode)
Severe/illegal → Immediate action (Tier 1 rules apply)
```

At no point is the account *deleted* — consistent with "消滅への抵抗". The most severe action is permanent read-only mode (the digital citizen still exists but cannot broadcast).

## Compatibility with decentralization (ADR 014)

In a future federated/decentralized Gleisner:

- **Each node operator sets their own Tier 2 policy** (like Mastodon instances)
- **Tier 1 obligations remain universal** (legal requirements don't change with architecture)
- **Content lives on the author's node** — other nodes can refuse to federate it, but can't delete it from the source
- **"Defederation" replaces "deletion"** — "I won't relay your content" vs "I'll destroy your content"
- **contentHash enables cross-node verification** — if content is claimed to be removed, the hash proves it existed

This aligns with the Egan principle: the author's data is sovereign. Others can choose not to listen, but they cannot erase.

## Leveraging existing technical infrastructure

| Existing feature | Moderation use |
|-----------------|----------------|
| contentHash (SHA-256) | Proof of existence, tamper detection |
| Ed25519 signature | Proof of authorship even after moderation |
| DID (ADR 014) | Portable identity — moderation history follows the user, not the platform |
| DMCA flow (ADR 018) | Already defines takedown/counter-notice process |
| Age policy (ADR 019) | Minor-specific content restrictions |

## Data model changes needed

```sql
-- New fields on posts table
moderation_status  VARCHAR  -- 'visible' | 'hidden' | 'removed'
moderation_reason  TEXT     -- Human-readable reason
moderated_at       TIMESTAMP
moderated_by       VARCHAR  -- 'system' | 'admin' | 'dmca' | 'court_order'
appeal_status      VARCHAR  -- NULL | 'pending' | 'denied' | 'restored'
appeal_submitted_at TIMESTAMP
appeal_resolved_at  TIMESTAMP

-- Moderation log table (audit trail)
CREATE TABLE moderation_log (
  id UUID PRIMARY KEY,
  post_id UUID REFERENCES posts(id),
  action VARCHAR NOT NULL,  -- 'hide' | 'restore' | 'warn' | 'restrict'
  reason TEXT NOT NULL,
  performed_by UUID,  -- admin user ID
  created_at TIMESTAMP
);
```

## Open questions

1. **Who moderates in the MVP?** Solo developer = single admin. At scale, need community moderators or paid moderation team.
2. **Automated detection**: Should Gleisner use AI/hash-matching for proactive detection (like PhotoDNA for CSAM)? Likely yes for Tier 1.
3. **Transparency report**: Publish periodic moderation statistics? This builds trust and aligns with the transparency principle.
4. **Creator-side content warnings**: Allow artists to self-label sensitive content (NSFW, violence) to reduce moderation burden?
5. **Regional differences**: EU DSA requires different handling than US Section 230. How to handle multi-jurisdictional compliance?

## Related

- [ADR 018](../decisions/018-copyright-protection.md) — Copyright protection (DMCA safe harbor)
- [ADR 019](../decisions/019-age-policy.md) — Age policy (minor content restrictions)
- [ADR 014](../decisions/014-decentralization-roadmap.md) — Decentralization roadmap (federation implications)
- [ADR 017](../decisions/017-content-hash-signature.md) — Content hash & signature (tamper detection)
- [Idea 014](014-post-visibility-and-audience-control.md) — Post visibility control (related but different scope)
