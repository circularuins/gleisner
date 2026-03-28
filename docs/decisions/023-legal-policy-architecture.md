# ADR 023: Legal Policy Architecture — Required Documents, UI Placement, and Consent Flow

## Status

Draft — **Requires legal counsel review before implementation**

## Context

Gleisner requires a comprehensive set of legal documents before public launch. Several ADRs have already designed specific policies (ADR 018: copyright/DMCA, ADR 019: age/guardian, ADR 020: security/GDPR minimum, ADR 022: telecommunications notification), but these exist as architectural decisions — not as user-facing legal documents.

This ADR defines:
1. **What legal documents are needed** (and which are already designed vs. new)
2. **Where they live in the UI** (placement, navigation)
3. **How users consent** (signup flow, consent records)
4. **What data must be retained** for legal compliance

### Legal landscape for a Japan-based SNS

Gleisner must comply with multiple legal frameworks simultaneously:

| Law | Scope | Key Obligation |
|-----|-------|----------------|
| 個人情報保護法 (APPI) | All personal data handling | Privacy policy with specific use purposes, breach notification, user rights |
| 電気通信事業法 | Communications mediation | Notification filing (ADR 022), communications secrecy, external transmission disclosure |
| 情報流通プラットフォーム対処法 (旧プロバイダ責任制限法) | UGC platforms | Sender information disclosure compliance, takedown procedures |
| 特定商取引法 | If paid features exist | Business operator disclosure, cancellation procedures |
| GDPR | EU users | Consent, data portability, right to erasure, DPO (at scale) |
| COPPA | US users under 13 | Verifiable Parental Consent (ADR 019) |
| DMCA §512 | US copyright | Safe harbor, designated agent (ADR 018) |

### What's already designed vs. gaps

| Policy Area | Existing ADR | Gap |
|-------------|-------------|-----|
| Copyright/DMCA takedown | ADR 018 (detailed) | Needs user-facing document |
| Repeat infringer policy | ADR 018 (detailed) | Needs user-facing document |
| Age policy / child safety | ADR 019 (detailed) | Needs user-facing document |
| Privacy (architecture) | ADR 016, 019, 020 | Needs comprehensive privacy policy |
| Telecom notification | ADR 022 | Filing only — obligations feed into other docs |
| Terms of Service | ADR 018 (copyright clauses only) | Needs full ToS |
| AI usage policy | — | New |
| Sender info disclosure | — | New (情プラ法) |
| Cookie/external transmission | ADR 022 (obligation noted) | Needs user-facing page |
| Account inheritance (death) | — | New |
| Data succession (M&A) | — | Covered within ToS |

## Decision

### Document Inventory

#### Tier 1: Pre-launch MUST (法的義務)

| # | Document | Primary Law | Notes |
|---|----------|-------------|-------|
| D-1 | **Terms of Service (利用規約)** | 民法, 消費者契約法 | Master agreement — references all other policies |
| D-2 | **Privacy Policy (プライバシーポリシー)** | 個人情報保護法, GDPR | Personal data handling, user rights, breach procedures |
| D-3 | **External Transmission Disclosure (外部送信に関する公表事項)** | 電気通信事業法 27-12 | What data is sent where and why |
| D-4 | **Copyright & Takedown Policy (著作権・権利侵害対応ポリシー)** | DMCA, 情プラ法 | Based on ADR 018 — DMCA process, repeat infringer policy |
| D-5 | **Child Safety Policy (児童安全ポリシー)** | COPPA, GDPR Art.8, 児童福祉法 | Based on ADR 019 — guardian accounts, data minimization |
| D-6 | **Sender Information Disclosure Policy (発信者情報開示に関するポリシー)** | 情プラ法 | Disclosure request handling, log retention |
| D-7 | **AI Usage Policy (AI利用ポリシー)** | 個人情報保護法 (第三者提供) | Claude API usage, no training on user content |

#### Tier 2: Pre-launch SHOULD (ベストプラクティス)

| # | Document | Notes |
|---|----------|-------|
| D-8 | **Cookie Policy (Cookieポリシー)** | Can be section of Privacy Policy if minimal cookie use |
| D-9 | **Community Guidelines (コミュニティガイドライン)** | Prohibited content, behavioral standards — referenced from ToS |

#### Tier 3: When Feature Launches

