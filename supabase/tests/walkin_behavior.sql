-- Disposable native synthetic tests only. Does not authorize production fees,
-- abuse thresholds, cloud changes, receipt resolution or cash reconciliation.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL TIME ZONE 'America/New_York';
DO $guard$
BEGIN
    IF current_database()<>'gymforce_batch1_synthetic'
       OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN
        RAISE EXCEPTION 'Synthetic walk-in target required';
    END IF;
END;
$guard$;
INSERT INTO private.owner_access(user_id,is_active)
VALUES('00000000-0000-4000-8000-000000000001',true) ON CONFLICT(user_id) DO NOTHING;

SET LOCAL ROLE service_role;
DO $requests_and_receipts$
DECLARE
    v_owner constant uuid:='00000000-0000-4000-8000-000000000001';
    v_fee jsonb; v_first jsonb; v_second jsonb; v_third jsonb; v_result jsonb; v_retry jsonb;
    v_op uuid:=gen_random_uuid(); v_review_op uuid:=gen_random_uuid(); v_summary jsonb; v_base jsonb;
BEGIN
    v_base:=api.owner_dashboard_summary(v_owner);
    PERFORM set_config('gymforce.walkin_base',v_base::text,true);
    BEGIN
        PERFORM api.owner_set_walkin_fee('00000000-0000-4000-8000-000000000002',100,'Synthetic unauthorized fee');
        RAISE EXCEPTION 'Non-Owner fee change allowed';
    EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.owner_set_walkin_fee(v_owner,0,'Synthetic invalid fee');
        RAISE EXCEPTION 'Nonpositive walk-in fee allowed';
    EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'INVALID_WALKIN_FEE' THEN RAISE; END IF;
    END;
    v_fee:=api.owner_set_walkin_fee(v_owner,100,'Synthetic opening walk-in fee');
    IF v_fee->>'currency' IS DISTINCT FROM 'PHP' OR (v_fee->>'feePhp')::numeric IS DISTINCT FROM 100 THEN
        RAISE EXCEPTION 'Owner fee snapshot invalid';
    END IF;
    PERFORM set_config('gymforce.walkin_first_fee',v_fee->>'id',true);
    v_first:=api.public_create_walkin_request('cash',100);
    IF (v_first->>'expiresAt')::timestamptz-(v_first->>'createdAt')::timestamptz IS DISTINCT FROM interval '15 minutes'
       OR v_first->>'paymentMethod' IS DISTINCT FROM 'cash' OR (v_first->>'feePhp')::numeric IS DISTINCT FROM 100 THEN
        RAISE EXCEPTION 'Public request did not freeze the 15-minute server snapshot';
    END IF;
    PERFORM set_config('gymforce.walkin_first_request',v_first->>'id',true);
    PERFORM api.owner_set_walkin_fee(v_owner,120,'Synthetic next fee version');
    v_second:=api.public_create_walkin_request('gcash',100);
    IF (v_second->>'feePhp')::numeric IS DISTINCT FROM 120 OR v_second->>'id'=v_first->>'id' THEN
        RAISE EXCEPTION 'New request reused an old ID or fee';
    END IF;
    PERFORM set_config('gymforce.walkin_second_request',v_second->>'id',true);
    BEGIN
        PERFORM api.public_create_walkin_request('cash',1);
        RAISE EXCEPTION 'Rolling-minute rate cap was bypassed';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'WALKIN_RATE_LIMITED' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.public_create_walkin_request('cash',NULL);
        RAISE EXCEPTION 'Missing explicit rate configuration accepted';
    EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'INVALID_WALKIN_REQUEST' THEN RAISE; END IF;
    END;
    BEGIN
        PERFORM api.owner_confirm_walkin('00000000-0000-4000-8000-000000000002',(v_first->>'id')::uuid,
            gen_random_uuid(),100,'cash',false);
        RAISE EXCEPTION 'Non-Owner confirmed a receipt';
    EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF;
    END;
    v_result:=api.owner_confirm_walkin(v_owner,(v_first->>'id')::uuid,v_op,100,'cash',false);
    IF v_result->>'outcome' IS DISTINCT FROM 'confirmed' OR v_result->>'attendanceId' IS NULL
       OR v_result->>'paymentId' IS NULL OR v_result->>'replayed' IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'Full actual cash receipt did not validate attendance';
    END IF;
    PERFORM set_config('gymforce.walkin_first_payment',v_result->>'paymentId',true);
    PERFORM set_config('gymforce.walkin_first_attendance',v_result->>'attendanceId',true);
    v_retry:=api.owner_confirm_walkin(v_owner,(v_first->>'id')::uuid,v_op,100,'cash',false);
    IF v_retry->>'paymentId' IS DISTINCT FROM v_result->>'paymentId'
       OR v_retry->>'attendanceId' IS DISTINCT FROM v_result->>'attendanceId'
       OR v_retry->>'replayed' IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Receipt replay changed original payment or attendance';
    END IF;
    BEGIN
        PERFORM api.owner_confirm_walkin(v_owner,(v_first->>'id')::uuid,v_op,101,'cash',false);
        RAISE EXCEPTION 'Changed receipt operation accepted';
    EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'WALKIN_OPERATION_CONFLICT' THEN RAISE; END IF;
    END;
    v_result:=api.owner_confirm_walkin(v_owner,(v_first->>'id')::uuid,gen_random_uuid(),100,'cash',false);
    IF v_result->>'outcome' IS DISTINCT FROM 'receipt_review' OR v_result ? 'attendanceId' THEN
        RAISE EXCEPTION 'Additional actual receipt duplicated attendance instead of review';
    END IF;
    BEGIN
        PERFORM api.owner_confirm_walkin(v_owner,(v_second->>'id')::uuid,gen_random_uuid(),120,'gcash',false);
        RAISE EXCEPTION 'Electronic payment accepted without evidence review';
    EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'PAYMENT_EVIDENCE_REQUIRED' THEN RAISE; END IF;
    END;
    v_result:=api.owner_confirm_walkin(v_owner,(v_second->>'id')::uuid,v_review_op,119,'gcash',true);
    IF v_result->>'outcome' IS DISTINCT FROM 'receipt_review' OR v_result ? 'attendanceId' THEN
        RAISE EXCEPTION 'Underpaid actual receipt created attendance';
    END IF;
    PERFORM set_config('gymforce.walkin_underpaid_payment',v_result->>'paymentId',true);
    v_retry:=api.owner_confirm_walkin(v_owner,(v_second->>'id')::uuid,v_review_op,119,'gcash',true);
    IF v_retry->>'paymentId' IS DISTINCT FROM v_result->>'paymentId' OR v_retry->>'replayed' IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Review receipt replay duplicated or changed actual money';
    END IF;
    v_result:=api.owner_confirm_walkin(v_owner,(v_second->>'id')::uuid,gen_random_uuid(),120,'gcash',true);
    IF v_result->>'outcome' IS DISTINCT FROM 'confirmed' THEN RAISE EXCEPTION 'Full new electronic receipt failed'; END IF;
    v_third:=api.public_create_walkin_request('cash',100);
    v_result:=api.owner_confirm_walkin(v_owner,(v_third->>'id')::uuid,gen_random_uuid(),120,'bank_transfer',true);
    IF v_result->>'outcome' IS DISTINCT FROM 'receipt_review' THEN
        RAISE EXCEPTION 'Actual method mismatch rewrote immutable selected method';
    END IF;
    PERFORM set_config('gymforce.walkin_method_payment',v_result->>'paymentId',true);
    v_summary:=api.owner_dashboard_summary(v_owner);
    IF (v_summary->>'confirmedWalkinIncomePhp')::numeric IS DISTINCT FROM (v_base->>'confirmedWalkinIncomePhp')::numeric+220
       OR (v_summary->>'todayValidCheckins')::bigint IS DISTINCT FROM (v_base->>'todayValidCheckins')::bigint+2 THEN
        RAISE EXCEPTION 'Review/unallocated receipts leaked into income or valid attendance';
    END IF;
