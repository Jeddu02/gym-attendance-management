-- LOCAL SYNTHETIC REVIEW CANDIDATE ONLY. No hosted authority or execution approval.
-- Apply only after the Phase 6.1 candidate in the guarded isolated test harness.
BEGIN;
SET LOCAL search_path=pg_catalog;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
DO $names$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='api' AND p.proname IN ('public_walkin_admit','public_walkin_bind','public_walkin_execute','public_walkin_finish','public_walkin_observe'))
 OR (n.nspname='private' AND p.proname IN ('assert_walkin_ingress_runtime','walkin_ingress_metric','guard_walkin_recovery_capacity')))
 THEN RAISE EXCEPTION 'Ingress routine namespace requires review'; END IF;
END $names$;
CREATE TABLE private.walkin_ingress_state (
 id int PRIMARY KEY CHECK(id=1), last_second bigint NOT NULL,
 day_number bigint NOT NULL, day_attempts int NOT NULL CHECK(day_attempts BETWEEN 0 AND 2147483647)
);
INSERT INTO private.walkin_ingress_state
 VALUES(1,0,0,0);
CREATE TABLE private.walkin_ingress_seconds (
 slot int PRIMARY KEY CHECK(slot BETWEEN 0 AND 60), second_number bigint NOT NULL,
 attempts int NOT NULL CHECK(attempts BETWEEN 0 AND 2147483647)
);
INSERT INTO private.walkin_ingress_seconds SELECT i,0,0 FROM generate_series(0,60) i;
CREATE TABLE private.walkin_ingress_buckets (
 slot int PRIMARY KEY CHECK(slot BETWEEN 0 AND 4095), updated_at timestamptz NOT NULL,
 tokens numeric NOT NULL CHECK(tokens BETWEEN 0 AND 3),
 lookup_tokens numeric NOT NULL CHECK(lookup_tokens BETWEEN 0 AND 2)
);
INSERT INTO private.walkin_ingress_buckets SELECT i,'epoch',3,2 FROM generate_series(0,4095) i;
CREATE TABLE private.walkin_ingress_leases (
 slot int PRIMARY KEY CHECK(slot BETWEEN 1 AND 8), ticket uuid UNIQUE,
 expires_at timestamptz, digest bytea CHECK(digest IS NULL OR octet_length(digest)=32),
 action text CHECK(action IN ('create','lookup')), method text CHECK(method IN ('cash','gcash','bank_transfer')),
 fingerprint bytea CHECK(fingerprint IS NULL OR octet_length(fingerprint)=32)
);
INSERT INTO private.walkin_ingress_leases(slot) SELECT generate_series(1,8);
CREATE TABLE private.walkin_ingress_minutes (
 slot int PRIMARY KEY CHECK(slot BETWEEN 0 AND 2879), minute_number bigint NOT NULL,
 attempts int NOT NULL CHECK(attempts>=0), denied int NOT NULL CHECK(denied>=0),
 unavailable int NOT NULL CHECK(unavailable>=0), timeouts int NOT NULL CHECK(timeouts>=0)
);
INSERT INTO private.walkin_ingress_minutes SELECT i,0,0,0,0,0 FROM generate_series(0,2879) i;
-- Only new bounded operational state is mutable. No business-table grants added.
DO $permissions$
DECLARE t text; columns text;
BEGIN
 FOR t,columns IN SELECT * FROM (VALUES
 ('walkin_ingress_state','id,last_second,day_number,day_attempts'),
 ('walkin_ingress_seconds','slot,second_number,attempts'),
 ('walkin_ingress_buckets','slot,updated_at,tokens,lookup_tokens'),
 ('walkin_ingress_leases','slot,ticket,expires_at,digest,action,method,fingerprint'),
 ('walkin_ingress_minutes','slot,minute_number,attempts,denied,unavailable,timeouts')) x(t,c)
 LOOP
  EXECUTE format('ALTER TABLE private.%I OWNER TO gym_data_owner',t);
  EXECUTE format('ALTER TABLE private.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE private.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON private.%I FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor',t);
  EXECUTE format('GRANT SELECT(%s),UPDATE(%s) ON private.%I TO gym_public_executor',columns,substr(columns,strpos(columns,',')+1),t);
  EXECUTE format('CREATE POLICY gf_ingress_select ON private.%I FOR SELECT TO gym_public_executor USING(CURRENT_USER=''gym_public_executor''::name)',t);
  EXECUTE format('CREATE POLICY gf_ingress_update ON private.%I FOR UPDATE TO gym_public_executor USING(CURRENT_USER=''gym_public_executor''::name) WITH CHECK(CURRENT_USER=''gym_public_executor''::name)',t);
 END LOOP;