| # | Document | Trigger |
|---|----------|---------|
| D-10 | **API & Bot Terms (API・Bot利用規約)** | Public API launch |
| D-11 | **Creator Monetization Terms (クリエイター収益化規約)** | Monetization feature |
| D-12 | **Specified Commercial Transaction Disclosure (特定商取引法に基づく表記)** | Any paid feature |

#### Tier 4: As Needed

| # | Document | Trigger |
|---|----------|---------|
| D-13 | **Account Inheritance Policy (死亡・相続時のアカウント取扱い)** | First incident or at meaningful user scale |
| D-14 | **Data Succession Policy (事業譲渡に伴うデータ継承)** | Covered as a clause in ToS (D-1) |

### Document Relationships

```
Terms of Service (D-1) ← Master agreement
├── Privacy Policy (D-2)
│   ├── External Transmission Disclosure (D-3)
│   ├── Cookie Policy (D-8)
│   └── AI Usage Policy (D-7)
├── Copyright & Takedown Policy (D-4)
│   └── Repeat Infringer Policy (section)
├── Child Safety Policy (D-5)
├── Sender Info Disclosure Policy (D-6)
├── Community Guidelines (D-9)
└── [Future] API Terms (D-10), Creator Terms (D-11)
```

ToS is the root document. Users agree to the ToS, which incorporates all sub-policies by reference. Sub-policies can be updated independently (with notification) without requiring re-acceptance of the entire ToS — unless the change is material.

### Key Content Decisions

#### D-1: Terms of Service — Key Clauses

| Clause | Content | Source |
|--------|---------|--------|
| License grant | User grants Gleisner limited license for display/distribution. No ownership transfer. | ADR 018 §1.6 |
| Content ownership | Users retain full ownership of their content. | ADR 001 vision |
| Prohibited conduct | Infringement, harassment, impersonation, spam, illegal content | New |
| Account termination | Gleisner may terminate for repeated violations | ADR 018 §1.5 |
| Data upon termination | Content export available for 30 days post-termination | New |
| Data succession (M&A) | User data may transfer with business; notification + opt-out provided | New (D-14 clause) |
| Dispute resolution | Japanese law governs; Tokyo District Court jurisdiction | New |
| Age requirement | All ages with guardian system (ADR 019). No blanket age ban. | ADR 019 |

#### D-2: Privacy Policy — Required Sections (個人情報保護法)

| Section | Content |
|---------|---------|
| 事業者情報 | Operator name, address, contact |
| 取得する個人情報 | DID, email, username, display name, content, IP (session only), guardian info (minors) |
| 利用目的 | Service provision, abuse prevention, AI title generation (Claude API), legal compliance |
| 第三者提供 | Cloudflare (CDN/storage), Anthropic (Claude API — title generation only), law enforcement (court order) |
| 安全管理措置 | Encryption, access control, Ed25519 signing (ref ADR 020) |
| 開示・訂正・削除請求 | Request procedure, response timeline, contact |
| データポータビリティ | Export endpoint (ref ADR 020 GDPR minimum) |
| 保有期間 | Content: account lifetime. Logs: session only. Consent records: age 18 + 3 years (minors). |
| 漏洩時の対応 | Notification to 個人情報保護委員会 + affected users |
| 未成年者の取扱い | Ref D-5 (Child Safety Policy), data minimization per ADR 019 |
| 国際転送 | Data stored on Railway (US region) / Cloudflare (global CDN) — disclosure required |

#### D-6: Sender Information Disclosure Policy — Key Design

Under the 情報流通プラットフォーム対処法 (effective 2025-04-01):

**All operators (including small-scale) must:**
- Respond to court-ordered sender information disclosure (発信者情報開示命令)
- Retain sufficient logs (IP address, timestamp) to identify senders
- Have a process for handling disclosure requests

**Log retention design:**

| Data | Retention | Purpose |
|------|-----------|---------|
| IP address | 6 months from access (proposed) | Sender identification |
| Access timestamp | 6 months from access (proposed) | Sender identification |
| Account creation IP | Account lifetime + 1 year | Fraud/abuse investigation |
| Post metadata (author, timestamp) | Content lifetime | Attribution |

Note: Gleisner's current architecture stores IP addresses for the session only (ADR 019). **This must change** — a minimum retention period is needed for sender information disclosure compliance. The exact period requires legal counsel input, but 3-6 months is industry standard.

**⚠ Architecture impact**: Backend must add IP logging with retention policy. This is a new requirement not covered by existing ADRs.

#### D-7: AI Usage Policy — Key Commitments

