BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 OR inet_server_addr()<>'127.0.0.1'::inet THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
 IF NOT has_function_privilege('authenticated','api.owner_list_payable_purchases(uuid,text,integer,integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Expected refused correction did not preserve prior state'; END IF;
END $guard$;
REVOKE gf_recovery_leak FROM authenticated;
REVOKE EXECUTE ON FUNCTION api.owner_list_payable_purchases(uuid,text,integer,integer) FROM gf_recovery_leak;
DROP ROLE gf_recovery_leak;
COMMIT;
