# ADR 019: Age Policy — Guardian-Managed Accounts for Lifelong Creative Logging

## Status

Draft — **Requires legal counsel review before implementation**

> **Phase 0 Amendment (2026-05-08)** — see "Phase 0 Amendment" section near the end of this ADR. The Tier-1 "private locked" default is implemented as `users.profileVisibility = 'private'` at child creation, but the unlock path is exposed to the guardian (rather than locked entirely) for the duration of Phase 0's family-only deployment. The Tier-1 locked + COPPA-grade verification is deferred to Phase 1 SNS opening.

## Context

Gleisner's vision (ADR 001) includes lifelong creative logging — an artist's journey captured from childhood practice videos to professional performances. The founder's explicit intent is to avoid arbitrary age restrictions that other platforms impose, viewing them as a pain point Gleisner was built to solve.

However, multiple jurisdictions impose strict requirements on platforms that serve minors:
- **US COPPA**: Verifiable Parental Consent (VPC) required for data collection from children under 13
- **EU GDPR Art.8**: Parental consent required below age thresholds (13-16, varies by country)
- **UK Children's Code**: 15 principles including privacy-by-default for services accessible by under-18s
- **EU DSA Art.28**: Appropriate measures to ensure minors' privacy, safety, and security
- **Australia**: Social Media Minimum Age Act 2024 bans SNS accounts for under-16 (effective 2025-12-10)

Enforcement is accelerating: YouTube ($170M, 2019), Epic Games ($520M, 2022), TikTok (DOJ lawsuit, 2024), Meta (42-state AG lawsuit, 2023). The trend is toward larger penalties and broader scope (now including "addictive design", not just data collection).

### Critical legal insight

**COPPA does not require banning children.** It requires Verifiable Parental Consent for data collection from children under 13. A platform CAN serve children of any age with proper consent and data minimization. The founder's intent is legally achievable.

### Research basis

This ADR is based on comprehensive research documented in Idea 012, covering:
- Six major platform approaches (YouTube, Instagram, TikTok, Discord, Roblox, Bluesky/Mastodon)
- Legal requirements across US, EU, UK, Japan, Australia, Korea, China, Brazil
- Age verification technology analysis
- Key enforcement cases and penalties
- Gleisner-specific legal analysis (DID-based guardian delegation)

### Key lesson from existing platforms

> "Protection is architecture, not a feature."

Instagram, YouTube, TikTok, and Discord all retrofitted child safety features onto existing architectures — resulting in billions of dollars in fines, lawsuits, and structural conflicts between engagement metrics and safety. Gleisner has the opportunity to build protection into the protocol layer from day one.

## Decision

### Guardian-Managed Accounts as a First-Class Feature

Gleisner will support users of all ages through a **Guardian-Managed Account** system that is designed into the architecture from day one — not added as a safety layer later.

```
┌──────────────────────────────────────────────────┐
│  Age Tier System                                  │
│                                                   │
│  <13    Guardian-Managed (full control)           │
│  13-15  Guardian-Supervised (moderate oversight)  │
│  16-17  Guardian-Notified (light oversight)       │
│  18+    Self-Managed (full autonomy)              │
│                                                   │
│  Transition: seamless, no data loss               │
└──────────────────────────────────────────────────┘
```

### Age Tier Design

#### Tier 1: Guardian-Managed (<13)

**Account creation**: Guardian creates the account on behalf of the child.

**Consent**: Verifiable Parental Consent (VPC) obtained via FTC-approved method at account creation.

**Default settings (all locked by guardian)**:
- Profile: **private** (not discoverable, not visible to non-followers)
- DM: **disabled** (no messages from anyone outside guardian-approved list)
- Public timeline: **not visible** (content stored and timestamped but not publicly accessible)
- Search engine indexing: **off**
- Profiling/personalization: **off**
- Location sharing: **off**

**Capabilities**:
- Create and upload content (timestamped, content-hashed, building the lifelong log)
- View content from guardian-approved accounts
- Guardian can view all activity, manage settings, delete content

**Data collection**: DID + content only. No email, no phone number for the child account. Guardian's identity handles legal requirements. No behavioral tracking. No personalized recommendations.

