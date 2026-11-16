# Native PostgreSQL migration testing

## Existing-cluster checkpoint: 2026-11-06

The approved existing cluster and `gymforce_pg18_test` were reverified with
read-only preflight on `127.0.0.1:55432` (PostgreSQL 18.6). All 24 migration
success entries and the completion marker were recovered from a read-only
normalized view of the existing log. Windows PowerShell's old mixed-encoding
log contains NUL characters; it was not rewritten. Future runner log writes
now consistently specify UTF-8. The runner was not executed again.

Live catalog inspection confirmed 22 application tables with RLS enabled,
the final payment migration's confirmation RPC and operation-ID index, and no
invalid application indexes. There is no `supabase_migrations` history schema
in this native harness: logs and current schema checks are corroborating
evidence, not an authoritative per-migration database ledger. Full schema
fingerprint comparison against an expected migration manifest is still pending.
The follow-up six-case non-destructive suite now verifies wrong expected
database/port guards, wrong execution role, migrated-bootstrap-state refusal,
and actual connections to an absent database/reserved closed loopback port.
Actual psql exits are 3 for guard/state/role refusals and 2 for connection
refusals. Before/after scoped data, sequence and catalog fingerprints matched.
These are preservation comparisons, not a complete security audit.
The foundation ownership mismatch (`postgres` versus `gym_data_owner`) remains.

Run only the read-only safety suite when explicitly authorized:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\local-testing\test-safety-guards.ps1
if ($LASTEXITCODE -ne 0) { throw 'Stop: safety tests failed.' }
```

See [foundation/lifecycle review](../foundation-lifecycle-review-2026-11-06.md)
for exact scope, ownership findings, lifecycle invariants and approval gates.

Do not rerun the initialization/migration examples below against the existing
cluster. Do not execute `cleanup.sql`; it drops the database. These examples
describe the original setup procedure, not authorization to repeat it.
See [the current development checkpoint](../development-checkpoint-2026-11-06.md).

This is a disposable, Docker-free PostgreSQL harness. It does not connect to,
link, or modify hosted Supabase. The SQL files and PowerShell scripts are
preparation artifacts and must be reviewed before use.

## Cluster identity and authentication

Initialize a **new** PostgreSQL cluster in the dedicated data directory below.
The harness stores a fresh UUID marker and the independent system identifier
reported by `pg_controldata` in separate files under
`%LOCALAPPDATA%\GYMFORCE-PG18-TEST`. The UUID setting is only a consistency
check; it is not proof of cluster identity. `preflight.ps1` compares the
protected system-identifier file with `pg_controldata` on the canonical
expected data directory. Every SQL guard also compares the supplied values
with `(pg_catalog.pg_control_system()).system_identifier` and the connected server's
`data_directory`. The migration runner repeats these checks before each
migration. Cleanup repeats them after reconnecting to `postgres` before
dropping only `gymforce_pg18_test`.

Protect the marker and system-identifier files with ACLs limited to the
current user, SYSTEM, and local Administrators. Never copy the identity files
or marker setting to another cluster. The preflight refuses missing, malformed,
or inconsistent identity files; it never regenerates them. The system
identifier plus canonical path guards against accidental directory/cluster
mismatch. A privileged local administrator can still replace files or alter a
cluster; this is not protection against a hostile local administrator. A
physical clone retains its PostgreSQL system identifier and must never be
treated as the disposable target; the dedicated path and protected identity
files are also required.

Use password authentication. `initdb --pwprompt --auth-host=scram-sha-256`
prompts for the local `postgres` password; it is not embedded in scripts.
Windows clients connect over TCP, so the host authentication rule is the
relevant one here. The server is explicitly bound to `127.0.0.1` only.

The runner uses `psql -w` to prohibit password prompts. Before using it, create
the standard Windows libpq password file at
`%APPDATA%\postgresql\pgpass.conf` with an entry for host `127.0.0.1`, port
`55432`, database `*`, user `postgres`, and the password chosen interactively
at `initdb`. Keep the file out of source control and restrict its Windows ACL
to the current user and required system administrators. The password file is
plain text; filesystem access control protects it. PostgreSQL documents this
Windows path in its [password-file documentation](https://www.postgresql.org/docs/18/libpq-pgpass.html).
Escape `:` and `\` in the password according to pgpass syntax. To edit the
file without putting the password in a command line and restrict its ACL:

```powershell
$pgpassDir = Join-Path $env:APPDATA 'postgresql'
$pgpass = Join-Path $pgpassDir 'pgpass.conf'
New-Item -ItemType Directory -Force -Path $pgpassDir | Out-Null
notepad.exe $pgpass
$current = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$acl = Get-Acl -LiteralPath $pgpass
$acl.SetAccessRuleProtection($true, $false)
foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRuleSpecific($rule) }
$acl.SetOwner($current.User)
foreach ($account in @($current.Name, 'NT AUTHORITY\SYSTEM', 'BUILTIN\Administrators')) {
  $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $account, 'FullControl', 'Allow'
  )
  [void]$acl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $pgpass -AclObject $acl
