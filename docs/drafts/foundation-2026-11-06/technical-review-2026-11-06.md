# Foundation draft technical review — November 6, 2026

## Latest accelerated three-phase review

[Accelerated review](accelerated-review/README.md) resolves the procedural
refusal: unparenthesized CASE expressions in two IF forms ended at the wrong
THEN. The corrected eight assertion DO blocks parse fully, all 17 bodies checked
individually and in complete files. The source-preserving aligned contract now
drives 110 constraint, 149 column and 28 explicit-index/40 key checks. R3/R5
offline syntax and definition-integration gaps are corrected; restricted runtime
capability proof is still pending. No grants/policies/ownership instructions or
default-proposal statements changed. All execution blockers remain intact.

Added 11 aligned/security negatives and nine malformed-procedural negative
subprocesses; existing 31 refusals remain. Sixteen declarative executor scenarios
and a controlled checklist cover all eight requested categories. Safe promotion,
backup/sequence/isolation approval and actual native executor acceptance remain
blockers. PG17 procedural and hosted behavior are not certified.
**NOT READY for controlled local execution.** No database connection/mutation or
hosted access occurred in this offline run.

## Previous definition-alignment follow-up (historical)

See [semantic-alignment/README.md](semantic-alignment/README.md) and its
per-object classification.json. All 66 prior definition mismatches are resolved:
51 CHECKs, one exclusion and 14 explicit indexes. Complete candidate comparisons
cover all 28 explicit indexes; independent metadata matches all 40 index keys.
The exclusion's default-opclass omission is backed by exact opclass/operator OID
checks. Earlier failed comparisons are retained, with explicit supersession.

R3's catalog-definition evidence gap is resolved. Integrating those proven
candidates into unchanged SQL draft contracts/assertions remains blocked work.
All three blocked SQL drafts parse using the installed PG18.4/PG17.7 grammars.
Dedicated PG18 PL/pgSQL parsing refuses ownership/assertion drafts with syntax
error at end of input; cause is unresolved, not dismissed as a binding issue.
This is an execution blocker. PG17 PL/pgSQL/runtime and restricted-executor
behavior remain unverified. The five default statements are still unexecuted.
No SQL draft, original migration, database or hosted state was changed.
**NOT READY for controlled local execution approval.**

## Previous pre-execution review (historical)

See [pre-execution-security-review.md](pre-execution-security-review.md) and
[executor-acceptance-plan.md](executor-acceptance-plan.md). Twelve new guarded
read-only boolean queries passed after fresh protected identity/SCRAM preflight.
All 25 routine identities/types/results/security properties and source body
fingerprints match; 149 column defaults/generated expressions and 25 routine
default lists align after confirmed narrow text casts. All 13 triggers and
58 PK/UNIQUE/FK definitions match. CHECK/exclusion definitions (52) and 14 of
28 explicit indexes remain unresolved; false text comparisons are not hidden.

R3 remains blocked by those definitions; R5 signature/default alignment now has
safe boolean evidence, but proposed restricted execution remains untested.
Offline parser options were investigated, not installed or run. The plan flags
embedded COMMITs, non-transactional sequence advances and multi-session visibility
as execution-design blockers. No SQL draft/active migration was changed.
**NOT READY for controlled local execution approval.**

## Default-privilege cause investigation — current decision

[default-privilege-proposal.md](default-privilege-proposal.md) supersedes older
R2 interpretations below. Fresh protected identity/SCRAM preflight and two
additional narrow read-only queries passed, exit 0. All ten flags equal built-in
PUBLIC function EXECUTE/type USAGE, with no explicit global/schema default ACL
entries, direct browser default grants or other/escalated grants. These are not
inherited creator defaults and are not proof of a current browser data leak.
Fresh browser counts: zero executable/reachable scoped routines and directly
privileged protected tables for anon/authenticated.

R2: the type branch's blanket non-owner rejection was overbroad. Drafts now
accept only unchanged implicit PUBLIC type USAGE without grant option. Explicit
grants/additive entries still refuse. Five function-default target failures
remain. A separate blocked proposal contains exactly five current-database
ALTER DEFAULT PRIVILEGES revocations; it has not run. Existing service-only
RPC grants and object ACLs are preserved. All original 31 refusal fixtures
still reject; nine new classification tests cover the narrow exception.