END;
$requests_and_receipts$;
RESET ROLE;

DO $immutable_facts$
DECLARE v_valid boolean; v_count bigint;
BEGIN
    IF NOT EXISTS(SELECT 1 FROM private.walkin_requests WHERE id=current_setting('gymforce.walkin_first_request')::uuid
        AND fee_php=100 AND requested_payment_method='cash' AND request_status='confirmed') THEN
        RAISE EXCEPTION 'Later fee version rewrote original request';
    END IF;
    IF (SELECT count(*) FROM private.attendance_checkins WHERE walkin_request_id=current_setting('gymforce.walkin_first_request')::uuid)<>1
       OR (SELECT count(*) FROM private.payment_allocations WHERE walkin_request_id=current_setting('gymforce.walkin_first_request')::uuid)<>1 THEN
        RAISE EXCEPTION 'Duplicate request allocation or attendance';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM private.receipt_review q JOIN private.payment_records p ON p.id=q.payment_id
        WHERE p.id=current_setting('gymforce.walkin_underpaid_payment')::uuid AND p.amount_php=119
          AND p.verification_status='recorded' AND q.reason='amount_mismatch' AND q.evidence_reviewed)
       OR EXISTS(SELECT 1 FROM private.payment_allocations WHERE payment_id=current_setting('gymforce.walkin_underpaid_payment')::uuid) THEN
        RAISE EXCEPTION 'Original underpaid verified receipt was discarded, changed or allocated';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM private.payment_records WHERE id=current_setting('gymforce.walkin_method_payment')::uuid
        AND payment_method='bank_transfer' AND verification_status='recorded') THEN
        RAISE EXCEPTION 'Actual mismatched payment method was not retained';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM private.attendance_checkins WHERE id=current_setting('gymforce.walkin_first_attendance')::uuid
        AND attendance_status='valid' AND gym_local_date=(checked_in_at AT TIME ZONE 'Asia/Manila')::date
        AND gym_local_date=(pg_catalog.clock_timestamp() AT TIME ZONE 'Asia/Manila')::date) THEN
        RAISE EXCEPTION 'Walk-in attendance used a browser or session-local date';
    END IF;
    BEGIN
        UPDATE private.walkin_requests SET fee_php=1 WHERE id=current_setting('gymforce.walkin_first_request')::uuid;
        RAISE EXCEPTION 'Request amount changed';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN IF SQLERRM<>'WALKIN_REQUEST_SNAPSHOT_IMMUTABLE' THEN RAISE; END IF;
    END;
    BEGIN
        UPDATE private.walkin_fee_versions SET fee_php=1 WHERE id=current_setting('gymforce.walkin_first_fee')::uuid;
        RAISE EXCEPTION 'Old fee version changed';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN IF SQLERRM<>'WALKIN_HISTORY_APPEND_ONLY' THEN RAISE; END IF;
    END;
    BEGIN
        DELETE FROM private.receipt_review WHERE payment_id=current_setting('gymforce.walkin_underpaid_payment')::uuid;
        RAISE EXCEPTION 'Verified receipt review history deleted';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN IF SQLERRM<>'WALKIN_HISTORY_APPEND_ONLY' THEN RAISE; END IF;
    END;
    SET LOCAL TIME ZONE 'Asia/Tokyo';
    SELECT is_valid,checked_events INTO v_valid,v_count FROM api.verify_audit_stream('walkins');
    IF v_valid IS DISTINCT FROM true OR COALESCE(v_count,0)<5 THEN RAISE EXCEPTION 'Walk-in audit history missing or invalid'; END IF;
