# GYMFORCE hosted diagnostic authorization form

**DRAFT ? NOT AUTHORIZED. Diagnostic session NO-GO until explicit, complete Owner approval.**
Prepared 2026-11-17, Asia/Manila. Preparation date is not an approval date.

This is an Owner-ready selection form, not an execution record. No approval is
preselected. Complete separate approval records for D-META and D-DATA. An
unselected unit is excluded. The inventory is a set of candidates, not a request
to run every unit. Approving a group name alone does not approve its files.

Read together with [approval governance](HOSTED-READINESS-OWNER-APPROVAL.md),
[reviewed SQL and diagnostic plan](HOSTED-READINESS-DIAGNOSTIC-PLAN.md), and
[decision matrix](HOSTED-READINESS-DECISION-MATRIX.md).

## Owner self-identification and personal approval scope

You have explicitly identified yourself as the **Project Owner / sole Developer /
Administrator** of Supabase project `alxhytivwybjbkjjdsyn`. This records your
statement in this session; it is not an independent verification of a hosted
account or database role, and it is not approval to execute diagnostics.
Your personal name, signature and approval date remain for you to complete.

You may personally approve and operate the diagnostic session in your Owner /
Administrator capacity. Having all three project responsibilities does not
establish the database connection's effective role, session role, client behavior
or privileges. Those still require verification through the approved access
path. Your declaration grants no credentials or production access to this
assistant. Raw production evidence remains under your Owner-controlled custody;
only the explicitly approved sanitized summary is shared for source review.

The complete candidate scope is **25 D-META units and five D-DATA units**, listed
individually below with their reviewed hashes. Metadata covers identity, history,
catalogs, routine/schema/table permissions, default ACLs, RLS, role authority and
legacy dependencies. Data checks cover baseline finance/attendance, registration /
plans / cash, audit-chain consistency, and conditional lifecycle and additional
legacy safeguards. No unit is selected automatically. You must identify the
exact subset, or explicitly name all 30 listed units with their conditional skips,
and approve the proposed order after completing the remaining fields.

### Information still requiring your confirmation

1. Selected D-META and D-DATA unit IDs, exact hashes and execution order, including
   optional omissions and prerequisite-dependent skips.
2. Existing operator/access path and client, intended database session/effective
   roles, and private confirmation of the actual target project. Do not provide
   credentials. H01 must later verify actual context; project identity is checked
   outside SQL.
3. Execution date, start/end time and timezone, and approval reference.
4. Evidence custodian (yourself or an explicitly named custodian), private storage,
   access restrictions, retention period/start/expiry, secure disposal method and
   responsibility, and any provider-controlled retention limitations.
5. Sanitized reporting route and recipient, prerequisite evidence, complete-result
   support and reliable same-session cancellation/rollback procedure.
6. Acceptance of the 30s statement / 2s lock limits and mandatory stop conditions,
   any required quiet-window/backup prerequisite, and rules for later reruns.
7. Your name, signature or explicit approval reference, approval date/time and
   explicit decision. None is supplied by this preparation.

After you explicitly approve a completed scope, the next task is authorization
verification and a **read-only pre-flight without hosted SQL execution**. It must
stop if the approval, bytes, actor, prerequisites or privacy conditions are
incomplete. A successful pre-flight does not itself execute SQL or authorize
migrations, repairs or deployments.

## Verified local preparation facts

| Field | Verified repository/context value | Execution requirement |
| --- | --- | --- |
| Intended target | Supabase production project `alxhytivwybjbkjjdsyn`, previously confirmed by Owner | Owner must confirm actual Dashboard/connection target privately before execution; catalog SQL cannot establish project reference. |
| Local review branch | `review/production-recovery` | This is source context, not the hosted deployment branch certification. |
| Local HEAD | `db700c1f42cdf561e3f55d61897ba8eb4948c94e` plus uncommitted recovery work | Commit SHA alone does not pin these uncommitted diagnostics; use each exact hash below. |
| Hash inventory | 27 existing file byte hashes and three embedded block hashes match the reviewed plan during this preparation | Recheck before approved execution; mismatch stops execution and requires renewed review. |
| Existing safety wrapper | REPEATABLE READ READ ONLY; transaction-local statement_timeout 30s, lock_timeout 2s, search_path pg_catalog; final ROLLBACK | Run the entire approved unit separately, unchanged; no selected SELECT without its wrapper. |
| Hosted status | NOT VERIFIED in this preparation | No production connection or SQL execution performed. Local review does not certify hosted identity, visibility or compatibility. |

