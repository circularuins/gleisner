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
  local TID="$1" TITLE="$2" IMP="$3" MTYPE="$4" DUR="${5:-}" URL="${6:-}" BODY="${7:-}"
  local EXTRA=""
  [ -n "$DUR" ] && EXTRA="$EXTRA, duration:$DUR"
  [ -n "$URL" ] && EXTRA="$EXTRA, mediaUrl:\"$URL\""
  [ -z "$BODY" ] && BODY="Test content for $TITLE"
  # Safely escape for JSON (handles quotes, newlines, backslashes)
  BODY=$(printf '%s' "$BODY" | jq -Rs . | sed 's/^"//;s/"$//')
  curl -s "$API" -X POST -H "Content-Type: application/json" -H "$AUTH" \
    -d "{\"query\":\"mutation { createPost(trackId:\\\"$TID\\\", title:\\\"$TITLE\\\", body:\\\"$BODY\\\", mediaType:$MTYPE, importance:$IMP$EXTRA) { id } }\"}" > /dev/null
  sleep 0.3
}

# Play track
create_post "$PLAY" "Flamenco-session" 1.0 video 204
create_post "$PLAY" "Chord-melody-practice" 0.6 video 292
create_post "$PLAY" "Blues-scale-workout" 0.25 audio 150
create_post "$PLAY" "New-rasgueado-pattern" 0.8 text "" "" "Been working on a new rasgueado technique all week. The key insight: instead of fanning all four fingers evenly, I delay the ring finger slightly to create a triplet feel against the strummed bass. It sounds almost like two guitarists playing at once. Still need to clean up the transition back into picado, but the core pattern is solid. Going to try it on the Bulerias piece next."
create_post "$PLAY" "Fingerpicking-exercise" 0.15 audio 310
create_post "$PLAY" "Jazz-improv-notes" 0.4 text "" "" "Transcribed the Wes Montgomery solo from Four on Six today. His octave technique is deceptively simple — the real magic is in the rhythmic displacement. He anticipates the chord changes by a half beat, creating this floating feeling over the groove. Tried applying the same concept to my own ii-V-I lines and it immediately made everything sound more musical. Less notes, more intention."
create_post "$PLAY" "Live-at-open-mic" 0.95 video 464

# Compose track
create_post "$COMPOSE" "Final-mix-Sunrise" 0.8 audio 222
create_post "$COMPOSE" "Sidechain-experiment" 0.3 audio 48
create_post "$COMPOSE" "WIP-Sunrise-Protocol" 0.65 audio 107
create_post "$COMPOSE" "Mix-notes" 0.1 text "" "" "Mixing session notes: The kick and bass are finally sitting right after sidechain compression at 3:1 ratio with 20ms attack. Vocals need more air around 12kHz — shelf boost maybe +2dB. The bridge section still feels empty. Thinking about adding a reversed reverb swell from the guitar hook. Also the snare sounds papery on laptop speakers, need to check the 200Hz region."
create_post "$COMPOSE" "Lyrics-Digital-Citizen" 0.4 text "" "" "Draft lyrics for Digital Citizen (verse 2):\n\nWe built our homes on borrowed ground\nServers hum where roots should grow\nEvery memory a rented room\nEvery voice an echo of the algorithm\n\nBut I remember the sound of rain on a real window\nAnd the weight of a letter that someone actually wrote\n\nStill working on the chorus. The theme is about reclaiming authenticity in digital spaces — which is literally what this platform is about."
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
create_post "$ENGLISH" "English-diary-5" 0.15 text "" "" "English diary day 5. Today I tried explaining my music production process in English to a friend from Berlin. I kept mixing up past tense and present tense when talking about the creative process. She said my English is getting much better though. New words I learned: resonance, overtone, sustain (I knew these in a music context but not how to use them in casual conversation). Going to try writing my next song bio in English first instead of translating from Japanese."
create_post "$ENGLISH" "Studio-tour" 0.55 video 255

# Live track
create_post "$LIVE" "Blues-jam-with-friends" 1.0 video 513
create_post "$LIVE" "Flamenco-x-beatbox" 0.95 video 372
create_post "$LIVE" "Talent-show-rehearsal" 0.5 video 115
create_post "$LIVE" "Evening-jam-circle" 0.85 audio 720

# Studio track
create_post "$STUDIO" "Sketch-Neon-Garden" 0.35 audio 72
create_post "$STUDIO" "EP-structure" 0.1 text "" "" "EP track listing draft:\n\n1. Glass Ocean (intro, 1:30) — ambient pads + reversed guitar\n2. Neon Garden (3:45) — uptempo, main single candidate\n3. Sunrise Protocol (4:12) — the one with the sidechain experiment\n4. Digital Citizen (3:58) — lyrics almost done\n5. Midnight Drift (outro, 2:15) — stripped back, just guitar + delay\n\nTotal runtime ~15:40. Might be too short? But I like the idea of a tight, focused EP rather than padding it out. Quality over quantity."
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