```

Use one line with format `127.0.0.1:55432:*:postgres:<password>` in that
protected file, replacing the placeholder there only. Never overwrite an
existing `pgpass.conf` automatically. `preflight.ps1` checks its ACL and
requires exactly one matching nonempty connection entry without printing the
password. It rejects malformed escapes, duplicate entries, and competing
wildcard/database-specific entries for this endpoint and user. Unrelated valid
entries may remain. Its conservative parser accepts only `\:` and `\\` escapes.
It requires an explicit current-user FullControl grant and rejects deny rules,
inheritance, unexpected principals, and reparse points in protected-file paths
or the data-directory path. It does not repair files or ACLs.

Run from a session without `PG*` environment variables: preflight rejects all
such overrides without displaying their values, including password, service,
password-file, and session-option overrides. Keep that environment unchanged
for subsequent harness commands. Preflight and migration connections require
`require_auth=scram-sha-256`, so password-free `trust` connections cannot pass.
This PostgreSQL 18 libpq parameter requires a completed SCRAM exchange;
see the [connection parameter documentation](https://www.postgresql.org/docs/18/libpq-connect.html#LIBPQ-CONNECT-REQUIRE-AUTH).
Still review the effective `pg_hba.conf` rule before testing.

Both preflight modes verify the server-reported system identifier, data
directory, marker, endpoint, database, and postgres superuser identity in a
read-only transaction. `-CheckPgpassOnly` connects to maintenance database
`postgres` before the test database exists; despite its legacy name it also
requires all cluster identity files and checks. The default mode checks
`gymforce_pg18_test` and returns the three expected identity values.

If a local Windows PostgreSQL build cannot use SCRAM for the selected local
connection path, do not switch this harness to `trust` silently. Confirm the
effective `pg_hba.conf` rule and use an appropriately protected password file.
If an unavoidable local-only alternative is ever approved, retain loopback
binding, keep the server running only for the test session, and document that
any local process able to reach it may be able to impersonate `postgres`.

## Compatibility objects

`bootstrap.sql` is intended for a fresh database named `gymforce_pg18_test`,
bound to `127.0.0.1:55432`, and run as local PostgreSQL superuser `postgres`.
It creates the restricted role names needed by migrations/assertions, the
`auth` and `extensions` schemas, a minimal `auth.users(id)` relation, two
synthetic UUIDs, and `auth.uid()` reading test subject claims. It validates
that `auth.users` has exactly one `id uuid NOT NULL PRIMARY KEY` column and no
unexpected constraints, triggers, rules, objects, or records. It also refuses
application schemas/objects or extension objects that indicate the database
is not fresh. The bootstrap is transactional and should be run only before
migrations. It requires the marker, system identifier, and canonical data
directory as psql variables.

It deliberately grants no table access, no role memberships, no `BYPASSRLS`,
and no schema creation privileges to application roles. `service_role` is
created without `BYPASSRLS` for restrictive local catalog/security checks;
this differs from Supabase's privileged service role. `gym_registration_login`
is `LOGIN` to match the existing assertion but has no password and receives no
database `CONNECT` privilege.

The bootstrap checks that `pgcrypto` and `btree_gist` are available. The
migrations themselves create those extensions inside `extensions`; the
bootstrap does not pre-create them, so migration extension DDL is exercised.
The audit hash code then uses `extensions.digest`; the dated membership
exclusion guard uses GiST support from `btree_gist`. `auth.uid()` is the only
Supabase Auth function referenced by these migrations.

Synthetic UUIDs:

- `00000000-0000-4000-8000-000000000001`
- `00000000-0000-4000-8000-000000000002`

They are not real Owner/member records. Add synthetic `private.owner_access`
rows only in an isolated fixture after migrations if a probe needs them.

## Exact migration order

`apply-migrations.ps1` pins all 24 migration filenames, checks the inventory,
requires the loopback database identity and compatibility bootstrap, then
applies one file at a time in filename order with `psql -X -w
-v ON_ERROR_STOP=1`. It also compares the running cluster's marker with the
marker file. It writes `migration-run.log` under
`%LOCALAPPDATA%\GYMFORCE-PG18-TEST`. On the first failure, it records that
filename and exits. It never skips a failure or resumes. Discard and recreate
the disposable database before a retry; migrations are drafts and are not
thereby production approved.

The pinned order is:

1. `20261028061728_initial_schema.sql`
2. `20261028062516_membership_core.sql`
3. `20261028062602_payment_ledger.sql`
4. `20261028062706_walkin_attendance.sql`
5. `20261028062757_owner_security.sql`
6. `20261028062853_member_pin_security.sql`
7. `20261028062935_cash_reconciliation.sql`
8. `20261028063027_audit_integrity.sql`
9. `20261028063404_integrity_fixes.sql`
10. `20261028063446_membership_overlap_guard.sql`
11. `20261028063638_payment_integrity_guard.sql`
12. `20261028064100_database_security_foundation.sql`
13. `20261029100000_owner_authorization_rpc.sql`
14. `20261030120000_audit_chain_enforcement.sql`
15. `20261030130000_owner_register_member.sql`
16. `20261030140000_owner_create_pin_enrollment_token.sql`
17. `20261030150000_member_pin_enrollment.sql`
18. `20261030160000_global_pin_enrollment_rate_limit.sql`
19. `20261030170000_rolling_pin_enrollment_rate_limit.sql`
20. `20261030180000_owner_list_members.sql`
21. `20261103080000_owner_membership_plans.sql`
22. `20261103100000_owner_create_membership_purchase.sql`
23. `20261103110000_owner_list_membership_purchases.sql`
24. `20261103120000_owner_membership_payments.sql`

## Later execution commands

These commands are documentation only; none was executed while preparing this
harness. PostgreSQL 18.6 is used because it is the installed native server. The
project's `supabase/config.toml` targets major version 17, so passing this run
does not replace final validation on PostgreSQL 17.

From PowerShell at the project root, initialize a fresh cluster. If the data
directory already exists, stop and review it; do not overwrite it or its marker.

```powershell
$ErrorActionPreference = 'Stop'
$pg = 'C:\Program Files\PostgreSQL\18\bin'
$root = Join-Path $env:LOCALAPPDATA 'GYMFORCE-PG18-TEST'
$data = Join-Path $root 'data'
$markerPath = Join-Path $root 'cluster-marker.txt'
$systemIdentifierPath = Join-Path $root 'system-identifier.txt'
$database = 'gymforce_pg18_test'

