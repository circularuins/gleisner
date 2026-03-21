# ADR 018: Copyright Protection and Infringement Prevention

## Status

Draft — **Requires legal counsel review before implementation**

## Context

Gleisner is a UGC (User-Generated Content) platform where artists upload and share creative work. This creates two copyright risks:

1. **Inbound infringement**: Users upload content they don't own (claiming others' work as original)
2. **Outbound protection**: Content legitimately posted on Gleisner needs protection from unauthorized use elsewhere

As a platform that stores and publicly displays user-uploaded content, Gleisner must comply with copyright safe harbor laws across multiple jurisdictions (US DMCA §512, EU Copyright Directive Art.17, Japan Information Distribution Platform Act) to avoid direct liability for user-uploaded infringing content.

Gleisner's existing architecture — Ed25519 signatures, contentHash (SHA-256), and DID-compatible identities (ADR 014, ADR 017) — provides unique structural advantages for copyright protection that no existing platform offers. This ADR defines how to leverage these advantages while meeting legal requirements.

### Research basis

This ADR is based on comprehensive research documented in Idea 011, covering:
- Six major platform approaches (YouTube, Instagram, TikTok, SoundCloud, Bandcamp, Bluesky/Mastodon)
- Legal requirements across US, EU, Japan, Korea, and Australia
- Key case law (Viacom v. YouTube, BMG v. Cox, Lenz v. Universal)
- Gleisner-specific legal analysis (DID/IPFS/AGPL implications)

## Decision

### Three-layer copyright protection strategy

```
┌──────────────────────────────────────────────────┐
│  Layer 1: Legal Compliance (MUST — Day 1)        │
│  DMCA Safe Harbor, Notice-and-Takedown,          │
│  Repeat Infringer Policy                         │
├──────────────────────────────────────────────────┤
│  Layer 2: Structural Protection (MUST — Day 1)   │
│  Ed25519 provenance, contentHash dedup,          │
│  DID-based infringer tracking                    │
├──────────────────────────────────────────────────┤
│  Layer 3: Enhanced Protection (Post-MVP)         │
│  Perceptual hashing, external timestamping,      │
│  creator protection tools                        │
└──────────────────────────────────────────────────┘
```

### Layer 1: Legal Compliance (Pre-launch MUST)

#### 1.1 DMCA Designated Agent

- Register a Designated Agent with the U.S. Copyright Office ($6, electronic filing)
- Publish agent contact information on a public `/dmca` page
- Set 3-year renewal reminder (registration expires if not renewed)

#### 1.2 DMCA Policy Page

Public page at `/legal/copyright` containing:
- Designated Agent name, address, email (e.g., `dmca@gleisner.app`)
- How to submit a takedown notice (required elements per §512(c)(3))
- How to submit a counter-notification
- Repeat Infringer Policy summary
- Statement that Gleisner respects copyright and will respond expeditiously

#### 1.3 Notice-and-Takedown Process

```
Rights holder sends notice (email or form)
  → Gleisner verifies notice meets §512(c)(3) requirements
    → If valid: remove content within 24 hours (target)
      → Notify uploader with takedown details
        → Uploader may file counter-notification
          → Rights holder has 10-14 business days to file suit
            → If no suit: restore content (putback)
    → If invalid: request correction from notifier
```

**Implementation**: Admin dashboard with takedown request queue, status tracking, and audit log. All actions timestamped and logged for legal compliance.

#### 1.4 Counter-Notification Process

- Uploader submits counter-notification via form
- Must include: signature, identification of removed content, statement under penalty of perjury, consent to jurisdiction
- Forward counter-notification to original notifier
- If notifier does not file suit within 10-14 business days, restore content
- Fair use consideration: provide guidance to uploaders about fair use rights (Lenz v. Universal)

#### 1.5 Repeat Infringer Policy

Graduated enforcement:

| Strike | Action |
|--------|--------|
| 1st | Warning + copyright education prompt |
| 2nd | 7-day upload restriction + warning |
| 3rd | Account suspension (30 days) |
| 4th+ | Permanent account termination |

- Strikes expire after 12 months (no additional violations)
- Counter-notification success removes the strike
- **Policy must be consistently enforced** (BMG v. Cox lesson: revenue-motivated non-enforcement = Safe Harbor loss)
- Strike count tracked via DID, not just account — prevents circumvention via new accounts

#### 1.6 Terms of Service

Copyright-related clauses:
- Users represent they own or have rights to uploaded content
- Gleisner receives limited license for display/distribution (not ownership transfer)
- Right to remove infringing content without prior notice
- Right to terminate accounts for repeated infringement
- Indemnification clause for copyright claims arising from user uploads

### Layer 2: Structural Protection (Pre-launch, leveraging existing architecture)

#### 2.1 Cryptographic Provenance (already implemented via ADR 017)

Every post on Gleisner has:
- **contentHash** (SHA-256): deterministic hash of content fields
- **Ed25519 signature** (optional): cryptographic proof of authorship
- **DID**: links content to a self-sovereign identity
- **Server timestamp**: when the content was first recorded

This creates an **unforgeable chain of authorship** that no other platform provides. For indie artists who cannot access YouTube's Content ID, Gleisner's built-in provenance is a meaningful alternative.

#### 2.2 Exact-Copy Detection via contentHash

- On upload, compute contentHash and check against all existing hashes
- If exact match found: block upload with message "This content already exists on Gleisner"
- Exception: same author re-uploading (e.g., updating a post) — allowed
- Cost: O(1) hash lookup — trivial even at scale

