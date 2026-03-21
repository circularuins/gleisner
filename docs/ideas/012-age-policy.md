# Idea 012: Age policy — enabling young artists without legal risk

**Status:** Exploring
**Date:** 2026-03-21
**Updated:** 2026-03-21

## Summary

Design an age policy that allows young artists to use Gleisner as a lifelong creative log (starting from childhood) while complying with COPPA, GDPR-K, and similar regulations. The founder explicitly does *not* want arbitrary age gates, viewing them as a pain point that Gleisner was built to solve.

## Research findings

### The core tension

- Gleisner's value proposition includes **lifelong creative logging** — an artist's journey from childhood practice videos to professional performances. Restricting access to 13+ undermines this.
- However, COPPA (US, <13), GDPR-K (EU, varies by country 13-16), and Japanese laws impose strict rules on collecting data from minors.
- Existing platforms' "parental consent" solutions are widely seen as theater — easy to bypass, rarely enforced, and accounts get suspended arbitrarily. **This is exactly the pain Gleisner wants to solve.**

### Critical legal insight: age restriction is NOT legally required

**COPPA does not require banning children under 13.** It requires Verifiable Parental Consent (VPC) for data collection from children under 13. A platform CAN serve children of any age if it properly obtains parental consent and minimizes data collection.

This means the founder's intent — "no age restriction" — **is legally achievable** through a Guardian-managed account model with proper VPC.

### Existing platform approaches — lessons learned

#### Common failure patterns across all platforms

1. **Self-declaration dependency**: Every platform initially relied on birth-date self-declaration. Bypass rate is near-100%.
2. **Retrofitting protection**: Adding safety features after massive growth is expensive and ineffective (Instagram: 42-state lawsuit; YouTube: $170M fine)
3. **Revenue model conflict**: Ad/engagement KPIs structurally conflict with usage limits (TikTok Lite EU withdrawal)
4. **Third-party ecosystem gaps**: Problems emerge at platform edges (YouTube channel operators, Roblox casinos, Discord server admins)
5. **Data collection inertia**: Changing how already-collected data is handled costs $170M-$520M in fines

#### Most relevant models for Gleisner

**YouTube Supervised Accounts** (best reference for Guardian-managed model):
- Parent creates and manages child's account via Google Family Link
- 3-tier content settings ("Explore", "Explore More", "Most of YouTube")
- No comments, no uploads, no purchases for supervised accounts
- No personalized ads; behavioral tracking restricted
- **Key learning**: Graduated access levels work well

**Roblox** (best reference for all-ages design):
- Explicitly designed for all ages from day one
- AI-based facial age estimation + ID verification (2025)
- Age-tiered restrictions: <9 (chat off by default), <13, <16, 17+
- **Key failure**: Monetization design (Robux) not age-appropriate — gambling lawsuit via third-party casino sites
- **Learning**: "All ages" must extend to revenue model, not just content

**Discord Teen-by-Default** (best reference for default safety):
- All unverified users treated as teens with restricted access
- AI Age Inference Model: metadata-based age estimation (90%+ accuracy)
- Age verification: on-device face scan OR government ID
- **Learning**: "Safe by default, verify to unlock" is the emerging industry standard

**Instagram Teen Accounts** (best reference for what NOT to do — retrofitting):
- Forced to add default-private, content filters, message restrictions in 2024
- Under 42-state AG lawsuit for "addictive design"
- **Learning**: Protection must be architecture, not a feature layer

### Legal requirements by jurisdiction

#### US: COPPA (2025 amended rules, compliance deadline: 2026-04-22)

| Requirement | Details |
|-------------|---------|
| **Age gate** | Must identify users under 13 (birth date input is the minimum) |
| **VPC (Verifiable Parental Consent)** | FTC-approved methods: credit card, government ID, video call, knowledge-based auth, text-plus, facial recognition matching |
| **Privacy policy** | Must detail: data collected, purpose, third-party sharing, parent rights |
| **Parent access/deletion rights** | Parents can view, delete child's data; can revoke consent |
| **Data minimization** | Collect only what's necessary for service |
| **Data retention limits** | No indefinite retention (Amazon Alexa $25M lesson) |
| **Separate consent for third-party sharing** | Non-core third-party data sharing requires separate parental consent |
| **No profiling-based ads** | For known minors |
| **Penalties** | $51,744-$53,088 per violation per day |