Embedded block hashes use the SQL text inside the plan's H01/H02/H03 fences,
LF line endings and one final LF; fence markers are excluded. Existing file
hashes cover exact bytes without line-ending normalization. If preparing an
execution copy changes its bytes, review and pin that copy before approval.
The form does not duplicate or alter the reviewed SQL.

## Owner completion record ? complete separately for each scope

| Required field | Entry for Owner completion |
| --- | --- |
| Approval record/reference | REQUIRES OWNER CONFIRMATION |
| Scope | [ ] D-META (selected catalog/metadata units only) / [ ] D-DATA (selected confidential aggregate units only) |
| Authorized unit IDs/paths | REQUIRES OWNER SELECTION in the inventory below; no folder-wide authorization |
| Approved exact order/subset | REQUIRES OWNER CONFIRMATION; use the order table below, listing each selected unit and conditional skip |
| Target environment | Intended production `alxhytivwybjbkjjdsyn`; actual target verification REQUIRES OWNER CONFIRMATION |
| Owner-declared project responsibilities | Project Owner / sole Developer / Administrator, as explicitly stated in this session; hosted account/role not independently verified |
| Existing approved operator | Proposed personal operator: you, in your Owner / Administrator capacity; actual execution identity/client REQUIRES OWNER CONFIRMATION privately; no credentials or new login authorized |
| Approved effective role and session role | REQUIRES OWNER CONFIRMATION; authority certification expects both current_user and session_user to be postgres; H01 must verify actual values |
| Existing approved client/access path | REQUIRES OWNER CONFIRMATION; must support complete results and same-session closure; SQL Editor identity cannot certify a different CLI connection |
| Execution date | REQUIRES OWNER CONFIRMATION |
| Start/end time and timezone | REQUIRES OWNER CONFIRMATION; record Asia/Manila and UTC equivalents |
| Evidence custodian | REQUIRES OWNER CONFIRMATION; Owner-controlled custody, not routine Developer access |
| Private storage/access controls | REQUIRES OWNER CONFIRMATION; identify restricted storage reference, encryption and named authorized viewers privately; do not include secrets or raw evidence here |
| Evidence retention | REQUIRES OWNER CONFIRMATION; specify duration, start event, expiry/review date and any authorized preservation hold |
| Secure disposal | REQUIRES OWNER CONFIRMATION; specify responsible person, deletion method, export/backup/query-history copies and completion record; provider log retention may require confirmation |
| Sanitized reporting method/recipient | REQUIRES OWNER CONFIRMATION; statuses, narrow categories, approved identifiers and SQLSTATE only; no raw grids |
| Prerequisite evidence references | REQUIRES OWNER CONFIRMATION; target/actor, actual source stage, schemas/tables/types/columns, visibility and prior diagnostic outcomes |
| Cancellation/transaction cleanup operator and method | REQUIRES OWNER CONFIRMATION; rollback or close the actual session and privately verify closure/lock release; a new SQL Editor click may be a different backend |
| Backup/quiet-window prerequisite, if required for this scope | REQUIRES OWNER DECISION; do not infer backup capture, restore or maintenance-change authorization. Backup/restore evidence remains a separate release gate. |
| Rerun authorization | REQUIRES OWNER CONFIRMATION for any rerun; no automatic retry after error or changed bytes, actor, stage or window |
| Owner name | REQUIRES OWNER COMPLETION |
| Owner signature / explicit approval reference | REQUIRES OWNER COMPLETION; do not fabricate or prefill |
| Approval date/time/timezone | REQUIRES OWNER COMPLETION |
| Decision | [ ] APPROVE ONLY SELECTED UNITS WITH COMPLETED CONDITIONS / [ ] HOLD |

Do not put connection strings, keys, passwords, PINs, tokens, member information,
payment details, raw role graphs or function bodies into this form or Git.
Private identity/storage details may be referenced through an Owner-controlled
record rather than published here; no credentials need to be shared.

## Exact candidate scope ? all boxes intentionally unchecked

The Owner selects only necessary units. D-META excludes business-row scans.
D-DATA requires separate selection and verified full visibility on every
referenced relation. Presence in this table confers no authorization.