Review status: R1/R4 structural checks remain satisfied in prior observations;
R2 root cause resolved, correction unexecuted; R3/R5 deparser/signature alignment
unresolved; R6 parser evidence absent; R7 future runner unimplemented; R8 executor
acceptance/runtime tests pending; R9 identity runtime behavior untested; R10
hosted compatibility unresolved. **NOT READY for local execution review.**
No active migration/assertion/bootstrap change or database mutation occurred.

## Minimal permitted catalog follow-up — latest evidence

See [minimal-catalog/README.md](minimal-catalog/README.md) and its structural
observations/findings. Protected identity/SCRAM preflight passed again. Nine
individually reviewed read-only structural queries were accepted, all exit 0;
none of the narrowed queries was rejected. The earlier three rejected broad
exports produced no snapshot and were replaced, not retried unchanged.

Current names/flags match: 22 tables, three sequences, 110 constraints, 57
valid/ready indexes, 149 columns, 25 routines and 13 enabled user triggers.
No table/column grants exist across 154 checked harness-role combinations.
No rewrite rules or reserved-role membership edges were observed. Current
postgres ownership and FORCE-disabled RLS remain the known hardening gap.

R2 is now an **observed blocker**: all five creator roles have non-owner global
default grants for functions and types (ten flags). No grant recipients,
credentials or raw ACL arrays were exported. No default privileges changed.
R3/R5 remain **partially verified**: structural properties match, including 11
harmless numeric type-spacing differences, but raw expression/default/function
argument/body exports are prohibited. Definition/deparser equivalence cannot
be claimed from these observations. All draft execution blockers remain intact.
Verdict: **NOT READY for local execution review**.

This follow-up updates only draft inspection sources, offline comparison tools,
safe structural observation files and documentation. Both executable SQL drafts,
their contracts/manifests and active migrations/assertions remain unchanged.
The older follow-ups below retain their original time-specific statements
about no connections and are superseded only by the permitted evidence here.

## Corrected-draft follow-up — current status

**NOT READY for isolated local application.** The sections below this addendum
are the preserved original review, not the current file hashes or correction
status. This follow-up changed draft SQL and offline files only. No PostgreSQL
connection, catalog query, migration/DO execution, hosted access, role/ownership/
grant change or application/UI change occurred. All 24 active migrations and
the four protected historical harness sources retain their original hashes.

### High findings

| Finding | Current correction and offline evidence | Remaining risk / required verification | Blocks application? |
|---|---|---|---|
| R1 exposed routines — **corrected for native scope** | New guard rejects every public/graphql_public function or procedure. Expected native inventory is explicitly empty; no application routine is expected there. All 25 private/api routines additionally have structured argument/result/language/strictness/volatility/parallel/cost/rows/leakproof/support/transform/extension metadata expectations, plus the existing owner/definer/search_path/ACL/body pins. Schema CREATE grants and private/api ownership are checked. Unexpected function and procedure fixtures exit 1. | No hosted provider exception is allowed. The documented pg_graphql candidate is NOT a verified allowlist entry: hosted profile remains unsupported until exact version, signature, result, owner, ACL, execution mode, configuration and provenance are independently reviewed. Native catalog behavior remains untested. | Not an outstanding source-coverage blocker; hosted/runtime verification still blocked. |
| R2 defaults — **guard restored; live safety unresolved** | Each of five creator roles is checked independently for tables, sequences, functions and types. Effective global ACL includes acldefault when no explicit row exists; additive defaults are checked separately in private/api/public/graphql_public. Every non-owner default grant refuses, including PUBLIC and browser/executor/service roles. Fixtures for postgres function defaults and a different creator's type defaults exit 1. No ALTER DEFAULT PRIVILEGES was added. | PostgreSQL's implicit PUBLIC function EXECUTE/type USAGE may fail these preconditions, especially for dormant roles without hardened creator defaults. Existing defaults have NOT been read or declared safe. A separate reviewed default-privilege correction proposal may be necessary; never bypass the check. | **Yes**, live precondition unknown; no privilege repair authorized/executed. |
| R3 schema — **coverage strengthened; alignment unresolved** | Source contract enumerates 22 PK, six UNIQUE, 30 FK, 51 CHECK and one exclusion constraint (110 total), every column's type/default/NOT NULL/identity/generated state, 28 explicit indexes and all 57 index dependencies. Definitions, FK actions, predicates, key order and exclusion operator classes are compared, not counts alone. PostgreSQL 18 NOT NULL constraint rows are handled through attnotnull; constraint-backed index validity/primary/unique/exclusion/immediacy and unexpected indexes are checked. Separate PK/FK/CHECK/UNIQUE/exclusion, default, nullability, identity/generated and index fixtures exit 1. | **Strict source lexical definitions are not a certified catalog baseline.** PostgreSQL deparses IN as ANY/arrays, inserts type casts in text/NULL defaults and may render TRIM as btrim. Those differences can reject an unchanged healthy schema. The tokenizer preserves literals, casts, parentheses and operators rather than deleting security-relevant syntax. Authoritative version-specific catalog/deparser alignment remains required; do not loosen normalization or claim a passing DB result. | **Yes**, this High finding is not fully closed. |

