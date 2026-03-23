# Idea 016: Monetization strategy — phased plan without ads

**Status:** Exploring
**Date:** 2026-03-23

## Summary

A three-phase monetization plan that avoids advertising and preserves Gleisner's UI/UX integrity. Revenue grows from zero (MVP) through tipping commissions to paid plugins, all while keeping the core platform free. Platform choice (Web vs iOS vs Android) directly impacts payment strategy due to app store commission structures.

## Guiding principles

- **No ads**: traditional display/banner advertising is ruled out. If ads ever become necessary, only native "sponsored post" format would be considered — but this is a last resort
- **Diaspora self-determination**: users choose what they pay for; no paywalls on core creative features
- **Web first advantage**: Gleisner's Flutter Web (CanvasKit) primary deployment avoids app store commissions entirely

## Phased plan

### Phase 1: Free (MVP — current)
- **Revenue**: none
- **Cost**: $0–10/month (Cloudflare Pages free, Railway $0–5, R2 $0–1, domain ~$1, Claude API $0–3)
- **Strategy**: validate product-market fit. Keep infrastructure costs minimal using free tiers
- **Pain threshold**: sustainable as pocket money for a solo developer

### Phase 2: Tipping (after user traction)
- **Model**: Ko-fi-style "support this artist" button on posts
- **Gleisner revenue**: 5% platform fee on tips (comparable to Ko-fi 5%, Patreon 5–12%)
- **Payment processor**: Stripe direct (3.6% processing fee on top)
- **Total artist cost**: ~8.6% (Stripe 3.6% + Gleisner 5%)
- **UI impact**: minimal — one button added to post detail sheet
- **Trigger**: when monthly infrastructure costs exceed comfortable pocket-money range (~$20–50/month, likely at hundreds of active users with media uploads)

### Phase 3: Paid plugins + Pro bundle (growth phase)
- **Model**: individual paid plugins, then a Pro bundle when enough plugins exist
- **Rollout sequence**:
  1. Launch plugins individually ($2–5/month each) — validate demand per feature
  2. Once 5+ plugins exist → introduce Pro bundle ($8–15/month for all)
  3. Individual purchase remains available for users who only want one feature
- **Plugin candidates**:
  - Advanced analytics (PV trends, fan demographics) — see Idea 015
  - AI enhancements (auto-tagging, recommendations, translation) — see Ideas 008, 009, 010
  - Custom themes / constellation display styles — see Idea 001
  - External service integrations (Spotify, YouTube auto-import)
  - Multiple artist profiles — see Idea 013
- **Gleisner revenue**: direct subscription income
- **Aligns with Diaspora principle**: core platform stays free; paid features are optional power tools

## App store commission analysis

### Apple (iOS)
- Standard: 30% (15% for Small Business Program, revenue < $1M/year)
- Subscriptions: 30% year 1, 15% year 2+
- **Tipping**: Apple tends to require IAP when the platform takes a commission (Patreon precedent — forced to use IAP in 2024)
- **External payment links**: restricted, though EU DMA is expanding exceptions
- **Conclusion**: if Gleisner takes 5% of tips, Apple would likely demand IAP → 15–30% on top. This makes tipping economically unviable on iOS

### Google (Android) — changing landscape
- Current: 30% standard, 15% for < $1M
- **2026 onward** (post-Epic settlement): 10–20% standard, 10% for < $1M
- **External payments officially allowed**: 10% for subscriptions, 20% for other digital content
- **Conclusion**: Android is significantly more favorable. Stripe direct payment within the app may be viable with only Google's 10–20% external payment fee, or potentially avoidable entirely depending on interpretation

### Web
- **No commissions**. Full control over payment flow
- Stripe processing fee only (3.6%)
- **Conclusion**: Web is the optimal platform for all payment features

## Platform strategy for payments

| Platform | Tip button | Plugin purchase | Rationale |
|----------|-----------|----------------|-----------|
| **Web (primary)** | Yes — Stripe direct | Yes — Stripe direct | No commissions, full control |
| **Android** | Yes — Stripe direct | Yes — Stripe direct | External payments allowed from 2026 |
| **iOS** | No payment UI | No payment UI | Avoid Apple IAP tax. Users who want to pay can use Web |

### The iOS dilemma
- No tip button on iOS = tips simply won't happen from iOS users (users won't switch to Web to pay)
- But adding IAP means 15–30% Apple tax on every tip, making the 5% Gleisner commission nearly meaningless
- **Decision deferred**: iOS app is not planned for MVP. By the time it's needed, the regulatory landscape (EU DMA, US antitrust) may have changed significantly
- MVP focus is on artists (who use Web on desktop) not fans (who want mobile apps), so this is acceptable for now

## Infrastructure cost projection

### Centralized (current architecture)

| User scale | Monthly cost | Notes |
|-----------|-------------|-------|
| ~Dozens | $0–10 | Free tiers cover everything |
| ~Hundreds + active media | $20–50 | Railway Hobby, R2 bandwidth |
| ~Thousands | $50–100+ | Pro plan/plugin revenue should cover |

### After decentralization (future — see ADR 014)

| Component | Current | After decentralization |
|-----------|---------|----------------------|
| Database | PostgreSQL (Railway $5~) | PostgreSQL + replication |
| Media storage | Cloudflare R2 ($0~) | **IPFS pinning ($10–50/month)** |
| Permanence | — | **Arweave (~$0.01/MB, one-time write)** |
| Node operation | — | **IPFS node or Pinata service** |

- Media storage costs increase significantly with decentralization, especially for video content
- **Timing**: decentralization should happen only when tip/plugin revenue can cover the increased infrastructure costs
- The Diaspora principle of "resistance to erasure" motivates decentralization, but it must be economically sustainable

## Why not: ad model
- Destroys the carefully crafted UI/UX (especially the constellation timeline)
- Misaligned with Gleisner's creative-tool identity — ads turn artists into inventory
- Recent industry trend: creator platforms moving away from ad dependence (see Mighty Networks, Ghost, Substack)
- If ever necessary: sponsored posts only (native format that blends with timeline), never banner/interstitial

## Why not: paid content sales (paywall)
- Gleisner is a creative journey timeline, not a content marketplace
- Paywalls would fragment the fan experience of "peeking into the artist's constellation"
- Better handled by linking to external services (Bandcamp, Gumroad) for artists who want to sell content

## Related
- Idea 003 (artist/fan mode): payment UI may differ between modes
- Idea 013 (multi-artist paid plan): candidate for paid plugin
- Idea 014 (post visibility): visibility controls are a free feature, not paywalled
- Idea 015 (view count display): advanced analytics as a paid plugin candidate
- ADR 014 (DID): decentralization cost implications
- ADR 015 (tech stack): Flutter Web first enables commission-free payments
