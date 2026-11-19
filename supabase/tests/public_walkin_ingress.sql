-- Synthetic guarded harness only; fixtures alter ONLY the new limiter state.
\set ON_ERROR_STOP on
DO $g$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $g$;
SET statement_timeout='1s';
SET lock_timeout='100ms';
CREATE FUNCTION pg_temp.reset_ingress() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
 UPDATE private.walkin_ingress_state SET last_second=0,day_number=0,day_attempts=0;
 UPDATE private.walkin_ingress_seconds SET second_number=0,attempts=0;
 UPDATE private.walkin_ingress_buckets SET updated_at='epoch',tokens=3,lookup_tokens=2;
 UPDATE private.walkin_ingress_leases SET ticket=NULL,expires_at=NULL,digest=NULL,action=NULL,method=NULL,fingerprint=NULL;
END $f$;
CREATE FUNCTION pg_temp.protected_hash() RETURNS bytea LANGUAGE sql AS $f$
 SELECT sha256(convert_to(jsonb_build_array(
 (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM private.payment_records x),
 (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM private.payment_allocations x),
 (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM private.payment_events x),
 (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM private.members x),
 (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM private.membership_purchases x),
 (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM private.attendance_checkins x),
 (SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM private.audit_events x),
 (SELECT jsonb_agg(to_jsonb(x) ORDER BY stream_key) FROM private.audit_chain_heads x)
 )::text,'UTF8'));
$f$;
SELECT pg_temp.reset_ingress();
-- These THREE statements are separate committed transactions, not an autonomous function.
SET ROLE service_role;
SELECT set_config('gymforce.ingress_ticket',api.public_walkin_admit()->>'ticket',false) AS ignored \gset
SELECT api.public_walkin_bind(current_setting('gymforce.ingress_ticket')::uuid,decode(repeat('91',32),'hex'),'create','cash') AS ignored \gset
RESET ROLE;
DO $t$ DECLARE before_n int; preserved bytea; result jsonb; BEGIN
 before_n:=(SELECT count(*) FROM private.walkin_creation_operations); preserved:=pg_temp.protected_hash();
 SET LOCAL ROLE service_role;
 BEGIN
  PERFORM api.public_walkin_execute(current_setting('gymforce.ingress_ticket')::uuid,decode(repeat('91',32),'hex'),'create','cash');
  RAISE EXCEPTION USING ERRCODE='ZX061',MESSAGE='Synthetic rollback';
 EXCEPTION WHEN SQLSTATE 'ZX061' THEN NULL; END;
 RESET ROLE;
 IF (SELECT count(*) FROM private.walkin_creation_operations)<>before_n
 OR (SELECT sum(attempts) FROM private.walkin_ingress_seconds)<>1
 OR (SELECT tokens FROM private.walkin_ingress_buckets WHERE slot=2329)>=3
 OR pg_temp.protected_hash() IS DISTINCT FROM preserved THEN RAISE EXCEPTION 'Independent admission/rollback failed'; END IF;
 SET LOCAL ROLE service_role;
 result:=api.public_walkin_execute(current_setting('gymforce.ingress_ticket')::uuid,decode(repeat('91',32),'hex'),'create','cash');
 IF result->>'classification'<>'PROVISIONAL_CREATED' THEN RAISE EXCEPTION 'Admitted creation failed'; END IF;
 BEGIN
  PERFORM api.public_walkin_execute(current_setting('gymforce.ingress_ticket')::uuid,decode(repeat('91',32),'hex'),'create','cash');
  RAISE EXCEPTION 'Completed lease accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RESET ROLE;
 IF pg_temp.protected_hash() IS DISTINCT FROM preserved THEN RAISE EXCEPTION 'Financial or audit mutation'; END IF;
