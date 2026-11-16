-- Behavioral probe for the local auth.uid()/JWT-GUC shim and PostgreSQL RLS.
-- Run with psql as postgres against the marked disposable database only.
-- The local_test_rls schema/table/policies are test fixtures created inside a
-- transaction and rolled back. They do not alter application policies.
\set ON_ERROR_STOP on

\if :{?expected_cluster_marker}
\else
    \echo 'Refusing RLS probe: expected_cluster_marker was not supplied.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\if :{?expected_system_identifier}
\else
    \echo 'Refusing RLS probe: expected_system_identifier was not supplied.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\if :{?expected_data_directory}
\else
    \echo 'Refusing RLS probe: expected_data_directory was not supplied.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

SELECT CASE
    WHEN current_setting('gymforce.test_cluster_marker', true) = :'expected_cluster_marker'
     AND (pg_catalog.pg_control_system()).system_identifier::text = :'expected_system_identifier'
     AND lower(rtrim(replace(current_setting('data_directory'), E'\\', '/'), '/')) =
         lower(rtrim(replace(:'expected_data_directory', E'\\', '/'), '/'))
    THEN 'true' ELSE 'false'
END AS cluster_marker_matches
\gset
\if :cluster_marker_matches
\else
    \echo 'Refusing RLS probe: marker, PostgreSQL system identifier, or data directory does not match.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

DO $target_guard$
BEGIN
    IF current_database() <> 'gymforce_pg18_test'
       OR current_setting('port') <> '55432'
       OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
       OR current_user <> 'postgres'
       OR session_user <> 'postgres'
       OR NOT (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user) THEN
        RAISE EXCEPTION 'RLS probe requires postgres on the marked loopback test database';
    END IF;
END;
$target_guard$;

BEGIN;

CREATE SCHEMA local_test_rls AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA local_test_rls FROM PUBLIC;
GRANT USAGE ON SCHEMA local_test_rls TO anon, authenticated;

CREATE TABLE local_test_rls.access_probe (
    record_key text PRIMARY KEY,
    owner_id uuid,
    payload text NOT NULL
);
ALTER TABLE local_test_rls.access_probe ENABLE ROW LEVEL SECURITY;
ALTER TABLE local_test_rls.access_probe FORCE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON local_test_rls.access_probe
    TO anon, authenticated;

INSERT INTO local_test_rls.access_probe (record_key, owner_id, payload) VALUES
    ('anon-readable', NULL, 'anon fixture'),
    ('auth-readable-owner-1', '00000000-0000-4000-8000-000000000001', 'owner one fixture'),
    ('auth-readable-owner-2', '00000000-0000-4000-8000-000000000002', 'owner two fixture');

CREATE POLICY anon_fixture_read ON local_test_rls.access_probe
    FOR SELECT TO anon
    USING (owner_id IS NULL AND record_key LIKE 'anon-%');
CREATE POLICY anon_fixture_insert ON local_test_rls.access_probe
    FOR INSERT TO anon
    WITH CHECK (owner_id IS NULL AND record_key LIKE 'anon-%');
CREATE POLICY anon_fixture_update ON local_test_rls.access_probe
    FOR UPDATE TO anon
    USING (owner_id IS NULL AND record_key LIKE 'anon-%')
    WITH CHECK (owner_id IS NULL AND record_key LIKE 'anon-%');

CREATE POLICY auth_fixture_read ON local_test_rls.access_probe
    FOR SELECT TO authenticated
    USING (owner_id = auth.uid());
CREATE POLICY auth_fixture_insert ON local_test_rls.access_probe
    FOR INSERT TO authenticated
    WITH CHECK (owner_id = auth.uid());
CREATE POLICY auth_fixture_update ON local_test_rls.access_probe
    FOR UPDATE TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- These policy probes exercise a deliberately isolated test fixture. They do
-- not claim application tables have corresponding allow policies.
SET LOCAL ROLE anon;
SELECT pg_catalog.set_config('request.jwt.claim.sub', '', true);

SELECT CASE WHEN count(*) = 1 THEN 'true' ELSE 'false' END AS anon_allowed_read
FROM local_test_rls.access_probe WHERE record_key = 'anon-readable'
\gset
\if :anon_allowed_read
    \echo 'PASS: anon permitted fixture read'
\else
    \echo 'FAIL: anon permitted fixture read'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

SELECT CASE WHEN count(*) = 0 THEN 'true' ELSE 'false' END AS anon_denied_read
FROM local_test_rls.access_probe WHERE record_key = 'auth-readable-owner-1'
\gset
\if :anon_denied_read
    \echo 'PASS: anon denied fixture read (RLS filtered the row)'
\else
    \echo 'FAIL: anon denied fixture read'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

INSERT INTO local_test_rls.access_probe (record_key, owner_id, payload)
VALUES ('anon-write-allowed', NULL, 'anon write fixture');
UPDATE local_test_rls.access_probe SET payload = 'anon update fixture'
WHERE record_key = 'anon-write-allowed';
SELECT CASE WHEN count(*) = 1 THEN 'true' ELSE 'false' END AS anon_allowed_write
FROM local_test_rls.access_probe
WHERE record_key = 'anon-write-allowed' AND payload = 'anon update fixture'
\gset
\if :anon_allowed_write
    \echo 'PASS: anon permitted fixture insert and update'
\else
    \echo 'FAIL: anon permitted fixture write'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

SAVEPOINT anon_denied_write;
\set ON_ERROR_STOP off
INSERT INTO local_test_rls.access_probe (record_key, owner_id, payload)
VALUES ('anon-write-denied', '00000000-0000-4000-8000-000000000001', 'must be rejected');
\if :ERROR
    ROLLBACK TO SAVEPOINT anon_denied_write;
    \echo 'PASS: anon denied fixture insert by WITH CHECK policy'
