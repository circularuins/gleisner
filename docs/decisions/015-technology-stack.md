# ADR 015: Technology Stack Selection

## Status

Accepted

## Context

The MVP requirements (mvp-requirements.md) and decentralization roadmap (ADR 014) are complete. Technology stack selection is the next blocker before implementation can begin.

### Constraints

- **Solo developer** — all choices must prioritize development velocity over theoretical optimality
- **ADR 006** — Timeline visual design requires CustomPainter-level rendering (constellation metaphor, particle effects)
- **ADR 014** — Decentralization roadmap requires Ed25519 key pairs, DID compatibility, and IPFS-ready media storage
- **MVP scope** — Family and musician friends (tens of users), URL sharing, no app store submission
- **Budget** — Must stay under $50/month for infrastructure
- **License** — All dependencies must be compatible with AGPL v3 (ADR 003)

## Decision

### Stack Summary

| Layer | Technology | Notes |
|-------|-----------|-------|
| Frontend | Flutter 3.x (Web → Mobile) | CanvasKit renderer for Web |
| Backend | TypeScript + Hono | Node.js runtime for MVP |
| Database | PostgreSQL 16 + Drizzle ORM | Type-safe queries, SQL-close syntax |
| Media Storage | Cloudflare R2 | S3-compatible, zero egress cost |
| API Protocol | GraphQL (yoga + pothos) | Subscriptions via WebSocket |
| Authentication | JWT + Ed25519 key pairs | DID-compatible from day one |
| AI Services | Claude API (Haiku) | Title auto-generation |
| Frontend Hosting | Cloudflare Pages | Free tier |
| Backend Hosting | Railway | Node.js + PostgreSQL, ~$5–20/mo |

### Frontend: Flutter (Web first, Mobile later)

**Choice:** Flutter 3.x (Dart), targeting Flutter Web with CanvasKit renderer.

**Rationale:**
- ADR 006 evaluated Flutter as "strongest fit" for the constellation timeline (CustomPainter for particle rendering)
- Founder has Flutter experience → minimal learning curve
- Web build enables URL-only distribution (no app store review)
- MVP data volume (tens to hundreds of items) is well within Flutter Web's performance envelope
- Code reuse rate of 80–90% when adding iOS/Android later

**Rejected alternatives:**
- *React + Canvas:* Strong web performance but requires separate technology for mobile. Doesn't leverage existing Flutter expertise
- *Native (Swift/Kotlin):* Best performance but doubles development cost across two platforms. Unrealistic for solo development

### Backend: TypeScript + Hono

**Choice:** TypeScript with Hono framework, running on Node.js for MVP.

**Rationale:**
- DID/cryptography library ecosystem is strongest in JavaScript/TypeScript (did-jwt, @noble/hashes, @noble/ed25519)
- Hono is lightweight, fast, and type-safe — ideal for API-first design
- TypeScript's type system ensures frontend/backend API contract consistency
- Excellent Claude Code support (TypeScript is among the best-supported languages)
- Rich Node.js ecosystem (sharp for image processing, bull for job queues)

**Rejected alternatives:**
- *Rails (Ruby):* Founder has experience, but DID/crypto ecosystem is weak. Poor real-time support
- *Go:* Good performance but immature DID libraries. High learning cost
- *Python (FastAPI):* Good ML/AI integration but weaker type safety and DID ecosystem vs TypeScript
- *Rust (Axum):* Best performance but steep learning curve kills solo development velocity
- *Elixir (Phoenix):* Best real-time support but tiny ecosystem with almost no DID libraries

### Database: PostgreSQL + Drizzle ORM

**Choice:** PostgreSQL 16 with Drizzle ORM and Drizzle Kit for migrations.

**Rationale:**
- 12-entity relational model needs proper FK constraints, composite PKs, and transactions
- PostgreSQL natively supports full-text search (genre/artist search), JSONB (flexible metadata), and UUID types
- Drizzle ORM is TypeScript-native with type-safe queries, lightweight, and SQL-close syntax
- Fully compatible with AGPL v3

**Rejected alternatives:**
- *MongoDB:* Too many inter-entity relationships; JOINs are frequently needed
- *MySQL:* Weaker full-text search and JSONB support compared to PostgreSQL
- *Prisma:* Popular but Drizzle is lighter, closer to SQL, and easier to performance-tune

### Media Storage: Cloudflare R2

**Choice:** Cloudflare R2 (S3-compatible) with integrated Cloudflare CDN. Image transformation via Cloudflare Images or server-side sharp.

**Rationale:**
- S3-compatible API with zero egress fees → dramatically lower media delivery cost
- Automatic Cloudflare CDN integration
- Clear migration path to IPFS (object storage → content-addressed storage)
- Free tier: 10GB storage, 10M requests/month — sufficient for MVP

**Rejected alternatives:**
- *AWS S3:* Proven but high egress costs. Doesn't fit MVP cost constraints
- *MinIO (self-hosted):* High operational burden. Unsuitable for solo development

### API Protocol: GraphQL

