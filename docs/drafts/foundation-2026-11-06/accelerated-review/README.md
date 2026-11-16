# Accelerated foundation review — November 6, 2026

All three authorized **offline/draft phases are complete**. **NOT READY for
controlled local execution**: no promoted rollback-only test revision, approved
recovery/fixture/sequence scope or restricted-executor runtime evidence exists.
This verdict does not mean that the parser or offline assertion tests failed.
No PostgreSQL connection, SQL execution, mutation, hosted operation, Docker,
application/UI change, migration promotion, commit or push occurred in this run.

## Phase 1: procedural parser resolution — PASS

The cause was an actual draft procedural delimiter defect, not incorrect body
extraction, nested dollar quoting or an excuse to skip parsing. Two distinct
conditions used an unparenthesized SQL CASE at IF-condition parenthesis depth
zero. The procedural scanner treats its first THEN as the IF terminator, leaving
an incomplete expression. Parenthesizing the **CASE expression** preserves its
logic and prevents that premature boundary. PostgreSQL's
[PL/pgSQL grammar](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/pl/plpgsql/src/pl_gram.y)
(`read_sql_construct`, which tracks parentheses) and the minimal regression
fixtures establish the cause. A plain SQL SELECT accepts the original CASE
expression; this did not prove that its enclosing procedural IF was valid.

Corrected the phase policy-command condition in four block copies and the
generated argument-mode condition in four copies. No policy semantics,
authorization checks or body fingerprints were removed. The eight changed DO
statements are recorded in [draft-statement-revisions.json](draft-statement-revisions.json).
Every other statement, including the unconditional blockers, grant/ownership/
policy instructions and five-default proposal, matches its previous digest.

`offline-parser.mjs` now uses PostgreSQL AST statement boundaries in UTF-8 byte
offsets. Each original DO/PLpgSQL CREATE FUNCTION/PROCEDURE statement is parsed
individually, then the entire original file is parsed procedurally. Expected
body counts must equal returned `plpgsql_funcs` counts. It never extracts just
the outer dollar body, wraps/replaces a failing body, masks exceptions, or falls
back to SQL-only success for the required PG18 procedural pass. Unknown
procedural languages, missing parser APIs and skipped bodies fail nonzero.

Pinned existing bindings were reused; no dependency was installed this run:

| Binding | Actual grammar | Coverage |
|---|---|---|
| libpg-query 18.1.4 | PG18.4 / 180004 | All three exact blocked SQL drafts; **17/17** procedural bodies (10 migration, 4 assertions, 3 defaults) |
| libpg-query 17.8.2 | PG17.7 / 170007 | All three exact blocked SQL drafts; procedural API **unavailable**, explicitly recorded |

[parser-results.json](parser-results.json) reports current hashes and per-body
boundaries. Historical failed parser results and catalog observations remain
unchanged in `semantic-alignment/`; only the authorized parser tool's evidence
pin changed, with its before/after hash in
[reviewed-pin-revisions.json](reviewed-pin-revisions.json). Pins were not
automatically refreshed to accept catalog drift. Source migration hashes remain
the original authoritative baseline.

Parser fixtures: five accepted subprocesses exit 0; **nine negative subprocesses
exit 2**, including both original CASE forms, malformed inner SQL, malformed
function/second DO bodies and broken quotes/terminators. Two extra tests reject
body-skipping and missing-parser responses. UTF-8 offsets, multiple statements,
nested dollar quoting and procedural-looking ordinary strings have positive
coverage. SQL grammar parsing is not catalog/type/privilege resolution or
runtime compilation; neither grammar patch exactly matches native 18.6.

## Phase 2: aligned security assertions — PASS offline; runtime NOT RUN

The original `source-contract.mjs` and `schema-contract.json` are unchanged.
`aligned-contract.mjs` derives a separate `aligned-schema-contract.json` from
original source, the previously verified complete candidates and evidence pins.
It preserves the original definitions and adds explicit catalog expectations;
observed expressions are never stripped of casts, grouping or operators.

The generated hardening block now checks:

- All **110** exact constraints, flags and validation; all 51 CHECKs and the
  exclusion consume their verified representations. The exclusion also checks
  exact GiST opclasses/operator OIDs/key identity and non-inheritance.
- All **28** explicit definitions and **40** index keys, including identity,
  type, opclass, default flag, ordering/null placement, collation, uniqueness
  and validity; all 57 indexes remain in the full inventory.
- All **149** column types/defaults/nullability/identity/generated properties,
  using the earlier approved text casts only where proven.
- All 25 routines' signatures, defaults, return/mode/security metadata and
  source pins; exposed routine, default-ACL, exact trigger/rule inventory,
  server-only ACL, RLS, column-grant and role-membership safeguards remain.

Token aggregation now orders by regex-token ordinality explicitly. The new
catalog guard refuses non-PG18 execution because conenforced and this verified
catalog profile are native PG18-specific. PG17 SQL grammar success is not a
hosted/native PG17 execution claim. Existing historical/future profiles still
refuse; future Attendance cannot pass through these assertions.

The exact statement manifest was updated only after checking unchanged
statement counts and that precisely eight allowed assertion DO statements
changed. Test runners never refresh manifests or evidence baselines. Original
31 negative fixtures remain; **11 added negative subprocesses exit 1** for
verified expression/default/opclass/key drift, unsafe privileges, unexpected
routines/triggers and removal of rule/key guards.

## Phase 3: restricted executor readiness — prepared, NOT EXECUTED

