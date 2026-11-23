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
echo "=== Runtime role-denial tests (all changes rolled back) ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN;
DO $test$
DECLARE role_name text; table_name text; routine_oid oid; violations integer;
BEGIN
 FOR role_name IN SELECT unnest(ARRAY['anon','authenticated']) LOOP
   SELECT count(*) INTO violations FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='private' AND c.relkind IN ('r','p') AND
   (has_table_privilege(role_name,c.oid,'SELECT') OR has_table_privilege(role_name,c.oid,'INSERT')
   OR has_table_privilege(role_name,c.oid,'UPDATE') OR has_table_privilege(role_name,c.oid,'DELETE'));
   IF violations<>0 THEN RAISE EXCEPTION 'Unexpected private table grants to %: %',role_name,violations; END IF;
   SELECT count(*) INTO violations FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='api' AND has_function_privilege(role_name,p.oid,'EXECUTE');
   IF violations<>0 THEN RAISE EXCEPTION 'Unexpected api execute grants to %: %',role_name,violations; END IF;
   RAISE NOTICE 'PASS: % has no direct private-table or API execute privileges',role_name;
 END LOOP;
END $test$;
SAVEPOINT anon_check;
SET LOCAL ROLE anon;
DO $test$
BEGIN
 BEGIN
  EXECUTE 'SELECT count(*) FROM private.members';
  RAISE EXCEPTION 'FAIL: anon read private.members';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS: anon private.members SELECT denied';
 END;
 BEGIN
  EXECUTE 'SELECT count(*) FROM private.payment_records';
  RAISE EXCEPTION 'FAIL: anon read private.payment_records';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS: anon private.payment_records SELECT denied';
 END;
END $test$;
ROLLBACK TO SAVEPOINT anon_check;
SAVEPOINT authenticated_check;
SET LOCAL ROLE authenticated;
DO $test$
BEGIN
 BEGIN
  EXECUTE 'SELECT count(*) FROM private.members';
  RAISE EXCEPTION 'FAIL: authenticated read private.members';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS: authenticated private.members SELECT denied';
 END;
 BEGIN
  EXECUTE 'SELECT count(*) FROM private.payment_records';
  RAISE EXCEPTION 'FAIL: authenticated read private.payment_records';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS: authenticated private.payment_records SELECT denied';
 END;
END $test$;
ROLLBACK TO SAVEPOINT authenticated_check;
DO $test$
DECLARE count_bad integer;
BEGIN
 SELECT count(*) INTO count_bad FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' AND c.relkind IN ('r','p') AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity);
 IF count_bad<>0 THEN RAISE EXCEPTION 'RLS disabled or not forced on % tables',count_bad; END IF;
 RAISE NOTICE 'PASS: private tables have forced RLS';
END $test$;
ROLLBACK;
SQL
echo "PASS: isolated runtime role-denial assertions completed without persistent writes"
