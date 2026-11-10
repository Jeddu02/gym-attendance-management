-- Native synthetic SQL only. No production execution, PIN hashing or JWT proof.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $guard$;
INSERT INTO private.owner_access(user_id,is_active) VALUES('00000000-0000-4000-8000-000000000001',true)
ON CONFLICT(user_id) DO UPDATE SET is_active=true,deactivated_at=NULL;

SET LOCAL ROLE service_role;
DO $fixtures$
DECLARE owner_id uuid:='00000000-0000-4000-8000-000000000001'; member jsonb; plan jsonb; purchase jsonb; payment jsonb; actual jsonb; replay jsonb;
BEGIN
 member:=api.owner_register_member(owner_id,'Synthetic receipt correction',decode(repeat('61',32),'hex'),decode(repeat('62',32),'hex'));
 PERFORM api.owner_approve_member(owner_id,(member->>'id')::uuid,'Synthetic registration approved');
 plan:=api.owner_save_membership_plan(owner_id,NULL,'Synthetic receipt plan',500,true);
 purchase:=api.owner_create_membership_purchase(owner_id,(member->>'id')::uuid,(plan->>'id')::uuid);
 payment:=api.owner_record_membership_payment(owner_id,'61000000-0000-4000-8000-000000000001',(purchase->>'id')::uuid,500,'cash',NULL);
 PERFORM api.owner_confirm_membership_payment(owner_id,(payment->>'id')::uuid,true);
 PERFORM api.owner_activate_membership_purchase(owner_id,(purchase->>'id')::uuid);
 PERFORM api.owner_create_verified_pin_enrollment_token(owner_id,(member->>'id')::uuid,repeat('9',64),'Synthetic in-person identity checked');
 PERFORM api.member_enroll_pin(repeat('9',64),'$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGljLXNhbHQ$ZmFrZS12ZXJpZmllci1ub3QtYS1yZWFsLXBpbg');
 IF api.commit_member_checkin((member->>'id')::uuid,1)->>'accepted' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION 'Synthetic paid member check-in failed'; END IF;
 PERFORM set_config('gymforce.receipt_member',member->>'id',true);
 PERFORM set_config('gymforce.receipt_purchase',purchase->>'id',true);
 PERFORM set_config('gymforce.receipt_payment',payment->>'id',true);
 actual:=api.owner_record_actual_receipt(owner_id,'61000000-0000-4000-8000-000000000002',125,'cash','Synthetic unmatched receipt verified','SYNTHETIC-EVIDENCE',true,NULL);
 replay:=api.owner_record_actual_receipt(owner_id,'61000000-0000-4000-8000-000000000002',125,'cash','Synthetic unmatched receipt verified','SYNTHETIC-EVIDENCE',true,NULL);
 IF actual->>'paymentId' IS DISTINCT FROM replay->>'paymentId' OR replay->>'replayed' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION 'Actual receipt idempotency failed'; END IF;
 PERFORM set_config('gymforce.actual_receipt',actual->>'paymentId',true);
 BEGIN
  PERFORM api.owner_record_actual_receipt(owner_id,'61000000-0000-4000-8000-000000000002',126,'cash','Synthetic unmatched receipt verified','SYNTHETIC-EVIDENCE',true,NULL);
  RAISE EXCEPTION 'Changed receipt replay accepted';
 EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'RECEIPT_OPERATION_CONFLICT' THEN RAISE; END IF; END;
 BEGIN
  PERFORM api.owner_verify_actual_receipt('00000000-0000-4000-8000-000000000002',(actual->>'paymentId')::uuid,'Synthetic outsider denied','SYNTHETIC-EVIDENCE',true);
  RAISE EXCEPTION 'Outsider receipt verification allowed';
 EXCEPTION WHEN insufficient_privilege THEN IF SQLERRM<>'OWNER_ACCESS_REQUIRED' THEN RAISE; END IF; END;
 BEGIN
  PERFORM api.owner_record_actual_receipt(owner_id,'61000000-0000-4000-8000-000000000003',125,'cash','Synthetic actual receipt','SYNTHETIC-EVIDENCE',false,NULL);
  RAISE EXCEPTION 'Unverified actual receipt created';
 EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'INVALID_ACTUAL_RECEIPT' THEN RAISE; END IF; END;
