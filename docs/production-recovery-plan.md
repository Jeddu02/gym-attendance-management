# GYMFORCE production migration reconciliation and recovery plan

Prepared 2026-11-16, Asia/Manila. Target: `alxhytivwybjbkjjdsyn`.

**Decision: NO-GO / HOLD production changes.** Review branch verified locally:
`review/production-recovery`, HEAD `38fdf66` (matching the requested baseline),
with a clean working tree at audit start. No checkout, merge, fetch or push was
performed. Sections 11–14 record this baseline audit, exact source references,
integration findings and fresh local test results. This is a local source review and an
approval-gated recovery plan, not an executable migration runbook. No production
SQL, migrations, history repair, permissions changes, endpoint deployment or
application deployment was performed in preparing it. No credentials were
requested or inspected. Only this existing report is updated in this audit.
Local synthetic tests may create isolated ignored cache/build outputs; they do
not change application behavior or access production. Findings identified here
remain unfixed because behavior changes are outside this audit's authorization.

## 1. Evidence and conclusions

| Evidence | Status | What it establishes / does not establish |
| --- | --- | --- |
| 37 migration files in `supabase/migrations/`, sorted by version | PASS, local inspection | Their intended changes and order; not hosted definitions. |
| Owner's 20 recorded production versions | PASS, supplied evidence | They match the first 20 local files, through `20261030180000`. A history record does not verify its current objects or original applied SQL. |
| 17 unrecorded versions | FAIL, release alignment | Pending reconciliation, not automatically safe to apply. |
| Owner's marker result: 91 occurrences, 88 absent, 3 present without history | PASS, supplied aggregate only | Significant object/deployment gap; individual marker identities and per-version results are UNKNOWN. This report has no raw output to assign the three present occurrences. |
| RLS enabled on all 22 inventoried production tables | PASS, supplied narrow finding | ENABLE RLS flags on that inventory; not FORCE RLS, correct owners/policies, absence of bypass paths, or complete final-release coverage. |
| Default ACL review | UNKNOWN | No full creator/scope/grantee output supplied. Unsafe effective defaults are a release blocker if found. |
| 14 Edge endpoints previously missing | FAIL, previously evidenced | Missing deployed handlers, independent of SQL migrations. Earlier reports record gateway 404; this task makes no new network probes. |
| Prior Owner index result: 51 indexes valid/ready | Historical narrow PASS | Does not verify expected definitions, predicates, uniqueness, ownership or constraints. |
| Migration-role ownership authority, audit integrity, legacy data compatibility, backups | UNKNOWN | Required before any production apply. |

Source references: [current stabilization report](STABILIZATION-2026-11-16.md),
[earlier complete bug/deployment report](STABILIZATION-2026-11-11.md),
[preflight review](production-preflight/README.md),
[SQL Editor package](production-preflight/sql-editor/README.md),
`supabase/tests/` and `scripts/test-database.ps1`.
The new Owner findings above supersede older reports saying no marker or RLS
results were supplied. They do not fill in the missing row-level metadata.

### Marker coverage correction

The local VALUES list contains **91 occurrences describing 79 distinct
kind/object/column markers across 15 migration versions**. It was derived from
the set of 17 pending migrations, but two have **zero declaration markers**:
executor hardening (`20261110100000`) and audit timezone (`20261110103000`).
Earlier package wording “across 17 versions” is imprecise; it is not complete
coverage of those 17 migrations. Approved SQL and package files are unchanged.

The marker query checks function **names**, accepting any function overload;
it does not compare signatures, bodies, owners, configuration or ACLs. It omits
indexes, constraints, policies, defaults, roles and most ALTER effects. Multiple
versions intentionally replace the same routines. Thus 3 present occurrences
need not mean 3 distinct objects, 88 absent occurrences need not mean 88 missing
objects, and neither count establishes which migrations are compatible.
Even the baseline already defines `api.member_enroll_pin`, a name reused in a
pending marker; its presence would not prove the pending recovery changes.
Do not infer the identities of the reported three from this example.

Read-only inventories taken in separate SQL Editor transactions are separate
snapshots. Record their times/context and reconcile them again during an
approved quiet window before relying on combined conclusions.

## 2. Inspection of all 37 migrations in chronological order

All paths in the next two tables are relative to `supabase/migrations/`.
The first 20 are recorded according to supplied history. **Do not replay them.**

| # | Recorded migration filename | Intended foundation / dependency relevance |
| --- | --- | --- |
| 1 | `20261028061728_initial_schema.sql` | pgcrypto, private schema, public gym settings, Owner registry, members, audit events; PHP/Manila seed settings and initial RLS/revocations. |
| 2 | `20261028062516_membership_core.sql` | Plans and one-calendar-month purchase snapshots, state/date constraints, RLS. |
| 3 | `20261028062602_payment_ledger.sql` | Original receipts, whole-receipt allocations, payment events/corrections; finance history preserved separately from eligibility. |
| 4 | `20261028062706_walkin_attendance.sql` | Fee versions, provisional requests, check-ins, validity resolutions; partial unique daily-member and per-walk-in attendance indexes. |
| 5 | `20261028062757_owner_security.sql` | Invoker Owner helper using Auth identity; direct client revocations. Not the later verified-actor RPC mechanism by itself. |
| 6 | `20261028062853_member_pin_security.sql` | Hashed PIN credentials, one-use capability hashes, attempt buckets; no plaintext PIN. |
| 7 | `20261028062935_cash_reconciliation.sql` | Original drawer sessions and reconciliation/adjustment history; later daily procedure refuses legacy sessions. |
| 8 | `20261028063027_audit_integrity.sql` | Audit stream/head structure and nullable foundation hash fields. |
| 9 | `20261028063404_integrity_fixes.sql` | Allocation foreign key to walk-in request. |
| 10 | `20261028063446_membership_overlap_guard.sql` | btree_gist and dated membership exclusion constraint; later corrections replace its predicate while retaining history. |
| 11 | `20261028063638_payment_integrity_guard.sql` | Additional finance access revocations. |
| 12 | `20261028064100_database_security_foundation.sql` | Server-only api schema boundary. |
| 13 | `20261029100000_owner_authorization_rpc.sql` | `api.is_active_owner_for_user(uuid)`, service-only lookup of verified actor status. |
| 14 | `20261030120000_audit_chain_enforcement.sql` | Canonical hash, controlled append/verification and append-only triggers. Includes historical event UPDATE/head DELETE/backfill when originally installed: replay would risk rewriting original history. |
| 15 | `20261030130000_owner_register_member.sql` | Owner-only registration with encrypted/keyed mobile fields and audit append. |
| 16 | `20261030140000_owner_create_pin_enrollment_token.sql` | Original setup-token issuance and active-enrollment index. Later verified-attestation wrapper removes service access to this original issuer. |
| 17 | `20261030150000_member_pin_enrollment.sql` | Original one-use enrollment routine; later replaced by stricter eligibility/locking implementation. |
| 18 | `20261030160000_global_pin_enrollment_rate_limit.sql` | Initial aggregate enrollment limiter. Superseded by next recorded migration. |
| 19 | `20261030170000_rolling_pin_enrollment_rate_limit.sql` | Drops original limiter function/table and installs rolling event table/routine. Do not recreate the superseded table as a repair. |
| 20 | `20261030180000_owner_list_members.sql` | Scoped Owner member directory returning id, memberCode, fullName, status and createdAt. No mobile ciphertext/hash or decryption is part of this list contract. |

### Pending migration compatibility matrix and execution order

P01–P17 are review identifiers, not new version numbers. Marker count is the
number of local occurrences for that version, **not a production presence
classification**. For every row, production compatibility is **UNKNOWN/HOLD**
until the named checks pass; all 17 versions are unrecorded in supplied history.
Dependencies shown are principal predecessors in addition to the recorded
baseline. Use the complete ascending order, not a subset inferred from missing
frontend pages.
Section 12 distinguishes direct source prerequisites from conservative release
sequencing and governs any minimal-dependency interpretation of this matrix.

| Order / filename | Principal dependencies | Intended objects / effects | Markers | Conflict, validation and recovery gate |
| --- | --- | --- | --- | --- |
| P01 `20261103080000_owner_membership_plans.sql` | Baseline plans, Owner lookup, append audit | CREATE OR REPLACE plan list/save RPCs; normalized-name unique expression index | 2 | Refuses normalized duplicate names, potentially including private names in its exception. IF NOT EXISTS index does not verify an existing same-name index. Verify exact expression/uniqueness/validity; compare any existing routine overloads and result types. |
| P02 `20261103100000_owner_create_membership_purchase.sql` | P01 and baseline plans/members/purchases/audit | CREATE OR REPLACE purchase creation RPC; server price snapshot and pending state | 1 | Existing overload/return/argument-name differences can block replacement or leave unintended overloads. Preserve approved members, positive price and immutable snapshot semantics. |
| P03 `20261103110000_owner_list_membership_purchases.sql` | P02 | CREATE OR REPLACE scoped purchase-history RPC | 1 | Exact parameter/default/result contract and ownership/ACL must match; P04 and P16 later replace this body. |
| P04 `20261103120000_owner_membership_payments.sql` | P01–P03 and baseline receipts/allocations/events | operation_id and target_membership_purchase_id columns, 5 indexes, 10 triggers, 5 guards and 5 API routine definitions including purchase-list replacement | 12 | Unconditional ADD COLUMN/index/trigger creates can collide with partial objects. Unique allocations/references/pending targets require legacy checks. DEFAULT gen_random_uuid on NOT NULL operation_id populates identifiers for existing receipts and may rewrite the table; this is a production financial-table effect requiring approval. No legacy target inference is supplied. |
| P05 `20261110100000_executor_hardening.sql` | Exact P01–P04 output | 3 reserved roles; ownership/ACL/FORCE RLS changes on 22 protected tables and 25 routines; 34 command-scoped policies, sequence/column bounds and default function revocations | 0 | Strict body/owner/config/ACL/trigger/index/constraint inventories refuse drift. Requires hosted authority proof; pre-hardening baseline differs from final state. ACCESS EXCLUSIVE locks all 22 tables. Not idempotent and not screened by marker count. |
| P06 `20261110103000_audit_timezone.sql` | P05 exact restricted hash helper and verifier | Verify all audit streams/heads under UTC, then pin hash helper TimeZone=UTC | 0 | Refuses incompatible stored chains; no rehash/backfill allowed. Audit tables locked exclusively. Missing marker declarations say nothing about compatibility or current timezone. |
| P07 `20261110110000_membership_lifecycle.sql` | P04–P06 | 5 private lifecycle helpers/guards, approval and activation RPCs, 2 triggers; future payment-event default uses clock_timestamp | 7 | Refuses inconsistent approval/dated/payment states. Existing functions/triggers collide with plain CREATE. Approval/full payment/server Manila dates and Option A expiry must pass before apply; no backdating or guessed repair. |
| P08 `20261110120000_owner_reporting.sql` | P05, P07; baseline attendance/audit | Dashboard summary and audit-list RPCs; Owner attendance read policy/grants | 2 | Plain CREATE functions/policy can collide. Confirm privilege bounds and exact confirmed-income/valid-attendance definitions; P16 replaces summary. |
| P09 `20261110130000_pin_recovery.sql` | P05–P07; baseline rolling limiter | Verified enrollment issuer, recovery issuer, reset RPC, replacement enrollment body; credential column/policy additions; old issuer service EXECUTE revoked | 4 | Plain CREATE/policy conflicts; replacement compatibility; verify original issuer is no longer callable by service_role and PIN verifier is unreadable except later check-in executor. Gates remain disabled; development token/KDF settings are not production approvals. |
| P10 `20261110140000_walkin_operations.sql` | P04–P06, restricted executors; retain earlier lifecycle/reporting/PIN stages | requested_payment_method column; walkin_request_rate_events and receipt_review tables; 3 indexes, 8 triggers, 5 guards; fee/create/list/confirm RPCs | 12 | Unconditional objects may collide. Duplicate historical walk-in allocations block unique index. Legacy method stays NULL; no repricing/backfill/revival. New request lifetime is 15 minutes; fee/limiter values require explicit Owner configuration/approval. |
| P11 `20261110150000_member_checkin.sql` | P07, P09, P10 and restricted audit append | gym_checkin_executor, member_checkin_rate_events, membership_purchase_id attendance FK/index/check, eligibility/guard, reserve/prepare/commit RPCs | 7 | Reserved role must be absent or safely unused; membership/ownership/grants can force refusal. No automatic legacy attendance-basis backfill. Exact authority and default ACL proof required again for new role. |
| P12 `20261110153000_owner_attendance.sql` | P08, P11 | Owner attendance RPC and validity-resolution SELECT policy/grants | 1 | Plain CREATE function/policy collisions; preserve invalidated history and distinguish valid totals. Prerequisite for correction resolution privileges. |
| P13 `20261110160000_receipt_review_corrections.sql` | P07–P12, especially walk-in and check-in bases | 4 append-only verification/void/replacement tables, receipt record/verify/list/void RPCs, attendance invalidation guards, replacement lifecycle/payment guards and membership overlap constraint | 14 | Existing payment_review terms explicitly refuse migration. Exact named overlap constraint must exist; replacing it can fail on legacy overlaps. New tables/policies/triggers/functions can collide; append-only originals and invalidation must survive rollback. |
| P14 `20261110170000_cash_operations.sql` | P13 verified-receipt helper and finance corrections | Daily drawer business_date/operation_id, reason/evidence columns, unique day constraint, cash_reconciliation_receipts table, append-only/close triggers and open/close/list RPCs; future receipt timestamp default | 9 | Refuses ANY legacy cash_drawer_sessions row. NOT NULL additions and uniqueness also need empty/compatible reconciliation state. No invented historical opening attestation, date, reason or evidence. New columns/objects can collide. |
| P15 `20261110180000_provisional_claims.sql` | P07, P11, P13 eligibility/void semantics; retain P14 order | owner_attendance_claims and owner_claim_resolutions, operation uniqueness/FKs, append-only policies/triggers and submit/resolve/list RPCs | 5 | Plain CREATE collisions; persistent offline queue/retention still gated. Current Manila date presence only; old/conflicting claims remain review or reasoned no-attendance resolution. |
| P16 `20261110190000_receipt_allocation_review.sql` | P04, P07, P08, P10, P11, P13; retain P14–P15 | receipt_allocation_reviews, helper/allocation RPC; replacements of 8 eligibility/payment/walk-in/reporting routines | 11 | Plain CREATE plus replacement signature/owner/ACL risks. Receipt must be verified/exact/unallocated, one target only, original target respected; no combined receipts, refunds, silent restoration or expired walk-in revival. |
| P17 `20261110200000_operational_reports.sql` | P08, P13, P16 | Income, expiry-reminder and payable-purchase RPCs; service-only Owner execution | 3 | Plain CREATE/signature conflicts. Final payment handler requires payable RPC; reporting handler requires final income/expiry RPCs. Pending/unallocated/void money must not become confirmed income. |

