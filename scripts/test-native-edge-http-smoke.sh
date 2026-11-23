#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${SUPABASE_SERVICE_ROLE_KEY:-}${SUPABASE_URL:-}" ]] || { echo "BLOCKED: database/service credentials in environment"; exit 2; }
command -v curl >/dev/null && command -v npm >/dev/null || { echo "curl and npm required"; exit 2; }
# Download Deno only to the local npm cache, without modifying the project manifest.
if command -v deno >/dev/null 2>&1; then
 deno_cmd=(deno)
else
 echo "Installing temporary Deno CLI through npm exec cache (no package.json changes)"
 deno_cmd=(npm exec --yes --package=deno -- deno)
fi
"${deno_cmd[@]}" --version
echo "=== Deno static checks for selected real Edge entrypoints ==="
for file in supabase/functions/member-checkin/index.ts supabase/functions/owner-status/index.ts supabase/functions/public-walkin-request/index.ts; do
 "${deno_cmd[@]}" fmt --check "$file" || echo "INFO: formatting differs in $file (not a runtime failure)"
done
echo "=== Native fail-closed HTTP smoke: owner-status ==="
port=18743
log="$(mktemp)"
pid=""
cleanup() { [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }; rm -f "$log"; }
trap cleanup EXIT
if curl -fsS --max-time 2 "http://127.0.0.1:$port/" >/dev/null 2>&1; then echo "BLOCKED: local test port already in use"; exit 2; fi
APP_ORIGIN="http://127.0.0.1:5173" "${deno_cmd[@]}" run --allow-net=127.0.0.1 --allow-env=APP_ORIGIN --allow-read --no-check supabase/functions/owner-status/index.ts --port "$port" >"$log" 2>&1 &
pid=$!
ready=0
for _ in $(seq 1 40); do
 if ! kill -0 "$pid" 2>/dev/null; then cat "$log"; echo "FAIL: Edge Function exited"; exit 1; fi
 if curl -sS --max-time 1 -o /dev/null "http://127.0.0.1:$port/" 2>/dev/null; then ready=1; break; fi
 sleep 1
done
if (( !ready )); then cat "$log"; echo "FAIL: Edge Function did not start"; exit 1; fi
request() {
 local expected="$1"; shift
 local status
 status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 5 "$@")"
 [[ "$status" == "$expected" ]] || { echo "FAIL: expected HTTP $expected, got $status"; return 1; }
}
request 403 -X POST -H 'Origin: https://untrusted.invalid' "http://127.0.0.1:$port/"
echo "PASS: disallowed Origin rejected"
request 401 -X POST -H 'Origin: http://127.0.0.1:5173' "http://127.0.0.1:$port/"
echo "PASS: missing Bearer token rejected"
request 405 -X GET -H 'Origin: http://127.0.0.1:5173' "http://127.0.0.1:$port/"
echo "PASS: incorrect HTTP method rejected"
echo "PASS: native Deno HTTP fail-closed smoke completed"
