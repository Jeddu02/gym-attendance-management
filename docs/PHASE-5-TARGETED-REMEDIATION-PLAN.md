# Phase 5 targeted remediation plan

Prepared **2026-11-19, Asia/Manila**. Existing project:
`Jeddu02/gym-attendance-management`, branch `master`, HEAD
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.

**Production NO-GO. This document authorizes no execution.** Only this file is
created. No application, migration, diagnostic SQL/hash, permission, role, RLS,
schema, history, configuration or existing report is changed. No connection,
SQL, migration, restore, environment creation, broad regression, commit or push.

## 1. Scope and current evidence

Authority for this plan is the completed
`docs/PHASE-5-CONSOLIDATED-COMPATIBILITY-RECOVERY-REVIEW.md:14`, with its private
evidence references PE-U01/02/03/19/20/22/23/25. The existing Owner-controlled
packet remains outside the repository; no raw evidence is reproduced here.
The saved results were reviewed previously, not collected again in this task.
Their date/stage is historical, not a claim about production on November 19.
Owner confirmation of freshness is required before relying on them for execution.

Established snapshot facts:

- 20 recorded versions match the original local prefix; 17 local versions remain
  unrecorded. Recorded history does not prove original applied bytes.
- 91 marker occurrences: 88 absent, three present without history across P01/P09.
  Two P01 plan RPC identities match but composite fingerprints differ. Their
  normalized-name index matches the P01 reference. The third occurrence is the
  older baseline enrollment function, whose composite fingerprint matches.
- All 12 recorded-baseline routine fingerprints match the existing local reference;
  the two plan routines bring the observed total to 14. All observed routine
  owners are postgres; 12 routines are SECURITY DEFINER, all 14 have empty search
  paths. The saved Owner database actor has pre-existing BYPASSRLS.
- Four reserved roles are absent. Zero provider-edge/temporary-path counts are
  vacuous for those nonexistent roles; executor digest EXECUTE is null.
- Unit 22 has seven PASS and three FAIL: missing_reserved_roles,
  creator_global_public_function_default, direct_browser_or_service_data_access.
  H02 identifies global PUBLIC function defaults for two creator classes; it
  does not establish that provider defaults can or should be changed.
- 21 of 22 table fingerprints match the baseline reference. The exception is
  public.gym_settings. No component-level cause was established.
- No D-DATA or demonstrated real restore/RPO/RTO evidence was supplied in that
  packet. P04 payment operation/target, P10 walk-in method and P11 attendance
  basis columns were absent. Units 29/30 therefore remain prerequisite-blocked.

Existing local PG17 tests are historical supporting evidence only. Prior offline
checks verified 75 source fingerprints and 40 compatibility artifacts; this plan
does not rerun or promote those checks into hosted proof. Source references:
consolidated review `:46`, `:87`, `:235`, `:279`, `:337`.

## 2. Object discrepancies: exact questions to resolve