if (Test-Path -LiteralPath $data) { throw 'Data directory exists; inspect the cluster before proceeding.' }
if ((Test-Path -LiteralPath $markerPath) -or (Test-Path -LiteralPath $systemIdentifierPath)) {
  throw 'Identity file exists; inspect the cluster before initializing. Never regenerate identity during a test session.'
}
New-Item -ItemType Directory -Force -Path $root | Out-Null
$marker = [guid]::NewGuid().ToString('D')
Set-Content -LiteralPath $markerPath -Value $marker -NoNewline

& "$pg\initdb.exe" -D $data -U postgres --auth-local=scram-sha-256 `
  --auth-host=scram-sha-256 --encoding=UTF8 --pwprompt `
  "--set=gymforce.test_cluster_marker=$marker"
if ($LASTEXITCODE -ne 0) { throw 'initdb failed; do not reuse this marker without reviewing the partial data directory.' }

$controlOutput = & "$pg\pg_controldata.exe" $data 2>&1
if ($LASTEXITCODE -ne 0) { throw 'pg_controldata failed; preserve the partial state for review.' }
$systemIdLine = @($controlOutput | Select-String -Pattern '^Database system identifier:\s*([0-9]+)\s*$')
if ($systemIdLine.Count -ne 1) { throw 'Could not read one system identifier; do not continue.' }
$systemIdentifier = $systemIdLine[0].Matches[0].Groups[1].Value
Set-Content -LiteralPath $systemIdentifierPath -Value $systemIdentifier -NoNewline

