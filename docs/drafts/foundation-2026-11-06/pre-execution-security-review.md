# Pre-execution foundation security review — November 6, 2026

Latest: [accelerated-review/README.md](accelerated-review/README.md). Definition
integration and all PG18 procedural parsing now pass; this earlier review is
historical. Proposed database changes and runtime acceptance remain unexecuted.

Follow-up: [semantic-alignment/README.md](semantic-alignment/README.md) resolves
the 52/14 definition gaps below. SQL grammar parsing now passes; dedicated
PL/pgSQL refusals and unchanged draft integration remain blockers. This document
preserves the earlier checkpoint; the overall verdict is still NOT READY.

**NOT READY for controlled local execution approval.** The review and permitted
boolean comparisons are complete; definition equivalence and parser/runtime
acceptance are not. No migration, proposal, DO block, role/ownership/grant change,
fixture, application query or hosted operation was executed. No runner was
implemented. All three proposal/assertion SQL draft blockers remain intact.

## Default-privilege proposal verdict

All five statements in `default-function-privileges.sql.draft` match the intended
creators and object class:

| Creator (one statement each) | Class and scope | Review |
|---|---|---|
| postgres | Future FUNCTIONS, current database, all schemas | Correct native-only target; impacts future extension/provider creation too |
| gym_data_owner | Same | Correct; grants no schema CREATE or login capability |
| gym_owner_executor | Same | Correct; does not retroactively alter the 14 proposed API owners' function ACLs |
| gym_public_executor | Same | Correct; current PIN/RPC entrypoint ACLs remain separate |
| gym_registration_login | Same | Correct; does not activate this dormant login or supply credentials |