END;
$immutable_facts$;

-- New synthetic historical facts exercise expiry without waiting or changing
-- an existing request, server clock, trigger, snapshot or previously paid visit.
DO $expired_receipt$
DECLARE
    v_owner constant uuid:='00000000-0000-4000-8000-000000000001';
    v_fee uuid; v_request uuid; v_result jsonb; v_replacement jsonb;
    v_created timestamptz:=pg_catalog.clock_timestamp()-interval '20 minutes';
BEGIN
    INSERT INTO private.walkin_fee_versions(fee_php,created_by,effective_from,created_at)
    VALUES(91,v_owner,v_created-interval '1 hour',v_created-interval '1 hour') RETURNING id INTO v_fee;
    INSERT INTO private.walkin_requests(fee_version_id,fee_php,currency,created_at,expires_at,requested_payment_method)
    VALUES(v_fee,91,'PHP',v_created,v_created+interval '15 minutes','cash') RETURNING id INTO v_request;
    SET LOCAL ROLE service_role;
    v_result:=api.owner_confirm_walkin(v_owner,v_request,gen_random_uuid(),91,'cash',false);
    v_replacement:=api.public_create_walkin_request('cash',100);
    RESET ROLE;
    IF v_result->>'outcome' IS DISTINCT FROM 'receipt_review' OR v_result ? 'attendanceId'
       OR NOT EXISTS(SELECT 1 FROM private.walkin_requests WHERE id=v_request AND request_status='expired')
       OR EXISTS(SELECT 1 FROM private.attendance_checkins WHERE walkin_request_id=v_request)
       OR NOT EXISTS(SELECT 1 FROM private.receipt_review WHERE payment_id=(v_result->>'paymentId')::uuid AND reason='request_expired') THEN
        RAISE EXCEPTION 'Expired receipt revived request or lost actual money';
    END IF;
    IF (v_replacement->>'id')::uuid=v_request OR (v_replacement->>'feePhp')::numeric IS DISTINCT FROM 120 THEN
        RAISE EXCEPTION 'Replacement request reused expired ID or fee';
    END IF;
    BEGIN
        UPDATE private.walkin_requests SET request_status='pending' WHERE id=v_request;
        RAISE EXCEPTION 'Expired request revived';
    EXCEPTION WHEN object_not_in_prerequisite_state THEN IF SQLERRM<>'WALKIN_REQUEST_CANNOT_BE_REVIVED' THEN RAISE; END IF;
    END;
    INSERT INTO private.walkin_request_rate_events(requested_at) VALUES(pg_catalog.clock_timestamp()-interval '61 seconds');
    SET LOCAL ROLE service_role;
    PERFORM api.public_create_walkin_request('cash',100);
    RESET ROLE;
    IF EXISTS(SELECT 1 FROM private.walkin_request_rate_events WHERE requested_at<=pg_catalog.clock_timestamp()-interval '60 seconds') THEN
        RAISE EXCEPTION 'Expired rate events were not pruned';
    END IF;
