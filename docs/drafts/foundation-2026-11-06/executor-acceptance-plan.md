# Future isolated executor acceptance plan — NOT AUTHORIZED TO RUN

This is a review plan, not a runner or approval to create fixtures, clone/reset
databases, change privileges or apply SQL. Current identity guards permit only
the existing approved native cluster/database. No other target is authorized.

## Preconditions and revision gate

The [definition follow-up](semantic-alignment/README.md) resolves the 52/14
comparisons. The accelerated review integrates those candidates in a separate
aligned contract and corrects both unparenthesized CASE defects. All 17 draft
procedural bodies now pass the pinned PG18 parser without rewriting/extraction
shortcuts. PG17 remains SQL-grammar-only; native runtime is still unverified.
Review the five-function-default
proposal and exact owners/columns/policies/function call graph. Owner explicitly
approves the exact revisions, native test target, maintenance window, fixture
scope, failure injection, any committed DDL and non-transactional side effects.
No hosted deployment or Developer access to live records follows from this.

Fresh protected marker/system-ID/data-directory/endpoint/database/postgres/SCRAM
preflight is mandatory. Verify PG_VERSION, seven restricted role attributes,
zero memberships, original migration/source hashes and current catalog/default
ACL baseline. Stop on drift. No PG* overrides, password prompts, credential logs
or system execution-policy changes. A future separately reviewed client must
use -X -w -v ON_ERROR_STOP=1 and propagate every native failure.

Owner controls protected backup and recovery evidence for database schema,
synthetic data, default/object ACLs and relevant cluster-role metadata. Verify
restore feasibility before the window; do not take a general catalog/credential
dump or run restores without separate approval. Do not reset/reapply old
migrations, DROP OWNED, execute cleanup.sql or manufacture a fresh database.

## Transaction and isolation hazards to resolve first

**Do not wrap the present draft files in an outer BEGIN/ROLLBACK.** They contain
their own BEGIN/COMMIT; an embedded COMMIT would defeat the outer rollback.
After approval, review a specifically promoted single-session rollback test
revision with exactly one transaction boundary, no internal COMMIT and intact
identity/security preconditions. Removing draft blockers is itself a promoted
revision action requiring approval. No such executable revision was built here.

Table/function/default-ACL DDL and fixture DML can roll back, but identity
sequences may advance even when the transaction aborts. A rollback therefore
does **not** prove byte-for-byte database preservation. Explicitly authorize and
measure bounded advances or select a separately approved isolation/recovery
arrangement; never auto-reset sequences with setval or assume gaps are errors.

Concurrent sessions cannot see uncommitted ownership/grant/policy changes from
the rollback test session. Multi-session acceptance needs an explicitly approved
committed isolated fixture state and recovery plan. A new/restored target, if
chosen, needs separate creation/identity authorization and reviewed exact guards;
never broaden or disable the existing guards. Until that is approved, concurrency
acceptance is blocked. No test below has been run in this task.

## Acceptance matrix

The concrete synthetic fixture definitions and 16 scenarios are in
`executor-acceptance-fixtures.json` (two per category). They are declarative,
have `autorun: false`, require collision checks and never reuse existing rows.
`check-executor-fixtures.mjs` validates their design only. No executable runner,
provisioning SQL or live fixture was created. All tests below remain NOT RUN.

