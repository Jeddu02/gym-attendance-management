# Production recovery implementation results

Prepared 2026-11-16, Asia/Manila. Branch `review/production-recovery`, baseline
`db700c1f42cdf561e3f55d61897ba8eb4948c94e`; HEAD unchanged, no commit created.

**Production decision: NO-GO.** Executable local recovery tooling and an ACL
correction proposal are implemented and tested. A hosted-compatible A02
architecture has not been implemented: preserving the original zero-membership
contract under documented customer permissions remains blocked. The master task
explicitly requires stopping that remediation for Owner approval if an invariant
cannot be preserved. Independent safe phases were completed to the extent below.

No production connection/SQL/data/configuration/role/history change, provisioning,
deployment, commit, push or merge occurred. Original 37 migrations, application
source, 21 Edge entrypoints, runtime shared modules, package files and hosted
configuration remain unchanged. Newly prepared SQL is outside the automatic
migration directory and has no production execution approval. Synthetic mutations
were confined to newly initialized isolated loopback clusters, which were stopped.

## 1. Blocker status

| Finding | Required status | Actual implementation and remaining boundary |
| --- | --- | --- |
| A02 authority | **BLOCKED** | Added PG17-only launcher and actual authenticated non-superuser refusal/rollback probes. P05/P11 rejection is reproduced on PG18, not PG17. No unsupported grant workaround, assertion removal or revised compatible migration architecture is claimed. Owner/provider or separately approved trust-contract redesign still required. |
| A03 effective privileges | **BLOCKED** | Scoped existing-RPC/browser ACL correction and explicit schema-default cleanup implemented; injected PUBLIC access repaired, repeat execution and inherited-leak refusal verified in PG18. Global creator PUBLIC defaults remain FAIL; correcting unrelated future creator defaults needs scoped approval. Hosted authority remains unresolved. |
| A04 legacy compatibility | **NOT VERIFIED** | Executable prerequisite planner, four read-only diagnostic units, normalized-plan/cash conflict fixtures and audit incompatibility refusal tested. Real legacy identities/facts unavailable. No automatic financial/member/audit correction is safe on supplied evidence. |
| A07 object reconciliation | **IMPLEMENTED — AWAITING HOSTED VALIDATION** | Offline SHA-256 metadata comparison, pinned source manifest, stage catalogs and fail-closed drift/prerequisite classification implemented/tested. This status covers tooling only: three production present-marker occurrences are unidentified; full dependency/definition review and any adoption procedure remain NOT VERIFIED. No history repair/automatic skip exists. |

No production blocker is labelled FIXED AND VERIFIED. Local test completion is
not production release acceptance. A05/A06 remain the prior committed fixes.

## 2. Root causes and concrete changes

### A02: executable refusal evidence without weakening the contract

The existing source rejects automatic role-creator ADMIN edges, then requires
ordinary transfers while forbidding their SET/schema-CREATE prerequisites.
Post-transfer DDL and FOR ROLE defaults require additional continuing authority.
See the three earlier A02 documents for exact migration statement indexes and
official provider evidence. P11's own CREATE refusal is at lines 231-237, as
corrected in the remediation design; do not rely on the earlier review's omission.

`scripts/test-recovery-pg17.ps1` requires an installed PG17 executable and exits
2/BLOCKED before creating anything if unavailable or the major differs. It never
accepts a production URL or silently falls back to PG18.

The opt-in `-RecoveryAudit` extension to `scripts/test-database.ps1` creates a
synthetic LOGIN/CREATEROLE actor with SCRAM credentials in its fresh private
cluster. It uses a separate real login connection with current_user=session_user,
not a superuser's SET ROLE approximation. Unchanged P05 and P11 must reject on
their explicit membership guards. Every created reserved role is checked absent
after failed-connection rollback. SHA-256 object catalogs before/after each probe
must match, including after removal of P11's minimal schema/lock fixture grants.

Superuser replay then continues as a **separate engine control**. It does not
prove non-superuser execution works. `docs/A02-REDESIGN-PROPOSAL.md` records the
required Owner decision; no customer-only alternative preserving every invariant
was demonstrated, so that remediation stops rather than granting broader access.

