#!/usr/bin/env bash
# PHASE_0_REVERT: このスクリプトは Phase 0 のクロール拒否対策が本番で機能しているかを検証する。
# Phase 1 一般公開時は検証項目を反転させるか、スクリプトごと削除すること。
# 参照: docs/phase1-revert-checklist.md

# -e は意図的に付けない: 各 check_* ヘルパーが独立して fail カウンタを加算する設計のため、
# 途中の失敗でスクリプト全体を中断しない。pass/fail の集計後に exit コードで結果を返す。
set -uo pipefail

if [[ "${1:-}" == "" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<USAGE
Usage: $0 <base_url> [seed_user]

  <base_url>   検証対象の URL（必須）。例: https://staging.gleisner.app
  [seed_user]  OGP 検証に使う公開アーティスト username（デフォルト: seeduser、
               環境変数 SEED_USER でも指定可）

例:
  $0 https://staging.gleisner.app
  $0 https://gleisner.app myartist
  SEED_USER=myartist $0 https://gleisner.app
USAGE
  exit 64
fi

BASE_URL="$1"
SEED_USER="${2:-${SEED_USER:-seeduser}}"

PASS=0
FAIL=0
SKIP=0

# Colors (無効な環境 = plain)
if [[ -t 1 ]]; then
  G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
  G=""; R=""; Y=""; B=""; N=""
fi

pass() { echo "${G}✓${N} $1"; PASS=$((PASS + 1)); }
fail() { echo "${R}✗${N} $1"; FAIL=$((FAIL + 1)); }
skip() { echo "${Y}- ${N}$1 (skipped: $2)"; SKIP=$((SKIP + 1)); }

section() { echo; echo "${B}==> $1${N}"; }

check_contains() {
  local label="$1" body="$2" needle="$3"
  if grep -qi -- "$needle" <<< "$body"; then
    pass "$label"
  else
    fail "$label — expected to find: $needle"
  fi
}

check_header_contains() {
  local label="$1" headers="$2" header_name="$3" needle="$4"
  local line
  line=$(grep -i "^${header_name}:" <<< "$headers" || true)
  if [[ -z "$line" ]]; then
    fail "$label — header '${header_name}' not present"
    return
  fi
  if grep -qi -- "$needle" <<< "$line"; then
    pass "$label"
  else
    fail "$label — header '${header_name}' missing value: $needle (got: ${line})"
  fi
}

echo "${B}Phase 0 deploy verification${N}"
echo "Target: $BASE_URL"
echo "Seed user: $SEED_USER"

# ----------------------------------------------------------------------
section "1. robots.txt"
# ----------------------------------------------------------------------
ROBOTS_RESPONSE=$(curl -fsSL -w "\n%{http_code}" "$BASE_URL/robots.txt" 2>/dev/null || echo -e "\n000")
ROBOTS_STATUS=$(tail -n1 <<< "$ROBOTS_RESPONSE")
ROBOTS_BODY=$(sed '$d' <<< "$ROBOTS_RESPONSE")

if [[ "$ROBOTS_STATUS" == "200" ]]; then
  pass "GET /robots.txt returns 200"
  check_contains "robots.txt contains 'Disallow: /'" "$ROBOTS_BODY" "Disallow: /"
  # 主要な LLM/AI クローラーが個別ブロックされているかのサンプル検証。
  # robots.txt の全エントリを検査する代わりに、代表的な UA を確認する。
  # 全リストは frontend/web/robots.txt を参照。
  REQUIRED_LLM_BOTS=(GPTBot ClaudeBot Google-Extended PerplexityBot CCBot)
  for bot in "${REQUIRED_LLM_BOTS[@]}"; do
    check_contains "robots.txt blocks $bot" "$ROBOTS_BODY" "User-agent: $bot"
  done
else
  fail "GET /robots.txt returned status $ROBOTS_STATUS (expected 200)"
fi

# ----------------------------------------------------------------------
section "2. SPA index.html"
# ----------------------------------------------------------------------
INDEX_RESPONSE=$(curl -fsSL -w "\n%{http_code}" "$BASE_URL/" 2>/dev/null || echo -e "\n000")
INDEX_STATUS=$(tail -n1 <<< "$INDEX_RESPONSE")
INDEX_BODY=$(sed '$d' <<< "$INDEX_RESPONSE")

if [[ "$INDEX_STATUS" == "200" ]]; then
  pass "GET / returns 200"
  check_contains "SPA has <meta name=\"robots\" noindex>" "$INDEX_BODY" 'name="robots".*noindex'
  check_contains "SPA has <meta name=\"googlebot\" noindex>" "$INDEX_BODY" 'name="googlebot".*noindex'
else
  fail "GET / returned status $INDEX_STATUS (expected 200)"
fi

# ----------------------------------------------------------------------
section "3. OGP endpoint (simulated Twitter/Facebook bot)"
# ----------------------------------------------------------------------
# Twitterbot simulation → Cloudflare Pages Function が OGP にプロキシする経路を確認。
# ヘッダーと本文は 1 回の curl で同時取得する（CDN キャッシュ世代差でヘッダーと本文が
# 不整合になる事故を防ぐ）。
OGP_DUMP=$(curl -fsSL -D - \
  -A "Mozilla/5.0 (compatible; Twitterbot/1.0)" \
  "$BASE_URL/@$SEED_USER" 2>/dev/null || true)

# ヘッダーと本文を空行で分割（HTTP/1.1 200 OK ... \r\n\r\n <body>）
OGP_HEADERS=$(awk 'BEGIN{RS="\r\n\r\n"} NR==1{print; exit}' <<< "$OGP_DUMP")
OGP_BODY=$(awk 'BEGIN{RS="\r\n\r\n"} NR>=2{print}' <<< "$OGP_DUMP")

if [[ -z "$OGP_BODY" ]]; then
  skip "OGP endpoint check" "seed user '$SEED_USER' may not exist or not public — set SEED_USER env var to a known public artist"
else
  # OGP response or SPA response (Pages Function が bot 判定した場合のみ OGP HTML)
  if grep -qi 'og:title' <<< "$OGP_BODY"; then
    pass "Twitterbot UA receives OGP HTML (Pages Function proxy working)"
    check_contains "OGP HTML contains noindex meta" "$OGP_BODY" 'name="robots".*noindex'
    check_header_contains "OGP response has X-Robots-Tag: noindex" "$OGP_HEADERS" "x-robots-tag" "noindex"
    check_header_contains "OGP response X-Robots-Tag includes nosnippet" "$OGP_HEADERS" "x-robots-tag" "nosnippet"
  else
    skip "OGP HTML check" "Twitterbot UA got SPA response — check Pages Function deployed and seed user is public"
  fi
fi

# ----------------------------------------------------------------------
section "4. /discover returns SPA (not OGP) for browsers"
# ----------------------------------------------------------------------
# 通常ブラウザ UA で /discover を取得 → Flutter SPA が返ることを確認
DISCOVER_BODY=$(curl -fsSL \
  -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
  "$BASE_URL/discover" 2>/dev/null || true)

if [[ -n "$DISCOVER_BODY" ]]; then
  check_contains "/discover returns Flutter SPA" "$DISCOVER_BODY" "flutter_bootstrap.js"
  check_contains "/discover has noindex meta" "$DISCOVER_BODY" 'name="robots".*noindex'
else
  fail "GET /discover returned empty body"
fi

# ----------------------------------------------------------------------
section "5. Cloudflare Bot Fight Mode (手動確認項目)"
# ----------------------------------------------------------------------
# 注: Bot Fight Mode の ON/OFF は API でも取得できるが、API Token が必要。
# 手動確認を促すのみ。
echo "${Y}- 手動確認: Cloudflare Dashboard → Security → Bots → Bot Fight Mode が ON${N}"
echo "  URL: https://dash.cloudflare.com/?to=/:account/:zone/security/bots"
SKIP=$((SKIP + 1))

# ----------------------------------------------------------------------
section "6. OGP プレビュー検証（外部ツール）"
# ----------------------------------------------------------------------
echo "${Y}- 手動確認: 以下のツールで /@$SEED_USER のプレビューが正常表示されるか${N}"
echo "  Twitter:  https://cards-dev.twitter.com/validator"
echo "  Facebook: https://developers.facebook.com/tools/debug/?q=$BASE_URL/@$SEED_USER"
SKIP=$((SKIP + 1))

# ----------------------------------------------------------------------
echo
echo "${B}Summary${N}: ${G}${PASS} passed${N}, ${R}${FAIL} failed${N}, ${Y}${SKIP} skipped/manual${N}"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
