# Controlled local pilot preparation — November 6, 2026

**NOT READY for pilot execution approval. No database connection was made.**
All safe preparation/review portions are complete. The executable SQL candidate
is deliberately limited to a **catalogue-only rollback pilot**. A database client,
original-baseline recovery verifier, business fixture runner and full concurrent
pilot were **not** prepared: recovery evidence, isolation choice and side-effect
authorization remain unresolved. The offline wrapper always refuses `-Execute`.
This follows the requested boundary to stop executable portions that require an
unresolved decision, while completing unaffected offline work.

## Exact identity, roles and scope

| Property | Required value; never inferred from a connection string alone |
|---|---|
| Database / endpoint | `gymforce_pg18_test`, `127.0.0.1:55432` |
| Cluster marker | `f497fabb-a12f-4068-b745-8b0729279276` |
| System identifier | `7704603813616068820` |
| Canonical data directory | `C:\Users\Banco-Sual\AppData\Local\GYMFORCE-PG18-TEST\data` |
| Server / execution identity | Native PG18, current_user = session_user = postgres, superuser required |
| Future client | Fresh connection, protected identity/ACL/pgpass preflight, `-X -w -v ON_ERROR_STOP=1`, required SCRAM, no PG* environment overrides |

The SQL checks these identities inside the transaction before any DDL/default
changes. Missing values use IS DISTINCT FROM and refuse. It additionally requires
exact approved revision, backup verification and maintenance-attestation session
settings; unset settings refuse. These settings are **not** proof of a backup or
Owner consent: a trusted future client must validate external evidence first.
A malicious superuser can forge them; this protects against accidental targets,
not a hostile administrator. No client that sets them is implemented here.

Only postgres executes the catalogue candidate. It does not SET ROLE or create
roles, modify role attributes/memberships, set credentials or enable logins.
The seven existing roles remain the original restricted roles. Intended runtime
entrypoints remain service_role -> narrow SECURITY DEFINER executors, with no
browser direct protected-table access. No runtime-role behavior was tested.

[candidate-manifest.json](candidate-manifest.json) enumerates the source-defined
affected names and exact source/candidate hashes:

- 22 tables: proposed ownership, FORCE RLS and exact table/column ACLs.
- 25 application routines: proposed owners, invoker/definer modes and execution
  ACLs; bodies remain unchanged and fingerprint-checked.
- Three identity sequences: implicit parent ownership and restricted ACLs;
  **no nextval/setval or fixture DML**, zero advancement budget.
- 34 named command/role policies; 57 dependent indexes and 44 row/array types.
- Schema ACLs for private/public/api/extensions, and the existing
  `extensions.digest(bytea,text)` EXECUTE grant to gym_owner_executor only.
  Its implementation/owner/version and schema owners are unchanged.
- Five current-database future-function default revocations, one each for
  postgres, gym_data_owner, gym_owner_executor, gym_public_executor and
  gym_registration_login. They precede the foundation preconditions and leave
  existing RPC/extension function ACLs unchanged except the already documented
  explicit grants in the foundation proposal.

Implicit TOAST auxiliary ownership effects require an exact future read-only
catalogue inventory. Their actual names cannot be established offline and were
**not guessed**. This is an additional pre-execution inventory item. No new table,
routine body, role, login, membership, database or extension is proposed.

## Existing database versus isolated clone

The existing disposable database is a **conditional target for catalogue-only
testing**, after recovery proof, fresh identity/baseline checks and an enforced
Owner-controlled maintenance window. No business fixtures or sequence calls are
included, so it avoids known nontransactional fixture consumption. The candidate
refuses other existing client backends, but that single check cannot prevent a
new connection after it runs. The Owner must control quiescence for the entire
window; no server configuration or ALLOW_CONNECTIONS change is authorized.

**Use separately approved isolation for full executor/concurrency acceptance.**
Committed proposed DDL/fixtures are necessary for independent sessions to see
the same changed state. A single-session rollback pilot cannot establish that.
Sequence consumption and immutable/audit fixture recovery also need an explicit
budget. Prefer a separately approved logical clone/restore for those tests; do
not run them on the preserved database by broadening this candidate.

