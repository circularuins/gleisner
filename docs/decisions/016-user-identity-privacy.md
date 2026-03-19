# ADR 016: User Identity Privacy — PublicUserType Separation

## Status

Accepted

## Context

GraphQL API where user data is returned in multiple contexts: the authenticated user viewing their own profile (`me` query, `signup`/`login` responses) vs. other users appearing in public contexts (post authors, reaction users, comment users, followers, tune-in users).

Without explicit separation, sensitive fields (`email`, `passwordHash`, `encryptedPrivateKey`, etc.) could leak through public-facing resolvers. A single `UserType` with all fields creates a risk where future field additions (e.g., `t.exposeString("passwordHash")`) would immediately expose secrets.

## Decision

### Two GraphQL Types for Users

| Type | Exposed via | Fields |
|------|------------|--------|
| `UserType` | `me` query, `AuthPayload` (signup/login) | id, did, email, username, displayName, bio, avatarUrl, publicKey, createdAt, updatedAt |
| `PublicUserType` | All public queries (post author, reactions, comments, follows, tune-ins) | id, did, username, displayName, bio, avatarUrl, createdAt |

### Column Selection Pattern

Two explicit column sets prevent DB-level leakage:

- **`userColumns`** — For `UserType` resolvers. Includes email, publicKey, but excludes passwordHash, encryptedPrivateKey, passwordSalt, encryptionSalt.
- **`publicUserColumns`** — For `PublicUserType` resolvers. Further excludes email and publicKey.

### Rules

1. Never use `db.select().from(users)` (full-column select) — always specify a column set.
2. Never use `.returning()` without column restriction on the `users` table.
3. When adding fields to `PublicUserType`, update both `PublicUserShape` and `publicUserColumns`.
4. When adding fields to `UserType`, update both `UserShape` and `userColumns`.

## Consequences

- Email and secrets are protected at the DB query level, not just the GraphQL schema level.
- Two-layer defense: TypeScript types + Drizzle column selection.
- Slight code overhead for maintaining two type definitions and column sets.

## Related

- ADR 014: Decentralization Roadmap (DID compatibility)
- ADR 015: Technology Stack (Ed25519 for key pairs)
- Implementation: `src/graphql/types/user.ts`
