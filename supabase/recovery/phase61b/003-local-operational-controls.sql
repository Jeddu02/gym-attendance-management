-- Additive LOCAL review candidate. No hosted scheduler/delivery authorization.
BEGIN;
SET LOCAL search_path=pg_catalog;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
CREATE FUNCTION api.public_walkin_maintenance()
RETURNS pg_catalog.jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE m pg_catalog.int8:=pg_catalog.floor(EXTRACT(epoch FROM pg_catalog.clock_timestamp())/60); r RECORD; result pg_catalog.jsonb;
BEGIN
 PERFORM private.assert_walkin_ingress_runtime(1000,100);
 -- No business history, C1 replay bindings or active locked lease is modified.
 FOR r IN SELECT slot FROM private.walkin_ingress_leases
 WHERE expires_at<=pg_catalog.clock_timestamp() FOR UPDATE SKIP LOCKED LOOP
  UPDATE private.walkin_ingress_leases SET ticket=NULL,expires_at=NULL,digest=NULL,action=NULL,method=NULL,fingerprint=NULL WHERE slot=r.slot;
 END LOOP;
 UPDATE private.walkin_ingress_minutes SET minute_number=0,attempts=0,denied=0,unavailable=0,timeouts=0 WHERE minute_number>0 AND minute_number<=m-2880;
 SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('minute',minute_number,'attempts',attempts,'denied',denied,'unavailable',unavailable,'timeouts',timeouts) ORDER BY minute_number),'[]'::pg_catalog.jsonb)
 INTO result FROM private.walkin_ingress_minutes WHERE minute_number BETWEEN m-1 AND m;
 RETURN result;
END $f$;
ALTER FUNCTION api.public_walkin_maintenance() OWNER TO gym_public_executor;
REVOKE ALL ON FUNCTION api.public_walkin_maintenance() FROM PUBLIC,anon,authenticated,service_role,gym_owner_executor,gym_checkin_executor;
GRANT EXECUTE ON FUNCTION api.public_walkin_maintenance() TO service_role;
DO $closure$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
 WHERE p.oid='api.public_walkin_maintenance()'::pg_catalog.regprocedure AND a.grantee NOT IN (p.proowner,'service_role'::pg_catalog.regrole))
 OR pg_catalog.has_function_privilege('anon','api.public_walkin_maintenance()','EXECUTE')
 OR pg_catalog.has_function_privilege('authenticated','api.public_walkin_maintenance()','EXECUTE')
 THEN RAISE EXCEPTION 'Maintenance ACL closure failed'; END IF;
END $closure$;
COMMIT;
