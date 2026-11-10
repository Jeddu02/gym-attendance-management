-- Disposable native synthetic database only. PHC strings are synthetic fixtures;
-- real PIN hashing, dummy verification and Edge orchestration have separate tests.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL TIME ZONE 'America/New_York';
DO $guard$
BEGIN
    IF current_database()<>'gymforce_batch1_synthetic'
       OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
        RAISE EXCEPTION 'Synthetic member check-in target required';
    END IF;
END;
$guard$;
INSERT INTO private.owner_access(user_id,is_active)
VALUES('00000000-0000-4000-8000-000000000001',true) ON CONFLICT(user_id) DO NOTHING;

SET LOCAL ROLE service_role;
DO $rate_reservations$
DECLARE v_result jsonb;
BEGIN
    v_result:=api.reserve_member_checkin_request(repeat('1',64),100,2);
    IF v_result->>'allowed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'First rate reservation failed'; END IF;
    v_result:=api.reserve_member_checkin_request(repeat('1',64),100,2);
    IF v_result->>'allowed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Second rate reservation failed'; END IF;
    v_result:=api.reserve_member_checkin_request(repeat('1',64),100,2);
    IF v_result->>'allowed' IS DISTINCT FROM 'false' OR (v_result->>'retryAfterSeconds')::integer NOT BETWEEN 1 AND 60 THEN
        RAISE EXCEPTION 'Identifier cap failed';
    END IF;
    v_result:=api.reserve_member_checkin_request(repeat('2',64),2,100);
    IF v_result->>'allowed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Global cap failed'; END IF;
    BEGIN
        PERFORM api.reserve_member_checkin_request(repeat('1',64),NULL,2);
        RAISE EXCEPTION 'Missing explicit check-in rate accepted';
    EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'INVALID_MEMBER_CHECKIN_RATE_REQUEST' THEN RAISE; END IF;
    END;
END;
$rate_reservations$;

DO $prepare_and_commit$
DECLARE
    v_owner constant uuid:='00000000-0000-4000-8000-000000000001';
    v_phc constant text:='$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGljLXNhbHQ$ZmFrZS12ZXJpZmllci1ub3QtYS1yZWFsLXBpbg';
    v_member jsonb; v_candidate jsonb; v_mobile_candidate jsonb; v_plan jsonb; v_purchase jsonb; v_payment jsonb; v_result jsonb;
