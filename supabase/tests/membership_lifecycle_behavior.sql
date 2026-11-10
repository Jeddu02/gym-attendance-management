-- Disposable native synthetic database only. This does not certify GoTrue,
-- Edge JWT verification, hosted permissions or production release readiness.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL TIME ZONE 'America/New_York';
DO $synthetic_guard$
BEGIN
    IF current_database()<>'gymforce_batch1_synthetic'
       OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
        RAISE EXCEPTION 'Synthetic lifecycle target required';
    END IF;
END;
$synthetic_guard$;
INSERT INTO private.owner_access(user_id,is_active)
VALUES ('00000000-0000-4000-8000-000000000001',true)
ON CONFLICT (user_id) DO NOTHING;

DO $option_a$
DECLARE v record;
BEGIN
    FOR v IN SELECT * FROM (VALUES
        (date '2025-01-31',date '2025-02-27'),
        (date '2024-01-31',date '2024-02-28'),
        (date '2025-02-28',date '2025-03-27'),
        (date '2024-02-29',date '2024-03-28'),
        (date '2025-12-31',date '2026-01-30'),
        (date '2025-04-30',date '2025-05-29')) t(activation,expiry)
    LOOP
        IF private.membership_inclusive_expiry(v.activation) IS DISTINCT FROM v.expiry THEN
            RAISE EXCEPTION 'Option A failed for %',v.activation;
        END IF;
    END LOOP;
END;
$option_a$;