### A03: scoped ACL correction and effective checks

`supabase/recovery/proposals/01-explicit-routine-acls.sql` validates the final
routine security boundary, removes PUBLIC/anon/authenticated EXECUTE in api/private,
removes explicit unsafe schema-default additions for named creators and refuses
if effective browser EXECUTE remains through inheritance. It preserves existing
service/executor allowlists, function bodies and business data. It owns a
transaction and has statement/lock bounds; it is not automatically deployed.

Synthetic fixtures commit a deliberate PUBLIC leak, apply the proposal twice and
verify browser denial with retained service EXECUTE. Another fixture commits
inherited access, runs the proposal expecting refusal, verifies original state
survives that rollback, explicitly cleans only the synthetic leak and reruns
unchanged final assertions. Fixture cleanup SQL is never a production procedure.

`effective-privileges.sql` inspects effective access rather than ACL text alone,
including direct table/view/sequence and column access, role edges/attributes,
schema CREATE and explicit/implicit default risks. Creator inventory includes
application owners, postgres/current actor and roles with relevant explicit
defaults. Type/default fingerprints complement the screen; it does not certify
every provider path or policy expression.

Final synthetic screen: eight PASS, one **FAIL**:
`creator_global_public_function_default`. Schema-specific REVOKE cannot cancel
global implicit PUBLIC EXECUTE. The proposal intentionally does not silently
change every future postgres-created function across unrelated schemas. A03
therefore remains blocked for that decision and hosted authority, despite the
verified existing-object correction. No test PASS overrides this negative result.

### A04: prerequisites, stage context and preserved history

`checks.json` explicitly declares each diagnostic's table/column requirements.
`plan-checks.mjs` returns UNKNOWN for missing columns/tables, denied reads or
active row filtering, rather than attempting queries against an incompatible
baseline. Stage-bound checks need explicit intended next-version context and
become NOT_APPLICABLE_TO_STAGE after their applicable migration. This prevents
mistaking legitimate dated payment_review history after voids for a pre-P13
migration blocker. It never infers applied history from a function name.

Three diagnostic units copy earlier reviewed audit, registration/plan/cash and
lifecycle/payment SQL unchanged into a separate package. A fourth covers walk-in
allocation uniqueness, P13 dated-review/overlap preconditions and legacy NULL
attendance/method bases. Queries return aggregate statuses, never member/payment
rows. Planner readiness is not execution approval. SQL failures/timeouts or
incomplete visibility remain UNKNOWN. Audit verification is UTC and read-only.

The supplied 20-file baseline lacks P04/P11 columns: actual captured synthetic
baseline planning correctly leaves lifecycle/payment and later history checks
UNKNOWN. Post-final planning correctly skips superseded stage-bound checks.
The aggregate dated-review check can return FAIL on a final synthetic correction
dataset, as expected for a **pre-P13** condition; that is not a product regression
or proof of incompatible production data. Direct SQL execution must respect the
documented intended stage, not only whether the columns exist.

No deterministic legacy **data** repair is justified by the supplied aggregates.
Cash sessions, approval/payment bases, overlaps and review terms require real
evidence; old NULL methods/bases must not be guessed. Do not deduplicate receipts,
delete financial history, invent allocations, fabricate approvals/dates, rehash
audit chains, rewrite attendance or label a version applied. A separate approved
forward reconciliation is required for each actual conflict. P04's new random
operation IDs remain a financial-table effect requiring approval and lock review.

### A07: repeatable comparison without automatic adoption

`catalog.sql` produces one private catalog JSON result under READ ONLY/timeouts/
ROLLBACK. It hashes definitions rather than returning function bodies, policy
expressions, trigger arguments or default values. Inventory covers routines,
tables/views/indexes/sequences, columns, constraints, triggers, policies, reserved
role attributes/memberships, schemas, types and explicit default ACLs. It does
not return private records or password catalogs. Names/metadata remain private.

`source-manifest.json` fingerprints all 37 migrations, 21 Edge entrypoints and
17 recursively imported runtime shared modules (including the new CORS helper).
The 17 pending versions match the prior report's P01-P17 dependency sequence.
Each source-stage reference catalog carries the full migration manifest.

