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

### Gleisner's unique approach: Guardian-managed accounts

#### Legal feasibility confirmed

- COPPA allows serving children of any age with proper VPC
- GDPR allows processing with parental consent below age threshold
- Guardian-managed accounts are a recognized model (YouTube Supervised, Roblox Parental Controls)

#### DID-based guardian delegation — hybrid approach recommended

**DID signatures alone are insufficient for VPC** — initial verification must use FTC-approved methods. DID signatures are used for ongoing consent management and audit trails.

#### Data minimization as competitive advantage

Gleisner's architecture naturally minimizes data collection:
- DID + content only (no email/phone for minor accounts)
- Guardian's identity handles legal requirements
- No personalized ads = no tracking infrastructure
- **COPPA compliance surface is dramatically reduced**

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

**Trend**: Enforcement is accelerating dramatically. Fines are growing by orders of magnitude.

## Open questions

| # | Question | Status |
|---|----------|--------|
| OQ-1 | Which FTC-approved VPC method to implement for MVP? (email-plus is cheapest) | Decision needed |
| OQ-2 | Australia market: accept 16+ restriction or delay AU launch? | Decision needed |
| OQ-3 | Zero-knowledge proof for age verification: technically feasible with DID, but no legal precedent | Future research |
| OQ-4 | How to handle edge cases: guardian abuse, custody disputes, emancipated minors? | Needs legal counsel |

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
- **ADR 019 (Age Policy)**: drafted based on this research
