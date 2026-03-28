# ADR 022: Telecommunications Business Notification (電気通信事業届出)

## Status

Draft — **Requires legal counsel review before service launch**

## Context

Gleisner is a platform where users create posts, send messages, and interact through server-mediated communication. Under Japan's Telecommunications Business Act (電気通信事業法), any service that mediates communication between users using telecommunications equipment ("他人の通信を媒介") and provides this as a business ("他人の需要に応ずるために提供する事業") is required to file a notification (届出) with the Ministry of Internal Affairs and Communications (総務省).

Gleisner meets both criteria:

1. **Communication mediation**: Posts, DMs, reactions, and connections all pass through Gleisner's servers, mediating user-to-user communication
2. **Business provision**: Gleisner is operated as a service available to the general public

This is a **notification system (届出制), not a license system (許可制)** — filing is straightforward and does not require pre-approval. However, operating without filing is a legal violation subject to penalties.

### Legal basis

- **電気通信事業法 第16条**: 電気通信事業を営もうとする者は、総務大臣に届出をしなければならない
- **同法 第9条**: 電気通信事業の定義
- **同法 第186条**: 届出義務違反に対する罰則（6月以下の懲役又は50万円以下の罰金）

### Classification

Gleisner falls under **第三号事業 (Category 3)** — internet-related services that do not manage their own physical transmission infrastructure. The notification form category is "31 インターネット関連サービス（IP電話を除く。）".

Note: The 2022 amendment excludes large-scale services (10M+ users designated by the Minister) from Category 3, requiring full registration instead. This is not applicable at Gleisner's launch scale but must be monitored.

## Decision

### Pre-launch: File Telecommunications Business Notification

#### Filing Requirements

| Item | Detail |
|------|--------|
| Filing destination | 総合通信局 (Regional Bureau of Telecommunications) for the jurisdiction of the business address |
| Form | 電気通信事業届出書 (様式第8) |
| Category | 31 インターネット関連サービス（IP電話を除く。） |
| Cost | Free |
| Processing time | Typically accepted upon submission (届出制) |
| Required attachments | Network configuration diagram (ネットワーク構成図) |

#### Filing Checklist

- [ ] Prepare 電気通信事業届出書 (様式第8)
- [ ] Prepare network configuration diagram showing server infrastructure (Railway, Cloudflare)
- [ ] Identify the correct 総合通信局 based on business address
- [ ] Submit notification before service launch
- [ ] Retain copy of accepted notification with reception stamp (受付印)

### Post-filing Obligations

Once filed, Gleisner must comply with the following obligations:

#### 1. Protection of Communications Secrecy (通信の秘密の保護)

**Article 4**: The secrecy of communications handled by a telecommunications carrier shall not be violated.

- Server logs must not expose message content or metadata beyond operational necessity
- Employee access to user communications must be strictly controlled
- Law enforcement requests must follow proper legal procedures (裁判所の令状)

**Gleisner-specific considerations**:
- Content stored in PostgreSQL must have access controls
- Admin dashboard (future) must not display private post content or DMs without proper authorization
- Cloudflare R2 media storage access must be restricted

#### 2. External Transmission Regulation (外部送信規律)

**Article 27-12** (2023 amendment): When causing user information to be transmitted to third parties, the service must provide users with an opportunity to confirm.

Required disclosures:
- What information is being sent externally
- To whom it is being sent
- For what purpose

**Gleisner-specific considerations**:
- Analytics services (if any)
- Cloudflare services (CDN, R2)
- Claude API (Haiku) for title generation — user content is sent to Anthropic's API
- Any future third-party integrations

**Implementation**: Create a public page at `/legal/external-transmission` (or equivalent) documenting all external data transmissions. This page must be kept current as integrations change.

#### 3. Handling of User Information (利用者情報の適正な取扱い)

- Privacy policy must be published and accessible
- User data handling procedures must be documented
- Data breach notification procedures must be established

#### 4. Annual Report (報告義務)

Telecommunications carriers may be required to submit periodic reports to the 総合通信局 upon request.

### Relationship to Other ADRs

This notification affects and is affected by several existing decisions:

| ADR | Relationship |
|-----|-------------|
| ADR 014 (Decentralization) | Federation/IPFS may change the notification scope — if Gleisner operates relay nodes, additional filing may be required |
| ADR 016 (User Identity Privacy) | Communications secrecy obligations reinforce the privacy-by-design approach |
| ADR 018 (Copyright) | DMCA takedown procedures must respect communications secrecy boundaries |
| ADR 019 (Age Policy) | Minor user data handling has additional protections under both this Act and COPPA |
| ADR 020 (Security) | Security architecture must support communications secrecy compliance |

### Monitoring Thresholds

| Threshold | Action Required |
|-----------|----------------|
| 10M+ monthly users | May be designated as "large-scale" by Minister → full registration required (Category 3 exclusion) |
| Federation launch | Review whether relay/node operation changes filing category |
| New third-party integration | Update external transmission disclosure page |

## Consequences

- Gleisner operates legally in Japan from day one with minimal cost (free filing)
- Communications secrecy obligations align with Gleisner's existing privacy-by-design philosophy (ADR 016)
- External transmission regulation requires maintaining a disclosure page — low effort but must be kept current
- The Claude API integration for title generation constitutes external transmission and must be disclosed
- Future decentralization (ADR 014) may require re-evaluation of filing category
- Penalty for non-compliance is significant (up to 6 months imprisonment or ¥500,000 fine) — filing must be completed before launch

## Items Requiring Legal Counsel Review

| # | Item | Priority |
|---|------|----------|
| LC-1 | Review notification form and network diagram before submission | Pre-launch |
| LC-2 | Communications secrecy: scope of permissible server-side content analysis (spam detection, content moderation) | Pre-launch |
| LC-3 | External transmission: does Claude API title generation require opt-in consent or is disclosure sufficient? | Pre-launch |
| LC-4 | Federation impact: does operating IPFS/relay nodes require a different filing category? | Before ADR 014 Phase 1 |
| LC-5 | Business entity: can filing be done as an individual (個人事業主) or is corporate entity required? | Pre-launch |

## Related

- ADR 014 — Decentralization Roadmap (federation may affect filing scope)
- ADR 016 — User Identity Privacy (communications secrecy alignment)
- ADR 018 — Copyright Protection (takedown vs. secrecy boundary)
- ADR 019 — Age Policy (minor data protection overlap)
- ADR 020 — Security Architecture (technical compliance)
