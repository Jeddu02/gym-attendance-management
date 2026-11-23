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
echo "=== Owner lifecycle RPC authorization (rollback-only) ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN;
SET LOCAL ROLE service_role;
DO $test$
DECLARE unknown_actor uuid:='00000000-0000-4000-8000-000000000001'; unknown_member uuid:='00000000-0000-4000-8000-000000000002';
BEGIN
 BEGIN
  PERFORM api.owner_approve_member(unknown_actor,unknown_member,'Synthetic owner approval');
  RAISE EXCEPTION 'FAIL: unapproved actor approved member';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS: unauthorized member approval rejected';
 END;
 BEGIN
  PERFORM api.owner_activate_membership_purchase(unknown_actor,unknown_member);
  RAISE EXCEPTION 'FAIL: unapproved actor activated purchase';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS: unauthorized purchase activation rejected';
 END;
END $test$;
ROLLBACK;
SQL
echo "PASS: owner lifecycle RPC authorization tested without persistent writes"
