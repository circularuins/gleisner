#!/usr/bin/env bash
# Seed test data for development: user + artist + 6 tracks + ~30 posts across all media types
# Usage: ./scripts/seed-test-data.sh [api_url]
set -euo pipefail

API="${1:-http://localhost:4000/graphql}"
EMAIL="seed@test.com"
PASSWORD="password123"
USERNAME="seeduser"

echo "==> Seeding test data at $API"

# 1. Signup (ignore error if user exists)
TOKEN=$(curl -s "$API" -X POST -H 'Content-Type: application/json' \
  -d "{\"query\":\"mutation { signup(email:\\\"$EMAIL\\\", password:\\\"$PASSWORD\\\", username:\\\"$USERNAME\\\") { token } }\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['signup']['token'])" 2>/dev/null || true)

# 2. Login (if signup failed, user already exists)
if [ -z "$TOKEN" ]; then
  TOKEN=$(curl -s "$API" -X POST -H 'Content-Type: application/json' \
    -d "{\"query\":\"mutation { login(email:\\\"$EMAIL\\\", password:\\\"$PASSWORD\\\") { token } }\"}" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['login']['token'])")
fi

AUTH="Authorization: Bearer $TOKEN"
echo "==> Logged in as $USERNAME"

# 3. Register artist (ignore error if exists)
curl -s "$API" -X POST -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"query":"mutation { registerArtist(artistUsername:\"seeduser\", displayName:\"Seed Artist\") { id } }"}' > /dev/null 2>&1 || true

# 4. Create tracks
COLORS=("#f97316" "#a78bfa" "#22d3ee" "#84cc16" "#ef4444" "#fbbf24")
NAMES=("Play" "Compose" "Life" "English" "Live" "Studio")
for i in 0 1 2 3 4 5; do
  curl -s "$API" -X POST -H "Content-Type: application/json" -H "$AUTH" \
    -d "{\"query\":\"mutation { createTrack(name:\\\"${NAMES[$i]}\\\", color:\\\"${COLORS[$i]}\\\") { id } }\"}" > /dev/null 2>&1 || true
done
echo "==> Tracks created"

# 5. Get track IDs (single query, parse all at once)
TRACKS_JSON=$(curl -s "$API" -X POST -H "Content-Type: application/json" -H "$AUTH" \
  -d '{"query":"{ artist(username:\"seeduser\") { tracks { id name } } }"}')

get_track_id() {
  echo "$TRACKS_JSON" | python3 -c "
import json, sys
ts = json.load(sys.stdin)['data']['artist']['tracks']
matches = [t['id'] for t in ts if t['name'] == '$1']
print(matches[0] if matches else '')
"
}

PLAY=$(get_track_id Play)
COMPOSE=$(get_track_id Compose)
LIFE=$(get_track_id Life)
ENGLISH=$(get_track_id English)
LIVE=$(get_track_id Live)
STUDIO=$(get_track_id Studio)

echo "==> Track IDs: Play=$PLAY Compose=$COMPOSE Life=$LIFE English=$ENGLISH Live=$LIVE Studio=$STUDIO"

# 6. Create posts: track_id title importance mediaType [duration] [mediaUrl]
create_post() {
  local TID="$1" TITLE="$2" IMP="$3" MTYPE="$4" DUR="${5:-}" URL="${6:-}"
  local EXTRA=""
  [ -n "$DUR" ] && EXTRA="$EXTRA, duration:$DUR"
  [ -n "$URL" ] && EXTRA="$EXTRA, mediaUrl:\"$URL\""
  curl -s "$API" -X POST -H "Content-Type: application/json" -H "$AUTH" \
    -d "{\"query\":\"mutation { createPost(trackId:\\\"$TID\\\", title:\\\"$TITLE\\\", body:\\\"Test content for $TITLE\\\", mediaType:$MTYPE, importance:$IMP$EXTRA) { id } }\"}" > /dev/null
  sleep 0.3
}

# Play track
create_post "$PLAY" "Flamenco-session" 1.0 video 204
create_post "$PLAY" "Chord-melody-practice" 0.6 video 292
create_post "$PLAY" "Blues-scale-workout" 0.25 audio 150
create_post "$PLAY" "New-rasgueado-pattern" 0.8 text
create_post "$PLAY" "Fingerpicking-exercise" 0.15 audio 310
create_post "$PLAY" "Jazz-improv-notes" 0.4 text
create_post "$PLAY" "Live-at-open-mic" 0.95 video 464

# Compose track
create_post "$COMPOSE" "Final-mix-Sunrise" 0.8 audio 222
create_post "$COMPOSE" "Sidechain-experiment" 0.3 audio 48
create_post "$COMPOSE" "WIP-Sunrise-Protocol" 0.65 audio 107
create_post "$COMPOSE" "Mix-notes" 0.1 text
create_post "$COMPOSE" "Lyrics-Digital-Citizen" 0.4 text
create_post "$COMPOSE" "Beat-tape-vol3" 0.55 audio 382