#### EU: GDPR Article 8 + UK Children's Code + DSA

**GDPR consent ages by country:**
- 13: Spain, Czech Republic, Denmark, Ireland, Latvia, Poland, Sweden, UK
- 14: Austria, Italy, Bulgaria, Cyprus, Lithuania
- 15: France, Greece
- 16 (default): Germany, Hungary, Luxembourg, Netherlands, Slovakia

**UK Age Appropriate Design Code (15 principles):**
- Best interests of the child as primary consideration
- Privacy by default (profiles private, location off, profiling off)
- No nudging toward weaker privacy
- Age-appropriate transparency
- Data minimization

**DSA Article 28**: Platforms must ensure privacy, safety, security for minors. No profiling-based ads for known minors. Self-declaration alone is insufficient for age verification.

#### Japan
- No specific child data protection statute equivalent to COPPA
- Personal Information Protection Act: parental consent for minors' legal acts (Civil Code Art. 5)
- Youth Internet Environment Act: filtering service obligation (mainly on ISPs/carriers)
- **Practically lowest barrier** among major markets, but international operations trigger other jurisdictions

#### Australia (most restrictive)
- **Social Media Minimum Age Act 2024**: SNS account ban for under-16. Penalty: up to AUD 49.5M
- Effective 2025-12-10
- If Gleisner operates in Australia, age-16 restriction is legally mandatory

#### Other notable jurisdictions
- **China**: Minor Mode mandatory (2025); 40min/day for <14, banned 22:00-06:00
- **Korea**: Shutdown Law repealed 2021; moved to parental opt-in model
- **Brazil**: LGPD requires "clear and prominent" parental consent for <12

### Age verification methods — effectiveness analysis

| Method | Legal validity | Privacy impact | Implementation cost | Bypass difficulty |
|--------|---------------|----------------|-------------------|-------------------|
| Self-declaration (DOB) | Low (but triggers COPPA "actual knowledge") | Minimal | Very low | Trivial |
| Parent email (email-plus) | Medium-low (COPPA: internal use only) | Low | Low | Easy |
| Credit card / government ID | High (FTC approved) | Medium-high | Medium | Hard |
| AI facial age estimation | Medium-high (FTC approved 2025) | High (biometric) | High | Medium |
| Digital ID service | High | Medium | Medium-high | Hard |
| **DID-based guardian delegation** | **Untested** (no legal precedent) | **Low** (data-minimal) | Medium | N/A |

### Gleisner's unique approach: Guardian-managed accounts

#### Legal feasibility confirmed

- COPPA allows serving children of any age with proper VPC
- GDPR allows processing with parental consent below age threshold
- Guardian-managed accounts are a recognized model (YouTube Supervised, Roblox Parental Controls)

#### DID-based guardian delegation — hybrid approach recommended

**DID signatures alone are insufficient for VPC** because:
- DID proves "holder of this private key" but not "this person is the child's legal guardian"
- No FTC precedent for DID-based VPC
- No legal precedent for cryptographic consent records

**Recommended hybrid model**:
1. **Initial VPC**: Use FTC-approved method (credit card, email-plus, or ID verification)
2. **Ongoing consent management**: Record consent via DID signature (Ed25519) for audit trail
3. **Guardian-child relationship**: Model as DID delegation in the protocol layer
4. **Ownership transfer at legal age**: Seamless transition from guardian-managed to self-managed

This gives Gleisner the best of both worlds: legal compliance via established VPC methods + the architectural elegance of DID-based guardian delegation.

#### Data minimization as competitive advantage

Gleisner's architecture naturally minimizes data collection:
- DID + content only (no email/phone for minor accounts)
- Guardian's identity handles legal requirements
- contentHash for content integrity, not behavioral tracking
- No personalized ads = no tracking infrastructure

