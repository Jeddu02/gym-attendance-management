\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $guard$;
SET LOCAL ROLE service_role;
SELECT api.owner_set_walkin_fee('00000000-0000-4000-8000-000000000001',125,'Synthetic recovery fee');
RESET ROLE;
CREATE FUNCTION pg_temp.recovery_preserved_rows() RETURNS bytea LANGUAGE sql AS $hash$
 SELECT sha256(convert_to(jsonb_build_array(
  (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.id),'[]'::jsonb) FROM private.payment_records p),
  (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.id),'[]'::jsonb) FROM private.payment_allocations p),
  (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.id),'[]'::jsonb) FROM private.members p),
  (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.id),'[]'::jsonb) FROM private.membership_purchases p),
  (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.id),'[]'::jsonb) FROM private.audit_events p),
  (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.stream_key),'[]'::jsonb) FROM private.audit_chain_heads p),
  to_regclass('supabase_migrations.schema_migrations')::text
 )::text,'UTF8'));
$hash$;
DO $tests$
DECLARE first jsonb; replay jsonb; result jsonb; id uuid; n bigint; audit_n bigint; payments bigint; attendance bigint; preserved bytea;
BEGIN
 preserved:=pg_temp.recovery_preserved_rows();
 SELECT count(*) INTO n FROM private.walkin_requests;
 SELECT count(*) INTO audit_n FROM private.audit_events;
 SELECT count(*) INTO payments FROM private.payment_records;
 SELECT count(*) INTO attendance FROM private.attendance_checkins;
 SET LOCAL ROLE service_role;
 BEGIN
  PERFORM api.public_create_walkin_request('cash',100);
  RAISE EXCEPTION 'Unkeyed transport bypass remains';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 first:=api.public_create_walkin_request_v2(decode(repeat('61',32),'hex'),'cash',100);
 IF first->>'classification'<>'PROVISIONAL_CREATED' THEN RAISE EXCEPTION 'First creation failed'; END IF;
 id:=(first->'request'->>'id')::uuid;
 replay:=api.public_create_walkin_request_v2(decode(repeat('61',32),'hex'),'cash',100);
 IF replay->>'classification'<>'PROVISIONAL_RECOVERED' OR first->'request' IS DISTINCT FROM replay->'request'
 THEN RAISE EXCEPTION 'Replay changed snapshot'; END IF;
 result:=api.public_create_walkin_request_v2(decode(repeat('61',32),'hex'),'gcash',100);
 IF result<>jsonb_build_object('classification','OPERATION_CONFLICT') THEN RAISE EXCEPTION 'Conflict accepted'; END IF;
 IF api.public_lookup_walkin_request(decode(repeat('61',32),'hex'))->'request' IS DISTINCT FROM first->'request'
 THEN RAISE EXCEPTION 'Lookup changed outcome'; END IF;
 IF api.public_lookup_walkin_request(decode(repeat('62',32),'hex'))<>jsonb_build_object('classification','NO_RECOVERABLE_OUTCOME')
 THEN RAISE EXCEPTION 'Unknown key lookup leaked'; END IF;
 BEGIN
  PERFORM api.public_create_walkin_request_v2(decode(repeat('63',32),'hex'),'cash',100);
  RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='Synthetic rollback';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 RESET ROLE;
 IF EXISTS(SELECT 1 FROM private.walkin_creation_operations WHERE capability_digest=decode(repeat('63',32),'hex'))
 OR (SELECT count(*) FROM private.walkin_requests)<>n+1
 OR (SELECT count(*) FROM private.payment_records)<>payments
 OR (SELECT count(*) FROM private.attendance_checkins)<>attendance
 OR (SELECT count(*) FROM private.audit_events)<>audit_n
 OR pg_temp.recovery_preserved_rows() IS DISTINCT FROM preserved
 THEN RAISE EXCEPTION 'Replay/rollback changed unrelated state'; END IF;
 IF (SELECT payload_fingerprint FROM private.walkin_creation_operations WHERE request_id=id)
 <>sha256(convert_to(E'gymforce:walkin-create:v1\npaymentMethod=cash\n','UTF8'))
 THEN RAISE EXCEPTION 'Canonical fingerprint mismatch'; END IF;
 IF (first->'request'->>'expiresAt')::timestamptz-(first->'request'->>'createdAt')::timestamptz<>interval '15 minutes'
 THEN RAISE EXCEPTION 'Request lifetime changed'; END IF;
 SET LOCAL ROLE service_role;
 -- A different key is deliberately a different anonymous operation.
 PERFORM api.public_create_walkin_request_v2(decode(repeat('64',32),'hex'),'cash',100);
 RESET ROLE;
 IF (SELECT count(*) FROM private.walkin_requests)<>n+2 THEN RAISE EXCEPTION 'Different-key semantics changed'; END IF;
 FOR result IN SELECT jsonb_build_object('role',r) FROM unnest(ARRAY['anon','authenticated','gym_owner_executor','gym_checkin_executor']) r LOOP
  IF has_function_privilege(result->>'role','api.public_create_walkin_request_v2(bytea,text,integer)','EXECUTE')
  OR has_function_privilege(result->>'role','api.public_lookup_walkin_request(bytea)','EXECUTE')
  THEN RAISE EXCEPTION 'Unexpected recovery execution'; END IF;
 END LOOP;
 IF has_table_privilege('service_role','private.walkin_creation_operations','SELECT,INSERT,UPDATE,DELETE')
 OR NOT (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='private.walkin_creation_operations'::regclass)
 THEN RAISE EXCEPTION 'Recovery security boundary changed'; END IF;
