#!/usr/bin/env bash
# Shared helpers for scenarios/*/run.sh. Requires: bash, curl, jq, docker.
#
#   gql <opName> <query> [variablesJson] [extra curl args...]
#       Sends an operation to the Router. Afterwards these are set:
#         BODY        response body
#         CC          Cache-Control response header
#         XCACHE      x-response-cache header (hit | partial_hit | miss | none)
#         CACHE_TAG   Cache-Tag header (CDN invalidation labels)
#   hdr <name>           any header from the last gql response
#   sg_stat <subgraph> <field>   subgraph counter (requests, rootFetches, entityFetches, entityRepresentations)
#   rest_stat "<GET /path>"      REST mock call counter
#   reset_all            flush Redis + zero all counters
#   invalidate <sharedKey> <json>   POST to the invalidation endpoint (sets INV_CODE, INV_BODY)
#   expect_eq / expect_contains / expect_not_contains   assertions → PASS/FAIL
#   finish               prints the summary; exits 1 if anything failed

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTER_URL="${ROUTER_URL:-http://localhost:4000/}"
INVALIDATION_URL="${INVALIDATION_URL:-http://localhost:4005/invalidation}"
SUBGRAPHS_URL="${SUBGRAPHS_URL:-http://localhost:4001}"
REST_URL="${REST_URL:-http://localhost:4010}"

if [ -f "$REPO_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.env"
  set +a
fi

for bin in curl jq docker; do
  command -v "$bin" >/dev/null || { echo "missing required tool: $bin" >&2; exit 2; }
done

if [ -t 1 ]; then
  B=$'\033[1m'; DIM=$'\033[2m'; G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'
else
  B=""; DIM=""; G=""; R=""; Y=""; C=""; N=""
fi

PASSED=0
FAILED=0
_HDRS="$(mktemp)"
trap 'rm -f "$_HDRS"' EXIT

title() { echo; echo "${B}${C}══ $* ══${N}"; }
step() { echo; echo "${B}▶ $*${N}"; }
note() { echo "${DIM}  $*${N}"; }

hdr() { grep -i "^$1:" "$_HDRS" | head -1 | cut -d: -f2- | sed 's/^ *//' | tr -d '\r'; }

gql() {
  local op="$1" query="$2" vars="${3:-}"
  [ -z "$vars" ] && vars='{}'
  shift 3 2>/dev/null || shift $#
  local payload
  payload="$(jq -nc --arg q "$query" --arg op "$op" --argjson v "$vars" \
    '{query:$q, variables:$v} + (if $op == "" then {} else {operationName:$op} end)')"
  BODY="$(curl -s -D "$_HDRS" "$ROUTER_URL" -H 'content-type: application/json' "$@" -d "$payload")"
  CC="$(hdr cache-control)"
  XCACHE="$(hdr x-response-cache)"
  CACHE_TAG="$(hdr cache-tag)"
  printf "  %s→ %-10s%s cache-control: %-22s %s\n" "$DIM" "${XCACHE:-n/a}" "$N" "${CC:-<none>}" "${DIM}${op:-<anonymous>}${N}"
}

sg_stat() { curl -s "$SUBGRAPHS_URL/__stats" | jq -r --arg s "$1" --arg f "$2" '.[$s][$f] // 0'; }
rest_stat() { curl -s "$REST_URL/__stats" | jq -r --arg k "$1" '.[$k] // 0'; }

reset_all() {
  (cd "$REPO_ROOT" && docker compose exec -T redis redis-cli FLUSHALL >/dev/null)
  curl -s -XPOST "$SUBGRAPHS_URL/__reset" >/dev/null
  curl -s -XPOST "$REST_URL/__reset" >/dev/null
  note "Redis flushed, subgraph + REST counters reset"
}

invalidate() {
  local key="$1" json="$2" out
  out="$(curl -s -w $'\n%{http_code}' -XPOST "$INVALIDATION_URL" \
    -H "authorization: $key" -H 'content-type: application/json' -d "$json")"
  INV_CODE="$(echo "$out" | tail -1)"
  INV_BODY="$(echo "$out" | sed '$d')"
  note "POST /invalidation $json → $INV_CODE $INV_BODY"
}

redis_ttl_for() {
  # Prints the TTL (seconds) of the first Redis key matching a pattern.
  (cd "$REPO_ROOT" && docker compose exec -T redis sh -c \
    "k=\$(redis-cli --scan --pattern '$1' | head -1); [ -n \"\$k\" ] && redis-cli TTL \"\$k\"") | tr -d '\r'
}

wait_for() {
  local secs="$1" why="$2"
  printf "  %s⏳ waiting %ss (%s)%s" "$Y" "$secs" "$why" "$N"
  for _ in $(seq 1 "$secs"); do sleep 1; printf "."; done
  echo
}

_pass() { PASSED=$((PASSED + 1)); echo "  ${G}✔ PASS${N} $1"; }
_fail() { FAILED=$((FAILED + 1)); echo "  ${R}✘ FAIL${N} $1"; echo "      ${DIM}$2${N}"; }

expect_eq() { # desc actual expected
  if [ "$2" = "$3" ]; then _pass "$1"; else _fail "$1" "expected '$3', got '$2'"; fi
}
expect_contains() { # desc haystack needle
  case "$2" in *"$3"*) _pass "$1" ;; *) _fail "$1" "expected to contain '$3', got '$2'" ;; esac
}
expect_not_contains() { # desc haystack needle
  case "$2" in *"$3"*) _fail "$1" "expected NOT to contain '$3', got '$2'" ;; *) _pass "$1" ;; esac
}

require_stack() {
  if ! curl -sf "http://localhost:8088/health" >/dev/null; then
    echo "${R}Router is not reachable on :4000 / health :8088.${N} Start the stack: docker compose up -d --build" >&2
    exit 2
  fi
}

finish() {
  echo
  if [ "$FAILED" -eq 0 ]; then
    echo "${G}${B}All $PASSED checks passed.${N}"
  else
    echo "${R}${B}$FAILED failed${N}, $PASSED passed."
    exit 1
  fi
}
