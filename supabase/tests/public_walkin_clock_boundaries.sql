-- Synthetic test only. No deployable clock hook and no historical SQL change.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path=pg_catalog;
SET LOCAL statement_timeout='1s';
SET LOCAL lock_timeout='100ms';
SET LOCAL timezone='UTC';
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('server_version_num')<>'170012'
 OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
 THEN RAISE EXCEPTION 'Isolated PG17 fixture required'; END IF;
END $guard$;
CREATE TEMP TABLE gf_clock_original(signature text,definition text);
CREATE FUNCTION private.gf_test_clock() RETURNS timestamptz LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
BEGIN
 IF pg_catalog.current_database()<>'gymforce_batch1_synthetic' OR pg_catalog.current_setting('gymforce.synthetic_run_id',true) IS NULL THEN RAISE EXCEPTION 'Synthetic clock refused'; END IF;
 RETURN pg_catalog.current_setting('gymforce.test_clock')::pg_catalog.timestamptz;
END $f$;
REVOKE ALL ON FUNCTION private.gf_test_clock() FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION private.gf_test_clock() TO gym_public_executor;
DO $copies$ DECLARE original text; copy text; name text; signature text; calls int; expected int; BEGIN
 FOR name,signature,expected IN SELECT * FROM (VALUES
 ('public_walkin_admit','api.public_walkin_admit()',3),
 ('public_walkin_bind','api.public_walkin_bind(uuid,bytea,text,text)',1)) x(n,s,c)
 LOOP
  original:=pg_get_functiondef(signature::regprocedure);
  INSERT INTO pg_temp.gf_clock_original VALUES(signature,original);
  calls:=(length(original)-length(replace(original,'pg_catalog.clock_timestamp()','')))/length('pg_catalog.clock_timestamp()');
  IF calls<>expected THEN RAISE EXCEPTION 'Unreviewed clock surface'; END IF;
  copy:=replace(replace(original,'api.'||name||'(','api.gf_clock_'||name||'('),'pg_catalog.clock_timestamp()','private.gf_test_clock()');
  IF copy=original OR replace(replace(copy,'api.gf_clock_'||name||'(','api.'||name||'('),'private.gf_test_clock()','pg_catalog.clock_timestamp()')<>original THEN RAISE EXCEPTION 'Clock copy drift'; END IF;
  EXECUTE copy;
  EXECUTE format('ALTER FUNCTION api.gf_clock_%s(%s) OWNER TO gym_public_executor',name,CASE WHEN name='public_walkin_admit' THEN '' ELSE 'uuid,bytea,text,text' END);
  EXECUTE format('REVOKE ALL ON FUNCTION api.gf_clock_%s(%s) FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_checkin_executor',name,CASE WHEN name='public_walkin_admit' THEN '' ELSE 'uuid,bytea,text,text' END);
 END LOOP;
END $copies$;
CREATE FUNCTION pg_temp.clock_reset(at_time timestamptz) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN
 PERFORM set_config('gymforce.test_clock',at_time::text,true);
 UPDATE private.walkin_ingress_state SET last_second=0,day_number=0,day_attempts=0;
 UPDATE private.walkin_ingress_seconds SET second_number=0,attempts=0;
 UPDATE private.walkin_ingress_buckets SET updated_at='epoch',tokens=3,lookup_tokens=2;
 UPDATE private.walkin_ingress_leases SET ticket=NULL,expires_at=NULL,digest=NULL,action=NULL,method=NULL,fingerprint=NULL;
END $f$;
DO $day$ DECLARE r jsonb; sec bigint; BEGIN
 PERFORM pg_temp.clock_reset('2030-01-01 23:59:59.999999+00');
 sec:=floor(extract(epoch FROM private.gf_test_clock()));
 UPDATE private.walkin_ingress_state SET day_number=sec/86400,day_attempts=1999;
 r:=api.gf_clock_public_walkin_admit();
 IF r->>'status' IS DISTINCT FROM 'allowed' OR (SELECT day_attempts FROM private.walkin_ingress_state)<>2000 THEN RAISE EXCEPTION 'Last UTC-day admission failed'; END IF;
 PERFORM set_config('gymforce.test_clock','2030-01-02 00:00:00+00',true);
 r:=api.gf_clock_public_walkin_admit();
 IF r->>'status' IS DISTINCT FROM 'allowed' OR (SELECT day_attempts FROM private.walkin_ingress_state)<>1 THEN RAISE EXCEPTION 'Exact midnight reset failed'; END IF;
 PERFORM set_config('gymforce.test_clock','2030-01-01 23:59:59+00',true);
 IF api.gf_clock_public_walkin_admit()->>'status' IS DISTINCT FROM 'unavailable' OR (SELECT day_attempts FROM private.walkin_ingress_state)<>1 THEN RAISE EXCEPTION 'Backward day transition modified state'; END IF;
END $day$;
\echo 'PASS deterministic UTC midnight: last day slot, microsecond cutover and backward-day refusal.'
DO $windows$ DECLARE age int; quota int; r jsonb; sec bigint; BEGIN
 FOR age,quota IN SELECT * FROM (VALUES(10,20),(11,20),(60,120),(61,120)) x(a,q) LOOP
  PERFORM pg_temp.clock_reset('2030-01-02 12:00:00+00');sec:=floor(extract(epoch FROM private.gf_test_clock()));
  UPDATE private.walkin_ingress_seconds SET second_number=sec-age,attempts=quota WHERE slot=mod(sec-age,61);
  r:=api.gf_clock_public_walkin_admit();
  IF (r->>'status') IS DISTINCT FROM (CASE WHEN age IN(10,60) THEN 'denied' ELSE 'allowed' END) THEN RAISE EXCEPTION 'Exact window boundary failed'; END IF;
 END LOOP;