[executor-acceptance-fixtures.json](../executor-acceptance-fixtures.json) defines
16 synthetic scenarios, two for each requested category: nested RPC, triggers,
row locks, RLS, role escalation, rollback, sequence advancement and concurrency.
It has explicit exact-target identity, collision refusal, no existing-row reuse,
no stored credential material and `autorun: false`. Its checker validates design,
not database behavior. No provisioning SQL, executable runner or live fixture
was created. Payment confirmation remains pending_activation with null access
dates; no lifecycle feature or unpaid activation is implemented.

[Executor plan](../executor-acceptance-plan.md) now includes a controlled
execution checklist and these critical limits:

1. Both proposal files' embedded COMMITs defeat a naive outer rollback. Future
   promotion needs reviewed single boundaries, intact preconditions and final
   ROLLBACK; repository drafts stay blocked.
2. Apply the five function-default changes **first in that same approved pilot
   transaction**, verify them, then check/apply the foundation draft. Its current
   profile already requires hardened defaults. Global current-database scope
   for each creator is necessary; existing server/nested RPC grants stay intact.
   No statements were executed and the default proposal text/hash is unchanged.
3. SET LOCAL ROLE alone under postgres does not prove role-assumption denial:
   SET ROLE checks session_user. The plan distinguishes session-authorization
   simulation from a real restricted login; no password/role membership changes
   are proposed for testing. Superuser reset power is never hidden.
4. Sequence advancement survives rollback; approve/cache-account/bound it, and
   never auto-reset. Post-RPC division-by-zero verifies transaction rollback,
   not every internal RPC failure path. A safe natural nested-trigger failure
   reproducer remains a specific follow-up test-design gap.
5. Session B cannot see uncommitted proposed ACL/schema state. Multi-session
   tests require separate committed isolation/recovery approval, barriers and
   timeouts. Single-session results cannot certify concurrency.

Hosted postgres default changes could affect future provider/extension-created
objects; no hosted compatibility or deployment approval is inferred. The five
revokes do not change existing functions and do not create executor privileges.
GitHub/Cloudflare deployment deploys neither Supabase SQL nor Edge Functions.

## Validation performed

| Check | Actual result |
|---|---|
| PG18 SQL + full-file/individual PLpgSQL | PASS, all 17 bodies |
| PG17 SQL | PASS, all three drafts; PLpgSQL unavailable |
| Definition gate | PASS, exit 0; unresolved evidence still fails nonzero |
| Parser/semantic/text-cast tests | PASS, 40/40 |
| Existing / added security negatives | PASS, 31/31 and 11/11, each native exit 1 |
| Default classification | PASS, 9/9 |
| Executor fixture design | PASS, 16 scenarios; all runtime cases NOT RUN |
| Existing security configuration | PASS |
| Existing Deno shared unit tests | PASS, 38/38, cached-only, no DB/network capability |
| npm.cmd run lint / typecheck | PASS |
| npm.cmd run build | PASS, including PWA output; generated dist remains ignored |
| Original migration / protected-source hashes | PASS, 24 originals and four protected sources |

The integrated `validate-offline.ps1` propagates every parser/gate/static/test
failure. It does not invoke PostgreSQL, install dependencies, regenerate SQL,
refresh manifests or run acceptance cases. Its isolated pinned parser packages
must already exist under ignored `.cache/`; absence fails closed.

## Changed files and Git review

Added: `offline-parser.mjs`, parser fixtures/checker/tests, `aligned-contract.mjs`,
`aligned-schema-contract.json`, added aligned negative checker,
executor fixture JSON/design checker and this review/evidence directory.
Updated: two blocked foundation SQL drafts, hardening renderer, offline checker,
original-negative runner's baseline path, statement manifest, offline validation
wrapper, definition-gate status text, executor plan and review/status documents.
The semantic evidence pin revision is limited to the changed parser tool;
historical catalog observations were not re-baselined.

Suitable for a future **explicitly scoped** commit: reviewed draft-only SQL,
source-derived contracts, tools, manifests, synthetic fixtures and documentation.
Existing boolean evidence contains only approved structural labels/flags.
Never stage `.cache/`, dist, local data, logs, backups, identity/pgpass files,
environment credentials or broad scratch output. Application dependencies/UI,
all active migrations, bootstrap and active assertions are unchanged. Inherited
`.gitignore`/attendance-readiness edits and other checkpoint/local-testing files
remain unstaged and need their own review; do not use a blanket git add.

## Remaining blockers and exact next action

**NOT READY for controlled local execution.** Offline syntax/integration blockers
are resolved; these are the remaining operational/runtime gates:

- Owner-controlled backup/recovery and the exact fixture/maintenance/sequence
  budget must be approved. No fresh identity claim is made in this offline run.
- A separately reviewed promoted rollback-only revision is needed; no runner or
  executable promotion exists and all repository SQL blockers remain intact.
- Five future-function corrections and proposed owners/ACLs/RLS remain
  unexecuted. All real executor, trigger, locking, rollback and concurrency
  outcomes are untested; nested-failure fixture design needs further review.
- PG17 procedural/runtime and hosted Auth/JWT/Supabase compatibility remain
  outside this native offline evidence. Lifecycle/Attendance remain separate.

**Recommended next action:** Owner reviews this exact eight-DO revision and
approves the rollback-only native pilot scope in the executor checklist, including
identity-bound target, restorable backup, synthetic fixture provisioning and
bounded sequence advances. Then prepare/review a single-boundary promoted test
copy before executing anything. Concurrency/committed isolation needs separate
approval; no hosted release follows from the pilot.