| Select | Scope | Exact source or embedded block ID | Reviewed SHA-256 |
| --- | --- | --- | --- |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-01-identity.sql` | `ec2ae5068417de800407c4fc3a4b6c42a3b81d9343a224a48dc12d28ae142f18` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-02-migration-history.sql` | `0f68ecadba3b65beb5107a8497e76973de276d58ae0e503ee0f2abfbb906e5a2` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-03-schemas.sql` | `accea708dec33e38eea1673b79ff3c21cd96c5d31833fbad50444840eb89ec04` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-04-routines.sql` | `50d815a047c48f35d5001f0a825ce679bc6ebf874ea31cd11905d494a062bbbc` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-05-routine-acls.sql` | `c2e4359b1c6dfb1f800c8e8d0dc22ab7fbde935358ace1ea7a8af2e26ad28e0a` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-06-routine-permissions.sql` | `2c140b40743119cd219595d5dbc7afb3a0f91ad6c28e95dfdccc01ccd3a6f76f` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-07-schema-permissions.sql` | `ead08012da6869e6878d30b7d011b5a7fccb6d05fa44bd1edc98e275c33e8c8d` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-08-default-acls.sql` | `694c079db19c118793d726c0abd458a73b3ca56fd1672ae1ae863927130cb008` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-09-table-rls.sql` | `8144c90e46ee7763df79aa2b06b1fc2e142f1496863126eef3b1241ee93255d1` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-10-table-permissions.sql` | `b37dfc50a9bbf51a9c946563176466ab35b0871f63f1b1d0a04c4b1159d0e7d3` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-11-policies.sql` | `077a49111cbe6579f08803d8281d37872423cd33e1251249624337ff4481da86` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-12-columns.sql` | `4fc5cfa7c15d7c750474a61896d75e8062d931d87b5f8bd93f6192f28bd25038` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-13-triggers.sql` | `372743b4fc21ac68b2ab006c3b05ada592b61916db6f5b13e5070a6c5fe078fe` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-14-constraints.sql` | `81e3ba555247fb1376cd364bd1831f670418782d2c037f92d6a589569d20d3cd` |
| [ ] | D-META | `docs/production-preflight/sql-editor/01-15-indexes.sql` | `410fb2525972b1dd43b7236544a32a77ad3771b948a3288af3508426c9e2ba14` |
| [ ] | D-META | `docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql` | `71bca850a5ddb76ffbb15ab32a28c2bcca86209fa107bd5cbd00f5f82a14ba76` |
| [ ] | D-META | `supabase/recovery/history.sql` | `38195ddb8a3f01b8d8a8b65b1560b04c3e2d78fb086a77f782fd7f957ad6ebe9` |
| [ ] | D-META | `supabase/recovery/catalog.sql` | `8e564aa33500db90e52c9582a669699348489908656fe4cc5f7298a0acee4eef` |
| [ ] | D-META | `supabase/recovery/effective-privileges.sql` | `43bfad19d3a7b3b2dc41c87d0414c89e025a27c09190fd659442c1465f7febad` |
| [ ] | D-META | `supabase/recovery/diagnostics/compatibility-authority.sql` | `7ef743624536dc44098e1341c49426868b3338f1c5879d97fe7e25c662ab2cc2` |
| [ ] | D-META | `supabase/recovery/diagnostics/migration-authority.sql` | `7be262a2d013824ba12aa1ce4a452ddcc4fc211b588c607ecf5728510f8b14ea` |
| [ ] | D-META | `supabase/recovery/diagnostics/legacy-dependencies.sql` | `a8b352b01cf27de47424a0396f4aeee71173244862cac1c727d132036f8ed19f` |
| [ ] | D-DATA | `supabase/recovery/diagnostics/registration-plan-cash.sql` | `9a0b31dd2c674d641cf8e6432c0e382f08f4b7543d10b2cddbbba292e085922a` |
| [ ] | D-DATA | `supabase/recovery/diagnostics/audit.sql` | `baf6c309770944b4a0153f344eab2a31265aa3df1af3215d2f7d537b7e45ed4d` |
| [ ] | D-DATA | `supabase/recovery/diagnostics/lifecycle-payments.sql` | `0d5afa002dfac8b133d02be1be98d473a3b5ee6b3dac6cf84ab49761a47c3809` |
| [ ] | D-DATA | `supabase/recovery/diagnostics/additional-legacy-blockers.sql` | `d2361a019c4716ea1f5b38bc5c795a384030fd9215d7100c0531f057fd4d5602` |
| [ ] | D-META | `supabase/recovery/compatibility/review/effective-privileges.sql` | `88f2d95127f4e996ac938e4235d28108fc9052caf9d6c6906b8738c3f3f2a7a6` |
| [ ] | D-META | `H01` | `7f6aea263b9d7305bd60554e398dd607e426c80774bd92875975429e468804be` |
| [ ] | D-META | `H02` | `ee124d5d1cc5a28cd846982c7de029aa75e104096c9e42cc6d80f39746f6fa5c` |
| [ ] | D-DATA | `H03` | `ec5fe157c88734e8b1f4c31e1136fa19b1eb1e6a8227e15c2428b16230f30d02` |