P01–P04 are **inputs** to P05, not proof that the payment subsystem can be
released independently. The final handlers depend on later lifecycle, receipt
review, allocation and reporting behavior. Do not expose an intermediate schema
to production traffic or selectively deploy a list-only endpoint while its
other actions depend on missing objects.

## 3. Dependency analysis and security boundary

The principal chain is baseline → P01–P04 → P05 → P06 → P07 → subsequent
operations → P16 allocation semantics → P17 reporting/payables. Key cross-links:

- Every Owner RPC depends on the active Owner registry and controlled audit
  append, even when it does not call `is_active_owner_for_user` by name.
- P05 pins exact P04-era function bodies and dependent object definitions.
  An individually “equivalent” manual definition or extra routine may refuse
  hardening; preserve its assertions rather than bypassing them.
- P09 replaces the old PIN-enrollment boundary. Deploying the current enrollment
  token handler against only the recorded baseline fails because it calls the
  new verified issuer, not the original issuer.
- P11 eligibility uses approved membership and full confirmed allocated payment;
  P13 adds explicit void exclusions and P16 reviewed allocations must be
  recognized by check-in, lifecycle, dashboard and both payment/purchase lists.
- P12 is needed before P13's attendance-validity resolution writes; P14 depends
  on actual-receipt verification, not confirmed-income totals; P15 depends on
  server eligibility and must not trust device date as historical attendance.
- P17's payable RPC is called by the current payment page's selector and refresh.
  P04 payment-list presence alone is insufficient to make that page work.

### SECURITY DEFINER and executor review

Local source uses empty function search paths and qualified application objects.
P05 changes nine private helpers to invoker semantics and leaves sixteen
then-existing API entrypoints as SECURITY DEFINER under bounded executors.
Subsequent API entrypoints follow that model; private business/trigger helpers
are invokers. Intentional exceptions require attention rather than blanket
function grants:

| Identity / boundary | Intended final scope | Acceptance requirement |
| --- | --- | --- |
| gym_data_owner | NOLOGIN/non-superuser/non-bypass/no membership; protected tables and private helper ownership | FORCE RLS, no externally reachable membership/SET ROLE path; not a routine login or application credential. |
| gym_owner_executor | SECURITY DEFINER Owner operations; narrowly granted columns and command policies | Caller identity must come from verified Auth and each privileged RPC must independently enforce active Owner. CURRENT_USER policy predicates alone do not authenticate an Owner. |
| gym_public_executor | Narrow one-use PIN and provisional walk-in operations | No unrestricted member/receipt reads, no public eligibility disclosure, no confirmed payment authority. |
| gym_checkin_executor | Only rate/lookup/credential-version/eligibility/attendance duties from P11 | Credential hash SELECT only on this trusted path, bounded server response, no hash in client result/log/cache; not login, Owner or direct service-role table access. |
| service_role | Trusted Edge transport may execute approved api RPCs | No direct protected table/column/sequence privileges in final boundary; private schema not exposed. Bypass-RLS capability must not substitute for removing direct grants. Never a browser key. |
| anon/authenticated/PUBLIC | No direct protected data or api/private routine execution | Verify inherited/effective privileges, schema access and unexpected overloads. Browser Auth tokens identify Owner only to verified server handlers. |

Approved internal audit append/verification and wrapped PIN issuer access must
match the exact source grants. Do not grant all API routines to all executors.
The legacy raw enrollment issuer remains internally required by its verified
wrapper but must lose service-role execution in P09. Revoking its access does
not authorize deleting the routine or records.

### Blocking ownership-transfer compatibility risk

P05 creates/checks reserved roles, rejects all membership edges involving them,
denies schema CREATE for them, then changes protected object owners to them.
Standard non-superuser ownership transfers require suitable ownership authority,
ability to SET ROLE to the destination, and destination schema CREATE. These
requirements conflict with the restricted final model during the transfer unless
the actual operator has a valid, demonstrated authority path. Newly created
roles may also acquire automatic membership relationships depending on the
actual runtime/creator, which the assertions can reject.

**Static blocker; hosted compatibility UNKNOWN.** Do not assume SQL Editor's
`postgres`, CREATEROLE, local-superuser success or a service API key proves the
required authority. P11 and later OWNER TO/default-privilege statements require
this proof too. Any solution involving temporary migration privileges,
membership, schema CREATE or revised migration mechanics needs separate source
review, isolated acceptance, explicit Owner approval and final-state revocation
verification. None is proposed as an immediate production command here.

### Schema privileges, default ACLs and RLS

The approved hosted target exposes **only `api`** through PostgREST, with routines
only in that schema; `private` and `public.gym_settings` remain outside the public
Data API surface. Local TOML specifies api-only exposure and disables automatic
table exposure. It is not evidence of hosted configuration. Owner dashboard
inspection must confirm exposed schemas and Data API enablement without saving
changes during diagnostics; SQL session settings alone are not authoritative.

Default privileges attach to the **creator**, not the new owner after ALTER
OWNER. P05 revokes PUBLIC future function EXECUTE for gym_data_owner,
gym_owner_executor and gym_public_executor; P11 does so for gym_checkin_executor.
These do not automatically harden future routines created as postgres or another
migration actor. Existing functions retain their own ACLs; CREATE OR REPLACE can
retain old grants, and transferring ownership does not replace them with the
new owner's defaults. Explicit revocations/narrow grants in the same migration
reduce known-role exposure, but unknown creator defaults/grantees must be checked.

Owner/private review must evaluate:

1. Every actual creator, including postgres and the intended migration actor,
   with global defaults, schema additions and implicit acldefault behavior.
   An empty pg_default_acl result is not evidence of deny; default function
   PUBLIC EXECUTE and type USAGE must be considered.
2. Effective permissions, inherited memberships, grant options, all unexpected
   grantees and overloads, with table/column/sequence/type defaults where relevant.
   Anonymized OTHER_ROLE output and the limited creator allowlist are insufficient
   for identifying a private remediation target.
3. Exact schema USAGE/CREATE bounds, no unreviewed function/schema ownership,
   command/role-scoped policy expressions privately, helper SECURITY INVOKER and
   SECURITY DEFINER owners/configuration. Original inventories do not return
   expressions or full function source and cannot certify them alone.
4. RLS enabled **and forced**, correct owners and policies on final application
   tables, with negative request-level tests. The 22-table supplied result is
   the baseline inventory. Pending source adds 11 tables, making the intended
   final protected inventory 33 (32 private plus public.gym_settings), subject
   to exact inventory reconciliation. Do not confuse Auth/provider tables with
   this application allowlist.

Do not adopt broad generic Supabase custom-schema grants or enable browser RPC
execution. Default ACL correction, if necessary, is a separately approved
privilege change; no correction SQL or permission changes are made by this plan.

## 4. Existing-object conflicts and data-integrity blockers

No specific duplicate object is confirmed by the supplied aggregate. The
following are **source-confirmed collision paths** with production occurrence
UNKNOWN, and must be checked before selecting an apply procedure.

| Risk | Why absence of version is insufficient | Required disposition |
| --- | --- | --- |
| Three present marker occurrences | Could be older baseline definitions, one reused function across versions, or partial/manual installation | Privately associate each occurrence with version/kind/source object/column; compare exact overloads, arguments, result/defaults, owner/config/ACL/dependencies. No migration-history marking. |
| CREATE OR REPLACE routines in P01–P04/P09/P13/P16 | Return type or input argument name changes can fail; changed identity can create another overload; successful replacement can retain unwanted grants | Definition-by-definition compatibility review, not function-name equality or “CREATE OR REPLACE is safe.” Do not DROP a production routine to force a replacement. |
| Plain CREATE functions/tables/policies/triggers | Most P07+ definitions and all new tables have no conditional guard | Any matching name/kind is a HOLD until reconciled, including objects omitted by marker inventory. Triggers are relation-scoped; same trigger name on different tables is legitimate. |
| P01 normalized plan index | IF NOT EXISTS skips a same-name relation/index without proving definition | Compare expression, collation/opclass/uniqueness/validity and normalized duplicate data. Duplicate exception includes plan names; keep raw error private. |
| P04 finance columns/indexes/triggers | Existing columns cause ADD COLUMN errors; indexes can reject duplicate allocations/reference keys; old confirmed receipts may lack the newly introduced target basis | No guesses about historical allocation/payment facts. Review original receipt/event evidence through Owner procedure; no silent target assignment or delete/deduplication. |
| P05 strict input assertions | Recorded baseline can have different bodies, owners, extra routines/policies, sequence bindings, pgcrypto dependency or invalid constraints | Exact source-to-catalog comparison at the correct stage. File 03 is a screen, not the whole migration contract. Never disable its refusals. |
| P06 UTC chain compatibility | Stored timestamptz serialization can differ; chain heads can be inconsistent or orphaned | Owner-approved aggregate verification with full visibility and isolated UTC/refusal tests. If incompatible, halt for a separate legacy-history decision; never rewrite hashes/heads or replay recorded audit migration. |
| P07 legacy registration/membership state | Active without approval, pending with approval, future approval, dated-state mismatch, wrong Option A expiry, missing exact confirmed allocated receipt/event basis | No invented approval/payment timestamps, backdated activation or repaired financial status to pass DDL. Each real anomaly requires documented Owner resolution and separate approval. |
| Legacy walk-in and attendance history | New method and member-basis columns intentionally leave old rows NULL | Existing check-ins remain; no guessed method, basis or fee; assess eligibility/correction/reporting consequences separately. No expiry revival or automatic validity restoration. |
| P10 allocation uniqueness | Multiple existing payment allocations for one walk-in cause unique-index failure | Preserve all receipts and allocations; separate reviewed correction process, never delete records to build the index. |
| P11 existing check-in role | Role may exist with dependencies/ownership/ACLs or membership; safe-looking name is insufficient | Exact attribute, all dependencies and effective privilege inspection plus isolated creation/transfer test. Refuse reuse if unexpected. |
| P13 overlap constraint / review terms | Requires expected named constraint; historical payment_review terms are expressly refused; replacement exclusion predicate may expose incompatible dated history | Private Owner basis review, compare exact constraint and all affected terms; retain history and require a separately approved reconciliation if blocked. |
| P14 legacy drawers | Any drawer session blocks this source, even if closed; NOT NULL reason/evidence/date additions cannot fabricate history | Check sessions and reconciliations with Owner-only aggregate outcomes. Do not delete/close/relabel old sessions to satisfy the empty-table requirement. A real legacy dataset needs a separately reviewed migration/procedure. |
| Cash/post-close and immutable history | Corrections may affect facts after immutable snapshots | Never recalculate or edit historical drawer totals to match income/counts; unresolved stale/post-close procedure remains an approval gate. |
| Transaction/history ambiguity | Every file contains its own BEGIN/COMMIT; schema commit and runner history insertion behavior must be established | Test exact CLI/runner version/path and failure boundaries in isolation. Lost acknowledgement requires metadata reconciliation, not blind retry or history repair. |