| Object / stage | Expected local definition and source | Observed evidence | Possible cause, not a finding | Exact additional evidence and acceptance |
| --- | --- | --- | --- | --- |
| api.owner_list_membership_plans — P01 20261103080000 | `(uuid) RETURNS jsonb`, PL/pgSQL SECURITY DEFINER, empty search path; active Owner check; ordered JSON plan array including legitimate empty array; service-only EXECUTE. `supabase/migrations/20261103080000_owner_membership_plans.sql:37`, `:195`, `:201`. | One observed overload with expected identity; composite definition/owner/ACL fingerprint differs from P01. | Older/manual implementation, whitespace/deparser representation, configuration or grant difference. No malicious change is established. | Private per-component comparison: complete identity/input names/types/defaults/result/language/config/definer flags, definition/body hashes, owner and canonical ACL comparison, plus dependencies. Retain original composite digest. Every difference must have an approved disposition before replacement; a matching name or reformatted hash is insufficient. |
| api.owner_save_membership_plan — same P01 | `(uuid,uuid,text,numeric,boolean) RETURNS jsonb`; same Owner/definer/search-path boundary; normalized unique name, positive exact PHP price, create/update locking and audit append; service-only EXECUTE. Same file `:75`, `:105`, `:140`, `:169`, `:197`, `:202`. | One expected identity; different composite fingerprint; normalized-name index fingerprint matches. | Same possibilities; index presence does not prove the function body or P01 installation/history. | Same component evidence, with private proof of argument/result compatibility, exact validation/audit behavior and dependent caller compatibility. No DROP to force a return/argument change. Confirm the already-matching index remains valid at the accepted stage; do not rebuild it merely for reconciliation. |
| api.member_enroll_pin — recorded baseline versus P09 20261110130000 | Baseline `(text,text) RETURNS jsonb` in `supabase/migrations/20261030150000_member_pin_enrollment.sql:3`. P09 replacement at `supabase/migrations/20261110130000_pin_recovery.sql:101` adds common advisory/member/token lock ordering, expiry recheck after waits and credential-version semantics; related issuer permissions at `:131`, `:141`. | One identity and exact older-baseline composite fingerprint; differs from P09-stage reference. | Expected reuse of an existing function name in a later replacement; no separate drift cause needs inventing. | Treat PRESENT-OLDER as reconciled classification, not P09 applied. No standalone repair is justified now. Before eventual P09, verify the then-current P05/P07-stage prerequisites, replacement signature/default/result contract and preserved one-use-token behavior. No PIN/token/credential rows need export. |
| public.gym_settings — foundation, then P05 transfer/hardening | Original relation/RLS/client revocations in `supabase/migrations/20261028061728_initial_schema.sql` access section; P05 includes it in the 22-table transfer/force/ACL inventory. `supabase/migrations/20261110100000_executor_hardening.sql:35`, `:827`. | Composite relation fingerprint differs; other 21 table fingerprints match. The data-privilege screen also fails, but causation is unknown. | Owner, explicit/default/inherited ACL, RLS flag or another relation component; a provider-created grant is only a hypothesis. | Return separate relation-kind/owner/ACL-component hashes, ENABLE/FORCE flags and effective privileges for approved callers; policy metadata/hash and dependency differences if relevant. Independently attribute every data-screen violation. Explain the difference before selecting any correction. |

Three markers are not three newly introduced objects and do not imply either
migration was applied. Marker scope omits P05/P06 declaration coverage and many
indexes/constraints/policies/ALTER effects. Exact reference fingerprints remain
unchanged; secondary semantic/format comparisons must never overwrite or conceal
an original mismatch. Catalog composition is `supabase/recovery/catalog.sql:8`,
`:19`; name-only checks are
`docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql:103`.

## 3. Prioritized remediation matrix

IDs/severities preserve the consolidated review: **one critical, four high,
two medium and one low**. These are eight finding categories, not eight proven
exploits or eight independent production defects. Split work packages below
avoid double-counting their shared dependencies.

