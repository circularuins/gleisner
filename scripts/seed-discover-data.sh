#!/usr/bin/env bash
# Seed multi-artist data for Discover/Tune In development
# Creates: promoted genres, 3 additional artists (visual, writer, filmmaker), posts, Tune In + Follow relationships
# Prerequisites: backend running, seed-test-data.sh already executed (seeduser + fanuser exist)
# Usage: ./scripts/seed-discover-data.sh [api_url]
set -euo pipefail

API="${1:-http://localhost:4000/graphql}"
PASSWORD="password123"

echo "==> Seeding Discover data at $API"

# ── Helper functions ──

gql() {
  local QUERY="$1"
  local AUTH_HEADER="${2:-}"
  local HEADERS=(-H "Content-Type: application/json")
  [ -n "$AUTH_HEADER" ] && HEADERS+=(-H "Authorization: Bearer $AUTH_HEADER")
  curl -s "$API" -X POST "${HEADERS[@]}" -d "{\"query\":$(echo "$QUERY" | jq -Rs .)}"
}

gql_quiet() {
  gql "$@" > /dev/null 2>&1 || true
}

get_token() {
  local EMAIL="$1" USER="$2"
  local RESULT
  RESULT=$(gql "mutation { signup(email:\"$EMAIL\", password:\"$PASSWORD\", username:\"$USER\") { token } }")
  TOKEN=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['signup']['token'])" 2>/dev/null || true)
  if [ -z "$TOKEN" ]; then
    RESULT=$(gql "mutation { login(email:\"$EMAIL\", password:\"$PASSWORD\") { token } }")
    TOKEN=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['login']['token'])")
  fi
  echo "$TOKEN"
}

register_artist() {
  local TOKEN="$1" AUSERNAME="$2" DNAME="$3" TAGLINE="$4" LOCATION="$5" SINCE="$6"
  gql_quiet "mutation { registerArtist(artistUsername:\"$AUSERNAME\", displayName:\"$DNAME\", tagline:\"$TAGLINE\", location:\"$LOCATION\", activeSince:$SINCE) { id } }" "$TOKEN"
}

create_track() {
  local TOKEN="$1" NAME="$2" COLOR="$3"
  gql_quiet "mutation { createTrack(name:\"$NAME\", color:\"$COLOR\") { id } }" "$TOKEN"
}

get_artist_id() {
  local USERNAME="$1"
  docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
    "SELECT id FROM artists WHERE artist_username = '$USERNAME' LIMIT 1;" \
    | tr -d ' ' | grep -v '^$'
}

get_track_id() {
  local ARTIST_USERNAME="$1" TRACK_NAME="$2"
  docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
    "SELECT t.id FROM tracks t JOIN artists a ON t.artist_id = a.id WHERE a.artist_username = '$ARTIST_USERNAME' AND t.name = '$TRACK_NAME' LIMIT 1;" \
    | tr -d ' ' | grep -v '^$'
}

create_post() {
  local TOKEN="$1" TID="$2" TITLE="$3" IMP="$4" MTYPE="$5" DUR="${6:-}" URL="${7:-}" BODY="${8:-}"
  local EXTRA=""
  [ -n "$DUR" ] && EXTRA="$EXTRA, duration:$DUR"
  [ -n "$URL" ] && EXTRA="$EXTRA, mediaUrl:\"$URL\""
  [ -z "$BODY" ] && BODY="Content for $TITLE"
  BODY=$(printf '%s' "$BODY" | jq -Rs . | sed 's/^"//;s/"$//')
  gql_quiet "mutation { createPost(trackId:\"$TID\", title:\"$TITLE\", body:\"$BODY\", mediaType:$MTYPE, importance:$IMP$EXTRA) { id } }" "$TOKEN"
  sleep 0.2
}

# ── 1. Seed promoted genres ──

echo "==> Seeding genres..."
docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
INSERT INTO genres (name, normalized_name, is_promoted) VALUES
  ('Rock', 'rock', true),
  ('Pop', 'pop', true),
  ('Electronic', 'electronic', true),
  ('Hip-Hop', 'hip-hop', true),
  ('Jazz', 'jazz', true),
  ('R&B', 'r&b', true),
  ('Classical', 'classical', true),
  ('Folk', 'folk', true),
  ('Flamenco', 'flamenco', true),
  ('Latin', 'latin', true),
  ('Ambient', 'ambient', true),
  ('Digital Art', 'digital art', true),
  ('Photography', 'photography', true),
  ('Illustration', 'illustration', true),
  ('Poetry', 'poetry', true),
  ('Fiction', 'fiction', true),
  ('Non-Fiction', 'non-fiction', true),
  ('Documentary', 'documentary', true),
  ('Short Film', 'short film', true),
  ('Music Video', 'music video', true)
