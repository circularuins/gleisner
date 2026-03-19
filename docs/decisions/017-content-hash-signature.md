# ADR 017: Post Content Hash and Optional Signature

## Status

Accepted

## Context

ADR 014 (Decentralization Roadmap) identifies content addressing and digital signatures as key features for the self-sovereign architecture. For MVP, we need tamper-detection infrastructure without requiring all clients to implement Ed25519 signing.

Key constraints:
- Not all clients will support Ed25519 signing at launch
- Content hash should be computed server-side for consistency
- Signed posts should not lose their signature silently on update
- Infrastructure must align with future DID-based verification (ADR 014 Phase 2)

## Decision

### Content Hash (Always Computed)

Every post gets a `contentHash` (SHA-256, 64 hex chars) computed server-side on create and update.

**Hash input — JSON canonical form:**
```typescript
JSON.stringify({
  title: fields.title ?? "",
  body: fields.body ?? "",
  mediaUrl: fields.mediaUrl ?? "",
  mediaType: fields.mediaType,
  importance: fields.importance,
})
```

**Excluded from hash:** `layoutX`, `layoutY` (presentation-only; moving a post on the timeline does not alter its content).

**Purpose even without signature:**
1. Content integrity checks (detect DB-level corruption or bugs)
2. Enable future signature addition without reprocessing existing posts

### Signature (Optional for MVP)

- Ed25519 signature over the `contentHash`, base64-encoded (88 chars)
- Client provides `signature` argument in `createPost`/`updatePost` mutations
- Server verifies against author's `publicKey` stored at signup
- If not provided, post is stored with `signature: null`

### Signed Post Update Protection

When a signed post's content is updated:
- A new signature **must** be provided — prevents silent signature removal
- If no signature is provided, the mutation throws: `"This post was signed. A new signature is required when updating content."`

When content is **not** changed (e.g., only `layoutX`/`layoutY`), signature is preserved as-is.

### Validation

| Check | Error |
|-------|-------|
| Signature not 88 chars | "Invalid signature format" |
| Signature verification fails | "Invalid signature" |
| Signer is not post author | "Only the post author can sign this post" |
| Author has no public key | "Author has no registered public key" |
| Content unchanged but signature provided | "Signature can only be updated when content fields are changed." |

## Consequences

- All posts have tamper-detection via contentHash, regardless of client signing capability
- Signature is strictly opt-in; no client is blocked from posting
- Signed posts maintain integrity across updates
- Future DID integration (ADR 014 Phase 2) can leverage existing contentHash + signature columns
- JSON canonical form prevents field-boundary collision attacks

## Related

- ADR 007: Posting Flow (contentHash/signature as optional post details)
- ADR 014: Decentralization Roadmap (content addressing, Phase 2 on-chain verification)
- ADR 015: Technology Stack (Ed25519 for DID compatibility)
- Implementation: `src/auth/signing.ts`, `src/graphql/types/post.ts`