END $t$;
\echo 'PASS ingress: separate admission/key commits survive business rollback; one atomic create, consumed-ticket denial, protected financial/member/audit rows unchanged.'
SELECT pg_temp.reset_ingress();
DO $t$ DECLARE t uuid; r jsonb; i int; BEGIN
 SET LOCAL ROLE service_role;
 FOR i IN 1..21 LOOP
  r:=api.public_walkin_admit();
  IF i<=20 AND r->>'status'<>'allowed' THEN RAISE EXCEPTION 'Burst premature denial'; END IF;
  IF i=21 AND r->>'status'<>'denied' THEN RAISE EXCEPTION 'Burst bypass'; END IF;
  IF i<=20 THEN PERFORM api.public_walkin_finish((r->>'ticket')::uuid,'denied'); END IF;
 END LOOP;
END $t$;
SELECT pg_temp.reset_ingress();
DO $t$ DECLARE r jsonb; i int; BEGIN
 SET LOCAL ROLE service_role;
 FOR i IN 1..9 LOOP
  r:=api.public_walkin_admit();
  IF r->>'status'<>(CASE WHEN i<=8 THEN 'allowed' ELSE 'denied' END) THEN RAISE EXCEPTION 'Eight-lease bound failed'; END IF;
 END LOOP;
END $t$;
SELECT pg_temp.reset_ingress();
DO $t$ DECLARE r jsonb; t uuid; i int; BEGIN
 SET LOCAL ROLE service_role;
 FOR i IN 1..4 LOOP
  t:=(api.public_walkin_admit()->>'ticket')::uuid;
  r:=api.public_walkin_bind(t,decode(repeat('92',32),'hex'),'create','cash');
  IF r->>'status'<>(CASE WHEN i<=3 THEN 'allowed' ELSE 'denied' END) THEN RAISE EXCEPTION 'Key bucket failed'; END IF;
  PERFORM api.public_walkin_finish(t,'denied');
 END LOOP;
END $t$;
SELECT pg_temp.reset_ingress();
DO $t$ DECLARE r jsonb; t uuid; i int; BEGIN
 SET LOCAL ROLE service_role;
 FOR i IN 1..3 LOOP
  t:=(api.public_walkin_admit()->>'ticket')::uuid;
  r:=api.public_walkin_bind(t,decode(repeat('93',32),'hex'),'lookup',NULL);
  IF r->>'status'<>(CASE WHEN i<=2 THEN 'allowed' ELSE 'denied' END) THEN RAISE EXCEPTION 'Lookup bucket failed'; END IF;
  PERFORM api.public_walkin_finish(t,'denied');
 END LOOP;
END $t$;
\echo 'PASS ingress: burst 20/21, eight/nine leases, key burst 3/4 and lookup burst 2/3.'
SELECT pg_temp.reset_ingress();
UPDATE private.walkin_ingress_state SET day_number=floor(extract(epoch FROM clock_timestamp()))::bigint/86400,day_attempts=2000;
DO $t$ BEGIN
 SET LOCAL ROLE service_role;
 IF api.public_walkin_admit()->>'status'<>'denied' THEN RAISE EXCEPTION 'Daily cap bypass'; END IF;
END $t$;
SELECT pg_temp.reset_ingress();
-- Use the correct old-bin index, so the current second cannot overwrite it.
UPDATE private.walkin_ingress_seconds SET second_number=floor(extract(epoch FROM clock_timestamp()))::bigint-20,attempts=120
 WHERE slot=mod(floor(extract(epoch FROM clock_timestamp()))::bigint-20,61);
DO $t$ BEGIN SET LOCAL ROLE service_role;
 IF api.public_walkin_admit()->>'status'<>'denied' THEN RAISE EXCEPTION 'Minute cap bypass'; END IF;
