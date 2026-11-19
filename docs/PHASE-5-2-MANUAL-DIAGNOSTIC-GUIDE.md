# Phase 5.2 — manual metadata diagnostic execution guide

Prepared 2026-11-17. Branch `master`; intended project
`alxhytivwybjbkjjdsyn`. **PREPARATION ONLY. NOT EXECUTION AUTHORIZATION.**
Production remains NO-GO. No hosted connection or SQL execution occurred.
Only this guide was created; source SQL, existing hashes and approval forms are
unchanged. No application, migration, privilege, configuration, commit or deploy.

## 1. Client compatibility decision

**Supabase SQL Editor: BLOCKED for this session's execution approval.** The SQL
itself passes static review; the required client guarantees have not been
established. This is not a claim that all versions of SQL Editor are unsuitable.

| Requirement | Evidence / outcome |
| --- | --- |
| REPEATABLE READ READ ONLY | PASS in all eight unchanged sources; actual hosted/client execution UNKNOWN. |
| Local 30s statement / 2s lock timeouts; pg_catalog search path | PASS in all eight sources; do not remove or increase them. |
| Explicit final ROLLBACK | PASS in all eight sources; reliable execution/acknowledgement after failures UNKNOWN. |
| One diagnostic result per unit | PASS locally: one SELECT per unit. Six return a single JSON cell (1, 2, 3, 20, 23, 25); unit 19 returns 91 rows; unit 22 returns ten rows. |
| Complete JSON/grid visibility after ROLLBACK | UNKNOWN for the actual hosted Editor. Prior Owner evidence showed only the final SELECT from the original multi-result inventory. Splitting avoids that particular multi-SELECT problem, but does not establish complete large JSON or rollback visibility. |
| Same-session error/cancellation cleanup | UNKNOWN. A later Run click or new tab cannot be assumed to reach the previous backend. |
| Approved target, actor, evidence controls and execution window | Not yet confirmed for this eight-unit session. |

The documentation reviewed does not establish an end-to-end guarantee for this
project's current Editor result retention, cancellation and transaction cleanup.
Do not test those assumptions against production under this preparation task.
If an already-authorized isolated target/client qualification exists, the Owner
may reference it privately; otherwise qualification needs its own approval.
Do not provision an environment, install software or broaden SQL scope implicitly.