**Limitation**: Does not detect near-copies (re-encoded, cropped, pitch-shifted). This is acceptable for MVP.

#### 2.3 DMCA Takedown Blocklist

- When content is removed via DMCA, record its contentHash in a blocklist
- Prevent re-upload of blocklisted content by any user
- Blocklist is persistent and survives account deletion
- Future: publish blocklist as a public API for fork compatibility (see AGPL considerations)

#### 2.4 DID-based Infringer Tracking

- Copyright strikes are recorded against the user's DID, not just the account
- In a future federated environment, strike history can follow the DID across instances
- This solves the decentralized platform's biggest copyright challenge: repeat infringer tracking

### Layer 3: Enhanced Protection (Post-MVP)

#### 3.1 External Timestamping

- Integrate OpenTimestamps (Bitcoin blockchain anchoring) for contentHash
- Provides third-party verifiable proof that "this content existed at this time"
- Gleisner's server timestamps are self-issued and thus weak evidence in court; blockchain-anchored timestamps are far stronger
- Batch processing for cost efficiency (e.g., daily batch of all new content hashes)

#### 3.2 Perceptual Hashing

- Add perceptual hash (pHash) computation alongside contentHash
- Detects near-copies: re-encoded audio, resized images, cropped videos
- Two-layer defense: contentHash (exact) + pHash (fuzzy)
- Consider existing libraries: Audible Magic (audio), pHash (images/video)
- Trigger: when platform scale justifies the computational cost

#### 3.3 Provenance Export ("Proof of Authorship" Certificate)

- Allow creators to export a signed document containing:
  - contentHash + timestamp
  - Ed25519 signature
  - DID
  - Optional: OpenTimestamps proof
- Usable as evidence in copyright disputes on other platforms
- Differentiator: "Gleisner protects your work even outside Gleisner"

#### 3.4 Rights Holder Portal (at scale)

- Self-service portal for rights holders to:
  - Submit reference hashes for proactive matching
  - View match reports
  - Issue takedowns directly
- Only justified at significant scale; not needed for MVP

### Multi-jurisdiction Compliance

#### EU Copyright Directive Article 17

Gleisner qualifies for the **small platform exemption** while:
- Available in EU for less than 3 years, AND
- Annual revenue under €10M, AND
- Monthly unique visitors under 5M

During exemption period: only notice-and-takedown required (same as DMCA).

**Action item**: Monitor these metrics. When any threshold is approached, begin implementing "best efforts" upload prevention (Layer 3 features become legally required).

#### Japan Information Distribution Platform Act (2025)

"Large platform" obligations (>10M monthly senders) include:
- Designated contact point for takedown requests
- 14-day response deadline
- Published takedown criteria
- Annual transparency report

**Action item**: Not immediately applicable at launch scale, but design the takedown system to meet these requirements from day one for smooth scaling.

### IPFS / Decentralized Storage Considerations

**⚠ LEGAL RISK — requires legal counsel**

When Gleisner transitions to IPFS/distributed storage (ADR 014 Phase 1+):
- Removing content from Gleisner's own IPFS gateway/pins is likely sufficient for DMCA "expeditious removal" (good faith effort)
- Content may persist on other IPFS nodes — this is outside Gleisner's control
- **Mitigation**: DMCA policy page must explain the technical limitations of distributed storage
- **Architecture**: Maintain ability to make content inaccessible via metadata removal (even if encrypted blob persists on Arweave)
- **No case law exists** on this topic — monitor legal developments

### AGPL Fork Considerations

- Gleisner bears **no liability** for copyright-infringing content on forks (forks are independent operators)
- Publish the DMCA takedown blocklist (contentHash list) as a public resource
- Recommend (but cannot enforce) that forks respect the blocklist
- Include in Terms of Service: data export users must comply with copyright obligations

## Consequences

- DMCA Safe Harbor protection is secured from day one with minimal cost (~$6 + operational procedures)
- Gleisner's existing contentHash + Ed25519 architecture provides structural copyright protection superior to platforms that rely on policy alone
- Indie artists get proof-of-authorship without needing Content ID access — a meaningful differentiator
- The three-layer approach scales from MVP (legal compliance + structural) to large-scale (enhanced detection)
- EU small platform exemption provides a compliance grace period, but monitoring thresholds is critical
- IPFS integration introduces legal uncertainty that must be resolved with legal counsel before Phase 1 deployment

## Items Requiring Legal Counsel Review

| # | Item | Priority |
|---|------|----------|
| LC-1 | Review DMCA policy page draft and Terms of Service copyright clauses | Pre-launch |
| LC-2 | IPFS takedown: does removing from own gateway satisfy "expeditious removal"? | Before ADR 014 Phase 1 |
| LC-3 | DID + Ed25519 signature as evidence of authorship: strength in US/EU/JP courts? | Pre-launch (informational) |
| LC-4 | AGPL fork liability exposure for copyright-infringing content | Pre-launch (informational) |
| LC-5 | Japan Information Distribution Platform Act compliance checklist | Pre-launch |
| LC-6 | Counter-notification: handling cross-border personal data disclosure (JP privacy law) | Pre-launch |

## Related

- ADR 001 — Project Vision (artist ownership)
- ADR 003 — AGPL License (fork considerations)
- ADR 014 — Decentralization Roadmap (IPFS, DID)
- ADR 017 — Content Hash and Signature (provenance infrastructure)
- Idea 011 — Copyright Protection research
- **ADR 019** — Age Policy (minors' content has additional protections)