ON CONFLICT (normalized_name) DO NOTHING;
"
echo "==> Genres seeded"

# ── 2. Assign genres to existing seeduser ──

SEED_TOKEN=$(get_token "seed@test.com" "seeduser")
SEED_ARTIST_ID=$(get_artist_id "seeduser")

get_genre_id() {
  docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
    "SELECT id FROM genres WHERE normalized_name = '$1' LIMIT 1;" \
    | tr -d ' ' | grep -v '^$'
}

GENRE_FLAMENCO=$(get_genre_id "flamenco")
GENRE_JAZZ=$(get_genre_id "jazz")
GENRE_LATIN=$(get_genre_id "latin")

docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
INSERT INTO artist_genres (artist_id, genre_id, position) VALUES
  ('$SEED_ARTIST_ID', '$GENRE_FLAMENCO', 0),
  ('$SEED_ARTIST_ID', '$GENRE_JAZZ', 1),
  ('$SEED_ARTIST_ID', '$GENRE_LATIN', 2)
ON CONFLICT DO NOTHING;
"
echo "==> seeduser genres assigned (Flamenco, Jazz, Latin)"

# ── 3. Create Artist: ayumi_visual (Visual Artist) ──

echo "==> Creating ayumi_visual..."
AYUMI_TOKEN=$(get_token "ayumi@test.com" "ayumi")
register_artist "$AYUMI_TOKEN" "ayumi_visual" "Ayumi Tanaka" "Colors speak louder than words" "Tokyo, Japan" 2018

AYUMI_ARTIST_ID=$(get_artist_id "ayumi_visual")

# Update bio via direct DB (bio not in registerArtist args)
docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
UPDATE artists SET bio = 'Digital artist exploring the intersection of traditional Japanese aesthetics and generative algorithms. My work bridges analog brushwork and computational creativity.' WHERE id = '$AYUMI_ARTIST_ID';
"

# Tracks: Visual Artist template (Works, Process, Thoughts)
create_track "$AYUMI_TOKEN" "Works" "#e11d48"
create_track "$AYUMI_TOKEN" "Process" "#7c3aed"
create_track "$AYUMI_TOKEN" "Thoughts" "#0ea5e9"

# Genres
GENRE_DIGITAL_ART=$(get_genre_id "digital art")
GENRE_ILLUSTRATION=$(get_genre_id "illustration")
GENRE_PHOTOGRAPHY=$(get_genre_id "photography")

docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
INSERT INTO artist_genres (artist_id, genre_id, position) VALUES
  ('$AYUMI_ARTIST_ID', '$GENRE_DIGITAL_ART', 0),
  ('$AYUMI_ARTIST_ID', '$GENRE_ILLUSTRATION', 1),
  ('$AYUMI_ARTIST_ID', '$GENRE_PHOTOGRAPHY', 2)
ON CONFLICT DO NOTHING;
"

# Posts
AYUMI_WORKS=$(get_track_id "ayumi_visual" "Works")
AYUMI_PROCESS=$(get_track_id "ayumi_visual" "Process")
AYUMI_THOUGHTS=$(get_track_id "ayumi_visual" "Thoughts")

