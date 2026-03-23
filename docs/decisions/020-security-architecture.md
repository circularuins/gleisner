# ADR 020: Security Architecture and Threat Mitigation

## Status

Draft

## Context

Gleisner is not an ordinary SNS — it embeds cryptographic identity (Ed25519 key pairs, DID, content signatures) at its core. This architectural choice, while enabling the Diaspora-inspired self-sovereignty philosophy (ADR 001), introduces security concerns beyond typical social platforms:

- **Account compromise = identity theft**: Unlike a traditional SNS where password reset resolves a breach, compromising a Gleisner account means the attacker gains access to cryptographic signing capability. They can produce content that is *cryptographically indistinguishable* from the real user's.
- **Server-side key custody**: The MVP generates Ed25519 key pairs server-side and stores encrypted private keys in the database. This is a pragmatic choice for UX (ADR 014, Phase 1), but creates a trust dependency on the server operator.
- **AI-accelerated threats**: As of 2025, AI-driven phishing accounts for 80%+ of social engineering attacks (ENISA). Password cracking with modern GPUs continues to accelerate.
- **Regulatory pressure**: GDPR fines exceeded $2.7B globally in 2024. COPPA revisions (effective June 2025) tighten requirements for platforms with minor users.
- **Industry context**: 29% of internet users have experienced account takeover; SNS platforms account for 53% of all hijacking incidents.

### Threat model

| Category | Attack surface | Impact |
|----------|---------------|--------|
| Credential leakage | JWT secret key logging, server-side plaintext key handling | Critical — all user identities compromised |
| Auth bypass | authMiddleware silent failure | Critical — unauthenticated access to protected resources |
| DoS / resource exhaustion | Unlimited password length + scrypt, no GraphQL depth/complexity limits | High — server availability loss |
| Key management | Server-side key generation, AES-GCM-only protection | High — undermines self-sovereignty premise |
| API abuse | No rate limiting, GraphQL introspection exposed | Medium — data scraping, enumeration attacks |

### Review process

Two independent investigations were conducted: a codebase security audit and an industry best-practices survey. Each finding was assigned a confidence score (0-100). Findings below 80 are classified as "review items" rather than decisions (higher false-positive risk).

**Findings with confidence ≥ 80 (reflected in decisions): 5**

| # | Finding | Confidence | Category |
|---|---------|-----------|----------|
| 1 | JWT secret key logged in plaintext | 95 | Credential leakage |
| 2 | No password length upper bound (scrypt DoS) | 90 | DoS |
| 3 | authMiddleware silently ignores auth failures | 92 | Auth bypass |
| 4 | Server-side key generation with plaintext handling | 88 | Key management |
| 5 | No GraphQL depth/complexity/rate limits | 85 | API abuse |

**Findings with confidence < 80 (recorded as review items): 2**

| # | Finding | Confidence | Notes |
|---|---------|-----------|-------|
| 6 | UserType exposes publicKey | 78 | Intentional design per ADR 016; may need revisiting for key rotation |
| 7 | scrypt parameter N=16384 is low | 75 | Meets OWASP minimum; N=32768+ advisable but needs server load testing |

### Industry trends (knowledge-cutoff-dependent — confidence ≤ 70)

The following claims are based on model knowledge and should be verified against official sources before implementation decisions.

| Claim | Confidence | Verification |
|-------|-----------|-------------|
| AT Protocol did:plc uses rotationKeys + 72-hour recovery window | 70 | Check AT Protocol official docs |
| 29% of users experienced account takeover in 2024 | 60 | Locate original survey report |
| AI-driven phishing exceeds 80% by early 2025 | 55 | Locate original ENISA report |
| 69% of users have at least one passkey in 2025 | 60 | Check FIDO Alliance official stats |
| COPPA June 2025 revision details | 65 | Check FTC website (tracked in ADR 019) |
| GDPR fines exceeded $2.7B in 2024 | 60 | Check GDPR Enforcement Tracker |

## Decision

### 1. Immediate (before MVP public release)

These are **vulnerabilities directly leading to data leakage or auth bypass** — must be fixed before any deployment.

