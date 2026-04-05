#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./socs/issues/stress_supabase_ios.sh [options]

Required env vars:
  SUPABASE_URL            e.g. https://<project>.supabase.co
  SUPABASE_ANON_KEY       anon/publishable key
  SUPABASE_ACCESS_TOKEN   user access token (JWT)
  STRESS_USER_ID          UUID for user-scoped queries
  STRESS_GROUP_ID         UUID for group-scoped queries

Options:
  -m MODE     one of: mixed|events|invites|plays|wishlist (default: mixed)
  -n COUNT    total request rounds (default: 40)
  -p PAR      max parallel requests (default: 8)
  -s SEC      sleep between rounds in seconds (default: 0)
  -o FILE     output file path (default: socs/issues/results/stress-<ts>.log)

Optional env vars:
  STRESS_INVITES_QUERY    one of: light|heavy (default: light)
                          light = select=* (current iOS app query path)
                          heavy = select with nested event graph (legacy/worst-case)
  STRESS_PLAYS_QUERY      one of: rpc|legacy (default: rpc)
                          rpc = POST to get_group_plays RPC (current iOS app path)
                          legacy = GET with nested joins via PostgREST (old path)

Examples:
  export SUPABASE_URL="https://yourproj.supabase.co"
  export SUPABASE_ANON_KEY="..."
  export SUPABASE_ACCESS_TOKEN="..."
  export STRESS_USER_ID="1652326c-1d56-4d1e-8453-354e55262c5f"
  export STRESS_GROUP_ID="A6C84503-F496-464A-BC00-206E7D3691AE"
  ./socs/issues/stress_supabase_ios.sh -m mixed -n 100 -p 12
EOF
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

MODE="mixed"
COUNT=40
PAR=8
SLEEP_SEC=0
OUT=""

while getopts ":m:n:p:s:o:h" opt; do
  case "$opt" in
    m) MODE="$OPTARG" ;;
    n) COUNT="$OPTARG" ;;
    p) PAR="$OPTARG" ;;
    s) SLEEP_SEC="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    :) echo "Option -$OPTARG requires a value." >&2; usage; exit 1 ;;
  esac
done

case "$MODE" in
  mixed|events|invites|plays|wishlist) ;;
  *) echo "Invalid mode: $MODE" >&2; usage; exit 1 ;;
esac

require_env SUPABASE_URL
require_env SUPABASE_ANON_KEY
require_env SUPABASE_ACCESS_TOKEN
require_env STRESS_USER_ID
require_env STRESS_GROUP_ID

mkdir -p socs/issues/results
if [[ -z "$OUT" ]]; then
  OUT="socs/issues/results/stress-$(date +%Y%m%d-%H%M%S).log"
fi

BASE_URL="${SUPABASE_URL%/}"
STRESS_INVITES_QUERY="${STRESS_INVITES_QUERY:-light}"

EVENTS_PATH="/rest/v1/events?select=*,host:users(*),games:event_games(*,game:games(*)),time_options!event_id(*),groups(id,name,emoji)&group_id=eq.${STRESS_GROUP_ID}&deleted_at=is.NULL&order=created_at.desc.nullslast"
INVITES_LIGHT_PATH="/rest/v1/invites?select=*&user_id=eq.${STRESS_USER_ID}"
INVITES_HEAVY_PATH="/rest/v1/invites?select=*,event:events(*,host:users(*),games:event_games(*,game:games(*)),time_options!event_id(*),groups(id,name,emoji))&user_id=eq.${STRESS_USER_ID}"
PLAYS_LEGACY_PATH="/rest/v1/plays?select=*,game:games(*),play_participants(*),logged_by_user:users!logged_by(*)&group_id=eq.${STRESS_GROUP_ID}&order=played_at.desc.nullslast"
PLAYS_RPC_PATH="/rest/v1/rpc/get_group_plays"
PLAYS_RPC_BODY="{\"p_group_id\":\"${STRESS_GROUP_ID}\"}"
STRESS_PLAYS_QUERY="${STRESS_PLAYS_QUERY:-rpc}"
WISHLIST_PATH="/rest/v1/game_wishlist?select=*,game:games(*)&user_id=eq.${STRESS_USER_ID}&order=added_at.desc.nullslast"

case "$STRESS_INVITES_QUERY" in
  light) INVITES_PATH="$INVITES_LIGHT_PATH" ;;
  heavy) INVITES_PATH="$INVITES_HEAVY_PATH" ;;
  *)
    echo "Invalid STRESS_INVITES_QUERY: $STRESS_INVITES_QUERY (expected light|heavy)" >&2
    exit 1
    ;;
esac

