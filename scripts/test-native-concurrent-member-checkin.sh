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
# Clone the already-verified isolated synthetic DB. Never mutate its source.
testdb="gymforce_concurrency_disposable"
admin=("${psql[@]}")
if [[ "$("${admin[@]}" -At -c "SELECT count(*) FROM pg_database WHERE datname='$testdb'")" != "0" ]]; then
 echo "BLOCKED: disposable test database name already exists"; exit 2
fi
created=0
cleanup() {
 if (( created )); then
  "${admin[@]}" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$testdb' AND pid<>pg_backend_pid()" >/dev/null || true
  "${admin[@]}" -c "DROP DATABASE $testdb" || echo "WARNING: manual cleanup required for $testdb"
 fi
}
trap cleanup EXIT
"${admin[@]}" -c "CREATE DATABASE $testdb TEMPLATE gymforce_integration_test"
created=1
db=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d "$testdb")
echo "=== Create paid member in disposable database ==="
"${db[@]}" <<'SQL'
BEGIN;
DO $fixture$
DECLARE actor uuid:=gen_random_uuid(); member uuid:=gen_random_uuid(); plan uuid:=gen_random_uuid(); purchase uuid:=gen_random_uuid(); operation uuid:=gen_random_uuid(); payment uuid; response jsonb; credential_version integer:=1;
BEGIN
 INSERT INTO auth.users(id) VALUES(actor);
 INSERT INTO private.owner_access(user_id,is_active) VALUES(actor,true);
 INSERT INTO private.members(id,member_code,full_name,mobile_lookup_hash,mobile_encrypted)
 VALUES(member,'MBR-'||upper(substr(replace(member::text,'-',''),1,12)),'Synthetic Paid Member',decode(md5(member::text)||md5('gymforce-synthetic:'||member::text),'hex'),decode('010203','hex'));
 INSERT INTO private.member_pin_credentials(member_id,password_hash,credential_version)
 VALUES(member,'synthetic-nonproduction-hash',credential_version);
 INSERT INTO private.membership_plans(id,name,price_php) VALUES(plan,'Synthetic Paid Plan',500);
 INSERT INTO private.membership_purchases(id,member_id,plan_id,price_php) VALUES(purchase,member,plan,500);
 response:=api.owner_approve_member(actor,member,'Approved for synthetic paid membership test');
 IF response->>'status'<>'active' THEN RAISE EXCEPTION 'Member approval failed: %',response; END IF;
 RAISE NOTICE 'PASS: owner approved member';
 response:=api.owner_record_membership_payment(actor,operation,purchase,500,'cash',NULL);
 SELECT id INTO payment FROM private.payment_records WHERE operation_id=operation;
 IF payment IS NULL THEN RAISE EXCEPTION 'Payment recording did not persist receipt: %',response; END IF;
 RAISE NOTICE 'PASS: owner recorded full membership receipt';
 BEGIN
  PERFORM api.owner_activate_membership_purchase(actor,purchase);
  RAISE EXCEPTION 'FAIL: unconfirmed payment activated membership';
 EXCEPTION WHEN invalid_parameter_value THEN
  RAISE NOTICE 'PASS: unconfirmed receipt cannot activate membership';
 END;
 response:=api.owner_confirm_membership_payment(actor,payment,true);
 IF NOT EXISTS(SELECT 1 FROM private.payment_records WHERE id=payment AND verification_status='confirmed') THEN
  RAISE EXCEPTION 'Receipt confirmation failed: %',response;
 END IF;
 RAISE NOTICE 'PASS: owner confirmed full payment';
 response:=api.owner_activate_membership_purchase(actor,purchase);
 IF response->>'purchaseStatus'<>'active' THEN RAISE EXCEPTION 'Activation failed: %',response; END IF;
 RAISE NOTICE 'PASS: owner activated paid membership';

END $fixture$;
COMMIT;
SQL
member_id="$("${db[@]}" -At -c "SELECT id FROM private.members WHERE full_name='Synthetic Paid Member'")"
[[ "$member_id" =~ ^[0-9a-f-]{36}$ ]] || { echo "FAIL: synthetic member missing"; exit 1; }
echo "=== Run two independent simultaneous check-in transactions ==="
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"; cleanup' EXIT
run_checkin() {
 local index="$1"
 "${db[@]}" -At -c "BEGIN; SELECT pg_sleep(1); SELECT api.commit_member_checkin('$member_id'::uuid,1)->>'accepted'; COMMIT;" >"$tmpdir/$index.out" 2>"$tmpdir/$index.err"
}
run_checkin 1 & p1=$!
run_checkin 2 & p2=$!
status=0
wait "$p1" || status=1
wait "$p2" || status=1
if (( status )); then
 cat "$tmpdir/"*.err; echo "FAIL: concurrent session error"; exit 1
fi
for index in 1 2; do
 if ! grep -qx 'true' "$tmpdir/$index.out"; then
  cat "$tmpdir/$index.out"; echo "FAIL: check-in session $index not accepted"; exit 1
 fi
done
"${db[@]}" <<SQL
DO \$verify\$
DECLARE attendance_count integer; audit_count integer;
BEGIN
 SELECT count(*) INTO attendance_count FROM private.attendance_checkins
 WHERE member_id='$member_id'::uuid AND attendance_status='valid';
 SELECT count(*) INTO audit_count FROM private.audit_events a
 JOIN private.attendance_checkins c ON a.subject_id=c.id::text
 WHERE c.member_id='$member_id'::uuid AND a.event_type='member.checked_in';
 IF attendance_count<>1 OR audit_count<>1 THEN
  RAISE EXCEPTION 'Concurrent check-in invariant failed: attendance %, audits %',attendance_count,audit_count;
 END IF;
 RAISE NOTICE 'PASS: two concurrent accepted calls produced exactly one attendance and one audit event';
END \$verify\$;
SQL
echo "PASS: disposable PostgreSQL concurrency test completed"