END $tests$;
-- Failure injected on the NEW binding, with all original guards still enabled.
CREATE FUNCTION pg_temp.reject_recovery_binding() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='Synthetic binding failure'; END $f$;
CREATE TRIGGER synthetic_binding_failure BEFORE INSERT ON private.walkin_creation_operations
 FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_recovery_binding();
DO $fault$ DECLARE n bigint; preserved bytea; BEGIN
 preserved:=pg_temp.recovery_preserved_rows();
 SELECT count(*) INTO n FROM private.walkin_requests;
 SET LOCAL ROLE service_role;
 BEGIN
  PERFORM api.public_create_walkin_request_v2(decode(repeat('68',32),'hex'),'cash',100);
  RAISE EXCEPTION 'Expected binding failure';
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN NULL; END;
 RESET ROLE;
 IF pg_temp.recovery_preserved_rows() IS DISTINCT FROM preserved
 OR (SELECT count(*) FROM private.walkin_requests)<>n OR EXISTS(SELECT 1 FROM private.walkin_creation_operations WHERE capability_digest=decode(repeat('68',32),'hex'))
 THEN RAISE EXCEPTION 'Failed binding left an orphan request'; END IF;
END $fault$;
DROP TRIGGER synthetic_binding_failure ON private.walkin_creation_operations;
DO $expiry_and_owner$
DECLARE created timestamptz:=clock_timestamp()-interval '20 minutes'; fee uuid; expired uuid;
 result jsonb; first jsonb; confirmed jsonb; again jsonb; op uuid:=gen_random_uuid(); before_n bigint;
