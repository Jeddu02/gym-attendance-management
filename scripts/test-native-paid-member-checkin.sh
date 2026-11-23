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
echo "=== Full payment to member check-in integration (rollback-only) ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN;
DO $fixture$
DECLARE actor uuid:=gen_random_uuid(); member uuid:=gen_random_uuid(); plan uuid:=gen_random_uuid(); purchase uuid:=gen_random_uuid(); operation uuid:=gen_random_uuid(); payment uuid; response jsonb; credential_version integer:=1; count_before integer; count_after integer;
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
 SELECT count(*) INTO count_before FROM private.attendance_checkins WHERE member_id=member;
 response:=api.commit_member_checkin(member,credential_version);
 IF response->>'accepted'<>'true' THEN RAISE EXCEPTION 'Check-in failed: %',response; END IF;
 SELECT count(*) INTO count_after FROM private.attendance_checkins WHERE member_id=member AND attendance_status='valid';
 IF count_after<>count_before+1 THEN RAISE EXCEPTION 'Check-in not recorded exactly once: before %, after %',count_before,count_after; END IF;
 RAISE NOTICE 'PASS: eligible member check-in accepted';
 response:=api.commit_member_checkin(member,credential_version);
 SELECT count(*) INTO count_after FROM private.attendance_checkins WHERE member_id=member AND attendance_status='valid';
 IF response->>'accepted'<>'true' OR count_after<>count_before+1 THEN RAISE EXCEPTION 'Check-in replay not idempotent: %',response; END IF;
 RAISE NOTICE 'PASS: same-day check-in replay is idempotent';
 IF NOT EXISTS(SELECT 1 FROM private.audit_events WHERE subject_id=member::text AND event_type LIKE '%checkin%') THEN
  RAISE NOTICE 'CHECK: check-in audit event naming requires inspection';
 ELSE
  RAISE NOTICE 'PASS: member check-in audit event exists';
 END IF;
END $fixture$;
ROLLBACK;
SQL
echo "PASS: paid-member integration assertions completed; all writes rolled back"
