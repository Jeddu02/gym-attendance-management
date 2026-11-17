-- Synthetic-only injection, followed by a separate expected-refusal connection.
BEGIN;
DO $guard$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS NULL
 OR inet_server_addr()<>'127.0.0.1'::inet THEN RAISE EXCEPTION 'Synthetic target required'; END IF;
END $guard$;
CREATE ROLE gf_recovery_leak NOLOGIN;
GRANT EXECUTE ON FUNCTION api.owner_list_payable_purchases(uuid,text,integer,integer) TO gf_recovery_leak;
GRANT gf_recovery_leak TO authenticated WITH INHERIT TRUE, SET FALSE;
COMMIT;
