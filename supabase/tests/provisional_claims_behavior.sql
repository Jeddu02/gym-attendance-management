\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL THEN RAISE EXCEPTION 'Synthetic target required'; END IF; END $guard$;
INSERT INTO private.owner_access(user_id,is_active) VALUES('00000000-0000-4000-8000-000000000001',true) ON CONFLICT DO NOTHING;
SET LOCAL ROLE service_role;
DO $claims$
DECLARE actor uuid:='00000000-0000-4000-8000-000000000001'; m jsonb; plan jsonb; purchase jsonb; receipt jsonb; claim jsonb; replay jsonb; result jsonb;
 today date:=(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date;
BEGIN
 m:=api.owner_register_member(actor,'Synthetic provisional presence',decode(repeat('81',32),'hex'),decode(repeat('82',32),'hex'));
 PERFORM set_config('gymforce.claim_member',m->>'id',true);
 claim:=api.owner_submit_attendance_claim(actor,'81000000-0000-4000-8000-000000000001',m->>'member_code',today);
 PERFORM set_config('gymforce.claim_pending',claim->>'id',true);
 replay:=api.owner_submit_attendance_claim(actor,'81000000-0000-4000-8000-000000000001',m->>'member_code',today);
 IF replay->>'id' IS DISTINCT FROM claim->>'id' OR replay->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Claim replay changed identity'; END IF;
 BEGIN PERFORM api.owner_resolve_attendance_claim(actor,(claim->>'id')::uuid,true,'Synthetic physical presence seen'); RAISE EXCEPTION 'Pending unpaid claim approved'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM api.owner_approve_member(actor,(m->>'id')::uuid,'Synthetic registration checked');
 plan:=api.owner_save_membership_plan(actor,NULL,'Synthetic presence monthly',300,true);
 purchase:=api.owner_create_membership_purchase(actor,(m->>'id')::uuid,(plan->>'id')::uuid);
 receipt:=api.owner_record_membership_payment(actor,gen_random_uuid(),(purchase->>'id')::uuid,300,'cash',NULL);
 PERFORM api.owner_confirm_membership_payment(actor,(receipt->>'id')::uuid,true);
 PERFORM api.owner_activate_membership_purchase(actor,(purchase->>'id')::uuid);
 claim:=api.owner_submit_attendance_claim(actor,'81000000-0000-4000-8000-000000000002',m->>'member_code',today-1);
 PERFORM set_config('gymforce.claim_stale',claim->>'id',true);
 BEGIN PERFORM api.owner_resolve_attendance_claim(actor,(claim->>'id')::uuid,true,'Synthetic stale claim presence'); RAISE EXCEPTION 'Stale claim backdated'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 result:=api.owner_resolve_attendance_claim(actor,current_setting('gymforce.claim_pending')::uuid,true,'Synthetic current physical presence confirmed');
 IF result->>'outcome' IS DISTINCT FROM 'current_presence_confirmed' OR result->>'attendanceId' IS NULL THEN RAISE EXCEPTION 'Current paid physical presence not recorded'; END IF;
 replay:=api.owner_resolve_attendance_claim(actor,current_setting('gymforce.claim_pending')::uuid,true,'Synthetic current physical presence confirmed');
 IF replay->>'attendanceId' IS DISTINCT FROM result->>'attendanceId' OR replay->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Resolution retry changed check-in'; END IF;
 claim:=api.owner_submit_attendance_claim(actor,'81000000-0000-4000-8000-000000000003',m->>'member_code',today);
 PERFORM set_config('gymforce.claim_conflict',claim->>'id',true);
 BEGIN PERFORM api.owner_resolve_attendance_claim(actor,(claim->>'id')::uuid,true,'Synthetic duplicate claim reviewed'); RAISE EXCEPTION 'Duplicate claim silently approved'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM api.owner_resolve_attendance_claim(actor,current_setting('gymforce.claim_stale')::uuid,false,'Synthetic older claim resolved without attendance');
 BEGIN PERFORM api.owner_list_attendance_claims('00000000-0000-4000-8000-000000000002',50,0); RAISE EXCEPTION 'Outsider claims read'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM api.owner_submit_attendance_claim(actor,'81000000-0000-4000-8000-000000000001',m->>'member_code',today-2); RAISE EXCEPTION 'Changed claim replay accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $claims$;
RESET ROLE;
DO $preserved$ BEGIN
 IF (SELECT count(*) FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.claim_member')::uuid)<>1
 OR EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=current_setting('gymforce.claim_member')::uuid AND gym_local_date<>(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date)
 OR EXISTS(SELECT 1 FROM private.owner_claim_resolutions WHERE claim_id=current_setting('gymforce.claim_conflict')::uuid)
 OR NOT EXISTS(SELECT 1 FROM private.owner_attendance_claims WHERE id=current_setting('gymforce.claim_stale')::uuid)
 THEN RAISE EXCEPTION 'Claims discarded, backdated, duplicated or implicitly resolved'; END IF;
 BEGIN DELETE FROM private.owner_attendance_claims; RAISE EXCEPTION 'Claim history deleted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $preserved$;
ROLLBACK;
\echo 'PASS: immutable provisional claims, changed replay denial, current paid presence only, stale/duplicate review and reasoned no-attendance resolution.'