create_post "$AYUMI_TOKEN" "$AYUMI_WORKS" "Neon-Koi-Series-IV" 1.0 image "" "" "Fourth piece in the Neon Koi series. This one uses a reaction-diffusion algorithm to grow organic patterns from a hand-drawn koi silhouette. The palette is inspired by Utagawa Kuniyoshi's woodblock prints but shifted into cyberpunk territory. 4000x4000px, rendered over 72 hours."
create_post "$AYUMI_TOKEN" "$AYUMI_WORKS" "Generative-Sakura" 0.85 image "" "" "Spring collection piece. 10,000 procedurally placed cherry blossom petals following a custom physics simulation for wind and gravity. Each petal's color is sampled from a photograph I took at Ueno Park last April."
create_post "$AYUMI_TOKEN" "$AYUMI_WORKS" "Digital-Sumi-Study-12" 0.6 image "" "" "Continuing my digital sumi-e studies. This brush engine simulates ink absorption, bristle spread, and paper texture. The goal is not to replicate physical sumi-e but to find what's uniquely possible when you combine the discipline of calligraphic gesture with computational control."
create_post "$AYUMI_TOKEN" "$AYUMI_WORKS" "Commission-Album-Cover" 0.9 image "" "" "Album cover commission for an ambient producer. They wanted something that felt like staring into deep water at night. Layered voronoi cells with depth-based color shifts. Really happy with how the bio-luminescence turned out."
create_post "$AYUMI_TOKEN" "$AYUMI_WORKS" "Pixel-Drift-001" 0.4 image "" "" "Experimenting with pixel sorting algorithms on photographs. This one started as a photo of Shibuya crossing, then I applied vertical pixel sorting based on luminance values. The result feels like the city melting in summer heat."
create_post "$AYUMI_TOKEN" "$AYUMI_WORKS" "Ink-and-Code-Triptych" 0.95 image "" "" "My largest piece to date: three panels, each 6000x2000px. Left panel: pure generative. Center: hand-drawn ink overlay on generative base. Right: photograph composited with both. The triptych explores the spectrum from algorithm to human gesture."

create_post "$AYUMI_TOKEN" "$AYUMI_PROCESS" "Brush-engine-v3-demo" 0.5 video 180 "" "Recorded my screen while testing brush engine v3. The new pressure curve mapping makes a huge difference for ink spread. Watch how the stroke tapers — that's 6 months of tweaking bezier curves for pressure response."
create_post "$AYUMI_TOKEN" "$AYUMI_PROCESS" "Color-palette-research" 0.2 image "" "" "Spent the afternoon at the Nezu Museum studying Rinpa school color combinations. Photographed 14 screens and extracted dominant palettes using k-means clustering. The gold-to-indigo transitions in Korin's work are mathematically fascinating."
create_post "$AYUMI_TOKEN" "$AYUMI_PROCESS" "Reaction-diffusion-params" 0.3 text "" "" "Notes on reaction-diffusion parameters for organic growth patterns:\n\nFeed rate: 0.055 (lower = more coral-like)\nKill rate: 0.062 (sweet spot for branching)\nDiffusion A: 1.0 / B: 0.5\nTime step: 1.0\n\nThe key insight: adding Perlin noise to the feed rate creates localized variation that looks much more natural than uniform parameters. Need to try anisotropic diffusion next."
create_post "$AYUMI_TOKEN" "$AYUMI_PROCESS" "Studio-timelapse" 0.7 video 240 "" "Full timelapse of creating Neon Koi IV from blank canvas to final render. You can see the hand-drawn phase, the algorithm growth phase, and the manual color correction at the end. Total working time: about 40 hours compressed into 4 minutes."

create_post "$AYUMI_TOKEN" "$AYUMI_THOUGHTS" "Why-I-code-my-art" 0.65 text "" "" "People ask me why I don't just use Photoshop or Procreate. The answer: I want to have a conversation with the algorithm. When I write code that generates visual output, there's a feedback loop between my aesthetic intention and the system's emergent behavior. Sometimes the algorithm surprises me — it creates something I couldn't have imagined. That moment of surprise is why I code."
create_post "$AYUMI_TOKEN" "$AYUMI_THOUGHTS" "Gallery-show-recap" 0.5 image "" "" "Quick recap from the group show at Gallery Koganei. Showed Neon Koi I-III as large-format prints (120x120cm). The physical scale completely changes how the generative details read. Tiny algorithmic artifacts that look like noise on screen become intricate textures at print scale."
create_post "$AYUMI_TOKEN" "$AYUMI_THOUGHTS" "Inspiration-board-march" 0.1 image "" "" "Monthly inspiration board. This month: Vera Molnar's early plotter drawings, teamLab's latest installation at Azabudai Hills, a fascinating paper on morphogenesis simulation, and the way morning light hits the concrete walls of my apartment."

echo "==> ayumi_visual: 13 posts created"

# ── 4. Create Artist: takeshi_pen (Writer) ──

echo "==> Creating takeshi_pen..."
TAKESHI_TOKEN=$(get_token "takeshi@test.com" "takeshi")
register_artist "$TAKESHI_TOKEN" "takeshi_pen" "Takeshi Mori" "Stories from the spaces between languages" "Osaka, Japan" 2015

TAKESHI_ARTIST_ID=$(get_artist_id "takeshi_pen")

docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
UPDATE artists SET bio = 'Bilingual writer working in Japanese and English. Published two poetry collections and one novel. Currently exploring how digital platforms change the relationship between writer and reader.' WHERE id = '$TAKESHI_ARTIST_ID';
"

