\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN RAISE EXCEPTION 'Synthetic target required'; END IF; END $guard$;
INSERT INTO private.owner_access(user_id,is_active) VALUES('00000000-0000-4000-8000-000000000001',true) ON CONFLICT DO NOTHING;
SET LOCAL ROLE service_role;
DO $review$
DECLARE actor uuid:='00000000-0000-4000-8000-000000000001'; m jsonb; plan jsonb; purchase jsonb; receipt jsonb; small jsonb; result jsonb; replay jsonb; request jsonb; short_request jsonb;
BEGIN
 m:=api.owner_register_member(actor,'Synthetic reviewed whole receipt',decode(repeat('a1',32),'hex'),decode(repeat('a2',32),'hex'));
 PERFORM api.owner_approve_member(actor,(m->>'id')::uuid,'Synthetic approved registration');
 plan:=api.owner_save_membership_plan(actor,NULL,'Synthetic allocation monthly',300,true);
 purchase:=api.owner_create_membership_purchase(actor,(m->>'id')::uuid,(plan->>'id')::uuid);
 receipt:=api.owner_record_actual_receipt(actor,gen_random_uuid(),300,'cash','Synthetic whole receipt verified','ALLOCATION-SYNTHETIC',true,NULL);
 small:=api.owner_record_actual_receipt(actor,gen_random_uuid(),100,'cash','Synthetic underpaid receipt retained','ALLOCATION-SYNTHETIC',true,NULL);
 PERFORM set_config('gymforce.allocation_payment',receipt->>'paymentId',true);
 PERFORM set_config('gymforce.allocation_member',m->>'id',true);
 PERFORM set_config('gymforce.allocation_purchase',purchase->>'id',true);
 BEGIN PERFORM api.owner_allocate_verified_receipt(actor,(small->>'paymentId')::uuid,(purchase->>'id')::uuid,NULL,'Synthetic underpayment denied','ALLOCATION-SYNTHETIC',false); RAISE EXCEPTION 'Underpayment allocated'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 result:=api.owner_allocate_verified_receipt(actor,(receipt->>'paymentId')::uuid,(purchase->>'id')::uuid,NULL,'Synthetic whole receipt allocated','ALLOCATION-SYNTHETIC',false);
 replay:=api.owner_allocate_verified_receipt(actor,(receipt->>'paymentId')::uuid,(purchase->>'id')::uuid,NULL,'Synthetic whole receipt allocated','ALLOCATION-SYNTHETIC',false);
 IF replay->>'replayed' IS DISTINCT FROM 'true' OR result->>'paymentId' IS DISTINCT FROM replay->>'paymentId' THEN RAISE EXCEPTION 'Reviewed allocation not idempotent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(api.owner_list_membership_payments(actor,receipt->>'paymentId','confirmed',50,0)->'payments') item WHERE item->>'purchaseId'=purchase->>'id')
 OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(api.owner_list_membership_purchases(actor,purchase->>'id','all',50,0)) item WHERE item->>'paymentStatus'='confirmed')
 THEN RAISE EXCEPTION 'Reviewed allocation missing or misleading in existing payment/purchase histories'; END IF;
 PERFORM api.owner_activate_membership_purchase(actor,(purchase->>'id')::uuid);
 PERFORM api.owner_create_verified_pin_enrollment_token(actor,(m->>'id')::uuid,repeat('bc',32),'Synthetic in-person verification');
 PERFORM api.member_enroll_pin(repeat('bc',32),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGljLXNhbHQ$ZmFrZS12ZXJpZmllci1ub3QtYS1yZWFsLXBpbg');
 IF api.commit_member_checkin((m->>'id')::uuid,1)->>'accepted' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Reviewed full receipt did not support eligible check-in'; END IF;
 BEGIN PERFORM api.owner_allocate_verified_receipt(actor,(receipt->>'paymentId')::uuid,gen_random_uuid(),NULL,'Synthetic whole receipt allocated','ALLOCATION-SYNTHETIC',false); RAISE EXCEPTION 'Receipt retargeted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM api.owner_set_walkin_fee(actor,100,'Synthetic allocation fee');
 request:=api.public_create_walkin_request('cash',100);
 receipt:=api.owner_record_actual_receipt(actor,gen_random_uuid(),100,'cash','Synthetic walk-in actual receipt','ALLOCATION-SYNTHETIC',true,NULL);
 BEGIN PERFORM api.owner_allocate_verified_receipt(actor,(receipt->>'paymentId')::uuid,NULL,(request->>'id')::uuid,'Synthetic presence not attested','ALLOCATION-SYNTHETIC',false); RAISE EXCEPTION 'Walk-in presence defaulted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 result:=api.owner_allocate_verified_receipt(actor,(receipt->>'paymentId')::uuid,NULL,(request->>'id')::uuid,'Synthetic current walk-in physical presence','ALLOCATION-SYNTHETIC',true);
 IF result->>'attendanceId' IS NULL THEN RAISE EXCEPTION 'Reviewed walk-in missing atomic attendance'; END IF;
 -- Mismatched actual receipt remains review; exact amount can subsequently be
 -- allocated to a NEW request whose server fee snapshot matches that receipt.
 PERFORM api.owner_set_walkin_fee(actor,50,'Synthetic alternate fee snapshot');
 short_request:=api.public_create_walkin_request('cash',100);
 receipt:=api.owner_confirm_walkin(actor,(short_request->>'id')::uuid,gen_random_uuid(),100,'cash',true);
 PERFORM api.owner_set_walkin_fee(actor,100,'Synthetic replacement current fee');
 request:=api.public_create_walkin_request('cash',100);
 PERFORM api.owner_allocate_verified_receipt(actor,(receipt->>'paymentId')::uuid,NULL,(request->>'id')::uuid,'Synthetic reviewed new request physical presence','ALLOCATION-SYNTHETIC',true);
 -- Void still invalidates the exact reviewed membership basis; retries do not restore it.
 PERFORM api.owner_void_payment_confirmation(actor,current_setting('gymforce.allocation_payment')::uuid,'Synthetic reviewed allocation correction','ALLOCATION-SYNTHETIC',true);
 replay:=api.owner_allocate_verified_receipt(actor,current_setting('gymforce.allocation_payment')::uuid,current_setting('gymforce.allocation_purchase')::uuid,NULL,'Synthetic whole receipt allocated','ALLOCATION-SYNTHETIC',false);
 IF replay->>'confirmationVoided' IS DISTINCT FROM 'true' OR api.commit_member_checkin((m->>'id')::uuid,1)->>'accepted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Reviewed retry restored voided eligibility'; END IF;
END $review$;
RESET ROLE;
DO $original$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.payment_records WHERE id=current_setting('gymforce.allocation_payment')::uuid AND target_membership_purchase_id IS NULL AND amount_php=300)
 OR (SELECT count(*) FROM private.payment_allocations WHERE payment_id=current_setting('gymforce.allocation_payment')::uuid)<>1
 OR NOT EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.allocation_member')::uuid AND attendance_status='invalidated_payment')
 THEN RAISE EXCEPTION 'Allocation rewrote receipt or lost invalidated history'; END IF;
 BEGIN DELETE FROM private.receipt_allocation_reviews; RAISE EXCEPTION 'Allocation review deleted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $original$;
