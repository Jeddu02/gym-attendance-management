# Minimal catalog investigation — November 6, 2026

Latest addendum: queries 10/11 passed and establish that all ten flags are
implicit built-in defaults, not explicit/inherited default-ACL configuration.
The corrected type expectation leaves five function-default hardening blockers,
with no current scoped browser routine/table exposure. See
[../default-privilege-proposal.md](../default-privilege-proposal.md).
The original nine-query evidence and historical interpretation below remain
preserved. The comparator now checks all eleven safe query sources/observations.

**NOT READY for local execution review.** Nine individually reviewed queries
were accepted and completed with psql exit 0. No narrowed query was rejected.
The earlier large export had three automatic-review rejections; it never
produced a snapshot. `../inspect-catalog.sql` now contains only query 01.

Protected preflight was rerun and passed before these queries: approved marker
`f497fabb-a12f-4068-b745-8b0729279276`, system identifier
`7704603813616068820`, canonical directory
`C:\Users\Banco-Sual\AppData\Local\GYMFORCE-PG18-TEST\data`, database
`gymforce_pg18_test`, endpoint `127.0.0.1:55432`, postgres session/current role,
and required SCRAM authentication. Identity files/pgpass ACLs were checked by
the existing protected preflight. No passwords or verifiers were printed.

Each query additionally verifies the exact approved identity inside its own
READ ONLY transaction, with a 15-second statement timeout. A false identity
causes division by zero and ON_ERROR_STOP=1 stops the client. Each connection
used `-X -w`, explicit endpoint/user/database, `require_auth=scram-sha-256` and
`connect_timeout=5`. Every successful query ended with ROLLBACK. This is not
a migration runner; no runner was implemented or promoted.

## Accepted queries and permitted evidence

| Query | Result | Verified evidence |
|---|---|---|
| 01 identity/counts | Accepted, exit 0 | Identity matched; transaction_read_only=on; 22 tables, 110 non-NOT-NULL constraints, 57 indexes, 25 routines |
| 02 tables | Accepted, exit 0 | All 22 expected table names: postgres-owned, RLS enabled, FORCE disabled; three expected sequences postgres-owned |
| 03 constraints/indexes | Accepted, exit 0 | Exact constraint names/table bindings/classes: 22 PK, six UNIQUE, 30 FK, 51 CHECK, one exclusion; all validated, expected deferral flags. All 57 index names/table bindings match, valid and ready; primary/unique/exclusion flags match |
| 04 columns | Accepted, exit 0 | All 149 ordered column identifiers/types/nullability/default-presence/identity/generated flags match source contract. Three ALWAYS identities and one stored generated column |
| 05 routines | Accepted, exit 0 | 25 unique scoped names; language/kind/owner/security/strictness/set/leakproof/volatility/parallel/input-count/default-count match current baseline. Exact empty-search_path configuration boolean true for every routine. No public/graphql_public routines. 16 API definers allow service_role EXECUTE and deny anon/authenticated; nine private routines deny those callers, seven remain definers and two invokers |
| 06 table privileges | Accepted, exit 0 | 154 table/role combinations checked: no table/column privileges for any of the seven harness roles |
| 07 triggers/rules | Accepted, exit 0 | Exact 13 expected user trigger names/table bindings, all enabled O; no rewrite rules |
| 08 defaults | Accepted, exit 0 | 20 creator/kind checks; **10 actual non-owner global default-grant flags**: function and type defaults for postgres, gym_data_owner, both executors and gym_registration_login. No non-owner schema-default additions observed |
| 09 roles/schemas | Accepted, exit 0 | All seven harness roles restricted; only registration login can log in; no schema CREATE or membership edges for these roles; only service_role has api schema USAGE |

These observations verify current baseline structure, not the proposed
post-migration executor behavior. Postgres ownership/FORCE-disabled state is
the known hardening gap, not a newly discovered ownership regression. No
privileges or ownership were changed to obtain matching results.

## Catalog normalization versus real discrepancies

Eleven type-format differences are legitimate whitespace normalization:
PostgreSQL prints numeric precision/scale without the source lexer's spaces.
Canonical tokens match exactly. `findings.json` identifies only these safe
column identifiers, not expression contents.

The ten default-privilege flags are **actual failures of the draft's default
ACL preconditions**, not deparser normalization. The boolean observations do
not identify grantees or distinguish implicit from explicit grants. No claim
that a particular grantee received these privileges is made. Resolving the
defaults requires separate reviewed work; do not relax the guards or assume
one creator's defaults apply to another.

No incorrect expected structural definitions were found in the properties
that could be compared safely. That does not certify complete definitions.

## Intentionally unresolved

- Constraint expressions, index expressions/predicates/key order, foreign-key
  target/actions and exclusion operators were not exported or certified.
- Column default/generated expression **presence** matched; values did not
  leave the server. IN/ANY, TRIM/btrim and inserted-cast compatibility remain
  unverified; they must not be inferred from matching object names/counts.
- Routine input/default counts matched; exact signatures, argument/result
  types/modes/default values, function bodies and implementation identity were
  not exported or certified. No raw configuration arrays were read into an
  artifact. Only an exact-equality boolean was selected for the approved empty
  search_path configuration.
- Trigger identity/enabled status matched, but definitions/arguments and
  runtime order/behavior remain unverified. Sequence privileges/bindings and
  policy definitions/runtime RLS behavior were not certified by these queries.
- No migration, assertion draft, fixture, RPC or application-data query ran.
  These independent read-only transactions are not an atomic whole-database
  snapshot or a before/after mutation-preservation test.
- Hosted Supabase and PostgreSQL 17 remain untested. Runtime executor acceptance,
  SQL parsing/compilation and a future fail-fast execution plan remain separate.

Further definition alignment must use separately reviewed, specific server-side
comparisons against approved source expectations returning booleans only.
It must not restore the old general export, export hashes as an approval-review
workaround, guess canonical definitions, or modify the database to pass checks.

## Files and offline validation

`01`–`09` SQL files are fixed, narrow query sources. `01`–`09` observed CSVs
contain only permitted structural rows/booleans. They contain no member/payment
records, secrets, definitions, function arguments/defaults or raw ACL/config
arrays. `findings.json` is an offline summary of comparisons, not an approved
catalog baseline for executable migrations.

`../prepare-minimal-inspection.mjs` writes these fixed queries only; it never
connects or launches PostgreSQL. `../compare-minimal-catalog.mjs` reads only
local CSV/contracts and audits the query fields. It rejects prohibited raw
metadata, wildcard exports, non-read-only commands and raw configuration
selection, then checks exact structural names and flags. It reports known
security blockers separately from comparator success.

```powershell
node docs/drafts/foundation-2026-11-06/compare-minimal-catalog.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/drafts/foundation-2026-11-06/validate-offline.ps1
```

The comparator exits 0 only when the current structural observations match;
its successful exit is **not** a deployment/readiness approval. It prints
NOT READY and records the ten default-ACL blockers. No executable SQL draft,
active assertion, original migration, role or privilege was changed in this
follow-up. No commit/push or hosted change occurred.
