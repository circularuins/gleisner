#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Starting PostgreSQL..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d --wait

echo "==> Starting backend dev server..."
# CORS_ORIGIN=* is required because Flutter Web dev server uses a random port
# that changes every run. See CLAUDE.md "CORS 注意" for details.
cd "$PROJECT_DIR/backend"
exec env CORS_ORIGIN="*" pnpm dev
