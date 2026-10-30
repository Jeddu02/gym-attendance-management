-- Procedure-level probes for a disposable database after all migrations.
-- Run as the trusted postgres migration actor with ON_ERROR_STOP enabled.
-- These probes do not observe the foundation migration's DDL context and do
-- not prove Supabase migration-runner atomicity. The committed probe removes
-- all of its fixture objects and test grants before committing.

-- Check final ownership for every protected private table and sequence, plus
-- public.gym_settings. This also appears in the catalog assertion suite.
do $$
declare
    object_record record;
    private_table_count integer;
    private_sequence_count integer;
begin
    if current_user <> 'postgres' then
        raise exception 'Run procedure probes as postgres';
    end if;
    for object_record in
        select c.relname, c.relowner
        from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'private' and c.relkind in ('r', 'p', 'S')
    loop
        if object_record.relowner <> (
            select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner'
        ) then
            raise exception 'private object % has the wrong owner', object_record.relname;
        end if;
    end loop;
    if not exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'gym_settings'
          and c.relowner = (
              select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner'
          )
    ) then
        raise exception 'public.gym_settings has the wrong owner or is missing';
    end if;

    select count(*) into private_table_count
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'private' and c.relkind in ('r', 'p');
    select count(*) into private_sequence_count
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'private' and c.relkind = 'S';
    if private_table_count <> 20 or private_sequence_count <> 1 then
        raise exception 'Unexpected protected private object inventory: % tables, % sequences',
            private_table_count, private_sequence_count;
    end if;
end;
$$;

-- Rollback probe: successful owner-role DDL must disappear on rollback. This
-- is not a test of migration-runner behavior.
begin;
grant gym_data_owner to postgres
    with admin false, inherit false, set true;
set local role gym_data_owner;
alter table private.owner_access
    add column phase1_owner_ddl_success_probe boolean;
reset role;
revoke gym_data_owner from postgres;
rollback;

do $$
begin
    if exists (
        select 1 from pg_catalog.pg_attribute a
        join pg_catalog.pg_class c on c.oid = a.attrelid
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'private'
          and c.relname = 'owner_access'
          and a.attname = 'phase1_owner_ddl_success_probe'
          and not a.attisdropped
    ) then
        raise exception 'Successful DDL rollback probe column survived';
    end if;
    if exists (
        select 1 from pg_catalog.pg_auth_members m
        join pg_catalog.pg_roles member_role on member_role.oid = m.member
        join pg_catalog.pg_roles target_role on target_role.oid = m.roleid
        join pg_catalog.pg_roles grantor_role on grantor_role.oid = m.grantor
        where member_role.rolname = 'postgres'
          and target_role.rolname = 'gym_data_owner'
          and grantor_role.rolname = 'postgres'
          and m.set_option
    ) then
        raise exception 'Rollback left a temporary SET membership';
    end if;
end;
$$;

-- Caught-statement-failure probe: the PL/pgSQL exception block rolls back its
-- subtransaction, then the outer transaction is rolled back. This is not an
-- unhandled migration error and proves no migration-runner atomicity.
begin;
grant gym_data_owner to postgres
    with admin false, inherit false, set true;
set local role gym_data_owner;
do $failure_probe$
begin
    begin
        alter table private.owner_access
            add column phase1_owner_ddl_failure_probe boolean;
        raise exception using message = 'phase1_intentional_failure';
    exception when others then
        if sqlerrm <> 'phase1_intentional_failure' then
            raise;
        end if;
    end;
end;
$failure_probe$;
reset role;
revoke gym_data_owner from postgres;
rollback;

do $$
begin
    if exists (
        select 1 from pg_catalog.pg_attribute a
        join pg_catalog.pg_class c on c.oid = a.attrelid
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'private'
          and c.relname = 'owner_access'
          and a.attname = 'phase1_owner_ddl_failure_probe'
          and not a.attisdropped
    ) then
        raise exception 'Caught-failure rollback probe column survived';
    end if;
    if exists (
        select 1 from pg_catalog.pg_auth_members m
        join pg_catalog.pg_roles member_role on member_role.oid = m.member
        join pg_catalog.pg_roles target_role on target_role.oid = m.roleid
        join pg_catalog.pg_roles grantor_role on grantor_role.oid = m.grantor
        where member_role.rolname = 'postgres'
          and target_role.rolname = 'gym_data_owner'
          and grantor_role.rolname = 'postgres'
          and m.set_option
    ) then
        raise exception 'Failure rollback left a temporary SET membership';
    end if;
end;
$$;

