# Gleisner

A decentralized, DAW-style multi-track timeline platform for artists to publish and control their multifaceted creative work.

## Why "Gleisner"?

In Greg Egan's novel *Diaspora*, **Gleisner robots** are the bridge between the physical and digital worlds — autonomous bodies that allow digital citizens to interact with physical reality. This project serves a similar purpose: bridging an artist's real-world creative activities with their digital presence, giving them full ownership and control.

## Core Concept

**DAW-style Multi-Track Timeline** — Just as a Digital Audio Workstation lets musicians layer multiple tracks (vocals, drums, synths) into a unified composition, Gleisner lets artists layer multiple activity streams (music, visual art, writing, performances) into a single, unified timeline. Users can solo, mute, or mix tracks to explore different facets of the artist's work.

## Tech Stack

> **Status: Accepted** — See [ADR 015](docs/decisions/015-technology-stack.md).

| Layer | Technology | Notes |
|-------|-----------|-------|
| Frontend | Flutter 3.x (Dart) | Web first (CanvasKit), iOS/Android later |
| Backend | TypeScript + Hono | Node.js runtime |
| Database | PostgreSQL 16 + Drizzle ORM | Type-safe queries, Drizzle Kit for migrations |
| API | GraphQL (Yoga + Pothos) | WebSocket Subscriptions for realtime |
| Auth | JWT + Ed25519 key pairs | DID-compatible ([ADR 014](docs/decisions/014-decentralization-roadmap.md)) |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (for PostgreSQL)
- [Node.js](https://nodejs.org/) >= 20
- [pnpm](https://pnpm.io/) >= 9
- [Flutter](https://flutter.dev/docs/get-started/install) >= 3.x (stable channel)

## Quick Start

### 1. Clone and setup

```bash
git clone https://github.com/circularuins/gleisner.git
cd gleisner
./scripts/dev-setup.sh
```

This will:
- Start PostgreSQL in Docker (port 5433)
- Install backend dependencies (`pnpm install`)
- Create `.env` from `.env.example`
- Push DB schema (`pnpm db:push`)
- Install frontend dependencies (`flutter pub get`)

### 2. Start the backend

```bash
./scripts/dev-start.sh
```

Starts PostgreSQL (if not running) and the backend dev server at **http://localhost:4000**.

> **CORS note**: Flutter Web uses a random port on each launch. `dev-start.sh` handles this. If starting manually: `CORS_ORIGIN="*" pnpm dev`

### 3. Start the frontend

In a separate terminal:

```bash
cd frontend
flutter run -d chrome
```

### 4. Seed test data

With the backend running:

```bash
# Base data: 1 artist, 6 tracks, 32 posts, reactions, constellations
./scripts/seed-test-data.sh

# Multi-artist data: 4 artists, 20 genres, Tune In/Follow relationships
./scripts/seed-discover-data.sh
```

### Test accounts

| Email | Password | Role |
|-------|----------|------|
| `seed@test.com` | `password123` | Artist (Musician) |
| `ayumi@test.com` | `password123` | Artist (Visual Artist) |
| `takeshi@test.com` | `password123` | Artist (Writer) |
| `mika@test.com` | `password123` | Artist (Filmmaker) |
| `fan@test.com` | `password123` | Fan only |
| `sakura@test.com` | `password123` | Fan only |

## Development

### Backend commands

```bash
cd backend
pnpm dev              # Dev server with hot reload
pnpm build            # TypeScript type check
pnpm lint             # ESLint
pnpm format:check     # Prettier check (CI)
pnpm test             # Integration tests (⚠ truncates seed data)
pnpm db:push          # Push schema to DB (⚠ may drop data)
pnpm db:generate      # Generate migration files
pnpm db:migrate       # Run migrations
pnpm db:studio        # Drizzle Studio (DB GUI)
```

### Frontend commands

```bash
cd frontend
dart analyze lib/     # Static analysis
dart format .         # Format code
flutter test          # Unit & widget tests
flutter run -d chrome # Run on Chrome
```

### Docker

```bash
docker compose up -d   # Start PostgreSQL
docker compose down    # Stop PostgreSQL
```

### Important notes

- **After `pnpm test`**: Seed data is truncated. Re-run seed scripts before manual testing.
- **After `pnpm db:push`**: May recreate tables and drop data. Use `db:generate` + `db:migrate` on populated databases.
- **After backend code changes**: Restart the dev server (schema, resolvers are not hot-reloaded).

## Architecture

- **API-first monorepo** — Backend and frontend are fully separated, communicating exclusively through GraphQL.

```
gleisner/
├── backend/
│   ├── src/
│   │   ├── auth/           # JWT, Ed25519, DID
│   │   ├── db/schema/      # Drizzle schema (12 tables)
│   │   └── graphql/
│   │       ├── types/      # Resolvers (artist, post, track, tune-in, ...)
│   │       └── __tests__/  # Integration tests
│   └── drizzle/            # Migration files
├── frontend/
│   ├── lib/
│   │   ├── graphql/        # Queries & mutations
│   │   ├── models/         # Data models
│   │   ├── providers/      # Riverpod state management
│   │   ├── screens/        # Page-level widgets
│   │   ├── widgets/        # Reusable components
│   │   ├── theme/          # Design tokens
│   │   └── utils/          # Constellation layout engine, helpers
│   └── test/
├── scripts/                # Dev setup, seed data
├── docs/
│   ├── decisions/          # Architecture Decision Records (ADR)
│   └── ideas/              # Feature exploration docs
└── docker-compose.yml
```

## Documentation

Architecture Decision Records are maintained in [`docs/decisions/`](docs/decisions/). Key decisions:

| ADR | Title |
|-----|-------|
| [004](docs/decisions/004-multitrack-timeline.md) | Multitrack Timeline |
| [008](docs/decisions/008-artist-mode.md) | Artist Mode & Content Management |
| [009](docs/decisions/009-discover-tab.md) | Discover Tab |
| [012](docs/decisions/012-track-redesign.md) | Track System Redesign |
| [013](docs/decisions/013-profile-and-artist-page.md) | Profile & Artist Page |
| [015](docs/decisions/015-technology-stack.md) | Technology Stack |

## License

[GNU Affero General Public License v3.0](LICENSE) — See [ADR 003](docs/decisions/003-license-agpl.md) for the rationale.
