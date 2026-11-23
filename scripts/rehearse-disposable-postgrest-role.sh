#!/usr/bin/env bash
# GYMFORCE: validate disposable PostgREST role bootstrap in a rolled-back transaction.
# Existing isolated PG17 fixture only. No persistent role changes or HTTP listener.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-postgrest-http-harness-gates.sh >/dev/null
socket="/tmp/gf-pg-23c0b94e"
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
echo '=== Transactional disposable PostgREST bootstrap rehearsal ==='
"${psql[@]}" -At <<'SQL'
BEGIN;
DO $$
BEGIN
 IF current_database()<>'gymforce_integration_test'
    OR current_setting('listen_addresses')<>''
    OR current_setting('data_directory') NOT LIKE '%/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937/data'
 THEN RAISE EXCEPTION 'Isolated fixture identity mismatch'; END IF;
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='gf_http_fixture_login')
 THEN RAISE EXCEPTION 'Disposable login role already exists'; END IF;
END $$;
CREATE ROLE gf_http_fixture_login LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
GRANT anon TO gf_http_fixture_login;
GRANT authenticated TO gf_http_fixture_login;
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_auth_members am
 JOIN pg_roles m ON m.oid=am.member
 JOIN pg_roles r ON r.oid=am.roleid
 WHERE m.rolname='gf_http_fixture_login' AND r.rolname IN ('anon','authenticated') AND am.set_option;
 IF n<>2 THEN RAISE EXCEPTION 'Expected exactly two permitted role switches; got %',n; END IF;
 IF EXISTS (SELECT 1 FROM pg_auth_members am
 JOIN pg_roles m ON m.oid=am.member JOIN pg_roles r ON r.oid=am.roleid
 WHERE m.rolname='gf_http_fixture_login' AND r.rolname='service_role')
 THEN RAISE EXCEPTION 'Service role escalation detected'; END IF;
 RAISE NOTICE 'PASS: temporary login can switch to anon/authenticated but not service_role';
END $$;
ROLLBACK;
SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname='gf_http_fixture_login')
 THEN 'FAIL: fixture role persisted' ELSE 'PASS: fixture role absent after rollback' END;
SQL
echo 'PASS: disposable login bootstrap rehearsal completed; no persistent SQL changes.'
echo 'NOT VERIFIED: actual PostgREST HTTP requests or real Supabase JWTs.'
