# Database Security Foundation — Phase 1

**Status:** Source changes are prepared; the migration and assertions have not
been run against PostgreSQL. Nothing in this document claims hosted or
database-backed validation.

## Scope and migration compatibility

`20261028064100_database_security_foundation.sql` follows the existing schema,
membership, payment, walk-in attendance, Owner registry, PIN security, cash
reconciliation, audit integrity, and integrity-guard migrations. It transfers
the current private tables and `public.gym_settings` to `gym_data_owner`, forces
RLS, hardens grants, and creates an empty exposed `api` schema. It adds no
policy, registration/Owner function, public write path, or credential.

The existing constraints, indexes, foreign keys, exclusion constraints, and
unique attendance rules are not rewritten. Prior migrations enable RLS and
revoke client table access. They define no policies; the existing
`private.is_active_owner()` is an invoker function, not an exposed endpoint.

The migration is one transaction. It fails if any reserved role already
exists, so reapplication after success is intentionally unsupported. A
transactional failure should roll back the role/object changes. This behavior
and the migration’s Supabase compatibility still require disposable database
testing.

## Roles and membership strategy

All four reserved roles are created `NOSUPERUSER NOCREATEDB NOCREATEROLE
NOINHERIT NOREPLICATION NOBYPASSRLS`. `gym_registration_login` has `LOGIN
PASSWORD NULL`; the other three use `NOLOGIN`.

PostgreSQL may automatically grant roles created by a non-superuser
`CREATEROLE` actor back to that actor with `ADMIN TRUE, INHERIT FALSE, SET
FALSE`. Supabase documents that hosted `postgres` is not a superuser and may
not be able to revoke system-granted memberships. The migration therefore
does not try to revoke those memberships. It allows only the exact
`postgres`-to-reserved-role ADMIN-only edge and rejects any other direct
membership. If run by a superuser that has no automatic memberships, the
assertions also allow the absence of those edges.

The `ADMIN` option means the trusted migration administrator could grant a
membership to another role. That is an administrative capability and remains
a trust assumption. The membership has `SET FALSE` and `INHERIT FALSE`, so it
does not itself let `postgres` inherit or `SET ROLE` to an executor. No
application role may have direct or indirect membership in either executor.
Assertions check the membership graph, the `ADMIN`/`INHERIT`/`SET` options,
and recursive `SET` reachability from `anon`, `authenticated`, and
`gym_registration_login` to both executors. A live connection as the
registration login must still attempt both `SET ROLE` commands in a disposable
database.

The migration temporarily grants its current trusted actor `SET` access to
`gym_data_owner` for table ownership transfer and revokes that grant before
commit. If PostgreSQL retains its separate automatic ADMIN-only membership,
that grant is not expected to revoke it. Application roles are never granted
data-owner or executor membership.

## Follow-on migration procedure for owned tables

`gym_data_owner` owns every existing table in `private`,
`public.gym_settings`, and private sequences. The migration administrator
does not retain routine `SET` access. Each later migration that must alter an
existing data-owner-owned table must use the following transaction pattern,
with `postgres` replaced only if the migration actor is deliberately changed
and the role/grant assertions are updated in the same reviewed change:

```sql
begin;

grant gym_data_owner to postgres
    with admin false, inherit false, set true;
set local role gym_data_owner;

-- Put only the reviewed ALTER TABLE / ALTER SEQUENCE statements here.
-- Do not create functions under this role or add schema CREATE here.

reset role;
revoke gym_data_owner from postgres;
commit;
```

The membership grant is limited to the trusted migration actor, scoped to
this transaction, and explicitly non-inheriting and non-administrative. A
future disposable-database test must confirm this works with the target
Supabase `postgres` role, including the case where an automatic ADMIN-only
membership remains under a different grantor. It must also force an error
after the temporary grant, roll back, and verify that the DDL and temporary
membership are absent afterwards. Migration tooling must stop on SQL errors;
never continue a failed transaction. This procedure is documented but has
not been executed.

No executor function ownership is transferred to `gym_data_owner`. Function
owners remain separate from table ownership.

## Function ACL/default-privilege strategy

The foundation revokes PostgreSQL’s default global `PUBLIC EXECUTE` grant for
functions created by `postgres` and also revokes `PUBLIC EXECUTE` from
schema-specific function defaults in `private` and `api`. It removes caller
grants from `postgres`-created tables/sequences. Default ACLs apply only to
objects created by the named current role; they do not follow role membership
or a later `ALTER FUNCTION OWNER`.

Future exposed `api` `SECURITY INVOKER` wrappers and private
`SECURITY DEFINER` helpers are to be created as `postgres`, so the configured
`postgres` default ACLs apply. Each future function migration must revoke
`PUBLIC EXECUTE` in the same transaction immediately after creation and
before any caller grant. Private helpers are then transferred to their
corresponding executor using a temporary `SET` membership and temporary
`CREATE` on `private` for the target executor; PostgreSQL requires both the
ability to `SET ROLE` and `CREATE` on the containing schema to change function
ownership. Revoke those temporary privileges before commit. API wrappers
remain `postgres`-owned and receive only exact, reviewed `authenticated`
execution grants. The transaction must set `search_path = ''`, fully qualify
references, and establish only the required helper execution/table grants.
No such executor schema, table, or function grants are made in Phase 1.