BEGIN
 -- Synthetic historical fixture, identical to the established expired-receipt
 -- tests: insert a NEW already-expired snapshot, never alter an existing one.
 INSERT INTO private.walkin_fee_versions(fee_php,created_by,effective_from,created_at)
 VALUES(91,'00000000-0000-4000-8000-000000000001',created-interval '1 hour',created-interval '1 hour') RETURNING id INTO fee;
 INSERT INTO private.walkin_requests(fee_version_id,fee_php,currency,created_at,expires_at,requested_payment_method)
 VALUES(fee,91,'PHP',created,created+interval '15 minutes','cash') RETURNING id INTO expired;
 INSERT INTO private.walkin_creation_operations VALUES(1,decode(repeat('67',32),'hex'),'cash',sha256(convert_to(E'gymforce:walkin-create:v1\npaymentMethod=cash\n','UTF8')),expired,created);
 SET LOCAL ROLE service_role;
 IF api.public_lookup_walkin_request(decode(repeat('67',32),'hex'))<>jsonb_build_object('classification','RECOVERY_CLOSED')
 OR api.public_create_walkin_request_v2(decode(repeat('67',32),'hex'),'cash',100)<>jsonb_build_object('classification','RECOVERY_CLOSED')
 THEN RAISE EXCEPTION 'Expired key revived or disclosed'; END IF;
 first:=api.public_lookup_walkin_request(decode(repeat('61',32),'hex'));
 PERFORM api.owner_set_walkin_fee('00000000-0000-4000-8000-000000000001',126,'Synthetic fee changed after creation');
 IF api.public_create_walkin_request_v2(decode(repeat('61',32),'hex'),'cash',100)->'request' IS DISTINCT FROM first->'request'
 THEN RAISE EXCEPTION 'Fee change repriced replay'; END IF;
 BEGIN
  PERFORM api.owner_confirm_walkin('00000000-0000-4000-8000-000000000002',(first->'request'->>'id')::uuid,op,125,'cash',true);
  RAISE EXCEPTION 'Unauthorized Owner accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 confirmed:=api.owner_confirm_walkin('00000000-0000-4000-8000-000000000001',(first->'request'->>'id')::uuid,op,125,'cash',true);
 again:=api.owner_confirm_walkin('00000000-0000-4000-8000-000000000001',(first->'request'->>'id')::uuid,op,125,'cash',true);
 IF confirmed->>'outcome'<>'confirmed' OR again->>'replayed'<>'true'
 OR api.public_lookup_walkin_request(decode(repeat('61',32),'hex'))<>jsonb_build_object('classification','RECOVERY_CLOSED')
 THEN RAISE EXCEPTION 'Owner outcome/replay boundary failed'; END IF;
 BEGIN
  PERFORM api.public_create_walkin_request_v2(decode(repeat('69',32),'hex'),'cash',1);
  RAISE EXCEPTION 'Creation limiter bypassed';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'WALKIN_RATE_LIMITED' THEN RAISE; END IF; END;
 RESET ROLE;
 IF (SELECT count(*) FROM private.payment_records WHERE operation_id=op)<>1
 OR (SELECT count(*) FROM private.payment_allocations WHERE walkin_request_id=(first->'request'->>'id')::uuid)<>1
 OR (SELECT count(*) FROM private.attendance_checkins WHERE walkin_request_id=(first->'request'->>'id')::uuid)<>1
 OR EXISTS(SELECT 1 FROM private.walkin_creation_operations WHERE capability_digest=decode(repeat('69',32),'hex'))
 THEN RAISE EXCEPTION 'Financial uniqueness/limit rollback failed'; END IF;
 SELECT count(*) INTO before_n FROM private.walkin_creation_operations;
 SET LOCAL ROLE service_role;
 BEGIN DELETE FROM private.walkin_creation_operations; RAISE EXCEPTION 'Replay evidence deletion allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RESET ROLE;
 IF (SELECT count(*) FROM private.walkin_creation_operations)<>before_n THEN RAISE EXCEPTION 'Replay evidence lost'; END IF;
END $expiry_and_owner$;
SELECT 'PASS: creation/replay/conflict/lookup/rollback/canonical/15-minute/different-key/ACL/RLS, no payment or attendance effects';
SELECT 'PASS: pre-binding fault rollback, expired/terminal replay, changed fee, Owner authorization/replay/financial uniqueness, creation limit and deletion denial';
ROLLBACK;
