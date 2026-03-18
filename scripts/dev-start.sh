#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Starting PostgreSQL..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d --wait

echo "==> Starting backend dev server..."
cd "$PROJECT_DIR/backend"
exec pnpm dev