| Priority / finding | Confirmed fact versus unknown root cause | Corrective approach / source-change decision | Exact source references |
| --- | --- | --- | --- |
| P0 — CR-01, Critical | Actual accepted provider/runner authority and real restore capability are not demonstrated. Original non-superuser zero-edge requirements conflict with ordinary role-creation assumptions; operational recovery evidence is missing, not proven nonexistent. | Qualify the accepted authority/runner and recovery method before any mutation. Existing compatibility artifacts are candidates, not approved migrations. If the provider cannot support them, commission a new reviewed architecture; do not bypass assertions. No source correction is established merely by missing evidence. | `scripts/recovery/build-compatibility.mjs:25`, `:48`, `:69`; `docs/production-recovery-plan.md:377`, `:518`, `:539`. |
| P1 — CR-02, High | Two P01 fingerprints differ; one older enrollment matches; plan index matches. Exact divergent component/cause is unknown. | Resolve section 2 via M1 below. If ACL/config-only, propose narrowly scoped changes; if body/contract differs, prepare an explicitly reviewed forward compatibility artifact before P05. Preserve originals and truthful provenance/history. No automatic P01 replay or function DROP. Source changes are conditional on evidence and separate authorization. | `supabase/migrations/20261103080000_owner_membership_plans.sql:29`, `:37`, `:75`, `:195`; `supabase/migrations/20261110130000_pin_recovery.sql:101`; `supabase/recovery/catalog.sql:19`. |
| P1 — CR-03, High | Direct data access FAIL and gym_settings metadata difference are confirmed. Exact caller/object/privilege origin and any causal link remain unknown. | M2 attributes violations before a smallest effective-privilege correction is proposed. Review table AND column/sequence/inherited grants; a top-level REVOKE may not remove inherited access. Preserve necessary RPC functionality and no direct browser/service protected data access. No present grant change or app-code fix is justified yet. | `supabase/recovery/effective-privileges.sql:21`; `supabase/recovery/catalog.sql:8`; `supabase/recovery/proposals/01-explicit-routine-acls.sql:25`, `:39`. |
| P1 — CR-04, High | Four roles absent; final owner/FORCE model not installed; global PUBLIC defaults for application/provider creator classes. Missing roles are stage-expected; final access model remains unmet. | Review actual creators and effective inheritance; plan P05–P17 restricted owners/FORCE policies after authority approval. Review proposal 02's database-wide postgres impact separately. Never revoke provider defaults blindly or treat empty pg_default_acl as deny. Source/design revision only if scope/provider evidence requires it; maintain explicit per-RPC deny/allowlists. | `supabase/recovery/effective-privileges.sql:30`, `:38`, `:45`; `supabase/recovery/proposals/02-postgres-future-routine-defaults.sql:15`; `supabase/migrations/20261110100000_executor_hardening.sql:827`; `supabase/migrations/20261110150000_member_checkin.sql:16`, `:38`. |
| P1 — CR-05, High | Actual finance/audit/lifecycle/attendance/cash safety UNKNOWN; four pending columns absent. No corruption is established. | Authorize only prerequisite-qualified baseline aggregates first. Separately design required missing uniqueness/legacy checks; never infer or populate payment/approval/date/basis facts. Any real anomaly needs Owner evidence and a separately reviewed correction/reconciliation design. No data repair or source workaround to bypass a refusal. | `supabase/recovery/checks.json:54`, `:132`, `:138`; `supabase/migrations/20261110110000_membership_lifecycle.sql:36`, `:52`; `supabase/migrations/20261110160000_receipt_review_corrections.sql:239`; `supabase/migrations/20261110170000_cash_operations.sql:12`. |
| P1 — CR-06, Medium | Saved output tags support completion but do not prove full target/client/TLS/source/approval/exit-code provenance. Missing records are not proof of unauthorized execution. | Owner first completes private references from existing records. Only irrecoverable, decision-relevant gaps justify a narrowly approved refresh; no blanket rerun. No application/migration change needed. | `docs/PHASE-5-CONSOLIDATED-COMPATIBILITY-RECOVERY-REVIEW.md:46`; `docs/PHASE-5-2-WINDOWS-PSQL-QUALIFICATION.md:222`; `docs/HOSTED-DIAGNOSTIC-AUTHORIZATION-FORM.md:1`. |
| P1 — CR-07, Medium | Revised four-edge ADMIN exception has no supplied adoption decision; actual provider operations remain unproven. | Obtain O2 and supported actor-specific answers. If rejected, keep the original contract blocked rather than weakening it. Acceptance is design adoption only, not execution approval. No source change is needed just to record a decision. | `scripts/recovery/build-compatibility.mjs:18`, `:25`; `supabase/recovery/compatibility/README.md:14`; `docs/HOSTED-READINESS-OWNER-APPROVAL.md:45`; consolidated review `:180`. |
| P2 — CR-08, Low | Older summaries retain superseded unknown-marker and cached-parser wording. Actual loader is explicitly pinned. | This plan uses the consolidated findings and actual pinned-loader implementation. Source-only clarification is sufficient; older documents remain historical. Only this plan may be written now; a broader documentation cleanup is unnecessary for resolving hosted blockers. | `supabase/recovery/compatibility/README.md:3`, `:70`; `scripts/recovery/parser.cjs:1`; consolidated review `:366`. |

### Evidence, approvals, acceptance and dependencies for every finding

“Hosted” includes already-saved evidence if its scope/freshness is accepted;
it does not automatically mean a new query. Future state-changing proof is
separate from read-only diagnostics and may use only a separately approved
existing environment. No environment creation is authorized here.

