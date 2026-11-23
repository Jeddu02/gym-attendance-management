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
echo "=== Check-in abuse boundaries (rollback-only) ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN;
SET LOCAL ROLE service_role;
DO $test$
DECLARE result jsonb; count_before bigint; count_after bigint; value text;
BEGIN
 SELECT count(*) INTO count_before FROM pg_catalog.pg_class WHERE relname='member_checkin_rate_events';
 IF count_before<>1 THEN RAISE EXCEPTION 'Expected rate events table missing'; END IF;
 FOREACH value IN ARRAY ARRAY['', 'abc', repeat('g',64), repeat('a',63)] LOOP
  BEGIN
   PERFORM api.reserve_member_checkin_request(value,2,1);
   RAISE EXCEPTION 'Invalid digest accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
 END LOOP;
 RAISE NOTICE 'PASS: malformed digests rejected';
 BEGIN
  PERFORM api.reserve_member_checkin_request(repeat('a',64),0,1);
  RAISE EXCEPTION 'Zero global limit accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 BEGIN
  PERFORM api.reserve_member_checkin_request(repeat('a',64),1,101);
  RAISE EXCEPTION 'Excessive identifier limit accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 RAISE NOTICE 'PASS: invalid abuse thresholds rejected';
 SELECT api.prepare_member_checkin('MBR-000000000000',NULL) INTO result;
 IF result IS NOT NULL THEN RAISE EXCEPTION 'Nonexistent valid-format identifier exposed'; END IF;
 SELECT api.prepare_member_checkin(NULL,decode(repeat('0',64),'hex')) INTO result;
 IF result IS NOT NULL THEN RAISE EXCEPTION 'Nonexistent mobile hash exposed'; END IF;
 SELECT api.prepare_member_checkin(NULL,decode('ff','hex')) INTO result;
 IF result IS NOT NULL THEN RAISE EXCEPTION 'Invalid mobile hash exposed'; END IF;
 RAISE NOTICE 'PASS: missing and malformed member credentials not exposed';
 SELECT api.commit_member_checkin('00000000-0000-4000-8000-000000000001',0) INTO result;
 IF result->>'accepted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Invalid credential version accepted'; END IF;
 SELECT api.commit_member_checkin('00000000-0000-4000-8000-000000000001',1) INTO result;
 IF result->>'accepted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Unknown member accepted'; END IF;
 RAISE NOTICE 'PASS: invalid credential version and unknown member rejected';
END $test$;
ROLLBACK;
SQL
echo "PASS: check-in abuse boundaries tested with transaction rollback"