No clone was created or named. A clone target requires its own approved exact
database/identity-bound artifact and baseline; current hardcoded guards must
reject it. No generic host/database override or copied identity-file workaround
is supplied. Any shared cluster roles must remain unchanged. Hosted Supabase
is excluded from both stages and cannot match the native canonical-path guards.

## Recovery procedure and incomplete guarantees

Before execution the Owner must supply:

1. A fresh, protected PG18 custom-format **database-only** backup of this exact
   verified target, with protected storage, checksum, timestamp and exact source
   identity. Capture only allowlisted non-secret role attributes/memberships and
   database/default/schema/object ACL metadata needed for recovery. Database
   dumps do not preserve cluster roles; do not use a general pg_dumpall/credential
   export. Do not put backup contents, role password verifiers or pgpass in Git.
2. Independent restoration evidence tied to that backup checksum and compatible
   tool/extension versions. Restoring into any disposable target needs separate
   creation/restore approval; none is authorized now. An archive listing or a
   successful checksum alone is not a tested recovery procedure.
3. A protected before-state of canonical schema/owner/RLS/ACL/defaults, membership
   and exact sequence state/cache configuration, plus an exact read-only
   after-state verifier. Original implicit function defaults must be compared
   directly after rollback: the hardened current-profile assertions cannot
   substitute for that original baseline.
4. An approved failure contact/window, recovery point and preservation policy.
   On unexpected failure stop, close the client to abort the transaction, retain
   sanitized evidence and report rollback **unconfirmed** until fresh identity-
   verified read-only checks succeed. Never automatically restore, repair,
   change ownership/membership, reset sequences, drop/recreate or run cleanup.sql.

Owner-supervised future backup steps: first strict identity/SCRAM preflight;
then use the installed PG18 `pg_dump` with custom format, no password prompt,
explicit loopback endpoint/user/database and a new protected path outside Git;
check its native exit; compute the file checksum; review with matching pg_restore
tools; perform a **separately approved** isolated restore drill and record its
verification results. No backup or restore command was executed or embedded in
an automatic runner. Exact storage location, recovery time/point and restore
target are unresolved Owner decisions; no overwrite or retention defaults were
chosen. This is a recovery plan, not evidence that a backup exists.

`approval.example.json` is deliberately unapproved. The offline verifier can
check an Owner-declared scope/window (at most one hour), exact revision, nonempty
regular backup/proof files and their SHA256 values. It cannot establish actual
restore success, protected ACLs, parent reparse-point safety, absence of races
or authentic Owner consent from JSON. Those deficiencies are why no execution
client was prepared. Completed approval, backup evidence and local observations
belong outside Git; `local/` and `*.local.json` are ignored.

Logical DDL/default/ACL changes should roll back under the single transaction;
server execution has **not** verified that. Sequence nextval/setval, client/server
logs, WAL, statistics, cache invalidations and experienced lock waits do not have
byte-for-byte rollback guarantees. No sequence functions or DML occur in this
candidate, but its zero-advancement requirement still needs before/after proof.
Failure after a hidden/intermediate COMMIT would invalidate rollback; independent
static checks reject any such boundary or changed payload. No recovery promise
is inferred merely from a terminal ROLLBACK or a successful process exit.

## Candidate construction and failure handling

`LOCAL-TEST-ONLY.catalogue-pilot.sql` is outside active migrations. It contains:

1. One BEGIN, local search path/timeouts and a strict identity/approval/maintenance
   gate. No eligible row or credential data is exported.
2. The exact original default proposal payload, then the exact foundation payload,
   including every precondition/postcondition and the aligned security contract.
3. One terminal ROLLBACK; no COMMIT, standalone scenario DML or runtime RPC call.

Only the two proposals' outer BEGINs, unconditional draft blockers and final
COMMITs were removed **in this separate copy**. All original blocked drafts are
unchanged and independently hash-checked. This copying is preparation authorized
by the current request, not authorization to submit SQL to PostgreSQL.

`prepare-pilot.mjs` only writes source-derived files. `check-pilot.mjs` is a
separate verifier that parses whole SQL and all procedural statements, checks
exact original payload order/digests and independently specifies the entire new
gate. It rejects unexpected mutations/grants, missing guards and transaction
boundaries. Existing aligned assertions remain fail-closed; they are not relaxed
to certify the original post-rollback default state.