| ID | Source-only sufficient? | Hosted read-only evidence needed? | Provider confirmation? | Owner approval | Acceptance criteria / dependencies |
| --- | --- | --- | --- | --- | --- |
| CR-01 | No; existing implementation/runner analysis can advance locally. | Yes, actor/schema/extension context; read-only alone cannot prove DDL or restore. | Yes for actual authority; recovery clarification if the Owner lacks authoritative capability evidence. | O2, O5, O6, O7, then O8. | Supported exact actor/provider path; successful approved ownership/cleanup/failure rehearsal; honest runner/history/lost-ack behavior; verified recovery point and real restore meets approved RPO/RTO. Depends on CR-02/04/05/06/07. |
| CR-02 | No for both plan RPCs; yes to classify the baseline enrollment occurrence without inventing a repair. | Yes, M1 component comparison unless adequate private evidence already exists. | Not initially; only if provider ownership/DDL restrictions emerge. | O1, O3; O7/O8 for any correction. | Both RPC differences completely attributed; input/default/result/owner/ACL/dependency contracts accepted; index already matched; P01/P05 prerequisites and actual artifact identity established. PRESENT-EXACT cannot be assigned from names alone. |
| CR-03 | No. | Yes, M2 role/object/column/sequence attribution and gym_settings components. | Conditional: only if a required correction affects provider-owned/inherited grants. | O1, O3, then O7/O8. | Every violating caller/privilege source identified; approved correction removes effective direct access while preserving exact server RPC allowlists; metadata and separately approved runtime negative tests pass. Do not assert gym_settings is the cause without proof. |
| CR-04 | No; creator-impact and final policy/owner design review can advance locally. | Yes, reuse H02 then request only missing creator/owner/RLS details in M2. | Conditional for provider-controlled creator/default/ownership restrictions. | O2, O3, O4, O5 if needed; O7/O8 for implementation. | Four final roles have required flags/owners, exact accepted edges, no at-rest SET/INHERIT/CREATE/maintenance leak; final 33-table inventory, FORCE RLS and scoped command policies verified; all relevant app creators and current RPCs closed to unauthorized execution, including inheritance. Provider-default treatment explicitly reconciled, not silently waived. |
| CR-05 | No. | Yes, D1 baseline aggregates; conditional later checks only when real prerequisites exist. | Not routinely; conditional on an unavoidable provider constraint/unsupported restore capability. | O3 for D-DATA; O6/O7/O8 for any correction/recovery. | Every migration refusal has a verified outcome with complete visibility; stored chains/heads/UTC preserved, exact payment/approval/basis/unique/overlap rules hold, pre-P14 drawer condition resolved without deleting history. UNKNOWN blocks apply. |
| CR-06 | No; Owner-held records may close it without new SQL. | Conditional, only narrowly refreshing unrecoverable essential context. | No, unless client/session provenance requires provider assistance. | O1; O3 if new diagnostics are required. | Owner accepts target/source/client/actor/window/closure and private custody references; snapshot stage/freshness adequate for the intended action. No fabricated signatures, retroactive authorization or assumed same-session execution. |
| CR-07 | No; decision drafting is source-only, actual adoption is Owner-controlled. | Yes for future real capability acceptance; zero nonexistent-role edges are not proof. | Yes, actual supported role/grantor/self-grant/revoke/transfer path or equivalent authoritative proof. | O2, O5; O7/O8 remain separate. | Explicit accept/reject/hold with named Owner/DBA, scope/date/conditions; actual four-edge behavior and cleanup subsequently demonstrated. Rejection retains NO-GO until another approved architecture is proven. |
| CR-08 | Yes, for current interpretation; no other document changed here. | No. | No. | Review of this plan; no execution permission implied. | Use current evidence/loader and historical labels consistently. Does not close any technical production gate. |

## 4. A — source-only work, without expanding this task

Completed here: checked branch/baseline, reviewed the consolidated evidence and
actual migration/builder/ACL definitions, specified expected object contracts,
and assigned bounded follow-ups/acceptance. No new implementation defect was
established by this planning review. Existing A05/A06 fixes are preserved.

Further source-only preparation, only if authorized as a later task:

1. Derive trusted **component** reference hashes for the exact M1 definitions from
   existing source/snapshots, recording serialization and PostgreSQL version.
   Do not overwrite composite expected hashes or treat normalization as equality.