The source extractor is a limited lexer for the SHA-256-pinned existing
migrations, not a PostgreSQL parser or a migration execution simulator. Its
supported table/column/ALTER forms are explicit; unsupported forms it processes
throw. Original-source hashes prevent unreviewed new grammar from being treated
as the same baseline. Implicit constraint naming and exact server deparsing
remain review points. No unverified catalog values were fabricated.

### Medium and Low findings

| Finding | Current status / evidence | Remaining risk and required verification | Blocks application? |
|---|---|---|---|
| R4 unexpected triggers/rules — **corrected in draft** | Exact count plus existing checks for all 13 distinct user trigger definitions/enabled states rejects extras/replacements; table rewrite rules are denied. Extra/disabled-trigger fixtures exit 1. Internal constraint triggers are excluded from the user-trigger count and are governed by constraint checks. | Later verify real trigger order, invocation identity and rejection/rollback behavior. | Runtime verification outstanding. |
| R5 routine metadata — **strengthened, not catalog-certified** | Full input/output type/mode/name/default/result checks, language, kind, strictness, set return, volatility, parallel mode, leakproof, support, variadic, transform, cost/rows, probin/prosqlbody and extension membership accompany existing owner/body/config/ACL checks. Result/language/mode/search_path fixtures exit 1. | Source-to-deparser default/result formatting needs alignment with R3; real NULL handling and nested execution still need authorized testing. | **Yes**, alignment/runtime evidence missing. |
| R6 static checker — **strengthened offline** | Independent structured comparator rebuilds expectations from original source and compares candidate fields exactly. Frozen statement inventory checks every complete top-level SQL statement, including DO bodies, so extra grants and modified policies are rejected. Generated hardening blocks must match source-derived expectations in all four locations. SQL-edit fixtures exit 1. | Frozen reference updates are explicit review operations, never automatic during checks. The lexer/checker is not a SQL/PLpgSQL parser. A coordinated edit to trusted code/reference files is a code-review concern, not an adversarial tamper-proof boundary. | **Yes**, parser/semantic evidence remains absent. |
| R7 process exits — **offline validators corrected; SQL runner unresolved** | validate-offline.ps1 checks every native child exit, catches failures and exits 1. Real checker subprocesses returned 1 for each refusal; positive control and suite return 0. A failing intermediate validation run also propagated exit 1, then its diagnostic-code mismatch was corrected. | No promoted SQL runner exists. Future separately approved native execution must use psql -X -w -v ON_ERROR_STOP=1 and propagate LASTEXITCODE after protected identity preflight. SQL files remain pure blocked drafts; they do not themselves force a psql process exit. No actual psql refusal test was run. | **Yes**, before executable promotion. |
| R8 executor capabilities — **reviewed, unresolved acceptance** | The 34 command/role policies, 16 server-only entrypoints and zero memberships are preserved. No UPDATE(status/approved_at/activation_date/expiry_date) or browser table grant was introduced. Escalation/policy/membership fixtures exit 1. | members.updated_at UPDATE remains necessary for current row locks; public executor still calls generic audit append. Separate design acceptance plus actor/token/concurrency/atomicity tests remain required. | **Yes**. |
| R9 unnecessary sequence grants — **removed from draft** | All three executor sequence USAGE grants removed. Manifest and pre/post assertions now deny every non-owner sequence privilege. Source has GENERATED ALWAYS identities and no nextval/currval/lastval/setval calls; original review cites PostgreSQL 17/18 identity implementation. Sequence escalation fixture exits 1. Ownership/bindings are preserved. | Verify actual identity insert behavior under restricted executors later; do not silently restore sequence grants on failure. | No independent source blocker; runtime dependency check remains. |
| R10 hosted compatibility — **unresolved, contained** | Native guard and unsupported-hosted fixture refuse. No Supabase-managed ownership/ACL changes or provider exceptions added. | Separate Owner-controlled hosted inventory, procedure, review and deployment approval. | No for native-only design; **yes for hosted**. |