# Tracks: Writer template (Writing, Notes, Life)
create_track "$TAKESHI_TOKEN" "Writing" "#f59e0b"
create_track "$TAKESHI_TOKEN" "Notes" "#6366f1"
create_track "$TAKESHI_TOKEN" "Life" "#10b981"

# Genres
GENRE_POETRY=$(get_genre_id "poetry")
GENRE_FICTION=$(get_genre_id "fiction")
GENRE_NONFICTION=$(get_genre_id "non-fiction")

docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
INSERT INTO artist_genres (artist_id, genre_id, position) VALUES
  ('$TAKESHI_ARTIST_ID', '$GENRE_POETRY', 0),
  ('$TAKESHI_ARTIST_ID', '$GENRE_FICTION', 1),
  ('$TAKESHI_ARTIST_ID', '$GENRE_NONFICTION', 2)
ON CONFLICT DO NOTHING;
"

TAKESHI_WRITING=$(get_track_id "takeshi_pen" "Writing")
TAKESHI_NOTES=$(get_track_id "takeshi_pen" "Notes")
TAKESHI_LIFE=$(get_track_id "takeshi_pen" "Life")

create_post "$TAKESHI_TOKEN" "$TAKESHI_WRITING" "Poem-Osaka-Rain" 1.0 text "" "" "Osaka Rain\n\nThe vending machines hum a chord\nno composer intended.\nUmbrella spokes trace constellations\non the wet pavement of Shinsaibashi.\n\nI count the languages\nspoken by a single puddle:\nJapanese from the salary man's phone,\nKorean from the tourist's laughter,\nEnglish from the sign that says\nWET FLOOR in letters\nthat don't know they're poetry.\n\nThe rain doesn't translate.\nIt just falls."
create_post "$TAKESHI_TOKEN" "$TAKESHI_WRITING" "Flash-Fiction-Platform-9" 0.85 text "" "" "Platform 9\n\nThe train arrives at 7:43 every morning. I know because I've been counting for six years. Not the trains — the woman who reads standing up, one hand on the strap, the other holding a book whose cover I can never quite see.\n\nToday the platform is empty. Not empty like Sunday empty. Empty like someone erased it.\n\nI check my phone: 7:42. I am one minute too early for a train that exists only in the agreement between thousands of commuters that it should.\n\nAt 7:43, the track hums.\nAt 7:44, I realize I was the last person still believing."
create_post "$TAKESHI_TOKEN" "$TAKESHI_WRITING" "Poem-Between-Languages" 0.7 text "" "" "Between Languages\n\nThere is a word in Japanese — 木漏れ日 (komorebi)\nsunlight filtering through leaves.\nEnglish doesn't have it\nso I carry it like a stone in my pocket,\nsmooth from years of touching.\n\nThere is a word in English — 'bittersweet'\nthat Japanese approximates but never catches.\nほろ苦い comes close\nbut misses the sweetness by a syllable.\n\nI live in the gap between these words.\nIt's drafty. But the light is good."
create_post "$TAKESHI_TOKEN" "$TAKESHI_WRITING" "Short-Story-Draft-Emigrant" 0.9 text "" "" "Working title: The Emigrant's Dictionary\n\nOpening paragraph draft:\n\nMy grandmother kept a dictionary by her bed — not for reading, but for pressing flowers. Between 'absence' and 'abstract,' a dried chrysanthemum. Between 'home' and 'honest,' a maple leaf from a park she visited once in 1962. I inherited the dictionary when she died. The flowers had stained the definitions, so that 'absence' now smelled faintly of autumn, and 'home' had a red vein running through it that looked like a river on a map."
create_post "$TAKESHI_TOKEN" "$TAKESHI_WRITING" "Poem-Digital-Impermanence" 0.55 text "" "" "Digital Impermanence\n\nI wrote a poem on a platform that no longer exists.\nThe servers were decommissioned in 2019.\nMy words became heat, then nothing.\n\nBut I remember the first line:\n'The best things I've written\nlive in places that forgot them.'\n\nIs this poem the same poem?\nIs a memory of a fire still warm?"
create_post "$TAKESHI_TOKEN" "$TAKESHI_WRITING" "Haiku-Set-Spring" 0.3 text "" "" "Spring haiku set:\n\nmorning commute —\nthe cherry tree doesn't care\nabout my deadline\n\nconbini coffee\nsteam rises through fluorescent light\nalmost beautiful\n\nrain on the window\nI rewrite the same sentence\nfor the seventh time"

