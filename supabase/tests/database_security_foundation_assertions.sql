-- Read-only assertions for a disposable PostgreSQL/Supabase database after
-- applying migrations. Run as a trusted test administrator with ON_ERROR_STOP.
-- This file makes no fixture or schema changes.

begin;

do $$
declare
    role_record record;
    object_record record;
    role_name text;
    protected_role_oids oid[];
    unreviewed_extension_routines text;
begin
    if not exists (
        select 1
        from pg_catalog.pg_roles
        where rolname = current_user and rolsuper
    ) then
        raise exception 'Run this read-only assertion script as a PostgreSQL superuser; password-catalog visibility is required';
    end if;

    -- Reserved roles must have the expected login and privilege attributes.
    for role_record in
        select * from (values
            ('gym_data_owner', false),
            ('gym_public_executor', false),
            ('gym_owner_executor', false),
            ('gym_registration_login', true)
        ) expected(role_name, can_login)
    loop
        if not exists (
            select 1 from pg_catalog.pg_roles r
            where r.rolname = role_record.role_name
              and r.rolcanlogin = role_record.can_login
              and not r.rolsuper
              and not r.rolcreatedb
              and not r.rolcreaterole
              and not r.rolinherit
              and not r.rolreplication
              and not r.rolbypassrls
        ) then
            raise exception 'Role attributes do not match for %', role_record.role_name;
        end if;
    end loop;

    -- rolpassword is only inspectable by a sufficiently privileged test
    -- administrator. Run this assertion on a disposable local database as
    -- its trusted superuser; hosted Supabase postgres may not see the hash.
    if exists (
        select 1
        from pg_catalog.pg_authid
        where rolname = 'gym_registration_login'
          and rolpassword is not null
    ) then
        raise exception 'gym_registration_login unexpectedly has a password verifier';
    end if;

    -- A non-superuser CREATEROLE actor can retain an automatic membership in
    -- each role it creates. Only postgres may have that exact ADMIN-only edge;
    -- all application/executor membership edges are forbidden.
    if exists (
        select 1
        from pg_catalog.pg_auth_members m
        join pg_catalog.pg_roles target_role on target_role.oid = m.roleid
        join pg_catalog.pg_roles member_role on member_role.oid = m.member
        where target_role.rolname in (
            'gym_data_owner', 'gym_public_executor',
            'gym_owner_executor', 'gym_registration_login'
        )
          and (
              member_role.rolname <> 'postgres'
              or m.admin_option is distinct from true
              or m.inherit_option is distinct from false
              or m.set_option is distinct from false
          )
    ) then
        raise exception 'Unexpected role membership to a reserved role or unsafe postgres membership options';
    end if;
    if exists (
        select 1
        from pg_catalog.pg_auth_members m
        join pg_catalog.pg_roles member_role on member_role.oid = m.member
        where member_role.rolname in (
            'gym_data_owner', 'gym_public_executor',
            'gym_owner_executor', 'gym_registration_login'
        )
    ) then
        raise exception 'A reserved role is a member of another role';
    end if;

    -- MEMBER checks every direct/indirect membership regardless of INHERIT;
    -- SET reachability is checked separately from pg_auth_members.set_option.
    foreach role_name in array array[
        'anon', 'authenticated', 'gym_registration_login'
    ] loop
        if pg_catalog.pg_has_role(role_name::name, 'gym_public_executor'::name, 'MEMBER')
            or pg_catalog.pg_has_role(role_name::name, 'gym_owner_executor'::name, 'MEMBER') then
            raise exception 'Application role % has direct or indirect membership in an executor', role_name;
        end if;
    end loop;

    with recursive set_reach(start_oid, reachable_oid) as (
        select r.oid, r.oid
        from pg_catalog.pg_roles r
        where r.rolname in ('anon', 'authenticated', 'gym_registration_login')
        union
        select sr.start_oid, m.roleid
        from set_reach sr
        join pg_catalog.pg_auth_members m on m.member = sr.reachable_oid
        where m.set_option
    )
    select array_agg(oid) into protected_role_oids
    from pg_catalog.pg_roles
    where rolname in ('gym_public_executor', 'gym_owner_executor');

    if exists (
        with recursive set_reach(start_oid, reachable_oid) as (
            select r.oid, r.oid
            from pg_catalog.pg_roles r
            where r.rolname in ('anon', 'authenticated', 'gym_registration_login')
            union
            select sr.start_oid, m.roleid
            from set_reach sr
            join pg_catalog.pg_auth_members m on m.member = sr.reachable_oid
            where m.set_option
        )
        select 1
        from set_reach sr
        where sr.reachable_oid = any(protected_role_oids)
    ) then
        raise exception 'anon, authenticated, or gym_registration_login can SET ROLE to an executor';
    end if;

    -- No caller gets direct privileges through PUBLIC on protected relations.
    if exists (
        select 1
        from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        cross join lateral pg_catalog.aclexplode(
            coalesce(c.relacl, pg_catalog.acldefault(
                case when c.relkind = 'S' then 'S' else 'r' end, c.relowner
            ))
        ) acl
        where ((n.nspname = 'private' and c.relkind in ('r', 'p', 'S'))
            or (n.nspname = 'public' and c.relname = 'gym_settings'))
          and acl.grantee = 0
          and acl.privilege_type in (
              'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE',
              'REFERENCES', 'TRIGGER', 'MAINTAIN', 'USAGE'
          )
    ) then
        raise exception 'PUBLIC has a direct privilege on a protected table or sequence';
    end if;
    if exists (
        select 1
        from pg_catalog.pg_attribute a
        join pg_catalog.pg_class c on c.oid = a.attrelid
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        cross join lateral pg_catalog.aclexplode(
            coalesce(a.attacl, array[]::pg_catalog.aclitem[])
        ) acl
        where a.attnum > 0
          and not a.attisdropped
          and ((n.nspname = 'private' and c.relkind in ('r', 'p'))
              or (n.nspname = 'public' and c.relname = 'gym_settings'))
          and acl.grantee = 0
    ) then
        raise exception 'PUBLIC has a column-level privilege on a protected table';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_namespace n
        cross join lateral pg_catalog.aclexplode(
            coalesce(n.nspacl, pg_catalog.acldefault('n', n.nspowner))
        ) acl
        where n.nspname in ('private', 'api')
          and acl.grantee = 0
          and acl.privilege_type in ('USAGE', 'CREATE')
    ) then
        raise exception 'PUBLIC has USAGE or CREATE on private/api';
    end if;

    if not exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        join pg_catalog.pg_roles r on r.oid = c.relowner
        where n.nspname = 'public' and c.relname = 'gym_settings'
          and r.rolname = 'gym_data_owner'
    ) then
        raise exception 'public.gym_settings is not owned by gym_data_owner';
    end if;

    -- This list is derived from CREATE TABLE statements in the migrations.
    -- Keep it explicit so missing project tables cannot make the later
    -- all-existing-tables ownership/RLS loop pass vacuously.
    if exists (
        select 1
        from unnest(array[
            'owner_access', 'members', 'audit_events',
            'membership_plans', 'membership_purchases',
            'payment_records', 'payment_allocations', 'payment_events', 'payment_corrections',
            'walkin_fee_versions', 'walkin_requests', 'attendance_checkins',
            'attendance_validity_resolutions',
            'member_pin_credentials', 'member_pin_setup_tokens', 'pin_attempt_buckets',
            'cash_drawer_sessions', 'cash_reconciliations', 'cash_reconciliation_adjustments',
            'audit_chain_heads'
        ]) expected(table_name)
        left join pg_catalog.pg_namespace n on n.nspname = 'private'
        left join pg_catalog.pg_class c
          on c.relnamespace = n.oid
         and c.relname = expected.table_name
         and c.relkind in ('r', 'p')
        where c.oid is null
           or c.relowner <> (select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner')
           or not c.relrowsecurity
           or not c.relforcerowsecurity
    ) then
        raise exception 'An expected private table is missing, incorrectly owned, or missing enabled/forced RLS';
    end if;

    -- The only private identity columns in the migrations are
    -- audit_events.id and payment_events.id. Resolve their actual sequence
    -- names instead of assuming PostgreSQL's generated naming convention.
    if exists (
        select 1
        from (values
            (pg_catalog.pg_get_serial_sequence('private.audit_events', 'id')),
            (pg_catalog.pg_get_serial_sequence('private.payment_events', 'id'))
        ) expected(sequence_name)
        left join pg_catalog.pg_class c
          on c.oid = pg_catalog.to_regclass(expected.sequence_name)
        where expected.sequence_name is null
           or c.oid is null
           or c.relkind <> 'S'
           or c.relowner <> (select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner')
    ) then
        raise exception 'An expected private identity sequence is missing or not owned by gym_data_owner';
    end if;

    for object_record in
        select c.relname, c.relowner, c.relrowsecurity, c.relforcerowsecurity
        from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'private' and c.relkind in ('r', 'p')
    loop
        if object_record.relowner <> (select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner') then
            raise exception 'private table % has the wrong owner', object_record.relname;
        end if;
        if not object_record.relrowsecurity or not object_record.relforcerowsecurity then
            raise exception 'private table % is missing enabled/forced RLS', object_record.relname;
        end if;
    end loop;

    if not exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'gym_settings'
          and c.relrowsecurity and c.relforcerowsecurity
    ) then
        raise exception 'public.gym_settings is missing enabled/forced RLS';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_policy p
        join pg_catalog.pg_class c on c.oid = p.polrelid
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where (n.nspname = 'private' and c.relkind in ('r', 'p'))
           or (n.nspname = 'public' and c.relname = 'gym_settings')
    ) then
        raise exception 'Phase 1 protected tables unexpectedly have RLS policies';
    end if;

    -- Application roles and restricted login have no table/sequence access.
    for role_record in
        select unnest(array[
            'anon', 'authenticated', 'service_role', 'gym_registration_login',
            'gym_public_executor', 'gym_owner_executor'
        ]) as role_name
    loop
        for object_record in
            select c.oid, n.nspname, c.relname, c.relkind
            from pg_catalog.pg_class c
            join pg_catalog.pg_namespace n on n.oid = c.relnamespace
            where (n.nspname = 'private' and c.relkind in ('r', 'p', 'S'))
               or (n.nspname = 'public' and c.relname = 'gym_settings')
        loop
            if object_record.relkind = 'S' then
                if pg_catalog.has_sequence_privilege(role_record.role_name, object_record.oid, 'USAGE')
                    or pg_catalog.has_sequence_privilege(role_record.role_name, object_record.oid, 'SELECT')
                    or pg_catalog.has_sequence_privilege(role_record.role_name, object_record.oid, 'UPDATE') then
                    raise exception 'Role % has sequence access to %.%', role_record.role_name, object_record.nspname, object_record.relname;
                end if;
            else
                if pg_catalog.has_table_privilege(role_record.role_name, object_record.oid, 'SELECT')
                    or pg_catalog.has_table_privilege(role_record.role_name, object_record.oid, 'INSERT')
                    or pg_catalog.has_table_privilege(role_record.role_name, object_record.oid, 'UPDATE')
                    or pg_catalog.has_table_privilege(role_record.role_name, object_record.oid, 'DELETE')
                    or pg_catalog.has_table_privilege(role_record.role_name, object_record.oid, 'TRUNCATE')
                    or pg_catalog.has_table_privilege(role_record.role_name, object_record.oid, 'REFERENCES')
                    or pg_catalog.has_table_privilege(role_record.role_name, object_record.oid, 'TRIGGER')
                    or pg_catalog.has_table_privilege(role_record.role_name, object_record.oid, 'MAINTAIN')
                    or pg_catalog.has_any_column_privilege(role_record.role_name, object_record.oid, 'SELECT')
                    or pg_catalog.has_any_column_privilege(role_record.role_name, object_record.oid, 'INSERT')
                    or pg_catalog.has_any_column_privilege(role_record.role_name, object_record.oid, 'UPDATE')
                    or pg_catalog.has_any_column_privilege(role_record.role_name, object_record.oid, 'REFERENCES') then
                    raise exception 'Role % has table access to %.%', role_record.role_name, object_record.nspname, object_record.relname;
                end if;
            end if;
        end loop;
    end loop;

    if not exists (select 1 from pg_catalog.pg_namespace where nspname = 'api') then
        raise exception 'api schema was not created';
    end if;
    if (
        select count(*) from pg_catalog.pg_namespace where nspname in ('private', 'api')
    ) <> 2 or exists (
        select 1
        from pg_catalog.pg_namespace n
        join pg_catalog.pg_roles r on r.oid = n.nspowner
        where n.nspname in ('private', 'api')
          and r.rolname <> 'postgres'
    ) then
        raise exception 'private and api schemas must both be owned by postgres';
    end if;
    if not pg_catalog.has_schema_privilege('authenticated', 'api', 'USAGE')
        or pg_catalog.has_schema_privilege('anon', 'api', 'USAGE')
        or pg_catalog.has_schema_privilege('service_role', 'api', 'USAGE') then
        raise exception 'api schema USAGE grants do not match the foundation';
    end if;
    if pg_catalog.has_schema_privilege('gym_registration_login', 'api', 'USAGE')
        or pg_catalog.has_schema_privilege('gym_public_executor', 'api', 'USAGE')
        or pg_catalog.has_schema_privilege('gym_owner_executor', 'api', 'USAGE') then
        raise exception 'Dormant login/executors unexpectedly have api schema USAGE';
    end if;
    if pg_catalog.has_schema_privilege('anon', 'private', 'USAGE')
        or pg_catalog.has_schema_privilege('authenticated', 'private', 'USAGE')
        or pg_catalog.has_schema_privilege('service_role', 'private', 'USAGE')
        or pg_catalog.has_schema_privilege('gym_registration_login', 'private', 'USAGE')
        or pg_catalog.has_schema_privilege('gym_public_executor', 'private', 'USAGE')
        or pg_catalog.has_schema_privilege('gym_owner_executor', 'private', 'USAGE') then
        raise exception 'private schema is accessible to a browser/service caller or dormant login';
    end if;
    if not pg_catalog.has_schema_privilege('gym_data_owner', 'private', 'USAGE')
        or pg_catalog.has_schema_privilege('gym_data_owner', 'private', 'CREATE')
        or pg_catalog.has_schema_privilege('gym_data_owner', 'public', 'CREATE') then
        raise exception 'gym_data_owner schema privileges do not match the foundation';
    end if;
    if pg_catalog.has_schema_privilege('anon', 'api', 'CREATE')
        or pg_catalog.has_schema_privilege('authenticated', 'api', 'CREATE')
        or pg_catalog.has_schema_privilege('service_role', 'api', 'CREATE')
        or pg_catalog.has_schema_privilege('anon', 'public', 'CREATE')
        or pg_catalog.has_schema_privilege('authenticated', 'public', 'CREATE')
        or pg_catalog.has_schema_privilege('service_role', 'public', 'CREATE') then
        raise exception 'a Data API role can create objects in an API schema';
    end if;
    if exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'api' and c.relkind in ('r', 'p', 'v', 'm', 'S')
    ) then
        raise exception 'api must contain no tables, views, or sequences in Phase 1';
    end if;
    if exists (
        select 1 from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'api'
    ) then
        raise exception 'api must contain no routines until their authorization design is approved';
    end if;
    if (
        select count(*)
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'private'
    ) <> 1 then
        raise exception 'private must contain only the existing is_active_owner helper in Phase 1';
    end if;
    if exists (
        select 1
        from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'private'
          and c.relkind = 'S'
          and c.relowner <> (select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner')
    ) then
        raise exception 'a private sequence has the wrong owner';
    end if;

    -- The repository config creates pgcrypto and btree_gist in the separate
    -- extensions schema. No extension-owned routines in the project API/private
    -- schemas are approved here except the exact pg_graphql wrapper.
    -- Fail with a routine/extension inventory so any additional extension
    -- routine is visible and must be reviewed before adding a narrow exception.
    select string_agg(
        format('%I.%I(%s) [extension %I]', n.nspname, p.proname,
            pg_catalog.pg_get_function_identity_arguments(p.oid), e.extname),
        '; ' order by n.nspname, p.proname,
            pg_catalog.pg_get_function_identity_arguments(p.oid), e.extname
    )
    into unreviewed_extension_routines
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    join pg_catalog.pg_depend d
      on d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
     and d.objid = p.oid
     and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
     and d.deptype = 'e'
    join pg_catalog.pg_extension e on e.oid = d.refobjid
    where n.nspname in ('private', 'api', 'public', 'graphql_public')
      and not (
          n.nspname = 'graphql_public'
          and p.proname = 'graphql'
          and p.prokind = 'f'
          and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          and e.extname = 'pg_graphql'
      );

    if unreviewed_extension_routines is not null then
        raise exception 'Unreviewed extension-owned routines in project API/private schemas: %',
            unreviewed_extension_routines;
    end if;

    -- The exposed schema list mirrors [api].schemas in config.toml and the
    -- exact-list assertion in check-security-config.ps1. Inspect project
    -- routines in every exposed schema plus private. Only the exact approved
    -- GraphQL wrapper below is platform-managed and exempt from project ACL,
    -- owner, and search-path rules.
    if not exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'graphql_public'
          and p.proname = 'graphql'
          and p.prokind = 'f'
          and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
    ) then
        raise exception 'Required graphql_public.graphql(text, text, jsonb, jsonb) function is missing';
    end if;

    if not exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        join pg_catalog.pg_depend d
          on d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
         and d.objid = p.oid
         and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
         and d.deptype = 'e'
        join pg_catalog.pg_extension e on e.oid = d.refobjid
        where n.nspname = 'graphql_public'
          and p.proname = 'graphql'
          and p.prokind = 'f'
          and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          and e.extname = 'pg_graphql'
    ) then
        raise exception 'The expected GraphQL wrapper must be owned by the pg_graphql extension';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('private', 'api', 'public', 'graphql_public')
          and not (
              n.nspname = 'graphql_public'
              and p.proname = 'graphql'
              and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          )
          and not exists (
              select 1
              from pg_catalog.pg_depend d
              where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.objid = p.oid
                and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
                and d.deptype = 'e'
          )
          and (
              pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')
              or pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE')
              or pg_catalog.has_function_privilege('service_role', p.oid, 'EXECUTE')
              or pg_catalog.has_function_privilege('gym_registration_login', p.oid, 'EXECUTE')
          )
    ) then
        raise exception 'A project-controlled private/exposed-schema function is executable by a caller role';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('private', 'api', 'public', 'graphql_public')
          and not (
              n.nspname = 'graphql_public'
              and p.proname = 'graphql'
              and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          )
          and not exists (
              select 1
              from pg_catalog.pg_depend d
              where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.objid = p.oid
                and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
                and d.deptype = 'e'
          )
          and (
              pg_catalog.has_function_privilege('gym_public_executor', p.oid, 'EXECUTE')
              or pg_catalog.has_function_privilege('gym_owner_executor', p.oid, 'EXECUTE')
          )
    ) then
        raise exception 'A dormant executor can execute a project-controlled private/exposed-schema function';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        cross join lateral pg_catalog.aclexplode(
            coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
        ) acl
        where n.nspname in ('private', 'api', 'public', 'graphql_public')
          and not (
              n.nspname = 'graphql_public'
              and p.proname = 'graphql'
              and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          )
          and not exists (
              select 1
              from pg_catalog.pg_depend d
              where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.objid = p.oid
                and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
                and d.deptype = 'e'
          )
          and acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
    ) then
        raise exception 'PUBLIC has EXECUTE on a project-controlled private/exposed-schema function';
    end if;

    -- Application-created SECURITY DEFINER endpoints are not part of Phase 1.
    -- The only extension-owned routine exception is the exact verified GraphQL
    -- wrapper; unknown extension routines fail in the inventory assertion above.
    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'graphql_public', 'api')
          and p.prosecdef
          and not (
              n.nspname = 'graphql_public'
              and p.proname = 'graphql'
              and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          )
          and not exists (
              select 1
              from pg_catalog.pg_depend d
              where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.objid = p.oid
                and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
                and d.deptype = 'e'
          )
    ) then
        raise exception 'Project-controlled SECURITY DEFINER function found in an exposed schema';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'graphql_public'
          and p.proname = 'graphql'
          and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          and p.prosecdef
    ) then
        raise exception 'The standard graphql_public.graphql wrapper must remain SECURITY INVOKER';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'graphql_public', 'api')
          and not (
              n.nspname = 'graphql_public'
              and p.proname = 'graphql'
              and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          )
          and not exists (
              select 1
              from pg_catalog.pg_depend d
              where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.objid = p.oid
                and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
                and d.deptype = 'e'
          )
          and p.proowner <> (select oid from pg_catalog.pg_roles where rolname = 'postgres')
    ) then
        raise exception 'A project-controlled exposed-schema function has an unexpected owner';
    end if;

    -- The standard GraphQL endpoint is intentionally platform-managed and
    -- callable through its exposed schema. Ensure it is not assigned to any
    -- project data-owner, executor, or dormant-login role; its platform ACL
    -- and search-path contract remain governed by the Supabase extension.
    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'graphql_public'
          and p.proname = 'graphql'
          and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          and p.proowner in (
              select oid from pg_catalog.pg_roles
              where rolname in (
                  'gym_data_owner', 'gym_public_executor',
                  'gym_owner_executor', 'gym_registration_login'
              )
          )
    ) then
        raise exception 'The standard GraphQL endpoint is owned by a project-restricted role';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('private', 'api')
          and p.prosecdef
          and not exists (
              select 1
              from pg_catalog.pg_depend d
              where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.objid = p.oid
                and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
                and d.deptype = 'e'
          )
          and pg_catalog.pg_get_userbyid(p.proowner) not in ('gym_public_executor', 'gym_owner_executor')
    ) then
        raise exception 'SECURITY DEFINER function has an unexpected owner';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where (
            n.nspname in ('private', 'api')
            and p.proowner = (select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner')
        ) or (
            n.nspname in ('public', 'graphql_public', 'api')
            and p.proowner in (
                select oid from pg_catalog.pg_roles
                where rolname in (
                    'gym_data_owner', 'gym_public_executor',
                    'gym_owner_executor', 'gym_registration_login'
                )
            )
        )
    ) then
        raise exception 'A reserved data/executor/login role owns a disallowed private/exposed-schema function';
    end if;

    if not exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'private'
          and p.proname = 'is_active_owner'
          and p.prokind = 'f'
          and not p.prosecdef
          and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
    ) then
        raise exception 'private.is_active_owner must exist as a postgres-owned SECURITY INVOKER function';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('private', 'api', 'public', 'graphql_public')
          and not (
              n.nspname = 'graphql_public'
              and p.proname = 'graphql'
              and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'text, text, jsonb, jsonb'
          )
          and not exists (
              select 1
              from pg_catalog.pg_depend d
              where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.objid = p.oid
                and d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
                and d.deptype = 'e'
          )
          and not (coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']::text[])
    ) then
        raise exception 'Project-controlled private/exposed-schema function is missing the hardened empty search_path';
    end if;

    -- Effective global function defaults for postgres include PostgreSQL's
    -- implicit defaults when no pg_default_acl row exists. This catalog check
    -- describes postgres-created functions only; creation-role probe objects
    -- are still required to verify effective runtime behavior.
    if exists (
        select 1
        from pg_catalog.pg_roles r
        left join pg_catalog.pg_default_acl d
          on d.defaclrole = r.oid
         and d.defaclnamespace = 0
         and d.defaclobjtype = 'f'
        cross join lateral pg_catalog.aclexplode(
            coalesce(d.defaclacl, pg_catalog.acldefault('f', r.oid))
        ) acl
        where r.rolname = 'postgres'
          and acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
    ) then
        raise exception 'Effective postgres function defaults grant PUBLIC EXECUTE';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_roles owner_role
        left join pg_catalog.pg_default_acl d
          on d.defaclrole = owner_role.oid
         and d.defaclnamespace = 0
         and d.defaclobjtype = 'f'
        cross join lateral pg_catalog.aclexplode(
            coalesce(d.defaclacl, pg_catalog.acldefault('f', owner_role.oid))
        ) acl
        where owner_role.rolname = 'postgres'
          and acl.grantee in (
              (select oid from pg_catalog.pg_roles where rolname = 'anon'),
              (select oid from pg_catalog.pg_roles where rolname = 'authenticated'),
              (select oid from pg_catalog.pg_roles where rolname = 'service_role'),
              (select oid from pg_catalog.pg_roles where rolname = 'gym_registration_login'),
              (select oid from pg_catalog.pg_roles where rolname = 'gym_public_executor'),
              (select oid from pg_catalog.pg_roles where rolname = 'gym_owner_executor')
          )
          and acl.privilege_type = 'EXECUTE'
    ) then
        raise exception 'Effective postgres function defaults grant execution to an application role';
    end if;

    if exists (
        select 1
        from pg_catalog.pg_default_acl d
        join pg_catalog.pg_roles owner_role on owner_role.oid = d.defaclrole
        cross join lateral pg_catalog.aclexplode(d.defaclacl) acl
        where owner_role.rolname = 'postgres'
          and d.defaclnamespace = 0
          and d.defaclobjtype in ('r', 'S')
          and acl.grantee in (
              0,
              (select oid from pg_catalog.pg_roles where rolname = 'anon'),
              (select oid from pg_catalog.pg_roles where rolname = 'authenticated'),
              (select oid from pg_catalog.pg_roles where rolname = 'service_role'),
              (select oid from pg_catalog.pg_roles where rolname = 'gym_registration_login'),
              (select oid from pg_catalog.pg_roles where rolname = 'gym_public_executor'),
              (select oid from pg_catalog.pg_roles where rolname = 'gym_owner_executor')
          )
    ) then
        raise exception 'postgres global defaults grant table or sequence access to an API caller';
    end if;

    -- These are explicit schema-specific default ACL entries. They are
    -- checked separately from the effective global function ACL above because
    -- per-schema defaults add to, rather than replace, global defaults.
    if exists (
        select 1
        from pg_catalog.pg_default_acl d
        join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
        join pg_catalog.pg_roles owner_role on owner_role.oid = d.defaclrole
        cross join lateral pg_catalog.aclexplode(d.defaclacl) acl
        where owner_role.rolname = 'postgres'
          and (
              (n.nspname in ('private', 'api') and d.defaclobjtype = 'f'
                  and acl.privilege_type = 'EXECUTE'
                  and acl.grantee in (
                      0,
                      (select oid from pg_catalog.pg_roles where rolname = 'anon'),
                      (select oid from pg_catalog.pg_roles where rolname = 'authenticated'),
                      (select oid from pg_catalog.pg_roles where rolname = 'service_role'),
                      (select oid from pg_catalog.pg_roles where rolname = 'gym_registration_login'),
                      (select oid from pg_catalog.pg_roles where rolname = 'gym_public_executor'),
                      (select oid from pg_catalog.pg_roles where rolname = 'gym_owner_executor')
                  ))
              or (n.nspname in ('private', 'api', 'public') and d.defaclobjtype in ('r', 'S')
                  and acl.grantee in (
                      0,
                      (select oid from pg_catalog.pg_roles where rolname = 'anon'),
                      (select oid from pg_catalog.pg_roles where rolname = 'authenticated'),
                      (select oid from pg_catalog.pg_roles where rolname = 'service_role'),
                      (select oid from pg_catalog.pg_roles where rolname = 'gym_registration_login'),
                      (select oid from pg_catalog.pg_roles where rolname = 'gym_public_executor'),
                      (select oid from pg_catalog.pg_roles where rolname = 'gym_owner_executor')
                  ))
          )
    ) then
        raise exception 'postgres schema-specific defaults grant prohibited API/private/public access';
    end if;
end;
$$;

rollback;