PostgreSQL transaction failure and client cleanup are separate matters. Supabase
documents that cancellation can leave a connection open, and an aborted
transaction still needs rollback. Closing an Editor browser tab is not proof of
database session closure. See [Supabase connection management](https://supabase.com/docs/guides/database/connection-management).
Do not introduce pg_cancel_backend/pg_terminate_backend SQL into this eight-unit
authorization; emergency backend intervention needs its own narrowly scoped authority.

### Safest supported alternative

Use an existing Owner-controlled PostgreSQL 17 `psql` client with an approved TLS
direct connection, or shared **session-mode** pooler if direct connectivity is
unavailable. Supabase documents both access paths and psql with certificate
verification: [connection options](https://supabase.com/docs/guides/database/connecting-to-postgres),
[connecting with psql](https://supabase.com/docs/guides/database/psql).
This recommendation does not approve any connection or new client installation.
No paid IPv4 add-on is required merely to choose the documented session-pooler path.
Do not guess hostnames or use transaction-pooling for this session-control procedure.

Use one noninteractive psql process per approved unit, in order, with `-X`,
`ON_ERROR_STOP=1`, pager disabled and `-f` for that unit only. `-X` avoids startup
scripts; error-stop exits a noninteractive script on error. A normal successful
run must show its result, final ROLLBACK and zero exit status. No `--single-transaction`,
extra BEGIN, pipeline of units or SQL echo flags. See [PostgreSQL 17 psql](https://www.postgresql.org/docs/17/app-psql.html).

Illustrative command syntax ONLY, not executed or approved:

```powershell
# Owner privately supplies an already-approved libpq service profile.
# That profile must pin target, existing identity and TLS verification without role overrides.
& '<approved-psql.exe>' -X --dbname='service=<approved-private-profile>' -v ON_ERROR_STOP=1 -P pager=off -f '<one-reviewed-unit-file>'
# Immediately inspect $LASTEXITCODE locally; anything other than 0 stops the sequence.
```

No password belongs in arguments, reports or Git. Obtain connection settings
privately from the intended project's Connect panel. Keep service/credential
files outside the repository under Owner-controlled access. Do not use
passwordless CLI flows that create temporary database identities. H01 must
verify actual session/effective identity; a pooler login string alone does not.

H01/H02 are embedded blocks, not existing standalone SQL files. For a later
approved psql run, the Owner must transfer their exact block text to a private
execution buffer/file, preserving their LF-plus-final-LF hash contract and
verifying it before use. That is a verbatim transport copy, not regenerated SQL;
if this copy is not explicitly covered and verified, stop. No SQL copies were
created in this task. Never hash the Markdown fences or the entire plan instead.

On a batch error, psql error-stop ends that process; do not assume the trailing
ROLLBACK was reached. Confirm connection termination/cleanup rather than
reporting explicit rollback success. If using interactive psql instead, Ctrl+C
only cancels the query: issue ROLLBACK in that same known connection, observe
acknowledgement, then close it. If cleanup cannot be confirmed after a network
failure, mark UNKNOWN and stop; do not reconnect just to send ROLLBACK to a new
backend. Connection termination semantics are described by
[PostgreSQL protocol termination](https://www.postgresql.org/docs/17/protocol-flow.html#PROTOCOL-FLOW-TERMINATION).

## 2. Unchanged scope, order and hash contracts

Fresh local verification: eight of eight SHA-256 matches against the existing
reviewed plan and form; eight of eight pass static PG17 and PG18 safety screens.
No database SQL was executed and no completed regression suite was repeated.
All are D-META; every other unit, especially D-DATA and preflight 03–07, is excluded.

| Order | Exact source | Expected SHA-256 |
| --- | --- | --- |
| 1 | H01 SQL block under section 3 of `docs/HOSTED-READINESS-DIAGNOSTIC-PLAN.md` | `7f6aea263b9d7305bd60554e398dd607e426c80774bd92875975429e468804be` |
| 2 | `supabase/recovery/history.sql` | `38195ddb8a3f01b8d8a8b65b1560b04c3e2d78fb086a77f782fd7f957ad6ebe9` |
| 3 | `supabase/recovery/catalog.sql` | `8e564aa33500db90e52c9582a669699348489908656fe4cc5f7298a0acee4eef` |
| 19 | `docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql` | `71bca850a5ddb76ffbb15ab32a28c2bcca86209fa107bd5cbd00f5f82a14ba76` |
| 20 | `supabase/recovery/diagnostics/compatibility-authority.sql` | `7ef743624536dc44098e1341c49426868b3338f1c5879d97fe7e25c662ab2cc2` |
| 22 | `supabase/recovery/effective-privileges.sql` | `43bfad19d3a7b3b2dc41c87d0414c89e025a27c09190fd659442c1465f7febad` |
| 23 | H02 SQL block under section 3 of `docs/HOSTED-READINESS-DIAGNOSTIC-PLAN.md` | `ee124d5d1cc5a28cd846982c7de029aa75e104096c9e42cc6d80f39746f6fa5c` |
| 25 | `supabase/recovery/diagnostics/legacy-dependencies.sql` | `a8b352b01cf27de47424a0396f4aeee71173244862cac1c727d132036f8ed19f` |

Six file hashes cover exact bytes, including existing line endings. H01/H02 use
only SQL inside their fences, LF line endings and one final LF. No SQL, timeout,
search path, BEGIN or ROLLBACK may be edited to fit a client. Hash a prepared
execution copy before connection; copy/paste appearance is not byte verification.

## 3. Shared manual procedure — conditional on new approval and client qualification

These instructions are a reviewable procedure, **not permission to click Run**.

1. Complete section 6. Verify authorization and client qualification without SQL
   first. If SQL Editor safeguards remain unproven, stop that route and approve
   the existing psql alternative explicitly. Do not start unit 1 as an unapproved
   client experiment.
2. Privately confirm Dashboard project ref `alxhytivwybjbkjjdsyn`, intended
   primary database and approved Owner access path. Do not rely on project display
   name or an IDE environment value. Check client role/connection settings against
   the approval. Never share connection strings or keys.
3. Recheck that unit's hash, source stage and prerequisites. Open only that full
   existing file/block. In a qualified SQL Editor, use a separate unshared query
   tab and the approved database/role context; ensure the run buffer is exactly
   the hashed unit and Run sends the whole unit. No highlighted partial SELECT,
   auto-rewrite/limit injection, AI rewrite or combined batch. If client behavior
   cannot be established, stop rather than changing the SQL.
4. Execute only after the separate approval and pre-flight permit it. Retain all
   wrapper statements. Record start/end UTC and Manila times, unit/hash, client,
   stage and private evidence reference. Each unit has one SELECT result; the
   final command is ROLLBACK, not an extra status SELECT.
5. Verify the complete expected result described in section 4 and the client's
   successful final ROLLBACK acknowledgement/known closed transaction. Parse large
   JSON only in Owner-private approved storage; inspect complete arrays, not
   abbreviated previews. If the Editor cannot show the result and completion
   evidence together, mark UNKNOWN, stop, and seek approval for another client.
6. On error/cancel/timeout/missing or truncated output, stop immediately. No
   automatic retry. Close/roll back the original known session under the approved
   cleanup procedure. Do not infer closure from a later Run, refresh or closed tab.
7. Continue to the next named unit only after technical completion is confirmed
   and the prerequisite outcome permits it. Results come from separate snapshots;
   do not claim a single atomic inventory across all eight executions.

These are metadata queries, not application-data scans. They still use database
resources and catalog/read locks; large definition hashing and membership graphs
can time out or conflict with DDL. The 30s bound is per statement, not a guaranteed
total client wall time. Do not raise either timeout to complete a result.

## 4. Per-unit prerequisites, expected outputs and stop rules

Every entry uses steps 1–7 above **separately** and its unchanged wrapper. For
each, completion requires the entire SELECT result plus confirmed final ROLLBACK
or a documented failure followed by verified original-connection termination.
Failure cleanup is not diagnostic success. No result count alone proves rollback.

### Unit 1 — H01 identity/context

- Source/hash: order 1 in section 2.
- Prerequisites: privately confirmed project/client; approved existing operator.
- Expected: one row, `context` JSON with serverVersion/serverVersionNum, readOnly,
  observedAtUtc, sessionIsPostgres, effectiveIsPostgres, sameSessionRole, actorFlags
  and context-only decision. Expect PG major 17, readOnly=on and the approved role
  booleans true for this authority path. Actual CREATEROLE/BYPASS/super flags are
  evidence, not permission to change them or proof of hosted DDL capability.
- Stop: wrong project, actor, PG major, read-only flag, null/incomplete context or
  any shared technical stop. Do not continue authority certification under another
  identity. Retain final ROLLBACK and its acknowledgement; do not append a PID query.

### Unit 2 — migration history

- Source/hash: order 2 in section 2.
- Prerequisites: unit 1 accepted; readable
  `supabase_migrations.schema_migrations(version)`.
- Expected: one row, `history={format:1,versions:[...]}`, sorted string versions.
  Supplied historical evidence was 20 versions through 20261030180000; this is a
  comparison reference, not an assumed current result. A recorded version does
  not prove the applied SQL bytes.
- Stop: denied/missing history, incomplete JSON, duplicates, unknown/gapped or
  unexpectedly changed history. Preserve the result privately; no history repair.
  Complete final ROLLBACK as above before any next approved unit.

### Unit 3 — catalog fingerprints

- Source/hash: order 3 in section 2.
- Prerequisites: accepted stage/context; readable PG17 catalogs and available
  builtin SHA-256. No new grant is permitted for inspection.
- Expected: one row, `private_catalog` JSON, format=1,
  fingerprintAlgorithm=sha256, serverMajor=17 and complete `objects` array.
  Elements include key/fingerprint/readable/filtered. Count is not predefined;
  a 22-table historical inventory is not proof of the 33-table final release.
  Definitions and expressions are hashed internally, not returned in plaintext.
- Stop: wrong format/major, missing or truncated objects, duplicate/malformed
  entries, unavailable catalogs/functions or unexplainable visibility. Missing
  objects are reconciliation evidence, not permission to apply anything. Final
  ROLLBACK/completeness acknowledgement is mandatory even for an empty inventory;
  empty does not certify the intended stage.

### Unit 19 — unrecorded-object markers

- Source/hash: order 19 in section 2.
- Prerequisites: readable history and normal catalogs; accepted context/stage.
- Expected: **91 rows**, columns version, kind, object_name, column_name,
  history_recorded, object_present, observation. There are 79 distinct markers
  across 15 pending versions; P05/P06 have no declaration markers here.
  Preserve all actual present-without-history tuple identities privately. The
  old 88-absent/3-present count is not assumed still true.
- Stop: not all 91 rows accessible, missing columns/flags or disagreement with the
  accepted history. Unexpected observations halt automatic reconciliation for
  Owner review. Function-name presence does not establish signatures or definitions.
  Verify final ROLLBACK; keep the grid private, sharing only approved classifications.

### Unit 20 — revised authority prerequisites

- Source/hash: order 20 in section 2.
- Prerequisites: PG17 catalogs, approved existing postgres session/effective role;
  preceding context/history/catalog accepted.
- Expected: one `compatibility` JSON with serverMajor/readOnly/actorMatches/actor,
  schemaGrantAuthority, digestDependency, reservedPresent, unsafeReservedAttributes,
  approvedProviderEdges, unexpectedEdges, reservedSchemaCreatePaths,
  missingProviderEdges, operatorSetOrInheritPaths, maintenancePolicies and
  decision=NOT_HOSTED_COMPATIBILITY_PROOF.
- Stop: identity/version/readOnly mismatch or unexpected unsafe role/edge/CREATE/
  maintenance state. Reserved roles or dependencies absent before hardening can
  be expected stage evidence: mark authority UNKNOWN and do not certify future
  creation/transfer/cleanup. Null privilege results are not affirmative permission.
  Full JSON and final ROLLBACK required; no grant/revoke test or RPC invocation.

### Unit 22 — effective-privilege screen, original strict contract

- Source/hash: order 22 in section 2.
- Prerequisites: appropriate PG17 catalog visibility and established stage; record
  missing roles instead of treating empty scans as a release PASS.
- Expected: **ten rows**, exactly `check_name,result`; named screens cover effective
  browser routine/direct data permissions, reserved edges/attributes/presence,
  schema CREATE and creator global/schema/nonfunction default exposure.
- Stop: fewer/missing/truncated rows, SQL error or unexplained privilege finding.
  At the baseline some FAILs may be expected; flag them for stage-specific review
  and pause dependent certification rather than changing privileges. This original
  screen rejects all reserved membership edges, including the revised design's
  provider ADMIN exception. It cannot certify that revised contract by itself.
  Full grid and final ROLLBACK are required. A successful SQL call with FAIL rows
  means successful evidence collection, not security acceptance.

### Unit 23 — H02 inherited/default/definer metadata

- Source/hash: order 23 in section 2.
- Prerequisites: PG17 catalogs, existing-context confirmation and permission to
  retain the full confidential metadata JSON. Recursion uses UNION deduplication.
- Expected: one `security` JSON with requiredRoles, creators,
  reachableMemberships, defaultAcl, routines and private-review decision.
  Routine entries include signatures, owner/config flags and SECURITY DEFINER;
  no function body or policy expression is returned. Unknown names are anonymized
  with linking OIDs; these remain sensitive metadata.
- Stop: incomplete large JSON, missing required-role evidence, unexpected definer/
  search-path/creator/grantee paths or unexplained privilege discrepancy. Missing
  stage-specific roles keep the associated conclusion UNKNOWN. Reachability does
  not mean effective SET/INHERIT, and default absence is not an automatic deny.
  Retain full JSON privately and verify final ROLLBACK, not just displayed rows.

### Unit 25 — legacy PIN-limiter dependencies

- Source/hash: order 25 in section 2.
- Prerequisites: accepted stage/context and readable dependency catalogs.
- Expected: one `legacy_inventory` JSON array of **three** entries for the
  superseded aggregate limiter table, required rolling event table and required
  rolling limiter RPC. Old-table entry includes dependency/policy/trigger counts.
- Stop: incomplete inventory, missing required rolling objects or an old table
  requiring review. Zero dependencies do not establish no dynamic/external users.
  This is only the selected limiter path, not a complete legacy-finance dependency
  audit. Retain final ROLLBACK; no object removal is authorized.

## 5. Scope suitability and remaining questions

This subset is suitable to establish initial context/stage, identify current
marker tuples and collect authority/ACL/definer/default and selected dependency
metadata. It does not establish a safe migration plan from names/counts alone.

- A02: observes actual role/edge/authority prerequisites; cannot prove hosted
  CREATE ROLE, ALTER OWNER, temporary membership/grant/revoke, failure rollback
  or supported provider behavior. ADMIN trust adoption remains an Owner decision.
- A03: exposes effective-risk screens and private creator/default/inherited/definer
  metadata; cannot prove live runtime RLS, policy business correctness or every
  nonfunction implicit default. No corrective permission changes authorized.
- A07: captures history, markers and exact-stage object fingerprints; cannot prove
  applied file bytes, migration compatibility or truthful artifact/history adoption.
  Fingerprints require a trusted same-stage reference and private interpretation.
- A04 real finance/member/attendance/audit-chain scans are excluded entirely.
  No D-DATA check, additional SELECT or mutating compatibility probe is implied.

## 6. Proposed Owner authorization — incomplete and unchecked

| Field | Owner confirmation needed |
| --- | --- |
| Approval reference and Owner name | REQUIRES OWNER CONFIRMATION |
| Exact target | Intended `alxhytivwybjbkjjdsyn`; confirm actual Dashboard/connection project and primary database privately |
| Scope/order/hashes | Confirm only 1 → 2 → 3 → 19 → 20 → 22 → 23 → 25 as pinned in section 2 |
| Existing execution identity | Operator and expected session/effective database roles; authority route requires actual postgres for both |
| Verified execution client | SQL Editor requested but BLOCKED pending qualification; record evidence reference or explicitly approve the existing psql direct/session alternative |
| Date and Asia/Manila window | Date, start and end; record UTC equivalents privately |
| Evidence custodian/restricted storage | Named custodian, private encrypted/access-controlled location reference; no secret path details required in public reports |
| Authorized viewers | Named people/roles; no automatic Developer/team/public access |
| Retention and secure disposal | Duration/start/expiry, preservation holds, disposal owner/method, copies/query-history/provider-retention limitations |
| Sanitized reporting | Approved recipient/channel and allowed identifiers/counts/categories; accept section 7 restrictions |
| Rollback/cancellation responsibility | Named operator, qualified same-session procedure and connection/transaction closure evidence; narrowly scoped escalation route if closure cannot be confirmed |
| Prerequisite acceptance | Target/identity/hash/stage/catalog visibility, complete results and client safeguards; missing prerequisites mean stop/UNKNOWN |
| Safety/stop conditions | Accept all shared and per-unit rules, unchanged wrappers and no automatic retry |
| Backup/quiet-window prerequisite | Owner decides applicability to this metadata scope; no capture, restore or maintenance change authorized by this guide |
| Owner decision and approval time | [ ] APPROVE COMPLETED SCOPE / [ ] HOLD — no choice preselected |

No credentials/signature/time window/viewer/retention choice is inferred or filled
on the Owner's behalf. The manual-client preference does not constitute execution
authorization. After a complete explicit decision, verify authorization and
perform the no-SQL pre-flight; execution is a later instructed step under that
valid scope, never an automatic result of producing this guide.

## 7. Evidence custody and compact sanitized response

Keep full JSON/grids and client messages Owner-private. Do not upload screenshots,
raw exports or database catalogs to chat/Git. Definitions are hashed internally by
unit 3, but hashes, OIDs, signatures, owners, roles/defaults and object identifiers
still disclose security structure. Sanitized summaries must not include tokens,
PINs/verifiers, credentials, personal/financial records, bodies, policy expressions,
raw exceptions, connection strings or unrestricted role graphs.

Copy only this summary structure, filled with approved non-sensitive outcomes:

```text
Approval reference: <non-sensitive reference>
Target/actor/client match: PASS | FAIL | UNKNOWN
Execution window: <Asia/Manila and UTC>
Unit: 1 | 2 | 3 | 19 | 20 | 22 | 23 | 25
Reviewed hash matches: YES | NO
Prerequisites/catalog visibility: PASS | FAIL | UNKNOWN
Query outcome: COMPLETED | ERROR | TIMEOUT | CANCELLED | NOT RUN
Result complete: YES | NO | UNKNOWN
Expected structure/row count: MATCH | MISMATCH | UNKNOWN
Finding: PASS | FAIL | UNKNOWN; <approved narrow category/count>
Closure: ROLLBACK ACKNOWLEDGED | CONNECTION TERMINATION VERIFIED | UNKNOWN
Evidence custody/retention: <private reference only>
Stop condition encountered: NONE | <sanitized category/SQLSTATE>
```

For unit 19, share only approved source tuple identifiers and classifications if
explicitly permitted; do not infer identities of the historical three from counts.
For unit 22, share named status rows without raw grant metadata. Never claim A02,
A03/A07 or production GO merely because queries completed. Missing/truncated
results and unconfirmed closure are UNKNOWN and block continuation.

**Prepared for Owner review; not ready for hosted execution approval while client
qualification and section 6 decisions remain incomplete. Stop here.**