# Protect both identity files. This replaces existing ACL entries only on
# these newly created harness files; it does not touch project or database files.
$current = [System.Security.Principal.WindowsIdentity]::GetCurrent()
foreach ($identityPath in @($markerPath, $systemIdentifierPath)) {
  $acl = Get-Acl -LiteralPath $identityPath
  $acl.SetAccessRuleProtection($true, $false)
  foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRuleSpecific($rule) }
  $acl.SetOwner($current.User)
  foreach ($account in @($current.Name, 'NT AUTHORITY\SYSTEM', 'BUILTIN\Administrators')) {
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
      $account, 'FullControl', 'Allow'
    )
    [void]$acl.AddAccessRule($rule)
  }
  Set-Acl -LiteralPath $identityPath -AclObject $acl
}

& "$pg\pg_ctl.exe" -D $data -l (Join-Path $root 'server.log') `
  -o '-h 127.0.0.1 -p 55432' start
if ($LASTEXITCODE -ne 0) { throw 'pg_ctl start failed' }

# Create the protected %APPDATA%\postgresql\pgpass.conf entry described above
# before continuing. No password is placed in this script or its arguments.
& .\docs\local-testing\preflight.ps1 -CheckPgpassOnly
if (-not $?) { throw 'Read-only identity and credential preflight failed; do not create the database.' }
& "$pg\createdb.exe" -w -h 127.0.0.1 -p 55432 -U postgres -T template0 $database
if ($LASTEXITCODE -ne 0) { throw 'createdb failed; inspect the cluster and marker.' }

$identity = & .\docs\local-testing\preflight.ps1
& "$pg\psql.exe" -X -w -v ON_ERROR_STOP=1 `
  -v "expected_cluster_marker=$($identity.Marker)" `
  -v "expected_system_identifier=$($identity.SystemIdentifier)" `
  -v "expected_data_directory=$($identity.DataDirectory)" `
  -h 127.0.0.1 -p 55432 `
  -U postgres -d "dbname=$database require_auth=scram-sha-256 connect_timeout=5" -f .\docs\local-testing\bootstrap.sql
if ($LASTEXITCODE -ne 0) { throw 'Compatibility bootstrap failed; discard this test database.' }

& .\docs\local-testing\apply-migrations.ps1
```

Do not use `supabase start`, `supabase db reset`, `supabase link`, or any
hosted-project command in this native PostgreSQL procedure.

Before any guarded SQL operation in a later PowerShell session, run the shared
read-only preflight. It verifies marker/system-ID file ACLs, the canonical
data-directory, `pg_controldata`, the marker setting in that directory's
configuration, the `pgpass.conf` entry/ACL, and the connected server's actual
identity and data directory. It never prints passwords or regenerates identity:

```powershell
$ErrorActionPreference = 'Stop'
$identity = & .\docs\local-testing\preflight.ps1
```

## RLS behavioral probe

Run the separate [rls_behavior_assertions.sql](rls_behavior_assertions.sql)
only after successful migrations. It builds a temporary fixture schema and
policies inside a transaction, switches from the superuser session to
`anon`/`authenticated`, supplies synthetic subject settings, checks allowed
and denied fixture reads/writes, checks protected application-table access,
and rolls the fixture back. Its temporary policies are examples for testing
the `auth.uid()` shim; they do not change or certify application policies.

```powershell
& "$pg\psql.exe" -X -w -v ON_ERROR_STOP=1 `
  -v "expected_cluster_marker=$($identity.Marker)" `
  -v "expected_system_identifier=$($identity.SystemIdentifier)" `
  -v "expected_data_directory=$($identity.DataDirectory)" `
  -h 127.0.0.1 -p 55432 `
  -U postgres -d "dbname=$database require_auth=scram-sha-256 connect_timeout=5" -f .\docs\local-testing\rls_behavior_assertions.sql
```

The existing superuser SQL assertions inspect catalog state and grants. They
must not be reported as RLS behavior tests: PostgreSQL superusers bypass RLS.
The separate probe explicitly uses `SET LOCAL ROLE` for behavior checks, but
its fixture policies are not the application's policies.

## Cleanup

The cleanup script requires all three expected identity values, checks
database name, server address, port, and superuser, switches to `postgres`,
then checks the system identifier, canonical path, marker, endpoint, and
superuser again before force-dropping exactly the test database.
Use `-w` and the protected password file for both connections. The following
command cleans up the database; stopping the server remains a separate action.