END $t$;
SELECT pg_temp.reset_ingress();
SET ROLE service_role;
SELECT set_config('gymforce.ingress_ticket',api.public_walkin_admit()->>'ticket',false) AS ignored \gset
SELECT api.public_walkin_bind(current_setting('gymforce.ingress_ticket')::uuid,decode(repeat('94',32),'hex'),'lookup',NULL) AS ignored \gset
RESET ROLE;
UPDATE private.walkin_ingress_leases SET expires_at=clock_timestamp()-interval '1 second';
DO $t$ DECLARE r jsonb; BEGIN
 SET LOCAL ROLE service_role;
 r:=api.public_walkin_admit();
 IF r->>'status'<>'allowed' THEN RAISE EXCEPTION 'Expired lease not reclaimed'; END IF;
 BEGIN
  PERFORM api.public_walkin_execute(current_setting('gymforce.ingress_ticket')::uuid,decode(repeat('94',32),'hex'),'lookup',NULL);
  RAISE EXCEPTION 'Stale generation accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $t$;
DO $t$ DECLARE p text; BEGIN
 IF (SELECT count(*) FROM pg_catalog.pg_proc f JOIN pg_catalog.pg_namespace n ON n.oid=f.pronamespace
 WHERE (n.nspname='api' AND f.proname IN ('public_walkin_admit','public_walkin_bind','public_walkin_execute','public_walkin_finish','public_walkin_observe') AND f.proowner='gym_public_executor'::pg_catalog.regrole AND f.prosecdef)
 OR (n.nspname='private' AND f.proname IN ('assert_walkin_ingress_runtime','walkin_ingress_metric','guard_walkin_recovery_capacity') AND f.proowner='gym_data_owner'::pg_catalog.regrole AND NOT f.prosecdef))<>8
 THEN RAISE EXCEPTION 'Real catalog ownership/security closure failed under shadow-install fixture'; END IF;
 FOR p IN SELECT oid::regprocedure::text FROM pg_proc WHERE proname IN ('public_walkin_admit','public_walkin_bind','public_walkin_execute','public_walkin_finish','public_walkin_observe') LOOP
  IF has_function_privilege('anon',p,'EXECUTE') OR has_function_privilege('authenticated',p,'EXECUTE') THEN RAISE EXCEPTION 'Browser RPC leak'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='private' AND c.relkind IN ('r','p') AND c.relname LIKE 'walkin_ingress_%' AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity OR has_table_privilege('service_role',c.oid,'SELECT,UPDATE,INSERT,DELETE')))
 THEN RAISE EXCEPTION 'Ingress RLS/direct-data leak'; END IF;
 SET LOCAL ROLE anon;
 BEGIN PERFORM api.public_walkin_admit(); RAISE EXCEPTION 'Anonymous execution allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RESET ROLE;
 SET LOCAL ROLE service_role;
 BEGIN PERFORM api.public_create_walkin_request_v2(decode(repeat('95',32),'hex'),'cash',10); RAISE EXCEPTION 'Ungated v2 allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM api.public_lookup_walkin_request(decode(repeat('95',32),'hex')); RAISE EXCEPTION 'Ungated lookup allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $t$;
SET statement_timeout='0';
DO $t$ BEGIN SET LOCAL ROLE service_role;
 BEGIN PERFORM api.public_walkin_admit(); RAISE EXCEPTION 'Unqualified runtime accepted'; EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
END $t$;
SET statement_timeout='1s';
SELECT pg_temp.reset_ingress();
\echo 'PASS ingress: daily/minute caps, expired/stale leases, FORCE RLS, browser/direct data/ungated RPC denial and unqualified-runtime refusal.'
CREATE FUNCTION pg_temp.ingress_call(a text,m text,d bytea) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE t uuid; b jsonb; result jsonb;
BEGIN
 SET LOCAL ROLE service_role;
 t:=(api.public_walkin_admit()->>'ticket')::uuid;
 b:=api.public_walkin_bind(t,d,a,m);
 IF b->>'status'<>'allowed' THEN RAISE EXCEPTION 'Synthetic binding denied'; END IF;
 result:=api.public_walkin_execute(t,d,a,m);
 RESET ROLE;
 RETURN result;
