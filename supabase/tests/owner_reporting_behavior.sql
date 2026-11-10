-- Native disposable synthetic fixtures only; not an attendance/payment workflow.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL TIME ZONE 'America/Los_Angeles';
DO $synthetic_guard$
BEGIN
    IF current_database()<>'gymforce_batch1_synthetic'
       OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
        RAISE EXCEPTION 'Synthetic reporting target required';
    END IF;
END;
$synthetic_guard$;
INSERT INTO private.owner_access(user_id,is_active)
VALUES ('00000000-0000-4000-8000-000000000001',true)
ON CONFLICT(user_id) DO NOTHING;

SET LOCAL ROLE service_role;
DO $member_summary$
DECLARE
    v_owner constant uuid:='00000000-0000-4000-8000-000000000001';
    v_base jsonb; v_summary jsonb; v_member jsonb; v_plan jsonb; v_purchase jsonb; v_receipt jsonb;
BEGIN
    v_base:=api.owner_dashboard_summary(v_owner);
    PERFORM set_config('gymforce.reporting_base',v_base::text,true);
    v_member:=api.owner_register_member(v_owner,'Reporting synthetic member',decode(repeat('81',32),'hex'),decode(repeat('82',32),'hex'));
    PERFORM set_config('gymforce.reporting_member',v_member->>'id',true);
    v_summary:=api.owner_dashboard_summary(v_owner);
    IF (v_summary->>'totalMembers')::bigint IS DISTINCT FROM (v_base->>'totalMembers')::bigint+1
       OR v_summary->>'approvedMembers' IS DISTINCT FROM v_base->>'approvedMembers'
       OR v_summary->>'currentEntitlements' IS DISTINCT FROM v_base->>'currentEntitlements' THEN
        RAISE EXCEPTION 'Pending registration was reported as approved/eligible';
    END IF;
    PERFORM api.owner_approve_member(v_owner,(v_member->>'id')::uuid,'Synthetic reporting identity review');
    v_summary:=api.owner_dashboard_summary(v_owner);
    IF (v_summary->>'approvedMembers')::bigint IS DISTINCT FROM (v_base->>'approvedMembers')::bigint+1
       OR v_summary->>'currentEntitlements' IS DISTINCT FROM v_base->>'currentEntitlements' THEN
        RAISE EXCEPTION 'Registration approval incorrectly created membership entitlement';
    END IF;
    v_plan:=api.owner_save_membership_plan(v_owner,NULL,'Reporting synthetic monthly',50,true);
    PERFORM set_config('gymforce.reporting_plan',v_plan->>'id',true);
    v_purchase:=api.owner_create_membership_purchase(v_owner,(v_member->>'id')::uuid,(v_plan->>'id')::uuid);
    v_receipt:=api.owner_record_membership_payment(v_owner,gen_random_uuid(),(v_purchase->>'id')::uuid,50,'cash',NULL);
    v_summary:=api.owner_dashboard_summary(v_owner);
    IF v_summary->>'confirmedMembershipIncomePhp' IS DISTINCT FROM v_base->>'confirmedMembershipIncomePhp' THEN
        RAISE EXCEPTION 'Pending receipt counted as confirmed membership income';
    END IF;
    PERFORM api.owner_confirm_membership_payment(v_owner,(v_receipt->>'id')::uuid,true);
    v_summary:=api.owner_dashboard_summary(v_owner);
    IF (v_summary->>'confirmedMembershipIncomePhp')::numeric IS DISTINCT FROM
        (v_base->>'confirmedMembershipIncomePhp')::numeric+50
       OR v_summary->>'currentEntitlements' IS DISTINCT FROM v_base->>'currentEntitlements' THEN
        RAISE EXCEPTION 'Confirmed paid status was confused with activated entitlement';
    END IF;
    PERFORM api.owner_activate_membership_purchase(v_owner,(v_purchase->>'id')::uuid);
    v_summary:=api.owner_dashboard_summary(v_owner);
    IF (v_summary->>'currentEntitlements')::bigint IS DISTINCT FROM (v_base->>'currentEntitlements')::bigint+1 THEN
        RAISE EXCEPTION 'Current paid approved entitlement missing from summary';
    END IF;
    v_purchase:=api.owner_create_membership_purchase(v_owner,(v_member->>'id')::uuid,(v_plan->>'id')::uuid);
    v_receipt:=api.owner_record_membership_payment(v_owner,gen_random_uuid(),(v_purchase->>'id')::uuid,49,'cash',NULL);
    IF v_receipt->>'verificationStatus' IS DISTINCT FROM 'rejected' THEN
        RAISE EXCEPTION 'Unexpected legacy mismatched-receipt fixture state';
    END IF;
    -- This asserts reporting only; it does not endorse or implement the legacy
    -- rejected-underpayment path as the required separate Owner receipt review.
    v_summary:=api.owner_dashboard_summary(v_owner);
    IF (v_summary->>'confirmedMembershipIncomePhp')::numeric IS DISTINCT FROM
        (v_base->>'confirmedMembershipIncomePhp')::numeric+50 THEN
        RAISE EXCEPTION 'Rejected/underpaid receipt counted as confirmed income';
    END IF;