SET LOCAL ROLE service_role;
DO $approval_and_activation$
DECLARE
    owner_id constant uuid:='00000000-0000-4000-8000-000000000001';
    outsider constant uuid:='00000000-0000-4000-8000-000000000002';
    member jsonb; approved jsonb; retry jsonb; plan jsonb; purchase jsonb;
    receipt jsonb; activated jsonb; renewal jsonb; renewed jsonb; third jsonb;
    v_today date:=(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
    v_first_expiry date;
BEGIN
    member:=api.owner_register_member(owner_id,'Lifecycle synthetic member',decode(repeat('71',32),'hex'),decode(repeat('72',32),'hex'));
    PERFORM set_config('gymforce.lifecycle_member',member->>'id',true);
    BEGIN
        PERFORM api.owner_approve_member(outsider,(member->>'id')::uuid,'Synthetic unauthorized approval');
        RAISE EXCEPTION 'Non-Owner approval accepted';
    EXCEPTION WHEN insufficient_privilege THEN
        IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.owner_approve_member(owner_id,(member->>'id')::uuid,'x');
        RAISE EXCEPTION 'Missing approval reason accepted';
    EXCEPTION WHEN invalid_parameter_value THEN
        IF SQLERRM<>'INVALID_REGISTRATION_APPROVAL' THEN RAISE; END IF;
    END;
    approved:=api.owner_approve_member(owner_id,(member->>'id')::uuid,'Synthetic identity and registration reviewed');
    IF approved->>'status' IS DISTINCT FROM 'active' OR approved->>'replayed' IS DISTINCT FROM 'false'
       OR approved->>'approvedAt' IS NULL THEN RAISE EXCEPTION 'Approval result invalid'; END IF;
    retry:=api.owner_approve_member(owner_id,(member->>'id')::uuid,'Synthetic repeat approval');
    IF retry->>'approvedAt' IS DISTINCT FROM approved->>'approvedAt' OR retry->>'replayed' IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Approval retry changed original approval';
    END IF;
    plan:=api.owner_save_membership_plan(owner_id,NULL,'Lifecycle synthetic monthly',500,true);
    PERFORM set_config('gymforce.lifecycle_plan',plan->>'id',true);
    purchase:=api.owner_create_membership_purchase(owner_id,(member->>'id')::uuid,(plan->>'id')::uuid);
    PERFORM set_config('gymforce.lifecycle_purchase',purchase->>'id',true);
    BEGIN
        PERFORM api.owner_activate_membership_purchase(outsider,(purchase->>'id')::uuid);
        RAISE EXCEPTION 'Non-Owner activation accepted';
    EXCEPTION WHEN insufficient_privilege THEN
        IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.owner_activate_membership_purchase(owner_id,(purchase->>'id')::uuid);
        RAISE EXCEPTION 'Unpaid activation accepted';
    EXCEPTION WHEN invalid_parameter_value THEN
        IF SQLERRM<>'PURCHASE_NOT_READY_FOR_ACTIVATION' THEN RAISE; END IF;
    END;
    receipt:=api.owner_record_membership_payment(owner_id,gen_random_uuid(),(purchase->>'id')::uuid,500,'cash',NULL);
    PERFORM api.owner_confirm_membership_payment(owner_id,(receipt->>'id')::uuid,true);
    activated:=api.owner_activate_membership_purchase(owner_id,(purchase->>'id')::uuid);
    v_first_expiry:=(v_today::timestamp+interval '1 month')::date-1;
    IF activated->>'purchaseStatus' IS DISTINCT FROM 'active'
       OR (activated->>'activationDate')::date IS DISTINCT FROM v_today
       OR (activated->>'expiryDate')::date IS DISTINCT FROM v_first_expiry
       OR activated->>'replayed' IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'First activation did not use server Manila dates';
    END IF;
    retry:=api.owner_activate_membership_purchase(owner_id,(purchase->>'id')::uuid);
    IF retry->>'activationDate' IS DISTINCT FROM activated->>'activationDate'
       OR retry->>'expiryDate' IS DISTINCT FROM activated->>'expiryDate'
       OR retry->>'replayed' IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Activation retry changed original term';
    END IF;
    renewal:=api.owner_create_membership_purchase(owner_id,(member->>'id')::uuid,(plan->>'id')::uuid);
    receipt:=api.owner_record_membership_payment(owner_id,gen_random_uuid(),(renewal->>'id')::uuid,500,'cash',NULL);
    PERFORM api.owner_confirm_membership_payment(owner_id,(receipt->>'id')::uuid,true);
    renewed:=api.owner_activate_membership_purchase(owner_id,(renewal->>'id')::uuid);
    IF (renewed->>'activationDate')::date IS DISTINCT FROM v_first_expiry+1
       OR (renewed->>'expiryDate')::date IS DISTINCT FROM ((v_first_expiry+1)::timestamp+interval '1 month')::date-1 THEN
        RAISE EXCEPTION 'Early renewal is not consecutive';
    END IF;
    third:=api.owner_create_membership_purchase(owner_id,(member->>'id')::uuid,(plan->>'id')::uuid);
    receipt:=api.owner_record_membership_payment(owner_id,gen_random_uuid(),(third->>'id')::uuid,500,'cash',NULL);
    PERFORM api.owner_confirm_membership_payment(owner_id,(receipt->>'id')::uuid,true);
    PERFORM set_config('gymforce.lifecycle_queued_purchase',third->>'id',true);
    BEGIN
        PERFORM api.owner_activate_membership_purchase(owner_id,(third->>'id')::uuid);
        RAISE EXCEPTION 'Arbitrary additional prepaid term accepted';
    EXCEPTION WHEN invalid_parameter_value THEN
        IF SQLERRM<>'FUTURE_MEMBERSHIP_TERM_ALREADY_EXISTS' THEN RAISE; END IF;
    END;
END;
$approval_and_activation$;
RESET ROLE;

DO $state_and_audit$
DECLARE v_stream text; v_valid boolean; v_count bigint;
BEGIN
    IF (SELECT count(*) FROM private.audit_events WHERE event_type='member.registration_approved'
        AND subject_id=current_setting('gymforce.lifecycle_member'))<>1 THEN
        RAISE EXCEPTION 'Approval retry duplicated audit history';
    END IF;
    IF (SELECT count(*) FROM private.audit_events WHERE event_type='membership_purchase.activated'
        AND subject_id=current_setting('gymforce.lifecycle_purchase'))<>1 THEN
        RAISE EXCEPTION 'Activation retry duplicated audit history';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM private.membership_purchases WHERE
        id=current_setting('gymforce.lifecycle_queued_purchase')::uuid
        AND purchase_status='pending_activation' AND activation_date IS NULL AND expiry_date IS NULL) THEN
        RAISE EXCEPTION 'Denied future activation rewrote paid-purchase history';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM private.payment_events e
        JOIN private.payment_records r ON r.id=e.payment_id
        WHERE r.target_membership_purchase_id=current_setting('gymforce.lifecycle_purchase')::uuid
          AND e.event_type='payment.confirmed' AND e.created_at>pg_catalog.transaction_timestamp()) THEN
        RAISE EXCEPTION 'Confirmation event incorrectly retained the transaction-start timestamp';
    END IF;
    -- Writes occurred under New York; hash verification must survive a switch.
    SET LOCAL TIME ZONE 'Asia/Tokyo';
    FOREACH v_stream IN ARRAY ARRAY['members','membership_plans','membership_purchases','payments'] LOOP
        SELECT is_valid,checked_events INTO v_valid,v_count FROM api.verify_audit_stream(v_stream);
        IF v_valid IS DISTINCT FROM true OR COALESCE(v_count,0)<=0 THEN
            RAISE EXCEPTION 'Missing or invalid lifecycle audit stream %',v_stream;
        END IF;
    END LOOP;