## Proposed order, prerequisites and expected outputs

This table is copied from the reviewed plan. It is not an approved execution
schedule. Approve each selected SPLIT01 file individually in 01-01 through 01-15
order. SECURITY has two separately selectable units, strict effective-privileges
then H02. Omitted optional units do not waive an indispensable prerequisite;
record how its evidence is established or stop the dependent diagnostic.

| Order / ID | Exact source | Prerequisite and expected output / meaning |
| --- | --- | --- |
| 1 H01 | Embedded below | One context JSON; readOnly=on, actual version/role flags. Wrong target/actor/version stops certification; project confirmed outside SQL. |
| 2 HISTORY | `supabase/recovery/history.sql` | History schema/table/version readable; one format/versions JSON. Compare offline; expected historical prefix 20/17 is NOT a release PASS. |
| 3 CATALOG | `supabase/recovery/catalog.sql` | Catalog visibility, SHA-256 built-in available; one private_catalog JSON with object fingerprints, readable/filtered flags and serverMajor. No bodies returned. |
| 4 SPLIT01 | `docs/production-preflight/sql-editor/01-01-identity.sql` through `01-15-indexes.sql` (exact manifest filenames below) | Fifteen individually wrapped result sets: identity/history/schema/routines/ACLs/effective function and schema permissions/default ACLs/RLS/table permissions/policies/columns/triggers/constraints/indexes. Some overlap H01-H02; optional, approve only needed files. |
| 5 MARKERS | `docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql` | Readable history and normal catalogs; 91 tuple occurrences across 15 versions, 79 distinct markers; two pending versions have no declaration markers. Reconcile actual present tuple identities; never infer three objects from three occurrences. |
| 6 AUTHORITY | `supabase/recovery/diagnostics/compatibility-authority.sql` | PG17 catalogs; one JSON of actual actor, four reserved roles/edges, schema grant authority, digest access and cleanup paths. Missing role => not yet testable, not compatible. No authority mutation test. |
| 7 STRICT-AUTH | `supabase/recovery/diagnostics/migration-authority.sql` | Original zero-edge interpretation, distinct from revised boundary. Diagnostic can legitimately report restricted-model differences. Never erase that distinction. |
| 8 SECURITY | `supabase/recovery/effective-privileges.sql`, H02 below | Ten strict-screen PASS/FAIL rows plus one H02 richer private JSON. Creator/role/default failures must be evaluated at the actual pre-hardening stage. Missing-role/empty inventories prevent blanket PASS. |
| 9 REVISED-SCREEN | `supabase/recovery/compatibility/review/effective-privileges.sql` | Optional explicitly revised ADMIN-edge screen, not the synthetic profile. Same scope plus exact exception. A PASS needs all expected roles/objects and independent stage reconciliation. |
| 10 LEGACY-META | `supabase/recovery/diagnostics/legacy-dependencies.sql` | One JSON: superseded aggregate limiter relation presence/dependency/policy/trigger counts plus rolling limiter relation/RPC presence. Counts omit dynamic/runtime/external callers. Zero is not unused; no removals approved. |
| 11 BASELINE-DATA | H03 below | Confirm four baseline relations/columns and full visibility; one JSON of seven narrow baseline finance/attendance checks. No pending columns needed; failures require Owner review, not corrections. |
| 12 REGISTRATION | `supabase/recovery/diagnostics/registration-plan-cash.sql` | members(status,approved_at), membership_plans(name), cash_drawer_sessions(id); two results: registration/normalized-plan booleans and any-legacy-drawer gate. Closed drawers still block P14. |
| 13 AUDIT | `supabase/recovery/diagnostics/audit.sql` | Full SELECT/no active RLS for audit_events and audit_chain_heads, exact columns in checks.json, version-1 hash contract. Four statuses: stream keys, links, inline UTC hash, heads. No application verifier/append RPC called. |
| 14 LIFECYCLE | `supabase/recovery/diagnostics/lifecycle-payments.sql` | P04 operation_id/target_membership_purchase_id and all checks.json columns must actually exist. Five named outcomes: dates/payment basis, external references, pending attempts, allocations, operation IDs. Missing columns on 20-file baseline => SKIP/UNKNOWN, not create-to-test. |
| 15 ADDITIONAL | `supabase/recovery/diagnostics/additional-legacy-blockers.sql` | P10 requested_payment_method and P11 membership_purchase_id plus all checks.json columns required. Five outcomes: walk-in allocation uniqueness, dated review terms, replacement overlaps, legacy attendance basis/method. Stage-dependent, not universally runnable now. |