| Path / invariant | Future synthetic test | Required evidence |
|---|---|---|
| Restricted identities | Trusted administrator uses controlled SET LOCAL ROLE probes only after identity verification. Browser/service/registration roles cannot assume executors or modify protected objects. | No LOGIN/BYPASSRLS/CREATE/role membership added; exact ACL matrix and denial SQLSTATEs, no sensitive outputs |
| Owner registration/plan/purchase | service_role invokes each allowlisted API with verified synthetic Owner actor; null/non-Owner/inactive actor fails. Pending member cannot purchase. | Existing Owner-only contract preserved; no approval/activation date invented by the harness |
| Nested audit chain | Owner RPC -> Owner executor definer -> invoker audit trigger -> invoker hash helper -> exact digest dependency. PIN enrollment public executor -> narrow audit append definer -> Owner executor trigger path. | Correct effective identities, audit append/head chain atomicity, immutable history; no public direct audit/table privilege |
| Trigger behavior | Exercise all 13 enabled triggers through intended operations and forbidden synthetic history mutations. | Immutable receipt/audit history, confirmed-payment allocation guard, no trigger bypass; no new trigger/rule remains |
| Payment confirmation | Owner records full-price synthetic receipt, confirms once, allocates once, reaches pending_activation with no dates. Duplicate, mismatched operation and non-Owner cases fail. | No unpaid access or activation feature smuggled in; audit/payment/purchase changes all commit or all roll back |
| Row locking | Member FOR UPDATE for purchase/token/enrollment; plan FOR SHARE; purchase/payment FOR KEY SHARE/FOR UPDATE; audit-head locks. | Minimum UPDATE column grants and matching UPDATE/SELECT RLS policies suffice; status/approved_at/activation/expiry fields remain denied |
| RLS and columns | Probe exact proposed column grants as each restricted executor; deny browser/service direct tables, credentials hash SELECT, protected-table DELETE, sequence direct access and schema CREATE. FORCE RLS also restricts data owner normal access. | Every allowed operation covered by exact named role/command policy; denied rows/writes do not silently count as success |
| Identities/sequences | Insert only approved synthetic audit/payment/rate events through APIs with no executor sequence USAGE grants. | Identity defaults work; no direct nextval/setval privilege, bounded non-transactional advances accounted for |
| PIN enrollment | Valid synthetic enrollment token and existing secure hash format; expired/consumed/replayed tokens fail and existing verifier cannot be replaced. | Credential insert/token consume/audit are atomic; no plaintext PIN/hash/token/PII output. This is not future check-in PIN verification |
| Failure rollback | Separately approved controlled failure after an operation starts, especially nested audit/trigger failure; expect nonzero client exit. | No partial business DML/DDL/default changes survive transaction; sequence caveat documented; don't weaken RLS or disable guards to induce success |
| Concurrency | In approved committed isolated state, race token redemption, duplicate receipt operations/confirmation, plan edits versus purchase snapshot, rate reservation and same audit stream. | One valid result or documented retry; no double allocation/redemption, deadlock handling reviewed; deterministic audit chain. Not certified by a single-session rollback test |
| Timezone/audit hashing | Synthetic audit append/verify under controlled UTC and Asia/Manila sessions. | Confirm timestamp serialization/hash stability; existing IMMUTABLE declaration alone is not proof |
| Defaults | Per creator, future routine default EXECUTE owner-only; explicit service/nested-call grants supplied atomically by creation migrations. | Existing API/extension ACLs unchanged; unmodified built-in type USAGE accepted only by its narrow exception |

No Manager/Front Desk, cancellation, refunds, free membership, checkout, public
member login or Attendance feature scenario is an initial-release acceptance
requirement. Supabase Auth, API gateway/JWT injection and Edge behavior need
separate hosted/staging approval; native Auth shim tests do not certify them.

## Completion criteria and failure handling

1. Every exact postcondition passes; all intended operations work using only
   proposed capabilities and every negative operation returns the expected
   failure. No skipped/obsolete profile is presented as full acceptance.
2. Compare protected baseline and post-test schema/ACL/role/fixture metadata;
   record permitted sequence changes separately. Preserve all failure evidence
   without records, tokens, PIN material, raw definitions or credential settings.
3. On any unexpected result: stop, close/rollback connections, preserve evidence
   and invoke the separately approved recovery procedure. No automatic schema,
   role, ownership, database or sequence repair. Committed-state rollback needs
   explicit Owner review; inverse default changes do not rewrite later objects.
4. Owner reviews actual results and outstanding lifecycle gaps before authorizing
   any next development phase. Hosted SQL/Edge release and GitHub/Cloudflare
   release are separate approvals. Attendance remains unimplemented.

