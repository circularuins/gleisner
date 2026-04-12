#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/set-featured-artist.sh <username>
# Sets the specified artist as the featured artist (clears previous).
# admin CLI tool — bypasses API authentication intentionally.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

USERNAME="${1:-}"

if [ -z "$USERNAME" ]; then
  echo "Usage: $0 <artist_username>"
  echo "Sets the specified artist as the featured artist on the login/signup screen."
  exit 1
fi

# Validate username format
if ! echo "$USERNAME" | grep -qE '^[a-zA-Z0-9_]{1,30}$'; then
  echo "Error: Invalid username format. Must be 1-30 alphanumeric characters or underscores."
  exit 1
fi

DB_CONTAINER="gleisner-db"

echo "==> Clearing previous featured artist..."
docker exec "$DB_CONTAINER" psql -U gleisner -d gleisner -c \
  "UPDATE artists SET is_featured = false WHERE is_featured = true;"

echo "==> Setting '$USERNAME' as featured artist..."
# USERNAME is validated above (alphanumeric + underscore only), safe to embed in SQL.
# psql -v/:'var' parameterization doesn't work reliably through docker exec.
RESULT=$(docker exec "$DB_CONTAINER" psql -U gleisner -d gleisner -t -c \
  "UPDATE artists SET is_featured = true WHERE artist_username = '$USERNAME' AND profile_visibility = 'public' RETURNING artist_username;")

if [ -z "$(echo "$RESULT" | tr -d '[:space:]')" ]; then
  echo "Error: Artist '$USERNAME' not found or profile is not public."
  echo "Make sure the artist exists and has profile_visibility = 'public'."
  exit 1
fi

echo "==> Done! Featured artist: $USERNAME"
