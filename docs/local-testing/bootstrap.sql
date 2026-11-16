-- GYMFORCE native PostgreSQL compatibility bootstrap.
-- Run only in the disposable database gymforce_pg18_test on 127.0.0.1:55432.
-- This supplies minimal Supabase Auth names referenced by the migrations. It
-- does not install Supabase services, create an API gateway, or validate JWTs.
\set ON_ERROR_STOP on

\if :{?expected_cluster_marker}
\else
    \echo 'Refusing bootstrap: expected_cluster_marker was not supplied.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\if :{?expected_system_identifier}
\else
    \echo 'Refusing bootstrap: expected_system_identifier was not supplied.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif
\if :{?expected_data_directory}
\else
    \echo 'Refusing bootstrap: expected_data_directory was not supplied.'
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
    \echo 'Refusing bootstrap: marker, PostgreSQL system identifier, or data directory does not match.'
    \set ON_ERROR_STOP on
    DO $local_test_refusal$ BEGIN RAISE EXCEPTION 'Local test safety guard or assertion failed'; END; $local_test_refusal$;
\endif

BEGIN;

DO $bootstrap_guard$
BEGIN
    IF current_database() <> 'gymforce_pg18_test'
       OR current_setting('port') <> '55432'
       OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN
        RAISE EXCEPTION
            'Refusing bootstrap outside gymforce_pg18_test on 127.0.0.1:55432';
    END IF;
    IF current_user <> 'postgres' OR session_user <> 'postgres' OR NOT
       (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user) THEN
        RAISE EXCEPTION 'Run bootstrap as the local PostgreSQL superuser postgres';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_available_extensions
        WHERE name = 'pgcrypto'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_available_extensions
        WHERE name = 'btree_gist'
    ) THEN
        RAISE EXCEPTION 'Required PostgreSQL extensions pgcrypto and btree_gist must be available';
    END IF;
    IF to_regnamespace('private') IS NOT NULL
       OR to_regnamespace('api') IS NOT NULL
       OR to_regclass('public.gym_settings') IS NOT NULL
       OR EXISTS (
            SELECT 1 FROM pg_catalog.pg_class c
            JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
       )
       OR EXISTS (
            SELECT 1 FROM pg_catalog.pg_proc p
            JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
       )
       OR EXISTS (
            SELECT 1 FROM pg_catalog.pg_extension e
            JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace
            WHERE n.nspname = 'extensions'
       )
       OR EXISTS (
            SELECT 1 FROM pg_catalog.pg_class c
            JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'extensions'
       )
       OR EXISTS (
            SELECT 1 FROM pg_catalog.pg_proc p
            JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'extensions'
       ) THEN
        RAISE EXCEPTION 'Database is not fresh; application schemas or extensions already exist';
    END IF;
END;
$bootstrap_guard$;

-- Roles that the migrations and security assertions name. All are
-- non-superuser and have no database/schema/table privileges by default.
-- gym_registration_login matches the existing assertion's LOGIN requirement,
-- but has no password; CONNECT is explicitly withheld from PUBLIC below.
DO $roles$
DECLARE
    role_name text;
    wants_login boolean;
    role_row record;
BEGIN
    FOR role_name, wants_login IN
        SELECT * FROM (VALUES
            ('anon', false),
            ('authenticated', false),
            ('service_role', false),
            ('gym_registration_login', true),
            ('gym_data_owner', false),
            ('gym_public_executor', false),
            ('gym_owner_executor', false)
        ) AS required(name, can_login)
    LOOP
        SELECT r.rolcanlogin, r.rolsuper, r.rolcreatedb, r.rolcreaterole,
               r.rolinherit, r.rolreplication, r.rolbypassrls,
               a.rolpassword
        INTO role_row
        FROM pg_catalog.pg_roles r
        LEFT JOIN pg_catalog.pg_authid a ON a.oid = r.oid
        WHERE r.rolname = role_name;

        IF NOT FOUND THEN
            EXECUTE pg_catalog.format(
                'CREATE ROLE %I %s NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS',
                role_name,
                CASE WHEN wants_login THEN 'LOGIN' ELSE 'NOLOGIN' END
            );
        ELSE
            IF role_row.rolcanlogin IS DISTINCT FROM wants_login
               OR role_row.rolsuper
               OR role_row.rolcreatedb
               OR role_row.rolcreaterole
               OR role_row.rolinherit
               OR role_row.rolreplication
               OR role_row.rolbypassrls
               OR (role_name = 'gym_registration_login' AND role_row.rolpassword IS NOT NULL) THEN
                RAISE EXCEPTION 'Existing role % has unexpected or unsafe attributes', role_name;
            END IF;
        END IF;
    END LOOP;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_auth_members m
        JOIN pg_catalog.pg_roles member_role ON member_role.oid = m.member
        JOIN pg_catalog.pg_roles target_role ON target_role.oid = m.roleid
        WHERE member_role.rolname IN (
            'anon', 'authenticated', 'service_role', 'gym_registration_login',
            'gym_data_owner', 'gym_public_executor', 'gym_owner_executor'
        ) OR target_role.rolname IN (
            'anon', 'authenticated', 'service_role', 'gym_registration_login',
            'gym_data_owner', 'gym_public_executor', 'gym_owner_executor'
        )
    ) THEN
        RAISE EXCEPTION 'Unexpected role membership exists; refusing to normalize it automatically';
    END IF;
END;
$roles$;

-- Keep the LOGIN-only registration role from using the database. The
-- administrator postgres retains connection access.
REVOKE CONNECT ON DATABASE gymforce_pg18_test FROM PUBLIC;
GRANT CONNECT ON DATABASE gymforce_pg18_test TO postgres;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS extensions AUTHORIZATION postgres;