`review-pilot.ps1` is an **offline review wrapper only**; `-Execute` exits 2
without a database command. It propagates the child native exit exactly. In
synthetic result validation an assertion/client failure of 3 stays 3; incomplete
rollback, identity or unexpected mutation evidence exits 2. These are result-
oracle tests, not an implemented psql runner. A future fresh-connection client
must enforce ON_ERROR_STOP=1, sanitize diagnostics, stop on any unexpected result
and require actual after-state/sequence verification before reporting success.

## Every executor scenario

[scenario-checklist.json](scenario-checklist.json) binds all 16 IDs to the
existing scenario-source hash and retains every expected result/step, with
explicit per-case identity, fixture, role, recovery and sequence/isolation
preconditions and pass/fail criteria. **All remain NOT EXECUTED and outside the
catalogue candidate.** RLS/role/sequence ACL metadata is checked by the candidate;
that is not runtime enforcement evidence. Nested RPC, trigger firing, row locks,
internal failure atomicity, role-assumption simulation and concurrency remain
untested. No scenario may be silently skipped and reported as a complete PASS.

## Offline safety validation — actual results

- Candidate: **323 SQL statements, 12/12 procedural bodies** parsed using the
  pinned PG18.4 grammar; PG17.7 SQL also passes. PG17 procedural API unavailable.
  Neither parser proves runtime resolution on PG18.6 or hosted compatibility.
- **23/23 new negative subprocesses refused**, positive artifact control exited
  0. Wrong database/host/port/marker/system ID/path/role, missing backup, failed
  assertion, incomplete rollback, unexpected schema/sequence/fixture state,
  embedded/final COMMIT, unexpected grant and bypassed guard were covered.
  Windows wrapper tests preserve exits 3/2 and refuse -Execute with exit 2.
- These negatives mutate **filesystem fixtures or synthetic outcome records**.
  They do not prove that SQL guards reject real connections or that PostgreSQL
  performed rollback. Local test output is ignored, not a committed observation.
- Existing offline suite: 40 parser/definition/text-cast tests, 31 original and
  11 aligned negative subprocesses, nine default classifications, static checks,
  definition gate, executor scenario design and security configuration checks
  passed. All 24 active migration/four protected-source hashes passed.
- Existing 38 Deno tests, lint, typecheck and build/PWA passed. No
  database/client/backup/restore test was run.

Offline-only commands (they do not install dependencies or execute SQL):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/drafts/foundation-2026-11-06/controlled-pilot/review-pilot.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
node docs/drafts/foundation-2026-11-06/controlled-pilot/test-pilot-negative.mjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

## Files and Git boundary

Added this directory's SQL candidate, source manifest/spec, unapproved example,
preparer, independent verifier, offline PowerShell wrapper, negative tests and
source-derived scenario checklist/generator. Added scoped .gitignore entries;
inherited edits remain preserved. Original SQL drafts/contracts/manifests,
24 active migrations, bootstrap/active assertions, application/UI and package
dependencies are unchanged. New candidate sources/manifests, tests and docs are
suitable for a future **reviewed scoped** commit. Exclude local approvals,
observations, parser/test output, backups, .cache, dist, pgpass/identity files,
logs and unrelated existing work. No staging/commit/push occurred.

## Exact remaining decision and approval

**NOT READY for pilot execution approval.** First resolve protected backup/restore
evidence and original-baseline/sequence verification design, exact auxiliary
inventory, maintenance enforcement, and whether the Owner selects the existing
database's catalogue-only stage or an isolated full-acceptance target. No
execution client is supplied until those decisions can be implemented safely.

After that review, execution requires explicit Owner approval of the exact
candidate/source hashes and revision, native target, affected object list
(including extension ACL and implicit dependencies), maintenance window,
restorable backup/recovery plan, zero-sequence/no-fixture catalogue scope and
verification procedure. Full executor fixtures, any nonzero sequence advances,
clone provisioning/restoration and committed concurrent testing require a
separate, exact approval. No hosted release, Attendance work or production
deployment follows. GitHub/Cloudflare does not deploy SQL or Edge Functions.