END $permissions$;

CREATE FUNCTION private.assert_walkin_ingress_runtime(max_ms int,lock_ms int)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE s int; l int;
BEGIN
 SELECT setting::int INTO s FROM pg_catalog.pg_settings WHERE name='statement_timeout';
 SELECT setting::int INTO l FROM pg_catalog.pg_settings WHERE name='lock_timeout';
 IF s IS NULL OR s<=0 OR s>max_ms OR l IS NULL OR l<=0 OR l>lock_ms THEN
  RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='INGRESS_RUNTIME_UNQUALIFIED';
 END IF;
END $f$;

CREATE FUNCTION private.walkin_ingress_metric(kind text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE m bigint:=floor(extract(epoch FROM pg_catalog.clock_timestamp())/60);
BEGIN
 IF kind NOT IN ('attempt','denied','unavailable','timeout') OR kind IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_REQUEST'; END IF;
 UPDATE private.walkin_ingress_minutes SET minute_number=0,attempts=0,denied=0,unavailable=0,timeouts=0
 WHERE minute_number>0 AND minute_number<=m-2880;
 UPDATE private.walkin_ingress_minutes SET minute_number=m,
 attempts=CASE WHEN kind='attempt' THEN least(2147483646,CASE WHEN minute_number=m THEN attempts ELSE 0 END)+1 ELSE CASE WHEN minute_number=m THEN attempts ELSE 0 END END,
 denied=CASE WHEN kind='denied' THEN least(2147483646,CASE WHEN minute_number=m THEN denied ELSE 0 END)+1 ELSE CASE WHEN minute_number=m THEN denied ELSE 0 END END,
 unavailable=CASE WHEN kind='unavailable' THEN least(2147483646,CASE WHEN minute_number=m THEN unavailable ELSE 0 END)+1 ELSE CASE WHEN minute_number=m THEN unavailable ELSE 0 END END,
 timeouts=CASE WHEN kind='timeout' THEN least(2147483646,CASE WHEN minute_number=m THEN timeouts ELSE 0 END)+1 ELSE CASE WHEN minute_number=m THEN timeouts ELSE 0 END END
 WHERE slot=mod(m,2880)::int;
END $f$;

CREATE FUNCTION api.public_walkin_admit()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE s private.walkin_ingress_state%ROWTYPE; sec bigint; n10 bigint; n60 bigint;
 chosen int; ticket_id uuid; r record;
BEGIN
 PERFORM private.assert_walkin_ingress_runtime(1000,100);
 SELECT * INTO STRICT s FROM private.walkin_ingress_state WHERE id=1 FOR UPDATE;
 sec:=floor(extract(epoch FROM pg_catalog.clock_timestamp()));
 IF sec<s.last_second THEN RETURN pg_catalog.jsonb_build_object('status','unavailable'); END IF;
 UPDATE private.walkin_ingress_state SET last_second=sec,
 day_number=sec/86400,day_attempts=CASE WHEN day_number=sec/86400 THEN least(day_attempts,2147483646)+1 ELSE 1 END WHERE id=1;
 UPDATE private.walkin_ingress_seconds SET second_number=sec,
 attempts=CASE WHEN second_number=sec THEN least(attempts,2147483646)+1 ELSE 1 END WHERE slot=mod(sec,61)::int;
 SELECT coalesce(sum(attempts) FILTER(WHERE second_number>=sec-10),0),coalesce(sum(attempts),0)
 INTO n10,n60 FROM private.walkin_ingress_seconds WHERE second_number>=sec-60;
 PERFORM private.walkin_ingress_metric('attempt');
 -- Reclaim only unlocked, expired leases; generation is a new unpredictable UUID.
 FOR r IN SELECT slot FROM private.walkin_ingress_leases WHERE expires_at<=pg_catalog.clock_timestamp() FOR UPDATE SKIP LOCKED LOOP
  UPDATE private.walkin_ingress_leases SET ticket=NULL,expires_at=NULL,digest=NULL,action=NULL,method=NULL,fingerprint=NULL WHERE slot=r.slot;
 END LOOP;
 IF n10>20 OR n60>120 OR (CASE WHEN s.day_number=sec/86400 THEN s.day_attempts ELSE 0 END)>=2000 THEN
  PERFORM private.walkin_ingress_metric('denied'); RETURN pg_catalog.jsonb_build_object('status','denied'); END IF;
 SELECT slot INTO chosen FROM private.walkin_ingress_leases WHERE ticket IS NULL ORDER BY slot LIMIT 1 FOR UPDATE SKIP LOCKED;
 IF chosen IS NULL THEN PERFORM private.walkin_ingress_metric('denied'); RETURN pg_catalog.jsonb_build_object('status','denied'); END IF;
 ticket_id:=pg_catalog.gen_random_uuid();
 UPDATE private.walkin_ingress_leases SET ticket=ticket_id,expires_at=pg_catalog.clock_timestamp()+interval '15 seconds' WHERE slot=chosen;
 RETURN pg_catalog.jsonb_build_object('status','allowed','ticket',ticket_id);
END $f$;

CREATE FUNCTION api.public_walkin_bind(p_ticket uuid,p_digest bytea,p_action text,p_method text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE b private.walkin_ingress_buckets%ROWTYPE; l private.walkin_ingress_leases%ROWTYPE;
 now_at timestamptz; elapsed numeric; tok numeric; look numeric; bucket int;
BEGIN
 PERFORM private.assert_walkin_ingress_runtime(1000,100);
 IF p_ticket IS NULL OR p_digest IS NULL OR pg_catalog.octet_length(p_digest)<>32 OR p_action IS NULL OR p_action NOT IN ('create','lookup')
 OR (p_action='create' AND (p_method IS NULL OR p_method NOT IN ('cash','gcash','bank_transfer')))
 OR (p_action='lookup' AND p_method IS NOT NULL) THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_REQUEST'; END IF;
 PERFORM id FROM private.walkin_ingress_state WHERE id=1 FOR UPDATE;
 bucket:=pg_catalog.get_byte(p_digest,0)*16+pg_catalog.get_byte(p_digest,1)/16;
 SELECT * INTO STRICT b FROM private.walkin_ingress_buckets WHERE slot=bucket FOR UPDATE;
 SELECT * INTO l FROM private.walkin_ingress_leases WHERE ticket=p_ticket FOR UPDATE;
 now_at:=pg_catalog.clock_timestamp();
 IF l.ticket IS NULL OR l.expires_at<=now_at OR l.digest IS NOT NULL THEN RETURN pg_catalog.jsonb_build_object('status','unavailable'); END IF;
 IF now_at<b.updated_at THEN RETURN pg_catalog.jsonb_build_object('status','unavailable'); END IF;
 elapsed:=extract(epoch FROM now_at-b.updated_at);
 tok:=least(3,b.tokens+elapsed/5); look:=least(2,b.lookup_tokens+elapsed/10);
 IF tok<1 OR (p_action='lookup' AND look<1) THEN
  PERFORM private.walkin_ingress_metric('denied'); RETURN pg_catalog.jsonb_build_object('status','denied'); END IF;
 UPDATE private.walkin_ingress_buckets SET updated_at=now_at,tokens=tok-1,lookup_tokens=look-CASE WHEN p_action='lookup' THEN 1 ELSE 0 END WHERE slot=bucket;
 UPDATE private.walkin_ingress_leases SET digest=p_digest,action=p_action,method=p_method,
 fingerprint=CASE WHEN p_action='create' THEN pg_catalog.sha256(pg_catalog.convert_to('gymforce:walkin-create:v1'||pg_catalog.chr(10)||'paymentMethod='||p_method||pg_catalog.chr(10),'UTF8')) END
 WHERE ticket=p_ticket;
 RETURN pg_catalog.jsonb_build_object('status','allowed');
END $f$;

-- A separate capacity row avoids acquiring the admission/global lock in business.
CREATE TABLE private.walkin_ingress_capacity(id int PRIMARY KEY CHECK(id=1),bindings int NOT NULL CHECK(bindings BETWEEN 0 AND 10000));
INSERT INTO private.walkin_ingress_capacity SELECT 1,count(*) FROM private.walkin_creation_operations;
ALTER TABLE private.walkin_ingress_capacity OWNER TO gym_data_owner;
ALTER TABLE private.walkin_ingress_capacity ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.walkin_ingress_capacity FORCE ROW LEVEL SECURITY;
REVOKE ALL ON private.walkin_ingress_capacity FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_public_executor,gym_checkin_executor;
GRANT SELECT(id,bindings),UPDATE(bindings) ON private.walkin_ingress_capacity TO gym_public_executor;
CREATE POLICY gf_ingress_select ON private.walkin_ingress_capacity FOR SELECT TO gym_public_executor USING(CURRENT_USER='gym_public_executor'::name);
CREATE POLICY gf_ingress_update ON private.walkin_ingress_capacity FOR UPDATE TO gym_public_executor USING(CURRENT_USER='gym_public_executor'::name) WITH CHECK(CURRENT_USER='gym_public_executor'::name);
CREATE FUNCTION private.guard_walkin_recovery_capacity()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE n int;
BEGIN
 SELECT bindings INTO STRICT n FROM private.walkin_ingress_capacity WHERE id=1 FOR UPDATE;
 IF n>=10000 OR n<>(SELECT count(*) FROM private.walkin_creation_operations) THEN
  RAISE EXCEPTION USING ERRCODE='54000',MESSAGE='RECOVERY_CAPACITY_UNAVAILABLE'; END IF;
 UPDATE private.walkin_ingress_capacity SET bindings=bindings+1 WHERE id=1;
 RETURN NEW;
END $f$;
CREATE TRIGGER guard_recovery_capacity BEFORE INSERT ON private.walkin_creation_operations
 FOR EACH ROW EXECUTE FUNCTION private.guard_walkin_recovery_capacity();

CREATE FUNCTION api.public_walkin_execute(p_ticket uuid,p_digest bytea,p_action text,p_method text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE l private.walkin_ingress_leases%ROWTYPE; result jsonb; fingerprint bytea;
BEGIN
 PERFORM private.assert_walkin_ingress_runtime(5000,500);
 SELECT * INTO l FROM private.walkin_ingress_leases WHERE ticket=p_ticket FOR UPDATE;
 fingerprint:=CASE WHEN p_action='create' THEN pg_catalog.sha256(pg_catalog.convert_to('gymforce:walkin-create:v1'||pg_catalog.chr(10)||'paymentMethod='||p_method||pg_catalog.chr(10),'UTF8')) END;
 IF l.ticket IS NULL OR l.expires_at<=pg_catalog.clock_timestamp() OR l.digest IS NULL
 OR l.digest IS DISTINCT FROM p_digest OR l.action IS DISTINCT FROM p_action OR l.method IS DISTINCT FROM p_method
 OR l.fingerprint IS DISTINCT FROM fingerprint THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='ADMISSION_REQUIRED'; END IF;
 result:=private.recover_walkin_operation(p_digest,p_method,CASE WHEN p_action='create' THEN 10 ELSE NULL END);
 UPDATE private.walkin_ingress_leases SET ticket=NULL,expires_at=NULL,digest=NULL,action=NULL,method=NULL,fingerprint=NULL WHERE slot=l.slot;
 RETURN result;
END $f$;

CREATE FUNCTION api.public_walkin_finish(p_ticket uuid,p_kind text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM private.assert_walkin_ingress_runtime(1000,100);
 IF p_kind NOT IN ('denied','unavailable','timeout') OR p_kind IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_REQUEST'; END IF;
 -- Only used before business dispatch or after known completion. Never on an
 -- uncertain dispatched business call. NOWAIT prevents waiting on active work.
 PERFORM slot FROM private.walkin_ingress_leases WHERE ticket=p_ticket FOR UPDATE NOWAIT;
 UPDATE private.walkin_ingress_leases SET ticket=NULL,expires_at=NULL,digest=NULL,action=NULL,method=NULL,fingerprint=NULL WHERE ticket=p_ticket;
 PERFORM private.walkin_ingress_metric(p_kind);
END $f$;

CREATE FUNCTION api.public_walkin_observe(p_kind text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM private.assert_walkin_ingress_runtime(1000,100);
 -- Identifier-free telemetry only: never releases an uncertain business lease.
 PERFORM private.walkin_ingress_metric(p_kind);
END $f$;

DO $routines$
DECLARE r record;
BEGIN
 FOR r IN SELECT p.oid::pg_catalog.regprocedure AS signature,n.nspname FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='api' AND p.proname IN ('public_walkin_admit','public_walkin_bind','public_walkin_execute','public_walkin_finish','public_walkin_observe'))
 OR (n.nspname='private' AND p.proname IN ('assert_walkin_ingress_runtime','walkin_ingress_metric','guard_walkin_recovery_capacity'))
 LOOP
  EXECUTE format('ALTER FUNCTION %s OWNER TO %I',r.signature,CASE WHEN r.nspname='api' THEN 'gym_public_executor' ELSE 'gym_data_owner' END);
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_checkin_executor,gym_public_executor',r.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %I',r.signature,CASE WHEN r.nspname='api' THEN 'service_role' ELSE 'gym_public_executor' END);
 END LOOP;
END $routines$;
REVOKE EXECUTE ON FUNCTION api.public_create_walkin_request_v2(bytea,text,integer),api.public_lookup_walkin_request(bytea) FROM service_role;
DO $closure$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='api' AND p.proname IN ('public_create_walkin_request','public_create_walkin_request_v2','public_lookup_walkin_request')
 AND pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE'))
 THEN RAISE EXCEPTION 'Ungated recovery overload requires review'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='api' AND p.proname IN ('public_walkin_admit','public_walkin_bind','public_walkin_execute','public_walkin_finish','public_walkin_observe')
 AND (pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE') OR pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')))
 THEN RAISE EXCEPTION 'Effective browser ingress permission requires review'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' AND c.relname IN ('walkin_ingress_state','walkin_ingress_seconds','walkin_ingress_buckets','walkin_ingress_leases','walkin_ingress_minutes','walkin_ingress_capacity')
 AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity OR c.relowner<>'gym_data_owner'::pg_catalog.regrole
 OR EXISTS(SELECT 1 FROM pg_catalog.aclexplode(c.relacl) a WHERE a.grantee NOT IN ('gym_data_owner'::pg_catalog.regrole,'gym_public_executor'::pg_catalog.regrole))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_attribute x CROSS JOIN LATERAL pg_catalog.aclexplode(x.attacl) a WHERE x.attrelid=c.oid AND a.grantee NOT IN ('gym_data_owner'::pg_catalog.regrole,'gym_public_executor'::pg_catalog.regrole))))
 THEN RAISE EXCEPTION 'Ingress table privilege closure failed'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 CROSS JOIN LATERAL pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
 WHERE ((n.nspname='api' AND p.proname IN ('public_walkin_admit','public_walkin_bind','public_walkin_execute','public_walkin_finish','public_walkin_observe'))
 OR (n.nspname='private' AND p.proname IN ('assert_walkin_ingress_runtime','walkin_ingress_metric','guard_walkin_recovery_capacity')))
 AND a.grantee NOT IN (p.proowner,CASE WHEN n.nspname='api' THEN 'service_role'::pg_catalog.regrole ELSE 'gym_public_executor'::pg_catalog.regrole END))
 THEN RAISE EXCEPTION 'Ingress routine privilege closure failed'; END IF;
END $closure$;
COMMIT;