## Controlled execution checklist — future approval required

1. Review the exact current draft/statement hashes, corrected CASE conditions,
   aligned catalog contract, full manifest and all fixture scenarios. Select
   a target and maintenance window with exclusive change control. Confirm a
   protected, restorable backup and Owner-controlled recovery; no automatic
   repair/reset or restoration is authorized by this document.
2. Define an Owner-approved bounded sequence budget for the three identities,
   accounting for cache size, connection endings, failed inserts and rollbacks.
   Store only boolean/bounded synthetic evidence; do not log records or hashes.
   Fixture UUID collisions, unexpected role/schema/data state or identity drift
   are refusal conditions; do not pick a different live row to continue.
3. Separately promote a test-only revision with exactly one BEGIN and a final
   ROLLBACK, retaining identity/role/source preconditions. Both current proposal
   files contain their own COMMIT. Do not concatenate them or rely on an outer
   rollback. Keep the repository drafts blocked; no promoted copy exists yet.
4. Verify fresh strict marker/system identifier/canonical directory/DB/endpoint/
   postgres/SCRAM identity before opening any future write transaction. Use
   -X -w -v ON_ERROR_STOP=1, bounded lock/statement timeouts and explicit native
   exit propagation. Test setup credentials stay outside source/output.
5. In the approved transaction, apply the **five future-function default
   revocations first**, check their exact postconditions, then the ownership/
   executor draft's current profile, DDL and proposed profile. This order is
   essential: its current profile already demands owner-only function defaults.
   No intermediate COMMIT. Each creator is independent; no schema-only revoke
   substitutes for global defaults. Five commands change future current-database
   objects only; they do not revoke existing nested/server RPC grants. The
   existing-object ACL regression check is still mandatory.
6. Run N/T/L/I/E cases using effective executor contexts, not postgres bypass.
   SET LOCAL ROLE from a postgres-authenticated session **cannot prove SET ROLE
   refusal**: role assumption checks session_user. E1 instead specifies a
   separately approved SET SESSION AUTHORIZATION simulation with both identities
   asserted. Its original superuser reset capability remains; it is SQL privilege
   simulation, not evidence of browser/native login isolation. Do not set a
   registration password, change LOGIN attributes or grant membership to test it.
7. Expected privilege exceptions must match SQLSTATE 42501; known Owner/evidence
   failures use their source codes. A denied row operation may instead return
   zero rows under RLS: assert affected-row count, not just lack of exception.
   Separate expected-refusal invocations from unexpected failures. A psql SQL
   refusal is exit 3, connection refusal exit 2; wrappers must propagate both.
8. B1 injects a division-by-zero **after** successful real RPC DML and checks
   complete savepoint/transaction rollback. It does not prove internal RPC
   exception handling. A safe natural nested-trigger failure reproducer remains
   a separate test-design item; do not disable guards, alter function bodies or
   create bypass objects to manufacture it. Unexpected real nested failures are
   preserved as failures with fixture-scoped atomicity evidence.
9. End the approved single-session pilot with ROLLBACK even after success; verify
   original ownership/ACL/RLS/defaults/schema and synthetic-row absence from a
   fresh connection. Record approved sequence changes separately and stop if
   bounds fail. Current-profile preconditions that require hardened defaults
   cannot stand in for the original pre-test baseline after rollback; compare
   the actual original implicit-default booleans separately.
10. C1/C2 require **additional committed-isolation approval** and recovery design.
    Session B cannot see session A's uncommitted new schema/ACLs. A new/restored
    database or committed DDL is not authorized here. Barriers and timeouts must
    replace timing guesses; test two users/sessions under the proposed roles.
    Never claim concurrency PASS from the rollback pilot.

Hosted Supabase is a separate deployment/review target: the global postgres
future-function revoke can affect provider/extension-created objects. Native
success does not establish hosted privileges, Auth/JWT behavior or PG17 runtime
compatibility. GitHub/Cloudflare release deploys neither SQL nor Edge Functions.