For object-presence reconciliation, classify each candidate privately as
ABSENT / PRESENT-EXACT / PRESENT-OLDER-COMPATIBLE / PRESENT-INCOMPATIBLE /
UNKNOWN. These are review classifications, **not** statements that its migration
is applied. A marker-absent routine does not mean its indexes/policies are absent.
Recorded-but-missing or altered objects are separate drift and must not be
“fixed” by replaying the 20 recorded migrations.

If a partial/manual installation prevents the original forward sequence, stop
and prepare a separate approved reconciliation design. Do not edit approved
migration files, add IF NOT EXISTS everywhere, introduce an early hidden repair
step, drop objects, or invent a history baseline in this report.

## 5. Edge Function deployment dependency audit

All 21 local entrypoints and their relevant shared dispatch/parsing modules were
reviewed. Every referenced RPC below is in `api`. Earlier endpoint observations
are historical and must be revalidated at an authorized release checkpoint;
successful OPTIONS alone proves neither current code nor POST authorization.

| Local Edge Function | Earlier endpoint evidence | Database dependencies needed by current source |
| --- | --- | --- |
| owner-status | Present preflight | Baseline is_active_owner_for_user; final hardened ownership/ACL. |
| owner-register-member | Present preflight | Baseline Owner lookup/register; final registration trigger/P07, Owner audit and mobile encryption/keyed lookup. |
| owner-list-members | Present preflight | Baseline owner_list_members; final ACL. Source returns no mobile material and performs no directory decryption. |
| owner-list-membership-plans | Present preflight | P01 owner_list_membership_plans; P05 boundary. Endpoint presence does not establish RPC presence. |
| owner-save-membership-plan | Present preflight | P01 owner_save_membership_plan and normalized unique index; P05. |
| owner-create-membership-purchase | Missing, HTTP 404 | P02 purchase RPC plus P07 lifecycle guards and final P13/P16 finance semantics. |
| owner-list-membership-purchases | Missing, HTTP 404 | P03 original list, P04 payment-status replacement, P16 reviewed-allocation replacement. |
| owner-membership-payments | Missing, HTTP 404 | P04 record/confirm/reject/list, P13/P16 final guards/list; **P17 owner_list_payable_purchases** for payable action. |
| owner-membership-lifecycle | Missing, HTTP 404 | P07 owner_approve_member / owner_activate_membership_purchase, final P13/P16 basis calculations. |
| owner-reporting | Missing, HTTP 404 | P08 summary/audit, P16 final summary, P17 income/expiry RPCs. |
| owner-attendance | Missing, HTTP 404 | P12 owner_list_attendance; P11 basis and P13 invalidation history. |
| owner-receipt-review | Missing, HTTP 404 | P13 record/verify/list/void; P16 owner_allocate_verified_receipt. |
| owner-cash | Missing, HTTP 404 | P14 open/close/list drawer and verified actual-receipt helper from P13. |
| owner-attendance-claims | Missing, HTTP 404 | P15 submit/resolve/list plus final eligibility/void/receipt-allocation semantics. |
| owner-create-pin-enrollment-token | Present preflight | **P09 owner_create_verified_pin_enrollment_token**, internally wrapped baseline issuer; current source needs P09 despite old endpoint existence. |
| member-enroll-pin | Present preflight | Baseline rolling reserve_pin_enrollment_request, P09 replacement member_enroll_pin and one-use token/credential version controls. |
| owner-create-pin-recovery-token | Missing, HTTP 404 | P09 owner_create_pin_recovery_token. |
| member-reset-pin | Missing, HTTP 404 | Baseline rolling reserve_pin_enrollment_request and P09 member_reset_pin. |
| owner-walkins | Missing, HTTP 404 | P10 owner_set_walkin_fee / owner_list_walkin_requests / owner_confirm_walkin; final allocation/receipt guards through P16. |
| public-walkin-request | Missing, HTTP 404 | P10 public_create_walkin_request, request limiter/fee snapshots and immutable guards; final whole-receipt rules. |
| member-checkin | Missing, HTTP 404 | P11 reserve_member_checkin_request / prepare_member_checkin / commit_member_checkin; P13/P16 final eligibility. |

There are two deployment gaps, not one common SQL repair: migrations install
PostgreSQL objects; deploying Edge bundles installs HTTP handlers. Resolving
either alone cannot establish end-to-end correctness. Old present handlers may
also require redeployment of changed code/shared modules, particularly PIN
issuance/enrollment. The conservative future release reviews all 21 bundles
against one accepted source snapshot, not just the 14 absent URLs.

### Server configuration and package dependencies

- `APP_ORIGIN` must equal the canonical HTTPS site origin exactly. CORS checks
  reject other origins, but CORS is not an authentication or abuse-control proof.
- All handlers need the intended `SUPABASE_URL` and server-only service-role
  credential. Owner Auth handlers also need a compatible public Auth key.
  `owner-register-member` currently reads **SUPABASE_ANON_KEY specifically**;
  most other Owner handlers accept ANON/PUBLISHABLE fallback in varying order.
  Do not assume a publishable-only server configuration supports every handler.
  Verify privately by configuration presence/type/project match, never values.
- `MEMBER_MOBILE_HMAC_KEY_B64` supports normalized mobile lookup; registration
  encryption requires `MEMBER_MOBILE_ENCRYPTION_KEY_B64`. Current directory
  listing does not return/decrypt mobile data. Preserve existing key identity and Owner
  custody: changing them can break lookups/decryption and is not a migration fix.
- Check-in also requires `PUBLIC_CHECKIN_LOOKUP_HMAC_KEY_B64`, `DUMMY_PIN_HASH`,
  `CHECKIN_GLOBAL_LIMIT_PER_MINUTE` and `CHECKIN_IDENTIFIER_LIMIT_PER_MINUTE`.
  Walk-ins require explicit `WALKIN_REQUEST_LIMIT_PER_MINUTE` and an
  Owner-configured positive fee version; no default fee is seeded by P10.
- Keep `PIN_SETUP_ENABLED`, `PIN_RECOVERY_ENABLED`,
  `PUBLIC_MEMBER_CHECKIN_ENABLED`, `PUBLIC_WALKIN_ENABLED` and
  `OWNER_OFFLINE_REVIEW_ENABLED` disabled unless their separate approvals and
  runtime tests are satisfied. Disabled POST may correctly return 503; it is not
  evidence of failed migration. Public self-check-in requires internet.
- PIN setup/reset implementation uses development token/KDF parameters, with
  six-digit PIN validation and Argon2id (`hash-wasm@4.12.0`); production limits,
  token lifetime and runtime CPU/memory/shared-network/DoS acceptance remain
  gated. The approved 15-minute walk-in lifetime does **not** approve a PIN-token
  lifetime by analogy. Do not generate/export verifier hashes or tokens here.
- Ten entrypoints pin Supabase JS to `2.118.0`; eleven use the broad `@2` import.
  Shared PIN code also imports npm/WASM dependencies. Verify actual resolved
  versions, lock/import-map coverage, Deno bundling, dependency
  resolution and runtime limits in isolation. Local cached typecheck is not
  evidence of hosted module/WASM availability or free-tier capacity.
- Local function configuration sets `verify_jwt=false` for these handlers.
  Owner handlers explicitly validate the bearer through Auth.getUser and derive
  p_actor_user_id from that result, then SQL checks Owner status. Public routes
  use one-use capabilities or bounded generic operations rather than Owner Auth.
  Preserve those distinctions; enabling gateway checks blindly can block public
  routes, and disabling them without handler/SQL validation is unsafe.
- Browser build variables are only `VITE_SUPABASE_URL` and its public key
  configuration. No service-role credential, mobile key, PIN secret or token
  belongs in VITE variables, assets, logs, caches or this report.

## 6. Approval-gated execution sequence

### Stage A — reconcile metadata; no schema changes

1. Owner reviews this report, the three unidentified present-marker occurrences
   and the full private catalog comparison. Confirm primary database/project,
   diagnostic role, result completeness and timestamps. No credentials are
   needed by the Developer. Keep full role/grant/body/record outputs private.
2. Use only separately approved diagnostic files. The split 01 results and 02
   marker result must be complete. Scripts 03–07 remain **on hold**; their
   existence here does not authorize running them. Review table/column/role
   prerequisites first, then request precise authorization for relevant screens.
3. Determine whether each pending version has exact compatible inputs and no
   unexpected unmarked objects. Confirm actual default ACLs, ownership, FORCE
   RLS, policy/trigger/index/constraint definitions and extensions. Do not use
   aggregate absence to declare P05/P06 passed.
4. Complete Owner-only data blocker outcomes without sharing rows. Existing
   script 06 covers plan/registration/legacy cash screens; 05 covers audit;
   07 is conditional on P04 columns and does not cover every new unique index.
   Additional reviewed aggregate checks are needed for all financial uniqueness,
   legacy NULL bases, exclusion/review-term and final inventory conditions.
   Do not run 07 against missing columns or create them just to run the probe.

### Stage B — isolated compatibility, recovery and release rehearsal

Use an existing separately authorized isolated environment, or obtain approval
before provisioning any resource. Match the actual hosted PostgreSQL major,
extensions, migration actor privileges, PostgREST schemas, Edge/Auth behavior and
migration runner. Synthetic records only; no production dump copied to Developer
machines. An Owner-controlled restore drill involving real backups is a separate
restricted task and must not expose live records to the Developer.

Reproduce the recorded baseline and compatible synthetic legacy states, including
the identified partial-object scenarios. Apply the **unchanged** P01–P17 in order
using the intended runner. Rehearse every refusal/failure branch and verify
transaction closure, privileges/ownership after failure and history bookkeeping.
Resolve P05/P11 authority before requesting a production window. A local
superuser PostgreSQL 18 Auth-shim PASS cannot certify hosted PostgreSQL 17
non-superuser compatibility.

### Stage C — Owner-approved maintenance and migration window

Only after A/B pass, approve the exact source hashes, operator, runner, target,
duration/lock budget, backup/recovery point, communication/traffic controls and
abort procedure. Stop public/Owner business mutations through separately
approved application/operational controls; UI hiding alone cannot quiesce APIs.
Do not disable RLS, authentication or integrity triggers. Avoid unrelated DDL.

Preserve files' own transaction boundaries; do not nest them inside a giant
rollback “dry run” or use production mutation tests. Test the real runner's
BEGIN/COMMIT behavior and history recording in Stage B first. Apply one reviewed
version at a time, fail fast, verify its committed metadata/history privately and
take the following checkpoints without allowing business traffic between stages:

| Checkpoint | Candidate migrations | Required acceptance before next stage |
| --- | --- | --- |
| C1 | P01–P04 in numeric order | Exact 25-routine/22-table pre-hardening input, normalized-plan index, finance columns/indexes/triggers and all legacy uniqueness/basis checks; history exactly matches committed files. |
| C2 | P05 then P06 | Complete hardening assertions and hosted role-transfer behavior; FORCE RLS/narrow ACLs/sequence bindings, no memberships/CREATE leaks; all streams verify under pinned UTC with preserved original hashes. |
| C3 | P07–P09 in numeric order | Registration/lifecycle invariants, actual server timing, Owner-only reports, wrapped PIN issuance, no raw issuer service access or hash leakage; release gates still closed. |
| C4 | P10–P12 in numeric order | Provisional 15-minute snapshots, no legacy repricing, whole receipt uniqueness, restricted check-in executor/credential reads, Owner attendance and legacy basis review. |
| C5 | P13–P17 in numeric order | Append-only correction/allocation/claim/cash histories, correct overlap predicate, daily drawer preconditions, final report/payable RPCs and 33-table target inventory; final role/RLS/ACL/definition acceptance. |

These checkpoint groups do not imply cross-file atomicity. If one file commits
and the next fails, production may be in a valid intermediate schema but **must
remain unavailable for business use** until reviewed recovery/roll-forward.
Never push through a refusal to complete a group.

### Lock and duration review