END $windows$;
\echo 'PASS deterministic inclusive 10/60-second bins and expiration at 11/61 seconds.'
DO $refill$ DECLARE ticket uuid; d bytea:=decode(repeat('aa',32),'hex'); r jsonb; at_time timestamptz:='2030-01-02 12:00:00+00'; BEGIN
 PERFORM pg_temp.clock_reset(at_time);ticket:=(api.gf_clock_public_walkin_admit()->>'ticket')::uuid;
 UPDATE private.walkin_ingress_buckets SET updated_at=at_time,tokens=0 WHERE slot=2730;
 PERFORM set_config('gymforce.test_clock',(at_time+interval '4.999999 seconds')::text,true);
 IF api.gf_clock_public_walkin_bind(ticket,d,'create','cash')->>'status' IS DISTINCT FROM 'denied' THEN RAISE EXCEPTION 'Premature exact creation refill'; END IF;
 PERFORM set_config('gymforce.test_clock',(at_time+interval '5 seconds')::text,true);
 IF api.gf_clock_public_walkin_bind(ticket,d,'create','cash')->>'status' IS DISTINCT FROM 'allowed' THEN RAISE EXCEPTION 'Exact creation refill missing'; END IF;
 PERFORM pg_temp.clock_reset(at_time);ticket:=(api.gf_clock_public_walkin_admit()->>'ticket')::uuid;
 UPDATE private.walkin_ingress_buckets SET updated_at=at_time,tokens=3,lookup_tokens=0 WHERE slot=2730;
 PERFORM set_config('gymforce.test_clock',(at_time+interval '9.999999 seconds')::text,true);
 IF api.gf_clock_public_walkin_bind(ticket,d,'lookup',NULL)->>'status' IS DISTINCT FROM 'denied' THEN RAISE EXCEPTION 'Premature exact lookup refill'; END IF;
 PERFORM set_config('gymforce.test_clock',(at_time+interval '10 seconds')::text,true);
 IF api.gf_clock_public_walkin_bind(ticket,d,'lookup',NULL)->>'status' IS DISTINCT FROM 'allowed' THEN RAISE EXCEPTION 'Exact lookup refill missing'; END IF;
 -- New unbound ticket at the same instant, then move back one microsecond.
 ticket:=(api.gf_clock_public_walkin_admit()->>'ticket')::uuid;
 PERFORM set_config('gymforce.test_clock',(at_time+interval '9.999999 seconds')::text,true);
 IF api.gf_clock_public_walkin_bind(ticket,d,'lookup',NULL)->>'status' IS DISTINCT FROM 'unavailable' THEN RAISE EXCEPTION 'Backward bucket clock accepted'; END IF;
END $refill$;
\echo 'PASS deterministic creation 4.999999/5s, lookup 9.999999/10s and microsecond rollback refusal.'
DO $lease$ DECLARE old_ticket uuid; fresh uuid; i int; r jsonb; base timestamptz:='2030-01-02 12:00:00+00'; BEGIN
 PERFORM pg_temp.clock_reset(base);
 FOR i IN 1..8 LOOP fresh:=(api.gf_clock_public_walkin_admit()->>'ticket')::uuid;IF fresh IS NULL THEN RAISE EXCEPTION 'Eight slots unavailable'; END IF;IF i=1 THEN old_ticket:=fresh; END IF;END LOOP;
 PERFORM set_config('gymforce.test_clock',(base+interval '14.999999 seconds')::text,true);
 IF api.gf_clock_public_walkin_admit()->>'status' IS DISTINCT FROM 'denied' THEN RAISE EXCEPTION 'Premature lease release'; END IF;
 PERFORM set_config('gymforce.test_clock',(base+interval '15 seconds')::text,true);
 fresh:=(api.gf_clock_public_walkin_admit()->>'ticket')::uuid;
 IF fresh IS NULL OR fresh=old_ticket THEN RAISE EXCEPTION 'Exact lease expiry/ABA failed'; END IF;
 IF api.gf_clock_public_walkin_bind(old_ticket,decode(repeat('ab',32),'hex'),'lookup',NULL)->>'status' IS DISTINCT FROM 'unavailable' THEN RAISE EXCEPTION 'Stale generation accepted'; END IF;
 PERFORM set_config('gymforce.test_clock','2035-01-01 00:00:00+00',true);
 r:=api.gf_clock_public_walkin_admit();
 IF r->>'status' IS DISTINCT FROM 'allowed' OR (SELECT day_attempts FROM private.walkin_ingress_state)<>1 THEN RAISE EXCEPTION 'Forward jump recovery failed'; END IF;
END $lease$;
\echo 'PASS deterministic eight slots, 14.999999/15s TTL, stale generation and forward multi-year transition.'
DO $closure$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_temp.gf_clock_original WHERE pg_get_functiondef(signature::regprocedure)<>definition) THEN RAISE EXCEPTION 'Original function changed'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='api' AND p.proname LIKE 'gf_clock_%' AND (pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE') OR pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE') OR pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE'))) THEN RAISE EXCEPTION 'Test hook exposed'; END IF;
END $closure$;
ROLLBACK;
DO $removed$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc WHERE proname IN('gf_test_clock','gf_clock_public_walkin_admit','gf_clock_public_walkin_bind')) THEN RAISE EXCEPTION 'Clock fixture leaked'; END IF;
END $removed$;
\echo 'PASS clock-copy equality, browser/service denial and complete fixture rollback. Not real-time HTTP or hosted clock proof.'