BEGIN
    v_member:=api.owner_register_member(v_owner,'Member check-in synthetic',decode(repeat('91',32),'hex'),decode(repeat('92',32),'hex'));
    PERFORM set_config('gymforce.checkin_member',v_member->>'id',true);
    PERFORM set_config('gymforce.checkin_code',v_member->>'member_code',true);
    IF api.prepare_member_checkin(v_member->>'member_code',NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'Unenrolled member had a credential candidate';
    END IF;
    PERFORM api.owner_create_verified_pin_enrollment_token(v_owner,(v_member->>'id')::uuid,repeat('c',64),'Synthetic in-person identity verified');
    PERFORM api.member_enroll_pin(repeat('c',64),v_phc);
    v_candidate:=api.prepare_member_checkin(v_member->>'member_code',NULL);
    v_mobile_candidate:=api.prepare_member_checkin(NULL,decode(repeat('91',32),'hex'));
    IF v_candidate->>'memberId' IS DISTINCT FROM v_member->>'id'
       OR v_candidate->>'passwordHash' IS DISTINCT FROM v_phc
       OR v_candidate->>'credentialVersion' IS DISTINCT FROM '1'
       OR v_candidate IS DISTINCT FROM v_mobile_candidate THEN
        RAISE EXCEPTION 'Trusted lookup omitted pending candidate or mismatched identifiers';
    END IF;
    IF api.prepare_member_checkin(v_member->>'member_code',decode(repeat('91',32),'hex')) IS NOT NULL
       OR api.prepare_member_checkin('MBR-000000000000',NULL) IS NOT NULL
       OR api.prepare_member_checkin(NULL,NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'Malformed or unknown lookup did not return generic absence';
    END IF;
    v_result:=api.commit_member_checkin((v_member->>'id')::uuid,1);
    IF v_result->>'accepted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Pending registration checked in'; END IF;
    PERFORM api.owner_approve_member(v_owner,(v_member->>'id')::uuid,'Synthetic approved registration');
    v_plan:=api.owner_save_membership_plan(v_owner,NULL,'Check-in synthetic monthly',300,true);
    PERFORM set_config('gymforce.checkin_plan',v_plan->>'id',true);
    v_purchase:=api.owner_create_membership_purchase(v_owner,(v_member->>'id')::uuid,(v_plan->>'id')::uuid);
    v_result:=api.commit_member_checkin((v_member->>'id')::uuid,1);
    IF v_result->>'accepted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Unpaid approved member checked in'; END IF;
    v_payment:=api.owner_record_membership_payment(v_owner,gen_random_uuid(),(v_purchase->>'id')::uuid,300,'cash',NULL);
    PERFORM api.owner_confirm_membership_payment(v_owner,(v_payment->>'id')::uuid,true);
    v_result:=api.commit_member_checkin((v_member->>'id')::uuid,1);
    IF v_result->>'accepted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Undated paid purchase checked in'; END IF;
    PERFORM api.owner_activate_membership_purchase(v_owner,(v_purchase->>'id')::uuid);
    PERFORM set_config('gymforce.checkin_purchase',v_purchase->>'id',true);
    v_result:=api.commit_member_checkin((v_member->>'id')::uuid,1);
    IF v_result IS DISTINCT FROM '{"accepted":true}'::jsonb THEN RAISE EXCEPTION 'Eligible member check-in failed'; END IF;
    v_result:=api.commit_member_checkin((v_member->>'id')::uuid,1);
    IF v_result IS DISTINCT FROM '{"accepted":true}'::jsonb THEN RAISE EXCEPTION 'Duplicate did not return same generic acceptance'; END IF;
END;
$prepare_and_commit$;
RESET ROLE;

DO $basis_and_retry_state$
DECLARE v_id uuid; v_at timestamptz;
BEGIN
    IF (SELECT count(*) FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.checkin_member')::uuid)<>1 THEN
        RAISE EXCEPTION 'Duplicate check-in wrote multiple records';
    END IF;
    SELECT id,checked_in_at INTO STRICT v_id,v_at FROM private.attendance_checkins
    WHERE member_id=current_setting('gymforce.checkin_member')::uuid
      AND membership_purchase_id=current_setting('gymforce.checkin_purchase')::uuid
      AND attendance_status='valid' AND gym_local_date=(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date
      AND gym_local_date=(checked_in_at AT TIME ZONE 'Asia/Manila')::date;
    PERFORM set_config('gymforce.checkin_attendance',v_id::text,true);
    PERFORM set_config('gymforce.checkin_at',v_at::text,true);
    IF (SELECT count(*) FROM private.audit_events WHERE event_type='member.checked_in'
        AND details->>'member_id'=current_setting('gymforce.checkin_member'))<>1 THEN
        RAISE EXCEPTION 'Duplicate check-in rewrote audit history';
    END IF;
END;
$basis_and_retry_state$;

SET LOCAL ROLE service_role;
DO $reset_race_protection$
DECLARE v_owner constant uuid:='00000000-0000-4000-8000-000000000001'; v_result jsonb;
BEGIN
    PERFORM api.owner_create_pin_recovery_token(v_owner,current_setting('gymforce.checkin_member')::uuid,
        repeat('d',64),'Synthetic in-person recovery verified');
    PERFORM api.member_reset_pin(repeat('d',64),
        '$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGljLXNhbHQ$YW5vdGhlci1zeW50aGV0aWMtdmVyaWZpZXI');
    v_result:=api.commit_member_checkin(current_setting('gymforce.checkin_member')::uuid,1);
    IF v_result->>'accepted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Stale pre-reset credential version accepted'; END IF;
    v_result:=api.commit_member_checkin(current_setting('gymforce.checkin_member')::uuid,2);
    IF v_result->>'accepted' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Current credential duplicate failed'; END IF;
END;
$reset_race_protection$;
RESET ROLE;
DO $preserve_and_invalidate_fixture$
DECLARE v_result jsonb;
BEGIN
    IF NOT EXISTS(SELECT 1 FROM private.attendance_checkins WHERE id=current_setting('gymforce.checkin_attendance')::uuid
        AND checked_in_at=current_setting('gymforce.checkin_at')::timestamptz
        AND membership_purchase_id=current_setting('gymforce.checkin_purchase')::uuid) THEN
        RAISE EXCEPTION 'Credential reset/retry rewrote original attendance';
    END IF;
    -- Documented synthetic invalidation, not a new application correction API.
    INSERT INTO private.attendance_validity_resolutions(attendance_id,prior_status,new_status,reason,resolved_by)
    VALUES(current_setting('gymforce.checkin_attendance')::uuid,'valid','invalidated_correction',
        'Synthetic historical invalidation: test that public retries cannot restore validity',
        '00000000-0000-4000-8000-000000000001');
    UPDATE private.attendance_checkins SET attendance_status='invalidated_correction'
    WHERE id=current_setting('gymforce.checkin_attendance')::uuid;
    PERFORM api.append_audit_event('attendance','00000000-0000-4000-8000-000000000001',
        'test.synthetic_attendance_invalidated','attendance',current_setting('gymforce.checkin_attendance'),
        '{"reason":"Synthetic invalidation fixture; no automatic restoration allowed"}');
    SET LOCAL ROLE service_role;
    v_result:=api.commit_member_checkin(current_setting('gymforce.checkin_member')::uuid,2);
    RESET ROLE;
    IF v_result->>'accepted' IS DISTINCT FROM 'false'
       OR (SELECT count(*) FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.checkin_member')::uuid)<>1
       OR NOT EXISTS(SELECT 1 FROM private.attendance_checkins WHERE id=current_setting('gymforce.checkin_attendance')::uuid
          AND attendance_status='invalidated_correction') THEN
        RAISE EXCEPTION 'Public retry silently restored invalidated eligibility or replaced history';
    END IF;
END;
$preserve_and_invalidate_fixture$;

SET LOCAL ROLE service_role;
DO $atomic_fixture$
DECLARE
    v_owner constant uuid:='00000000-0000-4000-8000-000000000001';
    v_member jsonb; v_purchase jsonb; v_payment jsonb;
BEGIN
    v_member:=api.owner_register_member(v_owner,'Check-in atomic synthetic',decode(repeat('93',32),'hex'),decode(repeat('94',32),'hex'));
    PERFORM set_config('gymforce.checkin_atomic_member',v_member->>'id',true);
    PERFORM api.owner_approve_member(v_owner,(v_member->>'id')::uuid,'Synthetic registration verified');
    PERFORM api.owner_create_verified_pin_enrollment_token(v_owner,(v_member->>'id')::uuid,repeat('e',64),'Synthetic member identity verified');
    PERFORM api.member_enroll_pin(repeat('e',64),
        '$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGljLXNhbHQ$ZmFrZS12ZXJpZmllci1ub3QtYS1yZWFsLXBpbg');
    v_purchase:=api.owner_create_membership_purchase(v_owner,(v_member->>'id')::uuid,current_setting('gymforce.checkin_plan')::uuid);
    v_payment:=api.owner_record_membership_payment(v_owner,gen_random_uuid(),(v_purchase->>'id')::uuid,300,'cash',NULL);
    PERFORM api.owner_confirm_membership_payment(v_owner,(v_payment->>'id')::uuid,true);
    PERFORM api.owner_activate_membership_purchase(v_owner,(v_purchase->>'id')::uuid);
END;
$atomic_fixture$;
RESET ROLE;
DO $atomic_checkin$
DECLARE v_before bigint; v_result jsonb;
BEGIN
    SELECT count(*) INTO v_before FROM private.audit_events;
    BEGIN
        REVOKE EXECUTE ON FUNCTION private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz) FROM gym_owner_executor;
        SET LOCAL ROLE service_role;
        PERFORM api.commit_member_checkin(current_setting('gymforce.checkin_atomic_member')::uuid,1);
        RAISE EXCEPTION 'Nested audit failure did not abort member check-in';
    EXCEPTION WHEN insufficient_privilege THEN
        RESET ROLE;
        IF pg_catalog.strpos(SQLERRM,'compute_audit_event_hash')=0 THEN RAISE; END IF;
    END;
    IF EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.checkin_atomic_member')::uuid)
       OR (SELECT count(*) FROM private.audit_events)<>v_before THEN
        RAISE EXCEPTION 'Failed member check-in retained attendance/audit changes';
    END IF;
    SET LOCAL ROLE service_role;
    v_result:=api.commit_member_checkin(current_setting('gymforce.checkin_atomic_member')::uuid,1);
    RESET ROLE;
    IF v_result->>'accepted' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Retry after audit rollback failed'; END IF;
END;
$atomic_checkin$;

-- Inspect the pure eligibility helper with synthetic reference instants;
-- public RPCs accept no dates and always supply their own server clock.
DO $inclusive_expiry$
DECLARE v_purchase uuid; v_expiry date; v_basis uuid;
BEGIN
    SELECT id,expiry_date INTO STRICT v_purchase,v_expiry FROM private.membership_purchases
    WHERE member_id=current_setting('gymforce.checkin_atomic_member')::uuid AND purchase_status='active';
    v_basis:=private.member_checkin_eligible_purchase(current_setting('gymforce.checkin_atomic_member')::uuid,
        (v_expiry+time '23:59:59') AT TIME ZONE 'Asia/Manila');
    IF v_basis IS DISTINCT FROM v_purchase THEN RAISE EXCEPTION 'Inclusive expiry ended before gym midnight'; END IF;
    v_basis:=private.member_checkin_eligible_purchase(current_setting('gymforce.checkin_atomic_member')::uuid,
        (v_expiry+1)::timestamp AT TIME ZONE 'Asia/Manila');
    IF v_basis IS NOT NULL THEN RAISE EXCEPTION 'Expired term remained eligible after Manila midnight'; END IF;
END;
$inclusive_expiry$;

DO $verifier_and_table_boundaries$
DECLARE v_actor text; v_result jsonb;
BEGIN
    FOREACH v_actor IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor'] LOOP
        EXECUTE format('SET LOCAL ROLE %I',v_actor);
        BEGIN
            PERFORM password_hash FROM private.member_pin_credentials;
            RAISE EXCEPTION 'Verifier read allowed for %',v_actor;
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        RESET ROLE;
    END LOOP;
    FOREACH v_actor IN ARRAY ARRAY['anon','authenticated','gym_owner_executor','gym_public_executor'] LOOP
        EXECUTE format('SET LOCAL ROLE %I',v_actor);
        BEGIN
            PERFORM api.prepare_member_checkin(current_setting('gymforce.checkin_code'),NULL);
            RAISE EXCEPTION 'Untrusted caller accessed verifier RPC';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        BEGIN
            PERFORM api.commit_member_checkin(current_setting('gymforce.checkin_member')::uuid,2);
            RAISE EXCEPTION 'Untrusted caller bypassed PIN verification';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        RESET ROLE;
    END LOOP;
    IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='gym_checkin_executor' AND NOT rolcanlogin
        AND NOT rolsuper AND NOT rolbypassrls AND NOT rolinherit AND NOT rolcreaterole AND NOT rolcreatedb)
       OR EXISTS(SELECT 1 FROM pg_auth_members a JOIN pg_roles r ON r.oid=a.member OR r.oid=a.roleid WHERE r.rolname='gym_checkin_executor') THEN
        RAISE EXCEPTION 'Verifier role attributes/membership unsafe';
    END IF;
    FOREACH v_actor IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor'] LOOP
        IF has_any_column_privilege(v_actor,'private.member_checkin_rate_events','SELECT,INSERT,UPDATE,REFERENCES')
           OR has_table_privilege(v_actor,'private.member_checkin_rate_events','DELETE,TRUNCATE,TRIGGER') THEN
            RAISE EXCEPTION 'Check-in HMAC rate counters exposed to %',v_actor;
        END IF;
    END LOOP;
    SET LOCAL ROLE service_role;
    v_result:=api.commit_member_checkin(NULL,1);
    IF v_result IS DISTINCT FROM '{"accepted":false}'::jsonb THEN RAISE EXCEPTION 'Null member input accepted'; END IF;
    v_result:=api.commit_member_checkin(current_setting('gymforce.checkin_member')::uuid,0);
    IF v_result IS DISTINCT FROM '{"accepted":false}'::jsonb THEN RAISE EXCEPTION 'Invalid credential version accepted'; END IF;
    RESET ROLE;
END;
$verifier_and_table_boundaries$;
ROLLBACK;
\echo 'PASS: gated verifier boundary, keyed rate limits, approved/paid eligibility, immutable daily duplicates, credential-version races and audit rollback.'