P05 explicitly requests ACCESS EXCLUSIVE on all 22 protected baseline tables.
P06 locks audit_events/heads; P07 locks members, purchases and finance tables;
P09 locks credential/token tables; P10 locks walk-in/fee/payment/allocation/
attendance tables; P11 locks attendance; P13 locks finance/purchases/attendance;
P14 locks drawers/reconciliations. These locks block ordinary reads as well as
writes on affected tables. Several use advisory transaction locks too.

P05–P11, P13–P14 and P16 set 5-second lock and 120-second statement
timeouts. P01–P04, P12, P15 and P17 do not supply both bounds. All still
have implicit DDL/function/policy/index locks; “no LOCK TABLE” is not “no locks.”
Index/constraint builds, hash verification and volatile-default column population
can scale with real data. Rehearse measured duration and runner-level bounds for
unbounded files; do not silently edit source or lengthen production timeouts.
The 120 seconds is per statement, not an overall maintenance deadline.

### Stage D — handlers, hosted settings, frontend and acceptance

Only after final database compatibility passes, separately approve any required
hosted `api` exposure/origin/settings changes and Edge releases. Deploy reviewed
bundles against the confirmed project, including old present handlers affected
by source/shared-code changes. Keep public/PIN/claim gates closed until their
explicit release acceptance; verify safe disabled responses and authentication
boundaries. Refresh public route/OPTIONS checks, then approved Owner production
reads. Do not create synthetic receipts/members among real production data.

Publish the reviewed frontend through the existing GitHub/Cloudflare Pages
workflow only after separate approval. Verify the actual production branch,
reviewed commit/build SHA, Node/build settings, output `dist`, public build-key
project match, headers, SPA fallback and preview isolation. Changing Vite values
requires rebuilding assets. Confirm Pages deployment logs/success rather than
inferring it from reachable HTML. The earlier stabilization report contains CLI
handoff examples; they are not authorized commands at the current stage.

Run real Auth → Edge → PostgREST → SQL mutation/negative tests in the approved
isolated environment. Owner production acceptance is limited to authorized real
operations/read verification; no test financial entries are mixed into live
records. Finish the checklist below before opening operational use.

## 7. Validation strategy and evidence handling

| Layer | Validation required | Current evidence |
| --- | --- | --- |
| Offline source | All 37 files chronological inventory, dependencies, top-level AST syntax, exact reviewed bytes, 21 handlers/shared dispatch, default ACL and authorization review | This task inspected all 37, parsed 993 top-level statements with cached PostgreSQL 17 parser; five UTF-8 BOMs stripped in parser memory only. No migration files changed. Bodies/DO blocks reviewed from source; parsing is not runtime SQL validation. |
| Baseline production metadata | Complete history/catalog/markers and exact stage-specific definitions | Owner aggregates only: 20 history, 88 absent/3 present, 22 ENABLE RLS. Identities/defaults/owners/policies/FORCE RLS and most definitions UNKNOWN. |
| Local synthetic suites | Lint/type/build, 37 Node and 103 Deno tests, 21 Edge typechecks, all migrations/nine races and fixture browser tests | Historical evidence remains separate; fresh baseline-audit reruns and new negative probes are recorded in section 14. Not hosted certification. |
| Hosted-compatible isolated replay | Same actor/runner/extensions/Postgres, partial-object cases, refusals and cleanup | UNKNOWN; must pass before production approval. |
| Data blockers / recovery drill | Owner-only aggregate outcomes, actual isolated restore/time/key custody validation | UNKNOWN; no live data read by this task. |
| Hosted full business and security acceptance | Real Auth/Edge/PostgREST/SQL with synthetic mutations in isolation | UNKNOWN. |

For every prospective migration capture privately: source version/hash, actor,
time, transaction outcome, bounded SQLSTATE/category, expected object changes,
approved history outcome, and named invariant PASS/FAIL/UNKNOWN. A successful
DDL or HTTP 200 alone is not full acceptance. Missing roles/rows, RLS-filtered
aggregates, truncated grids and unavailable prerequisite columns are UNKNOWN.

Never export raw function bodies from production, full ACL/role grids, policy
expressions, tokens/hashes, member/payment/audit rows, amounts, mobile numbers,
connection strings or complete exception logs. Migration guards can embed private
plan names or object details in errors; sanitize before sharing. Source filenames
and approved source object names in this report are not live record evidence.

### Required isolated business and abuse cases

- Active Owner only; non-Owner member/developer identity, unauthenticated,
  deactivated, forged/expired session and request-supplied actor cannot manage.
  Service-only RPCs, direct browser requests, table/column/sequence access and
  malicious overload/schema-search-path paths all fail closed.
- Approval and full confirmed receipt both required; activation is the later
  Manila date, never backdated. One calendar month Option A, inclusive expiry,
  Jan 31/February/leap/year edges, consecutive early renewal and lapsed renewal;
  no overlapping or arbitrary future prepaid terms.
- Cash, GCash, bank transfer, pending/rejected versus confirmed, exact amounts,
  evidence review, immutable originals, duplicate operation payload conflicts,
  unknown commit responses and no allocation before verified money.
- One valid check-in per member per Manila day, ID/mobile normalization, invalid
  PIN/unknown identifier generic response, expired/ineligible denial, credential
  version reset race and midnight/lock-wait behavior. No checkout.
- Provisional walk-in server ID/fee/currency/version/time/15-minute expiry,
  expired request cannot revive, Owner confirmation atomic with receipt and
  attendance, duplicate confirmation race and lost creation response safety.
- Whole unmatched receipt review, one allocation, no combining underpayments,
  no unverified income/access; void preserves histories, invalidates affected
  eligibility/check-ins and never silently restores independent access.
- Cash counts include verified unallocated actual cash; electronic exclusion,
  attested float/daily close, reason/evidence variance, immutable snapshots and
  no automatic income adjustment. Old claims remain review, not attendance.
- Audit chain append serialization/rollback/concurrent updates and incompatible
  legacy-UTC refusal; receipt, confirmation, token redemption, allocation,
  claim-resolution, daily-check-in and void/check-in concurrency.
- Runtime PIN/WASM CPU/memory, bounded KDF parsing/dummy path, rolling rates,
  shared-network fairness and DoS; real-mobile QR/navigation/PWA install/update,
  no sensitive API/Auth/PIN/attendance caching. Public use requires internet.

## 8. Recovery and rollback considerations

### Before any apply

Owner controls project membership, operator credentials, backup access, key
custody and recovery authorization. Verify actual provider/free-tier backup and
restore capabilities; do not assume PITR, service-plan privileges or an automatic
rollback exists. Agree RPO/RTO, maintenance data cutoff and backup encryption.
Capture reviewed schema/migration/role/extension configuration, application
release/build/function bundle inventory and server configuration references
without exporting secrets to the Developer. Database backups alone do not
restore Edge bundles, Auth/settings, mobile encryption/HMAC keys or Pages builds.
Rehearse an isolated restore with the intended Owner operator before production.

### Failure before a file commits

Stop immediately; preserve sanitized evidence and the exact error phase. Abort
the **same session's** transaction or close that known session; verify rollback
and lock release through the Owner-controlled operator. A later SQL Editor click
may use another backend and cannot prove cleanup of the first. Check all earlier
committed checkpoints separately. Do not assume timeout/cancellation means a
successful rollback or no history write.

### Lost acknowledgement / schema and history disagree

Freeze retries and keep traffic closed. Owner verifies actual commit outcome,
object definitions and history in the intended database. A schema commit with
missing history, unexpected history with incomplete objects or partial manual
DDL is a new reconciliation incident. **No automatic rerun, migration repair,
mark-applied operation or hand-edited schema_migrations is authorized.** Any
resolution must have its own reviewed compatibility/atomicity plan and approval.

### Failure after one or more files commit

Prefer an approved compatible application release or narrowly reviewed forward
fix; do not run reverse DDL casually. Rolling back frontend/handlers does not
undo ownership, API contracts or ledger semantics. Verify the previous app's
compatibility before routing traffic to it; if unproven, remain in maintenance.
Source contains no generally safe down-migration for this sequence.

If restore is the selected last resort, Owner explicitly approves scope/time and
the potential loss of all valid post-backup operations. Restore to an approved
isolated target first, verify Auth mappings, key custody, schema/roles, original
receipts/check-ins, audit streams/heads, history and app compatibility, then
approve controlled cutover. Keep failed state/evidence access-restricted for
investigation. Do not reset production, overwrite current finance/member records,
rehash history, delete duplicates, grant access or disable triggers/RLS as a
rollback shortcut. No restore or resource provisioning is authorized here.

## 9. Deployment readiness checklist and Owner approvals

PASS is a narrow evidenced result; FAIL is an evidenced unmet requirement;
UNKNOWN lacks sufficient evidence. Approval cannot turn an untested technical
requirement into a PASS.

| Gate | Current status | Required evidence / Owner decision |
| --- | --- | --- |
| Confirmed target and chronological source/history comparison | PASS | 37 local, first 20 recorded in supplied evidence. Reconfirm actual target at future execution. |
| Source release equals production database history | FAIL | 17 versions remain unrecorded; reconcile definitions before any apply. |
| Complete individual marker classification | UNKNOWN | Identify the three present occurrences privately; associate every marker with its version. |
| Duplicate-object/replacement/default-ACL compatibility | UNKNOWN | Exact definitions/effective privileges for all pending effects, not only 91 markers. |
| ENABLE RLS on inventoried baseline | PASS, supplied | 22 tables only; does not imply final FORCE/policy/role acceptance. |
| Final protected 33-table/RPC-only security inventory | UNKNOWN | Owners/FORCE RLS/command policies, routine/sequence/column/default bounds and isolated negative tests. |
| Migration actor can perform unchanged P05/P11 ownership changes | UNKNOWN / BLOCKER | Hosted-equivalent isolated proof; approve separate design if current source cannot run without prohibited final privileges. |
| Complete P05 exact input and output assertions | UNKNOWN | Correct P01–P04-stage inputs, not baseline or later definitions; extension dependency and full object checks. |
| Stored audit UTC compatibility and tamper-evident history | UNKNOWN | Approved Owner check and isolated refusal/restore validation; no rehash. |
| Legacy plan, payment, registration, lifecycle/overlap, attendance and drawer blockers | UNKNOWN | Full-visibility Owner outcomes; each financial/membership correction separately approved. |
| Backup/isolated restore, RPO/RTO and key custody | UNKNOWN | Owner-approved demonstrated recovery capability and responsibilities. |
| Exact runner atomicity/history behavior and failure cleanup | UNKNOWN | Isolated proof using intended actor, runner and transactions. |
| Production source hashes/operator/window/traffic/lock budgets | HOLD | Explicit Owner approval of final reconciled plan; no blanket db push. |
| Hosted api-only exposure and server origin/key configuration | UNKNOWN | Private dashboard/config verification; separate approval for any changes. |
| Required Edge endpoints | FAIL, earlier evidence | 14 missing; review/release all affected bundles and verify source/version/POST dependencies after SQL acceptance. |
| Public/PIN/check-in/claim release gates and parameters | HOLD | Owner approves tested rates, token/KDF/runtime values, fee and applicable privacy/retention/triage policies. |
| Isolated real Auth/JWT/Edge/PostgREST business/race acceptance | UNKNOWN | Synthetic full-stack cases above; local fixtures alone insufficient. |
| Existing GitHub/Pages branch, SHA, build, headers and mobile acceptance | UNKNOWN | Reviewed normal commit/push authorization, actual Pages success/logs/SHA, final mobile/PWA checks. |
| Owner production read acceptance and operational opening | HOLD | Successful authorized payment/payable/walk-in reads and reports; no synthetic live finance data. |
| No production changes during this task | PASS | Local inspection and this report only; no SQL/network execution, deploy, history or privilege change. |

Outstanding explicit Owner decisions include: authorization for any additional
read-only checks (03–07 still held); the three-object reconciliation result;
any role/default-ACL/ownership migration correction; legacy financial/member/
drawer resolution with preserved originals; isolated environment access or
provisioning; recovery drill and backup/restore capability; final migration
window/operator/bytes and abort policy; hosted schema/config changes; Edge and
Pages deployment; public/PIN/claim release parameters; privacy/retention and
evidence procedures. The Developer has no routine live-record access or Owner
privilege through their ordinary gym-member identity.

Finalized rules remain unchanged: Owner-only management/actual-receipt approval,
PHP, Manila dates, Option A calendar-month terms, full confirmed payment before
access, 15-minute immutable provisional walk-ins, at most one valid daily member
check-in, preserved financial/audit/check-in history, separate money-versus-income
and drawer accounting. No refunds, complimentary membership, installments,
checkout, cancellation/freeze/expiry override, automatic renewal, public member
dashboard/login or silent approval/backdating of offline claims.