2. Review all application creators and any non-GYMFORCE dependencies of proposal
   02 before approving its global scope. Existing functions and future defaults
   are separate problems; ownership reassignment does not change creator defaults.
3. Specify honest compatibility artifact/runner bookkeeping before any executable
   recovery release. A forward file after a failing P05 cannot solve its authority
   prerequisite; replacing historical files or marking variants as originals is
   not a valid forward-only strategy.

No broad regression rerun is justified without a concrete implementation change
or evidence discrepancy that the affected test can resolve. Opaque hosted
fingerprint differences cannot be explained by repeating local business tests.

## 5. B — smallest useful hosted read-only follow-up

**M1 and M2 are specifications for a future separately reviewed diagnostic
package, not SQL files, current approval or permission to run arbitrary queries.**
Bundle their approval/review to resolve multiple blockers in one controlled
session, but execute distinct transaction-owning units separately. Reuse the
existing eight-unit packet; do not repeat it by default.

### M1 — two plan RPC component comparisons (CR-02; supports CR-01/04)

- Scope only the two P01 routine names, all observed overloads and their immediate
  dependency/caller metadata. Obtain exact identity and full input-name/type/mode/
  default and result-type contracts, language, definer/config/owner flags.
- Return separate exact definition/body/config/owner/ACL fingerprints and approved
  non-sensitive contract flags. Keep raw bodies/default expressions/ACLs private.
  Compare raw representation first; separately document any format-only analysis
  without replacing the original mismatch. A body hash match alone does not
  establish correct ACL, ownership or all overloads.
- Return only approved source identifiers, counts and comparison classifications
  outside Owner custody. An Owner-private source/body review may be needed if
  component hashes differ; do not ask the Developer to receive production bodies.
- Acceptance: each difference explained, true replacement compatibility known,
  expected business/authorization/audit behavior accepted, exact future artifact
  scope approved. If a mismatch remains unexplained, hold before P01/P05.

### M2 — privilege attribution and gym_settings components (CR-03/04)

- Start with the **same object/caller allowlist as Unit 22's direct-data screen**:
  api/private relations and public.gym_settings, approved relation kinds including
  views/materialized views/sequences, and anon/authenticated/service_role.
  Do not restrict the violation search to gym_settings based on a hypothesis.
- Privately identify each effective table, column or sequence permission and its
  explicit/PUBLIC/inherited source, schema reachability and relevant membership
  path. No business rows, passwords or whole provider role graph are needed.
- For public.gym_settings separately return owner/kind/ENABLE/FORCE flags and
  component fingerprints for ACL/policies/constraints as needed to explain its
  relation mismatch. Do not return policy expression text. Inventory actual final
  protected relations and unexpected RPC overloads/definer ownership when relevant.
- Reuse H02 creator/default evidence first. Only request missing creator/global/
  schema/inherited grant details or necessary freshness, not another broad dump.
  Explicitly distinguish app-owned creators from provider-controlled defaults.
- Acceptance: violation attribution complete; relation mismatch explained;
  stage-specific correction scope and any provider dependency known. These are
  diagnostic acceptance conditions, not authorization to execute the correction.

### D1 — baseline data acceptance (CR-05)

After O3 and exact prerequisite/full-visibility checks, consider existing H03
(unit 26), registration/plan/cash (27) and audit (28). Audit uses builtins and
must not call a mutating application helper. Require complete PASS/FAIL/UNKNOWN
outcomes, not raw financial/member/audit records. Existing plan-normalization
data still needs checking even though its index fingerprint matches.

Units 29/30 remain **SKIP / UNKNOWN on the saved stage** because prerequisite
columns do not exist. Do not make those columns merely to query them. Any
additional baseline uniqueness/finance/attendance check must be designed against
columns that actually exist, separately reviewed and approved. A check that is
appropriate only before P13/P14 cannot condemn legitimate later history.

All proposed units retain reviewed READ ONLY / REPEATABLE READ, local 30s/2s
limits, pg_catalog search path and ROLLBACK, with complete results and an approved
client/session cleanup path. No unit, client choice or privilege escalation is
approved by this plan. Stop on wrong target/actor/hash/stage, missing prerequisites,
timeout/error/cancellation, truncated output or uncertain closure. Retain originals;
no grants, role creation, SQL edits or automatic retries to complete diagnostics.