For conditional data checks, use the exact relation/column requirements in
`supabase/recovery/checks.json` and the reviewed plan, including H03's baseline
columns. Catalog presence alone does not establish SELECT visibility. Missing
P04 columns prohibit LIFECYCLE; missing P10/P11 columns prohibit ADDITIONAL.
Do not install prerequisites, grant visibility or run migrations to make checks
runnable. Missing reserved roles may be expected before hardening but cannot
establish A02 compatibility. Strict and revised authority screens have distinct
contracts and must not be substituted silently.

## Prerequisite acknowledgements ? Owner review, not preapproved

- [ ] I have selected exact units/hashes/order separately for metadata and data scopes.
- [ ] I have confirmed target, existing operator/client and window privately.
- [ ] I have reviewed the actual database stage and each selected unit's prerequisites.
- [ ] I have verified full SELECT and no active RLS filtering for all selected data checks; otherwise they remain UNKNOWN and will not run.
- [ ] My client preserves all result sets, including both REGISTRATION results, and allows reliable closure of the same transaction.
- [ ] I accept one-unit-at-a-time execution, unchanged wrappers, 30s statement and 2s lock limits, and the stop conditions below.
- [ ] I have completed custodian/access/retention/disposal/reporting fields and approved the private handling of confidential aggregate results.
- [ ] I have resolved any specifically required quiet-window or backup evidence prerequisite without treating this approval as permission to capture/restore backups or change traffic controls.
- [ ] I understand local PG17 success and read-only catalog results do not prove Supabase-hosted migration authority or production readiness.

## Mandatory stop conditions and dependent exclusions

Stop before starting if any authorization field, selection, hash, target,
identity, window or required privacy control is missing. Stop on changed bytes,
unexpected actor, unsupported PG major for the reviewed PG17 path, missing
prerequisite, error, timeout, cancellation, hidden/truncated result or unknown
transaction closure. Mark affected/dependent outcomes UNKNOWN. Verify actual
same-session rollback/closure and lock release privately before further work;
never increase timeouts or blindly rerun.

If H01 target/context validation fails, do not proceed with the session. If
history differs from the supplied 20-version prefix or schema/history disagree,
stop for reconciliation. Do not run data checks after failed visibility or
prerequisite checks. Unexpected grants, role options, definer configuration or
legacy/audit failures stop related certification and release; no repair is
permitted. A diagnostic FAIL may be expected at a pre-hardening stage and must
be assessed against that stage, not automatically fixed.

Unselected diagnostics and original preflight 03-07 remain held. In particular,
no proposal SQL, compatibility migration variant, test fixture,
maintenance-rls-proof.sql or history-fixture.sql is authorized. No application
RPC is called merely because its EXECUTE privilege appears true.

## Privacy-safe evidence record

Complete privately for each approved unit, then share only the approved redacted
summary through the named route. Metadata grids and even aggregate business
statuses are confidential. Do not export raw member/payment/audit records,
function bodies, policy expressions, credentials, tokens or PIN material.

```text
Approval reference / diagnostic ID / exact SHA-256:
Observation UTC and Asia/Manila time:
Target / actual actor / approved client confirmed privately: PASS / FAIL / UNKNOWN
Actual source stage and prerequisite/visibility verdict:
Complete results and same-session transaction closure: PASS / FAIL / UNKNOWN
Narrow outcome: PASS / FAIL / UNKNOWN; approved check labels only
Marker occurrence classifications/source identifiers, only if approved:
Private evidence reference / custodian / authorized access:
Retention expiry / disposal responsibility and completion reference:
Sanitized SQLSTATE/category (no raw error text):
Next decision: NEXT NAMED AUTHORIZED UNIT / STOP / OWNER REVIEW
```

## Explicit authorization boundary

**Only explicitly selected, signed, time-bounded read-only diagnostics may be
authorized by this form.** It does not authorize migration execution, migration
history changes/repair, production data changes, role/membership/grant/RLS/schema
changes, configuration changes, commits, push/merge, Edge or frontend deployment,
feature activation, new connections/logins, support messages, infrastructure,
backup capture or restore. Those require their own explicit approvals.

Preparing or signing an incomplete form does not grant authority. Earlier 01/02
approval does not expand to this package. Diagnostic PASS authorizes no mutation.
Production remains NO-GO until every separate mandatory gate is evidenced and
approved. **Stop for Owner review; no hosted session has been authorized here.**