## 10. Reviewed pending source fingerprints

SHA-256 of exact local file bytes, including original encodings. These pin the
review input, not production definitions or applied-history evidence. Recompute
and compare before any later approved execution; changed files require review.
The intended runner must handle existing UTF-8 BOMs correctly; parser memory
normalization is not authorization to rewrite migration files.

```text
8129ad8b38744ab6ff0180f246cc2107da9a8abb1c03494e8a426691230b1196  20261103080000_owner_membership_plans.sql
7c8d0d18b1b4a8d2c475b3fa193764a7ece282abec33ad39a7d0b3fb23739fc6  20261103100000_owner_create_membership_purchase.sql
4e921477e040aa652a5943d7886f75c441395003674d72e36a1e84250933d0d5  20261103110000_owner_list_membership_purchases.sql
62ff9ec172e04f901bcec4d7b9f4d4718b8590dfb92ba13f2456fcd402635240  20261103120000_owner_membership_payments.sql
b524b698e1bb2d58d79231e498cee0db47694dc231f49cd9d0430e0544417b9d  20261110100000_executor_hardening.sql
58fd9a89b7f3aee11510fc439e75e9f543bd854c73e36635fc0a79aa2a74e26f  20261110103000_audit_timezone.sql
f8204849462b8a173f0ccceea4383368ed7baa731e98335591b950f26543f966  20261110110000_membership_lifecycle.sql
d9f51df5d75b56ba31a456fbd8b019c7c094f1b871f9514b2f03a456f9e1e0da  20261110120000_owner_reporting.sql
317c77c50cca204cdcbe4b7a24eae45103c16878f921573e225e926dbe8c56c4  20261110130000_pin_recovery.sql
48d8d2c9b8e6e2d890e4625b88455bca3084d67f0c2452b918336c7e21910303  20261110140000_walkin_operations.sql
012983386f610944b66a837135cb4f8e4571b5f11bde350bd81cf8e0cc04bd73  20261110150000_member_checkin.sql
7e6af68a594c5cb26ab77eac4620849a3ecf5b8888aede71808eda5f569a5f46  20261110153000_owner_attendance.sql
5f66c08fc3df9ba85760dc90ff69e1007e76409af2e77517b619b90407fe2b1e  20261110160000_receipt_review_corrections.sql
96bab1c3491f7129aaceffb9d032d5cebd622e2e69f0c5e9e44f3971c8b6969b  20261110170000_cash_operations.sql
d852267853d37648c1454941f49341bc1b9c07d1f17974eff8f614a6562c6253  20261110180000_provisional_claims.sql
6a052a9127e3c5ed571ffefe585a4969fefe616e302472f9ebf6bdd0d403463b  20261110190000_receipt_allocation_review.sql
7a4c471bfb37afcc1346cd5ad87fc7cbb6db2c0a58142974b8411b0175c24ab9  20261110200000_operational_reports.sql
```


## 11. Baseline security and integration audit findings

Repository: `https://github.com/Jeddu02/gym-attendance-management`; local branch
`review/production-recovery`, exact baseline `38fdf66`. Findings distinguish
confirmed source/synthetic behavior from unknown hosted conditions. Severity
measures operational/security impact; it does not assert that an unobserved
production vulnerability is exploitable. No production endpoint was probed here.

| ID | Severity | Finding / evidence state | Verified behavior or risk | Exact source evidence | Acceptance / disposition |
| --- | --- | --- | --- | --- | --- |
| A01 | HIGH ? release blocker | Supplied schema/HTTP deployment gaps; current per-object state UNKNOWN | 20/37 history and 88 absent markers do not support deploying the final code; 14 earlier gateway 404 endpoints are independent of SQL. Production metadata/HTTP was not refreshed in this task. | `docs/production-preflight/02-unrecorded-object-markers.sql:9`; `docs/STABILIZATION-2026-11-16.md:12` | Obtain complete private observations, verify all final dependencies, then separately approve deployments. |
| A02 | HIGH ? migration blocker | Ownership-transfer authority not demonstrated | P05 rejects reserved memberships/schema CREATE while assigning objects/default ACLs to those roles. P11 has another reserved-role creation/ownership boundary. Local superuser PASS does not resolve hosted migration-actor compatibility. | `supabase/migrations/20261110100000_executor_hardening.sql:30`; `supabase/migrations/20261110100000_executor_hardening.sql:827`; `supabase/migrations/20261110100000_executor_hardening.sql:655`; `supabase/migrations/20261110150000_member_checkin.sql:11` | Demonstrate exact operator/runner authority and cleanup in a hosted-equivalent isolated test. Review any required source/authority solution separately; never relax final roles/RLS. |
| A03 | HIGH ? security acceptance blocker | Effective creator defaults and inherited grants UNKNOWN | Reserved-owner default revocations do not harden objects created as postgres/other actor or remove inherited/unexpected existing grants. Inventory query filters creator names and anonymizes others; it cannot certify full effective future access. | `supabase/migrations/20261110100000_executor_hardening.sql:1135`; `docs/production-preflight/sql-editor/01-08-default-acls.sql:20` | Owner-private review of implicit/global/schema additions for actual creators; verify no direct data/API execution grants and least privilege. Any ACL correction needs explicit approval. |
| A04 | HIGH ? data/recovery blocker | Source-confirmed refusals; affected live data UNKNOWN | Cash refuses every legacy drawer-session row; lifecycle/audit/correction guards can refuse prior history. P04 adds volatile-generated operation IDs to existing finance rows, and P13 replaces exclusion constraints. Missing versions do not make these safe. | `supabase/migrations/20261110170000_cash_operations.sql:10`; `supabase/migrations/20261103120000_owner_membership_payments.sql:6`; `supabase/migrations/20261110103000_audit_timezone.sql:24`; `supabase/migrations/20261110160000_receipt_review_corrections.sql:241` | Owner data-blocker outcomes, measured lock/rewrite plan, original-history preservation and tested recovery before approval; no guessed backfill/delete/rehash. |
| A05 | MEDIUM ? reproduced integration defect | Malformed successful RPC response is masked as empty data | All three list handlers return HTTP 200 with [] when synthetic RPC JSON is an object. Frontend array checks accept the empty result, so RPC/schema contract drift can look like no records. | `supabase/functions/owner-list-members/index.ts:157`; `supabase/functions/owner-list-membership-plans/index.ts:151`; `supabase/functions/owner-list-membership-purchases/index.ts:129` | Future separately approved behavior fix must reject malformed/non-array data safely; tests must preserve legitimate empty arrays. No fix made in this audit. |
| A06 | MEDIUM ? reproduced failure-path defect | Configuration-before-OPTIONS remains in older handlers | Five locally loaded handlers returned 503 to trusted-origin OPTIONS when only APP_ORIGIN was configured: member list, plan list/save and purchase create/list. Other paths share this source ordering. This is conditional failure handling, not proof of hosted CORS misconfiguration and not the cause of a gateway 404. | `supabase/functions/owner-list-members/index.ts:60`; `supabase/functions/owner-list-membership-plans/index.ts:28`; `supabase/functions/owner-create-membership-purchase/index.ts:28`; `supabase/functions/owner-attendance/index.ts:25` | Review an approved consistent preflight fix with exact-origin rejection and gated POST tests across all 21 endpoints. Existing eight-handler preflight tests do not cover every remaining path. |
| A07 | HIGH ? reconciliation blocker | The three present occurrences remain unidentified | Plain CREATE/ADD COLUMN/index/policy/trigger statements can collide; OR REPLACE/IF NOT EXISTS do not prove definition compatibility. Marker count excludes P05/P06 and constraints/indexes/policies. | `supabase/migrations/20261103120000_owner_membership_payments.sql:5`; `supabase/migrations/20261103080000_owner_membership_plans.sql:29`; `docs/production-preflight/02-unrecorded-object-markers.sql:112` | Classify exact signatures/objects privately; preserve old source/history and hold on incompatible or unrecorded partial effects. |
| A08 | MEDIUM ? integrity/UX limitation | Public creation has no lost-response recovery/idempotency key | Frontend prevents only current in-flight/repeated success in memory. A lost committed response or reload loses the reference; a retry may create a separate provisional request. This does not itself confirm money/attendance, but at-most-once creation is not established. | `src/components/EntrancePage.tsx:86`; `src/components/EntrancePage.tsx:92`; `supabase/migrations/20261110140000_walkin_operations.sql:261` | Owner-approved recovery/duplicate-request decision and isolated lost-response tests before operational release; never auto-confirm or blindly resubmit a paid request. |
| A09 | MEDIUM ? deployment reproducibility risk | Mixed SDK version specifications | Eleven entrypoints import @supabase/supabase-js@2 while ten pin 2.118.0. Local Node adapter tests use the installed SDK and do not certify every Deno deployment resolved the identical version. | `supabase/functions/owner-register-member/index.ts:1`; `supabase/functions/owner-membership-payments/index.ts:1`; `supabase/functions/owner-walkins/index.ts:1` | Verify actual lock/import-map/bundle resolution and runtime acceptance privately; review any dependency pin changes separately. No known vulnerability is inferred from the version range. |
| A10 | LOW ? configuration compatibility | Public Auth key fallback is not uniform | Registration reads SUPABASE_ANON_KEY only, while other Owner handlers allow a publishable fallback. A publishable-only server configuration would leave registration unavailable. Actual hosted key configuration is UNKNOWN. | `supabase/functions/owner-register-member/index.ts:13`; `supabase/functions/owner-walkins/index.ts:7` | Verify compatible server key presence/type/project privately; never request values or expose service keys. |
| A11 | LOW ? invalid-input contract difference | Reset token format is narrower than common UI validation | Shared PIN page accepts 40?128 URL-safe characters, but reset parser requires exactly 43. Current generated tokens use 32 random bytes / 43 base64url characters, so no generated-token happy-path failure was found. | `src/components/PinSetupPage.tsx:10`; `supabase/functions/_shared/pin-recovery.ts:37`; `supabase/functions/_shared/pin-enrollment.ts:7` | Add approved contract tests for generated valid tokens and malformed lengths; retain generic responses and no Owner PIN disclosure. |

Authorization source review found verified-actor forwarding and SQL active-Owner
checks for the intended privileged paths; it did **not** demonstrate a new
unauthorized access bypass. Static patterns/fixtures cannot certify every hosted
JWT, RLS or runtime policy. No Manager/front-desk role or member login/dashboard
was added. The permanent QR contains only the public entrance URL: Member ID or
mobile plus PIN is entered privately afterward; no identity-bearing QR redesign
is proposed.

The three list envelopes intentionally omit success=true; their current clients
check the arrays, so that inconsistency alone is not a happy-path mismatch.
Member registration returns member_code and the client accepts it alongside
memberCode. The earlier report incorrectly described mobile decryption in the
directory path; the actual RPC returns only id/memberCode/fullName/status/createdAt
and no mobile material. The baseline/table and Edge sections above are corrected.

## 12. Direct migration dependencies versus conservative release order

This supplements the compatibility matrix in section 2. It distinguishes actual
object/routine/column/policy requirements from merely earlier version numbers.
The safe supported order remains P01 through P17; this is not permission to skip
chronological predecessors. Dependencies include runtime grants/policies, not
only whether PostgreSQL can create a deferred PL/pgSQL body. Function-body
creation can succeed even when its first runtime invocation would fail.

