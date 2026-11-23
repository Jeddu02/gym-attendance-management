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
echo "=== Synthetic check-in RPC behavior: rollback-only ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN;
SET LOCAL ROLE service_role;
DO $test$
DECLARE digest text:=repeat('a',64); result jsonb; id uuid:='00000000-0000-4000-8000-000000000001';
BEGIN
 SELECT api.reserve_member_checkin_request(digest,2,1) INTO result;
 IF result->>'allowed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'First rate reservation rejected: %',result; END IF;
 RAISE NOTICE 'PASS: first reservation accepted';
 SELECT api.reserve_member_checkin_request(digest,2,1) INTO result;
 IF result->>'allowed' IS DISTINCT FROM 'false' OR (result->>'retryAfterSeconds')::integer NOT BETWEEN 1 AND 60 THEN
 RAISE EXCEPTION 'Identifier rate limit failed: %',result; END IF;
 RAISE NOTICE 'PASS: identifier limit enforced';
 SELECT api.reserve_member_checkin_request(repeat('b',64),2,1) INTO result;
 IF result->>'allowed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Second identifier rejected: %',result; END IF;
 SELECT api.reserve_member_checkin_request(repeat('c',64),2,1) INTO result;
 IF result->>'allowed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Global limit failed: %',result; END IF;
 RAISE NOTICE 'PASS: global limit enforced';
 SELECT api.prepare_member_checkin('invalid',NULL) INTO result;
 IF result IS NOT NULL THEN RAISE EXCEPTION 'Invalid member code exposed: %',result; END IF;
 RAISE NOTICE 'PASS: invalid member identifier rejected';
 SELECT api.commit_member_checkin(id,1) INTO result;
 IF result->>'accepted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Unknown member accepted: %',result; END IF;
 RAISE NOTICE 'PASS: unknown member check-in rejected';
END $test$;
ROLLBACK;
SQL
echo "PASS: isolated check-in RPC tests completed with all writes rolled back"