END;
$state_and_audit$;

SET LOCAL ROLE gym_owner_executor;
DO $guard_denials$
BEGIN
    BEGIN
        UPDATE private.membership_purchases SET expiry_date=expiry_date+1
        WHERE id=current_setting('gymforce.lifecycle_purchase')::uuid;
        RAISE EXCEPTION 'Expiry override accepted';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN
        IF SQLERRM<>'MEMBERSHIP_TERM_IMMUTABLE' THEN RAISE; END IF;
    END;
    BEGIN
        UPDATE private.members SET approved_at=pg_catalog.clock_timestamp()
        WHERE id=current_setting('gymforce.lifecycle_member')::uuid;
        RAISE EXCEPTION 'Original approval rewritten';
    EXCEPTION WHEN check_violation THEN
        IF SQLERRM<>'REGISTRATION_APPROVAL_TRANSITION_INVALID' THEN RAISE; END IF;
    END;
    BEGIN
        UPDATE private.members SET status='pending',approved_at=NULL
        WHERE id=current_setting('gymforce.lifecycle_member')::uuid;
        RAISE EXCEPTION 'Registration reversal accepted';
    EXCEPTION WHEN check_violation THEN
        IF SQLERRM<>'REGISTRATION_APPROVAL_TRANSITION_INVALID' THEN RAISE; END IF;
    END;
END;
$guard_denials$;
RESET ROLE;

-- Controlled nested audit failure: temporarily revoke only the audit helper's
-- Owner-executor EXECUTE inside a subtransaction. The expected exception rolls
-- back both that temporary revoke and all writes by the approval/activation RPC.
SET LOCAL ROLE service_role;
DO $rollback_fixture$
DECLARE v_member jsonb;
BEGIN
    v_member:=api.owner_register_member('00000000-0000-4000-8000-000000000001',
        'Lifecycle rollback synthetic',decode(repeat('73',32),'hex'),decode(repeat('74',32),'hex'));
    PERFORM set_config('gymforce.lifecycle_rollback_member',v_member->>'id',true);
END;
$rollback_fixture$;
RESET ROLE;
DO $approval_atomicity$
DECLARE v_before bigint;
BEGIN
    SELECT count(*) INTO v_before FROM private.audit_events;
    BEGIN
        REVOKE EXECUTE ON FUNCTION private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz)
            FROM gym_owner_executor;
        SET LOCAL ROLE service_role;
        PERFORM api.owner_approve_member('00000000-0000-4000-8000-000000000001',
            current_setting('gymforce.lifecycle_rollback_member')::uuid,'Synthetic rollback approval');
        RAISE EXCEPTION 'Nested audit failure did not abort approval';
    EXCEPTION WHEN insufficient_privilege THEN
        RESET ROLE;
        IF pg_catalog.strpos(SQLERRM,'compute_audit_event_hash')=0 THEN RAISE; END IF;
    END;
    IF NOT EXISTS (SELECT 1 FROM private.members WHERE id=current_setting('gymforce.lifecycle_rollback_member')::uuid
        AND status='pending' AND approved_at IS NULL) OR
        (SELECT count(*) FROM private.audit_events)<>v_before THEN
        RAISE EXCEPTION 'Approval retained partial state after nested audit failure';
    END IF;
END;
$approval_atomicity$;

SET LOCAL ROLE service_role;
DO $activation_rollback_fixture$
DECLARE v_purchase jsonb; v_receipt jsonb;
BEGIN
    PERFORM api.owner_approve_member('00000000-0000-4000-8000-000000000001',
        current_setting('gymforce.lifecycle_rollback_member')::uuid,'Synthetic approval after rollback');
    v_purchase:=api.owner_create_membership_purchase('00000000-0000-4000-8000-000000000001',
        current_setting('gymforce.lifecycle_rollback_member')::uuid,current_setting('gymforce.lifecycle_plan')::uuid);
    v_receipt:=api.owner_record_membership_payment('00000000-0000-4000-8000-000000000001',gen_random_uuid(),
        (v_purchase->>'id')::uuid,500,'cash',NULL);
    PERFORM api.owner_confirm_membership_payment('00000000-0000-4000-8000-000000000001',(v_receipt->>'id')::uuid,true);
    PERFORM set_config('gymforce.lifecycle_rollback_purchase',v_purchase->>'id',true);