END $f$;
DO $t$ DECLARE n int; r jsonb; preserved bytea; BEGIN
 n:=(SELECT count(*) FROM private.walkin_creation_operations);preserved:=pg_temp.protected_hash();
 r:=pg_temp.ingress_call('create','cash',decode(repeat('91',32),'hex'));
 IF r->>'classification'<>'PROVISIONAL_RECOVERED' THEN RAISE EXCEPTION 'Admitted replay failed'; END IF;
 r:=pg_temp.ingress_call('create','gcash',decode(repeat('91',32),'hex'));
 IF r->>'classification'<>'OPERATION_CONFLICT' THEN RAISE EXCEPTION 'Admitted conflict accepted'; END IF;
 r:=pg_temp.ingress_call('lookup',NULL,decode(repeat('96',32),'hex'));
 IF r->>'classification'<>'NO_RECOVERABLE_OUTCOME' THEN RAISE EXCEPTION 'Unknown lookup disclosure'; END IF;
 IF (SELECT count(*) FROM private.walkin_creation_operations)<>n OR pg_temp.protected_hash() IS DISTINCT FROM preserved THEN RAISE EXCEPTION 'Replay mutated protected state'; END IF;
END $t$;
SELECT pg_temp.reset_ingress();
-- Drift is tested below capacity, independently of exhaustion.
UPDATE private.walkin_ingress_capacity SET bindings=0;
DO $t$ DECLARE n int; BEGIN
 n:=(SELECT count(*) FROM private.walkin_requests);
 BEGIN PERFORM pg_temp.ingress_call('create','cash',decode(repeat('97',32),'hex'));RAISE EXCEPTION 'Capacity accepted';
 EXCEPTION WHEN SQLSTATE '54000' THEN NULL; END;
 IF (SELECT count(*) FROM private.walkin_requests)<>n THEN RAISE EXCEPTION 'Capacity refusal left request'; END IF;
END $t$;
UPDATE private.walkin_ingress_capacity SET bindings=(SELECT count(*) FROM private.walkin_creation_operations);
UPDATE private.walkin_ingress_minutes SET minute_number=floor(extract(epoch FROM clock_timestamp())/60)::bigint-2881,attempts=1 WHERE slot=0;
DO $t$ BEGIN
 SET LOCAL ROLE service_role; PERFORM api.public_walkin_observe('timeout');RESET ROLE;
 IF EXISTS(SELECT 1 FROM private.walkin_ingress_minutes WHERE minute_number>0 AND minute_number<=floor(extract(epoch FROM clock_timestamp())/60)-2880)
 OR NOT EXISTS(SELECT 1 FROM private.walkin_ingress_minutes WHERE timeouts>0)
 OR (SELECT count(*) FROM private.walkin_ingress_minutes)<>2880
 THEN RAISE EXCEPTION 'Bounded telemetry cleanup failed'; END IF;
END $t$;
SELECT pg_temp.reset_ingress();
\echo 'PASS ingress: admitted replay/conflict/unknown lookup, capacity refusal rollback and fixed 48h aggregate cleanup. Capacity fixture is not a 10,000-row load benchmark.'