#### 1.1 Remove JWT secret key logging (confidence 95)

**Problem**: `src/auth/jwt.ts` logs auto-generated JWT private keys to stdout in development mode. If `NODE_ENV` is not set to `"production"` in deployment, keys leak to server logs (Railway, etc.), enabling full session impersonation for all users.

**Decision**:
- Remove all `console.log` statements containing key material
- Mask secret key fields in any environment variable dump (`***`)
- Consider adding ESLint custom rule for static analysis of secret logging

**Rationale**: Secret key leakage enables session forgery for all users — maximum blast radius. Fix cost is minimal (delete log lines).

#### 1.2 Fix authMiddleware silent failure (confidence 92)

**Problem**: Auth middleware catches all JWT validation errors silently and continues as unauthenticated (`authUser = undefined`). Resolver-side `authUser` null checks become the sole defense, creating risk of missed checks on new resolvers.

**Decision**:
- Log authentication failures at `warn` level (IP, timestamp, failure reason — NOT the token itself)
- Maintain current behavior of allowing unauthenticated access (needed for public queries)
- Document which queries/mutations are intentionally public vs authenticated in a centralized policy
- Evaluate Pothos `authScopes` plugin for declarative authorization

**Rationale**: "Default deny" is a fundamental auth design principle. Current "default allow" design makes it easy to forget auth checks when adding new resolvers.

#### 1.3 Add password length upper bound (confidence 90)

**Problem**: No maximum password length validation. `scryptSync` CPU/memory cost scales with input length. Attackers can send multi-MB password strings to exhaust server resources.

**Decision**:
- Maximum password length: **128 characters** (exceeds NIST 800-63B minimum of 64)
- Validate **before** scrypt computation
- Apply same limit on frontend (UX consistency)

**Rationale**: scrypt is intentionally expensive; without input length limits, amplification attacks are trivial. Combined with lack of rate limiting (see 2.1), this is an exploitable DoS vector today.

### 2. Short-term (before user-facing launch)

User data protection and basic API defense. Should be implemented before public launch, but acceptable during closed testing.

#### 2.1 GraphQL API hardening (confidence 85)

**Problem**: No query depth limit, complexity analysis, rate limiting, or batch limiting. Introspection is disabled in production (good), but the API is otherwise unprotected against resource exhaustion.

**Decision**:
- **Query depth limit**: max 10 levels (yoga `depthLimit` plugin)
- **Query complexity limit**: per-field cost definitions with total cost ceiling
- **Rate limiting**: IP-based + authenticated user-based
  - Anonymous: 60 req/min
  - Authenticated: 300 req/min
  - Per-mutation: signup/login at 10 req/min/IP
- **Batch limiting**: max 5 operations per HTTP request
- **Production introspection disabled** (already implemented)

**Rationale**: GraphQL accepts arbitrary depth/width queries at a single endpoint. Without defense layers, a single attacker can DoS the service. Yoga ecosystem has ready-made plugins with low implementation cost.

#### 2.2 Strengthen server-side key management (confidence 88)

**Problem**: Ed25519 private keys are generated server-side, encrypted with AES-GCM, and stored in the database. The encryption key derivation, plaintext handling in memory, and co-location of `encryptedPrivateKey` + `encryptionSalt` in the same table create a wide attack surface. Also misaligned with ADR 014's self-sovereignty philosophy.

**Decision (phased)**:
1. **Short-term**: Migrate encryption key management from environment variables to Cloud KMS (AWS KMS / GCP Cloud KMS / Cloudflare Workers KMS). Minimize plaintext private key lifetime in memory (zero-clear after use)
2. **Medium-term**: Migrate to client-side key generation (WebCrypto API). Server holds public key only
3. **Long-term**: Passkeys / WebAuthn integration (ADR 014 Phase 2)

**Rationale**: Current server-side key generation prioritizes development speed (ADR 014 explicitly states "server-side for MVP"). Risk mitigations must be in place before public launch; full client-side migration follows in later phases.

#### 2.3 Key derivation strengthening: scrypt → Argon2id

