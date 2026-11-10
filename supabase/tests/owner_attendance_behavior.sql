-- Isolated native synthetic read-only API tests. All fixture writes roll back.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$
BEGIN
    IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
        RAISE EXCEPTION 'Synthetic attendance target required';
    END IF;
END;
$guard$;
INSERT INTO private.owner_access(user_id,is_active)
VALUES('00000000-0000-4000-8000-000000000001',true) ON CONFLICT(user_id) DO NOTHING;
SET LOCAL ROLE service_role;
DO $fixture$
DECLARE v_owner constant uuid:='00000000-0000-4000-8000-000000000001'; v_member jsonb; v_plan jsonb; v_purchase jsonb; v_payment jsonb;
BEGIN
    v_member:=api.owner_register_member(v_owner,'Attendance report synthetic',decode(repeat('a1',32),'hex'),decode(repeat('a2',32),'hex'));
    PERFORM set_config('gymforce.attendance_report_member',v_member->>'id',true);
    PERFORM api.owner_approve_member(v_owner,(v_member->>'id')::uuid,'Synthetic registration reviewed');
    PERFORM api.owner_create_verified_pin_enrollment_token(v_owner,(v_member->>'id')::uuid,repeat('9',64),'Synthetic identity checked');
    PERFORM api.member_enroll_pin(repeat('9',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGljLXNhbHQ$ZmFrZS12ZXJpZmllci1ub3QtYS1yZWFsLXBpbg');
    v_plan:=api.owner_save_membership_plan(v_owner,NULL,'Attendance report synthetic monthly',200,true);
    v_purchase:=api.owner_create_membership_purchase(v_owner,(v_member->>'id')::uuid,(v_plan->>'id')::uuid);
    v_payment:=api.owner_record_membership_payment(v_owner,gen_random_uuid(),(v_purchase->>'id')::uuid,200,'cash',NULL);
    PERFORM api.owner_confirm_membership_payment(v_owner,(v_payment->>'id')::uuid,true);
    PERFORM api.owner_activate_membership_purchase(v_owner,(v_purchase->>'id')::uuid);
    IF api.commit_member_checkin((v_member->>'id')::uuid,1) IS DISTINCT FROM '{"accepted":true}'::jsonb THEN
        RAISE EXCEPTION 'Attendance report fixture could not check in';
    END IF;
END;
$fixture$;
RESET ROLE;
DO $projection_and_filters$
DECLARE v_owner constant uuid:='00000000-0000-4000-8000-000000000001'; v_today date:=(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
    v_rows jsonb; v_attendance uuid; v_actor text;
BEGIN
    SELECT id INTO STRICT v_attendance FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.attendance_report_member')::uuid;
    INSERT INTO private.attendance_validity_resolutions(attendance_id,prior_status,new_status,reason,resolved_by,resolved_at)
    VALUES(v_attendance,'valid','review','Synthetic earlier review reason',v_owner,clock_timestamp()-interval '1 minute'),
          (v_attendance,'review','invalidated_correction','Synthetic latest documented reason',v_owner,clock_timestamp());
    UPDATE private.attendance_checkins SET attendance_status='invalidated_correction' WHERE id=v_attendance;
    SET LOCAL ROLE service_role;
    v_rows:=api.owner_list_attendance(v_owner,'Attendance report synthetic',v_today,v_today,'invalidated_correction',1,0);
    IF jsonb_array_length(v_rows)<>1 OR v_rows->0->>'id' IS DISTINCT FROM v_attendance::text
       OR v_rows->0->>'memberName' IS DISTINCT FROM 'Attendance report synthetic'
       OR v_rows->0->>'resolutionReason' IS DISTINCT FROM 'Synthetic latest documented reason'
       OR ((v_rows->0)-ARRAY['id','memberId','memberCode','memberName','walkinRequestId','gymLocalDate','checkedInAt','attendanceStatus','resolutionReason'])<>'{}'::jsonb THEN
        RAISE EXCEPTION 'Attendance projection lost history reason or exposed extra fields';
    END IF;
    IF api.owner_list_attendance(v_owner,'Attendance report synthetic',v_today,v_today,'valid')<>'[]'::jsonb
       OR api.owner_list_attendance(v_owner,'Attendance report synthetic',v_today+1,NULL,'all')<>'[]'::jsonb
       OR api.owner_list_attendance(v_owner,'Attendance report synthetic',NULL,NULL,'all',1,1)<>'[]'::jsonb THEN
        RAISE EXCEPTION 'Attendance status/date/pagination filter failed';
    END IF;
    BEGIN
        PERFORM api.owner_list_attendance(v_owner,NULL,NULL,NULL,'all',101,0);
        RAISE EXCEPTION 'Oversized attendance page allowed';
    EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'INVALID_ATTENDANCE_FILTERS' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.owner_list_attendance('00000000-0000-4000-8000-000000000002');
        RAISE EXCEPTION 'Non-Owner attendance report allowed';
    EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    RESET ROLE;
    FOREACH v_actor IN ARRAY ARRAY['anon','authenticated','gym_public_executor','gym_checkin_executor'] LOOP
        EXECUTE format('SET LOCAL ROLE %I',v_actor);
        BEGIN
            PERFORM api.owner_list_attendance(v_owner);
            RAISE EXCEPTION 'Untrusted attendance report access allowed';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        RESET ROLE;
    END LOOP;
END;
$projection_and_filters$;
ROLLBACK;
\echo 'PASS: Owner-only scoped attendance projection, invalidation reason, date/status filters and pagination.'
