-- Only the fresh customer-mode PG17 harness; actual non-superuser connection.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_user<>'postgres' OR session_user<>'postgres'
 OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 OR inet_server_addr()<>'127.0.0.1'::inet
 OR EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls))
 THEN RAISE EXCEPTION 'Synthetic non-superuser customer required'; END IF;
END $guard$;
DO $deny$ DECLARE actor text; BEGIN
 FOREACH actor IN ARRAY ARRAY['gf_provider_admin','gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'] LOOP
 BEGIN
  EXECUTE format('SET LOCAL ROLE %I',actor);
  RAISE EXCEPTION 'Unexpected at-rest SET ROLE capability';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 END LOOP;
 BEGIN
  PERFORM 1 FROM private.members LIMIT 1;
  RAISE EXCEPTION 'Customer retained direct member data access';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 IF has_function_privilege('anon','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 OR has_function_privilege('authenticated','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 OR NOT has_function_privilege('service_role','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Existing explicit RPC boundary differs'; END IF;
END $deny$;
CREATE FUNCTION private.gf_compatibility_future() RETURNS integer LANGUAGE sql SET search_path='' AS 'SELECT 1';
DO $future$ BEGIN
 IF has_function_privilege('anon','private.gf_compatibility_future()','EXECUTE')
 OR has_function_privilege('authenticated','private.gf_compatibility_future()','EXECUTE')
 OR has_function_privilege('service_role','private.gf_compatibility_future()','EXECUTE')
 THEN RAISE EXCEPTION 'Unexpected future EXECUTE default'; END IF;
END $future$;
GRANT EXECUTE ON FUNCTION private.gf_compatibility_future() TO service_role;
DO $explicit$ BEGIN
 IF NOT has_function_privilege('service_role','private.gf_compatibility_future()','EXECUTE') THEN RAISE EXCEPTION 'Explicit service grant unavailable'; END IF;
END $explicit$;
ROLLBACK;
\echo 'PASS: customer at-rest SET/data denials, browser denial, explicit service RPC and future defaults; fixture rolled back.'