\else
    ROLLBACK TO SAVEPOINT anon_denied_write;
    \echo 'FAIL: anon denied fixture insert unexpectedly succeeded'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\set ON_ERROR_STOP on

-- Application-owned private tables and gym_settings must remain inaccessible
-- to browser roles. These probes expect privilege/schema denial, not a fixture
-- policy result.
SAVEPOINT anon_private_read;
\set ON_ERROR_STOP off
SELECT count(*) FROM private.members;
\if :ERROR
    ROLLBACK TO SAVEPOINT anon_private_read;
    \echo 'PASS: anon denied read of private.members'
\else
    ROLLBACK TO SAVEPOINT anon_private_read;
    \echo 'FAIL: anon read private.members unexpectedly succeeded'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\set ON_ERROR_STOP on

SAVEPOINT anon_public_write;
\set ON_ERROR_STOP off
INSERT INTO public.gym_settings (setting_key, setting_value)
VALUES ('local_rls_probe_anon', 'true'::jsonb);
\if :ERROR
    ROLLBACK TO SAVEPOINT anon_public_write;
    \echo 'PASS: anon denied write to public.gym_settings'
\else
    ROLLBACK TO SAVEPOINT anon_public_write;
    \echo 'FAIL: anon write to public.gym_settings unexpectedly succeeded'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\set ON_ERROR_STOP on

RESET ROLE;
SELECT pg_catalog.set_config(
    'request.jwt.claim.sub',
    '00000000-0000-4000-8000-000000000001',
    true
);
SET LOCAL ROLE authenticated;

SELECT CASE WHEN auth.uid() = '00000000-0000-4000-8000-000000000001'::uuid
    THEN 'true' ELSE 'false' END AS auth_subject_verified
\gset
\if :auth_subject_verified
    \echo 'PASS: authenticated synthetic JWT subject resolves through auth.uid()'
\else
    \echo 'FAIL: authenticated synthetic JWT subject did not resolve'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

SELECT pg_catalog.set_config('request.jwt.claim.sub', '', true);
SELECT pg_catalog.set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}',
    true
);
SELECT CASE WHEN auth.uid() = '00000000-0000-4000-8000-000000000001'::uuid
    THEN 'true' ELSE 'false' END AS auth_claims_subject_verified
\gset
\if :auth_claims_subject_verified
    \echo 'PASS: authenticated request.jwt.claims sub resolves through auth.uid()'
\else
    \echo 'FAIL: authenticated request.jwt.claims sub did not resolve'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

SELECT CASE WHEN count(*) = 1 THEN 'true' ELSE 'false' END AS auth_allowed_read
FROM local_test_rls.access_probe WHERE record_key = 'auth-readable-owner-1'
\gset
\if :auth_allowed_read
    \echo 'PASS: authenticated permitted own-row fixture read'
\else
    \echo 'FAIL: authenticated permitted fixture read'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

SELECT CASE WHEN count(*) = 0 THEN 'true' ELSE 'false' END AS auth_denied_read
FROM local_test_rls.access_probe WHERE record_key = 'auth-readable-owner-2'
\gset
\if :auth_denied_read
    \echo 'PASS: authenticated denied other-subject fixture read (RLS filtered the row)'
\else
    \echo 'FAIL: authenticated denied fixture read'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

INSERT INTO local_test_rls.access_probe (record_key, owner_id, payload)
VALUES ('auth-write-owner-1', auth.uid(), 'auth write fixture');
UPDATE local_test_rls.access_probe SET payload = 'auth update fixture'
WHERE record_key = 'auth-write-owner-1';
SELECT CASE WHEN count(*) = 1 THEN 'true' ELSE 'false' END AS auth_allowed_write
FROM local_test_rls.access_probe
WHERE record_key = 'auth-write-owner-1' AND payload = 'auth update fixture'
\gset
\if :auth_allowed_write
    \echo 'PASS: authenticated permitted fixture insert and update'
\else
    \echo 'FAIL: authenticated permitted fixture write'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

SAVEPOINT auth_denied_write;
\set ON_ERROR_STOP off
INSERT INTO local_test_rls.access_probe (record_key, owner_id, payload)
VALUES ('auth-write-owner-2', '00000000-0000-4000-8000-000000000002', 'must be rejected');
\if :ERROR
    ROLLBACK TO SAVEPOINT auth_denied_write;
    \echo 'PASS: authenticated denied other-subject fixture insert'
\else
    ROLLBACK TO SAVEPOINT auth_denied_write;
    \echo 'FAIL: authenticated denied fixture insert unexpectedly succeeded'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\set ON_ERROR_STOP on

SAVEPOINT auth_private_read;
\set ON_ERROR_STOP off
SELECT count(*) FROM private.members;
\if :ERROR
    ROLLBACK TO SAVEPOINT auth_private_read;
    \echo 'PASS: authenticated denied read of private.members'
\else
    ROLLBACK TO SAVEPOINT auth_private_read;
    \echo 'FAIL: authenticated read private.members unexpectedly succeeded'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\set ON_ERROR_STOP on

SAVEPOINT auth_public_write;
\set ON_ERROR_STOP off
INSERT INTO public.gym_settings (setting_key, setting_value)
VALUES ('local_rls_probe_authenticated', 'true'::jsonb);
\if :ERROR
    ROLLBACK TO SAVEPOINT auth_public_write;
    \echo 'PASS: authenticated denied write to public.gym_settings'
\else
    ROLLBACK TO SAVEPOINT auth_public_write;
    \echo 'FAIL: authenticated write to public.gym_settings unexpectedly succeeded'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\set ON_ERROR_STOP on

RESET ROLE;
ROLLBACK;
\echo 'RLS fixture transaction rolled back; application policies were not changed.'