END;
$expired_receipt$;

DO $atomic_confirmation$
DECLARE v_request jsonb; v_result jsonb; v_operation uuid:=gen_random_uuid(); v_before bigint;
BEGIN
    SET LOCAL ROLE service_role;
    v_request:=api.public_create_walkin_request('cash',100);
    RESET ROLE;
    SELECT count(*) INTO v_before FROM private.audit_events;
    BEGIN
        REVOKE EXECUTE ON FUNCTION private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz) FROM gym_owner_executor;
        SET LOCAL ROLE service_role;
        PERFORM api.owner_confirm_walkin('00000000-0000-4000-8000-000000000001',(v_request->>'id')::uuid,v_operation,120,'cash',false);
        RAISE EXCEPTION 'Nested audit failure did not abort walk-in confirmation';
    EXCEPTION WHEN insufficient_privilege THEN
        RESET ROLE;
        IF pg_catalog.strpos(SQLERRM,'compute_audit_event_hash')=0 THEN RAISE; END IF;
    END;
    IF EXISTS(SELECT 1 FROM private.payment_records WHERE operation_id=v_operation)
       OR EXISTS(SELECT 1 FROM private.attendance_checkins WHERE walkin_request_id=(v_request->>'id')::uuid)
       OR EXISTS(SELECT 1 FROM private.payment_allocations WHERE walkin_request_id=(v_request->>'id')::uuid)
       OR NOT EXISTS(SELECT 1 FROM private.walkin_requests WHERE id=(v_request->>'id')::uuid AND request_status='pending')
       OR (SELECT count(*) FROM private.audit_events)<>v_before THEN
        RAISE EXCEPTION 'Walk-in nested audit failure retained partial financial/access state';
    END IF;
    SET LOCAL ROLE service_role;
    v_result:=api.owner_confirm_walkin('00000000-0000-4000-8000-000000000001',(v_request->>'id')::uuid,v_operation,120,'cash',false);
    RESET ROLE;
    IF v_result->>'outcome' IS DISTINCT FROM 'confirmed' OR v_result->>'replayed' IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'Retry after rolled-back confirmation did not complete once';
    END IF;