| Commitment | Detail |
|------------|--------|
| What AI is used for | Post title auto-generation (Claude API / Haiku) |
| What data is sent | Post title, body text (content fields only — no personal identifiers) |
| User content is NOT used for AI training | Explicit commitment — Anthropic's API terms also prohibit training on API inputs |
| Opt-out | Users can disable AI title generation (feature toggle) |
| AI-generated content labeling | AI-suggested titles are marked as such in the UI |
| No profiling | AI is not used for behavioral profiling, recommendations, or ad targeting |
| Future AI features | Any new AI integration will be disclosed before deployment |

This positions Gleisner closer to Bluesky's approach (explicit no-training commitment) rather than X/Meta's approach (opt-out from training). This aligns with Gleisner's philosophy of user data sovereignty (ADR 001).

### UI Placement

#### Legal Pages — Route Structure

```
/legal                          → Legal index page (all documents listed)
/legal/terms                    → Terms of Service (D-1)
/legal/privacy                  → Privacy Policy (D-2)
/legal/external-transmission    → External Transmission Disclosure (D-3)
/legal/copyright                → Copyright & Takedown Policy (D-4)
/legal/child-safety             → Child Safety Policy (D-5)
/legal/disclosure               → Sender Info Disclosure Policy (D-6)
/legal/ai                       → AI Usage Policy (D-7)
/legal/cookies                  → Cookie Policy (D-8)
/legal/guidelines               → Community Guidelines (D-9)
```

#### Access Points in UI

| Location | What to Show | Implementation |
|----------|-------------|----------------|
| **Footer** (all pages) | Links to: Terms, Privacy, Copyright | Persistent footer with legal links |
| **Signup screen** | Consent checkbox with links to Terms + Privacy | Required before account creation |
| **Settings > Legal** | Full list of all legal documents | Settings menu section |
| **Onboarding** (guardian flow) | Child Safety Policy + explicit consent | Part of VPC flow (ADR 019) |
| **Post creation** (AI title) | "AI-generated" label + link to AI policy | Inline disclosure |
| **Profile/About** | Link to legal index | Footer or menu |
| **Public pages** (`/@username`) | Footer links accessible without auth | Same footer as authenticated pages |

#### Legal Footer Design

```
┌──────────────────────────────────────────────────┐
│  © 2026 Gleisner                                  │
│  Terms · Privacy · Copyright · Guidelines         │
│  [Language toggle: EN / JA]                       │
└──────────────────────────────────────────────────┘
```

- Footer is persistent across all screens (including public `/@username` pages)
- Compact: key documents only. Full list available at `/legal`
- Bilingual: all legal documents must be available in both Japanese and English

### Consent Flow

#### Signup Consent (Standard — Age 18+)

```
Signup Form:
  [Username] [Email] [Password]

  ☐ 利用規約とプライバシーポリシーに同意します
    I agree to the Terms of Service and Privacy Policy
    [利用規約] [プライバシーポリシー] ← tappable links

  [Create Account] ← disabled until checkbox is checked
```

**Design decisions:**
- Single checkbox covering ToS + Privacy Policy (industry standard, legally sufficient)
- Sub-policies (copyright, AI, etc.) are incorporated by reference in ToS — no separate checkboxes needed
- Links must open the actual documents (not just named)
- Checkbox is **required** — account creation button is disabled until checked

#### Signup Consent (Guardian Flow — Age <13)

```
Guardian Account Creation:
  [Guardian info fields]

  ☐ 利用規約とプライバシーポリシーに同意します（保護者として）
    I agree to the Terms of Service and Privacy Policy (as guardian)
  ☐ 児童安全ポリシーを確認し、未成年者のデータ取扱いに同意します
    I have reviewed the Child Safety Policy and consent to minor data handling
    [児童安全ポリシー] ← tappable link

  [Create Guardian Account] ← disabled until both checkboxes are checked
```

**Design decisions:**
- Two separate checkboxes for guardian flow (COPPA requires specific consent for child data)
- Child Safety Policy consent is a separate, explicit action
- VPC (Verifiable Parental Consent) is an additional step after these checkboxes (ADR 019)

#### Consent Record Storage

```typescript
interface ConsentRecord {
  userId: string;          // DID of consenting user
  consentType: "tos" | "privacy" | "child_safety" | "guardian_vpc";
  documentVersion: string; // e.g., "terms-v1.0", "privacy-v2.1"
  consentedAt: string;     // ISO 8601 timestamp
  ipAddress: string;       // IP at time of consent
  userAgent: string;       // Browser/device info
}
```