END;
$activation_rollback_fixture$;
RESET ROLE;
DO $activation_atomicity$
DECLARE v_before bigint;
BEGIN
    SELECT count(*) INTO v_before FROM private.audit_events;
    BEGIN
        REVOKE EXECUTE ON FUNCTION private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz)
            FROM gym_owner_executor;
        SET LOCAL ROLE service_role;
        PERFORM api.owner_activate_membership_purchase('00000000-0000-4000-8000-000000000001',
            current_setting('gymforce.lifecycle_rollback_purchase')::uuid);
        RAISE EXCEPTION 'Nested audit failure did not abort activation';
    EXCEPTION WHEN insufficient_privilege THEN
        RESET ROLE;
        IF pg_catalog.strpos(SQLERRM,'compute_audit_event_hash')=0 THEN RAISE; END IF;
    END;
    IF NOT EXISTS (SELECT 1 FROM private.membership_purchases WHERE
        id=current_setting('gymforce.lifecycle_rollback_purchase')::uuid AND purchase_status='pending_activation'
        AND activation_date IS NULL AND expiry_date IS NULL) OR
        (SELECT count(*) FROM private.audit_events)<>v_before THEN
        RAISE EXCEPTION 'Activation retained partial state after nested audit failure';
    END IF;
END;
$activation_atomicity$;

-- Historical dates below are deliberate administrator-created SYNTHETIC facts,
-- not client claims or a production backdating interface. Seed only new fixture
-- records; do not disable guards, update append-only events or change old terms.
-- This models payment confirmed before a prior expiry but finalized afterwards.
SET LOCAL ROLE service_role;
DO $historical_member_fixture$
DECLARE v_member jsonb;
BEGIN
    v_member:=api.owner_register_member('00000000-0000-4000-8000-000000000001',
        'Historical lifecycle synthetic',decode(repeat('75',32),'hex'),decode(repeat('76',32),'hex'));
    PERFORM set_config('gymforce.lifecycle_historical_member',v_member->>'id',true);
END;
$historical_member_fixture$;
RESET ROLE;
UPDATE private.members SET created_at=pg_catalog.clock_timestamp()-interval '6 months'
WHERE id=current_setting('gymforce.lifecycle_historical_member')::uuid;
SET LOCAL ROLE gym_owner_executor;
UPDATE private.members SET status='active',approved_at=pg_catalog.clock_timestamp()-interval '5 months'
WHERE id=current_setting('gymforce.lifecycle_historical_member')::uuid;
RESET ROLE;