END;
$atomic_confirmation$;

DO $access_boundaries$
DECLARE v_actor text; v_table text; v_list jsonb;
BEGIN
    SET LOCAL ROLE service_role;
    v_list:=api.owner_list_walkin_requests('00000000-0000-4000-8000-000000000001',1,0);
    RESET ROLE;
    IF jsonb_array_length(v_list)<>1 OR NOT(v_list->0 ? 'status') OR NOT(v_list->0 ? 'paymentMethod')
       OR v_list::text LIKE '%verified_by%' THEN RAISE EXCEPTION 'Walk-in list projection/pagination invalid'; END IF;
    FOREACH v_actor IN ARRAY ARRAY['anon','authenticated'] LOOP
        EXECUTE format('SET LOCAL ROLE %I',v_actor);
        BEGIN
            PERFORM api.public_create_walkin_request('cash',100);
            RAISE EXCEPTION 'Browser bypassed trusted Edge request limiter';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        BEGIN
            PERFORM api.owner_set_walkin_fee('00000000-0000-4000-8000-000000000001',1,'Synthetic denied call');
            RAISE EXCEPTION 'Browser changed fee';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
        RESET ROLE;
    END LOOP;
    FOREACH v_table IN ARRAY ARRAY['private.walkin_request_rate_events','private.receipt_review'] LOOP
        IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid=to_regclass(v_table) AND relrowsecurity AND relforcerowsecurity
            AND relowner=(SELECT oid FROM pg_roles WHERE rolname='gym_data_owner')) THEN
            RAISE EXCEPTION 'New walk-in table lacks protected ownership/RLS';
        END IF;
        FOREACH v_actor IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
            IF has_any_column_privilege(v_actor,v_table,'SELECT,INSERT,UPDATE,REFERENCES')
               OR has_table_privilege(v_actor,v_table,'DELETE,TRUNCATE,TRIGGER') THEN
                RAISE EXCEPTION 'Direct walk-in table access exposed';
            END IF;
        END LOOP;
    END LOOP;
    IF has_function_privilege('gym_public_executor','api.owner_confirm_walkin(uuid,uuid,uuid,numeric,text,boolean)','EXECUTE')
       OR has_column_privilege('gym_public_executor','private.payment_records','amount_php','SELECT')
       OR has_column_privilege('gym_public_executor','private.walkin_requests','fee_php','UPDATE') THEN
        RAISE EXCEPTION 'Public request executor gained financial or snapshot mutation access';
    END IF;
END;
$access_boundaries$;
ROLLBACK;
\echo 'PASS: 15-minute immutable walk-ins, versioned fees, rate cap, atomic actual receipt/attendance, receipt review and idempotent replay.'