create_post "$TAKESHI_TOKEN" "$TAKESHI_NOTES" "On-writing-daily" 0.4 text "" "" "Reading note: In 'Bird by Bird,' Anne Lamott says to write shitty first drafts. I've been doing that for 10 years and can confirm: the shitty drafts don't get less shitty, but your tolerance for sitting with the shittiness increases. That's the real skill — not writing well, but enduring writing badly long enough that something good accidentally happens."
create_post "$TAKESHI_TOKEN" "$TAKESHI_NOTES" "Translation-dilemma" 0.6 text "" "" "Translation problem I can't solve: In my short story, a character says '仕方がない' (shikata ga nai). The standard translation is 'it can't be helped' but that sounds passive and resigned in English. In Japanese, it carries a whole philosophy of acceptance — not giving up but acknowledging reality with dignity. I've tried 'that's how it is' and 'so it goes' (Vonnegut reference too heavy?) and 'what can you do' but nothing captures the weight. Maybe some concepts just have to remain in their original language."
create_post "$TAKESHI_TOKEN" "$TAKESHI_NOTES" "Reading-list-spring" 0.15 text "" "" "Spring reading stack:\n- 'Convenience Store Woman' by Sayaka Murata (reread)\n- 'Klara and the Sun' by Ishiguro\n- 'The Memory Police' by Yoko Ogawa\n- '言の葉の庭' screenplay by Makoto Shinkai\n\nTheme: characters who exist slightly outside the world everyone else agrees is real."

create_post "$TAKESHI_TOKEN" "$TAKESHI_LIFE" "Cafe-writing-spot" 0.05 image "" "" "Found a new writing cafe in Nakazakicho. They have a rule: no phone calls, no meetings, no music without headphones. Just the sound of typing and coffee machines. Paradise."
create_post "$TAKESHI_TOKEN" "$TAKESHI_LIFE" "Book-launch-photo" 0.75 image "" "" "Poetry collection launch at Standard Bookstore. 40 people came, which for poetry in Osaka is practically a stadium concert. Read five pieces including the new bilingual set. Someone cried at 'Between Languages.' That's all you can ask for."
create_post "$TAKESHI_TOKEN" "$TAKESHI_LIFE" "Morning-walk-words" 0.02 text "" "" "Walked along the Okawa river this morning. The willows are getting their spring green. Found a word I didn't know I was looking for: 'lambent' — softly bright or radiant. That's exactly how the water looked at 6am."

echo "==> takeshi_pen: 12 posts created"

# ── 5. Create Artist: mika_films (Filmmaker) ──

echo "==> Creating mika_films..."
MIKA_TOKEN=$(get_token "mika@test.com" "mika")
register_artist "$MIKA_TOKEN" "mika_films" "Mika Hayashi" "Capturing stories the world forgot to tell" "Kyoto, Japan" 2020

MIKA_ARTIST_ID=$(get_artist_id "mika_films")

docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
UPDATE artists SET bio = 'Independent filmmaker based in Kyoto. Focused on short documentaries about craftspeople and disappearing traditions. Shooting on vintage lenses because perfection is boring.' WHERE id = '$MIKA_ARTIST_ID';
"

# Tracks: Filmmaker template (Films, BTS, Stills)
create_track "$MIKA_TOKEN" "Films" "#dc2626"
create_track "$MIKA_TOKEN" "BTS" "#ea580c"
create_track "$MIKA_TOKEN" "Stills" "#8b5cf6"

# Genres
GENRE_DOCUMENTARY=$(get_genre_id "documentary")
GENRE_MUSICVIDEO=$(get_genre_id "music video")
GENRE_PHOTOGRAPHY2=$(get_genre_id "photography")

docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
INSERT INTO artist_genres (artist_id, genre_id, position) VALUES
  ('$MIKA_ARTIST_ID', '$GENRE_DOCUMENTARY', 0),
  ('$MIKA_ARTIST_ID', '$GENRE_MUSICVIDEO', 1),
  ('$MIKA_ARTIST_ID', '$GENRE_PHOTOGRAPHY2', 2)
ON CONFLICT DO NOTHING;
"

MIKA_FILMS=$(get_track_id "mika_films" "Films")
MIKA_BTS=$(get_track_id "mika_films" "BTS")
MIKA_STILLS=$(get_track_id "mika_films" "Stills")