Function-owner provisioning is intentionally incomplete. A future function
migration must separately demonstrate how the trusted migration actor gains
temporary `SET` access and how the executor receives narrowly scoped
`CREATE` on `private` for ownership transfer; those privileges must be
revoked afterward. This has not been validated against hosted Supabase.

## Local API and Auth configuration

Local `supabase/config.toml` exposes `api` and does not expose `private`.
`api` is empty. `authenticated` has schema `USAGE`, but no function exists;
`anon`, `service_role`, the registration login, and executors have no `api`
`USAGE`. `auto_expose_new_tables = false` is local configuration only.

The current SQL assertion suite also expects the `pg_graphql` extension and the
exact `graphql_public.graphql(text, text, jsonb, jsonb)` wrapper. The repository
migrations do not create or enable `pg_graphql`; exposing `graphql_public` in
`config.toml` does not provision the extension. The project must explicitly
decide whether GraphQL is required and, if so, document how the extension is
provisioned in each supported environment. Until then, the assertion has an
external prerequisite that may be absent from a fresh local database.

The wrapper's execution grants, expected owner, and search-path contract remain
unverified. The current assertion checks that it is an extension-owned,
`SECURITY INVOKER` function and is not owned by the project's restricted
roles; `SECURITY INVOKER` alone does not establish safe grants, ownership, or
search-path behavior. Do not assume those properties from the platform contract
without verifying the selected Supabase environment.

Local global, anonymous, email, and SMS signup settings are disabled. The
PowerShell check verifies these values statically. Neither this config nor
that check changes hosted project settings or proves Data API behavior. Local
config changes take effect after the local Supabase stack is restarted.

## Assertion and runtime coverage

`supabase/tests/database_security_foundation_assertions.sql` is a read-only
catalog assertion script wrapped in a transaction and rollback. It is
designed to run as a PostgreSQL superuser in a **disposable local database**;
it inspects `pg_authid` to prove that the registration role has no password
verifier. It checks role attributes and membership options, application
membership and recursive `SET` reachability, schema/table/function/sequence
privileges, schema/table/sequence/function ownership, RLS enabled/forced and
policy absence, function `search_path`, default ACLs, and that `api` has no
endpoints. The catalog checks establish database state only when actually run
against a database.

`supabase/tests/check-security-config.ps1` performs static checks against the
local TOML file. It does not start Supabase or test PostgREST.

`supabase/tests/database_owner_migration_procedure.sql` is a prepared,
disposable-database probe for successful owner-role DDL, a deliberately failed
DDL subtransaction, and rollback of both temporary columns and the
migration-actor `SET` membership. It is not a migration and must not be run on
hosted or production data. It has not been executed.

Required disposable-database tests still include:

1. Apply the full migration chain with the target PostgreSQL/Supabase version
   and the actual migration actor model. Confirm automatic creator memberships
   and the accepted `postgres` ADMIN-only membership shape.
2. Run the SQL assertion script as local superuser.
3. Connect as `gym_registration_login`; verify `SET ROLE gym_public_executor`
   and `SET ROLE gym_owner_executor` both fail. Verify the catalog graph also
   has no indirect `SET` path from `anon` or `authenticated`.
4. Run `database_owner_migration_procedure.sql`; verify its successful DDL,
   intentional DDL failure, and rollback assertions pass. Separately test
   migration-runner atomicity in a completely disposable local Supabase
   project with a unique project ID and unique ports. Do not link this project
   to a hosted project. First establish a clean baseline with
   `supabase db reset --local --no-seed`. Then add a temporary migration that
   creates a uniquely named probe schema/table, inserts a recognizable row,
   and raises an unhandled error after those changes. Do not add explicit
   transaction statements or a `transaction=false` directive to the probe.
   Trigger the failure with `supabase migration up --local`, leaving the local
   database running for inspection. Check whether the probe schema/table and
   row remain, and whether the probe migration version appears in
   `supabase_migrations.schema_migrations` (or `supabase migration list
   --local`). The expected fully rolled-back result is no probe objects or
   row and no migration-history entry. Inspect before any further reset.
   Until this test completes successfully in a disposable environment, CLI
   transaction behavior and migration-history handling remain unverified.
5. Create synthetic functions as `postgres`, verify the configured default
   ACL before explicit revocation, transfer a private helper to its executor
   using temporary membership/schema `CREATE`, and verify `PUBLIC` and
   unauthorized roles cannot execute after revocation. Roll the transaction
   back so no probe function or grant remains.
6. Verify PostgREST exposes the empty `api` schema and not `private`.

No migration or database test has been run for these corrections. No hosted
project, database, credential, or real member data was accessed.