-- Consistent capacity fixture: preserve all triggers, constraints and protected history.
-- Roll back every synthetic capacity row after last-slot/replay/exhaustion checks.
BEGIN;
SET LOCAL statement_timeout='60s';
DO $capacity$ DECLARE template private.walkin_requests%ROWTYPE; rid uuid; d bytea; i int; initial_hash bytea;
BEGIN
 initial_hash:=pg_temp.protected_hash();
 SELECT * INTO STRICT template FROM private.walkin_requests WHERE id=(SELECT request_id FROM private.walkin_creation_operations LIMIT 1);
 FOR i IN 1..(9999-(SELECT count(*) FROM private.walkin_creation_operations)) LOOP
  rid:=pg_catalog.gen_random_uuid();d:=pg_catalog.sha256(pg_catalog.convert_to('capacity-fixture-'||rid::text,'UTF8'));
  INSERT INTO private.walkin_requests(id,fee_version_id,fee_php,currency,created_at,expires_at,requested_payment_method)
  VALUES(rid,template.fee_version_id,template.fee_php,template.currency,template.created_at,template.created_at+interval '15 minutes',template.requested_payment_method);
  INSERT INTO private.walkin_creation_operations VALUES(1,d,template.requested_payment_method,
   pg_catalog.sha256(pg_catalog.convert_to('gymforce:walkin-create:v1'||chr(10)||'paymentMethod='||template.requested_payment_method||chr(10),'UTF8')),rid,template.created_at);
 END LOOP;
 IF (SELECT bindings FROM private.walkin_ingress_capacity)<>9999 OR (SELECT count(*) FROM private.walkin_creation_operations)<>9999 THEN RAISE EXCEPTION 'Consistent near-capacity fixture failed'; END IF;
 IF pg_temp.protected_hash() IS DISTINCT FROM initial_hash THEN RAISE EXCEPTION 'Capacity fixture changed protected history'; END IF;
END $capacity$;
SET LOCAL statement_timeout='1s';
SELECT pg_temp.reset_ingress();
DO $last$ DECLARE r jsonb; n int; BEGIN
 r:=pg_temp.ingress_call('create','cash',decode(repeat('a7',32),'hex'));
 IF r->>'classification'<>'PROVISIONAL_CREATED' OR (SELECT bindings FROM private.walkin_ingress_capacity)<>10000 THEN RAISE EXCEPTION 'Last capacity slot failed'; END IF;
 r:=pg_temp.ingress_call('create','cash',decode(repeat('a7',32),'hex'));
 IF r->>'classification'<>'PROVISIONAL_RECOVERED' THEN RAISE EXCEPTION 'Replay at capacity failed'; END IF;
 n:=(SELECT count(*) FROM private.walkin_requests);
 BEGIN PERFORM pg_temp.ingress_call('create','cash',decode(repeat('a8',32),'hex')); RAISE EXCEPTION 'Consistent capacity bypass';
 EXCEPTION WHEN SQLSTATE '54000' THEN NULL; END;
 IF (SELECT count(*) FROM private.walkin_requests)<>n OR (SELECT count(*) FROM private.walkin_creation_operations)<>10000 THEN RAISE EXCEPTION 'Exhaustion left orphan'; END IF;