No IN SCHEMA is appropriate: schema-only revocation cannot subtract global
PUBLIC EXECUTE. FUNCTIONS covers future procedures/aggregates as well. Existing
functions, existing service_role and nested executor EXECUTE grants, types,
tables and sequences are unaffected by these default changes. Future RPC/helper
creation transactions must explicitly grant each authorized caller. Ownership
transfer does not reapply creator defaults. See
[PostgreSQL 18](https://www.postgresql.org/docs/18/sql-alterdefaultprivileges.html)
and [PostgreSQL 17](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html).

Verdict: **sound scope for a separate native hardening proposal; not executable
approval**. Current database function defaults still fail the chosen owner-only
target for five creators. The implicit-type exception remains narrow and no
default privileges changed. Hosted Supabase creator authority, extension/API
defaults and provider updates require separate Owner review; applying this
globally for hosted postgres could break future provider-created routine access.
No hosted capability is inferred from native postgres superuser execution.

## Permitted definition/signature evidence

Fresh protected preflight again verified approved marker, system identifier,
canonical data directory, `gymforce_pg18_test`, `127.0.0.1:55432`, postgres
session/current identity and required SCRAM. Twelve small comparison queries
were individually accepted and exited 0. Each used its own exact identity
guard, READ ONLY transaction, statement timeout, `-X -w`, ON_ERROR_STOP=1 and
ROLLBACK. No failed identity guard or automatic-review rejection occurred.

Only object labels and booleans were returned. Expectations come from the
original-source-pinned contracts. Actual argument/default/definition/config
values, function bodies, body hashes, credentials and application records never
left PostgreSQL. The body comparison returns only equality to a fixed approved
MD5 source pin; it does not export a body/hash or provide an arbitrary oracle.
Those legacy MD5 checks are not adversarial tamper-proof evidence.

| Comparison | Actual result | Meaning |
|---|---|---|
| Approved routine identities, input/output argument types/names/modes, return types | **25/25 match** | Exact approved signatures resolve; argument/result shape matches. Return metadata normalization removes whitespace only |
| Volatility/parallel/language/definer/strict/set-return/leakproof and empty search_path | **25/25 match current baseline** | Matches current postgres-owned bodies; does not claim proposed restricted execution has been tested |
| Routine body source pins | **25/25 match** | Server-side fixed-source fingerprint comparisons only; no body or observed digest export |
| Primary keys | **22/22 exact normalized definitions match** | Includes column order in the approved definitions |
| UNIQUE constraints | **6/6 match** | Exact normalized definitions |
| Foreign keys | **30/30 match** | Exact normalized definitions, including declared target/actions |
| CHECK constraints | **0/51 strict source-text matches** | All 51 exist and are validated with expected flags; expression equivalence remains unresolved |
| Exclusion constraint | **0/1 strict source-text match** | Exists and is validated; membership-overlap expression/operator/predicate equivalence remains unresolved |
| Explicit indexes | **14/28 match** | All 28 exist, correct parent, valid/ready/live; the other 14 definitions remain unresolved. Previous structural evidence covers all 57 indexes, not 57 definition matches |
| Column defaults/generated expressions | **140/149 strict matches; 149/149 after narrowly approved text casts** | The nine differences are source text literals receiving explicit `::text`. All 149 identity/generated flags also match; stored variance expression matches without weakening normalization |
| Trigger definitions and enabled state | **13/13 match** | Exact normalized definitions against approved trigger inventory; no runtime firing behavior claim |
| Routine defaults | **20/25 strict matches; 25/25 after approved text casts** | Five routine default lists gain text casts for known text arguments, including typed NULLs. No default values were exported |

The text-cast candidates only add `::text` to a single approved text literal or
text NULL. They never strip casts, change constants, erase operators/grouping,
rewrite arbitrary expressions or apply to non-text types. Fourteen fixed
server-side comparisons (nine columns/five routines) all returned true; eight
offline tests cover this narrow transformation. These are legitimate catalog
normalization differences, not database defects.

The other **52 constraint and 14 explicit-index comparisons are unresolved**.
They are not established corruption, nor proven harmless deparser differences.
No actual expression was exported to guess the answer. Do not change expected
definitions or remove parentheses/casts to obtain green results. Current draft
source-only comparisons still need a separately reviewed canonical-expression
revision; this review did not rewrite the SQL drafts or refresh their baselines.

The new evidence is in `boolean-alignment/`: twelve query sources, twelve safe
CSV observations and `findings.json`. Independent connections are not an atomic
whole-database snapshot or a write-preservation test. Existing objects outside
the approved allowlist were not freshly re-inventoried by these equality probes;
the full inventory preconditions still must run before any approved application.

## Offline parser investigation

Reliable offline parsing is possible without executing SQL on a server.
`libpg_query` extracts PostgreSQL's parser and documents separate **18-latest**
and **17-latest** branches and an explicit PL/pgSQL parsing API. Windows builds
are documented using Visual Studio/nmake. See the primary
[PostgreSQL 18 library documentation](https://github.com/pganalyze/libpg_query/tree/18-latest),
[PostgreSQL 17 library documentation](https://github.com/pganalyze/libpg_query/tree/17-latest)
and [pglast documentation](https://pglast.readthedocs.io/en/latest/).

No suitable parser was found in the inspected project dependencies; no working
compiler/installed Python parser was established. No package/toolchain was
installed, downloaded or added to dependencies. **No PostgreSQL SQL or PL/pgSQL
parser was run.** Node --check validates JavaScript only; the current source
lexer and frozen statement comparison are not SQL parser certification.

A future approved parser setup must pin a reviewed release/commit and artifact
checksums for each PostgreSQL major, check security fixes, and run offline on
the exact draft files without credentials or network permissions. Raw SQL
parsing must cover all DDL/ACL statements, but DO/function dollar bodies need
the separate PL/pgSQL path. Verify that selected bindings actually handle DO
blocks and `%ROWTYPE`; do not infer that from a generic SQL AST pass. Any
diagnostic-only wrappers must stay outside execution paths and must never
remove blockers from the actual drafts. Parser success cannot resolve catalog
names, extension authority, RLS or runtime privilege behavior. PREPARE, EXPLAIN,
temporary functions and transactional migration execution were not used as
parser substitutes. PostgreSQL 18 evidence does not certify 17 or Supabase.

## Executor acceptance plan and execution blockers

The detailed [executor-acceptance-plan.md](executor-acceptance-plan.md) covers
nested Owner/public-executor audit calls, all trigger paths, row-lock grants,
exact RLS/column denials, identity insertion without sequence grants, controlled
failure rollback and separately authorized concurrency. It includes Owner
backup/recovery custody, fresh preconditions and explicit acceptance criteria.

Three hazards block a naive rollback test:

- Existing drafts contain BEGIN/COMMIT; an outer BEGIN/ROLLBACK does not undo an
  embedded COMMIT. A future approved test revision needs reviewed single
  transaction boundaries; do not execute these files inside an assumed wrapper.
- Identity sequence advancement may survive rollback. Authorize and measure
  bounded side effects or approve a separate isolation/recovery arrangement;
  never auto-reset sequences.
- A second connection cannot see uncommitted ownership/ACL/policy changes.
  Concurrent acceptance requires an explicitly approved committed isolated
  state; a single-session rollback test cannot certify it.

No runner, promoted migration, mutation fixture, alternate database/cluster or
acceptance test was created/executed. Owner approval of executor capabilities,
recovery and the exact future test scope remains required. Lifecycle approval,
activation/renewal/payment-void gaps remain unchanged; no Attendance readiness
or hosted release approval follows from this review.

## Validation and changed files

Actual completed checks: draft static checker, all **31 original negative
subprocesses** (each expected exit 1, positive control exit 0), **nine default
classification tests**, security configuration checks, **38 Deno shared unit
tests**, **eight text-cast tests**, original 24 migration/four protected-source
hashes, lint, typecheck and build/PWA. All passed, exit 0. Generated dist files
remain ignored. No SQL runtime or parser test is represented as PASS.

`review-boolean-alignment.mjs` validates permitted CSV fields/counts and writes
the evidence summary; summary mode exit 0 means evidence parsed, not acceptance.
With `--require-aligned`, it returned **native exit 2**, explicitly propagated
by the parent PowerShell process, while the 52/14 definition gaps remain. Never
use summary success as an execution-approval gate.

Added: prepare-boolean-alignment.mjs, approved-text-casts.mjs,
approved-text-casts.test.mjs, review-boolean-alignment.mjs, twelve boolean query
sources/observations plus findings.json, executor-acceptance-plan.md and this
review. Updated README/technical-review/default-proposal pointers only. Existing
migration/assertion/default-function SQL drafts, source contracts/renderers,
statement manifest, bootstrap, active assertions, all 24 original migrations,
UI and unrelated workspace work remain unchanged. No commit/push/deployment.

Final verdict: **NOT READY**. The five unexecuted function-default changes,
52 constraint/14 index definition gaps, parser evidence, safe transaction and
isolation design, and restricted-executor runtime acceptance remain blockers.
