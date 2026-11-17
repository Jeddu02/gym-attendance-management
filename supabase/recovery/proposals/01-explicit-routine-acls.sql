-- LOCAL PROPOSAL ONLY. Not in the automatic migration directory.
-- Owner must approve exact object inventory and operator before any hosted use.
-- Idempotent existing-object correction; does NOT solve global creator defaults.
BEGIN;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
DO $scope$
BEGIN
 IF to_regprocedure('api.owner_list_payable_purchases(uuid,text,integer,integer)') IS NULL
 OR (SELECT count(*) FROM pg_roles WHERE rolname IN
  ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))<>4
 OR EXISTS(SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.roleid OR r.oid=m.member
  WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 THEN RAISE EXCEPTION 'Final release and clean restricted role graph required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname IN ('api','private') AND (p.prokind<>'f'
   OR NOT(COALESCE(p.proconfig,ARRAY[]::text[]) @> ARRAY['search_path=""']::text[])
   OR (n.nspname='private' AND (p.prosecdef OR pg_get_userbyid(p.proowner)<>'gym_data_owner'))
   OR (n.nspname='api' AND (NOT p.prosecdef OR pg_get_userbyid(p.proowner) NOT IN
     ('gym_owner_executor','gym_public_executor','gym_checkin_executor')))))
 THEN RAISE EXCEPTION 'Unexpected routine security inventory; reconcile before correction'; END IF;
END $scope$;
-- Individual ACL changes preserve the existing service/executor allowlists.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA api,private FROM PUBLIC,anon,authenticated;
-- Remove explicit unsafe schema-default additions for these actual creators.
-- PG global implicit PUBLIC EXECUTE remains a separate, approval-gated issue.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA api,private
 REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC,anon,authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_data_owner IN SCHEMA private
 REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC,anon,authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_owner_executor,gym_public_executor,gym_checkin_executor IN SCHEMA api
 REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC,anon,authenticated;
DO $effective$
DECLARE r record; caller text;
BEGIN
 FOR r IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname IN ('api','private') LOOP
  FOREACH caller IN ARRAY ARRAY['anon','authenticated'] LOOP
   IF has_function_privilege(caller,r.oid,'EXECUTE') THEN
    RAISE EXCEPTION 'Inherited routine access remains; refusing partial correction';
   END IF;
  END LOOP;
 END LOOP;
END $effective$;
COMMIT;