## 6. C — Owner/provider decision register

All entries are **UNDECIDED / NOT AUTHORIZED**. Owner name, reference, date/time,
conditions and actual evidence links remain Owner-controlled; none are invented.

| Decision | Exact decision needed | Evidence / effect |
| --- | --- | --- |
| O1 — provenance and freshness | Confirm intended project, private packet origin/source/client/actor/window/closure, custody and whether state has changed. | Close CR-06 from existing records first; no blanket rerun or retroactive approval. |
| O2 — ADMIN trust exception | ACCEPT FOR DESIGN REVIEW / REJECT / HOLD for exactly one provider-granted ADMIN edge per reserved role to postgres, SET/INHERIT false. | Four NOLOGIN/NOBYPASSRLS roles remain required. ADMIN permits later membership grants even when direct SET/INHERIT are off; it is a permanent provider/Owner administrator trust exception, not a temporary customer permission. No automatic migration approval. |
| O3 — diagnostic authorization | Exact M1/M2 drafts/hashes and later D1 subset, existing verified client/identity, Manila window, privacy/viewers/retention/disposal and cleanup/stop rules. | Approve preparation/review first, then exact execution separately as applicable. No new diagnostics currently exist or may run under generic scope. |
| O4 — default/RLS/correction scope | Accept the exact app-creator coverage and global postgres proposal impact; require final owner/FORCE/RPC/direct-data bounds. | No blanket provider-default revocation. A remaining provider-related strict-screen FAIL must have explicit documented interpretation and compensating evidence; never rename it PASS or modify its approved SQL to hide it. |
| O5 — supported provider path | Owner authorizes a narrowly framed support inquiry or supplies authoritative existing confirmation for actual role hooks, schema/digest rights, transactional cleanup and actor/runner behavior. | Existing draft at `docs/HOSTED-READINESS-OWNER-APPROVAL.md:45`; no message sent here. General documentation/synthetic provider success alone is insufficient. |
| O6 — real recovery capability | Accept actual plan-supported backup scope/custody, successful separately authorized restore proof, explicit RPO/RTO, keys and incident/recovery operator. | Database backup alone omits relevant Auth/settings, mobile/HMAC keys, Edge secrets/bundles and Pages state. No assumed PITR, paid plan, backup, restore or new environment authorized. |
| O7 — truthful forward artifacts/history | Accept reconciled objects, exact artifact/source hashes, actual operator/runner, honest history provenance, checkpoint/abort/lost-ack procedure and any separately reviewed corrections. | Preserve 37 historical files and all 20 recorded entries. No mark-applied, blind skip/replay, hidden replacement or source-hash refresh. |
| O8 — controlled changes/releases | Separate exact migration/ACL/configuration/Edge/Pages/window/traffic and operational approvals after all mandatory gates pass. | Not granted by diagnostics, O2 or this report. Keep public/PIN/claim release parameters and privacy policies separately gated. |

Original authority contract: zero membership edges. Revised contract: four exact
provider ADMIN edges, plus customer-granted temporary ADMIN=false SET/INHERIT
edges removed before commit. Reserved roles must remain NOLOGIN/NOSUPERUSER/
NOCREATEROLE/NOCREATEDB/NOINHERIT/NOREPLICATION/NOBYPASSRLS; application privileges
remain narrow and FORCE RLS enabled. Temporary destination CREATE and restricted
Owner-session SELECT policies must also disappear. Source guard/cleanup:
`scripts/recovery/build-compatibility.mjs:18`, `:25`, `:48`, `:69`, `:82`.
Unit 22's original zero-edge screen cannot be treated as the revised acceptance
screen. Current roles being absent proves neither contract's future execution.

If O2 is rejected or O5 cannot establish support, stop the current architecture's
execution path and request a separately authorized design. Never give executors
LOGIN/BYPASSRLS/permanent CREATE, impersonate the provider, expose privileged DDL
RPCs, or disable assertions/RLS to force compatibility.

## 7. D — controlled execution, still blocked

No commands in this section are authorized. The dependency order below is the
shortest safe route; parallel independent decision/evidence work, not production
operations or statements sharing a transaction.