#### Tier 2: Guardian-Supervised (13-15)

**Transition**: Automatic when age threshold is reached (based on birth date provided at account creation).

**Default settings (changeable with guardian approval)**:
- Profile: **private** (can be switched to public with guardian approval)
- DM: **followers only**
- Public timeline: **visible if profile is public**
- Search engine indexing: **off** (changeable with guardian approval)
- Profiling/personalization: **off**

**Capabilities**:
- All Tier 1 capabilities
- Upload without guardian pre-approval
- Receive DMs from followers
- Guardian receives weekly activity summary (not full content access)
- Guardian can still approve/deny setting changes

#### Tier 3: Guardian-Notified (16-17)

**Default settings (self-changeable)**:
- Profile: **private** (user can change to public without guardian approval)
- DM: **followers only** (user can change)
- Full feature access except age-gated content (if applicable)

**Guardian role**: Receives notification when significant settings change (e.g., profile goes public). Cannot override user's choices.

#### Tier 4: Self-Managed (18+)

**Transition**: Automatic at 18th birthday.
- Full feature access, full autonomy
- DID management authority transfers from guardian to user
- All historical content remains intact — the "lifelong creative log" is complete and owned by the artist
- Guardian access is revoked (unless user explicitly re-grants)

**This is the "unlock your creative journey" moment** — the artist's complete history, from childhood practice sessions to adulthood, becomes fully self-sovereign.

### Verifiable Parental Consent (VPC) Implementation

#### MVP: Email-Plus Method

The lowest-cost FTC-approved method that provides reasonable verification:

1. Guardian provides their email address
2. System sends confirmation email with unique link
3. Guardian clicks link and completes a secondary verification step (e.g., answering a security question, or confirming a code sent to a different channel)
4. Consent is recorded with timestamp and guardian's DID signature

**Limitation**: Email-plus is only approved for "internal use only" scenarios (no third-party data sharing). Since Gleisner's data minimization approach means minimal third-party sharing, this is sufficient for MVP.

#### Post-MVP: Enhanced VPC Options

- Credit card micro-charge verification (stronger legal standing)
- Government ID verification via third-party service
- Knowledge-based authentication (KBA)

#### Consent Record Architecture

```
Guardian Consent Record:
  - guardian_did: DID of the consenting guardian
  - child_did: DID of the child account
  - consent_method: "email_plus" | "credit_card" | "government_id" | "kba"
  - consent_scope: ["account_creation", "data_collection", "content_display"]
  - consent_timestamp: ISO 8601
  - guardian_signature: Ed25519 signature over the consent payload
  - revocable: true (guardian can revoke at any time)
```

This provides a cryptographically verifiable, timestamped consent record — stronger than what any existing platform maintains.

### DID-Based Guardian-Child Relationship

#### Protocol-Level Design

The guardian-child relationship is modeled in the DID layer, not just the application layer:

```
Child's DID Document:
  - id: did:web:gleisner.app:u:{child-uuid}
  - controller: [did:web:gleisner.app:u:{guardian-uuid}]  // Guardian has management authority
  - authentication: [{child's Ed25519 public key}]
  - metadata:
      account_type: "guardian_managed"
      tier: 1 | 2 | 3
      birth_year_month: "YYYY-MM"  // For tier transition calculation
```

At age 18 (Tier 4 transition):
```
  - controller: [did:web:gleisner.app:u:{child-uuid}]  // Self-controlled
  - metadata:
      account_type: "self_managed"
```

This means any service reading the DID document knows whether the account is guardian-managed, enabling consistent protection across a future federated environment.

#### Content Propagation for Minor Accounts

- Tier 1 content: `propagation: none` — stored on Gleisner's server only, not replicated to federated nodes
- Tier 2 content (if public): `propagation: restricted` — replicated with deletion capability
- Tier 3+: `propagation: standard` — normal federation rules apply

This ensures that minors' content can be fully deleted on guardian/parent request, even in a future federated architecture.

### Privacy by Default

Following the UK Children's Code principles and the universal lesson that **default settings determine real-world safety**:

