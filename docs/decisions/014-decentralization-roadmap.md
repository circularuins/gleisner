# ADR 014: Decentralization Roadmap — Hybrid Architecture for Data Sovereignty

## Status

Draft

## Context

Gleisner's founding philosophy (ADR 001) commits to artist ownership and resistance to deletion: "No platform can revoke access" and "the artist's presence persists regardless of any single service's decisions." This is not just a feature — it is the project's reason for existing.

However, the MVP (see `docs/requirements/mvp-requirements.md`) is scoped as a single-instance deployment to validate the core UX first. This creates a tension: the MVP must be buildable without full decentralization, but the architecture must not preclude it.

This ADR defines the decentralization strategy, phasing, and the specific design decisions that must be embedded in the MVP to make the post-MVP transition feasible.

### Approaches Evaluated

Three levels of decentralization were considered:

| Level | Meaning | Approach |
|-------|---------|----------|
| **A: Theoretically undeletable** | All data on-chain, physically impossible to delete | Full blockchain. Infeasible for media-rich content due to storage cost and throughput limits |
| **B: Practically undeletable** | Identity on-chain (undeletable), content on distributed storage (resilient), app layer conventional | Hybrid. Best fit for Gleisner |
| **C: Resistant to arbitrary deletion** | Federation prevents single-operator censorship, but no blockchain guarantees | Federation only. Insufficient for Gleisner's philosophical commitment |

Level A is the ideal but impractical for a media-rich platform. Level C solves the "unjust ban" problem but lacks the blockchain element needed to credibly claim "your identity can never be erased." Level B is the pragmatic middle ground.

## Decision

### Architecture: Three-Layer Hybrid

```
┌───────────────────────────────────────┐
│  Application Layer                    │
│  Gleisner server: API, layout engine, │
│  search, notifications, UX           │
│  → Can be replaced / forked          │
└──────────┬──────────────┬────────────┘
           │              │
┌──────────▼───┐  ┌───────▼────────────┐
│  Blockchain  │  │  Distributed       │
│  (Identity)  │  │  Storage (Content) │
│              │  │                    │
│  • DID       │  │  • Post text       │
│  • Public key│  │  • Media files     │
│  • Content   │  │  • Profile data    │
│    hashes    │  │                    │
│              │  │  IPFS + persistent │
│  L2 chain or │  │  pinning service   │
│  lightweight │  │  (Filecoin/Arweave │
│  chain       │  │   for guarantees)  │
└──────────────┘  └────────────────────┘
```

**Identity (blockchain):** A user's DID and public key are recorded on a blockchain. This record is immutable — no entity, including the Gleisner operator, can delete it. Even if Gleisner ceases to exist, the identity persists.

**Content (distributed storage):** Posts, media, and profile data are stored on IPFS. The Gleisner server runs an IPFS node and pins its users' content. Content hashes are recorded on the blockchain, so the existence and integrity of any piece of content can be verified independently.

**Application (conventional server):** The Gleisner server handles UX-intensive operations — constellation layout computation, search, notifications, the timeline rendering API. This layer is replaceable: because Gleisner is AGPL-licensed (ADR 003), anyone can fork and deploy an alternative that reads from the same blockchain and IPFS data.

### Blockchain Selection

The specific chain is not decided yet, but the following constraints apply:

| Constraint | Rationale |
|-----------|-----------|
| Low transaction cost (< ¥10/tx) | Must be economically viable to register DIDs and record content hashes at scale |
| Ethereum-compatible or Ethereum-secured | Ethereum's security and longevity are the strongest in the ecosystem |
| Established ecosystem | Avoid chains that may not exist in 5 years |

Leading candidates:

| Chain | Cost/tx | Notes |
|-------|---------|-------|
| Ethereum L2 (Base, Arbitrum, Optimism) | ¥1–10 | Secured by Ethereum mainnet. Base is backed by Coinbase |
| Polygon PoS | < ¥1 | Widely adopted, very cheap, but independent security model |
| Ethereum mainnet | ¥100–1000+ | Too expensive for per-user operations |

A lightweight approach similar to Bluesky's PLC DID method (a dedicated DID registry that anchors to Ethereum periodically) is also under consideration.

**Decision deferred** to implementation phase. The application layer will interact with the chain through an abstraction layer, allowing the chain to be swapped.

### DID (Decentralized Identifier) Integration

DIDs are self-owned identifiers based on public-key cryptography. The user generates a key pair; the public key is registered on a blockchain, creating an identifier that no central authority can revoke.

#### MVP Phase: DID-Compatible

The MVP does not write to a blockchain, but adopts a DID-compatible ID scheme from day one:

- User IDs are generated in a format that can later become full DIDs (e.g., `did:web:gleisner.app:u:{uuid}` initially, upgradeable to `did:plc:{hash}` when blockchain integration is added)
- A key pair is generated for each user at signup and stored server-side
- The key pair is exportable by the user via a "Back up your identity" feature in settings
- All user-created content is signed with the user's private key, enabling future independent verification

#### Post-MVP Phase: On-Chain DIDs

- DID registration is written to the selected blockchain
- Content hashes are recorded on-chain (batched for cost efficiency — e.g., 100 hashes per transaction)
- Users who have backed up their keys can recover their identity and verify their content on any compatible service, even if Gleisner ceases to exist

### Content Addressing

All user-generated content (posts, media, profile data) is content-addressed from the MVP:

- A deterministic hash (e.g., SHA-256) is computed for each piece of content at creation time
- This hash is stored alongside the content in the database
- In the post-MVP phase, this hash becomes the IPFS CID (Content Identifier), and the content is pinned to IPFS
- The hash is also recorded on-chain, creating an immutable proof that the content existed