# 8. Add reactions to some posts
EMOJIS=("🔥" "❤️" "👏" "✨" "😍" "🎵" "💪" "🎸")
i=0
for PID in $(docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
  "SELECT id FROM posts WHERE author_id = (SELECT id FROM users WHERE username = '$USERNAME') LIMIT 12;" \
  | tr -d ' ' | grep -v '^$'); do
  for j in $(seq 0 $((i % 3))); do
    E="${EMOJIS[$(( (i + j) % 8 ))]}"
    curl -s "$API" -X POST -H "Content-Type: application/json" -H "$AUTH" \
      -d "{\"query\":\"mutation { toggleReaction(postId:\\\"$PID\\\", emoji:\\\"$E\\\") { id } }\"}" > /dev/null 2>&1
  done
  i=$((i+1))
done
echo "==> Reactions added to $i posts"

# 9. Add reactions from a fan user (other person's reactions)
FAN_EMAIL="fan@test.com"
FAN_USER="fanuser"
curl -s "$API" -X POST -H 'Content-Type: application/json' \
  -d "{\"query\":\"mutation { signup(email:\\\"$FAN_EMAIL\\\", password:\\\"$PASSWORD\\\", username:\\\"$FAN_USER\\\") { token } }\"}" > /dev/null 2>&1

FAN_TOKEN=$(curl -s "$API" -X POST -H 'Content-Type: application/json' \
  -d "{\"query\":\"mutation { login(email:\\\"$FAN_EMAIL\\\", password:\\\"$PASSWORD\\\") { token } }\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['login']['token'])")
FAN_AUTH="Authorization: Bearer $FAN_TOKEN"

i=0
for PID in $(docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
  "SELECT id FROM posts WHERE author_id = (SELECT id FROM users WHERE username = '$USERNAME') LIMIT 15;" \
  | tr -d ' ' | grep -v '^$'); do
  for j in $(seq 0 $((i % 4))); do
    E="${EMOJIS[$(( (i + j + 2) % 8 ))]}"
    curl -s "$API" -X POST -H "Content-Type: application/json" -H "$FAN_AUTH" \
      -d "{\"query\":\"mutation { toggleReaction(postId:\\\"$PID\\\", emoji:\\\"$E\\\") { id } }\"}" > /dev/null 2>&1
  done
  i=$((i+1))
done
echo "==> Fan reactions added to $i posts"

# 10. Create connections (synapses) between posts to form constellations
get_post_id() {
  docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
    "SELECT id FROM posts WHERE title = '$1' AND author_id = (SELECT id FROM users WHERE username = '$USERNAME') LIMIT 1;" \
    | tr -d ' ' | grep -v '^$'
}

create_connection() {
  local SRC="$1" TGT="$2"
  curl -s "$API" -X POST -H "Content-Type: application/json" -H "$AUTH" \
    -d "{\"query\":\"mutation { createConnection(sourceId:\\\"$SRC\\\", targetId:\\\"$TGT\\\", connectionType:reference) { id } }\"}" > /dev/null 2>&1
}

PID_FLAMENCO=$(get_post_id "Flamenco-session")
PID_RASGUEADO=$(get_post_id "New-rasgueado-pattern")
PID_OPEN_MIC=$(get_post_id "Live-at-open-mic")
PID_FLAMENCO_BB=$(get_post_id "Flamenco-x-beatbox")
PID_WIP_SUNRISE=$(get_post_id "WIP-Sunrise-Protocol")
PID_SIDECHAIN=$(get_post_id "Sidechain-experiment")
PID_FINAL_MIX=$(get_post_id "Final-mix-Sunrise")
PID_NEON_GARDEN=$(get_post_id "Sketch-Neon-Garden")
PID_COLLAB=$(get_post_id "Collab-sketch")
PID_GLASS_OCEAN=$(get_post_id "Demo-Glass-Ocean")

# Constellation "Flamenco Journey" — Play + Live cross-track, long distances
create_connection "$PID_FLAMENCO" "$PID_RASGUEADO"
create_connection "$PID_FLAMENCO" "$PID_FLAMENCO_BB"
create_connection "$PID_RASGUEADO" "$PID_OPEN_MIC"

# Constellation "Sunrise Protocol" — Compose + Studio cross-track
create_connection "$PID_WIP_SUNRISE" "$PID_SIDECHAIN"
create_connection "$PID_WIP_SUNRISE" "$PID_FINAL_MIX"
create_connection "$PID_WIP_SUNRISE" "$PID_NEON_GARDEN"

# Unnamed small constellation — Studio only
create_connection "$PID_COLLAB" "$PID_GLASS_OCEAN"

echo "==> 7 connections created (3 constellations)"

# 11. Name two constellations
name_constellation() {
  local PID="$1" NAME="$2"
  curl -s "$API" -X POST -H "Content-Type: application/json" -H "$AUTH" \
    -d "{\"query\":\"mutation { nameConstellation(postId:\\\"$PID\\\", name:\\\"$NAME\\\") { id name } }\"}" > /dev/null 2>&1
}

name_constellation "$PID_FLAMENCO" "Flamenco Journey"
name_constellation "$PID_WIP_SUNRISE" "Sunrise Protocol"

echo "==> 2 constellations named (1 unnamed)"

# 12. Seed discover data (genres, additional artists, tune-in/follow relations)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Running discover seed..."
"$SCRIPT_DIR/seed-discover-data.sh" "${1:-http://localhost:4000/graphql}"

echo "==> Done! Login: $EMAIL / $PASSWORD"