`compare-catalog.mjs` validates envelope/algorithm/keys/digests, rejects empty or
duplicate references, checks source hashes at CLI entry and requires matching
PG17 majors unless explicitly labelled --engine-control. It distinguishes
EXACT_METADATA (matching inventoried SHA-256 fingerprints), ABSENT,
PRESENT_DIFFERENT and UNEXPECTED. It outputs sanitized counts and always HOLD;
history, data and authority remain NOT_VERIFIED. Error output omits raw inputs.

This is a pre-execution halt mechanism, not a universal idempotent migration.
Same-name changed overload/column/default/owner/ACL/index/constraint is not adopted.
Repeated comparison is deterministic and does not mutate inputs. Mixed/interrupted
states are compared with expected prior/next stages and held on any mismatch.
No drop, IF NOT EXISTS rewrite, apply, skip or history-marking operation exists.
Fingerprints are not complete database equivalence: pg_depend/provider-object
coverage and effective privileges still require private review and tests.

Final source-stage versus post-proposal synthetic reference: **1,074 matching
inventoried fingerprints, zero absent/different/unexpected**. This narrow engine
control establishes that the tested repair/cleanup leaves inventoried security
metadata stable. It does not identify the three production occurrences or certify
their definitions. A matching object still needs a reviewed reconciliation
decision before any original migration is run.

## 3. Commands actually run and results

| Check | Result and scope |
| --- | --- |
| `npm.cmd run lint` | PASS; repeated after code changes |
| `npm.cmd run typecheck` | PASS |
| `npm.cmd run build` | PASS including PWA generation |
| `npm.cmd test` | PASS 38/38 existing tests |
| `node --test tests/recovery.test.mjs` | PASS 7/7 new regression tests, final SHA-256/stage-aware version |
| `npm.cmd run test:security` | PASS static source checks; no environment-file reads |
| Cached Deno shared tests | PASS 105/105; synthetic inputs, no hosted requests |
| Cached Deno check on 21 index.ts paths | PASS 21/21 |
| `node scripts/test-browser.mjs --production` | PASS mobile/Owner navigation, unavailable/empty/retry states, payment/walk-in, QR/PIN, PWA static caches; intercepted synthetic Auth/API only |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1` | **BLOCKED, exit 2**; installed local major is 18, no PG17 environment provisioned |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-database.ps1 -RecoveryAudit` | PASS final fresh PG18 run: 37 migrations, P01-P17 source-stage snapshots, two authenticated refusal/rollback probes and before/after catalog comparisons, nine concurrency races, all existing phase suites, new ACL/legacy/effective checks |
| Same engine-control command with `-TestLegacyAuditRefusal` | PASS expected incompatible-UTC-chain refusal and preserved-hash assertions; stops intentionally at P06, not full-sequence acceptance |
| All 37 original files through cached PG17 parser | PASS 993 top-level statements; BOM normalized only in parser memory |
| Final new SQL through cached PG17 parser | PASS syntax; diagnostic top-level transaction/settings/SELECT/visibility DO only. Parsing does not resolve objects or prove permissions |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS PG17/PG18 AST/exact SELECT/source-hash checks for all 16 approved variants; originals unchanged |
| Offline actual synthetic catalog comparison/planning | PASS stable final metadata; detected source-stage additions and baseline missing prerequisites; post-stage checks excluded |
| `git diff --check`, original migration/Edge/src/config/package diff | PASS |
| Actual PG17 full migration execution / hosted Auth-Edge-PostgREST-SQL / production data fit | **NOT RUN / NOT VERIFIED** |

There is no revised A02 success test: actual non-superuser probes pass by
**refusing** unchanged SQL. The complete SQL replay remains a genuine-superuser
PG18 control. The standalone ACL proposal also still needs hosted ownership/default
authority; it is not a way to bypass A02.

During implementation, preliminary runs exposed catalog text-type coercion,
PowerShell error-string formatting and a missing synthetic schema-USAGE lock
prerequisite; these were fixed and covered by the final passing run. One fresh
synthetic startup failed during earlier parallel checks; its cause was not
established. The final clean run passed and all clusters were stopped. Earlier
failed logs are retained privately; they are not relabelled as PASS.

