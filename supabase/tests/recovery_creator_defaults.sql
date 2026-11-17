-- Synthetic fixture only. No production compatibility inference.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic'
 OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 OR inet_server_addr()<>'127.0.0.1'::inet THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $guard$;
-- Demonstrate the schema-only revoke cannot cancel the implicit global grant.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA private REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
CREATE FUNCTION private.gf_recovery_default_before() RETURNS integer LANGUAGE sql SET search_path='' AS 'SELECT 1';
DO $detect$ BEGIN
 IF NOT has_function_privilege('anon','private.gf_recovery_default_before()','EXECUTE')
 THEN RAISE EXCEPTION 'Global PUBLIC default was not detected'; END IF;
END $detect$;
ROLLBACK;
-- Run twice outside the fixture transaction; no nested migration transaction.
\ir ../recovery/proposals/02-postgres-future-routine-defaults.sql
\ir ../recovery/proposals/02-postgres-future-routine-defaults.sql
BEGIN;
CREATE FUNCTION private.gf_recovery_default_after() RETURNS integer LANGUAGE sql SET search_path='' AS 'SELECT 1';
DO $deny$ BEGIN
 IF has_function_privilege('anon','private.gf_recovery_default_after()','EXECUTE')
 OR has_function_privilege('authenticated','private.gf_recovery_default_after()','EXECUTE')
 OR has_function_privilege('service_role','private.gf_recovery_default_after()','EXECUTE')
 THEN RAISE EXCEPTION 'Unexpected future routine grant'; END IF;
 IF NOT has_function_privilege('service_role','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Existing explicit service RPC grant changed'; END IF;
END $deny$;
GRANT EXECUTE ON FUNCTION private.gf_recovery_default_after() TO service_role;
DO $allow$ BEGIN
 IF NOT has_function_privilege('service_role','private.gf_recovery_default_after()','EXECUTE')
 THEN RAISE EXCEPTION 'Explicit future service grant failed'; END IF;
END $allow$;
ROLLBACK;
\echo 'PASS: global default correction, replay, future deny and explicit service grant; fixture routines rolled back.'
