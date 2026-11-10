-- Native synthetic integration tests. Not JWT/Edge/PostgREST certification.
-- The fresh cluster is disposable; identity sequence advances are expected.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$
BEGIN
 IF current_database() <> 'gymforce_batch1_synthetic'
 OR current_setting('gymforce.synthetic_run_id', true) IS NULL THEN
  RAISE EXCEPTION 'Synthetic test target required';
 END IF;
END $guard$;
INSERT INTO private.owner_access(user_id, is_active)
VALUES ('00000000-0000-4000-8000-000000000001', true);

SET LOCAL ROLE service_role;
DO $owner_operations$
DECLARE
 owner_id constant uuid := '00000000-0000-4000-8000-000000000001';
 outsider constant uuid := '00000000-0000-4000-8000-000000000002';
 registered jsonb;
 plan jsonb;
BEGIN
 BEGIN
  PERFORM api.owner_register_member(outsider, 'Synthetic denied', decode(repeat('01',32),'hex'), decode(repeat('02',32),'hex'));
  RAISE EXCEPTION 'Non-Owner registration was allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM api.owner_register_member(NULL, 'Synthetic denied', decode(repeat('01',32),'hex'), decode(repeat('02',32),'hex'));
  RAISE EXCEPTION 'Null actor registration was allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 registered := api.owner_register_member(owner_id, 'Synthetic integration member', decode(repeat('01',32),'hex'), decode(repeat('02',32),'hex'));
 IF registered->>'status' IS DISTINCT FROM 'pending' OR NOT COALESCE(registered->>'member_code' LIKE 'MBR-%',false) THEN
  RAISE EXCEPTION 'Registration output/state is incorrect';
 END IF;
 PERFORM set_config('gymforce.fixture_member', registered->>'id', true);
 BEGIN
  PERFORM api.owner_register_member(owner_id, 'Synthetic duplicate', decode(repeat('01',32),'hex'), decode(repeat('02',32),'hex'));
  RAISE EXCEPTION 'Duplicate mobile accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'MEMBER_MOBILE_EXISTS' THEN RAISE; END IF;
 END;
 plan := api.owner_save_membership_plan(owner_id, NULL, 'Synthetic monthly', 500, true);
 PERFORM set_config('gymforce.fixture_plan', plan->>'id', true);
 BEGIN
  PERFORM api.owner_create_membership_purchase(owner_id, (registered->>'id')::uuid, (plan->>'id')::uuid);
  RAISE EXCEPTION 'Pending registration could purchase';
 EXCEPTION WHEN invalid_parameter_value THEN
  IF SQLERRM <> 'MEMBER_NOT_ACTIVE' THEN RAISE; END IF;
 END;
END $owner_operations$;
RESET ROLE;
-- Fixture preparation is explicitly administrator-only. This is NOT an
-- implemented registration approval path and must never become application code.
UPDATE private.members SET status='active', approved_at=clock_timestamp()
WHERE id=current_setting('gymforce.fixture_member')::uuid;

SET LOCAL ROLE service_role;
DO $payment_operations$
DECLARE
 owner_id constant uuid := '00000000-0000-4000-8000-000000000001';
 purchase jsonb;
 receipt jsonb;
 replay jsonb;
 operation_id constant uuid := '00000000-0000-4000-8000-000000000003';
