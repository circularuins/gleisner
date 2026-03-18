#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Starting PostgreSQL..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d --wait

echo "==> Installing backend dependencies..."
cd "$PROJECT_DIR/backend"
pnpm install

echo "==> Setting up .env..."
if [ ! -f .env ]; then
  cp .env.example .env
  echo "    .env created from .env.example"
else
  echo "    .env already exists, skipping"
fi

echo "==> Pushing DB schema..."
pnpm db:push

echo "==> Installing frontend dependencies..."
cd "$PROJECT_DIR/frontend"
flutter pub get

echo ""
echo "Setup complete! Run ./scripts/dev-start.sh to start the dev server."