**Problem**: scrypt with `N=16384` (2^14) is used for both password hashing and encryption key derivation. OWASP 2024 recommends scrypt `N=65536` (2^16) minimum. Argon2id is now the recommended algorithm for new implementations (RFC 9106, Password Hashing Competition winner).

**Decision**:
- New accounts: use Argon2id with OWASP-recommended parameters
- Existing accounts: migrate on next login (re-hash when user provides correct password)
- Store algorithm version in a new `hashAlgorithm` column to support gradual migration

**Rationale**: The encrypted private key is the crown jewel. If the DB leaks, weak KDF + weak password = private key recovery in hours on modern GPUs. Stronger KDF buys critical time.

#### 2.4 Two-factor authentication (TOTP + backup codes)

**Decision**:
- Implement TOTP (RFC 6238) as optional 2FA
- Generate 10 single-use backup codes at enrollment, stored as Argon2id hashes
- Show backup codes once at setup; prompt user to save offline
- Recovery flow: backup code → disable 2FA → re-enroll (no bypass of 2FA via email-only recovery)

**Rationale**: Account takeover in Gleisner is more damaging than in a typical SNS because the attacker gains cryptographic signing capability. TOTP is the minimum viable protection while Passkeys mature.

#### 2.5 GDPR minimum compliance

**Decision**:
- Implement account deletion endpoint (right to erasure) — cascade delete all user data
- Publish privacy policy documenting data collected, processing purposes, and retention
- Add data export endpoint (right to portability) — JSON download of all user data

**Rationale**: GDPR applies to any service accessible from the EU, regardless of operator location. Non-compliance fines start at €10M. These are also good engineering practices regardless of legal obligation.

### 3. Medium-term (growth phase)

Security enhancements needed as the user base expands.

#### 3.1 Passkeys / WebAuthn

**Decision**:
- Add WebAuthn as an additional authentication method (not replacing email/password)
- Phased rollout: opt-in in settings → recommended default → default for new signups

**Rationale**: Industry-wide shift to passwordless auth. Apple/Google/Microsoft have made passkeys default for new accounts. 69% of users have at least one passkey (2025). Phishing-resistant by design (origin-bound). However, MVP email/password is sufficient; ROI is higher after user base growth.

#### 3.2 Persisted queries (GraphQL)

**Decision**:
- Pre-register allowed queries from the client; reject arbitrary queries in production
- Development environment allows all queries; production allows registered queries only

**Rationale**: Fundamentally eliminates sophisticated query attacks that depth/complexity limits cannot fully prevent. Flutter client is fixed, making persisted queries straightforward to implement.

#### 3.3 Recovery phrase (BIP39 mnemonic)

**Decision**: At signup, generate a 12-word BIP39 mnemonic that deterministically derives the Ed25519 key pair. Display once, prompt user to write down offline.

**Purpose**:
- If the server is compromised or goes offline, the user can recreate their key pair from the mnemonic alone
- Aligns with Diaspora principle: the user truly *owns* their identity, independent of any server
- Compatible with future client-side key generation (4.1)
- Migration: existing users can "claim" a mnemonic by verifying their password

#### 3.4 Security audit logging

**Decision**:
- Log authentication events (login/signup/logout/failure), permission changes, and admin operations in structured format
- Alert on anomalous patterns (mass login failures from single IP, account enumeration, etc.)

**Rationale**: Foundation for incident response and legal compliance (GDPR, COPPA — see ADR 019). Incident probability increases with user count; growth phase is the appropriate timing.

### 4. Long-term (decentralization phase)

Security enhancements aligned with ADR 014's decentralization roadmap.

#### 4.1 Client-side key generation + DID self-sovereignty

**Decision**:
- Generate Ed25519 key pairs in the browser/device via WebCrypto API
- Server receives public key only; never touches private key
- BIP-39 recovery phrase for key backup (ADR 014 Phase 2)
- Evaluate AT Protocol's `rotationKeys` pattern (key compromise recovery within time window)

**Rationale**: Full self-sovereign identity requires the server to never hold private keys. However, WebCrypto Ed25519 browser compatibility, recovery phrase UX design, and other challenges make this a gradual migration best suited for the decentralization phase.