create_post "$MIKA_TOKEN" "$MIKA_FILMS" "The-Last-Indigo-Dyer" 1.0 video 780 "" "Full short documentary (13 min). Morita-san is 82 years old and the last person in Kyoto still dyeing fabric with natural indigo using the traditional sukumo fermentation method. The process takes 100 days from dried leaves to usable dye. She says the vat is alive — you have to talk to it, feed it, keep it warm. When she retires, the vat dies with her."
create_post "$MIKA_TOKEN" "$MIKA_FILMS" "Bamboo-and-Silence" 0.9 video 420 "" "Short film (7 min): A day in the life of a bamboo craftsman in Arashiyama. No narration, no music — just the sounds of splitting bamboo, the rasp of a knife, and his breathing. I wanted to make a film about attention itself. What does it look like when someone is fully present with their material?"
create_post "$MIKA_TOKEN" "$MIKA_FILMS" "MV-Digital-Citizen" 0.85 video 238 "" "Music video for Seed Artist's 'Digital Citizen' (collaboration). Shot on Super 8 film stock transferred to digital. The concept: a musician walking through increasingly glitched urban environments. We used practical effects — projectors, prisms, and mylar sheets — no CGI. The lo-fi texture of Super 8 makes the digital artifacts feel organic."
create_post "$MIKA_TOKEN" "$MIKA_FILMS" "Paper-Crane-Teaser" 0.7 video 60 "" "30-second teaser for my next documentary about Sasaki Sadako and the 1,000 cranes tradition. Interviewing atomic bomb survivors, origami masters, and schoolchildren who still fold cranes at the Hiroshima memorial. Production starts next month."

create_post "$MIKA_TOKEN" "$MIKA_BTS" "Indigo-shoot-day-3" 0.4 video 120 "" "BTS from The Last Indigo Dyer shoot. The hardest part was lighting the workshop — Morita-san works with natural light only, and the indigo vat room has one small window. I ended up bouncing a single LED panel off the ceiling at 10% power. You can see the before/after in this clip."
create_post "$MIKA_TOKEN" "$MIKA_BTS" "Lens-comparison-test" 0.3 video 90 "" "Shot the same scene with three lenses: Helios 44-2 (vintage Soviet, swirly bokeh), Canon FD 50mm 1.4 (80s warmth), and a modern Sigma 50mm Art. For documentary work, the Helios wins every time. The optical imperfections add a humanity that modern lenses polish away."
create_post "$MIKA_TOKEN" "$MIKA_BTS" "Sound-recording-tips" 0.5 text "" "" "Things I learned about sound recording the hard way:\n\n1. Always record 60 seconds of room tone. You WILL need it in editing.\n2. Lapel mics pick up stomach growls. Schedule around meals.\n3. The most important sound in a documentary is often the one you didn't plan to record.\n4. Wind is not your friend. Buy a dead cat (the microphone accessory, obviously).\n5. The Zoom H6 has saved more films than any camera ever made."
create_post "$MIKA_TOKEN" "$MIKA_BTS" "Color-grading-process" 0.35 image "" "" "Color grading breakdown for Bamboo and Silence. Top: raw footage. Middle: after primary correction (lifted shadows, pulled highlights). Bottom: final grade with the teal-and-orange split toning desaturated to about 30%. The goal was a look that feels timeless — not vintage, not modern."

create_post "$MIKA_TOKEN" "$MIKA_STILLS" "Kyoto-Machiya-Dawn" 0.8 image "" "" "Shot at 5:30am in Gion. The light at this hour turns the wooden machiya facades into abstract paintings. Helios 44-2 wide open at f/2, natural light only. The swirly bokeh in the lantern reflections was a happy accident."
create_post "$MIKA_TOKEN" "$MIKA_STILLS" "Workshop-Hands" 0.65 image "" "" "Morita-san's hands after 60 years of indigo work. The dye has permanently stained her fingertips blue. She says it's the mark of someone who has given their life to one thing. I asked if she ever tried to wash it off. She laughed."
create_post "$MIKA_TOKEN" "$MIKA_STILLS" "Arashiyama-Bamboo-Light" 0.45 image "" "" "The bamboo grove at Arashiyama, shot during the 15 minutes when the sun is at exactly the right angle to create these parallel light shafts. Most tourists are still asleep. It's just me, the bamboo, and a couple of joggers."
create_post "$MIKA_TOKEN" "$MIKA_STILLS" "Super8-Frame-Grabs" 0.55 image "" "" "Selected frame grabs from the Digital Citizen music video shoot. Super 8 film at 18fps gives you this dreamy motion blur that's impossible to replicate digitally. Each frame is a little painting. I sometimes like the individual frames more than the final edit."

