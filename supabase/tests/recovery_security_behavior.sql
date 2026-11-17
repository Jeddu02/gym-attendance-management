-- Fresh synthetic harness only; deliberate privilege damage is repaired or rolled back.
\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic'
 OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 OR inet_server_addr()<>'127.0.0.1'::inet THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $guard$;
GRANT EXECUTE ON FUNCTION api.owner_list_payable_purchases(uuid,text,integer,integer) TO PUBLIC;
DO $detect$
BEGIN
 IF NOT has_function_privilege('anon','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Injected PUBLIC leak not detected'; END IF;
END $detect$;
COMMIT;
-- A transaction-owning proposal must not be nested in the test transaction.
\ir ../recovery/proposals/01-explicit-routine-acls.sql
\ir ../recovery/proposals/01-explicit-routine-acls.sql
BEGIN;
DO $repaired$
BEGIN
 IF has_function_privilege('anon','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 OR has_function_privilege('authenticated','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 OR NOT has_function_privilege('service_role','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Scoped correction changed required effective access'; END IF;
END $repaired$;
CREATE ROLE gf_recovery_leak NOLOGIN;
GRANT EXECUTE ON FUNCTION api.owner_list_payable_purchases(uuid,text,integer,integer) TO gf_recovery_leak;
GRANT gf_recovery_leak TO authenticated WITH INHERIT TRUE, SET FALSE;
DO $inherited$
BEGIN
 IF NOT has_function_privilege('authenticated','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Inherited EXECUTE leak missed'; END IF;
END $inherited$;
ROLLBACK;
\echo 'PASS: PUBLIC and inherited privilege leaks detected; scoped proposal replay is idempotent.'
