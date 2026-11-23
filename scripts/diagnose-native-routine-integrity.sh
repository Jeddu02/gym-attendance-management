#!/usr/bin/env bash
# Read-only integrity inventory before retrying executor hardening.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited database override"; exit 2; }
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
socket="/tmp/gf-pg-23c0b94e"
[[ ! -L .cache && ! -L "$root" && ! -L "$socket" ]] || { echo "BLOCKED: redirected path"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$root")" == "postgres:postgres:700" && "$(sudo -n stat -c '%U:%G:%a' "$socket")" == "postgres:postgres:700" ]] || { echo "BLOCKED: ownership mismatch"; exit 2; }
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
identity="$("${psql[@]}" -At -c "select current_database() || '|' || current_user || '|' || current_setting('data_directory') || '|' || current_setting('listen_addresses') || '|' || current_setting('server_version_num')")"
[[ "$identity" == "gymforce_integration_test|postgres|$root/data||170012" ]] || { echo "BLOCKED: synthetic identity mismatch"; exit 2; }
echo "=== All application routine hashes and metadata ==="
rows="$("${psql[@]}" -F ' | ' -At -c "SELECT p.oid::regprocedure,md5(p.prosrc),pg_get_userbyid(p.proowner),p.prosecdef,p.proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('private','api') ORDER BY p.oid::regprocedure::text")"
[[ -n "$rows" ]] || { echo "BLOCKED: no application routine records returned"; exit 2; }
printf '%s\n' "$rows"
echo "=== Source definitions containing append_audit_event ==="
grep -RniE 'create[[:space:]]+(or[[:space:]]+replace[[:space:]]+)?function[[:space:]]+api[.]append_audit_event|7a05ca54592137c75b9adda7023516a8' supabase/migrations || true
echo "PASS: forensic inventory completed; no modifications"