DO $atomic_allocation$
DECLARE actor uuid:='00000000-0000-4000-8000-000000000001'; receipt jsonb; request jsonb;
BEGIN
 SET LOCAL ROLE service_role;
 request:=api.public_create_walkin_request('cash',100);
 receipt:=api.owner_record_actual_receipt(actor,gen_random_uuid(),100,'cash','Synthetic rollback receipt','ALLOCATION-ROLLBACK',true,NULL);
 RESET ROLE;
 BEGIN
  REVOKE EXECUTE ON FUNCTION private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz) FROM gym_owner_executor;
  SET LOCAL ROLE service_role;
  PERFORM api.owner_allocate_verified_receipt(actor,(receipt->>'paymentId')::uuid,NULL,(request->>'id')::uuid,'Synthetic atomic allocation rollback','ALLOCATION-ROLLBACK',true);
  RAISE EXCEPTION 'Missing audit dependency ignored';
 EXCEPTION WHEN insufficient_privilege THEN RESET ROLE;
  IF SQLERRM NOT LIKE '%compute_audit_event_hash%' THEN RAISE; END IF;
 END;
 IF EXISTS(SELECT 1 FROM private.receipt_allocation_reviews WHERE payment_id=(receipt->>'paymentId')::uuid)
 OR EXISTS(SELECT 1 FROM private.payment_allocations WHERE payment_id=(receipt->>'paymentId')::uuid)
 OR EXISTS(SELECT 1 FROM private.attendance_checkins WHERE walkin_request_id=(request->>'id')::uuid)
 OR NOT EXISTS(SELECT 1 FROM private.payment_records WHERE id=(receipt->>'paymentId')::uuid AND verification_status='recorded')
 OR NOT EXISTS(SELECT 1 FROM private.walkin_requests WHERE id=(request->>'id')::uuid AND request_status='pending')
 THEN RAISE EXCEPTION 'Failed allocation retained partial payment/attendance/review changes'; END IF;
END $atomic_allocation$;
ROLLBACK;
\echo 'PASS: exact verified whole receipt allocation, underpayment/presence denial, immutable targets, new walk-in request, activation/check-in, retry and correction invalidation.'