echo "==> mika_films: 12 posts created"

# ── 6. Create additional fan user ──

echo "==> Creating sakura_fan..."
SAKURA_TOKEN=$(get_token "sakura@test.com" "sakura_fan")
echo "==> sakura_fan created"

# Also get fanuser token
FAN_TOKEN=$(get_token "fan@test.com" "fanuser")

# ── 7. Spread dates across 2 weeks for new artists ──

echo "==> Spreading dates..."
docker exec gleisner-db psql -U gleisner -d gleisner -q -c "
WITH ranked AS (
  SELECT p.id, p.title, a.artist_username,
    ROW_NUMBER() OVER (PARTITION BY a.artist_username ORDER BY p.created_at) as rn,
    COUNT(*) OVER (PARTITION BY a.artist_username) as total
  FROM posts p
  JOIN tracks t ON p.track_id = t.id
  JOIN artists a ON t.artist_id = a.id
  WHERE a.artist_username IN ('ayumi_visual', 'takeshi_pen', 'mika_films')
)
UPDATE posts SET created_at = now() - (
  (ranked.rn::float / ranked.total * 14) || ' days'
)::interval - (
  (random() * 12) || ' hours'
)::interval
FROM ranked WHERE posts.id = ranked.id;
"
echo "==> Dates spread across 2 weeks"

# ── 8. Set up Tune In relationships ──

echo "==> Setting up Tune In relationships..."

# fanuser tunes in to seeduser (already follows via reactions), ayumi, mika
gql_quiet "mutation { toggleTuneIn(artistId:\"$SEED_ARTIST_ID\") { createdAt } }" "$FAN_TOKEN"
gql_quiet "mutation { toggleTuneIn(artistId:\"$AYUMI_ARTIST_ID\") { createdAt } }" "$FAN_TOKEN"
gql_quiet "mutation { toggleTuneIn(artistId:\"$MIKA_ARTIST_ID\") { createdAt } }" "$FAN_TOKEN"

# sakura_fan tunes in to all 4 artists
gql_quiet "mutation { toggleTuneIn(artistId:\"$SEED_ARTIST_ID\") { createdAt } }" "$SAKURA_TOKEN"
gql_quiet "mutation { toggleTuneIn(artistId:\"$AYUMI_ARTIST_ID\") { createdAt } }" "$SAKURA_TOKEN"
gql_quiet "mutation { toggleTuneIn(artistId:\"$TAKESHI_ARTIST_ID\") { createdAt } }" "$SAKURA_TOKEN"
gql_quiet "mutation { toggleTuneIn(artistId:\"$MIKA_ARTIST_ID\") { createdAt } }" "$SAKURA_TOKEN"

# seeduser (as a fan) tunes in to ayumi and mika
gql_quiet "mutation { toggleTuneIn(artistId:\"$AYUMI_ARTIST_ID\") { createdAt } }" "$SEED_TOKEN"
gql_quiet "mutation { toggleTuneIn(artistId:\"$MIKA_ARTIST_ID\") { createdAt } }" "$SEED_TOKEN"

echo "==> Tune In relationships created"

# ── 9. Set up Follow relationships ──

echo "==> Setting up Follow relationships..."

# Get user IDs
get_user_id() {
  docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
    "SELECT id FROM users WHERE username = '$1' LIMIT 1;" \
    | tr -d ' ' | grep -v '^$'
}

SEED_USER_ID=$(get_user_id "seeduser")
FAN_USER_ID=$(get_user_id "fanuser")
AYUMI_USER_ID=$(get_user_id "ayumi")
TAKESHI_USER_ID=$(get_user_id "takeshi")
MIKA_USER_ID=$(get_user_id "mika")
SAKURA_USER_ID=$(get_user_id "sakura_fan")

# Mutual follows: seeduser <-> ayumi, seeduser <-> mika (artist connections)
gql_quiet "mutation { toggleFollow(userId:\"$AYUMI_USER_ID\") { createdAt } }" "$SEED_TOKEN"
gql_quiet "mutation { toggleFollow(userId:\"$SEED_USER_ID\") { createdAt } }" "$AYUMI_TOKEN"
gql_quiet "mutation { toggleFollow(userId:\"$MIKA_USER_ID\") { createdAt } }" "$SEED_TOKEN"
gql_quiet "mutation { toggleFollow(userId:\"$SEED_USER_ID\") { createdAt } }" "$MIKA_TOKEN"