**COPPA compliance surface is dramatically reduced** when you don't collect PII from minors.

**Caveat**: DID itself may qualify as a "persistent identifier" under COPPA 2025 amendments. Content containing voice/photos of minors is also covered. Metadata (IP, device ID) counts as personal information.

#### Tiered privacy by age

| Age tier | Default visibility | Capabilities | Guardian control |
|----------|-------------------|-------------|-----------------|
| <13 | Private only | Create, upload (guardian-approved); no DM from strangers; no public timeline | Full (create account, manage settings, view activity, delete) |
| 13-15 | Private (changeable with guardian approval) | Upload; limited DM (followers only); guardian can view activity | Moderate (can approve public switch, view weekly report) |
| 16-17 | Private by default (self-changeable) | Full features except age-gated content | Light (notification of setting changes) |
| 18+ | User's choice | Full features | None |

#### Ownership transfer design (unique to Gleisner)

At legal age, the account seamlessly transitions:
- DID management authority transfers from guardian to owner
- All historical content (the "lifelong creative log") remains intact
- Guardian loses management access (not content access if previously shared)
- No data loss, no account recreation
- This is the "unlock your creative journey" moment

### Enforcement trends (2019-2026)

| Year | Target | Fine/Status | Summary |
|------|--------|-------------|---------|
| 2019 | YouTube | $170M | COPPA: tracking on kids' content without consent |
| 2019 | TikTok/Musical.ly | $5.7M | COPPA: collecting children's data without consent |
| 2022 | Epic Games | $520M | COPPA ($275M) + dark patterns ($245M) |
| 2023 | 42 US state AGs | Meta lawsuit | Addictive design harming children |
| 2024 | DOJ/FTC | TikTok lawsuit (pending) | Violating 2019 consent order |
| 2025 | FTC | Disney $10M | COPPA violation |
| 2025 | Texas AG | Roblox lawsuit | Child safety failures |
| 2026 | Jury trial | Meta, YouTube et al. | Addictive design causing harm to minors |

**Trend**: Enforcement is accelerating dramatically. Fines are growing by orders of magnitude. "Addictive design" lawsuits (not just data collection) are the new frontier.

## Open questions

| # | Question | Status |
|---|----------|--------|
| OQ-1 | Which FTC-approved VPC method to implement for MVP? (email-plus is cheapest; credit card is most reliable) | Decision needed |
| OQ-2 | Should Gleisner pursue COPPA Safe Harbor certification (kidSAFE/PRIVO)? Significantly reduces FTC enforcement risk | Decision needed |
| OQ-3 | Australia market: accept 16+ restriction or delay AU launch? | Decision needed |
| OQ-4 | Zero-knowledge proof for age verification: "prove I'm over 13 without revealing my age" — technically feasible with DID, but no legal precedent | Future research |
| OQ-5 | Guardian-child DID delegation: restrict content propagation for minor accounts? (e.g., `propagation: restricted` flag) | Architecture decision |
| OQ-6 | How to handle edge cases: guardian abuse, custody disputes, emancipated minors? | Needs legal counsel |

## Founder's intent (strong)

- "I genuinely do not want age restrictions" — this is achievable through Guardian-managed accounts with proper VPC
- This is not about ignoring safety, but about *designing safety properly* rather than applying a blanket ban
- The lifelong creative log concept *requires* early adoption to be maximally valuable
- The goal is to be *more* protective of young users than competitors, not less — while avoiding arbitrary exclusion
- "Protection is architecture, not a feature" — the single most important lesson from existing platforms

## Related

- ADR 014 (DID): guardian-child relationship could be modeled as DID delegation
- ADR 016 (User Identity Privacy): PublicUserType separation already protects sensitive fields
- Idea 011 (Copyright): minors' content has additional legal protections in some jurisdictions
- Egan principle of "self-determination": even young users should own their creative identity
- **ADR 019 (Age Policy)**: to be drafted based on this research