# Life track
create_post "$LIFE" "Studio-morning" 0.03 image
create_post "$LIFE" "Park-hangout" 0.0 image
create_post "$LIFE" "New-gear-day" 0.5 image
create_post "$LIFE" "Morning-routine" 0.02 image
create_post "$LIFE" "Birthday" 0.6 image

# English track
create_post "$ENGLISH" "1K-followers-thankyou" 0.9 video 131
create_post "$ENGLISH" "QA-How-I-started" 0.6 video 225
create_post "$ENGLISH" "English-diary-5" 0.15 text
create_post "$ENGLISH" "Studio-tour" 0.55 video 255

# Live track
create_post "$LIVE" "Blues-jam-with-friends" 1.0 video 513
create_post "$LIVE" "Flamenco-x-beatbox" 0.95 video 372
create_post "$LIVE" "Talent-show-rehearsal" 0.5 video 115
create_post "$LIVE" "Evening-jam-circle" 0.85 audio 720

# Studio track
create_post "$STUDIO" "Sketch-Neon-Garden" 0.35 audio 72
create_post "$STUDIO" "EP-structure" 0.1 text
create_post "$STUDIO" "Collab-sketch" 0.7 audio 93
create_post "$STUDIO" "Demo-Glass-Ocean" 0.65 audio 178
create_post "$STUDIO" "cool-guitar-lesson" 0.45 link "" "https://www.youtube.com/watch?v=example"
create_post "$STUDIO" "music-theory-resource" 0.2 link "" "https://musictheory.net"

echo "==> 32 posts created"

# 7. Spread dates across 2 weeks
docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
WITH src AS (
  SELECT id, title FROM posts
  WHERE author_id = (SELECT id FROM users WHERE username = '$USERNAME')
)
UPDATE posts SET created_at = now() - (
  CASE src.title
    WHEN 'Flamenco-session' THEN interval '2 hours'
    WHEN 'Chord-melody-practice' THEN interval '8 hours'
    WHEN 'Blues-scale-workout' THEN interval '1 day 6 hours'
    WHEN 'New-rasgueado-pattern' THEN interval '1 day 14 hours'
    WHEN 'Fingerpicking-exercise' THEN interval '3 days 10 hours'
    WHEN 'Jazz-improv-notes' THEN interval '5 days 16 hours'
    WHEN 'Live-at-open-mic' THEN interval '8 days 21 hours'
    WHEN 'Final-mix-Sunrise' THEN interval '5 hours'
    WHEN 'Sidechain-experiment' THEN interval '2 days 13 hours'
    WHEN 'WIP-Sunrise-Protocol' THEN interval '4 days 11 hours'
    WHEN 'Mix-notes' THEN interval '6 days 9 hours'
    WHEN 'Lyrics-Digital-Citizen' THEN interval '9 days 15 hours'
    WHEN 'Beat-tape-vol3' THEN interval '12 days 8 hours'
    WHEN 'Studio-morning' THEN interval '9 hours'
    WHEN 'Park-hangout' THEN interval '2 days 17 hours'
    WHEN 'New-gear-day' THEN interval '5 days 12 hours'
    WHEN 'Morning-routine' THEN interval '7 days 7 hours'
    WHEN 'Birthday' THEN interval '10 days 3 hours'
    WHEN '1K-followers-thankyou' THEN interval '1 day 4 hours'
    WHEN 'QA-How-I-started' THEN interval '4 days 16 hours'
    WHEN 'English-diary-5' THEN interval '8 days 10 hours'
    WHEN 'Studio-tour' THEN interval '13 days 14 hours'
    WHEN 'Blues-jam-with-friends' THEN interval '1 hour'
    WHEN 'Flamenco-x-beatbox' THEN interval '3 days 20 hours'
    WHEN 'Talent-show-rehearsal' THEN interval '6 days 18 hours'
    WHEN 'Evening-jam-circle' THEN interval '11 days 22 hours'
    WHEN 'Sketch-Neon-Garden' THEN interval '4 hours'
    WHEN 'EP-structure' THEN interval '3 days 9 hours'
    WHEN 'Collab-sketch' THEN interval '5 days 19 hours'
    WHEN 'Demo-Glass-Ocean' THEN interval '7 days 15 hours'
    WHEN 'cool-guitar-lesson' THEN interval '9 days 11 hours'
    WHEN 'music-theory-resource' THEN interval '13 days 6 hours'
    ELSE interval '0'
  END
)
FROM src WHERE posts.id = src.id;
"

echo "==> Dates spread across 2 weeks"
echo "==> Done! Login: $EMAIL / $PASSWORD"
