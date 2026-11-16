# Production pre-deployment verification — review package

Prepared 2026-11-11, Asia/Manila. Intended project: `alxhytivwybjbkjjdsyn`.
**SQL FOR OWNER REVIEW, NOT EXECUTED AGAINST PRODUCTION.** This package does not
authorize running it, applying migrations, deploying handlers or changing settings.

## Current conclusion

The supplied 20 migration versions match the first 20 of 37 local migrations.
Seventeen versions are unrecorded. Earlier public-only diagnostics found 14
required Edge endpoints returning gateway 404. Those are separate gaps: database
migrations create RPCs, not Edge deployments. See the existing
[stabilization report](../STABILIZATION-2026-11-11.md) for the exact migration and
endpoint lists. This package supersedes that report's request for migration
history: the 20 version numbers have now been supplied.

No production catalog output has been supplied yet. **Which unrecorded objects
already exist is UNKNOWN.** The supplied history does not establish object absence
or prove that recorded SQL bodies match local source. Existing plan endpoints
answered preflight despite their SQL migration being unrecorded; they could call
missing routines, older routines or manually created objects.

## Review and execution boundaries

- Seven complete SQL files below contain their own repeatable-read, read-only
  transactions and end with `ROLLBACK`. `SET LOCAL` changes only transaction-local
  timeouts/search path, and UTC serialization in the audit check. It does not
  change project configuration, RLS, grants, memberships or persisted settings.
- Use an Owner-controlled connection to this exact project. Metadata reads may
  be run through SQL Editor; migration authority must additionally be inspected
  through the actual intended migration connection. Those actors may differ.
- Run a complete reviewed file, not selected statements without its transaction
  guard. Prefer a client that captures every result set. If the SQL Editor shows
  only the final command's result, use an Owner-controlled client supporting
  multiple results; do not remove the read-only wrapper or assume editor sessions
  persist across separate runs.
- Stop on any permission, version, missing-object or timeout error. That check is
  **UNKNOWN**, not PASS. Do not grant access, change RLS, create objects, extend
  timeouts automatically or repair migration history to make a probe succeed.
- Files 05–07 read private records internally but return only named check outcomes.
  They are for the Owner, not routine Developer access. Share only sanitized
  PASS/FAIL/UNKNOWN outputs and metadata; keep data, credentials and raw logs local.
- No application RPC is invoked, including the existing audit verifier. The audit
  check uses built-in SHA-256 with the reviewed UTC serialization inline. The
  files do not print function bodies/hashes, policy expressions, defaults, PIN
  or token values, row IDs, audit details, financial amounts, member names or receipt data.
- Each file has its own consistent snapshot; different files are not one atomic
  snapshot. Passing checks must be revalidated in the future authorized maintenance
  window. Read-only aggregate scans can still consume resources and take ordinary
  read locks; timeouts bound them. No exclusive/advisory locks are requested.
- Do not run original migration files or existing mutation-based SQL tests as
  diagnostics, even inside a rollback. In particular,
  `supabase/tests/database_owner_migration_procedure.sql` changes test objects and
  memberships and belongs only in a disposable isolated environment.

## SQL inventory and interpretation

| Review file | Output and prerequisites |
| --- | --- |
| [01-catalog.sql](01-catalog.sql) | Connection role/version, migration versions, schema/routine ownership, exact routine signatures, effective/explicit/default privileges, RLS flags, policy metadata, columns, triggers, indexes and constraints. Catalog reads; no function source or policy expressions. |
| [02-unrecorded-object-markers.sql](02-unrecorded-object-markers.sql) | 91 declaration markers from the 17 pending files: routine names, new tables and selected added columns compared with migration history. Presence without history flags a review candidate; it does not establish application of that migration. |
| [03-hardening-screen.sql](03-hardening-screen.sql) | Compares the hardening migration's 25 baseline routine-body hashes/configurations/owners, execution metadata and 22 expected table column inventories. Also screens reserved roles, trigger/sequence/table counts, rewrite rules, unvalidated constraints and pgcrypto dependency. |
| [04-migration-authority.sql](04-migration-authority.sql) | Role attributes, existing reserved-role memberships, ability to SET ROLE, target-owner schema CREATE and current object ownership. It never executes SET ROLE, grants or ownership DDL. |
| [05-audit-blockers.sql](05-audit-blockers.sql) | Owner-only checks of stream keys, predecessor links, UTC hashes and chain heads, including orphan heads. Requires audit tables/columns verified in 01 and full SELECT visibility without RLS filtering. Only PASS/FAIL/UNKNOWN is returned. |
| [06-registration-and-plan-blockers.sql](06-registration-and-plan-blockers.sql) | Owner-only checks for inconsistent approval state, duplicate normalized plan names and legacy cash sessions. Requires baseline tables/columns and full visibility. No names, counts or financial values returned. |
| [07-lifecycle-payment-blockers.sql](07-lifecycle-payment-blockers.sql) | **Conditional:** exact lifecycle date/payment-basis checks and pending payment uniqueness checks. Requires `payment_records.operation_id` and `target_membership_purchase_id`, introduced by unrecorded migration `20261103120000`, plus all referenced tables/columns. If absent, skip and mark UNKNOWN; do not create them. |