Private synthetic evidence, ignored by Git:

- Final SHA-256/full recovery run: `.cache/security-test-6197bd5471e64f59b40119add1f0a2fa`.
- Incompatible-audit control: `.cache/security-test-460699ae332d4dfcbb12f63eb72f22ba`.
- Browser control: `.cache/browser-test-ac3cbcdf-4a0f-4a4b-8a2c-eaf7c90561df`.

No credentials or raw metadata should be exported from those directories. Test
password/bootstrap files were deleted by the harness. The audit-refusal run
preceded the final fingerprint format; use the final run for catalog evidence.

## 4. Recovery/approval decisions still required

1. A02: supported provider capability and PG17 rehearsal, or explicit separate
   architecture/trust-contract redesign. No automatic ADMIN exception is approved.
2. A03: creator-wide default scope and actual inherited/default privilege evidence;
   exact correction inventory/operator approval before any hosted use.
3. A04: authorized full-visibility diagnostics, actual legacy evidence and separate
   decisions for cash, membership, receipt, overlap/attendance and audit conflicts.
4. A07: privately identify all three present occurrences, compare exact stage
   definitions/dependencies and approve any reconciliation. Never alter migration
   history merely because a fingerprint matches or source file is unrecorded.
5. PG17 authorized isolated environment, real hosted-compatible operator/runner
   tests, backup/restore/key-custody evidence, RPO/RTO and traffic/lock/abort plan.
6. Actual api exposure, server settings, missing Edge deployment dependencies,
   full synthetic Auth/Edge/PostgREST business acceptance, then separate Owner
   approval for migrations/Edge/Pages release and operational opening.

Automatic approval review rejected a bundled action that also proposed adding
npm shortcuts to package.json, citing the earlier configuration-change restriction.
That optional change was not performed. The tests were executed directly instead;
no package/configuration approval is needed to review these results. This does
not authorize bypassing that rejection or a later configuration edit.

## 5. Exact task file inventory

The table below lists this task's additions/modification. Three already-untracked
documents (`docs/A02-EXECUTOR-HARDENING-REVIEW.md`,
`docs/A02-REMEDIATION-DESIGN.md`, `docs/A02-PROVIDER-COMPATIBILITY.md`) were preserved
and are not new implementation changes. No application business rule changed.

| File | Change |
| --- | --- |
| `docs/A02-REDESIGN-PROPOSAL.md` | Added |
| `docs/PRODUCTION-RECOVERY-IMPLEMENTATION-RESULTS.md` | Added |
| `scripts/recovery/compare-catalog.mjs` | Added |
| `scripts/recovery/plan-checks.mjs` | Added |
| `scripts/test-database.ps1` | Modified |
| `scripts/test-recovery-pg17.ps1` | Added |
| `supabase/recovery/catalog.sql` | Added |
| `supabase/recovery/checks.json` | Added |
| `supabase/recovery/diagnostics/additional-legacy-blockers.sql` | Added |
| `supabase/recovery/diagnostics/audit.sql` | Added |
| `supabase/recovery/diagnostics/lifecycle-payments.sql` | Added |
| `supabase/recovery/diagnostics/registration-plan-cash.sql` | Added |
| `supabase/recovery/effective-privileges.sql` | Added |
| `supabase/recovery/proposals/01-explicit-routine-acls.sql` | Added |
| `supabase/recovery/README.md` | Added |
| `supabase/recovery/source-manifest.json` | Added |
| `supabase/tests/recovery_inherited_cleanup.sql` | Added |
| `supabase/tests/recovery_inherited_leak.sql` | Added |
| `supabase/tests/recovery_legacy_behavior.sql` | Added |
| `supabase/tests/recovery_security_behavior.sql` | Added |
| `tests/recovery.test.mjs` | Added |

21 task files; all changes remain uncommitted. Review instructions and exact local commands are in `supabase/recovery/README.md`.

**Stop for Owner review. Production remains NO-GO; no commit/push/deployment follows.**
