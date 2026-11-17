# Local recovery tools - not a production apply package

## Final local hardening (2026-11-17)

Recovery parsers now use the explicit lock in `tools/recovery-parser/`, never an
implicit .cache parser installation. See that package's README for `npm.cmd ci`
and `node scripts/test-recovery-reproducibility.mjs` clean-room verification.
The SQL Editor validator uses the same loader; its 16 SQL files remain unchanged.
Earlier references to cached parser prerequisites below describe historical runs.

The PG17 recovery profiles now execute eleven real legacy migration refusal
cases at P01/P07/P13/P14. Each compares complete synthetic protected-row hashes
(including payment/member/audit data and any model migration-history relations)
and catalog fingerprints before/after the refused transaction. No production
rows are read. P13 uses a disposable, FORCE-RLS inherited fixture because the
current parent lifecycle trigger correctly forbids manufacturing dated review
rows; no existing trigger, constraint, permission or RLS flag is disabled. The
paid expiry fixture uses actual synthetic receipt/confirmation RPCs and retains
that history, correcting only its deliberately malformed pre-lifecycle term
after refusal. Other fixtures remove only their new synthetic objects/records.

`scripts/test-recovery-cleanup.ps1` verifies five controlled initialization
failure points. Credential creation now lives inside the harness's cleanup
boundary. `scripts/verify-native-pg17-archive.ps1` compares the ZIP with EDB's
separately published HTTPS SHA-256 before setup extracts or executes it;
`scripts/test-native-pg17-provenance.ps1` checks valid and mismatched archives.
No detached signature or resilience to abrupt OS/process death is asserted.
All hosted authority, ADMIN trust and production data/release gates stay held.

## Authorized PG17 authority redesign

The Owner subsequently authorized local-only A02 implementation and native PG17
testing. See [compatibility/README.md](compatibility/README.md) for the implemented
boundary, exact source/compatibility manifests and commands. Portable PG17.12 is
now available under ignored `.cache/pg17-portable-17.12/pgsql/bin`; the launcher
selects it without changing PG18, services or PATH. The earlier unavailable-PG17
results are historical, not the current runtime status.

`scripts/test-recovery-pg17.ps1 -CustomerCompatibility` uses an actual separate
non-superuser/NOBYPASSRLS customer login. Plain invocation remains the unchanged
superuser engine control. Strict zero-edge source assertions and redesigned
ADMIN-edge assertion variants are kept separate; no original assertion or
migration is overwritten. All hosted changes and history reconciliation remain
unapproved and production NO-GO. Original proposal 01 is still the strict
zero-edge version; the compatibility manifests identify its separate variant.

## Current readiness follow-up

See `docs/PRODUCTION-RECOVERY-FINAL-READINESS.md` for the latest status; prior
execution results below are historical. New review-only files:

- `history.sql`: version-only single-cell JSON. Run only after separate approval;
  compare privately with `node scripts/recovery/compare-history.mjs history.json`.
  Duplicate/unknown/gapped history fails; a contiguous prefix is not deployment
  readiness or proof of the applied bytes. Empty history is a valid empty prefix,
  reported as 37 unrecorded local files, never a production PASS.
- `diagnostics/migration-authority.sql`: single JSON cell with actor attributes
  and four reserved roles' SET/inheritance, membership and CREATE counts. Run
  through the intended migration connection; SQL Editor does not prove CLI
  identity. Missing roles are explicit. Catalog capability never proves that
  transfers/defaults/cleanup will succeed. Do not share the raw security grid.
- `diagnostics/legacy-dependencies.sql`: aggregate catalog dependency/policy/
  trigger counts for the source-confirmed superseded limiter table. Never drop
  the recreated rolling limiter RPC. Counts omit runtime/dynamic callers and
  do not establish that an object is unused. Unexpected objects require private
  full dependency review and separate approval, not automatic cleanup.
- `proposals/02-postgres-future-routine-defaults.sql`: MUTATING REVIEW PROPOSAL,
  not a read-only diagnostic and not production-authorized. Removes global and
  api/private schema future routine defaults for creator postgres. Its global
  scope affects other schemas/applications; assess impact before approval.
  Existing explicit grants survive. It cannot correct provider-owned creators
  or unknown inherited grants. Synthetic tests exercise replay, future denial
  and explicit grants. It does not solve A02's cross-role authority problem.

Additional offline validation:

```powershell
node scripts/recovery/validate-source.mjs
node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs
```

The latter uses already cached PG17/18 grammar packages; it installs nothing.
Missing parsers are a test prerequisite failure, not a reason to skip validation.
The synthetic harness now requires all ten final privilege statuses to PASS
after the review proposals. The new global client-default screen is additional
coverage beyond the earlier nine-screen result. A provider/default FAIL in an
actual project needs creator/scope/application exposure review, not an attempt
to revoke provider-owned defaults.

