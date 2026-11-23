#!/usr/bin/env bash
# Real Deno Edge handlers: local fail-closed HTTP matrix; no hosted credentials.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${SUPABASE_URL:-}${SUPABASE_SERVICE_ROLE_KEY:-}${SUPABASE_ANON_KEY:-}${SUPABASE_PUBLISHABLE_KEY:-}" ]] || { echo "BLOCKED: inherited service/database credentials"; exit 2; }
if command -v deno >/dev/null 2>&1; then deno_cmd=(deno); else deno_cmd=(npm exec --yes --package=deno -- deno); fi
port=18743
origin=http://127.0.0.1:5173
log="$(mktemp)"
pid=""
cleanup() { if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; rm -f "$log"; }
trap cleanup EXIT
if [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$port/" || true)" != "000" ]]; then echo "BLOCKED: local port $port already occupied"; exit 2; fi
check() {
 local label="$1" expected="$2"; shift 2
 local actual
 actual="$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "$@" "http://127.0.0.1:$port/")"
 if [[ "$actual" != "$expected" ]]; then echo "FAIL: $label expected $expected, received $actual"; cat "$log"; exit 1; fi
 echo "PASS: $label ($actual)"
}
start() {
 local name="$1"
 : > "$log"
 APP_ORIGIN="$origin" GYMFORCE_HTTP_TEST_PORT="$port" "${deno_cmd[@]}" run --no-check --allow-net=0.0.0.0:18743,127.0.0.1 --allow-env=APP_ORIGIN,GYMFORCE_HTTP_TEST_PORT --allow-read "supabase/functions/$name/index.ts" >"$log" 2>&1 &
 pid=$!
 local ready=0
 for _ in $(seq 1 45); do
  if ! kill -0 "$pid" 2>/dev/null; then cat "$log"; echo "FAIL: $name exited"; exit 1; fi
  if [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 1 "http://127.0.0.1:$port/" || true)" != "000" ]]; then ready=1; break; fi
  sleep 1
 done
 if (( !ready )); then cat "$log"; echo "FAIL: $name failed to listen"; exit 1; fi
 echo "=== $name native HTTP ==="
}
stop() {
 kill "$pid" 2>/dev/null || true
 wait "$pid" 2>/dev/null || true
 pid=""
 for _ in $(seq 1 30); do
  [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 1 "http://127.0.0.1:$port/" || true)" == "000" ]] && return
  sleep 1
 done
 echo "FAIL: test port still occupied after stopping handler"; exit 1
}
start owner-status
check 'owner-status foreign Origin' 403 -X POST -H 'Origin: https://untrusted.invalid'
check 'owner-status no Bearer token' 401 -X POST -H "Origin: $origin"
check 'owner-status wrong method' 405 -X GET -H "Origin: $origin"
check 'owner-status preflight' 204 -X OPTIONS -H "Origin: $origin"
stop
start member-checkin
check 'member-checkin foreign Origin' 403 -X POST -H 'Origin: https://untrusted.invalid'
check 'member-checkin disabled without approved configuration' 503 -X POST -H "Origin: $origin" -H 'Content-Type: application/json' -d '{}'
check 'member-checkin preflight' 204 -X OPTIONS -H "Origin: $origin"
stop
start public-walkin-request
check 'walkin foreign Origin' 403 -X POST -H 'Origin: https://untrusted.invalid'
check 'walkin disabled without approved configuration' 503 -X POST -H "Origin: $origin" -H 'Content-Type: application/json' -d '{}'
check 'walkin preflight' 204 -X OPTIONS -H "Origin: $origin"
stop
start owner-membership-payments
check 'owner-payments foreign Origin' 403 -X POST -H 'Origin: https://untrusted.invalid'
check 'owner-payments missing server credentials' 503 -X POST -H "Origin: $origin" -H 'Content-Type: application/json' -d '{}'
check 'owner-payments preflight' 204 -X OPTIONS -H "Origin: $origin"
stop
echo 'PASS: 13 native Edge HTTP assertions; all handlers stopped; no database writes'
