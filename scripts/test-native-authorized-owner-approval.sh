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
echo "=== Authorized member approval fixture (rollback-only) ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN;
DO $fixture$
DECLARE actor uuid:=gen_random_uuid(); member uuid:=gen_random_uuid(); plan uuid:=gen_random_uuid(); purchase uuid:=gen_random_uuid(); result jsonb;
BEGIN
 INSERT INTO auth.users(id) VALUES(actor);
 INSERT INTO private.owner_access(user_id,is_active) VALUES(actor,true);
 INSERT INTO private.members(id,member_code,full_name,mobile_lookup_hash,mobile_encrypted)
 VALUES(member,'MBR-'||upper(substr(replace(member::text,'-',''),1,12)),'Synthetic Approved Member',digest(member::text,'sha256'),decode('010203','hex'));
 INSERT INTO private.membership_plans(id,name,price_php) VALUES(plan,'Synthetic Owner Test Plan',500);
 INSERT INTO private.membership_purchases(id,member_id,plan_id,price_php) VALUES(purchase,member,plan,500);
 PERFORM pg_catalog.set_config('role','service_role',true);
 SELECT api.owner_approve_member(actor,member,'Synthetic test owner approval') INTO result;
 IF result->>'status' IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'Owner approval failed: %',result; END IF;
 RAISE NOTICE 'PASS: authorized owner approval transitioned member to active';
 SELECT api.owner_approve_member(actor,member,'Synthetic test owner approval') INTO result;
 IF result->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Owner approval replay failed: %',result; END IF;
 RAISE NOTICE 'PASS: repeat owner approval is idempotent';
 BEGIN
  PERFORM api.owner_activate_membership_purchase(actor,purchase);
  RAISE EXCEPTION 'FAIL: unpaid purchase activated';
 EXCEPTION WHEN invalid_parameter_value THEN
  RAISE NOTICE 'PASS: owner cannot activate unpaid purchase';
 END;
END $fixture$;
ROLLBACK;
SQL
echo "PASS: authorized owner fixture completed; no persistent writes"