For SQL Editor, run each approved read-only file separately and retain its final
ROLLBACK. Each returns one result set. If the UI hides that result, use an
Owner-operated client that displays results and closes the same transaction;
do not omit transaction closure or split across SQL Editor sessions. Keep
results private and report only statuses/counts. History access can fail if
supabase_migrations or its table/version column is missing or not readable.
Legacy/effective screens require normal catalog visibility; missing roles can
make an inventory incomplete. These queries scan catalogs only, with 30-second
statement and 2-second lock timeouts; no application rows, function bodies or
policy expressions are returned by the new two diagnostics. Catalog reads can
wait behind DDL. Stop on error and ensure the same transaction is rolled back.

These files are outside `supabase/migrations` deliberately. No tool here connects
to production, applies a migration, marks history applied, adopts an existing
object, drops a conflicting object or submits a deployment. Hosted execution of
any SQL requires a separate Owner review of the exact bytes and authorization.
Previously approved preflight files are unchanged; scripts 03-07 remain held.

## Authority and test environments

Run the strict PG17 launcher from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1
```

It exits BLOCKED (2) before initialization when PG17 is unavailable or a different
major is selected. It accepts an installed binary directory, never a database
URL. It delegates to the existing harness, which creates a **new**, private,
synthetic loopback cluster, rejects inherited PG connection overrides, pins
database/run ID/data directory, uses SCRAM and stops the server in finally.
Synthetic password files are deleted. No existing test database is reused.

An explicit PG18 **engine control**, not PG17/hosted certification:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-database.ps1 -RecoveryAudit
```

The runner creates an actual LOGIN/CREATEROLE non-superuser test actor in the
new cluster. It attempts unchanged P05 and P11, expecting their membership
refusals, closes each failed connection and verifies its new role rolled back.
Only the P11 probe receives temporary private schema USAGE/attendance UPDATE
to reach its role guard past the table lock; both are revoked in finally.
These are fixture permissions on the synthetic migrator, not application grants.

In unchanged-control mode, the remaining replay runs as the cluster's trusted superuser so its
results cannot resolve A02. It captures 18 source-stage catalogs (baseline after
20 files and after each of 17 pending files) before phase fixtures, plus a final
post-test catalog. It runs existing behavior/financial/audit/race assertions,
new legacy conflict fixtures, ACL proposal replay, inherited-leak refusal and
final assertions. Refusal success is not successful non-superuser migration.

