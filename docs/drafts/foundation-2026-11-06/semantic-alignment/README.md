# Definition alignment review — November 6, 2026

Historical checkpoint. The [accelerated follow-up](../accelerated-review/README.md)
now integrates the verified definitions and resolves the CASE-related procedural
parser defects. Original observations below remain preserved. Runtime approval
and acceptance are still outstanding; no catalog queries were rerun in that work.

**66 previous mismatches resolved; NOT READY for controlled local execution approval.**
No database objects, privileges, ownership, data, active migrations, SQL drafts or
execution blockers changed. These probes are fixed read-only catalog comparisons,
not migration/assertion execution. No observed expression, function body, secret,
application row or arbitrary configuration value was exported.

## Evidence and classification

Fresh protected identity/SCRAM preflight passed for the approved marker, system
identifier, canonical data directory, postgres identity and
`gymforce_pg18_test` at `127.0.0.1:55432`. Queries 20–24 were separately accepted
and each returned psql exit 0 inside guarded READ ONLY / ROLLBACK transactions.
No automatic-review rejection or identity mismatch occurred.

| Query | Actual result |
|---|---|
| 20 CHECK candidates | 51/51 complete definitions and flags match |
| 21 explicit-index candidates | 28/28 complete definitions and validity flags match; includes all 14 previous mismatches |
| 22 first exclusion candidate | Definition and added inheritance flag fail; retained as historical failed evidence |
| 23 targeted exclusion evidence | Exact revised candidate, UUID/range GiST opclasses, exclusion operator OIDs, backing-index flags and non-inheritance all match |
| 24 explicit-index key metadata | 40/40 keys match identity, type, default opclass, ordering/null placement, collation and index flags |

[classification.json](classification.json) enumerates **each of the 66** previous
mismatches: expected original definition, complete source-derived candidate,
verified representation, accepted rules and evidence file. Candidate text is
derived from original migration source, **not exported catalog expressions**.
The observed representation is established only as exact equality to that
approved candidate, never by printing the observed expression. Earlier PK22,
UNIQUE6 and FK30 matches are preserved, giving 110/110 definition coverage across
the combined evidence. All 57 indexes have earlier structural coverage; only the
28 source-explicit indexes are claimed here as definition-aligned.

## Why the accepted rules preserve the intended definitions

The renderer consumes only original-source-pinned ASTs, never observed metadata.
It produces a complete candidate whose normalized token sequence must match
exactly. Whitespace/unquoted-keyword case are the only transformations applied
to the observed sequence. Constants, parentheses, casts, operator order,
predicates and qualifications are never stripped from observed text.

- PostgreSQL's non-pretty ruleutils output adds parentheses at operator,
  Boolean and null-test nodes, plus CHECK/predicate wrapper parentheses. AST
  grouping is preserved; `(a OR b) AND c` cannot align with `a OR (b AND c)`.
- Known text-column `IN` lists contain only fixed non-NULL text literals. Their
  parsed scalar-array form uses the same equality operator and ordered typed
  ARRAY elements. Every constant and its case is preserved; no general
  IN/subquery/NULL rewrite is accepted.
- The SQL grammar maps TRIM to the built-in btrim function; its SQL-syntax
  deparser emits `TRIM(BOTH FROM ...)`. Explicit `btrim(...)` calls remain
  ordinary calls. Neither function nesting nor argument order is erased.
- Known numeric columns coerce the integer zero to numeric. Known text literals
  gain text casts. These are source-type-specific candidates, not cast removal
  or permission to reinterpret arbitrary types, values or expressions.
- Visible pg_catalog functions print without their schema qualification.
  Schema-specific functions and unknown nodes/options are refused. Parentheses
  around a simple index attribute collapse to an attribute key, independently
  verified against `indkey`; expression keys remain expressions.
- ruleutils suppresses a default operator-class name even if the source names
  it explicitly. Query 23 separately pins `extensions.gist_uuid_ops` for UUID
  and `pg_catalog.range_ops` for anyrange, both GiST/default, plus the exact
  `=(uuid,uuid)` and `&&(anyrange,anyrange)` operator OIDs. Range bounds remain
  the source's `[]`; the activation/expiry predicate and column order match.
- The original query 22 incorrectly applied CHECK's inheritable expectation to
  an exclusion. Exclusion constraints are not inherited. Query 23 explicitly
  requires its non-inheritable flag; no blanket flag exception is used.

