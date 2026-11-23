#!/usr/bin/env bash
# Read-only preflight against ONLY the isolated GYMFORCE synthetic PG17 database.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited database override"; exit 2; }
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
socket="/tmp/gf-pg-23c0b94e"
[[ ! -L .cache && ! -L "$root" && ! -L "$socket" ]] || { echo "BLOCKED: redirected path"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$root")" == "postgres:postgres:700" ]] || { echo "BLOCKED: unexpected cluster ownership"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$socket")" == "postgres:postgres:700" ]] || { echo "BLOCKED: unexpected socket ownership"; exit 2; }
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
identity="$("${psql[@]}" -At -c "select current_database() || '|' || current_user || '|' || current_setting('data_directory') || '|' || current_setting('listen_addresses') || '|' || current_setting('server_version_num')")"
[[ "$identity" == "gymforce_integration_test|postgres|$root/data||170012" ]] || { echo "BLOCKED: isolated database identity mismatch: $identity"; exit 2; }
echo "=== Native HTTP/Auth integration readiness (read-only) ==="
for binary in deno postgrest curl node npm; do
 if command -v "$binary" >/dev/null 2>&1; then
  printf 'AVAILABLE %s: %s\n' "$binary" "$(command -v "$binary")"
 else
  printf 'MISSING %s\n' "$binary"
 fi
done
echo "=== HTTP endpoint and auth-related source inventory ==="
find supabase/functions -maxdepth 2 -name index.ts -type f -print | sort
echo "=== PostgreSQL HTTP-facing grants (catalog-only) ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN READ ONLY;
SELECT n.nspname AS schema_name, p.proname AS function_name,
 pg_get_function_identity_arguments(p.oid) AS arguments,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS service_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='api' AND p.proname IN
 ('prepare_member_checkin','commit_member_checkin','reserve_member_checkin_request','owner_approve_member','owner_record_membership_payment','owner_confirm_membership_payment','owner_activate_membership_purchase')
ORDER BY p.proname;
ROLLBACK;
SQL
echo "PASS: native HTTP/Auth readiness inventory complete; no services installed or started"