Additional incompatible-audit refusal control:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-database.ps1 -RecoveryAudit -TestLegacyAuditRefusal
```

This intentionally stops the sequence at the audit refusal and verifies original
hashes; it is not a full-release replay. Never wrap original migration files in
another rollback transaction to simulate a production dry run.

## Metadata reconciliation

`catalog.sql` returns one private JSON result of catalog-only reads, wrapped in
READ ONLY with timeouts and ROLLBACK. Definitions/configuration/ACLs are hashed
internally rather than returning bodies, defaults, policy expressions or trigger
arguments. Object names and visibility flags remain private security metadata.
Do not export the full JSON publicly or include it in Git. There are no business
records in this result and no password-catalog query.

The manifest pins all 37 original migration files, 21 Edge entrypoints and 17
recursively imported runtime shared modules. The added CORS module accounts for
the increase from the earlier audit's 16 shared modules. Those pinned migrations
and runtime modules remain unchanged. Stage reference catalogs must be built from these bytes in a trusted
isolated environment matching the actual PostgreSQL major/provider context.

Offline comparisons (paths below are placeholders for privately retained JSON):

```powershell
node scripts/recovery/compare-catalog.mjs reference.json observed.json
node scripts/recovery/plan-checks.mjs observed.json 20261110160000
node --test tests/recovery.test.mjs
```

The first command requires matching PG17 majors by default and verifies the
reference's 37-file source manifest. `--engine-control` permits an explicitly
labelled same-major control; it never accepts a PG18/PG17 comparison. Exit 0
means matching inventoried fingerprints only; exit 1 means differences; exit 2
means invalid input, missing provenance or unsupported major. Every outcome
retains production HOLD and unverified history/authority/data status. Errors do
not echo private inputs or keys. Reject duplicate keys and empty references.

Classifications are EXACT_METADATA (same fingerprint), ABSENT,
PRESENT_DIFFERENT and UNEXPECTED. Same name with changed signature, body,
ACL/owner, policy/constraint/index definition or column default is not an exact
match. EXACT_METADATA is deliberately **not** a claim that a migration ran or
that two complete databases are equivalent: fingerprints are checksums (SHA-256),
not authentication/signatures, and coverage is finite. Require trusted references,
private definition/dependency review and unchanged migration assertions. The
export does not capture the complete pg_depend graph, every provider object,
implicit defaults or all effective inherited privileges; effective screens and
business tests remain necessary. Do not use digest equality to waive a guard.

For the three present production marker occurrences, Owner must still privately
identify each version/signature/object and compare it with the correct stage.
No local fixture can identify these three. An exact reviewed object leads to a
reconciliation decision, not an automatic skip, IF NOT EXISTS rewrite or history
repair. Different/unexpected/unmarked objects halt. Interrupted/lost-ack states
are compared with both prior and next stage; mixed state remains HOLD. Reference
replay and offline comparison are repeatable; original migrations are not
thereby made idempotent. Stop before execution rather than suppressing duplicate
object errors after partial application.

## Legacy compatibility

`checks.json` declares every table/column required by the four diagnostic units.
The planner returns UNKNOWN unless all prerequisites exist and the catalog's
capturing actor had full SELECT with no active row filtering. READY_FOR_OWNER_REVIEW
means only that prerequisite screen passed, never that data are compatible or
that execution is approved. Use the same actor and a fresh, quiet-window snapshot;
permissions/schema changes between planning and execution invalidate the plan.
The optional explicit version is the intended next migration, not a claim about
applied history. Stage-bound checks without it are UNKNOWN; checks after their
applicable migration are NOT_APPLICABLE_TO_STAGE. In particular, a dated
payment_review term is a pre-P13 refusal condition but may be legitimate retained
history after a later payment void. Do not misread this precondition as a final
operational-health rule.

The audit, registration/plan/cash and lifecycle/payment units preserve the
earlier reviewed SQL text via separate copies. Their existing visibility guards
remain; missing privilege, column, table, timeout or parse failure is UNKNOWN.
Additional checks cover walk-in allocation uniqueness, dated review terms,
the P13 replacement overlap predicate and legacy NULL attendance/method bases.
Only status names and PASS/FAIL/UNKNOWN outcomes should be shared.

Do not scan application rows until the Owner has approved the diagnostic and its
full-visibility operator. The aggregate queries can take table AccessShare locks
and scan/sort large histories; 30s statement/2s lock limits apply. Originals and
fingerprints alone cannot measure production runtime. Audit hashing is pinned
to UTC and never mutates hashes or heads. SQL Editor result truncation is UNKNOWN.

No deterministic financial/member/audit **data** correction is provided: production
identities and conflicts are unavailable, and the reviewed cases require actual
approval/payment/receipt/evidence facts. Existing cash sessions cannot be deleted
or relabelled; duplicate receipt/allocation history cannot be deduplicated; old
NULL snapshots cannot be guessed; invalid chains cannot be rehashed; overlap or
approval/payment states cannot be rewritten merely to pass DDL. The reconciliation
disposition is Owner evidence review, separately approved forward design and
rehearsal, or continued HOLD. P04's generated operation IDs still require explicit
financial-table approval and lock/rewrite review. Do not blind-retry it.

## Effective privileges and scoped correction

`effective-privileges.sql` reads effective browser RPC/data privileges, server
direct-data paths, reserved role attributes/memberships, schema CREATE and future
default risks. It includes every explicit global/default creator and application
object owner plus postgres/current actor. It does not certify all provider ACLs,
unknown indirect security-definer paths or row policy meanings. Catalog fingerprints
also include explicit defaults/types, while final assertions verify actual RLS,
owners, routine configuration and denial paths. An empty diagnostic inventory
must not be treated as final-release acceptance.

`proposals/01-explicit-routine-acls.sql` is a transaction-owning **local proposal**:
it validates the final routine security boundary, removes existing PUBLIC/browser
EXECUTE and explicit schema-default additions, and refuses if browser EXECUTE
remains through inheritance. Replaying it is idempotent on an accepted final
stage. Service/executor allowlists and function bodies are preserved. It needs
the same unresolved hosted authority as the rest of the release; do not deploy it.

The proposal does not revoke global implicit PUBLIC function defaults from
postgres/other creators, remove unknown memberships or change unrelated future
function behavior. Schema-specific REVOKE cannot cancel global PUBLIC EXECUTE.
After proposal 01 alone, the screen reports that remaining global-default risk
as FAIL. The full current harness also tests proposal 02, after which all ten
screens must PASS. Production use of creator-wide defaults still needs Owner
approval and actual creator/inherited privilege evidence. Do not claim A03 is
hosted-verified from these synthetic results.

The SQL fixture suite injects a PUBLIC leak and verifies correction/replay, then
injects inherited access and verifies the proposal refuses transactionally.
Only the synthetic leak is explicitly cleaned up afterward, and unchanged final
security assertions run again. Production cleanup must never borrow those fixture
DROP/GRANT operations. Failed runs stop the cluster and retain private evidence.
