# A02 customer-authority compatibility package — local review only

Current tooling prerequisite: `npm.cmd ci --prefix tools/recovery-parser
--ignore-scripts --no-audit --no-fund` (one command). Parsers are exactly pinned
with transitive SRI in that separate development package, not loaded from hidden
.cache packages. `node scripts/test-recovery-reproducibility.mjs` proves a fresh
allowlisted workspace can install/run them from an empty npm cache. See the
current final review for eleven actual legacy refusals and five init fault tests.

Owner authorization covers local implementation/testing, not production adoption.
This package does not update migration history, deploy anything, or modify the
37 files under `supabase/migrations/`. See the current readiness report for results.

## Boundary and execution strategy

Unchanged P05/P11 cannot succeed under ordinary customer role creation while
requiring zero membership edges. The explicitly redesigned boundary permits
exactly one provider-granted ADMIN edge per reserved role to the Owner-controlled
`postgres` administrator, with SET and INHERIT false. No other permanent edge is
accepted. ADMIN remains powerful: it permits future grants; this is an explicit
trust-contract change requiring separate production approval, not preservation
of literal zero-edge assertions. Local implementation is authorized.

During a file's single transaction, customer postgres grants itself temporary
SET/INHERIT membership, ADMIN false, **GRANTED BY postgres**, using its existing
administration rights. It grants destination schema CREATE only as required:
data owner in private (and public only for P05's gym_settings transfer), API
executors in api. It then performs the source ownership changes, DDL, explicit
ACLs and FOR ROLE defaults with normal PostgreSQL ownership checks. No provider
identity is assumed, no new BYPASSRLS is granted, and no generic privileged
function/DDL endpoint is installed.

For direct legacy checks only, an uncommitted SELECT policy is added for the
exact Owner-operated postgres session/current role on these tables:

| Source stage | Temporary SELECT visibility |
| --- | --- |
| P06 audit timezone | private.audit_events, private.audit_chain_heads |
| P07 lifecycle | private.members, private.membership_purchases, private.payment_records, private.payment_allocations, private.payment_events |
| P13 receipt corrections | private.membership_purchases |
| P14 daily cash | private.cash_drawer_sessions |
| All others / ACL-only proposal | None |

FORCE RLS remains active. Restrictive policies that would undermine full visibility
cause refusal; no disabling or generic permissive runtime policy is used. The
policy checks both CURRENT_USER and SESSION_USER postgres, so definer executors
and application roles do not acquire this access. No write policy is added.
All maintenance policies, customer-granted memberships and destination CREATE
grants are removed before final acceptance/COMMIT. Inherited/effective capability
checks must prove closure, including no remaining SET/inheritance path.

All unexpected role attributes, grantors/members/options, stale maintenance
policies and at-rest schema CREATE cause refusal. New role creation and partial
transfers roll back on errors. Each file owns BEGIN/COMMIT; never nest the package
in a production rollback experiment or continue after failure. Locks/statement
bounds are 5s/120s for migration variants. Mutation traffic must be excluded in a
future separately approved production window. Temporary policy DDL adds locks;
quiet-window timing and real data volume remain unverified.

The original grant on provider-owned `extensions.digest(bytea,text)` is replaced
with a check of existing effective executor EXECUTE. It refuses if unavailable;
it does not attempt an unsupported grant or impersonate the provider. Customer
authority to grant schema USAGE must also be verified. The fixture supplies only
the schema-USAGE grant option and an already installed/public-executable pgcrypto
dependency; no customer ownership of provider routines is manufactured.

## Artifacts and immutable source

`scripts/recovery/build-compatibility.mjs` checks the original 37 SHA-256 values,
parses SQL with cached PG17 grammar, and emits two explicit profiles:

- `review/manifest.json`: provider `supabase_admin`; 19 SQL artifacts. Thirteen
  P05–P17 variants, scoped ACL proposal 01 variant, three assertion variants,
  effective-privilege screen and read-only authority diagnostic. This profile
  is prepared/parsed, not executed against Supabase.
- `synthetic/manifest.json`: provider `gf_provider_admin`; the same artifacts
  plus two synthetic-only tests (maintenance RLS proof and history-query fixture),
  21 SQL artifacts total. Only this profile is used by the local customer harness.

Each manifest records exact source/compatibility SHA-256 values, explicit graph
predicate counts and no history action. Each source migration's CREATE FUNCTION
AST is compared in full (signature, return/options/language/body), ignoring parser
positions and source CRLF/LF normalization only. Runtime SQL functions and business
rules stay identical. Seven role-graph predicates across P05/P07/P08/P10/P11 are
replaced with the documented exact-edge rule; no predicate inventory drift is
accepted. All other source metadata/business/data-integrity assertions remain.

The non-superuser harness checks artifact hashes before initialization and before
each customer artifact executes. Its stage catalogs identify the execution profile
and compatibility-manifest hash. Altered artifacts cause a stop, not adoption.

The source delta is forward-only: a fresh synthetic replay uses originals through
P04 (24 files), then the 13 compatibility variants in ascending version order.
The first 20 original files are **already recorded in production** and must not
be replayed there. Production needs exact baseline/partial-object reconciliation
before considering P01–P04 followed by these variants. A new migration appended
after a failing P05 cannot fix that prerequisite.

These artifacts are **not** original migrations under another history label.
No tool here inserts schema_migrations rows or declares a version applied. An
Owner-approved provenance/runner/history design is required before a production
recovery release: preserve original records, record the actual reviewed artifact
identity and acknowledge its source differences truthfully. No marking originals
as applied, hidden rewriting, blind skipping, copying variants over historical
files or blanket CLI db push is authorized. Lost acknowledgements require private
commit/object/history reconciliation and continued HOLD.

## Native profiles and local commands

```powershell
# Download only if no suitable archive was located; installation is portable.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/setup-native-pg17.ps1 -ArchivePath <existing-official-archive.zip>
# Alternatively, explicitly authorized acquisition from the published EDB link:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/setup-native-pg17.ps1 -DownloadOfficialArchive

node scripts/recovery/build-compatibility.mjs --synthetic
node scripts/recovery/build-compatibility.mjs
node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility -TestLegacyAuditRefusal
```

The setup script refuses an existing target; do not rerun acquisition/extraction
over the installed portable runtime. It writes only ignored workspace cache,
extracts bin/lib/share after ZIP path checks, records local SHA-256/provenance and
verifies 17.12. No Windows service, PATH change, Docker or paid resource is used.
The launcher selects that portable PG17 first, verifies major 17 and rejects PG18.

The unchanged suite runs as a real superuser engine control and reproduces the
original non-superuser refusals. Customer mode initializes another fresh cluster
with bootstrap `gf_provider_admin`, creates a real LOGIN/CREATEROLE postgres
customer with NOSUPERUSER/NOBYPASSRLS/NOINHERIT, and uses a separate SCRAM login
for every source/compatibility migration and ACL operation. Provider bootstrap
handles only Auth/schema/dependency fixtures; it does not execute the customer
migration DDL. Behavioral/race fixtures use the bootstrap to arrange synthetic
records and exercise the original restricted RPC execution identities.

Supabase documents that hosted postgres can have BYPASSRLS. The review profile
allows that **pre-existing operator attribute**, while never setting it or
relying on it; application executors must remain NOBYPASSRLS. The synthetic
profile rejects bypass and proves this design works without it. Provider roles,
schema/extension grant authority, existing inherited administrative access,
supautils behavior and CLI session identity still need hosted verification.
The native profile is not represented as a complete Supabase emulator.

The synthetic history fixture temporarily creates a model history table containing
the supplied 20 versions, runs the actual READ ONLY query, checks offline 20/17
classification and removes only that fixture. It is not migration-runner history,
proof that the 20 originals ran there, or a production mark-applied operation.
The legacy fixture similarly adds/removes only synthetic obsolete-table/view/
policy metadata to test the actual dependency query. Never use fixture SQL for
production cleanup. Every fresh cluster stops and deletes synthetic credential
files in finally; private ignored logs are retained for evidence.

## Hosted next steps (read-only only after separate approval)

Review `supabase/recovery/diagnostics/compatibility-authority.sql` alongside the
existing history/catalog/effective/legacy diagnostics. It returns one private JSON
result: actor flags, grantable schema access, digest dependency, four role states,
approved versus unexpected edge counts, missing ADMIN edges, effective schema
CREATE/SET/inheritance and maintenance-policy counts. It never grants anything.
Use the intended operator connection; SQL Editor cannot certify a different CLI
session. Existing `migration-authority.sql` and strict zero-edge screens retain
their original meanings and can legitimately disagree with the redesigned profile.

Full results remain Owner-private. Report sanitized check names/status/counts,
not credentials, raw role graphs, function bodies or business rows. The exact
project, complete baseline, three present marker identities, data blockers,
backup/restore and actual Auth/Edge/PostgREST acceptance remain NOT VERIFIED.
Production remains NO-GO pending all gates and separate change authorization.
