-- Only used by scripts/test-database.ps1 in its newly initialized cluster.
-- Auth is a SQL shim, not GoTrue/JWT/PostgREST verification.
BEGIN;
DO $bootstrap$
BEGIN
 IF current_database() <> 'gymforce_batch1_synthetic'
    OR current_setting('gymforce.synthetic_run_id', true) IS NULL
    OR to_regnamespace('private') IS NOT NULL
    OR to_regnamespace('auth') IS NOT NULL THEN
   RAISE EXCEPTION 'Fresh synthetic cluster required';
 END IF;
END $bootstrap$;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
-- Match the hosted service role bypass attribute: direct access must still
-- fail through ACLs, not merely because an inaccurate shim lacks BYPASSRLS.
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA extensions;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
SET search_path = '' AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
INSERT INTO auth.users(id) VALUES
 ('00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000002');
COMMIT;