### User Experience: Progressive Self-Sovereignty

Decentralization must not create friction for users who don't care about it, while empowering those who do. The approach is progressive disclosure with natural motivation:

#### All Users (Free)

- Normal SNS experience — email/password signup, no blockchain knowledge required
- Key pair generated automatically in the background
- Full data export available (P0 requirement in MVP)
- Data is safe as long as Gleisner operates

#### Self-Sovereign Upgrade (Post-MVP, Paid or Included)

Triggered naturally when the user has accumulated meaningful content (e.g., 10+ posts):

1. **Prompt:** "Protect your work permanently — back up your identity key"
2. **Key backup:** User receives a 12-word recovery phrase (BIP-39 standard) or downloads an encrypted key file
3. **On-chain registration:** DID is written to the blockchain
4. **Content pinning:** All existing and future content is pinned to IPFS
5. **Badge:** Profile displays "🔐 Self-Sovereign" — visible to other users as a trust signal
6. **Guarantee:** Even if Gleisner disappears, the user can recover their identity and data on any compatible service using their recovery phrase

The Self-Sovereign upgrade aligns with the open-core model (ADR 005): it is a value-added service that enhances data sovereignty, but the core platform functions without it. Whether this is a paid feature or included for all users is a business decision deferred to post-MVP.

### Phasing

| Phase | Scope | Blockchain Dependency |
|-------|-------|----------------------|
| **MVP** | DID-compatible IDs, key pair generation, content hashing, data export | None (all server-side) |
| **Post-MVP Phase 1** | Key backup UX, Self-Sovereign badge, IPFS node + content pinning | IPFS only |
| **Post-MVP Phase 2** | On-chain DID registration, content hash recording, recovery flow | Blockchain + IPFS |
| **Post-MVP Phase 3** | Federation protocol (multiple Gleisner instances), cross-instance discovery | Full stack |

Each phase is independently valuable and deployable. Phase 1 can ship without any blockchain integration. Phase 2 adds the "undeletable identity" guarantee. Phase 3 enables the full decentralized vision.

### What AGPL Enables

The AGPL license (ADR 003) is a critical enabler of the decentralization story:

- If Gleisner ceases to exist, anyone can fork the codebase and deploy a compatible instance
- Because data lives on blockchain + IPFS (not proprietary servers), the new instance can read all existing data
- Users with backed-up keys can authenticate on the new instance and resume where they left off
- Competing services built on the same data layer strengthen the ecosystem rather than fragmenting it

This means "Gleisner can never truly die" — the code is open, the data is distributed, and the identities are self-owned.

### Cost Model (Post-MVP Estimates)

| Component | Cost | Who Pays |
|-----------|------|----------|
| DID registration (L2) | ¥1–10 per user (one-time) | Gleisner (subsidized) or user |
| Content hash recording (L2, batched) | ¥1,000–5,000/month (batches of 100+ hashes) | Gleisner operational cost |
| IPFS node operation | Equivalent to normal storage hosting | Gleisner operational cost |
| Persistent pinning (Filecoin/Arweave) | Varies by data volume; ¥10,000–50,000/month at MVP scale | Gleisner or Self-Sovereign plan fee |

At 10,000 users on an L2 chain, DID registration costs approximately ¥10,000–100,000 total (one-time). This is manageable as an operational cost or as part of a Self-Sovereign subscription.

## Consequences

- The MVP can be built without any blockchain or IPFS dependency, but is architecturally prepared for both
- DID-compatible IDs and content hashing add minimal development overhead to the MVP (~5–10% increase)
- The Self-Sovereign feature creates a compelling differentiator and aligns with the Egan philosophy of self-determination
- The progressive disclosure approach avoids alienating non-technical users while empowering those who value data sovereignty
- Blockchain chain selection is deferred, reducing the risk of betting on the wrong chain
- The AGPL license ensures that the decentralization promise is credible — even if Gleisner the company fails, the project survives
- The cost of on-chain operations is manageable on L2 chains, but Ethereum mainnet is prohibitively expensive for per-user operations

## Open Questions

| # | Topic | Notes |
|---|-------|-------|
| OQ-D01 | Blockchain chain selection | L2 (Base/Arbitrum/Optimism) vs Polygon vs custom lightweight chain. Defer to implementation |
| OQ-D02 | DID method | `did:web` (simple, server-dependent) → `did:plc` (Bluesky-style) → `did:ethr` (Ethereum-native)? Migration path matters |
| OQ-D03 | IPFS pinning strategy | Self-hosted node only, or also use Pinata/Filecoin/Arweave for persistence guarantees? |
| OQ-D04 | Content hash batching | Optimal batch size and frequency for on-chain recording (cost vs latency trade-off) |
| OQ-D05 | Self-Sovereign pricing | Free for all users, or premium feature? Affects open-core boundary (ADR 005) |
| OQ-D06 | Key custody and recovery | Recovery phrase (BIP-39) vs encrypted key file vs social recovery? UX implications differ greatly |
| OQ-D07 | Media permanence guarantee | IPFS data disappears if unpinned. Is Arweave (permanent, paid) necessary for the "never deleted" promise? |
| OQ-D08 | Federation protocol | Build on ActivityPub, AT Protocol, or design a Gleisner-native protocol? Defer to Phase 3 |

## Related

- ADR 001 — Project vision (artist ownership, decentralization, resistance to deletion)
- ADR 003 — AGPL license (enables fork-and-recover scenario)
- ADR 005 — Open-core model (Self-Sovereign as potential premium feature)
- ADR 013 — Profile & Artist Page (DID-compatible ID scheme affects User entity)
- MVP Requirements — `docs/requirements/mvp-requirements.md` (NFR-SCAL-002: architecture must not preclude federation)