END;
$member_summary$;
RESET ROLE;

-- Administrator-created mock walk-in facts exercise accounting filters only.
-- Their arbitrary fixture timestamps are NOT a production request lifetime.
DO $receipt_and_attendance_fixtures$
DECLARE
    v_owner constant uuid:='00000000-0000-4000-8000-000000000001';
    v_today date:=(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
    v_fee uuid; v_walkin uuid; v_receipt uuid; v_summary jsonb;
    v_base jsonb:=current_setting('gymforce.reporting_base')::jsonb;
BEGIN
    INSERT INTO private.walkin_fee_versions(fee_php,created_by) VALUES(75,v_owner) RETURNING id INTO v_fee;
    INSERT INTO private.walkin_requests(fee_version_id,fee_php,expires_at,request_status,confirmed_by,confirmed_at)
    VALUES(v_fee,75,pg_catalog.clock_timestamp()+interval '1 hour','confirmed',v_owner,pg_catalog.clock_timestamp())
    RETURNING id INTO v_walkin;
    INSERT INTO private.payment_records(amount_php,payment_method,verification_status,recorded_by)
    VALUES(75,'cash','confirmed',v_owner) RETURNING id INTO v_receipt;
    INSERT INTO private.payment_allocations(payment_id,walkin_request_id,allocated_by)
    VALUES(v_receipt,v_walkin,v_owner);
    INSERT INTO private.payment_records(amount_php,payment_method,verification_status,recorded_by)
    VALUES(999,'cash','confirmed',v_owner),(111,'cash','recorded',v_owner),(222,'cash','rejected',v_owner);
    INSERT INTO private.attendance_checkins(member_id,gym_local_date,attendance_status)
    VALUES(current_setting('gymforce.reporting_member')::uuid,v_today,'valid'),
          (current_setting('gymforce.reporting_member')::uuid,v_today,'invalidated_payment'),
          (current_setting('gymforce.reporting_member')::uuid,v_today-1,'valid');
    SET LOCAL ROLE service_role;
    v_summary:=api.owner_dashboard_summary(v_owner);
    RESET ROLE;
    IF (v_summary->>'confirmedWalkinIncomePhp')::numeric IS DISTINCT FROM
        (v_base->>'confirmedWalkinIncomePhp')::numeric+75
       OR (v_summary->>'confirmedMembershipIncomePhp')::numeric IS DISTINCT FROM
        (v_base->>'confirmedMembershipIncomePhp')::numeric+50 THEN
        RAISE EXCEPTION 'Income included unallocated receipts or mixed allocation targets';
    END IF;
    IF (v_summary->>'todayValidCheckins')::bigint IS DISTINCT FROM (v_base->>'todayValidCheckins')::bigint+1 THEN
        RAISE EXCEPTION 'Attendance summary included invalidated or other-date history';
    END IF;
END;
$receipt_and_attendance_fixtures$;

SET LOCAL ROLE service_role;
DO $audit_projection$
DECLARE
    v_owner constant uuid:='00000000-0000-4000-8000-000000000001';
    v_today date:=(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
    v_events jsonb; v_next jsonb; v_event jsonb; v_case record;
BEGIN
    PERFORM api.append_audit_event('reporting-fixture',v_owner,'reporting.synthetic.a','reporting_fixture','fixture-a',
        '{"reason":"Reporting reason A","privateNote":"SYNTHETIC_HIDDEN_MARKER"}'::jsonb);
    PERFORM api.append_audit_event('reporting-fixture',v_owner,'reporting.synthetic.b','reporting_fixture','fixture-b',
        '{"reason":"Reporting reason B"}'::jsonb);
    PERFORM api.append_audit_event('reporting-fixture',v_owner,'reporting.synthetic.c','reporting_fixture','fixture-c',
        '{"reason":"Reporting reason C"}'::jsonb);
    v_events:=api.owner_list_audit_events(v_owner,'reporting.synthetic.',v_today,v_today,2,0);
    v_next:=api.owner_list_audit_events(v_owner,'reporting.synthetic.',v_today,v_today,2,2);
    IF jsonb_array_length(v_events)<>2 OR jsonb_array_length(v_next)<>1
       OR v_events->0->>'eventType' IS DISTINCT FROM 'reporting.synthetic.c'
       OR v_events->1->>'eventType' IS DISTINCT FROM 'reporting.synthetic.b'
       OR v_next->0->>'eventType' IS DISTINCT FROM 'reporting.synthetic.a' THEN
        RAISE EXCEPTION 'Audit date filter/order/pagination incorrect';
    END IF;
    FOR v_event IN SELECT value FROM jsonb_array_elements(v_events||v_next) LOOP
        IF jsonb_typeof(v_event->'id') IS DISTINCT FROM 'string'
           OR v_event->>'actorUserId' IS DISTINCT FROM v_owner::text
           OR v_event->>'reason' IS NULL
           OR (v_event-ARRAY['id','actorUserId','eventType','subjectType','subjectId','createdAt','reason'])<>'{}'::jsonb
           OR v_event::text LIKE '%SYNTHETIC_HIDDEN_MARKER%' THEN
            RAISE EXCEPTION 'Audit projection exposed unapproved fields or lost string IDs';
        END IF;
    END LOOP;
    IF api.owner_list_audit_events(v_owner,'SYNTHETIC_HIDDEN_MARKER')<>'[]'::jsonb
       OR api.owner_list_audit_events(v_owner,'reporting.synthetic.',v_today+1,NULL)<>'[]'::jsonb THEN
        RAISE EXCEPTION 'Audit search scanned hidden details or crossed Manila date bounds';
    END IF;
    FOR v_case IN SELECT * FROM (VALUES(0,0),(101,0),(1,-1),(1,100001),(NULL::integer,0),(1,NULL::integer)) t(page_limit,page_offset) LOOP
        BEGIN
            PERFORM api.owner_list_audit_events(v_owner,NULL,NULL,NULL,v_case.page_limit,v_case.page_offset);
            RAISE EXCEPTION 'Invalid audit pagination accepted';
        EXCEPTION WHEN invalid_parameter_value THEN
            IF SQLERRM<>'INVALID_AUDIT_FILTERS' THEN RAISE; END IF;
        END;
    END LOOP;
    BEGIN
        PERFORM api.owner_list_audit_events(v_owner,repeat('x',81));
        RAISE EXCEPTION 'Overlong audit search accepted';
    EXCEPTION WHEN invalid_parameter_value THEN
        IF SQLERRM<>'INVALID_AUDIT_FILTERS' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.owner_list_audit_events(v_owner,NULL,v_today+1,v_today);
        RAISE EXCEPTION 'Reversed audit date bounds accepted';
    EXCEPTION WHEN invalid_parameter_value THEN
        IF SQLERRM<>'INVALID_AUDIT_FILTERS' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.owner_list_audit_events(v_owner,NULL,'infinity'::date,NULL);
        RAISE EXCEPTION 'Infinite audit date accepted';
    EXCEPTION WHEN invalid_parameter_value THEN
        IF SQLERRM<>'INVALID_AUDIT_FILTERS' THEN RAISE; END IF;
    END;
END;
$audit_projection$;
RESET ROLE;

DO $report_authorization$
DECLARE v_actor text;
BEGIN
    SET LOCAL ROLE service_role;
    BEGIN
        PERFORM api.owner_dashboard_summary('00000000-0000-4000-8000-000000000002');
        RAISE EXCEPTION 'Non-Owner summary allowed';
    EXCEPTION WHEN insufficient_privilege THEN
        IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.owner_list_audit_events(NULL);
        RAISE EXCEPTION 'Null-actor audit access allowed';
    EXCEPTION WHEN insufficient_privilege THEN
        IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    RESET ROLE;
    BEGIN
        UPDATE private.owner_access SET is_active=false,deactivated_at=pg_catalog.clock_timestamp()
        WHERE user_id='00000000-0000-4000-8000-000000000001';
        SET LOCAL ROLE service_role;
        PERFORM api.owner_dashboard_summary('00000000-0000-4000-8000-000000000001');
        RAISE EXCEPTION 'Revoked Owner summary allowed';
    EXCEPTION WHEN insufficient_privilege THEN
        RESET ROLE;
        IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    FOREACH v_actor IN ARRAY ARRAY['anon','authenticated','gym_public_executor'] LOOP
        EXECUTE format('SET LOCAL ROLE %I',v_actor);
        BEGIN
            PERFORM api.owner_dashboard_summary('00000000-0000-4000-8000-000000000001');
            RAISE EXCEPTION 'Unauthorized summary entrypoint allowed';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        BEGIN
            PERFORM api.owner_list_audit_events('00000000-0000-4000-8000-000000000001');
            RAISE EXCEPTION 'Unauthorized audit entrypoint allowed';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        RESET ROLE;
    END LOOP;
    FOREACH v_actor IN ARRAY ARRAY['anon','authenticated','service_role','gym_public_executor'] LOOP
        IF pg_catalog.has_any_column_privilege(v_actor,'private.attendance_checkins','SELECT,INSERT,UPDATE,REFERENCES')
          OR pg_catalog.has_table_privilege(v_actor,'private.attendance_checkins','DELETE,TRUNCATE,TRIGGER') THEN
            RAISE EXCEPTION 'Reporting broadened direct attendance access';
        END IF;
    END LOOP;
    IF pg_catalog.has_table_privilege('gym_owner_executor','private.attendance_checkins','INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
       OR pg_catalog.has_any_column_privilege('gym_owner_executor','private.attendance_checkins','INSERT,UPDATE,REFERENCES')
       OR pg_catalog.has_column_privilege('gym_owner_executor','private.attendance_checkins','member_id','SELECT')
       OR pg_catalog.has_column_privilege('gym_owner_executor','private.attendance_checkins','id','SELECT') THEN
        RAISE EXCEPTION 'Reporting granted attendance writes or unnecessary identity access';
    END IF;
END;
$report_authorization$;
ROLLBACK;
\echo 'PASS: Owner-only summary accounting, eligibility, attendance status, redacted audit filters and bounded pagination (synthetic SQL).'
