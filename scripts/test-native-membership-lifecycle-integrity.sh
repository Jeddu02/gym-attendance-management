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
echo "=== Membership lifecycle integrity tests (rollback-only) ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN;
DO $test$
DECLARE member_id uuid:=gen_random_uuid(); plan_id uuid:=gen_random_uuid(); purchase_id uuid:=gen_random_uuid(); check_date date:=(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
BEGIN
 INSERT INTO private.members(id,member_code,full_name,mobile_lookup_hash,mobile_encrypted)
 VALUES(member_id,'MBR-'||upper(substr(replace(member_id::text,'-',''),1,12)),'Synthetic Test Member',decode(repeat('a',64),'hex'),decode('010203','hex'));
 RAISE NOTICE 'PASS: member starts pending approval';
 BEGIN
  INSERT INTO private.members(id,member_code,full_name,mobile_lookup_hash,mobile_encrypted,status,approved_at)
  VALUES(gen_random_uuid(),'MBR-111111111111','Invalid Direct Active',decode(repeat('b',64),'hex'),decode('010203','hex'),'active',clock_timestamp());
  RAISE EXCEPTION 'FAIL: directly active member accepted';
 EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'PASS: direct active-member insertion rejected';
 END;
 INSERT INTO private.membership_plans(id,name,price_php) VALUES(plan_id,'Synthetic Test Plan',500);
 INSERT INTO private.membership_purchases(id,member_id,plan_id,price_php) VALUES(purchase_id,member_id,plan_id,500);
 RAISE NOTICE 'PASS: purchase starts pending payment';
 BEGIN
  INSERT INTO private.membership_purchases(member_id,plan_id,price_php,purchase_status,activation_date,expiry_date)
  VALUES(member_id,plan_id,500,'active',check_date,check_date+30);
  RAISE EXCEPTION 'FAIL: active unpaid purchase inserted';
 EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'PASS: direct active unpaid purchase rejected';
 END;
 BEGIN
  UPDATE private.membership_purchases SET purchase_status='active',activation_date=check_date,expiry_date=check_date+30 WHERE id=purchase_id;
  RAISE EXCEPTION 'FAIL: unpaid purchase activation accepted';
 EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'PASS: unpaid purchase activation rejected';
 END;
END $test$;
ROLLBACK;
SQL
echo "PASS: synthetic membership lifecycle integrity tests completed with rollback"