curl_code() {
  local url="$1"
  local code
  code="$(curl -sS --connect-timeout 10 --max-time 30 \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "User-Agent: CWM-Stress/1.0" \
    -o /dev/null -w "%{http_code}" \
    "${BASE_URL}${url}" || true)"

  if [[ -z "$code" ]]; then
    code="000"
  fi

  printf "%s" "$code"
}

curl_post_code() {
  local url="$1"
  local body="$2"
  local code
  code="$(curl -sS --connect-timeout 10 --max-time 30 \
    -X POST \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "User-Agent: CWM-Stress/1.0" \
    -d "$body" \
    -o /dev/null -w "%{http_code}" \
    "${BASE_URL}${url}" || true)"

  if [[ -z "$code" ]]; then
    code="000"
  fi

  printf "%s" "$code"
}

run_one_round() {
  local i="$1"
  local ts endpoint code
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  case "$MODE" in
    events)
      endpoint="events"; code="$(curl_code "$EVENTS_PATH")"
      printf "%s round=%s endpoint=%s code=%s\n" "$ts" "$i" "$endpoint" "$code"
      ;;
    invites)
      endpoint="invites"; code="$(curl_code "$INVITES_PATH")"
      printf "%s round=%s endpoint=%s code=%s\n" "$ts" "$i" "$endpoint" "$code"
      ;;
    plays)
      if [[ "$STRESS_PLAYS_QUERY" == "rpc" ]]; then
        endpoint="plays"; code="$(curl_post_code "$PLAYS_RPC_PATH" "$PLAYS_RPC_BODY")"
      else
        endpoint="plays"; code="$(curl_code "$PLAYS_LEGACY_PATH")"
      fi
      printf "%s round=%s endpoint=%s code=%s\n" "$ts" "$i" "$endpoint" "$code"
      ;;
    wishlist)
      endpoint="wishlist"; code="$(curl_code "$WISHLIST_PATH")"
      printf "%s round=%s endpoint=%s code=%s\n" "$ts" "$i" "$endpoint" "$code"
      ;;
    mixed)
      endpoint="events"; code="$(curl_code "$EVENTS_PATH")"
      printf "%s round=%s endpoint=%s code=%s\n" "$ts" "$i" "$endpoint" "$code"
      endpoint="invites"; code="$(curl_code "$INVITES_PATH")"
      printf "%s round=%s endpoint=%s code=%s\n" "$ts" "$i" "$endpoint" "$code"
      if [[ "$STRESS_PLAYS_QUERY" == "rpc" ]]; then
        endpoint="plays"; code="$(curl_post_code "$PLAYS_RPC_PATH" "$PLAYS_RPC_BODY")"
      else
        endpoint="plays"; code="$(curl_code "$PLAYS_LEGACY_PATH")"
      fi
      printf "%s round=%s endpoint=%s code=%s\n" "$ts" "$i" "$endpoint" "$code"
      endpoint="wishlist"; code="$(curl_code "$WISHLIST_PATH")"
      printf "%s round=%s endpoint=%s code=%s\n" "$ts" "$i" "$endpoint" "$code"
      ;;
  esac

  if [[ "$SLEEP_SEC" != "0" ]]; then
    sleep "$SLEEP_SEC"
  fi
}

export -f run_one_round curl_code curl_post_code
export MODE COUNT PAR SLEEP_SEC BASE_URL SUPABASE_ANON_KEY SUPABASE_ACCESS_TOKEN
export EVENTS_PATH INVITES_PATH PLAYS_LEGACY_PATH PLAYS_RPC_PATH PLAYS_RPC_BODY STRESS_PLAYS_QUERY WISHLIST_PATH

echo "Starting stress test:"
echo "  mode=$MODE rounds=$COUNT parallel=$PAR sleep=$SLEEP_SEC out=$OUT"
echo "  invites_query=$STRESS_INVITES_QUERY plays_query=$STRESS_PLAYS_QUERY"
echo "  url=$BASE_URL user=$STRESS_USER_ID group=$STRESS_GROUP_ID"

seq 1 "$COUNT" | xargs -n1 -P"$PAR" -I{} bash -lc 'run_one_round "$@"' _ {} >> "$OUT"

echo
echo "Done. Results written to: $OUT"
echo
echo "Status summary:"
awk '{for(i=1;i<=NF;i++){if($i ~ /^endpoint=/){split($i,a,"="); ep=a[2]} if($i ~ /^code=/){split($i,b,"="); cd=b[2]}} if(ep!="" && cd!=""){k=ep":"cd; c[k]++}} END{for(k in c) print c[k], k}' "$OUT" | sort -nr

echo
echo "Errors (non-2xx):"
awk '$0 !~ /code=2[0-9][0-9]/ {print}' "$OUT" | tail -n 50