BEGIN
 purchase := api.owner_create_membership_purchase(owner_id, current_setting('gymforce.fixture_member')::uuid, current_setting('gymforce.fixture_plan')::uuid);
 PERFORM set_config('gymforce.fixture_purchase', purchase->>'id', true);
 -- Editing a plan must not rewrite a purchase's price snapshot.
 PERFORM api.owner_save_membership_plan(owner_id, current_setting('gymforce.fixture_plan')::uuid, 'Synthetic monthly', 600, true);
 receipt := api.owner_record_membership_payment(owner_id, operation_id, (purchase->>'id')::uuid, 500, 'gcash', 'SYNTHETIC-ONLY');
 PERFORM set_config('gymforce.fixture_payment', receipt->>'id', true);
 replay := api.owner_record_membership_payment(owner_id, operation_id, (purchase->>'id')::uuid, 500, 'gcash', 'SYNTHETIC-ONLY');
 IF replay->>'id' IS DISTINCT FROM receipt->>'id' OR replay->>'replayed' IS DISTINCT FROM 'true' THEN
  RAISE EXCEPTION 'Identical payment retry was not idempotent';
 END IF;
 BEGIN
  PERFORM api.owner_record_membership_payment(owner_id, operation_id, (purchase->>'id')::uuid, 499, 'gcash', 'SYNTHETIC-ONLY');
  RAISE EXCEPTION 'Mismatched operation replay accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 BEGIN
  PERFORM api.owner_confirm_membership_payment(owner_id, (receipt->>'id')::uuid, false);
  RAISE EXCEPTION 'Electronic receipt confirmed without evidence review';
 EXCEPTION WHEN invalid_parameter_value THEN NULL;
 END;
 PERFORM api.owner_confirm_membership_payment(owner_id, (receipt->>'id')::uuid, true);
 BEGIN
  PERFORM api.owner_confirm_membership_payment(owner_id, (receipt->>'id')::uuid, true);
  RAISE EXCEPTION 'Duplicate confirmation accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'PAYMENT_NOT_AWAITING_DECISION' THEN RAISE; END IF;
 END;
END $payment_operations$;
RESET ROLE;

DO $payment_state$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.membership_purchases
  WHERE id=current_setting('gymforce.fixture_purchase')::uuid
  AND price_php=500 AND purchase_status='pending_activation'
  AND activation_date IS NULL AND expiry_date IS NULL) THEN
  RAISE EXCEPTION 'Payment confirmation state/snapshot changed unexpectedly';
 END IF;
 IF (SELECT count(*) FROM private.payment_allocations WHERE payment_id=current_setting('gymforce.fixture_payment')::uuid)<>1 THEN
  RAISE EXCEPTION 'Expected one whole-receipt allocation';
 END IF;
END $payment_state$;

SET LOCAL ROLE service_role;
DO $pin_and_audit$
DECLARE
 owner_id constant uuid := '00000000-0000-4000-8000-000000000001';
 token_hash text := repeat('a',64);
 synthetic_hash text := '$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGljLXNhbHQ$ZmFrZS12ZXJpZmllci1ub3QtYS1yZWFsLXBpbg';
 result jsonb;
 stream text;
 valid boolean;
 event_count bigint;
BEGIN
 -- PHC-format fixture only: real Argon hashing/verification is covered by
 -- Deno tests. SQL enrollment cannot prove the plaintext PIN or KDF itself.
 PERFORM api.owner_create_pin_enrollment_token(owner_id, current_setting('gymforce.fixture_member')::uuid, token_hash, clock_timestamp()+interval '15 minutes');
 result := api.member_enroll_pin(token_hash, synthetic_hash);
 IF result->>'success' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Enrollment did not succeed'; END IF;
 BEGIN
  PERFORM api.member_enroll_pin(token_hash, synthetic_hash);
  RAISE EXCEPTION 'Consumed token accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'INVALID_OR_EXPIRED_TOKEN' THEN RAISE; END IF;
 END;
 IF (api.reserve_pin_enrollment_request()->>'allowed') IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Rate reservation failed'; END IF;
 -- Confirm nonempty streams; cross-timezone legacy hashing has a separate gate.
 FOREACH stream IN ARRAY ARRAY['members','membership_plans','payments','member-pin:'||current_setting('gymforce.fixture_member')] LOOP
  SELECT is_valid, checked_events INTO valid, event_count FROM api.verify_audit_stream(stream);
  IF valid IS DISTINCT FROM true OR event_count IS NULL OR event_count=0 THEN RAISE EXCEPTION 'Audit chain invalid or empty: %',stream; END IF;
 END LOOP;
END $pin_and_audit$;
RESET ROLE;