For file 02:

- `ABSENT_WITHOUT_HISTORY`: a declared marker is absent. This supports a pending
  dependency finding, not a conclusion about every statement in that migration.
- `PRESENT_WITHOUT_HISTORY`: possibly a pre-existing older definition, shared
  object or manual drift. Review signatures in 01 and expected bodies in 03.
  Do not mark the migration applied or rerun it on this evidence alone.
- `RECORDED`: history records the version; definitions still need verification.
- The manifest is a source-declaration inventory, not an exhaustive schema diff.
  Dynamic SQL, policies, privileges, constraint expressions, index definitions,
  dropped objects and every default are not certified by these presence markers.

## Executor-hardening prerequisites

File 03 is deliberately labeled a **screening subset**. Its expected values were
copied from the first, pre-change assertion matrices in
`20261110100000_executor_hardening.sql`: 25 routines and 22 protected tables.
It checks the input after all four November 3 migrations, not just the currently
reported October baseline. Missing November objects will therefore FAIL that
future input screen; this is not by itself evidence of data corruption.

The complete migration also verifies exact privilege matrices, policy expressions,
constraint/index definitions, dependent object inventories, sequence bindings,
default privileges and extension dependencies. The catalog inventories support
private comparison, but a file-03 PASS does not certify all of those conditions or
authorize execution. Full faithful replay remains an isolated-environment gate.

Important prerequisites and stop conditions:

1. Four November 3 migrations precede hardening. Unexpected manual/partial objects
   must be reconciled by source comparison, not blind reapplication/history repair.
2. Baseline application tables/routines must have the expected `postgres`
   ownership, exact columns/body metadata and existing RLS. Application/browser
   roles must not have unreviewed direct table/column access.
3. Existing reserved roles must have the specified safe NOLOGIN/non-bypass
   attributes and no membership edges. Missing roles are created by the migration;
   creation authority and automatic memberships still need isolated verification.
4. `api` must contain routines only; the schema-usage/execution boundary must
   match source. Final-state FORCE RLS/executor ownership must not be confused
   with the different pre-hardening ownership baseline.
5. Exact table/trigger/sequence inventories and expected pgcrypto dependency must
   match. Source refusal is a stop, not an instruction to bypass a check.
6. The migration takes ACCESS EXCLUSIVE locks with 5-second lock and 120-second
   statement timeouts. Actual duration, concurrency effects and migration-runner
   failure/transaction behavior cannot be proven by these production reads.

## Audit and lifecycle blockers

The UTC migration refuses history that fails verification under UTC. File 05
recomputes the reviewed version-1 hash using PostgreSQL built-ins rather than
calling an unverified production function. It checks full stored history in one
snapshot without exposing event content or stream keys. No existing hash is
rehydrated, changed or deleted. A PASS means the stored chain matches this source
algorithm at that snapshot; it does not prove authenticity against an external
trusted anchor or certify every trigger/function currently installed.

Permission denial or RLS-filtered reads must not yield a false PASS. The aggregate
files check visibility; incomplete visibility produces UNKNOWN (or a permission
error, also UNKNOWN). The Owner must not share underlying failed records here.

Lifecycle source specifically refuses:

- Active registrations without approval, pending registrations with approval, or
  approval timestamps in the future.