END $fixtures$;
RESET ROLE;
DO $unallocated$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.payment_records WHERE id=current_setting('gymforce.actual_receipt')::uuid AND verification_status='recorded' AND target_membership_purchase_id IS NULL)
 OR NOT EXISTS(SELECT 1 FROM private.receipt_verifications WHERE payment_id=current_setting('gymforce.actual_receipt')::uuid)
 OR EXISTS(SELECT 1 FROM private.payment_allocations WHERE payment_id=current_setting('gymforce.actual_receipt')::uuid)
 THEN RAISE EXCEPTION 'Verified unallocated receipt granted allocation or lost original state'; END IF;
END $unallocated$;

-- A missing audit dependency must roll back void, projection, attendance and
-- appended resolution together; no partial correction may survive failure.
DO $rollback$
BEGIN
 BEGIN
  -- Inject failure in the nested hashing dependency, preserving entrypoint grants.
  REVOKE EXECUTE ON FUNCTION private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz) FROM gym_owner_executor;
  SET LOCAL ROLE service_role;
  PERFORM api.owner_void_payment_confirmation('00000000-0000-4000-8000-000000000001',current_setting('gymforce.receipt_payment')::uuid,'Synthetic erroneous confirmation','SYNTHETIC-CORRECTION',false);
  RAISE EXCEPTION 'Audit failure ignored';
 EXCEPTION WHEN insufficient_privilege THEN RESET ROLE;
  IF SQLERRM NOT LIKE '%compute_audit_event_hash%' THEN RAISE; END IF;
 END;
 IF EXISTS(SELECT 1 FROM private.payment_confirmation_voids WHERE payment_id=current_setting('gymforce.receipt_payment')::uuid)
 OR NOT EXISTS(SELECT 1 FROM private.payment_records WHERE id=current_setting('gymforce.receipt_payment')::uuid AND verification_status='confirmed')
 OR NOT EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.receipt_member')::uuid AND attendance_status='valid')
 THEN RAISE EXCEPTION 'Failed correction retained partial changes'; END IF;
END $rollback$;

SET LOCAL ROLE service_role;
SELECT api.owner_void_payment_confirmation('00000000-0000-4000-8000-000000000001',current_setting('gymforce.receipt_payment')::uuid,'Synthetic erroneous confirmation','SYNTHETIC-CORRECTION',false);
SELECT api.owner_void_payment_confirmation('00000000-0000-4000-8000-000000000001',current_setting('gymforce.receipt_payment')::uuid,'Synthetic erroneous confirmation','SYNTHETIC-CORRECTION',false);
DO $replacement$
DECLARE result jsonb; purchase jsonb; payment jsonb; plan jsonb;
BEGIN
 result:=api.owner_record_actual_receipt('00000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000004',500,'cash','Synthetic corrected actual receipt','SYNTHETIC-REPLACEMENT',true,current_setting('gymforce.receipt_payment')::uuid);
 PERFORM set_config('gymforce.replacement_receipt',result->>'paymentId',true);
 IF api.commit_member_checkin(current_setting('gymforce.receipt_member')::uuid,1)->>'accepted' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION 'Voided or replacement-unallocated receipt restored attendance'; END IF;
 plan:=api.owner_save_membership_plan('00000000-0000-4000-8000-000000000001',NULL,'Synthetic retained cash replacement denial',500,true);
 purchase:=api.owner_create_membership_purchase('00000000-0000-4000-8000-000000000001',current_setting('gymforce.receipt_member')::uuid,(plan->>'id')::uuid);
 payment:=api.owner_record_membership_payment('00000000-0000-4000-8000-000000000001',gen_random_uuid(),(purchase->>'id')::uuid,500,'cash',NULL);
 PERFORM api.owner_confirm_membership_payment('00000000-0000-4000-8000-000000000001',(payment->>'id')::uuid,true);
 PERFORM api.owner_void_payment_confirmation('00000000-0000-4000-8000-000000000001',(payment->>'id')::uuid,'Synthetic allocation erroneous but cash retained','SYNTHETIC-RETAINED-CASH',true);
 BEGIN
  PERFORM api.owner_record_actual_receipt('00000000-0000-4000-8000-000000000001',gen_random_uuid(),500,'cash','Synthetic duplicate cash replacement denied','SYNTHETIC-RETAINED-CASH',true,(payment->>'id')::uuid);
  RAISE EXCEPTION 'Replacement duplicated still-verified physical cash';
 EXCEPTION WHEN invalid_parameter_value THEN IF SQLERRM<>'DOCUMENTED_UNREPLACED_VOID_REQUIRED' THEN RAISE; END IF; END;
