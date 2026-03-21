# Idea 011: Copyright protection and infringement prevention

**Status:** Exploring
**Date:** 2026-03-21
**Updated:** 2026-03-21

## Summary

Design rules and system-level safeguards for copyright on Gleisner: preventing infringement by uploaders (claiming others' work as original) and protecting the rights of content posted to the platform. Research existing SNS precedents to ensure legal compliance.

## Research findings

### Two sides of the copyright problem

1. **Infringement risk (inbound)**: Artists may upload copyrighted content and claim it as original. Gleisner needs policies and, where possible, technical measures to mitigate this.
2. **Content protection (outbound)**: How to protect content posted on Gleisner from unauthorized use elsewhere. The platform's decentralized aspirations (see ADR 014, DID) may offer unique approaches.

### Existing SNS precedents — key findings

#### YouTube (Content ID)
- Automated audio/video fingerprinting system processing **2.2 billion claims/year** (2024)
- **Invitation-only access** — individual artists cannot use Content ID directly; must go through distributors (TuneCore, AWAL etc.)
- 99%+ of claims are automated; ~4.2% are fundamentally erroneous, ~28.4% questionable
- Paid out **$12B+** to rights holders cumulatively
- **Lesson**: Content ID is a business strategy, not a legal requirement. The DMCA Safe Harbor requirements are far simpler and cheaper

#### Instagram / Meta (Rights Manager)
- Video fingerprinting for Facebook/Instagram; Rights Manager access restricted to large rights holders
- New Reels protection tool (2025) for individual creators
- Comprehensive music licensing deals with major labels for Stories/Reels
- **Lesson**: Individual creator protection tools are a growing area, but still limited

#### TikTok
- Music licensing via major labels + NMPA publishing deals
- Personal accounts: full catalog access; Business accounts: restricted to Commercial Music Library
- Temporary Universal license lapse (early 2024) caused mass track removal
- **Lesson**: Music licensing fragility; modular contract structures as mitigation

#### SoundCloud
- Automated audio scanning against block-registered tracks
- Repost Network (acquired 2019): YouTube Content ID integration for artists
- Creative Commons license selection per track — unique feature
- **Lesson**: CC licensing as a differentiator for creator-first platforms

#### Bandcamp
- **No automated detection system** — relies entirely on DMCA notice-and-takedown
- Artist-first: Bandcamp claims no copyright; manual human review of takedowns
- **Lesson**: Minimal approach works at small scale but doesn't scale for proactive protection

#### Bluesky / Mastodon (decentralized)
- DMCA Designated Agent registered but **no automated detection**
- AT Protocol's decentralization means takedowns on Bluesky don't affect other PDS nodes
- Mastodon: each instance admin must register their own DMCA Agent ($6/3yr); most don't
- Federated content persists in caches across instances after deletion
- **Lesson**: Decentralized platforms face structural challenges for effective takedowns

### Legal requirements — what is MUST vs. NICE-TO-HAVE

#### Legally required (DMCA Safe Harbor — loss of protection if any is missing)

| Requirement | Cost/Effort | Details |
|-------------|-------------|---------|
| Designated Agent registration | $6/3yr | Electronic filing at copyright.gov |
| Agent info published on site | Minimal | DMCA policy page |
| Notice-and-takedown process | Moderate | Receive, verify, remove, notify uploader |
| Counter-notification process | Moderate | 10-14 business day putback rule |
| Repeat Infringer Policy | Moderate | Must be adopted AND consistently enforced (BMG v. Cox lesson) |
| No willful blindness | Behavioral | Must not intentionally ignore specific infringement (Viacom v. YouTube) |

#### Voluntary (business strategy, not legally required)
- Automated content detection (Content ID, fingerprinting)
- Music licensing deals
- Revenue sharing with rights holders
- Creator protection tools
- Copyright education for users

### Key case law

| Case | Ruling | Relevance to Gleisner |
|------|--------|----------------------|
| **Viacom v. YouTube (2012)** | General awareness of infringement is insufficient; must be item-specific knowledge | Safe Harbor survives even if platform knows infringement exists in general |
| **BMG v. Cox (2018)** | Repeat infringer policy must be genuinely enforced; revenue-motivated non-enforcement = Safe Harbor loss | Must actually terminate repeat infringers, not just have a policy on paper |
| **Lenz v. Universal (2015)** | Copyright holders must consider fair use before sending DMCA takedowns | Platform should support counter-notification and fair use claims |

### Multi-jurisdiction requirements

| Jurisdiction | Key law | Platform obligations | Small platform exemption |
|-------------|---------|---------------------|------------------------|
| **US** | DMCA §512 | Notice-and-takedown, repeat infringer policy | None (applies equally) |
| **EU** | Copyright Directive Art.17 | Best efforts to prevent unauthorized uploads (large platforms) | Yes: <3yr, <€10M revenue, <5M monthly visitors |
| **Japan** | Information Distribution Platform Act (2025) | Takedown process, designated contact (large platforms: 14-day response) | Yes: large platform obligations only for >10M monthly senders |
| **Korea** | Copyright Act §133-2 | Notice-and-takedown + administrative 3-strike system | Limited |
| **Australia** | Copyright Act 1968 | Similar to DMCA (narrower scope) | Effectively none |

### Gleisner's unique advantages

Gleisner's architecture (Ed25519 + contentHash + DID) provides structural copyright protection that no existing platform offers:

1. **Cryptographic provenance**: Every post has an unforgeable Ed25519 signature + contentHash = "who posted what, when" is tamper-proof
2. **DID-based authorship registry**: A user's DID-linked post history functions as a decentralized "work registry" — all posts automatically have provenance proof
3. **Exact-copy detection at O(1) cost**: contentHash enables instant detection of identical re-uploads (though not modified copies)
4. **Consistent infringer tracking across federation**: DID enables cross-instance repeat infringer tracking

**Limitations**: contentHash cannot detect near-copies (re-encoded, resized). Future enhancement: perceptual hashing as a second layer.

### Founder's intent

- The goal is to proactively protect artists, not just reactively handle takedowns
- System-level protections are preferred over relying solely on policy enforcement
- This aligns with the Egan principle of "resistance to erasure" — but for *legitimate* creators
- DID + signature provides indie artists with proof-of-authorship that Content ID gatekeeps behind distributors

## Open questions

| # | Question | Status |
|---|----------|--------|
| OQ-1 | DMCA takedown + IPFS: does removing from own gateway/pins satisfy "expeditious removal"? No case law yet | Needs legal counsel |
| OQ-2 | contentHash as legal evidence: needs external timestamping (OpenTimestamps) for third-party credibility | Technical decision pending |
| OQ-3 | When to introduce perceptual hashing for near-copy detection? | Defer to post-MVP |
| OQ-4 | AGPL fork liability: if a fork restores DMCA-removed content, what is Gleisner's liability? (Likely none, but needs legal review) | Needs legal counsel |
| OQ-5 | EU Art.17 small platform exemption timeline: at what growth point must Gleisner fully comply? | Monitor metrics |

## Related

- ADR 014 (DID / identity): content ownership tied to decentralized identity
- ADR 017 (Content hash / signature): already provides proof of authorship
- Idea 012 (Age policy): minors' content has additional legal protections in some jurisdictions
- **ADR 018 (Copyright Protection)**: to be drafted based on this research