### Offline checks and actual results

- Draft static checker and exact structured/statement comparator: PASS, exit 0.
- Independent negative suite: **31 refusal subprocesses, each exit 1 for its
  expected diagnostic**; unmodified positive control exit 0. The suite exits
  0 only when every expected refusal is observed.
- Existing security configuration checks: PASS, exit 0.
- Existing cached Deno shared tests: **38 passed, 0 failed**, exit 0.
- Original migrations: **24/24 SHA-256 matches**; protected harness/assertions:
  four matches. All 25 function bodies are checked against original source.
- npm.cmd run lint and npm.cmd run typecheck: PASS, exit 0.
- npm.cmd run build: PASS, exit 0, including PWA generation. Generated dist
  artifacts remain ignored and are not staged or included as draft changes.
- SQL/PLpgSQL parse/compile, catalog alignment, live defaults, identity/SCRAM,
  RLS/RPC/trigger/concurrency behavior: **NOT RUN**. No DB preservation or live
  environment claim is inferred from repository hashes or offline fixtures.

Run the filesystem-only chain from the project root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/drafts/foundation-2026-11-06/validate-offline.ps1
if ($LASTEXITCODE -ne 0) { throw 'Offline validation failed.' }
```

It never calls PostgreSQL or runs Deno/network commands. Deno was run separately
with the existing cached-only command below, its two named environment
permissions and no database/network permission. Process-scoped execution policy
Bypass does not change system policy. Temporary negative files contain only
synthetic metadata/SQL text; they are deleted individually without recursive
directory deletion. The fixtures exercise the real checker as child processes;
they are not database fixtures and do not execute any candidate SQL.

The source generator and SQL renderer are maintenance tools, **not validators**.
Normal checks do not regenerate schema-contract.json, rewrite SQL or refresh
statement-manifest.json. Their --write / --freeze-statements-after-review
operations require a deliberate draft edit and review; never refresh a baseline
to silence a test failure. This is still not SQL parser evidence.

Changed existing draft files: both SQL drafts, object-manifest.json (sequence
runtime privileges only), static-review.ps1, README.md and this review. Added:
source-contract.mjs, schema-contract.json, render-hardening.mjs,
statement-manifest.json, check-offline.mjs, offline-negative-fixtures.json,
test-offline-negative.mjs and validate-offline.ps1. dependent-objects.json and
all original migrations/bootstrap/assertions/runners remain unchanged.

Next review must resolve R3/R5 catalog alignment, assess the live-default
precondition via a separately authorized read-only inventory, obtain parser
evidence and define/approve the isolated runtime test plan and fail-fast runner.
Do not promote or apply this draft as a shortcut to obtaining those results.

Current corrected SQL SHA-256 values (the original snapshot hashes below are
historical): migration `303b4bac77c4df426a6a58e319d9621d793e173318fce51b4608966991fb61c4`;
assertions `bb8ed915dd05c4f95591bc4ac136940b871d3486bf75002cf4640da581e91f9e`.
The source-derived explicit plus constraint-backed index names/parents are
also compared with all 57 original dependent-index records.

---

## Original review snapshot (superseded by the addendum above)

**NOT READY for local application.** This is a source/static review, not a
database test. No SQL draft, fragment, DO block, migration, fixture or database
assertion was submitted to a server. No database connection was made during
this review. Neither SQL draft nor either manifest was changed. There were no
hosted Supabase, role, schema, ownership, UI, Attendance, commit or push changes.

No Critical vulnerability or new, reachable browser authorization bypass was
confirmed. The intended restricted-executor design is plausible, but the
acceptance contract loses several enduring security checks and has incomplete
drift detection. Static PASS is not sufficient approval evidence.

## Reviewed artifacts and preservation

Read the proposal README, both complete SQL files, both JSON manifests, the
static checker, the foundation/lifecycle review, historical foundation
assertions, bootstrap, relevant Edge authorization paths and migration sources.
The manifests enumerate every proposed object; this review does not silently
expand their scope.

Reviewed SQL SHA-256 values:

| Draft | SHA-256 |
|---|---|
| `20261106120000_owner_executor_foundation.sql.draft` | `60ca760b18c92bf67ce86437cde379e0a40a26a9c9bed73cdf7ce7bafb616c01` |
| `foundation_assertions.sql.draft` | `4613383dcbc2533a08b2aa0664ef20d49fe8babe17253950dc37a9b33ec83e7b` |

All 24 original migration files and the four protected source files matched the
manifest's SHA-256 baseline. All 25 latest migration function bodies matched
the recorded MD5 fingerprints exactly, including original line endings. An
initial comparison that normalized CRLF failed; comparing the unchanged raw
source resolved that review-method discrepancy. It was not a draft/body change.
Each of the three phase-assertion blocks and three dependency-assertion blocks
in the migration matches its standalone assertion counterpart byte-for-byte.

These are repository comparisons. Existing applied database contents and live
server availability were not reverified today.

## Ownership, dependency and execution review

The explicit 22-table transfers all target `gym_data_owner`, with ENABLE and
FORCE RLS. There is no broad REASSIGN OWNED, provider-object transfer, role
membership grant, role creation or body rewrite. The 57 dependent indexes and
44 composite/array types are named with their parent relations. The three
identity sequences retain their parent bindings and follow table ownership;
there is no independent ALTER SEQUENCE OWNER statement. Catalog execution is
still needed later to verify those postconditions on the actual server.

| Existing operation / functions | Proposed dependency assessment |
|---|---|
| `is_active_owner_for_user`, `owner_list_members`, `owner_list_membership_plans`, `owner_list_membership_purchases`, `owner_list_membership_payments` | Owner executor has SELECT on the Owner registry and each queried member/plan/purchase/payment/allocation/event relation. Full-row reads have full-column SELECT. No PIN-verifier SELECT is granted. |
| `owner_register_member` | Named INSERT columns, SELECT for conflict detection/RETURNING, registry check and nested audit append are covered. Registration remains pending. |
| `owner_save_membership_plan` | Plan SELECT, named INSERT/UPDATE, RETURNING and locking permissions/policies are covered. |
| `owner_create_membership_purchase` | Member FOR UPDATE and plan FOR SHARE have SELECT plus UPDATE on at least one column and corresponding UPDATE policies. Purchase INSERT/RETURNING and audit are covered. |
| `owner_record_membership_payment`, `owner_confirm_membership_payment`, `owner_reject_membership_payment` | Payment/purchase locking, receipt INSERT/status UPDATE, allocation INSERT, event INSERT, trigger reads and audit dependencies are covered on paper. Only verification/purchase status columns are writable; no date/amount/receipt-history UPDATE is granted. |
| `owner_create_pin_enrollment_token` | Owner check, member lock, token SELECT/INSERT/consumption UPDATE, RETURNING and audit are covered. |
| `member_enroll_pin` | Public executor has scalar member reads/lock, token reads/lock/consumption, credential-existence SELECT and credential INSERT. No credential hash SELECT. Nested audit switches to the Owner executor, whose private invoker trigger performs the audit writes. |
| `reserve_pin_enrollment_request` | Public executor SELECT(requested_at), INSERT(requested_at) and DELETE with SELECT/INSERT/DELETE policies cover counting and existing retention. No other table DELETE is proposed. |
| `append_audit_event`, `verify_audit_stream` | Owner executor has audit SELECT/INSERT, head SELECT/INSERT/UPDATE, hash-helper execution, extensions USAGE and exact digest EXECUTE. The append trigger's head lock has UPDATE authority. |

All 16 API routines retain DEFINER with restricted NOLOGIN owners: 14 Owner
executor, two public executor. All nine private helpers become/remain INVOKER.
Seven trigger helpers lose superuser-definer execution; their SQL dependencies
are assigned to the calling Owner executor. `prevent_*` helpers only raise;
the four payment guards read already granted purchase/payment/allocation data.
The audit trigger calls the invoker hash helper and writes the chain head.
`private.is_active_owner()` remains dormant: no runtime caller is granted it,
and this proposal does not authorize its Auth-dependent use.

Row-locking SELECT needs UPDATE privilege on at least one column, and UPDATE
RLS policies participate in locking SELECT. The proposal supplies both; removing
the member UPDATE grant alone would break these operations. The remaining
`members.updated_at` write capability deserves explicit acceptance. See
[PostgreSQL 18 SELECT](https://www.postgresql.org/docs/18/sql-select.html) and
[CREATE POLICY](https://www.postgresql.org/docs/18/sql-createpolicy.html).

The 34 policies are command-specific and target exact executor roles. Their
CURRENT_USER tests admit that executor's rows; they do **not** independently
authenticate an Owner or bind a member. Authorization remains the unchanged
allowlisted RPC bodies, trusted Edge actor derivation and token verification.
Owner Edge paths inspected derive actor IDs from Auth `getUser`, not browser
actor fields. NOLOGIN alone is insufficient: the zero-membership checks are an
essential part of preventing direct SQL access to these executor capabilities.

No browser/service direct protected-table grant, PUBLIC policy, BYPASSRLS or
schema CREATE grant is proposed. Service-role execution of all 16 API routines
is preserved. The new public-executor audit-append grant is usable only from
its pinned definer entrypoints under the proposed membership boundary. Append
itself accepts arbitrary event/actor fields and is not an Owner authorization
function; it must never be exposed as a browser RPC.

Referential-integrity enforcement is separate from ordinary executor SQL and
bypasses RLS internally. Do not add broad Auth/table grants to solve an assumed
FK requirement. Constraint-error privacy still needs integration coverage.
[PostgreSQL RLS](https://www.postgresql.org/docs/18/ddl-rowsecurity.html).

## SQL and PostgreSQL compatibility result

Manual grammar review found no definite PostgreSQL 18 syntax defect in the
ownership, FORCE RLS, column grants, command policies, SET search_path, DO,
locking or transaction statements. Lexical/static checks pass. **Neither SQL
nor PL/pgSQL has been parser-certified or compiled.** No suitable standalone
PostgreSQL parser was found in the inspected project tooling; the available
Python launcher was inaccessible. No dependencies were installed. A generic
SQL parser would also not establish PL/pgSQL name resolution or ACL semantics.

The reviewed DDL forms and policy design also exist in PostgreSQL 17. That is
a documentation comparison, not a PostgreSQL 17 test. Catalog/deparser text,
extension placement/version, default privileges and provider objects need
separate inventory and version-specific expectations.

The file is deliberately native-only: exact local endpoint/identity, real
superuser, pg_control_system and pg_authid checks reject hosted execution.
Supabase's postgres role is not a superuser. Without superuser, owner transfer
requires SET ROLE ability and target-schema CREATE authority, conflicting with
this draft's zero membership/no CREATE contract. A reviewed hosted procedure
is required; do not add permanent memberships or weaken guards as a workaround.
See [ALTER FUNCTION](https://www.postgresql.org/docs/18/sql-alterfunction.html)
and [Supabase superuser restrictions](https://supabase.com/docs/guides/database/postgres/roles-superuser).

## Security risk register

Severity describes potential impact, not a demonstrated exploit. Blocking means
the item must be resolved or explicitly reviewed before local promotion and
application; no correction below has been applied.

| ID / severity | Affected object and root cause | Proposed correction | Required verification | Blocks local application? |
|---|---|---|---|---|
| R1 **High** | New phase profiles inspect routines only in private/api (`foundation_assertions.sql.draft:502`). Historical checks also covered exposed public/graphql_public routines and extension provenance. An unexpected exposed definer or PUBLIC-executable routine outside the 25-function inventory can escape the new acceptance contract. Data API CREATE checks on public and schema-owner checks are also omitted. | Restore an exhaustive exposed-namespace object/ACL/owner/CREATE inventory with native and hosted provider adapters. Allow only explicitly verified provider exceptions; no fake GraphQL wrapper. | Offline negative fixtures for unexpected exposed routines, PUBLIC EXECUTE, schema CREATE/owner drift and wrong extension provenance; separately approved catalog checks later. | **Yes** |
| R2 **High** | Neither new profile inspects pg_default_acl. Historical assertions at lines 703–803 reject dangerous effective global and additive schema defaults. README acknowledges unchanged defaults, but leaving defaults unchanged does not justify omitting their validation. Future routines could inherit unreviewed access without being caught by this contract. | Restore read-only effective-default assertions, including implicit defaults, global plus schema additions and relevant creators. Record any existing unsafe state as a failure/blocker; altering defaults is a separate approval. | Offline ACL-model fixtures and later approved catalog comparison. Future CREATE FUNCTION must revoke PUBLIC/grant narrowly in the same transaction regardless. | **Yes** |
| R3 **High** | Table columns are pinned only by names/types; constraints are checked only for convalidated (`:739`), and indexes only by owner/parent/readiness. Missing/weakened CHECK/FK/UNIQUE/exclusion definitions, changed predicates, defaults, identity mode or nullability can pass. Approval/payment/duplicate/overlap protections depend on these properties. | Pin full expected constraint inventory/definitions, index keys/expressions/predicates/uniqueness/exclusion, column nullability/default/generated/identity metadata and related bindings. | Compare exact expected source/catalog definitions; offline altered-definition/missing-object fixtures; later authorized runtime invariants. | **Yes** |
| R4 **Medium** | Trigger loop (`:584–603`) requires 13 named triggers but rejects no extra user triggers/rules. An extra trigger can change NEW values, skip writes or add side effects while all required triggers remain. | Require exact user-trigger inventory per scoped table, definitions/functions/enabled state; explicitly review internal constraint triggers and reject unreviewed rewrite rules. | Offline extra/reordered/disabled trigger and rule fixtures; approved runtime trigger-chain checks later. | **Yes** |
| R5 **Medium** | Routine pins cover input signature/prosrc/owner/definer/proconfig, not the full execution contract. Language, result/argument modes/defaults, strictness, volatility/leakproof/support metadata and extension/dependency provenance are not pinned. | Add a structured reviewed routine contract, including return shape and relevant execution/dependency metadata. Do not equate MD5(prosrc) with full function identity. | Offline metadata-drift fixtures and later catalog checks; return-shape/NULL/error behavior regression tests. | **Yes** |
| R6 **Medium** | static-review.ps1 is primarily presence/count/lexical based. It can confirm required grants without excluding every extra executor/column/schema/extension grant; it does not parse DO bodies or enforce all semantic invariants. | Treat PASS as lexical evidence only. Extend an independent offline manifest comparison to reject unexpected statements/grants and add mutation fixtures. Preserve SQL pre/postconditions as separate checks. | Extra-grant/policy/predicate/owner/blocker-change fixtures must fail; obtain PostgreSQL-compatible SQL and PL/pgSQL syntax review without submitting draft SQL to a server. | **Yes**, current validation evidence is insufficient |
| R7 **Medium** | Drafts raise errors but do not establish a client exit-code contract. With psql's default continue-on-error mode, a failed DO/blocker followed by ROLLBACK/aborted COMMIT may still yield process exit 0. Transaction abort prevents draft DDL, but does not prove automation failure propagation. | Specify a future runner using ON_ERROR_STOP=1, checking native exit codes and refusing success after any assertion error. Never remove the blocker for this review. | Offline runner contract review; after separate authorization, dedicated refusal tests must produce nonzero process exits. | **Yes**, before executable promotion |
| R8 **Medium** | Executor CURRENT_USER policies are broad within each granted command; members.updated_at UPDATE exists for row locks. Public executor additionally reaches generic audit append. A future unsafe definer or role membership could turn these capabilities into arbitrary writes/audit attribution. | Explicitly accept the present capability/call graph or draft a separate narrow locking/audit interface. Keep exact entrypoint inventories, zero memberships and Edge-derived actors. Do not remove locks or grant status/date updates. | Actor-spoofing, direct-role denial, token replay/expiry, audit attribution, concurrency and rollback tests under approved synthetic integration scope. | **Yes**, requires design acceptance and test plan; no current browser exploit demonstrated |
| R9 **Low** | USAGE grants on all three identity sequences appear unnecessary for existing bodies: they use implicit GENERATED ALWAYS identity insertion, with no nextval/currval/lastval calls. USAGE additionally permits direct sequence advancement when executing as that role. | Remove unnecessary grants and adjust the proposed matrix/assertions in a reviewed draft revision, or justify a concrete dependency. Preserve sequence ownership/bindings. | Offline source check plus later authorized identity-insert tests without sequence grants. | No by itself; resolve least-privilege decision before approval |
| R10 **Medium** | Hosted execution cannot satisfy native superuser/identity preconditions; ownership-transfer authority, extension ACL authority and catalog assumptions differ. | Keep this native draft blocked from hosted use; prepare a separately approved hosted inventory/adapter/procedure. | Owner-controlled PostgreSQL version/role/default/extension inventory and staging security verification. | No for native-only application; **yes for hosted** |

R9 is a source-based finding: PostgreSQL 17/18 identity evaluation calls
`nextval_internal(..., false)`. It does not require the caller's ordinary
sequence privilege check. See the official
[18 executor source](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/executor/execExprInterp.c)
and [17 executor source](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/executor/execExprInterp.c),
`ExecEvalNextValueExpr`. This is not permission testing against this cluster.

## Assertion profiles and requirements traceability

| Profile | Review result |
|---|---|
| historical_phase1 | Explicit refusal is correct. Empty-API, dormant-executor and old authenticated API access assumptions are archival. |
| current_server_only | Exact postgres-owned baseline and current ingress are explicit; hardening is warned as unsatisfied. This is not hardened acceptance. R1–R5 still apply. |
| proposed_owner_executor | Requires new owners, FORCE RLS, exact 34 policies and intended column/function ACLs; cannot accept the current baseline. R1–R5 still prevent treating it as complete acceptance. |
| future_attendance | Raises unconditionally before acceptance checks. NULL/unknown profiles also refuse. No eligibility/PIN-verification/check-in feature can be certified by selecting this profile. |

The historical file remains unchanged and its ownership failure was not
disabled. However, the README's claim that only obsolete checks were omitted
is too broad: exposed-routine/default-ACL checks are enduring safeguards.
Phase-awareness must restore them rather than report them as obsolete.
No existing failure was rerun, hidden or converted to PASS in this review.

Registration approval, trustworthy approval/confirmation times, activation,
Option A expiry, serialized renewal, unmatched-receipt allocation and payment
void invalidation remain lifecycle blockers from the prior review. This draft
grants no new approval/date writes and implements none of those transitions.
Ownership hardening cannot certify paid access or Attendance readiness.

## Actual validation results and limits

| Check performed | Result |
|---|---|
| Existing draft static-review.ps1 | PASS, exit 0; lexical/manifest/source-hash scope only |
| Existing supabase/tests/check-security-config.ps1 | PASS, exit 0; API exposure/signup configuration and parser self-tests |
| Existing cached Deno shared unit suite | 38 passed, 0 failed, exit 0 |
| Additional filesystem source-body comparison | PASS, 25/25 raw body MD5 pins |
| Repeated versus standalone assertion blocks | PASS, three phase and three dependency blocks match |
| Original migrations/protected harness sources | PASS, 24 migrations plus four protected hashes unchanged |
| SQL/PLpgSQL parser/compilation, live catalog checks, role/RPC/RLS/concurrency tests | NOT RUN; no database SQL executed |
| Hosted Supabase compatibility/deployment | NOT TESTED / no hosted access or changes |

Commands actually used for existing checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/drafts/foundation-2026-11-06/static-review.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/check-security-config.ps1
$env:DENO_NO_UPDATE_CHECK = '1'
Remove-Item Env:MEMBER_MOBILE_ENCRYPTION_KEY_B64 -ErrorAction SilentlyContinue
Remove-Item Env:MEMBER_MOBILE_HMAC_KEY_B64 -ErrorAction SilentlyContinue
& 'C:\Users\Banco-Sual\AppData\Local\Microsoft\WinGet\Links\deno.exe' test --cached-only --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared
```

PowerShell Bypass was process-scoped only. The sandbox could not launch the
installed Deno executable; the authorized cached test command succeeded
outside that sandbox with no database/network permission granted to tests.
No package installation occurred. Lint/typecheck/build were not rerun because
this review changes documentation only. Deno unit tests do not exercise the
proposed PostgreSQL security behavior. Mutation-capable Owner boundary probes
and all SQL assertion files were deliberately not run.

## Next checkpoint, without execution

Prepare a separately reviewed draft revision addressing R1–R7, decide R8/R9,
and add independent offline negative fixtures for the assertion/checker
contracts. Obtain parser evidence without executing draft SQL. Review the
resulting manifest and authorized synthetic integration plan before requesting
local-application approval. The unconditional blockers and inactive filenames
remain in place. Hosted adaptation/deployment and Git commit/push require their
own approvals; Cloudflare/GitHub release does not deploy Supabase SQL/functions.

Files changed by this review: this new report and a README pointer to it.
All findings are proposed corrections, not applied SQL changes.