END $replacement$;
RESET ROLE;

DO $preserved$
DECLARE original_activation date; original_expiry date; actor text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.membership_purchases WHERE id=current_setting('gymforce.receipt_purchase')::uuid
  AND purchase_status='payment_review' AND activation_date IS NOT NULL AND expiry_date IS NOT NULL)
 OR NOT EXISTS(SELECT 1 FROM private.payment_records WHERE id=current_setting('gymforce.receipt_payment')::uuid AND amount_php=500
  AND payment_method='cash' AND verification_status='confirmation_voided_in_error')
 OR (SELECT count(*) FROM private.payment_allocations WHERE payment_id=current_setting('gymforce.receipt_payment')::uuid)<>1
 OR (SELECT count(*) FROM private.payment_events WHERE payment_id=current_setting('gymforce.receipt_payment')::uuid AND event_type='payment.confirmed')<>1
 OR (SELECT count(*) FROM private.payment_confirmation_voids WHERE payment_id=current_setting('gymforce.receipt_payment')::uuid)<>1
 OR NOT EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.receipt_member')::uuid AND attendance_status='invalidated_payment')
 OR NOT EXISTS(SELECT 1 FROM private.attendance_validity_resolutions r JOIN private.attendance_checkins c ON c.id=r.attendance_id
  WHERE c.member_id=current_setting('gymforce.receipt_member')::uuid AND r.prior_status='valid' AND r.new_status='invalidated_payment')
 OR NOT EXISTS(SELECT 1 FROM private.receipt_replacement_links WHERE original_payment_id=current_setting('gymforce.receipt_payment')::uuid AND replacement_payment_id=current_setting('gymforce.replacement_receipt')::uuid)
 OR EXISTS(SELECT 1 FROM private.payment_allocations WHERE payment_id=current_setting('gymforce.replacement_receipt')::uuid)
 THEN RAISE EXCEPTION 'Correction lost history or silently restored access'; END IF;
 FOREACH actor IN ARRAY ARRAY['anon','authenticated','service_role','gym_public_executor','gym_checkin_executor'] LOOP
  EXECUTE format('SET LOCAL ROLE %I',actor);
  BEGIN PERFORM payment_id FROM private.receipt_verifications; RAISE EXCEPTION 'Receipt proof exposed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET ROLE;
 END LOOP;
 BEGIN UPDATE private.receipt_verifications SET reason='Changed proof'; RAISE EXCEPTION 'Proof history changed';
 EXCEPTION WHEN object_not_in_prerequisite_state THEN IF SQLERRM<>'PAYMENT_HISTORY_APPEND_ONLY' THEN RAISE; END IF; END;
 BEGIN DELETE FROM private.payment_confirmation_voids; RAISE EXCEPTION 'Void history deleted';
 EXCEPTION WHEN object_not_in_prerequisite_state THEN IF SQLERRM<>'PAYMENT_HISTORY_APPEND_ONLY' THEN RAISE; END IF; END;
END $preserved$;
SET LOCAL ROLE service_role;
DO $money_basis$ BEGIN
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(api.owner_list_receipt_review(
   '00000000-0000-4000-8000-000000000001',100,0)) r
   WHERE r->>'paymentId'=current_setting('gymforce.receipt_payment')
   AND (r->>'actualReceiptVerified')::boolean)
 THEN RAISE EXCEPTION 'Proof-void still counts as verified money'; END IF;
END $money_basis$;
-- Helpers are deliberately not gateway-callable: test their actual facts via
-- the Owner list API instead of invoking a private function as service_role.
RESET ROLE;
ROLLBACK;
\echo 'PASS: synthetic actual receipts, idempotency, preserved void/re-record history, eligibility invalidation and rollback.'
