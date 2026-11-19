# Phase 5.2 — hosted readiness results

2026-11-17, Asia/Manila. Source: `master`,
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`. Intended project:
`alxhytivwybjbkjjdsyn`. **Hosted verification UNVERIFIED; diagnostic session
NO-GO pending complete authorization.** No hosted connection or SQL execution.

## Evidence and local preparation

Reviewed the current-phase assessment, authorization form, hosted approval/plan/
decision documents, final readiness and PG17 review, compatibility implementation,
source-integrity policy, recovery diagnostics and relevant tests. Older documents
retain review-branch/uncommitted-work references; those describe their preparation
context, not this task's clean starting baseline on master.

| Check | Result | Limit |
| --- | --- | --- |
| Baseline branch/SHA and clean starting tree | PASS locally | No fetch or hosted state observation. |
| 30 candidate hashes against existing plan and form | PASS locally | 27 exact file byte hashes; H01–H03 use LF text plus one final LF. No expected hash or SQL changed. |
| Scope and expanded order | PASS locally | 25 metadata / five confidential aggregate units; no unit approved automatically. |
| PG17 and PG18 AST safety screens | PASS locally | Explicit transaction boundaries, local settings, nested mutation/lock rejection and reviewed builtin calls. Not a hosted permission proof. |
| Existing approval completeness | BLOCKED | Form remains DRAFT/unchecked; actor/client, selected units, window, custody, retention, privacy and cleanup decisions are incomplete. |
| Actual target, actor, hosted PG version, visibility and permissions | UNKNOWN | Must be established through approved existing Owner access; a project reference in a document cannot verify a connection. |
| Real backup/restore and maintenance evidence | UNKNOWN | No backup capture, restore or traffic-control change authorized or performed. |

New repeatable check: `node scripts/recovery/validate-hosted-package.mjs`.
Regressions: `node --test tests/hosted-package.test.mjs` (4/4 PASS).
The checker reads files and parses SQL only. In Git it also requires the unchanged
review plan/form to match HEAD. It neither connects nor authorizes execution.

All units keep REPEATABLE READ READ ONLY, 30s statement / 2s lock timeouts,
pg_catalog search path and ROLLBACK. The audit file also sets transaction-local
UTC. One existing DO in unit 30 is the reviewed visibility/RAISE-only block;
its exception is pinned to the unchanged full-file hash, not a generic DO allowance.
SELECT is not inherently safe: application RPCs and unreviewed function calls
are rejected by the local screen. This is a finite reviewed package, not a
general-purpose SQL sandbox or proof against a compromised server/parser.

## Exact proposed order

The authoritative SQL and hashes remain in
[the unchanged plan](HOSTED-READINESS-DIAGNOSTIC-PLAN.md) and
[authorization form](HOSTED-DIAGNOSTIC-AUTHORIZATION-FORM.md).

| Expanded order | Unit |
| --- | --- |
| 1 | H01 context |
| 2 | `supabase/recovery/history.sql` |
| 3 | `supabase/recovery/catalog.sql` |
| 4–18 | `docs/production-preflight/sql-editor/01-01-identity.sql` through `01-15-indexes.sql`, exact existing manifest names in order |
| 19 | `docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql` |
| 20 | `supabase/recovery/diagnostics/compatibility-authority.sql` |
| 21 | `supabase/recovery/diagnostics/migration-authority.sql` (original contract) |
| 22 | `supabase/recovery/effective-privileges.sql` |
| 23 | H02 inherited graph / creator defaults / routine security |
| 24 | `supabase/recovery/compatibility/review/effective-privileges.sql` (revised contract) |
| 25 | `supabase/recovery/diagnostics/legacy-dependencies.sql` |
| 26 | H03 baseline finance / attendance aggregates |
| 27 | `supabase/recovery/diagnostics/registration-plan-cash.sql` |
| 28 | `supabase/recovery/diagnostics/audit.sql` |
| 29 | `supabase/recovery/diagnostics/lifecycle-payments.sql` — conditional |
| 30 | `supabase/recovery/diagnostics/additional-legacy-blockers.sql` — conditional |

Recommended first metadata subset for Owner selection: **1, 2, 3, 19, 20, 22,
23, 25**, in that order. It establishes context, stage, object fingerprints,
marker identities, revised authority prerequisites, effective privileges,
creator defaults and legacy dependencies. Unit 22 is stage-sensitive: a
pre-hardening failure is evidence for review, not an automatic remediation.
Add individually approved split inventories when fingerprints alone cannot
explain a discrepancy; use 21/24 to explicitly compare original/revised boundaries.
This subset does not certify complete release readiness.

Only after prerequisites and separate D-DATA approval, select 26–28. Before
29–30, verify **every** prerequisite in `supabase/recovery/checks.json`: P04
payment columns for 29; P10/P11 method/basis columns for 30. Missing columns,
denied SELECT or active RLS filtering mean SKIP/UNKNOWN; never add privileges,
columns or policies to run a diagnostic. No automatic error retry.

## Historical evidence and privacy

Owner-supplied historical evidence: 20 recorded migrations through
20261030180000; 17 unrecorded versions; 91 marker occurrences, 88 absent and
three present without history; ENABLE RLS on 22 tables; 51 valid/ready indexes;
14 earlier missing Edge endpoints. None was refreshed. Three occurrences do
not identify three distinct objects. Final source expects 33 protected tables.

Keep full results Owner-private. Catalog fingerprinting reads function bodies,
policy/default expressions internally to hash them; it does not return their
text. Signatures, owners, grants, OIDs and fingerprints remain security metadata.
Aggregate business checks are confidential and can scan/join whole tables;
audit/window and overlap checks may be expensive despite bounded timeouts.
Read-only queries can acquire read locks and conflict with DDL. Record private
timing/visibility/completeness; timeout is UNKNOWN, never permission to extend limits.

Sanitized evidence template:
`unit/order | reviewed hash match | approved target/actor match | UTC window |
stage/prerequisites | full visibility/results | status/category | transaction
closed | private custody reference`. Share approved object classifications or
counts only, never raw bodies/graphs/records/errors, PINs, tokens or credentials.

Stop on target/actor/hash mismatch, error, timeout, cancellation, truncation,
unknown transaction closure or missing prerequisite. Roll back/close the actual
session and confirm cleanup privately; a later SQL Editor click may use another
backend. If result grids are incomplete, hold for an approved complete-result
client; retain ROLLBACK. Scripts 03–07 remain held. Diagnostic approval never
authorizes migrations, history changes, grants, configuration or deployment.