| Pending migration | Direct prerequisites and ordering qualification | Required output / evidence |
| --- | --- | --- |
| P01 `supabase/migrations/20261103080000_owner_membership_plans.sql` | Recorded plans/Owner/audit; no new routine from another pending migration is called. | Normalized index and plan list/save. `supabase/migrations/20261103080000_owner_membership_plans.sql:29` |
| P02 `supabase/migrations/20261103100000_owner_create_membership_purchase.sql` | Recorded members/plans/purchases/Owner/audit. P01 is chronological/security-index ordering, not a direct plan-list RPC call. | Purchase creation and price snapshot. `supabase/migrations/20261103100000_owner_create_membership_purchase.sql:3` |
| P03 `supabase/migrations/20261103110000_owner_list_membership_purchases.sql` | Recorded members/plans/purchases/Owner. P02 is source lineage, not a call dependency. | Original purchase list, later replaced in P04/P16. `supabase/migrations/20261103110000_owner_list_membership_purchases.sql:3` |
| P04 `supabase/migrations/20261103120000_owner_membership_payments.sql` | Recorded finance tables/audit; supersedes the P03 routine body. Preserve P01?P03 sequence for P05 input/history. | Adds two payment columns, five indexes and ten triggers before hardening. `supabase/migrations/20261103120000_owner_membership_payments.sql:6` |
| P05 `supabase/migrations/20261110100000_executor_hardening.sql` | Exact P01 plan functions/index, P02 purchase function and P04 payment/list/trigger/index output plus recorded baseline. P03 remains a chronological predecessor. | 25 exact routine signatures/bodies, 22 table inventories, roles/ACL/RLS/sequence/trigger/index/constraint assertions. `supabase/migrations/20261110100000_executor_hardening.sql:588`; `supabase/migrations/20261110100000_executor_hardening.sql:827` |
| P06 `supabase/migrations/20261110103000_audit_timezone.sql` | P05-owned invoker hash helper; recorded audit verifier under hardened executor and existing events/heads. | UTC source compatibility before altering helper configuration. `supabase/migrations/20261110103000_audit_timezone.sql:11` |
| P07 `supabase/migrations/20261110110000_membership_lifecycle.sql` | P04 target receipt column/guards, P05 roles/ownership/FORCE RLS; P06 required for safe audited execution. | Lifecycle helpers, approval/activation, dated-state/approval/exact-paid preconditions. `supabase/migrations/20261110110000_membership_lifecycle.sql:12` |
| P08 `supabase/migrations/20261110120000_owner_reporting.sql` | P05 protected Owner/attendance privileges and explicit P07 activation-routine existence check. | Attendance SELECT policy, dashboard/audit RPCs. `supabase/migrations/20261110120000_owner_reporting.sql:22` |
| P09 `supabase/migrations/20261110130000_pin_recovery.sql` | P05 Owner/public executors and baseline issuer/token/credential/rolling limiter. P07/P08 retained for approved lifecycle/release order; no call to their report RPCs. | Verified issuer/reset and old raw issuer revocation. `supabase/migrations/20261110130000_pin_recovery.sql:21`; `supabase/migrations/20261110130000_pin_recovery.sql:141` |
| P10 `supabase/migrations/20261110140000_walkin_operations.sql` | P04 operation-ID/payment integrity, P05 roles/audit; P08 Owner attendance SELECT policy for complete confirmation/read behavior. P07/P09 retained as release predecessors. | Walk-in method/rate/review, guarded confirmation and provisional creation. `supabase/migrations/20261110140000_walkin_operations.sql:33`; `supabase/migrations/20261110140000_walkin_operations.sql:312` |
| P11 `supabase/migrations/20261110150000_member_checkin.sql` | P04 receipt target/basis columns, P05 private/public/audit boundary. P07 lifecycle and P09 credential-reset semantics retained for complete release; P10 is chronological, not a direct call to walk-in RPCs. | Verifier role, member basis/rate tables and reserve/prepare/commit. `supabase/migrations/20261110150000_member_checkin.sql:11`; `supabase/migrations/20261110150000_member_checkin.sql:40` |
| P12 `supabase/migrations/20261110153000_owner_attendance.sql` | P11 attendance membership_purchase_id column; P05 Owner and P08 attendance SELECT policy. | Owner history and validity-resolution read policy. `supabase/migrations/20261110153000_owner_attendance.sql:4` |
| P13 `supabase/migrations/20261110160000_receipt_review_corrections.sql` | P04 immutable/payment guards; P07 lifecycle helpers/guards; P10 receipt_review/walk-in guards; P11 credential/basis and check-in role; P12 resolution read privileges. Baseline named btree_gist overlap constraint required. | Four verification/void/replacement tables, correction guards and overlap replacement. `supabase/migrations/20261110160000_receipt_review_corrections.sql:12`; `supabase/migrations/20261110160000_receipt_review_corrections.sql:241` |
| P14 `supabase/migrations/20261110170000_cash_operations.sql` | P13 assert_receipt_review_owner/is_receipt_verified; P04 immutable history helper; P05 Owner boundary and recorded cash tables. | Daily cash metadata requires zero legacy sessions. `supabase/migrations/20261110170000_cash_operations.sql:10`; `supabase/migrations/20261110170000_cash_operations.sql:118` |
| P15 `supabase/migrations/20261110180000_provisional_claims.sql` | P11 member_checkin_eligible_purchase and attendance membership basis; P04 append-only helper; P05 Owner boundary. P13 final void semantics and P14 chronological order retained. | Immutable claim/resolution, current-presence-only path. `supabase/migrations/20261110180000_provisional_claims.sql:5`; `supabase/migrations/20261110180000_provisional_claims.sql:37` |
| P16 `supabase/migrations/20261110190000_receipt_allocation_review.sql` | P13 verification/void tables/helpers; P10 walk-in review/allocation guards; P11 eligibility; P07 paid/lifecycle helpers; P08 summary; P04/P03 payment/purchase-list lineage. P14/P15 retained chronologically. | Reviewed allocation + eight replacement definitions; no dependency on P14 cash RPCs. `supabase/migrations/20261110190000_receipt_allocation_review.sql:8`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:49` |
| P17 `supabase/migrations/20261110200000_operational_reports.sql` | P16 receipt_membership_target_matches and final eligibility/paid-date helpers; P11 eligibility and P07 lifecycle facts with P05 Owner policies. | Final income, expiry and payable RPC contracts. `supabase/migrations/20261110200000_operational_reports.sql:25`; `supabase/migrations/20261110200000_operational_reports.sql:58` |

Recorded-source audit covers all 20 files listed in section 2; each path is
`supabase/migrations/<exact filename>`. All 37 were opened and parsed again at
38fdf66 (993 statements). DDL, function bodies, role assertions, constraints,
SQL/RPC dispatch and shared source were reviewed; syntax parsing alone is not
being represented as database compatibility. No record-level production state
was available to resolve conflict/data-dependent conditions.

## 13. Exact endpoint RPC edges and marker consumer cross-reference

This section is source-derived from all 21 entrypoints and 16 unique recursively
imported runtime shared modules (37 runtime source files). It does not execute
handlers or inspect hosted dependencies. Direct RPC names include action dispatch
in shared modules. Each database source link points to the **final local** routine
definition; first-introduction versions and replay requirements remain in section 2.

### 13.1 Direct Edge-to-RPC matrix

All endpoint filenames below use their exact repository paths. Imported
dispatch modules are included when resolving dynamic rpc/rpcName variables.

| Edge entrypoint | Direct API RPCs ? final local definition |
| --- | --- |
| `supabase/functions/member-checkin/index.ts:1` | `api.reserve_member_checkin_request` ? `supabase/migrations/20261110150000_member_checkin.sql:130`; `api.prepare_member_checkin` ? `supabase/migrations/20261110150000_member_checkin.sql:170`; `api.commit_member_checkin` ? `supabase/migrations/20261110150000_member_checkin.sql:188` |
| `supabase/functions/member-enroll-pin/index.ts:1` | `api.member_enroll_pin` ? `supabase/migrations/20261110130000_pin_recovery.sql:101`; `api.reserve_pin_enrollment_request` ? `supabase/migrations/20261030170000_rolling_pin_enrollment_rate_limit.sql:21` |
| `supabase/functions/member-reset-pin/index.ts:1` | `api.reserve_pin_enrollment_request` ? `supabase/migrations/20261030170000_rolling_pin_enrollment_rate_limit.sql:21`; `api.member_reset_pin` ? `supabase/migrations/20261110130000_pin_recovery.sql:66` |
| `supabase/functions/owner-attendance/index.ts:1` | `api.owner_list_attendance` ? `supabase/migrations/20261110153000_owner_attendance.sql:9` |
| `supabase/functions/owner-attendance-claims/index.ts:1` | `api.owner_submit_attendance_claim` ? `supabase/migrations/20261110180000_provisional_claims.sql:39`; `api.owner_resolve_attendance_claim` ? `supabase/migrations/20261110180000_provisional_claims.sql:62`; `api.owner_list_attendance_claims` ? `supabase/migrations/20261110180000_provisional_claims.sql:102` |
| `supabase/functions/owner-cash/index.ts:1` | `api.owner_open_cash_drawer` ? `supabase/migrations/20261110170000_cash_operations.sql:69`; `api.owner_close_cash_drawer` ? `supabase/migrations/20261110170000_cash_operations.sql:94`; `api.owner_list_cash_drawers` ? `supabase/migrations/20261110170000_cash_operations.sql:130` |
| `supabase/functions/owner-create-membership-purchase/index.ts:1` | `api.owner_create_membership_purchase` ? `supabase/migrations/20261103100000_owner_create_membership_purchase.sql:3` |
| `supabase/functions/owner-create-pin-enrollment-token/index.ts:1` | `api.owner_create_verified_pin_enrollment_token` ? `supabase/migrations/20261110130000_pin_recovery.sql:21` |
| `supabase/functions/owner-create-pin-recovery-token/index.ts:1` | `api.owner_create_pin_recovery_token` ? `supabase/migrations/20261110130000_pin_recovery.sql:39` |
| `supabase/functions/owner-list-members/index.ts:1` | `api.owner_list_members` ? `supabase/migrations/20261030180000_owner_list_members.sql:3` |
| `supabase/functions/owner-list-membership-plans/index.ts:1` | `api.owner_list_membership_plans` ? `supabase/migrations/20261103080000_owner_membership_plans.sql:37` |
| `supabase/functions/owner-list-membership-purchases/index.ts:1` | `api.owner_list_membership_purchases` ? `supabase/migrations/20261110190000_receipt_allocation_review.sql:403` |
| `supabase/functions/owner-membership-lifecycle/index.ts:1` | `api.owner_approve_member` ? `supabase/migrations/20261110110000_membership_lifecycle.sql:220`; `api.owner_activate_membership_purchase` ? `supabase/migrations/20261110110000_membership_lifecycle.sql:253` |
| `supabase/functions/owner-membership-payments/index.ts:1` | `api.owner_record_membership_payment` ? `supabase/migrations/20261103120000_owner_membership_payments.sql:246`; `api.owner_confirm_membership_payment` ? `supabase/migrations/20261103120000_owner_membership_payments.sql:399`; `api.owner_reject_membership_payment` ? `supabase/migrations/20261103120000_owner_membership_payments.sql:498`; `api.owner_list_membership_payments` ? `supabase/migrations/20261110190000_receipt_allocation_review.sql:271`; `api.owner_list_payable_purchases` ? `supabase/migrations/20261110200000_operational_reports.sql:58` |
| `supabase/functions/owner-receipt-review/index.ts:1` | `api.owner_verify_actual_receipt` ? `supabase/migrations/20261110160000_receipt_review_corrections.sql:90`; `api.owner_record_actual_receipt` ? `supabase/migrations/20261110160000_receipt_review_corrections.sql:118`; `api.owner_list_receipt_review` ? `supabase/migrations/20261110160000_receipt_review_corrections.sql:163`; `api.owner_void_payment_confirmation` ? `supabase/migrations/20261110160000_receipt_review_corrections.sql:278`; `api.owner_allocate_verified_receipt` ? `supabase/migrations/20261110190000_receipt_allocation_review.sql:42` |
| `supabase/functions/owner-register-member/index.ts:1` | `api.is_active_owner_for_user` ? `supabase/migrations/20261029100000_owner_authorization_rpc.sql:8`; `api.owner_register_member` ? `supabase/migrations/20261030130000_owner_register_member.sql:3` |
| `supabase/functions/owner-reporting/index.ts:1` | `api.owner_dashboard_summary` ? `supabase/migrations/20261110190000_receipt_allocation_review.sql:210`; `api.owner_list_audit_events` ? `supabase/migrations/20261110120000_owner_reporting.sql:78`; `api.owner_income_report` ? `supabase/migrations/20261110200000_operational_reports.sql:5`; `api.owner_expiry_reminders` ? `supabase/migrations/20261110200000_operational_reports.sql:31` |
| `supabase/functions/owner-save-membership-plan/index.ts:1` | `api.owner_save_membership_plan` ? `supabase/migrations/20261103080000_owner_membership_plans.sql:75` |
| `supabase/functions/owner-status/index.ts:1` | `api.is_active_owner_for_user` ? `supabase/migrations/20261029100000_owner_authorization_rpc.sql:8` |
| `supabase/functions/owner-walkins/index.ts:1` | `api.owner_set_walkin_fee` ? `supabase/migrations/20261110140000_walkin_operations.sql:237`; `api.owner_list_walkin_requests` ? `supabase/migrations/20261110140000_walkin_operations.sql:289`; `api.owner_confirm_walkin` ? `supabase/migrations/20261110140000_walkin_operations.sql:312` |
| `supabase/functions/public-walkin-request/index.ts:1` | `api.public_create_walkin_request` ? `supabase/migrations/20261110140000_walkin_operations.sql:261` |

### 13.2 All 79 distinct declaration markers and potential consumers

These are candidates covered by the 91-occurrence inventory, **not 79 confirmed
missing objects**. The supplied aggregate does not identify which occurrences
are absent/present, so per-object production state is UNKNOWN throughout.
The source column records every marker version and its declaration line when
available. Routine replacements intentionally repeat across versions.

Consumer mapping follows direct RPC roots, qualified function/table references
and statically declared triggers on referenced tables. Column markers inherit
their relation consumers rather than claiming exact column-level access. Trigger-protection edges
are conservative structural dependencies, including read-only consumers that
rely on protected data; they do not assert that a SELECT fires a trigger. Dynamic
SQL/policy/constraint/extension dependencies require the explicit migration matrix
and full isolated replay too. All consumers are potential release impact, not
evidence that a handler directly executes a private helper/table.

| Marker object (kind) | Source declaration(s) | Potential Edge consumers (structural, transitive) |
| --- | --- | --- |
| `api.owner_list_membership_plans` (routine_name) | `supabase/migrations/20261103080000_owner_membership_plans.sql:37` | `owner-list-membership-plans` |
| `api.owner_save_membership_plan` (routine_name) | `supabase/migrations/20261103080000_owner_membership_plans.sql:75` | `owner-save-membership-plan` |
| `api.owner_create_membership_purchase` (routine_name) | `supabase/migrations/20261103100000_owner_create_membership_purchase.sql:3` | `owner-create-membership-purchase` |
| `api.owner_list_membership_purchases` (routine_name) | `supabase/migrations/20261103110000_owner_list_membership_purchases.sql:3`; `supabase/migrations/20261103120000_owner_membership_payments.sql:694`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:403` | `owner-list-membership-purchases` |
| `private.guard_membership_payment_record_insert` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:38` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_membership_payment_record_update` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:84`; `supabase/migrations/20261110160000_receipt_review_corrections.sql:187` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_membership_payment_allocation` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:121`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:112` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.prevent_payment_history_mutation` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:163` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_purchase_pending_activation` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:206`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:149` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `api.owner_record_membership_payment` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:246` | `owner-membership-payments` |
| `api.owner_confirm_membership_payment` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:399` | `owner-membership-payments` |
| `api.owner_reject_membership_payment` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:498` | `owner-membership-payments` |
| `api.owner_list_membership_payments` (routine_name) | `supabase/migrations/20261103120000_owner_membership_payments.sql:559`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:271` | `owner-membership-payments` |
| `private.payment_records.operation_id` (column) | `supabase/migrations/20261103120000_owner_membership_payments.sql:6` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.membership_inclusive_expiry` (routine_name) | `supabase/migrations/20261110110000_membership_lifecycle.sql:63` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.membership_payment_confirmed_at` (routine_name) | `supabase/migrations/20261110110000_membership_lifecycle.sql:75`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:184` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.membership_activation_dates` (routine_name) | `supabase/migrations/20261110110000_membership_lifecycle.sql:92`; `supabase/migrations/20261110160000_receipt_review_corrections.sql:343` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_member_registration_approval` (routine_name) | `supabase/migrations/20261110110000_membership_lifecycle.sql:149` | `member-checkin`, `member-enroll-pin`, `member-reset-pin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-create-pin-enrollment-token`, `owner-create-pin-recovery-token`, `owner-list-members`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-register-member`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_membership_lifecycle` (routine_name) | `supabase/migrations/20261110110000_membership_lifecycle.sql:173`; `supabase/migrations/20261110160000_receipt_review_corrections.sql:202` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `api.owner_approve_member` (routine_name) | `supabase/migrations/20261110110000_membership_lifecycle.sql:220` | `owner-membership-lifecycle` |
| `api.owner_activate_membership_purchase` (routine_name) | `supabase/migrations/20261110110000_membership_lifecycle.sql:253` | `owner-membership-lifecycle` |
| `api.owner_dashboard_summary` (routine_name) | `supabase/migrations/20261110120000_owner_reporting.sql:34`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:210` | `owner-reporting` |
| `api.owner_list_audit_events` (routine_name) | `supabase/migrations/20261110120000_owner_reporting.sql:78` | `owner-reporting` |
| `api.owner_create_verified_pin_enrollment_token` (routine_name) | `supabase/migrations/20261110130000_pin_recovery.sql:21` | `owner-create-pin-enrollment-token` |
| `api.owner_create_pin_recovery_token` (routine_name) | `supabase/migrations/20261110130000_pin_recovery.sql:39` | `owner-create-pin-recovery-token` |
| `api.member_reset_pin` (routine_name) | `supabase/migrations/20261110130000_pin_recovery.sql:66` | `member-reset-pin` |
| `api.member_enroll_pin` (routine_name) | `supabase/migrations/20261110130000_pin_recovery.sql:101` | `member-enroll-pin` |
| `private.prevent_walkin_history_mutation` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:104` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_walkin_request_snapshot` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:122` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_walkin_allocation` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:167`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:251` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_paid_walkin_attendance` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:192` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_walkin_receipt_review` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:217` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `api.owner_set_walkin_fee` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:237` | `owner-walkins` |
| `api.public_create_walkin_request` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:261` | `public-walkin-request` |
| `api.owner_list_walkin_requests` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:289` | `owner-walkins` |
| `api.owner_confirm_walkin` (routine_name) | `supabase/migrations/20261110140000_walkin_operations.sql:312` | `owner-walkins` |
| `private.walkin_request_rate_events` (relation) | `supabase/migrations/20261110140000_walkin_operations.sql:40` | `public-walkin-request` |
| `private.receipt_review` (relation) | `supabase/migrations/20261110140000_walkin_operations.sql:59` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.walkin_requests.requested_payment_method` (column) | `supabase/migrations/20261110140000_walkin_operations.sql:33` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.member_checkin_eligible_purchase` (routine_name) | `supabase/migrations/20261110150000_member_checkin.sql:90`; `supabase/migrations/20261110190000_receipt_allocation_review.sql:196` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.guard_member_attendance_basis` (routine_name) | `supabase/migrations/20261110150000_member_checkin.sql:107` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `api.reserve_member_checkin_request` (routine_name) | `supabase/migrations/20261110150000_member_checkin.sql:130` | `member-checkin` |
| `api.prepare_member_checkin` (routine_name) | `supabase/migrations/20261110150000_member_checkin.sql:170` | `member-checkin` |
| `api.commit_member_checkin` (routine_name) | `supabase/migrations/20261110150000_member_checkin.sql:188` | `member-checkin` |
| `private.member_checkin_rate_events` (relation) | `supabase/migrations/20261110150000_member_checkin.sql:50` | `member-checkin` |
| `private.attendance_checkins.membership_purchase_id` (column) | `supabase/migrations/20261110150000_member_checkin.sql:40` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `api.owner_list_attendance` (routine_name) | `supabase/migrations/20261110153000_owner_attendance.sql:9` | `owner-attendance` |
| `private.assert_receipt_review_owner` (routine_name) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:64` | `owner-cash`, `owner-receipt-review` |
| `private.is_receipt_verified` (routine_name) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:79` | `owner-cash`, `owner-receipt-review` |
| `api.owner_verify_actual_receipt` (routine_name) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:90` | `owner-receipt-review` |
| `api.owner_record_actual_receipt` (routine_name) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:118` | `owner-receipt-review` |
| `api.owner_list_receipt_review` (routine_name) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:163` | `owner-receipt-review` |
| `private.guard_attendance_payment_invalidation` (routine_name) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:257` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `api.owner_void_payment_confirmation` (routine_name) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:278` | `owner-receipt-review` |
| `private.receipt_verifications` (relation) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:12` | `owner-cash`, `owner-receipt-review` |
| `private.payment_confirmation_voids` (relation) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:19` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `private.receipt_verification_voids` (relation) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:28` | `owner-cash`, `owner-receipt-review` |
| `private.receipt_replacement_links` (relation) | `supabase/migrations/20261110160000_receipt_review_corrections.sql:36` | `owner-receipt-review` |
| `private.guard_cash_session` (routine_name) | `supabase/migrations/20261110170000_cash_operations.sql:54` | `owner-cash` |
| `api.owner_open_cash_drawer` (routine_name) | `supabase/migrations/20261110170000_cash_operations.sql:69` | `owner-cash` |
| `api.owner_close_cash_drawer` (routine_name) | `supabase/migrations/20261110170000_cash_operations.sql:94` | `owner-cash` |
| `api.owner_list_cash_drawers` (routine_name) | `supabase/migrations/20261110170000_cash_operations.sql:130` | `owner-cash` |
| `private.cash_reconciliation_receipts` (relation) | `supabase/migrations/20261110170000_cash_operations.sql:20` | `owner-cash` |
| `private.cash_drawer_sessions.business_date` (column) | `supabase/migrations/20261110170000_cash_operations.sql:15` | `owner-cash` |
| `private.cash_drawer_sessions.operation_id` (column) | `supabase/migrations/20261110170000_cash_operations.sql:16` | `owner-cash` |
| `private.cash_reconciliations.reason` (column) | `supabase/migrations/20261110170000_cash_operations.sql:18` | `owner-cash` |
| `private.cash_reconciliations.evidence_reference` (column) | `supabase/migrations/20261110170000_cash_operations.sql:19` | `owner-cash` |
| `api.owner_submit_attendance_claim` (routine_name) | `supabase/migrations/20261110180000_provisional_claims.sql:39` | `owner-attendance-claims` |
| `api.owner_resolve_attendance_claim` (routine_name) | `supabase/migrations/20261110180000_provisional_claims.sql:62` | `owner-attendance-claims` |
| `api.owner_list_attendance_claims` (routine_name) | `supabase/migrations/20261110180000_provisional_claims.sql:102` | `owner-attendance-claims` |
| `private.owner_attendance_claims` (relation) | `supabase/migrations/20261110180000_provisional_claims.sql:5` | `owner-attendance-claims` |
| `private.owner_claim_resolutions` (relation) | `supabase/migrations/20261110180000_provisional_claims.sql:13` | `owner-attendance-claims` |
| `private.receipt_membership_target_matches` (routine_name) | `supabase/migrations/20261110190000_receipt_allocation_review.sql:32` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `api.owner_allocate_verified_receipt` (routine_name) | `supabase/migrations/20261110190000_receipt_allocation_review.sql:42` | `owner-receipt-review` |
| `private.receipt_allocation_reviews` (relation) | `supabase/migrations/20261110190000_receipt_allocation_review.sql:8` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |
| `api.owner_income_report` (routine_name) | `supabase/migrations/20261110200000_operational_reports.sql:5` | `owner-reporting` |
| `api.owner_expiry_reminders` (routine_name) | `supabase/migrations/20261110200000_operational_reports.sql:31` | `owner-reporting` |
| `api.owner_list_payable_purchases` (routine_name) | `supabase/migrations/20261110200000_operational_reports.sql:58` | `owner-membership-payments` |
| `private.payment_records.target_membership_purchase_id` (column) | `supabase/migrations/20261103120000_owner_membership_payments.sql:7` | `member-checkin`, `owner-attendance`, `owner-attendance-claims`, `owner-cash`, `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-lifecycle`, `owner-membership-payments`, `owner-receipt-review`, `owner-reporting`, `owner-walkins`, `public-walkin-request` |

### 13.3 Frontend-to-handler request/response review

All 21 endpoint names have a matching frontend consumer. The payload/response
checks below compare source, not real hosted success. Correctly typed empty
arrays are legitimate; A05 concerns malformed RPC results becoming empty arrays.
Every handler reference is its actual entrypoint; the direct RPC matrix above
provides final SQL definition lines. Additional shared validation is at
`supabase/functions/_shared/owner-register-request.ts:5`,
`supabase/functions/_shared/receipt-review.ts:4`,
`supabase/functions/_shared/member-checkin.ts:83` and
`supabase/functions/_shared/owner-reporting.ts:19`.

| Edge endpoint | Frontend call evidence | Request intent | Consumed/returned shape | Result / limitation |
| --- | --- | --- | --- | --- |
| `supabase/functions/owner-status/index.ts:1` | `src/App.tsx:82` | Owner session; no client-supplied Owner identity | authenticated/isActiveOwner/authorizationReady booleans | No static valid-request mismatch found; hosted JWT/role path untested. |
| `supabase/functions/owner-register-member/index.ts:1` | `src/components/MembersPage.tsx:269` | fullName/mobile | success + member.member_code; client also tolerates memberCode | Names compatible. Generic error UI does not parse FunctionsHttpError JSON for detailed mobile-conflict message; no sensitive error forwarding proposed. |
| `supabase/functions/owner-list-members/index.ts:1` | `src/components/MembersPage.tsx:189` | search/status/limit/offset | members[] (no success flag required) | Compatible normal array; A05 masks malformed RPC output. |
| `supabase/functions/owner-list-membership-plans/index.ts:1` | `src/components/MembershipPlansPage.tsx:56` | list request | plans[] (no success flag required) | Compatible normal array; A05 masks malformed RPC output. |
| `supabase/functions/owner-save-membership-plan/index.ts:1` | `src/components/MembershipPlansPage.tsx:156` | optional id/name/pricePhp/isActive | success + plan.id | No static valid-request mismatch found. |
| `supabase/functions/owner-create-membership-purchase/index.ts:1` | `src/components/MembershipPurchasesPage.tsx:216` | memberId/planId | success + purchase.id | Compatible; server supplies price/state, no activation date in request. |
| `supabase/functions/owner-list-membership-purchases/index.ts:1` | `src/components/MembershipPurchasesPage.tsx:171` | search/status/limit/offset | purchases[] (no success flag required) | Compatible normal array including payment_review; A05 masks malformed RPC output. |
| `supabase/functions/owner-membership-payments/index.ts:1` | `src/components/PaymentsPage.tsx:138` | action=list/payable/record/confirm/reject with action-specific fields | list result.payments/payablePurchases; payable purchases; mutation success + payment/confirmation/rejection | Matches dispatch; payable requires P17 and list final semantics require P16. Separate errors/retry payloads retained. |
| `supabase/functions/owner-membership-lifecycle/index.ts:1` | `src/components/MembersPage.tsx:239` | approve memberId/reason; activate membershipPurchaseId | success + member or purchase with expected IDs/states/dates | Matches shared dispatcher; source derives actor from getUser, not payload. |
| `supabase/functions/owner-reporting/index.ts:1` | `src/components/ReportsPage.tsx:21` | summary/audit/income/expiry with bounded filters | success + summary/events/income/expiries, exact-decimal amount strings | Matches source; UI wording at most 366 days corresponds to SQL through-from <=365 inclusive. Blank dates default in SQL. |
| `supabase/functions/owner-attendance/index.ts:1` | `src/components/AttendancePage.tsx:59` | search/fromDate/toDate/status/limit/offset | success + attendance[] | Names/date/status fields match SQL JSON; unavailable status remains separate from empty arrays. |
| `supabase/functions/owner-receipt-review/index.ts:1` | `src/components/ReceiptReviewPage.tsx:41` | list/record/verify/void/allocate, operation/evidence/target attestations | success + result (list array or action result) | Matches action parser; allocate needs P16, does not infer payment verification from UI. |
| `supabase/functions/owner-cash/index.ts:1` | `src/components/CashDrawerPage.tsx:28` | list/open/close with attestation, reason/evidence and operation ID | success + result; list has businessDate/status/float/totals | Matches SQL JSON. UI current date is advisory; server owns dates; stale drawer remains review. |
| `supabase/functions/owner-attendance-claims/index.ts:1` | `src/components/ClaimReviewPage.tsx:22` | list/submit/resolve, claimedLocalDate or confirmCurrentPresence/reason | success + result; immutable claim/resolution status | Matches dispatcher; no durable offline queue or client-proven historical attendance. |
| `supabase/functions/owner-create-pin-enrollment-token/index.ts:1` | `src/components/MembersPage.tsx:78` | memberId/identityVerified=true/reason | token/purpose=enrollment/expiresAt | Matches new P09 verified issuer. No success flag required by UI; raw token goes only to private fragment handoff. |
| `supabase/functions/owner-create-pin-recovery-token/index.ts:1` | `src/components/MembersPage.tsx:78` | memberId/identityVerified=true/reason | token/purpose=reset/expiresAt | Matches P09 issuer, no member PIN returned. |
| `supabase/functions/member-enroll-pin/index.ts:1` | `src/components/PinSetupPage.tsx:42` | token/pin | success=true / PIN_ENROLLMENT_COMPLETE | Matches generated-token path; request values are never accepted as actor/date/payment facts. |
| `supabase/functions/member-reset-pin/index.ts:1` | `src/components/PinSetupPage.tsx:42` | token/pin | success=true / PIN_RESET_COMPLETE | Generated 43-character tokens match. A11 covers wider invalid-input UI acceptance only. |
| `supabase/functions/member-checkin/index.ts:1` | `src/components/EntrancePage.tsx:58` | identifier/pin only | success=true + CHECKIN_ACCEPTED; denial/unavailable generic | Matches final constructed public result; raw prepare candidate/hash never forwarded. |
| `supabase/functions/owner-walkins/index.ts:1` | `src/components/WalkinsPage.tsx:73` | fee/list/confirm with fee/reason or immutable confirmation payload | success + fee/requests/result; confirmed result includes requestId/paymentId/outcome/attendanceId | Matches SQL confirmed versus receipt_review outcome; only Owner actually verifies money. |
| `supabase/functions/public-walkin-request/index.ts:1` | `src/components/EntrancePage.tsx:91` | paymentMethod only | success + request{id,feePhp,currency,paymentMethod,createdAt,expiresAt} | Matches allowlisted RPC shape; A08 covers lost-response duplication. |

The browser client is configured in `src/lib/supabase.ts:29`.
Owner identity still requires Auth verification in handlers and SQL authorization;
frontend types, hidden menus, Origin and gateway verify_jwt=false are not grants.
No confirmed valid-generated request/response naming mismatch was found in this
review. Failure-path A05/A06 and configuration A10 remain actual audit findings;
this conclusion does not certify malformed/unexpected payload handling everywhere.

## 14. Fresh baseline tests, GO/NO-GO and closing acceptance

These commands actually ran during this audit at 38fdf66. Test/generated outputs
are ignored local artifacts; only the report is changed in the tracked tree.

| Check | Fresh result | Scope / limits |
| --- | --- | --- |
| `npm.cmd run lint` | PASS | Static lint, not runtime authorization. |
| `npm.cmd run typecheck` | PASS | Frontend TypeScript compile. |
| `npm.cmd test` | PASS 37/37 | Includes source boundaries, safe errors, exact money, retry handling, synthetic handler HTTP and public diagnostic mocks; no real hosted calls. |
| `npm.cmd run test:security` | PASS | Static rules; no environment-file reads. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS | PG17/PG18 parser/AST/text/hash checks on all 16 diagnostic variants; approved original SQL unchanged; no SQL execution. |
| All 37 migration files parsed with cached PG17 grammar | PASS, 993 statements | Five leading BOMs removed only from parser input in memory. All function/DO bodies inspected as source; this does not validate hosted object resolution or authority. |
| Cached Deno shared tests | PASS 103/103 | `deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared`, using the installed binary and synthetic test values. |
| Cached Deno entrypoint typecheck | PASS 21/21 | `deno check --cached-only --node-modules-dir=manual` on the 21 exact `index.ts` paths; no dependency installation/deployment. |
| `npm.cmd run test:database` | PASS | Fresh isolated loopback PostgreSQL 18 cluster, synthetic Auth/records, all 37 files/phase behavior, final security assertions and nine deterministic two-session races. Cluster stopped. Hosted PostgreSQL 17/non-superuser compatibility UNKNOWN. |
| `npm.cmd run build` | PASS | Full Vite/PWA generation. PWA closeBundle emitted a slow-callback warning (approximately 316 seconds); exit was successful. This is a local toolchain timing observation, not a production request benchmark. |
| `node scripts/test-browser.mjs --production` | PASS | Synthetic Auth/API mobile entrance/Owner navigation, list failure/recovery, payment/walk-in handling, QR/PIN and static-only cache checks, no external application requests. Not real Supabase end-to-end acceptance. |
| Additional A05 negative probe | Defect reproduced in 3/3 tested list handlers | Real handler source loaded through Node TypeScript stripping and installed SDK; synthetic Auth JSON plus malformed RPC JSON object. All returned 200/empty array; expected fail-closed behavior remains unmet. |
| Additional A06 negative probe | Defect reproduced in 5/5 tested handlers | Real handler source, APP_ORIGIN only, trusted-origin OPTIONS; all returned 503. This reproduction does not claim production secrets are missing. |
| `git diff --check` / final report-reference validation | PASS | 37 migration references, 17 unchanged source fingerprints/dependency rows, 79 distinct marker rows, all 21 endpoint contracts, 11 findings and 262 in-bounds source-line references checked. Only this report changed. |
| Real hosted mutation/authorization tests, production SQL, Pages/Edge deployment | NOT RUN / UNTESTED | Explicitly outside audit scope; no production connection or configuration change. |

Additional-probe method: the five A06 handlers were member list, plan list,
plan save, purchase create and purchase list. For A05, `globalThis.fetch` was
replaced by a strict synthetic-origin dispatcher for member/plan/purchase list;
it supplied one verified synthetic Auth user and an RPC object where an array
was required. Six intercepted synthetic fetches occurred and **zero network
requests**. The assertions passing means the undesirable behavior was reproduced,
not that the product passed those negative requirements. No probe source or
application change was committed; exact affected code is cited in section 11.

Native database evidence:
`.cache/security-test-50f65182028645c1b5ae962f0aa0ee28`.
Browser evidence:
`.cache/browser-test-012a5c0e-4c26-49e5-bf5a-25784acf7fd8`.
The optional legacy incompatible-audit seed mode was not rerun; its older PASS
remains historical. The ordinary audit-timezone seed/behavior suites did pass.

### Evidence availability audit

`docs/production-preflight/` contains verification SQL, instructions/manifests,
status documentation and the SQL Editor archive. The archive inventory contains
16 SQL files, one JSON manifest, four Markdown files and one validator; it does
not supply the missing production result grids. Documentation is not a query
execution log. The Owner-supplied 88/3 marker and 22-table ENABLE RLS aggregates
are accepted as supplied evidence, but exact identities, defaults, signatures,
owners, executor memberships, full policy predicates, audit/data checks and
current endpoint deployment state remain UNKNOWN. No production bodies/records
are requested to resolve these; use private Owner review and sanitized outcomes.

### Final recommendation: NO-GO

Do not apply migrations, deploy handlers/frontend or open full operational use.
Local test PASS does not outweigh confirmed release gaps or unknown hosted
authority/data conditions. Keep the safe recovery order in section 6, with the
direct/chronological distinctions and source edges in sections 12–13.

Release acceptance requires all of the following, with explicit evidence:

1. **Metadata reconciliation:** identify the three present occurrences privately,
   resolve every incompatible/unmarked effect, verify exact 20-file baseline and
   P01–P17 prerequisites, and approve any further read-only scripts. Scripts
   03–07 remain held; no history repair or blanket replay is authorized.
2. **Authority/security:** hosted-equivalent ownership/default-ACL/runner proof,
   correct final owners/FORCE RLS/33-table allowlist, no executor memberships or
   schema CREATE leaks, api-only exposure and no direct browser/service table
   privileges. A02/A03 must be resolved technically, not waived as test PASS.
3. **Data/recovery:** Owner-approved audit/lifecycle/financial/legacy drawer
   outcomes, exact uniqueness/exclusion checks, preserved originals and tested
   backup/isolated recovery with agreed RPO/RTO and maintained key custody.
4. **Code defects:** separately authorize fixes for A05/A06, with regressions
   across all relevant handlers and legitimate-empty versus malformed-data
   cases. Review A08's lost-response operation/recovery policy before enabling
   public creation. Verify A09/A10 bundle/key configuration; address/document
   A11 without weakening the server format or generic responses.
5. **Controlled release:** Owner approves exact source bytes/runner/operator,
   window/locks/traffic controls, forward checkpoints and abort plan; then
   separately authorizes hosted settings, Edge bundles and normal Pages
   publication. No automatic merge/push/deploy follows this report.
6. **End-to-end acceptance:** actual isolated Auth/JWT/Edge/PostgREST/SQL success,
   negative and race tests; correct Owner-only payment/registration/renewal/
   expiry/receipt/cash/audit behavior, secure public QR/PIN and 15-minute walk-in
   workflow. Owner production reads must prove payment/payable/walk-in loading
   after release without introducing synthetic live financial records.
7. **Operating approvals:** approved fee, PIN token/KDF/abuse/runtime parameters,
   applicable privacy/retention/recovery/evidence procedures and real-device
   acceptance. Keep disabled release switches closed until those gates pass.

No finalized business rule was changed. The remaining application defects and
all production remediation are proposed work requiring the appropriate Owner
authorization after this report. **Audit work stops here.**

**Stop here for Owner review. No production apply, history reconciliation write,
permission change, release switch, Edge deployment, commit/push or Pages
deployment is authorized or performed by this report.**