- Active/expired purchase-state/date inconsistencies, wrong Option A inclusive
  expiry, and paid/active states without the required approval and exact confirmed
  allocated payment/event basis.

These are migration-precondition checks, not a complete correctness proof. File
07 cannot reference missing columns safely: its preconditions must be reviewed in
01 before running it. SQL CASE cannot make absent column references parse safely.
Missing prerequisites are UNKNOWN until an authorized later stage, not permission
to apply migrations now.

The cash-procedure migration additionally refuses **any legacy drawer session**.
A FAIL in file 06 requires a separate documented Owner procedure. Do not delete,
close, rewrite or reclassify drawer/receipt history to bypass this restriction.

## Hosted API exposed-schema inspection

In the intended project's Supabase Dashboard, open **API/Data API settings** and
inspect the **Exposed schemas** list without saving changes. Record only:

- Whether `api` is exposed.
- Whether `private` is excluded.
- Whether any other schema is exposed. The approved target is exactly `api`.
- Whether the Data API is enabled as required by the RPC architecture.

The local `supabase/config.toml` specifies `schemas = ["api"]`; it does not prove
hosted settings. A SQL Editor session's `current_setting('pgrst.db_schemas',true)`
or database/role defaults alone are not authoritative proof of the running hosted
PostgREST configuration. A later authorized runtime check must test the intended
RPC boundary after schema/deployment prerequisites are satisfied.