# fanuser follows seeduser and ayumi (one-way)
gql_quiet "mutation { toggleFollow(userId:\"$SEED_USER_ID\") { createdAt } }" "$FAN_TOKEN"
gql_quiet "mutation { toggleFollow(userId:\"$AYUMI_USER_ID\") { createdAt } }" "$FAN_TOKEN"

# sakura_fan follows seeduser (one-way)
gql_quiet "mutation { toggleFollow(userId:\"$SEED_USER_ID\") { createdAt } }" "$SAKURA_TOKEN"

echo "==> Follow relationships created"

# ── 10. Add reactions from fans to new artists' posts ──

echo "==> Adding reactions to new artists' posts..."
EMOJIS=("🔥" "❤️" "👏" "✨" "😍" "🎵" "💪" "🎸" "📸" "🎬" "✍️" "🖌️")

add_reactions_to_artist() {
  local ARTIST_USER="$1" REACTOR_TOKEN="$2" COUNT="${3:-8}"
  local i=0
  for PID in $(docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
    "SELECT p.id FROM posts p JOIN tracks t ON p.track_id = t.id JOIN artists a ON t.artist_id = a.id WHERE a.artist_username = '$ARTIST_USER' ORDER BY p.importance DESC LIMIT $COUNT;" \
    | tr -d ' ' | grep -v '^$'); do
    for j in $(seq 0 $((i % 3))); do
      local E="${EMOJIS[$(( (i + j) % ${#EMOJIS[@]} ))]}"
      gql_quiet "mutation { toggleReaction(postId:\"$PID\", emoji:\"$E\") { id } }" "$REACTOR_TOKEN"
    done
    i=$((i+1))
  done
}

# fanuser reacts to ayumi's and mika's posts
add_reactions_to_artist "ayumi_visual" "$FAN_TOKEN" 8
add_reactions_to_artist "mika_films" "$FAN_TOKEN" 6

# sakura_fan reacts to all artists' posts
add_reactions_to_artist "ayumi_visual" "$SAKURA_TOKEN" 10
add_reactions_to_artist "takeshi_pen" "$SAKURA_TOKEN" 8
add_reactions_to_artist "mika_films" "$SAKURA_TOKEN" 8
add_reactions_to_artist "seeduser" "$SAKURA_TOKEN" 6

# seeduser reacts to ayumi's and mika's posts (as a fan)
add_reactions_to_artist "ayumi_visual" "$SEED_TOKEN" 5
add_reactions_to_artist "mika_films" "$SEED_TOKEN" 4

echo "==> Reactions added"

# ── 11. Create cross-artist connections (MV collaboration) ──

echo "==> Creating cross-references..."

# mika's MV-Digital-Citizen references seeduser's Lyrics-Digital-Citizen (collaboration)
MV_PID=$(docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
  "SELECT p.id FROM posts p JOIN tracks t ON p.track_id = t.id JOIN artists a ON t.artist_id = a.id WHERE a.artist_username = 'mika_films' AND p.title = 'MV-Digital-Citizen' LIMIT 1;" \
  | tr -d ' ' | grep -v '^$')
LYRICS_PID=$(docker exec gleisner-db psql -U gleisner -d gleisner -t -c \
  "SELECT p.id FROM posts p JOIN tracks t ON p.track_id = t.id JOIN artists a ON t.artist_id = a.id WHERE a.artist_username = 'seeduser' AND p.title = 'Lyrics-Digital-Citizen' LIMIT 1;" \
  | tr -d ' ' | grep -v '^$')

if [ -n "$MV_PID" ] && [ -n "$LYRICS_PID" ]; then
  gql_quiet "mutation { createConnection(sourceId:\"$MV_PID\", targetId:\"$LYRICS_PID\", connectionType:reference) { id } }" "$MIKA_TOKEN"
  echo "==> Cross-artist connection created (MV -> Lyrics)"
fi

echo ""
echo "==> Discover seed data complete!"
echo "    Artists: seeduser (Musician), ayumi_visual (Visual), takeshi_pen (Writer), mika_films (Filmmaker)"
echo "    Fans: fanuser, sakura_fan"
echo "    Genres: 20 promoted genres"
echo "    Login credentials: <name>@test.com / password123"
echo "    Usernames: seeduser, ayumi, takeshi, mika, fanuser, sakura_fan"