Primary references: PostgreSQL 18
[ruleutils.c](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/utils/adt/ruleutils.c),
[grammar](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/parser/gram.y),
[IN/ANY semantics](https://www.postgresql.org/docs/18/functions-comparisons.html),
[index opclasses](https://www.postgresql.org/docs/18/indexes-opclass.html),
[inheritance limitations](https://www.postgresql.org/docs/18/ddl-inherit.html).
This is equivalence of the narrowly approved definitions and catalog identities,
not certification of planner behavior, extension binary provenance, privileged
administrator tampering resistance or application runtime correctness.

## Parser installation and actual limits

Installed prebuilt WASM bindings only into ignored `.cache/foundation-parser`,
with npm lifecycle scripts disabled (`--ignore-scripts --no-audit --no-fund`).
No Docker/native build, application dependency/lockfile change, global install,
database connection, SQL execution or object creation was involved in parsing.
Initial sandbox registry access failed; explicitly reviewed network access then
succeeded. Package tarball integrity pins/dependency versions are recorded in
[parser-provenance.json](parser-provenance.json). No parser normalization or
fingerprint API is used; only approved local source is parsed.

| Binding package | Actual reported grammar | Result |
|---|---|---|
| libpg-query 18.1.4 | 180004 (PostgreSQL 18.4) | All three exact blocked SQL drafts parse; 51 CHECK and 28 index source ASTs agree with PG17, ignoring locations only |
| libpg-query 17.8.2 | 170007 (PostgreSQL 17.7) | All three exact blocked SQL drafts parse; SQL-only API |

Package version is **not** server grammar patch version. The installed 17.8.2
binding does not report a 17.8 grammar. Neither parser matches the running 18.6
server patch exactly. Primary binding documentation:
[libpg-query-node](https://github.com/constructive-io/libpg-query-node).

Top-level SQL parsing treats dollar bodies as opaque. The separate PG18
PL/pgSQL API passes the default-privilege proposal, but refuses both ownership
and assertion drafts with **syntax error at end of input**. Minimal DO/function
controls parse; separately parsed source DO blocks also reproduce refusals.
This has **not** been established as a harmless binding limitation or a real
draft defect. No unsafe execution workaround, body rewrite, catalog shim or
server compilation was attempted. PG17 PL/pgSQL is unavailable in this binding.
[parser-results.json](parser-results.json) records these failures; parser review
returns native **exit 2**, deliberately propagated through PowerShell.

## Fail-closed offline validation

`review-semantic-alignment.mjs` requires exact source-derived object sets, counts,
field allowlists, true flags and reviewed source/evidence pins. Any missing,
duplicate, substituted or unresolved definition causes nonzero exit 2.
`review-boolean-alignment.mjs --require-aligned` now consumes this evidence while
retaining all earlier structural/signature/trigger checks and requiring a
specific successful cast comparison for every historical false default.
Both definition gates currently exit **0**. Their success is limited to recorded
definition evidence; the overall verdict remains NOT READY. Evidence pins are
review artifacts, not signed or adversarial tamper-proof attestations. Do not
automatically refresh them to accept drift.

New tests: 16/16 passed, including six negative child processes each exiting 2
and a positive child exiting 0. They cover changed grouping/operators/constants,
unknown types/nodes/functions/options, index collations/opclasses and incorrect
null semantics. The original 31 negative subprocesses remain unchanged.

Validation also passed: existing draft static/security checks, 31 negatives,
nine default classifications, eight text-cast tests, 38 Deno shared unit tests,
lint, typecheck, build/PWA and original 24 migration/four protected-source hash
verification. All three blocked SQL draft hashes remain unchanged.

Re-run filesystem gates without database access:

```powershell
node docs/drafts/foundation-2026-11-06/review-boolean-alignment.mjs --require-aligned
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
node --test docs/drafts/foundation-2026-11-06/semantic-alignment.test.mjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

The new renderer tests require the isolated pinned parsers. No script installs
dependencies automatically. Re-generating query sources never runs them;
database probes still require fresh identity verification and explicit scope.

## Files changed in this follow-up

Added draft-only tools: `deparser-candidates.mjs`,
`prepare-semantic-alignment.mjs`, `prepare-index-metadata.mjs`,
`review-semantic-alignment.mjs`, `semantic-alignment.test.mjs` and
`parse-drafts-offline.mjs`. Added this directory's five fixed SQL probes/five
boolean observations, source candidates, per-object classifications, key
expectations, provenance, evidence pins, parser results and findings.

Updated `review-boolean-alignment.mjs` and its generated
`boolean-alignment/findings.json` to consume the new evidence fail-closed.
Updated parent README, technical review, pre-execution review and executor plan
to distinguish resolved definitions from remaining blockers. The isolated npm
installation and investigation scratch files remain ignored under `.cache/`;
dist output remains ignored. Inherited unrelated working-tree edits were
preserved. Application files, package.json/package-lock.json, original migrations,
active assertions/bootstrap, all three SQL drafts and their blockers are unchanged.

## Remaining execution blockers

1. Separately review integrating the verified source-specific candidates into
   draft contracts/renderers/assertions. They still use the earlier strict
   lexical expectations and would reject legitimate catalog forms. No SQL
   draft was changed just to obtain a passing review.
2. Resolve the offline PL/pgSQL refusals and obtain appropriate compilation
   evidence. SQL grammar passes do not certify DO bodies or catalog resolution.
3. The five function-default hardening statements remain unexecuted; their
   current preconditions still fail. Existing ownership/executor design remains
   proposed, not implemented or runtime-tested.
4. Owner-approved recovery/isolation, transaction-boundary/sequence handling,
   nested RPC/trigger/row-lock/RLS acceptance and concurrency remain required.
   See [executor plan](../executor-acceptance-plan.md). No new runner, fixture,
   transaction rollback test or migration was executed.
5. Hosted Supabase/PG17 runtime compatibility remains separately unverified.
   No hosted access or deployment occurred; no Attendance/UI changes or Git
   commit/push.