DO $schema_guard$
BEGIN
    IF (SELECT nspowner FROM pg_catalog.pg_namespace WHERE nspname = 'auth')
       <> (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'postgres')
       OR (SELECT nspowner FROM pg_catalog.pg_namespace WHERE nspname = 'extensions')
       <> (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'postgres') THEN
        RAISE EXCEPTION 'auth and extensions schemas must be owned by postgres';
    END IF;
END;
$schema_guard$;

-- The migrations reference only auth.users(id). No password, email, phone,
-- metadata, session, or provider data is needed for SQL/RLS unit probes.
CREATE TABLE IF NOT EXISTS auth.users (
    id uuid PRIMARY KEY
);

DO $auth_users_guard$
DECLARE
    users_oid oid := 'auth.users'::regclass;
    id_attnum smallint;
    column_count integer;
    primary_key_count integer;
    constraint_count integer;
    user_count integer;
BEGIN
    SELECT count(*) INTO column_count
    FROM pg_catalog.pg_attribute
    WHERE attrelid = users_oid AND attnum > 0;
    SELECT attnum INTO id_attnum
    FROM pg_catalog.pg_attribute
    WHERE attrelid = users_oid AND attname = 'id'
      AND atttypid = 'pg_catalog.uuid'::regtype
      AND attnotnull AND attnum > 0 AND NOT attisdropped
      AND attidentity = '' AND attgenerated = '' AND NOT atthasdef;
    SELECT count(*) INTO primary_key_count
    FROM pg_catalog.pg_constraint
    WHERE conrelid = users_oid AND contype = 'p'
      AND conkey = ARRAY[id_attnum]::smallint[]
      AND convalidated AND conislocal
      AND NOT condeferrable AND NOT condeferred AND coninhcount = 0;
    SELECT count(*) INTO constraint_count
    FROM pg_catalog.pg_constraint
    WHERE conrelid = users_oid
      -- PostgreSQL 18 also catalogs the id column's NOT NULL constraint.
      -- Ignore only that exact validated constraint; all other constraints
      -- must still consist of the one primary key checked above.
      AND NOT (
          contype = 'n' AND conkey = ARRAY[id_attnum]::smallint[]
          AND convalidated AND conislocal
          AND NOT condeferrable AND NOT condeferred AND coninhcount = 0
      );
    SELECT count(*) INTO user_count FROM auth.users;

    IF (SELECT relkind FROM pg_catalog.pg_class WHERE oid = users_oid) <> 'r'
       OR (SELECT relowner FROM pg_catalog.pg_class WHERE oid = users_oid)
          <> (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'postgres')
       OR (SELECT relrowsecurity OR relforcerowsecurity
           FROM pg_catalog.pg_class WHERE oid = users_oid)
       OR column_count <> 1 OR id_attnum IS NULL
       OR primary_key_count <> 1 OR constraint_count <> 1 THEN
        RAISE EXCEPTION 'auth.users must be a postgres-owned heap with only id uuid NOT NULL PRIMARY KEY and no defaults or RLS';
    END IF;
    IF user_count > 2 OR EXISTS (
        SELECT 1 FROM auth.users
        WHERE id NOT IN (
            '00000000-0000-4000-8000-000000000001'::uuid,
            '00000000-0000-4000-8000-000000000002'::uuid
        )
    ) THEN
        RAISE EXCEPTION 'auth.users contains unexpected pre-existing records';
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_catalog.pg_trigger
        WHERE tgrelid = users_oid AND NOT tgisinternal
    ) OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_rewrite
        WHERE ev_class = users_oid AND rulename <> '_RETURN'
    ) THEN
        RAISE EXCEPTION 'auth.users contains unexpected triggers or rules';
    END IF;
END;
$auth_users_guard$;

REVOKE ALL ON SCHEMA auth FROM PUBLIC, anon, authenticated, service_role,
    gym_registration_login;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
REVOKE ALL ON TABLE auth.users FROM PUBLIC, anon, authenticated,
    service_role, gym_registration_login;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
PARALLEL SAFE
SET search_path = ''
AS $auth_uid$
    SELECT COALESCE(
        NULLIF(pg_catalog.current_setting('request.jwt.claim.sub', true), '')::uuid,
        (
            NULLIF(
                pg_catalog.current_setting('request.jwt.claims', true),
                ''
            )::jsonb ->> 'sub'
        )::uuid
    )
$auth_uid$;

REVOKE ALL ON FUNCTION auth.uid() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;

-- Synthetic identities only; UUIDs contain no member or production data.
INSERT INTO auth.users (id) VALUES
    ('00000000-0000-4000-8000-000000000001'),
    ('00000000-0000-4000-8000-000000000002')
ON CONFLICT (id) DO NOTHING;

COMMENT ON SCHEMA auth IS
    'Local test compatibility shim only; not Supabase Auth.';
COMMENT ON FUNCTION auth.uid() IS
    'Local test shim reading request JWT subject GUCs; does not validate JWTs.';

DO $auth_schema_inventory$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'auth'
          AND c.relname NOT IN ('users', 'users_pkey')
    ) OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'auth' AND p.proname <> 'uid'
    ) OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_type t
        JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'auth'
          AND t.typrelid = 0
          AND t.typtype <> 'p'
          AND t.typname !~ '^_'
    ) THEN
        RAISE EXCEPTION 'auth schema contains unexpected pre-existing objects';
    END IF;
END;
$auth_schema_inventory$;

COMMIT;