-- Committed procedure-level approximation of the temporary transfer grant.
-- Probe objects are dropped before commit. This verifies PostgreSQL's
-- transfer prerequisites, not the actual foundation migration's context.
begin;
grant gym_data_owner to postgres
    with admin false, inherit false, set true;
grant create on schema private, public to gym_data_owner;
create table private.phase1_owner_transfer_probe (id integer);
create table public.phase1_owner_transfer_public_probe (id integer);
create sequence private.phase1_owner_transfer_probe_seq;

do $$
begin
    if current_user <> 'postgres' or session_user <> 'postgres' then
        raise exception 'Ownership transfer probe must execute as postgres';
    end if;
    if not pg_catalog.has_schema_privilege('gym_data_owner', 'private', 'CREATE')
        or not pg_catalog.has_schema_privilege('gym_data_owner', 'public', 'CREATE') then
        raise exception 'gym_data_owner lacks destination-schema CREATE privileges';
    end if;
    if not exists (
        select 1 from pg_catalog.pg_auth_members m
        join pg_catalog.pg_roles member_role on member_role.oid = m.member
        join pg_catalog.pg_roles target_role on target_role.oid = m.roleid
        where member_role.rolname = 'postgres'
          and target_role.rolname = 'gym_data_owner'
          and m.set_option and not m.inherit_option and not m.admin_option
    ) then
        raise exception 'Expected temporary membership options were not granted';
    end if;
end;
$$;

-- No SET ROLE occurs before these owner changes: current_user stays postgres.
alter table private.phase1_owner_transfer_probe owner to gym_data_owner;
alter table public.phase1_owner_transfer_public_probe owner to gym_data_owner;
alter sequence private.phase1_owner_transfer_probe_seq owner to gym_data_owner;

do $$
begin
    if current_user <> 'postgres' then
        raise exception 'Ownership changes did not retain postgres as current_user';
    end if;
    if not exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'private'
          and c.relname = 'phase1_owner_transfer_probe'
          and c.relowner = (
              select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner'
          )
    ) then
        raise exception 'Table ownership transfer probe failed';
    end if;
    if not exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relname = 'phase1_owner_transfer_public_probe'
          and c.relowner = (
              select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner'
          )
    ) then
        raise exception 'Public-table ownership transfer probe failed';
    end if;
    if not exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'private'
          and c.relname = 'phase1_owner_transfer_probe_seq'
          and c.relkind = 'S'
          and c.relowner = (
              select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner'
          )
    ) then
        raise exception 'Sequence ownership transfer probe failed';
    end if;
end;
$$;

set local role gym_data_owner;
drop table private.phase1_owner_transfer_probe;
drop table public.phase1_owner_transfer_public_probe;
drop sequence private.phase1_owner_transfer_probe_seq;
reset role;
revoke gym_data_owner from postgres;
revoke create on schema private, public from gym_data_owner;
commit;

-- Post-commit checks: no enclosing transaction rolls these assertions back.
do $$
begin
    if exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where (n.nspname = 'private' and c.relname in (
                  'phase1_owner_transfer_probe',
                  'phase1_owner_transfer_probe_seq'
              ))
           or (n.nspname = 'public'
               and c.relname = 'phase1_owner_transfer_public_probe')
    ) then
        raise exception 'Committed ownership probe objects were not cleaned up';
    end if;
    if exists (
        select 1 from pg_catalog.pg_auth_members m
        join pg_catalog.pg_roles member_role on member_role.oid = m.member
        join pg_catalog.pg_roles target_role on target_role.oid = m.roleid
        join pg_catalog.pg_roles grantor_role on grantor_role.oid = m.grantor
        where member_role.rolname = 'postgres'
          and target_role.rolname = 'gym_data_owner'
          and grantor_role.rolname = 'postgres'
          and not (m.admin_option and not m.inherit_option and not m.set_option)
    ) then
        raise exception 'Temporary membership edge survived commit';
    end if;
    if exists (
        with recursive set_reach(role_oid) as (
            select oid from pg_catalog.pg_roles where rolname = 'postgres'
            union
            select m.roleid
            from set_reach sr
            join pg_catalog.pg_auth_members m on m.member = sr.role_oid
            where m.set_option
        )
        select 1 from set_reach
        where role_oid = (
            select oid from pg_catalog.pg_roles where rolname = 'gym_data_owner'
        )
    ) then
        raise exception 'A SET membership path to gym_data_owner survived commit';
    end if;
    if pg_catalog.has_schema_privilege('gym_data_owner', 'private', 'CREATE')
        or pg_catalog.has_schema_privilege('gym_data_owner', 'public', 'CREATE') then
        raise exception 'Temporary destination-schema CREATE privilege survived commit';
    end if;
end;
$$;
