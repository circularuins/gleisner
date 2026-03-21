# ADR 019: Age Policy — Guardian-Managed Accounts for Lifelong Creative Logging

## Status

Draft — **Requires legal counsel review before implementation**

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

## Related

- ADR 001 — Project Vision (lifelong creative logging)
- ADR 014 — Decentralization Roadmap (DID, content propagation)
- ADR 016 — User Identity Privacy (PublicUserType separation)
- ADR 017 — Content Hash and Signature (provenance for minors' content)
- **ADR 018** — Copyright Protection (minors' content has additional protections)
- Idea 012 — Age Policy research