**Retention**: Consent records are retained for the lifetime of the account + 3 years (statute of limitations buffer). For minor accounts, retention follows ADR 019 rules (age 18 + 3 years).

#### Material Change Re-consent

When a legal document undergoes a **material change** (defined as: changes to data collection scope, third-party sharing, user rights, or dispute resolution):

1. Notify all users via in-app banner (not just email)
2. Provide 30-day notice period before the change takes effect
3. Require re-acceptance for material ToS changes
4. Log the new consent with updated document version

Non-material changes (typo fixes, clarifications) do not require re-consent but should be noted in a changelog.

### Language and Localization

| Requirement | Detail |
|------------|--------|
| Primary language | Japanese (法的効力を持つ正本) |
| Secondary language | English |
| In case of conflict | Japanese version prevails (stated in ToS) |
| Document format | Markdown source → rendered HTML on `/legal/*` pages |

### Implementation Phases

#### Phase 1: Pre-launch (MVP)

- [ ] D-1: Terms of Service (Japanese + English)
- [ ] D-2: Privacy Policy (Japanese + English)
- [ ] D-3: External Transmission Disclosure
- [ ] D-4: Copyright & Takedown Policy (based on ADR 018)
- [ ] D-5: Child Safety Policy (based on ADR 019)
- [ ] D-6: Sender Information Disclosure Policy
- [ ] D-7: AI Usage Policy
- [ ] Signup consent checkbox UI
- [ ] Legal footer on all pages
- [ ] `/legal` index page and sub-routes
- [ ] Consent record storage (backend)
- [ ] IP address logging with retention policy (backend — new requirement)

#### Phase 2: Post-launch Enhancement

- [ ] D-8: Cookie Policy (if analytics/tracking added)
- [ ] D-9: Community Guidelines
- [ ] Material change notification system
- [ ] Document version tracking and changelog
- [ ] Guardian-specific consent flow (when ADR 019 is implemented)

#### Phase 3: Feature-driven

- [ ] D-10: API Terms (when API is public)
- [ ] D-11: Creator Monetization Terms (when monetization launches)
- [ ] D-12: 特定商取引法表記 (when paid features launch)
- [ ] D-13: Account Inheritance Policy (when needed)

## Consequences

- All legally required documents are identified and prioritized before launch
- Signup consent flow meets APPI + GDPR + COPPA requirements through a minimal but legally sufficient checkbox design
- Legal documents are accessible from every screen via persistent footer
- Bilingual (JA/EN) with Japanese as the legally binding version
- Consent records provide an auditable trail for regulatory compliance
- **New architecture requirement identified**: IP address logging with retention (currently session-only per ADR 019) must be added for 情プラ法 compliance. This creates a tension with data minimization that must be resolved with minimal retention period.
- AI Usage Policy with explicit no-training commitment differentiates Gleisner from major platforms
- Document structure (ToS as master + sub-policies by reference) allows independent updates without full re-consent
- Phase 1 scope (7 documents + UI) is achievable pre-launch; remaining documents are deferred to appropriate triggers

## Items Requiring Legal Counsel Review

| # | Item | Priority |
|---|------|----------|
| LC-1 | Draft review of all Tier 1 documents (D-1 through D-7) | Pre-launch |
| LC-2 | IP log retention period: minimum required for 情プラ法 compliance vs. APPI data minimization | Pre-launch |
| LC-3 | Single consent checkbox: legally sufficient for APPI + GDPR, or must Privacy Policy consent be separate? | Pre-launch |
| LC-4 | Claude API data transmission: does sending post content constitute "第三者提供" requiring explicit opt-in? | Pre-launch |
| LC-5 | International data transfer disclosure: Railway (US) + Cloudflare (global) — adequate consent mechanism? | Pre-launch |
| LC-6 | Material change threshold: what constitutes a "material" vs. "non-material" change in Japanese consumer contract law? | Pre-launch |
| LC-7 | Guardian consent: does COPPA require a separate click-through for Child Safety Policy, or can it be folded into VPC? | Pre-launch |

## Related

- ADR 001 — Project Vision (user data sovereignty)
- ADR 016 — User Identity Privacy (PublicUserType separation)
- ADR 018 — Copyright Protection (D-4 source)
- ADR 019 — Age Policy (D-5 source, consent records, data minimization tension with IP logging)
- ADR 020 — Security Architecture (GDPR minimum, encryption)
- ADR 022 — Telecommunications Business Notification (D-3 obligation source)