1. **O1 and O2 first**, while reviewing existing source/creator scope and O6
   evidence in parallel. This may close provenance gaps or reject the architecture
   without spending another hosted diagnostic cycle.
2. Under new exact O3 approval, execute M1/M2 through the verified existing client
   and return sanitized results. Decide any conditional source/correction work
   from those outcomes; do not alter historical files. Address provider questions
   under O5 in parallel. Neither metadata nor support answers alone prove DDL.
3. Collect authorized D1 baseline data evidence; resolve every actual anomaly
   under its own evidence-preserving Owner procedure. Complete O4, O5, O6 and O7.
   Rehearsal/restore may only use separately authorized existing targets; no
   environment creation or restore operation is part of this plan.
4. Require supported actual authority/ownership/default cleanup, real rollback/
   partial-failure and runner/history/lost-ack proof, all legacy preconditions,
   demonstrated restore within RPO/RTO, and accepted final security. Historical
   synthetic PG17 success supplies coverage, not hosted certification.
5. Only with O8 and a valid recovery point/traffic-exclusion window, consider
   **unrecorded P01–P04, then reviewed P05–P17 compatibility artifacts in order**,
   subject to the P01 partial-object reconciliation and exact stage prerequisites.
   Never replay the 20 recorded originals. Do not expose intermediate schemas to
   business traffic. Use the staged checkpoints in `docs/production-recovery-plan.md:394`.
6. Separate accepted DB changes from hosted settings/Edge/frontend release and
   operating-gate opening. Require actual hosted-equivalent Auth/Edge/PostgREST
   business/negative/race acceptance, then authorized Owner production reads and
   verified release logs/SHAs; no synthetic money enters production. Remaining
   public lost-response recovery, PIN parameters, offline/privacy/retention and
   real-device acceptance still block operational GO where applicable.

### Mandatory failure and recovery acceptance

- Before a file commits: close/rollback the actual known session and verify
  cleanup/lock release; do not infer it from a new SQL Editor click or process
  termination during a network outage. No rollback is executed in this task.
- After a file commits: failure of the next file does not undo it. Keep traffic
  closed, preserve private evidence and inspect the actual committed state.
- Lost acknowledgement/schema-history disagreement: freeze retries and privately
  establish commit outcome, definitions and history; require a new approved
  disposition. No automatic rerun, history repair or version marking.
- Prefer an approved compatible forward recovery, not casual reverse DDL. Restore
  is a separately approved last-resort operation with explicit data-loss scope,
  recovery cutoff, key custody and independently checked financial/audit history.
- P05 requests ACCESS EXCLUSIVE on 22 baseline tables. Compatibility variants
  set 5s lock/120s statement bounds; diagnostic 30s/2s limits are different.
  Real data volume, total maintenance duration, traffic controls and operator
  escalation budgets must be accepted; do not silently extend timeouts.

References: `docs/production-recovery-plan.md:421`, `:518`, `:530`, `:539`,
`:548`; `scripts/test-database.ps1:150`, `:171`, `:233` for historical failure
assertion implementation. Plans are not proof of an actual backup or restore.

## 8. Recommended next action and decision

**Approve preparation of one narrowly scoped M1/M2 follow-up package**, alongside
the explicit O2 accept/reject/hold decision. M1/M2 should resolve the plan-RPC
fingerprint components, gym_settings metadata and direct-privilege attribution
together. Preparation is distinct from approving its exact SQL/client/window for
execution. Reuse the existing packet instead of another general assessment or
repeat of all eight units. No new SQL artifact was created here.

Current count: **five critical/high finding categories** (one critical + four
high), plus two medium and one low. CR-08 is source-only sufficient; source-only
preparation advances CR-02/04/07 but cannot close their hosted gates. CR-01–05
and CR-07 need hosted or hosted-equivalent technical evidence; CR-06 should first
use existing Owner records. Provider confirmation is core to CR-01/07 and
conditional for provider-controlled aspects of CR-03/04/05.

**Production NO-GO; Phase 5 incomplete.** No unresolved result is promoted to PASS,
no new source defect is invented, and no production execution or Phase 6 release
is authorized by this plan.
