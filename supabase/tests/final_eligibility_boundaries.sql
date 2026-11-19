-- Native synthetic runner only. No clock changes, backdating or trigger bypass.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$
BEGIN
  IF current_database() <> 'gymforce_batch1_synthetic'
     OR current_setting('gymforce.synthetic_run_id', true) IS NULL THEN
    RAISE EXCEPTION 'Synthetic target required';
  END IF;
END;
$guard$;
INSERT INTO private.owner_access(user_id,is_active)
VALUES ('00000000-0000-4000-8000-000000000001',true) ON CONFLICT DO NOTHING;
SET LOCAL ROLE service_role;
DO $prepare$
DECLARE
  actor uuid := '00000000-0000-4000-8000-000000000001';
  member jsonb; plan jsonb; purchase jsonb; receipt jsonb;
BEGIN
  member := api.owner_register_member(actor,'Synthetic expiry boundary audit',
    decode(repeat('e7',32),'hex'),decode(repeat('e8',32),'hex'));
  PERFORM api.owner_approve_member(actor,(member->>'id')::uuid,'Synthetic identity and registration approved');
  plan := api.owner_save_membership_plan(actor,NULL,'Synthetic expiry boundary monthly',350,true);
  purchase := api.owner_create_membership_purchase(actor,(member->>'id')::uuid,(plan->>'id')::uuid);
  receipt := api.owner_record_membership_payment(actor,gen_random_uuid(),(purchase->>'id')::uuid,350,'cash',NULL);
  PERFORM api.owner_confirm_membership_payment(actor,(receipt->>'id')::uuid,true);
  PERFORM api.owner_activate_membership_purchase(actor,(purchase->>'id')::uuid);
  PERFORM set_config('gymforce.phase59_member',member->>'id',true);
  PERFORM set_config('gymforce.phase59_purchase',purchase->>'id',true);
END;
$prepare$;
RESET ROLE;
DO $boundaries$
DECLARE
  member_id uuid := current_setting('gymforce.phase59_member')::uuid;
  purchase_id uuid := current_setting('gymforce.phase59_purchase')::uuid;
  activation date; expiry date; audit_before bigint; attendance_before bigint;
BEGIN
  SELECT activation_date,expiry_date INTO STRICT activation,expiry
  FROM private.membership_purchases WHERE id=purchase_id;
  SELECT count(*) INTO audit_before FROM private.audit_events;
  SELECT count(*) INTO attendance_before FROM private.attendance_checkins;
  -- Exercise the final helper used by commit_member_checkin with explicit instants.
  -- Session timezone must not change Manila midnight/inclusive expiry semantics.
  SET LOCAL TIME ZONE 'America/New_York';
  IF private.member_checkin_eligible_purchase(member_id,
       (expiry::timestamp + interval '1 day' - interval '1 microsecond') AT TIME ZONE 'Asia/Manila')
       IS DISTINCT FROM purchase_id THEN
    RAISE EXCEPTION 'Inclusive expiry final instant lost eligibility';
  END IF;
  IF private.member_checkin_eligible_purchase(member_id,
       (expiry::timestamp + interval '1 day') AT TIME ZONE 'Asia/Manila') IS NOT NULL THEN
    RAISE EXCEPTION 'Expired membership retained eligibility';
  END IF;
  IF private.member_checkin_eligible_purchase(member_id,
       (activation::timestamp - interval '1 microsecond') AT TIME ZONE 'Asia/Manila') IS NOT NULL THEN
    RAISE EXCEPTION 'Pre-activation instant gained eligibility';
  END IF;
  IF (SELECT count(*) FROM private.audit_events) <> audit_before
     OR (SELECT count(*) FROM private.attendance_checkins) <> attendance_before THEN
    RAISE EXCEPTION 'Eligibility lookup mutated audit or attendance';
  END IF;
END;
$boundaries$;
ROLLBACK;
\echo 'PASS: final SQL eligibility includes expiry final instant, denies next Manila midnight/pre-activation and preserves attendance/audit; not browser/HTTP E2E.'