| Setting | <13 | 13-15 | 16-17 | 18+ |
|---------|-----|-------|-------|-----|
| Profile visibility | Private (locked) | Private (guardian can unlock) | Private (self-changeable) | User's choice |
| DM | Off (locked) | Followers only | Followers only (changeable) | User's choice |
| Search engine indexing | Off (locked) | Off (guardian can unlock) | Off (changeable) | User's choice |
| Profiling/recommendations | Off (locked) | Off | Off (changeable) | User's choice |
| Location sharing | Off (locked) | Off (locked) | Off (changeable) | User's choice |
| Content filters | Strictest (locked) | Strict (guardian adjustable) | Moderate (self-adjustable) | User's choice |

### Data Minimization

#### What Gleisner collects for minor accounts

| Data | Tier 1 (<13) | Tier 2-3 (13-17) | Purpose |
|------|-------------|------------------|---------|
| DID | Yes | Yes | Identity (persistent identifier — COPPA-relevant) |
| Content (posts, media) | Yes | Yes | Core service |
| contentHash | Yes | Yes | Integrity/provenance |
| Birth year-month | Yes | Yes | Tier calculation |
| Guardian DID | Yes | Yes (Tier 2-3) | Legal compliance |
| Consent record | Yes | Yes | Legal compliance |
| IP address | Session only (not stored) | Session only | Abuse prevention |
| Device ID | No | No | Not needed |
| Email | No (guardian's only) | Optional (13+) | Notifications |
| Phone | No | No | Not needed |
| Behavioral data | No | No | Not collected |
| Location | No | No | Not collected |

#### What Gleisner does NOT collect for minor accounts

- No email or phone for <13 accounts
- No behavioral tracking or analytics
- No device fingerprinting
- No location data
- No profiling data
- No advertising identifiers
- No third-party tracking pixels/SDKs

### Data Retention and Deletion

- **Content**: Retained as long as the account exists (this IS the lifelong log)
- **Metadata** (IP, session data): Not stored beyond the session
- **Consent records**: Retained for legal compliance until child reaches 18 + 3 years (statute of limitations buffer)
- **Guardian deletion right**: Guardian can request deletion of all child's data at any time. Deletion is complete and irreversible.
- **No indefinite retention of non-essential data** (Amazon Alexa $25M lesson)

### Age Verification

#### Registration Flow

```
New user registration:
  1. Enter birth date (year-month only — day not needed)
  2. If age >= 18: standard registration
  3. If age 13-17: standard registration + notification about guardian features
  4. If age < 13: redirect to Guardian Account Creation flow
     a. Guardian creates their own account first (if not already registered)
     b. Guardian completes VPC (email-plus for MVP)
     c. Guardian creates child's account under their supervision
     d. Consent record created and signed
```

**Important**: Once Gleisner asks for age and learns a user is <13, COPPA obligations are triggered ("actual knowledge"). The system MUST NOT allow the user to simply go back and enter a different age.

#### Age Misrepresentation

- If a user is discovered to be <13 without a guardian account (e.g., reported by a parent, or detected through behavior):
  - Account is suspended (not deleted)
  - Guardian is contacted (if identifiable) to complete VPC
  - If VPC is completed, account is restored as Tier 1
  - If VPC is not completed within 30 days, account and data are deleted

### Multi-Jurisdiction Compliance

| Jurisdiction | Requirement | Gleisner's Approach |
|-------------|-------------|-------------------|
| **US (COPPA)** | VPC for <13, data minimization | Guardian-managed accounts + email-plus VPC + minimal data collection |
| **EU (GDPR Art.8)** | Parental consent below threshold (13-16) | Same guardian model, adjusted age thresholds per country |
| **UK (Children's Code)** | 15 principles for <18 | Privacy-by-default settings, no nudging, no profiling |
| **EU (DSA Art.28)** | Appropriate measures for minors | Tiered system + default privacy + no profiling-based ads |
| **Japan** | No specific child data law | Baseline protections exceed requirements |
| **Australia** | No SNS accounts <16 | **⚠ Requires special handling** — see below |

#### Australia Special Case

The Social Media Minimum Age Act 2024 bans SNS accounts for under-16. Options:

1. **Comply**: Enforce 16+ age gate for Australian users (geo-IP based)
2. **Argue exemption**: Gleisner may not meet the Act's definition of "age-restricted social media platform" if it can demonstrate that guardian-managed accounts provide superior protection
3. **Delay AU market entry**: Until legal clarity emerges

**Decision deferred** — requires legal counsel analysis of whether Gleisner's guardian-managed model could qualify for an exemption or alternative compliance pathway.

### COPPA Safe Harbor Program

**Recommendation**: Apply to kidSAFE or PRIVO COPPA Safe Harbor program before or shortly after launch.

Benefits:
- Significantly reduces FTC enforcement risk
- Provides ongoing compliance guidance
- Acts as a "good faith" signal to regulators
- Annual audit keeps compliance current

Cost: Varies by program, typically $5,000-$15,000/year for small platforms.

## Consequences

- Gleisner can serve users of **all ages** — fulfilling the founder's vision of lifelong creative logging
- Guardian-managed accounts provide **stronger protection** than competitors' age-gating (which is trivially bypassed)
- DID-based guardian-child relationship enables consistent protection across a future federated architecture
- Data minimization approach dramatically reduces COPPA compliance surface — less data collected = less risk
- The ownership transfer at age 18 is a unique differentiator: "Your creative journey is yours forever"
- Privacy-by-default settings align with UK Children's Code, DSA, and emerging global standards
- Email-plus VPC for MVP keeps implementation cost low while meeting legal requirements
- Australia compliance requires special handling and may delay AU market entry
- COPPA Safe Harbor certification is strongly recommended for risk reduction

## Items Requiring Legal Counsel Review

| # | Item | Priority |
|---|------|----------|
| LC-1 | VPC implementation: does email-plus meet requirements given Gleisner's data minimization? | Pre-launch |
| LC-2 | DID as "persistent identifier" under COPPA 2025 amendments: implications? | Pre-launch |
| LC-3 | Guardian consent record architecture: legally sufficient? | Pre-launch |
| LC-4 | Australia Social Media Minimum Age Act: does guardian-managed model qualify for exemption? | Pre-AU-launch |
| LC-5 | Content containing minors' voices/photos: COPPA coverage even with DID-only collection? | Pre-launch |
| LC-6 | Guardian abuse/custody dispute handling: legal obligations? | Pre-launch |
| LC-7 | GDPR Art.8 age thresholds: must Gleisner detect user's EU country for correct threshold? | Pre-EU-launch |
| LC-8 | Data retention for consent records: how long after child turns 18? | Pre-launch |
| LC-9 | Phase 0 amendment (guardian-only unlock without per-tier age check) acceptable under COPPA / UK Children's Code, given the family-only / non-discoverable / 0-yen deployment scope? | Pre-Phase-1 |

## Phase 0 Amendment (2026-05-08)

### Context

The full design above (Tier 1 locked, Tier 2 guardian-approved unlock, Tier 3 self unlock) targets a public SNS deployment. Phase 0 of Gleisner's release strategy
(`project_phased_launch_strategy.md`) is **family-only lifelong logging**, not a public SNS:

- 0-yen, invite-distributed
- No discovery feed, no search engine indexing, no federated propagation
- Members reach the platform through the founder's personal network — there is no path
  for an unrelated stranger to find a child's account

A bug in the post-author-visibility filter (PR-A / gleisner#363) hid every child-authored
post from every viewer, including the family members the platform exists for. This
amendment defines the minimum unlock path needed for Phase 0 to function while
deferring the legally-loaded pieces of the full design to Phase 1.

### What Phase 0 implements

- **`users.profileVisibility` is the source of truth for the post-author-visibility
  layer (Layer 0).** A child's posts are hidden from third parties iff
  `users.profileVisibility !== 'public'`. The `guardianId !== null` blanket hide
  introduced in PR-A is removed.
- **`createChildAccount` continues to insert `profileVisibility = 'private'`.** New
  child accounts remain hidden from third parties at creation time — the public path
  is opt-in.
- **A new mutation `setChildProfileVisibility(childId, profileVisibility)` lets the
  child's guardian flip the value.** Authorisation is `users.guardianId = ctx.authUser.userId`
  on the target row. The child themselves still cannot change their own
  `profileVisibility` (`updateMe` retains the existing `ctx.authUser.guardianId` reject).
- **The artist-visibility layer (`artists.profileVisibility`, Layer 1) is unchanged.**
  ADR 016's two-axis model is preserved: the user-level switch governs whether the
  child appears as a post author; the artist-level switch governs whether the artist
  profile and tracks are reachable. Both must be `'public'` for unauthenticated viewers
  to see the timeline.

### What Phase 0 deliberately defers (Phase 1 work)

| Phase 0 stance | Phase 1 target |
|---|---|
| Guardian unlock applies regardless of age tier | **Tier 1 (<13) `private` is locked** — guardian unlock disabled for under-13 accounts (COPPA §312.5 / UK Children's Code) |
| No tier-based UI variation | Tier 2 (13-15) shows guardian-approved unlock; Tier 3 (16-17) shows self unlock |
| No VPC (Verifiable Parental Consent) flow | Email-Plus VPC at `createChildAccount` time, recorded with guardian DID signature |
| No federated propagation rules per tier | `propagation: none / restricted / standard` per Tier 1 / 2 / 3+ |

### Why this is acceptable for Phase 0 only

The amendment widens the unlock path **but the deployment surface is closed**:

- **Not discoverable.** No `searchUsers` / `searchArtists` resolver exposes child rows
  outside the family-invite network. (PR-B / gleisner#370 added the artist-side gate;
  the user side is still closed because no public-facing user search exists.)
- **Not federated.** Phase 0 is single-instance Railway — no cross-node propagation.
- **Not indexed.** `robots.txt` denies search engines; no sitemap, no public profile
  HTML pages.
- **Membership is human-vetted.** The founder distributes invites personally; there
  is no anonymous signup path that lands a stranger on a child's profile.

These properties hold by deployment fact, not by code-level enforcement, so they
**must be re-verified before Phase 1 opens**. If any of them stop holding, Phase 1's
re-implementation of Tier-1 locking becomes a launch blocker rather than a planned
feature. This is captured as **LC-9** above and tracked as a Phase 1 SNS-release
preflight item.

### Phase 1 re-implementation checklist

When Phase 1 closes this amendment (replacing Tier-1 unlock with the locked design):

- [ ] `setChildProfileVisibility` rejects under-13 targets (`users.birthYearMonth` →
      derived age) with COPPA-friendly error
- [ ] VPC capture in `createChildAccount` (Email-Plus method, recorded with guardian
      Ed25519 signature)
- [ ] Tier-2 / Tier-3 differentiated UI (the user-level toggle becomes
      self-controllable at Tier 3)
- [ ] Federated propagation rules per tier (relevant once federation lands)
- [ ] LC-9 cleared by counsel: amendment-period exposure was within COPPA / UK
      Children's Code tolerance for non-discoverable, family-only deployment

### Cross-file constraint (do not edit in isolation)

`backend/src/graphql/access.ts` keeps `guardianId` on the
`isAuthorVisibleToViewer` input shape — and `backend/src/graphql/types/post.ts`
keeps fetching it as part of the `_authorMeta` prefetch — even though the
field stopped driving the boolean during this amendment. That isn't dead code:
the Tier-1 lock that Phase 1 re-installs needs the same prefetched
`guardianId` to refuse author visibility for under-13 children regardless of
their `users.profileVisibility` setting.

**Restoration must happen in a single PR.** When closing this amendment, the
PR that re-introduces a guardianId-aware branch in `isAuthorVisibleToViewer`
MUST also (a) install the Tier-1 reject in `setChildProfileVisibility`,
(b) gate the frontend Switch on the same tier, and (c) close
gleisner#378 + #381. Splitting these changes leaves the gate half-installed
on `main` and re-creates the original bug from PR-A in inverted form.

The TODO comment in `setChildProfileVisibility` cross-references this
section — they should always move together.

## Related

- ADR 001 — Project Vision (lifelong creative logging)
- ADR 014 — Decentralization Roadmap (DID, content propagation)
- ADR 016 — User Identity Privacy (PublicUserType separation)
- ADR 017 — Content Hash and Signature (provenance for minors' content)
- **ADR 018** — Copyright Protection (minors' content has additional protections)
- Idea 012 — Age Policy research