**Choice:** GraphQL via yoga (server) + pothos (schema builder), with WebSocket Subscriptions for real-time updates. Client: graphql_flutter package.

**Rationale:**
- Timeline's nested data (Post + Reactions + Comments + Connections) fetched in a single request
- Subscriptions cover real-time reaction and comment updates
- pothos is TypeScript-first schema builder with full type safety
- Future clients (Web, iOS, Android) each fetch only what they need
- Avoids REST → GraphQL migration tech debt

**Rejected alternatives:**
- *REST:* Simpler but N+1 request problem predictable for nested timeline data. Future migration cost
- *gRPC:* Flutter integration limited on Web
- *tRPC:* Excellent for TypeScript-to-TypeScript but unusable from Flutter (Dart) client

### Authentication: JWT + DID-Compatible

**Choice:** JWT with Ed25519 key pairs, argon2id password hashing.

**Rationale:**
- JWT is stateless, fitting API-first design
- Ed25519 key pairs are DID-compatible (standard in did:key, did:plc)
- Same key pair serves both JWT signing and future DID registration → natural migration path
- argon2id is the current best-practice password hashing algorithm

### AI Services: Claude API

**Choice:** Claude API with Haiku for title auto-generation. Sonnet reserved for post-MVP connection detection.

**Rationale:**
- Haiku delivers sufficient quality for title generation at low cost
- Consistent with yatima's use of Claude Code as primary development tool
- Connection detection (thematic similarity analysis) is post-MVP scope requiring Sonnet's capability

### Infrastructure: Cloudflare Pages + Railway

**Choice:** Cloudflare Pages for frontend, Railway for backend + PostgreSQL, Cloudflare DNS.

**Rationale:**
- Cloudflare Pages has generous free tier for Flutter Web static hosting
- Railway offers PostgreSQL included from ~$5/month with git-push auto-deploy
- Both services are solo-developer-friendly in simplicity
- Migration path to AWS/GCP available when scale demands it

**MVP Cost Estimate:**

| Service | Cost |
|---------|------|
| Cloudflare Pages | Free |
| Cloudflare R2 | Free tier (10GB) |
| Railway | $5–20/month |
| Claude API (Haiku) | $5–10/month |
| Domain | ~$10/year |
| **Total** | **~$10–30/month** |

## Consequences

### Benefits

- **Unified language experience:** TypeScript backend + Dart frontend, both strongly typed
- **DID-ready from day one:** Ed25519 keys and TypeScript crypto ecosystem enable smooth ADR 014 transition
- **Cost-effective:** MVP runs under $30/month, well within the $50 budget constraint
- **Solo-developer optimized:** Every choice prioritizes development speed and operational simplicity
- **Cross-platform future:** Flutter's single codebase covers Web, iOS, and Android

### Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Flutter Web performance at scale | MVP targets tens of users; monitor Core Web Vitals. CanvasKit renderer handles custom drawing well. Mobile builds available as escape hatch |
| GraphQL complexity for solo developer | pothos + yoga reduce boilerplate. Start with simple queries, add complexity incrementally |
| Railway scaling limits | Railway supports horizontal scaling. Migration to AWS/GCP is straightforward if needed |
| Hono ecosystem maturity | Hono is Cloudflare-backed with growing adoption. Standard Node.js middleware is compatible |

### Trade-offs Accepted

- Flutter Web's initial load time (~2MB CanvasKit) is acceptable for MVP's URL-sharing use case (users bookmark and revisit)
- GraphQL's learning curve is accepted in exchange for avoiding REST → GraphQL migration later
- Railway over self-hosted infra trades control for operational simplicity

## Migration Path: Web → Mobile

1. **Phase 1 (MVP):** Flutter Web only. Validate UX with family and friends via URL sharing
2. **Phase 2:** Add responsive breakpoints for mobile browsers (still Web)
3. **Phase 3:** Build iOS/Android from same codebase. Platform-specific adjustments:
   - Push notifications (Firebase Cloud Messaging)
   - Deep linking
   - Platform-specific media pickers
   - App store metadata and screenshots
4. **Phase 4:** App store submission (after UX is validated and polished)

Expected code reuse: 80–90% (UI layouts need platform-specific responsive adjustments; business logic and state management are fully shared).

## Open Questions

1. **GraphQL client library for Flutter:** Ferry vs graphql_flutter vs graphql — needs hands-on evaluation during initial setup
2. **Image transformation pipeline:** Cloudflare Images vs server-side sharp — decide based on actual image processing requirements during implementation
3. **WebSocket infrastructure on Railway:** Verify Railway's WebSocket support for GraphQL Subscriptions; may need sticky sessions configuration
4. **Flutter Web SEO:** Artist pages may benefit from server-side rendering or pre-rendering for discoverability — evaluate post-MVP

## References

- ADR 001: Project Vision
- ADR 003: License (AGPL v3)
- ADR 006: Timeline Visual Design
- ADR 014: Decentralization Roadmap
- `docs/requirements/mvp-requirements.md`