DO $historical_terms$
DECLARE
    v_owner constant uuid:='00000000-0000-4000-8000-000000000001';
    v_member uuid:=current_setting('gymforce.lifecycle_historical_member')::uuid;
    v_plan uuid:=current_setting('gymforce.lifecycle_plan')::uuid;
    v_first_date date:=((pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date-interval '4 months')::date;
    v_prior_expiry date;
    v_confirmation date;
    v_purchase jsonb;
    v_receipt uuid;
    v_activated jsonb;
    v_first_purchase uuid;
    v_delayed_purchase uuid;
    v_fresh jsonb;
    v_payment jsonb;
    v_today date:=(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
BEGIN
    v_prior_expiry:=private.membership_inclusive_expiry(v_first_date);
    SET LOCAL ROLE service_role;
    v_purchase:=api.owner_create_membership_purchase(v_owner,v_member,v_plan);
    RESET ROLE;
    v_first_purchase:=(v_purchase->>'id')::uuid;
    INSERT INTO private.payment_records(amount_php,payment_method,verification_status,recorded_by,
        target_membership_purchase_id,received_at,created_at)
    VALUES (500,'cash','recorded',v_owner,v_first_purchase,
        v_first_date::timestamp AT TIME ZONE 'Asia/Manila',v_first_date::timestamp AT TIME ZONE 'Asia/Manila')
    RETURNING id INTO v_receipt;
    UPDATE private.payment_records SET verification_status='confirmed' WHERE id=v_receipt;
    INSERT INTO private.payment_events(payment_id,event_type,reason,actor_user_id,created_at)
    VALUES (v_receipt,'payment.confirmed','Synthetic historical server-event fixture',v_owner,
        v_first_date::timestamp AT TIME ZONE 'Asia/Manila');
    INSERT INTO private.payment_allocations(payment_id,membership_purchase_id,allocated_by)
    VALUES (v_receipt,v_first_purchase,v_owner);
    UPDATE private.membership_purchases SET purchase_status='pending_activation' WHERE id=v_first_purchase;
    SET LOCAL ROLE service_role;
    v_activated:=api.owner_activate_membership_purchase(v_owner,v_first_purchase);
    RESET ROLE;
    IF (v_activated->>'activationDate')::date IS DISTINCT FROM v_first_date
       OR (v_activated->>'expiryDate')::date IS DISTINCT FROM v_prior_expiry THEN
        RAISE EXCEPTION 'Historical first term did not use confirmation date';
    END IF;

    SET LOCAL ROLE service_role;
    v_purchase:=api.owner_create_membership_purchase(v_owner,v_member,v_plan);
    RESET ROLE;
    v_delayed_purchase:=(v_purchase->>'id')::uuid;
    v_confirmation:=v_prior_expiry-2;
    INSERT INTO private.payment_records(amount_php,payment_method,verification_status,recorded_by,
        target_membership_purchase_id,received_at,created_at)
    VALUES (500,'cash','recorded',v_owner,v_delayed_purchase,
        v_confirmation::timestamp AT TIME ZONE 'Asia/Manila',v_confirmation::timestamp AT TIME ZONE 'Asia/Manila')
    RETURNING id INTO v_receipt;
    UPDATE private.payment_records SET verification_status='confirmed' WHERE id=v_receipt;
    INSERT INTO private.payment_events(payment_id,event_type,reason,actor_user_id,created_at)
    VALUES (v_receipt,'payment.confirmed','Synthetic confirmation before prior inclusive expiry',v_owner,
        v_confirmation::timestamp AT TIME ZONE 'Asia/Manila');
    INSERT INTO private.payment_allocations(payment_id,membership_purchase_id,allocated_by)
    VALUES (v_receipt,v_delayed_purchase,v_owner);
    UPDATE private.membership_purchases SET purchase_status='pending_activation' WHERE id=v_delayed_purchase;
    SET LOCAL ROLE service_role;
    v_activated:=api.owner_activate_membership_purchase(v_owner,v_delayed_purchase);
    RESET ROLE;
    IF (v_activated->>'activationDate')::date IS DISTINCT FROM v_prior_expiry+1
       OR (v_activated->>'expiryDate')::date IS DISTINCT FROM private.membership_inclusive_expiry(v_prior_expiry+1) THEN
        RAISE EXCEPTION 'Delayed finalization did not preserve consecutive early renewal';
    END IF;

    -- A real current server confirmation after all historical terms lapsed
    -- starts today, not the day after the historical expiry.
    SET LOCAL ROLE service_role;
    v_fresh:=api.owner_create_membership_purchase(v_owner,v_member,v_plan);
    v_payment:=api.owner_record_membership_payment(v_owner,gen_random_uuid(),(v_fresh->>'id')::uuid,500,'cash',NULL);
    PERFORM api.owner_confirm_membership_payment(v_owner,(v_payment->>'id')::uuid,true);
    v_activated:=api.owner_activate_membership_purchase(v_owner,(v_fresh->>'id')::uuid);
    RESET ROLE;
    IF (v_activated->>'activationDate')::date IS DISTINCT FROM v_today THEN
        RAISE EXCEPTION 'Lapsed renewal was backdated';
    END IF;
END;
$historical_terms$;

DO $entrypoint_boundaries$
DECLARE v_actor text;
BEGIN
    FOREACH v_actor IN ARRAY ARRAY['anon','authenticated','gym_public_executor'] LOOP
        EXECUTE format('SET LOCAL ROLE %I',v_actor);
        BEGIN
            PERFORM api.owner_approve_member('00000000-0000-4000-8000-000000000001',
                current_setting('gymforce.lifecycle_member')::uuid,'Synthetic forbidden call');
            RAISE EXCEPTION 'Forbidden approval entrypoint allowed for %',v_actor;
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        BEGIN
            PERFORM api.owner_activate_membership_purchase('00000000-0000-4000-8000-000000000001',
                current_setting('gymforce.lifecycle_purchase')::uuid);
            RAISE EXCEPTION 'Forbidden activation entrypoint allowed for %',v_actor;
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        RESET ROLE;
    END LOOP;
END;
$entrypoint_boundaries$;
ROLLBACK;
\echo 'PASS: synthetic approval, paid activation, Option A, consecutive renewal, queued-term denial, immutable replay, audit and rollback.'
