#!/usr/bin/env bash
# GYMFORCE: read-only verification of locally installed PostgREST and isolated PG17.
# Does not start PostgREST, create JWTs, read secrets, or modify any database.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}${SUPABASE_SERVICE_ROLE_KEY:-}" ]] || { echo 'BLOCKED: inherited database or service credential overrides'; exit 2; }
[[ ! -L .cache && ! -L .cache/gymforce-postgrest ]] || { echo 'BLOCKED: redirected local cache'; exit 2; }
binary="$(pwd -P)/.cache/gymforce-postgrest/postgrest"
[[ -f "$binary" && -x "$binary" && ! -L "$binary" ]] || { echo 'BLOCKED: verified local PostgREST binary missing'; exit 2; }
echo '=== Local PostgREST executable ==='
"$binary" --version
echo '=== Local binary file type ==='
if command -v file >/dev/null; then file "$binary"; fi
echo '=== Isolated database identity and HTTP-facing RPC permissions ==='
bash scripts/inspect-native-http-auth-readiness.sh
echo '=== Available test tooling ==='
node --version
npm --version
if command -v openssl >/dev/null; then openssl version; else echo 'MISSING openssl'; fi
echo 'PASS: local PostgREST binary and isolated DB preflight; no HTTP server, JWT, or database mutation.'
echo 'NEXT: synthetic JWT and local PostgREST HTTP tests require an isolated, explicitly configured runtime.'