DO $browser_denial$
DECLARE actor text; item record;
BEGIN
 FOREACH actor IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
  FOR item IN SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')) AND c.relkind='r'
  LOOP
   EXECUTE format('SET LOCAL ROLE %I',actor);
   BEGIN
    EXECUTE format('SELECT 1 FROM %I.%I LIMIT 1',item.nspname,item.relname);
    RAISE EXCEPTION 'Direct protected table read allowed: % / %.%',actor,item.nspname,item.relname;
   EXCEPTION WHEN insufficient_privilege THEN NULL;
   END;
   RESET ROLE;
  END LOOP;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY['anon','authenticated'] LOOP
  EXECUTE format('SET LOCAL ROLE %I',actor);
  BEGIN
   PERFORM api.is_active_owner_for_user('00000000-0000-4000-8000-000000000001');
   RAISE EXCEPTION 'Browser RPC access allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;
 END LOOP;
END $browser_denial$;

SET LOCAL ROLE gym_data_owner;
DO $forced_rls$
BEGIN
 IF EXISTS(SELECT 1 FROM private.members) THEN RAISE EXCEPTION 'Data owner bypasses FORCE RLS'; END IF;
END $forced_rls$;
RESET ROLE;

SET LOCAL ROLE gym_public_executor;
DO $public_executor_denial$
BEGIN
 BEGIN
  PERFORM password_hash FROM private.member_pin_credentials;
  RAISE EXCEPTION 'Public executor can read verifier';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM api.owner_list_membership_plans('00000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'Public executor can invoke Owner RPC';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $public_executor_denial$;
RESET ROLE;

SET LOCAL ROLE gym_owner_executor;
DO $owner_column_denial$
BEGIN
 BEGIN
  PERFORM password_hash FROM private.member_pin_credentials;
  RAISE EXCEPTION 'Owner executor can read verifier';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  UPDATE private.membership_purchases SET expiry_date=current_date;
  RAISE EXCEPTION 'Owner executor can override expiry';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $owner_column_denial$;
RESET ROLE;

-- Inject a missing dependency permission INSIDE the RPC's nested audit path.
-- The exception subtransaction restores this temporary test revocation.
DO $atomic_rollback$
DECLARE before_count bigint; after_count bigint; before_audit bigint; before_heads bigint;
BEGIN
 SELECT count(*) INTO before_count FROM private.membership_plans;
 SELECT count(*) INTO before_audit FROM private.audit_events;
 SELECT count(*) INTO before_heads FROM private.audit_chain_heads;
 BEGIN
  REVOKE EXECUTE ON FUNCTION private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz) FROM gym_owner_executor;
  SET LOCAL ROLE service_role;
  PERFORM api.owner_save_membership_plan('00000000-0000-4000-8000-000000000001',NULL,'Synthetic rollback',700,true);
  RAISE EXCEPTION 'Nested audit dependency failure was ignored';
 EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  IF SQLERRM NOT LIKE '%compute_audit_event_hash%' THEN RAISE; END IF;
 END;
 SELECT count(*) INTO after_count FROM private.membership_plans;
 IF before_count<>after_count OR EXISTS(SELECT 1 FROM private.membership_plans WHERE name='Synthetic rollback') THEN
  RAISE EXCEPTION 'Failed transaction retained partial business data';
 END IF;
 IF (SELECT count(*) FROM private.audit_events)<>before_audit OR (SELECT count(*) FROM private.audit_chain_heads)<>before_heads THEN
  RAISE EXCEPTION 'Failed RPC retained partial audit data';
 END IF;
END $atomic_rollback$;

DO $immutable_history$
BEGIN
 BEGIN
  UPDATE private.audit_events SET event_type='changed';
  RAISE EXCEPTION 'Audit mutation accepted';
 EXCEPTION WHEN object_not_in_prerequisite_state THEN
  IF SQLERRM <> 'Audit events are append-only and cannot be modified or deleted' THEN RAISE; END IF;
 END;
 BEGIN
  DELETE FROM private.payment_events;
  RAISE EXCEPTION 'Payment history deletion accepted';
 EXCEPTION WHEN object_not_in_prerequisite_state THEN
  IF SQLERRM <> 'PAYMENT_HISTORY_APPEND_ONLY' THEN RAISE; END IF;
 END;
END $immutable_history$;
ROLLBACK;
\echo 'PASS: restricted executor business paths, negative access, idempotency, immutable history and rollback (synthetic native SQL only).'