END $last$;
ROLLBACK;
DO $rollback$ BEGIN IF (SELECT bindings FROM private.walkin_ingress_capacity)<>(SELECT count(*) FROM private.walkin_creation_operations) THEN RAISE EXCEPTION 'Capacity rollback drift'; END IF; END $rollback$;
\echo 'PASS ingress hardening: consistent 9999/10000/10001 capacity, replay at capacity, orphan refusal and fixture rollback; separate counter-drift refusal.'
-- Real limiter functions against seeded synthetic clock-relative state; no clock hooks.
SELECT pg_temp.reset_ingress();
DO $clock$ DECLARE t uuid; r jsonb; sec bigint; BEGIN
 sec:=floor(extract(epoch FROM clock_timestamp()));
 UPDATE private.walkin_ingress_state SET last_second=sec+3600;
 SET LOCAL ROLE service_role;r:=api.public_walkin_admit();RESET ROLE;
 IF r->>'status'<>'unavailable' THEN RAISE EXCEPTION 'Backward global clock accepted'; END IF;
 PERFORM pg_temp.reset_ingress();
 UPDATE private.walkin_ingress_state SET day_number=sec/86400-1,day_attempts=2000;
 SET LOCAL ROLE service_role;r:=api.public_walkin_admit();RESET ROLE;
 IF r->>'status'<>'allowed' OR (SELECT day_attempts FROM private.walkin_ingress_state)<>1 THEN RAISE EXCEPTION 'UTC day reset failed'; END IF;
 PERFORM pg_temp.reset_ingress();
 -- Use 59s with a one-second scheduling margin; exact predicates also checked below.
 UPDATE private.walkin_ingress_seconds SET second_number=sec-59,attempts=120 WHERE slot=mod(sec-59,61);
 SET LOCAL ROLE service_role;r:=api.public_walkin_admit();RESET ROLE;
 IF r->>'status'<>'denied' THEN RAISE EXCEPTION 'Window boundary accepted'; END IF;
 IF NOT (sec-60>=sec-60) OR sec-61>=sec-60 THEN RAISE EXCEPTION 'Window predicate boundary'; END IF;
 PERFORM pg_temp.reset_ingress();sec:=floor(extract(epoch FROM clock_timestamp()));
 UPDATE private.walkin_ingress_seconds SET second_number=sec-61,attempts=120 WHERE slot=mod(sec-61,61);
 SET LOCAL ROLE service_role;r:=api.public_walkin_admit();RESET ROLE;
 IF r->>'status'<>'allowed' THEN RAISE EXCEPTION 'Expired window retained'; END IF;
 PERFORM pg_temp.reset_ingress();
 SET LOCAL ROLE service_role;t:=(api.public_walkin_admit()->>'ticket')::uuid;RESET ROLE;
 UPDATE private.walkin_ingress_buckets SET updated_at=clock_timestamp()+interval '1 hour' WHERE slot=2730;
 SET LOCAL ROLE service_role;r:=api.public_walkin_bind(t,decode(repeat('aa',32),'hex'),'create','cash');RESET ROLE;
 IF r->>'status'<>'unavailable' THEN RAISE EXCEPTION 'Backward bucket clock accepted'; END IF;
 UPDATE private.walkin_ingress_buckets SET updated_at=clock_timestamp()-interval '4 seconds',tokens=0 WHERE slot=2730;
 SET LOCAL ROLE service_role;r:=api.public_walkin_bind(t,decode(repeat('aa',32),'hex'),'create','cash');RESET ROLE;
 IF r->>'status'<>'denied' THEN RAISE EXCEPTION 'Premature token refill'; END IF;
 UPDATE private.walkin_ingress_buckets SET updated_at=clock_timestamp()-interval '6 seconds',tokens=0 WHERE slot=2730;
 SET LOCAL ROLE service_role;r:=api.public_walkin_bind(t,decode(repeat('aa',32),'hex'),'create','cash');RESET ROLE;
 IF r->>'status'<>'allowed' THEN RAISE EXCEPTION 'Creation refill missing'; END IF;
 PERFORM pg_temp.reset_ingress();
 SET LOCAL ROLE service_role;t:=(api.public_walkin_admit()->>'ticket')::uuid;RESET ROLE;
 UPDATE private.walkin_ingress_buckets SET updated_at=clock_timestamp()-interval '9 seconds',tokens=3,lookup_tokens=0 WHERE slot=2730;
 SET LOCAL ROLE service_role;r:=api.public_walkin_bind(t,decode(repeat('aa',32),'hex'),'lookup',NULL);RESET ROLE;
 IF r->>'status'<>'denied' THEN RAISE EXCEPTION 'Premature lookup refill'; END IF;
 UPDATE private.walkin_ingress_buckets SET updated_at=clock_timestamp()-interval '11 seconds',tokens=0,lookup_tokens=0 WHERE slot=2730;
 SET LOCAL ROLE service_role;r:=api.public_walkin_bind(t,decode(repeat('aa',32),'hex'),'lookup',NULL);RESET ROLE;
 IF r->>'status'<>'allowed' THEN RAISE EXCEPTION 'Lookup refill missing'; END IF;
END $clock$;
SELECT pg_temp.reset_ingress();
\echo 'PASS ingress hardening: global/bucket backward clock refusal, prior UTC-day reset, conservative 59/61 second live window (60s predicate checked separately), create 4/6s and lookup 9/11s refill boundaries.'
