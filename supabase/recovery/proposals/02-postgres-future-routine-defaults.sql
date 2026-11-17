-- REVIEW PROPOSAL ONLY. Not a historical migration; NOT authorized for production.
-- Requires Owner approval: affects ALL future functions/procedures created by
-- postgres in this database, including schemas outside GYMFORCE. Does not revoke
-- existing routine ACLs or touch provider-owned creators such as supabase_admin.
-- Review other applications/automation before approving. No implicit service RPC grants.
BEGIN;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path = pg_catalog;
DO $guard$ BEGIN
 IF current_user <> 'postgres' THEN
   RAISE EXCEPTION 'Reviewed creator must be the effective actor';
 END IF;
END $guard$;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA api, private
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;
COMMIT;