#### 4.2 Zero-knowledge proof age verification

**Decision**:
- Integrate ZK proofs into ADR 019's age verification flow to prove age range without disclosing birth date
- Enable ZK-verifiable DID relationship for Guardian-Managed Accounts

**Rationale**: Ultimate form of privacy protection, but technological maturity and implementation cost position this as a long-term goal.

### Child safety security requirements

Per Idea 012 (age policy) and ADR 019, if Gleisner allows users under 13:
- COPPA (revised June 2025) requires verifiable parental consent
- Child accounts need additional protection layers:
  - Default-private posts (Idea 014)
  - Guardian-managed account recovery (not self-service)
  - Restricted data collection (minimize PII)
  - No direct messaging without guardian approval
- The 2FA and recovery mechanisms above must accommodate guardian-delegated authentication from the start

### Review items (confidence < 80 — further investigation needed)

#### R.1 UserType publicKey exposure (confidence 78)

`publicKey` is included in `UserType` (authenticated user's own view only) as an intentional design decision per ADR 016. It is NOT included in `PublicUserType`, so it is not visible to other users.

**Points to investigate**:
- Whether exposing historical public keys becomes problematic during key rotation
- Re-evaluate publicKey handling when migrating to client-side key generation

#### R.2 scrypt parameter N=16384 (confidence 75)

N=16384 (2^14) meets OWASP minimum, but N=32768 (2^15) or higher is advisable given 2026 hardware capabilities.

**Points to investigate**:
- Measure server memory/CPU impact (doubling N doubles resource consumption)
- Evaluate Argon2id migration in parallel (more modern memory-hard function)
- Password length cap (1.3) mitigates DoS risk even with lower N

## Consequences

### Positive

- Critical vulnerabilities (key leakage, auth bypass, DoS) are resolved before MVP release
- Phased implementation balances security investment with development velocity
- Consistent design with ADR 014 (decentralization), ADR 018 (copyright), ADR 019 (age policy)
- Clear migration path for key management toward full self-sovereign identity

### Negative

- Immediate fixes impact MVP schedule (though fix cost is small)
- GraphQL defense layers add slight friction to development-time query debugging (mitigated by relaxed dev-environment settings)
- Cloud KMS adoption increases infrastructure cost (Railway environment options need investigation)

### Accepted risks

The following risks are accepted at this time and will be addressed in the designated phase:
- Server-side key generation continues during MVP (mitigated by Cloud KMS)
- No Passkeys support (email/password + JWT is sufficient for MVP)
- No persisted queries (depth/complexity limits provide initial protection)

## Open Questions

| # | Topic | Notes |
|---|-------|-------|
| OQ-S01 | Cloud KMS feasibility on Railway | Compare Railway Secrets vs external KMS services |
| OQ-S02 | WebCrypto Ed25519 browser support | Verify behavior in Flutter Web (CanvasKit) environment |
| OQ-S03 | scrypt → Argon2id migration impact | Design migration strategy (re-hash on next login, etc.) |
| OQ-S04 | Rate limiting state management | Compare Redis vs in-memory vs Cloudflare WAF |
| OQ-S05 | AT Protocol rotationKeys applicability | Verify did:plc specification details (industry survey confidence 70) |

## Related

- ADR 001 — Project Vision (self-sovereignty philosophy)
- ADR 014 — Decentralization Roadmap (DID, key management, phase definitions)
- ADR 015 — Technology Stack (Ed25519, JWT, scrypt selection rationale)
- ADR 016 — User Identity Privacy (UserType / PublicUserType separation, publicKey handling)
- ADR 017 — Content Hash and Signature (contentHash, Ed25519 signatures)
- ADR 018 — Copyright Protection (DID-based infringement tracking)
- ADR 019 — Age Policy (COPPA/GDPR compliance, data minimization)
- Idea 012 — Age policy (COPPA implications)
- Idea 014 — Post visibility and audience control
- Idea 015 — View count display (analytics as paid feature, not free data leak)
- Idea 016 — Monetization strategy (security as trust differentiator)