```powershell
$identity = & .\docs\local-testing\preflight.ps1
& "$pg\psql.exe" -X -w -v ON_ERROR_STOP=1 `
  -v "expected_cluster_marker=$($identity.Marker)" `
  -v "expected_system_identifier=$($identity.SystemIdentifier)" `
  -v "expected_data_directory=$($identity.DataDirectory)" `
  -h 127.0.0.1 -p 55432 `
  -U postgres -d "dbname=$database require_auth=scram-sha-256 connect_timeout=5" -f .\docs\local-testing\cleanup.sql
if ($LASTEXITCODE -ne 0) { throw 'Guarded cleanup failed; inspect target before continuing.' }
& "$pg\pg_ctl.exe" -D $data stop
```

Do not delete or reuse the cluster directory without checking that the server
is stopped and that the marker/data directory pair still correspond.

## Existing SQL assertions

- `supabase/tests/membership_payment_security_assertions.sql` is a read-only
  catalog assertion suite intended to run as local superuser after successful
  migrations. It is the best candidate for this minimal bootstrap, although
  execution is still needed to establish whether it passes.
- `supabase/tests/database_security_foundation_assertions.sql` is read-only,
  but cannot pass against the current migrations plus this bootstrap. It
  requires object ownership/permissions for reserved executor/data-owner
  roles and a real extension-owned `graphql_public.graphql(...)` wrapper.
- `supabase/tests/database_owner_migration_procedure.sql` contains mutating
  probes and assumes objects owned by `gym_data_owner`. Current migrations do
  not create/assign that owner role, so it is not a passing candidate without
  resolving the migration/validation contract.
- `supabase/tests/check-security-config.ps1` is a source/config check, not a
  SQL assertion, and does not validate live database behavior.

## Limitations and manual review

### Pending safety validation (not executed)

PowerShell parser checks passed during source review; no preflight, PostgreSQL
utility, SQL operation, or harness execution was performed. Actual cluster
identity, credentials, ACL behavior, and SQL execution remain unverified.
No expected identity values were invented or regenerated.

For the next validation session, first review the effective local SCRAM rule
and the existing disposable cluster provenance. Do not initialize or replace
an existing cluster just to make preflight pass. Then, in Windows PowerShell
with no `PG*` environment overrides, run only the read-only checks:

```powershell
$ErrorActionPreference = 'Stop'
& .\docs\local-testing\preflight.ps1 -CheckPgpassOnly
# Run the default mode only if the disposable test database already exists.
$identity = & .\docs\local-testing\preflight.ps1
$identity | Select-Object Marker, SystemIdentifier, DataDirectory
```

Stop on any failure. A missing identity file or ambiguous `pg_controldata`
output requires review of the original initialization evidence, not a guessed
identifier. The parser deliberately fails on non-English system-ID labels.
Review SQL composite-field expressions as
`(pg_catalog.pg_control_system()).system_identifier` before any SQL execution.

Before authorizing mutating harness steps, validate rejection cases in a
separate disposable Windows profile/cluster with synthetic credentials:
missing/malformed/mismatched identity files; wrong server data directory,
system identifier, marker, port, or database; missing/unreadable password file;
duplicate/shadowing entries, malformed escapes, empty or incorrect passwords,
and a server offering `trust` instead of SCRAM;
inherited ACLs, unexpected principals, deny rules, partial FullControl grants,
and reparse points. Each must fail without returning identity or displaying
password-file contents. Confirm both preflight modes remain read-only. Check
the bootstrap/RLS guards, every migration guard, and both cleanup connections
under separately authorized SQL testing; their runtime behavior is still
untested. Never use production or an unrelated cluster for negative tests.

The `auth.uid()` function reads caller-supplied PostgreSQL GUC values; it does
not verify JWT signatures, issuer, expiry, audience, role, or revocation. Any
database role can set custom GUC values, so this is only a SQL test shim.
Synthetic `auth.users` is not GoTrue Auth. `SET ROLE` plus the GUC settings can
exercise PostgreSQL policy expressions but cannot prove PostgREST role
switching, API schema exposure, HTTP behavior, or Supabase Auth claim
injection. The shim omits `auth.jwt()`, refresh-token state, Auth triggers,
and signup flows because these migrations do not reference them.

Native PostgreSQL can test ordinary PostgreSQL DDL, constraints, functions,
transactions, and role/RLS catalog behavior. It cannot test Supabase's Edge
Runtime, API gateway, Auth service, Realtime, Storage, or `pg_graphql`. The
project targets PostgreSQL 17; the installed PostgreSQL 18.6 run is a
preliminary compatibility signal only. Attendance check-in and PIN
verification operations are not implemented in this repository yet.