Do not copy the broad grants from generic custom-schema examples. Preserve this
project's service-only, bounded RPC execution and deny browser routine execution
and direct service-role application table access. Do not reveal any API keys.
See [Supabase custom schemas](https://supabase.com/docs/guides/api/using-custom-schemas).

## Migration-role compatibility method

1. Run file 04 using the **intended migration actor/connection**. Capture the
   effective role, server major version and prerequisite booleans. A successful
   SQL Editor query or `rolcreaterole = true` does not prove ownership-transfer
   authority. Keep connection credentials and provider session configuration private.
2. Standard PostgreSQL ownership changes require ownership authority over the
   object, the ability to SET ROLE to the new owner, and schema CREATE for that
   new owner, unless applicable superuser privileges bypass those rules.
   [ALTER FUNCTION](https://www.postgresql.org/docs/17/sql-alterfunction.html),
   [ALTER TABLE](https://www.postgresql.org/docs/17/sql-altertable.html).
3. **Structural compatibility risk:** the hardening migration rejects membership
   edges involving reserved roles and denies schema CREATE, yet performs transfers
   to those roles without a temporary membership/CREATE procedure. Under standard
   non-superuser rules these requirements conflict. Supabase's normal hosted
   `postgres` is not a full superuser; provider-specific capabilities cannot be
   assumed. [Supabase hosted roles](https://supabase.com/docs/guides/database/postgres/roles-superuser).
4. Read-only checks can expose missing prerequisites but cannot prove actual DDL
   authority, automatic role-creation membership behavior, provider exceptions or
   transaction atomicity. Mark real compatibility UNKNOWN until the exact path is
   demonstrated in an existing, separately authorized isolated environment.
5. In that future isolated test, use the same provider/PostgreSQL major version,
   extensions, migration actor and runner; synthetic records only. Reproduce the
   20-migration baseline, apply the four November 3 prerequisites, then exercise
   the exact hardening migration and subsequent migrations in order. Do not use a
   local superuser result to certify the hosted non-superuser path.
6. Exercise success and deliberate refusal cases, rollback boundaries, ownership,
   ACL/RLS invariants, leftover memberships and migration-history recording. If
   compatibility fails, prepare a separately reviewed solution; do not grant extra
   production privileges or weaken security to get past the error.

No environment is provisioned or mutation-based test executed in this phase.

## Checks requiring separate isolated testing

| Check | Why production read-only checks are insufficient |
| --- | --- |
| Role creation and actual ownership transfer | Requires DDL/privilege effects and provider/migration-runner behavior. |
| Exact migration replay/rollback/refusal atomicity | Includes schema, index, default and ownership changes. |
| Non-UTC audit refusal and legacy-state scenarios | Requires synthetic histories and controlled inconsistencies. |
| RLS/authorization negative tests using multiple actors | Catalog grants do not prove complete request-level authorization. |
| Payment, allocation, void, drawer and membership behavior | Creates/changes financial or entitlement state. |
| Concurrent daily check-in and idempotent receipt retries | Requires competing mutation requests and controlled clocks/data. |
| PIN setup/reset, KDF/load/shared-network/DoS limits | Requires synthetic credentials, capabilities and runtime load. |
| Edge/Auth/PostgREST business end-to-end acceptance | Must combine the actual runtime boundary with synthetic mutations. |
| Recovery drill | Must restore to an approved isolated target, not reset production. |

## Readiness at preparation time

PASS means the stated narrow check is evidenced, not overall readiness. FAIL means
an evidenced requirement is unmet. UNKNOWN means missing output, unrun test or
insufficient authority/evidence. Prior live HTTP observations are not new probes.

| Check | Status | Evidence / next requirement |
| --- | --- | --- |
| Intended project confirmed | PASS | Owner confirmation: `alxhytivwybjbkjjdsyn`. |
| Supplied 20 versions match local prefix | PASS | Compared with all 37 local migration files. |
| Production migration history matches full local release | FAIL | 17 local versions unrecorded. |
| Required Edge endpoint availability | FAIL | Earlier read-only live diagnostics found 14 gateway 404s; inventory must be refreshed before release. |
| Seven prepared SQL files parse | PASS | PostgreSQL 17 and 18 parser checks; no database connection. |
| Prepared statements structurally limited to read-only operations | PASS | AST check allows read-only SELECT, transaction-local settings and BEGIN READ ONLY / ROLLBACK only. |
| Which unrecorded database objects already exist | UNKNOWN | Requires reviewed file 02 output and definition comparison. |
| Production signatures/owners/ACL/default privileges/RLS | UNKNOWN | Requires file 01 output. |
| Complete hardening input assertions | UNKNOWN | File 03 is a screening subset; full isolated replay outstanding. |
| Actual migration-actor ownership compatibility | UNKNOWN | File 04 plus isolated proof; structural non-superuser risk identified. |
| Stored UTC audit-chain compatibility | UNKNOWN | File 05 not executed. |
| Registration/plan/legacy-cash blockers | UNKNOWN | File 06 not executed. |
| Lifecycle/payment prerequisites and consistency | UNKNOWN | File 07 conditional and not executed. |
| Hosted exposed schemas equal approved target | UNKNOWN | Owner Dashboard inspection outstanding. |
| Backup/restore acceptance and maintenance window | UNKNOWN | Owner evidence and isolated recovery drill required. |
| Hosted business/security end-to-end acceptance | UNKNOWN | Isolated synthetic runtime tests outstanding. |
| Production public/PIN release parameters accepted | UNKNOWN | Existing release gates remain closed unless separately approved. |
| No production mutation or deployment in this phase | PASS | Package preparation and static parser/AST review only. |

## Safest later deployment sequence — awaiting approval

1. Owner reviews this SQL package. Execute only approved read-only checks with the
   specified prerequisites; collect sanitized metadata and named outcomes.
2. Reconcile catalog/history discrepancies privately. Never replay already-recorded
   migrations, reset the database, rewrite audit hashes or mark versions applied
   merely because some objects exist.
3. Resolve the migration-authority risk and exact preconditions in a separately
   approved isolated environment. Complete synthetic security/business tests and
   Owner-controlled backup/recovery acceptance.
4. Present the exact migration plan and expected locks/data effects for explicit
   approval. In the future approved window, revalidate prerequisites, apply only
   the pending reviewed versions in ascending order with fail-fast checkpoints,
   and verify database ownership/RLS/ACL/audit invariants after each stage.
5. Obtain separate approval for hosted exposed-schema changes if required and for
   Edge deployment. Deploy reviewed handlers only once their full RPC prerequisites
   are satisfied; keep independent release switches at approved settings.
6. Publish the reviewed frontend through the existing authorized GitHub/Pages
   branch workflow. Verify SHA, headers, endpoint reachability and the complete
   runtime path; do not mix synthetic money/member tests into real production data.

**Current recommendation: remain at the review/metadata stage. No apply, repair,
deployment or privilege-changing command is authorized by this package.**
