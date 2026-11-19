# Phase 5 consolidated compatibility and recovery review

Reviewed 2026-11-17, Asia/Manila. Existing repository:
`Jeddu02/gym-attendance-management`, branch **master**, HEAD
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda` (requested `ad41b79`).

**Phase 5 remains incomplete. Production and recovery execution: NO-GO.**
The saved metadata materially advances reconciliation, but none of the six gates
is fully accepted for production. No production connection, SQL, migration,
privilege change, rollback/restore operation, application edit, history write,
commit, push, deployment, new folder or database environment was performed.
Only this consolidated report is created. Existing untracked work is preserved.

## 1. Executive conclusions

- All eight saved units are present and locally parseable. They contain BEGIN,
  three SET acknowledgements and a final ROLLBACK tag. This is saved-output
  evidence, not an independent live-session or signed execution attestation.
- History matches the first **20** original local versions; **17** remain
  unrecorded. Unit 19 confirms **91** occurrences: **88 absent**, **three present
  without history**, now identified across **two** pending versions.
- Both P01 plan RPCs have matching identities but **different catalog
  fingerprints** from the existing P01-stage reference. Their normalized-name
  index matches. They cannot be classified PRESENT-EXACT or safely replayed by
  assuming all P01 effects are missing.
- The P09 enrollment name occurrence matches the **older recorded baseline**
  routine fingerprint exactly; it does not match the later P09 reference.
  Name reuse explains that occurrence without establishing P09 application.
- All **12 recorded-baseline routine fingerprints** match the existing baseline
  reference. The saved inventory contains 14 routines including the two extra
  plan RPCs. This narrow match does not verify all recorded migration effects.
- The four restricted roles are **absent**. Zero edge/temporary-capability counts
  are therefore not proof of future role creation, provider grantor behavior or
  cleanup. Actual hosted A02 execution authority remains unproven.
- Unit 22 has **7 PASS / 3 FAIL**. The missing-role failure is stage-expected;
  direct-data privileges and global function defaults remain real final-boundary
  gaps. No failure authorizes an automatic grant/revoke or historical replay.
- No D-DATA, actual backup/restore drill, RPO/RTO acceptance, maintenance evidence
  or signed trust-exception decision was present in the supplied private packet.
  Their absence here does not prove backups or decisions do not exist elsewhere.

This report supersedes the earlier “three identities unknown / metadata not yet
reviewed” statements **only for these saved snapshots**. Older execution reports
remain the source for historical local tests; they are not newly rerun results.

## 2. Evidence inventory, provenance and boundaries

The Owner supplied the existing private evidence directory outside the Git
workspace. It was inspected in place, read-only. Its absolute path, raw filenames,
role graphs, fingerprints, definitions and records are deliberately omitted.
No evidence file was copied into the repository or another directory.

| Private reference | Saved input | Structural review / use |
| --- | --- | --- |
| PE-U01 | Unit 1 text result and SQL copy | One context JSON; PG17, READ ONLY, matching postgres session/effective role; nonsuperuser/CREATEROLE/BYPASSRLS flags. Saved SQL bytes match H01's reviewed hash. |
| PE-U02 | Unit 2 text result | One version JSON; 20 unique known versions, exact supplied prefix, 17 unrecorded. |
| PE-U03 | Unit 3 text result | One valid format-1 PG17 catalog JSON; 477 unique object keys, well-formed SHA-256 fields; 22 readable/unfiltered table entries for the observed actor. |
| PE-U19 | Unit 19 text result | All 91 expected rows and seven expected columns; exact three source-allowlisted present occurrences identified. |
| PE-U20 | Unit 20 text result | One authority JSON; actual reserved-role count zero, zero edge/temporary paths, digest present; executor EXECUTE null because executor absent. Four schema-USAGE grant-authority entries affirmative. |
| PE-U22 | Unit 22 text result | All ten named status rows; seven pass, three fail. No per-caller/per-object violation details in this result. |
| PE-U23 | Unit 23 text result and SQL copy | Complete parseable security JSON, eight expected role-presence entries with four missing roles, 14 routines; saved SQL bytes match H02's reviewed hash. |
| PE-U25 | Unit 25 text result | One three-entry inventory: superseded limiter table absent; rolling event table and limiter RPC present, definitions not certified by this query. |

Total supplied packet: **eight text outputs plus two SQL copies**. Six outputs
contain a single JSON cell; unit 19 has 91 rows and unit 22 ten. All eight saved
outputs have final ROLLBACK text and expected result footers. No private D-DATA
result or financial/member/audit row was read.

Provenance limits:

1. These are Owner-provided hosted snapshots, not independently replayed queries.
   The context result contains an observation timestamp; a complete per-unit
   server timestamp/PID/exit-code/signed execution manifest was not supplied.
2. Saved tags support reported successful completion, but cannot independently
   prove target project, TLS validation, source-to-output binding for every unit,
   actual present-day session closure or that all units share one snapshot.
3. The repository authorization form remains DRAFT. This task authorizes local
   review of existing evidence; it neither reconstructs past execution approval
   nor authorizes new hosted work. Do not infer that the prior executions were
   unauthorized merely because an approval record is absent from this packet.
4. Unit 1 validates its own saved actor context, not every later arbitrary client
   connection. The project reference still requires Owner-controlled provenance.
5. Catalog fingerprints combine definition/owner/ACL or relation metadata. A
   mismatch identifies composite metadata drift; it does not identify its cause.
   No production body was returned/read to explain a mismatch.

### Exact local reference inventory

Source inspected: `supabase/recovery/compatibility/README.md:15`,
`scripts/recovery/build-compatibility.mjs:18`, `scripts/test-database.ps1:150`,
`tests/recovery-compatibility.test.mjs:1`, both compatibility `manifest.json`
files, ACL proposals, diagnostic SQL/check definitions and the requested Phase 5
reports/manual guide. The complete recovery plan's dependency/security/recovery
sections were reviewed; existing requirements remain unchanged.

Existing synthetic reference root:
`.cache/security-test-06e5d8ba808247b7b4178a974a9a8f56`.
Only existing catalog JSON snapshots for stages `20261030180000`,
`20261103080000` and `20261110130000` were compared. All report PG17 and
customer-compatibility profile, and all three stored compatibility-manifest
identities match the current synthetic manifest. These are synthetic references,
not trusted replacements for unknown hosted provider metadata.

Fresh offline integrity checks: **75/75 unchanged source fingerprints** (37
historical migrations, 21 Edge entrypoints, 17 shared runtime modules) and
**40/40 existing compatibility SQL artifact hashes** across review/synthetic
manifests match. No artifact was regenerated, SQL executed, hash
catalog changed or broad regression suite rerun. The raw private fingerprints
and graph are not included here.

Historical local execution evidence remains
`docs/PHASE-5-4-INTEGRATION-TEST-REPORT.md:3`: three actual PG17.12 profiles,
nine concurrency scenarios per full profile, eleven real legacy refusals per
full profile, two ownership rollback probes, ten final privilege screens and
five initialization faults; 38 application, 27 recovery and 105 Deno tests,
21 Edge checks and browser regressions passed then. This review executes none
of those database/rollback tests. Their asserted scope/limits remain in
`docs/PG17-COMPATIBILITY-FINAL-REVIEW.md:12`.

## 3. Six-gate decision matrix

PASS is narrow evidenced conformance; FAIL is an observed unmet invariant;
UNKNOWN lacks evidence; BLOCKED prevents advancement pending specified evidence
or approval. Local subchecks do not change a gate's production verdict.

| Gate | Local/saved evidence established | Production gate | Remaining requirement |
| --- | --- | --- | --- |
| 1. Provider ADMIN-edge compatibility | PASS static exact-edge model and historical synthetic operation; saved actual actor has required context flags, but zero reserved roles. | **BLOCKED** | Supported actual role-creation/grantor/options behavior, self-grant/revoke and hosted-equivalent authority proof; Owner adopts or rejects exception. |
| 2. Ownership and privilege cleanup | PASS source safeguards and historical rollback/cleanup tests; saved current maintenance/SET/CREATE paths zero with no restricted roles. | **UNKNOWN** | Demonstrate real provider transactional ownership/default/policy mechanics, effective cleanup and failure paths with the accepted actor/runner. |
| 3. Creator/default ACL and RLS | Seven screen passes; three actual final-boundary failures; all 14 routine owners are postgres, 12 are definers. | **FAIL — final acceptance** | Stage-specific ACL/default and owner/FORCE-RLS reconciliation, approved corrections and runtime denial evidence. Baseline expectation is not a waiver. |
| 4. Legacy/data/history reconciliation | PASS 20/17 history comparison and exact marker identification; two P01 routine fingerprints differ, one older enrollment matches. | **BLOCKED** | Resolve composite drift and partial objects, establish truthful artifact/history strategy; legacy-data safety remains **UNKNOWN** without D-DATA. |
| 5. Rollback/restore/recovery | PASS documented plan and historical synthetic rollback assertions. | **BLOCKED** | Actual backup coverage, isolated restore evidence, RPO/RTO, key custody, named responsibility, quiet-window/traffic and recovery acceptance. |
| 6. Owner trust-exception adoption | Exact decision scope prepared below; no recorded adoption in supplied evidence. | **BLOCKED** | Explicit Owner/DBA decision with prerequisites, not implied by this review. |

## 4. Gate 1 and Gate 6 — original versus revised authority contract

| Aspect | Original migrations | Explicit compatibility design |
| --- | --- | --- |
| Permanent reserved-role membership edges | Zero | Exactly one edge for each of four reserved roles: grantor supabase_admin, member postgres, ADMIN true, SET false, INHERIT false |
| Reserved roles | NOLOGIN, non-superuser, NOCREATEROLE, NOCREATEDB, NOINHERIT, NOREPLICATION, NOBYPASSRLS | Same required role attributes |
| At-rest schema CREATE / application data paths | Restricted | Same intended end-state restriction; no temporary capability retained |
| Temporary ownership authority | Ordinary customer authority conflicts with zero-edge/schema requirements | Explicit transaction-local customer-granted SET/INHERIT edges with ADMIN false, destination CREATE and scoped read policies, removed before commit |
| Provider digest access | Contains grant on provider-owned routine | Verifies existing executor EXECUTE; refuses if unavailable; no provider impersonation |
| Application functions/business logic | Original definitions | Same function ASTs checked; seven role-graph assertion predicates deliberately adapted, not secretly skipped |
| History | Original files/versions | Separate reviewed artifacts; no automatic mark-applied/runner-history claim |

Source: `supabase/migrations/20261110100000_executor_hardening.sql:19`,
`:27`, `:827`; `supabase/migrations/20261110150000_member_checkin.sql:16`,
`:31`, `:38`; `scripts/recovery/build-compatibility.mjs:18`, `:25`, `:48`,
`:108`, `:120`, `:125`; `supabase/recovery/compatibility/README.md:15`.

The saved zero-edge counts do **not** demonstrate this future four-edge contract:
there are zero reserved roles. Unit 20's missingProviderEdges=0 is vacuous in
that state. Owner-executor digest EXECUTE is null, not false and not a PASS.
Current schema-USAGE grant authority is useful metadata, not proof of every
future ALTER OWNER/default/role operation.

The synthetic provider is `gf_provider_admin`; the review provider is
`supabase_admin`. Their manifests are deliberately different. The synthetic
customer is NOBYPASSRLS; the saved actual postgres actor has pre-existing
BYPASSRLS. Review source allows that operator attribute but never grants it;
application executors remain NOBYPASSRLS. Do not normalize these differences
away or claim local success simulates all hosted hooks.

### Required provider/Owner answers

- Does the real existing actor's role creation produce exactly the expected
  provider-granted ADMIN edge/options, including rollback and existing-role cases?
- Can it create/remove only its own temporary SET/INHERIT grant, transfer ownership,
  set creator defaults and manage the required schemas/policies transactionally?
- Are existing extension schema/digest privileges sufficient for future executors?
- Does the approved runner preserve postgres session/effective identity and honest
  artifact/history bookkeeping under failure/lost acknowledgement?
- Are the actual provider implementation and restrictions supported, not merely
  compatible with a synthetic superuser bootstrap?

Existing inquiry text is `docs/HOSTED-READINESS-OWNER-APPROVAL.md:45`; it was not
sent. No provider capability is newly certified from the current zero-role result.

### Explicit Owner/DBA decision record — not completed

Decision choices: **ACCEPT FOR FUTURE DESIGN REVIEW / REJECT / HOLD**.
Owner/DBA name, decision, reference, date/time and conditions: **OWNER TO COMPLETE**.

Acceptance would acknowledge exactly four provider-controlled ADMIN exceptions,
their ongoing power to grant future membership despite SET/INHERIT being off,
and that literal zero-membership security is changed. This leaves a privileged
Owner database administrator/provider trust path; it does not grant any browser,
service transport or ordinary member/developer identity those capabilities.
Accept only if every other attribute/edge/path is rejected and temporary authority
is proven closed. The customer must not attempt to revoke the provider's edge.

This decision alone would **not** authorize role creation, migrations, history
changes, hosted tests, ACL/configuration writes or deployment. Those need separate
exact approvals after the evidence gates pass.

Alternatives: retain zero-edge requirements and remain blocked until a genuinely
supported mechanism is demonstrated; or commission a separately reviewed new
authority architecture using available provider capabilities. No superuser
assumption, unbounded definer DDL RPC, executor LOGIN/BYPASSRLS, permanent schema
CREATE, provider impersonation or disabled assertion is an acceptable shortcut.

## 5. Gate 2 — ownership transitions and cleanup

Builder safeguards inspected at `scripts/recovery/build-compatibility.mjs:25`,
`:48`, `:69`, `:93`, `:108`, `:120`, `:129`:

- At-rest graph guards reject unexpected grantors/members/options/attributes,
  effective schema CREATE and stale maintenance policies.
- Temporary customer edges are granted by postgres, ADMIN false, SET/INHERIT
  true. Only the owner role's required private/public transfer scope and API
  executors' destination CREATE are provided. Normal ownership checks still apply.
- Temporary SELECT policies are limited to the exact P06/P07/P13/P14 guard tables
  and require both session and current role postgres. They are not write policies.
  Restrictive-policy conflicts refuse execution. FORCE RLS is not disabled.
- Cleanup removes maintenance policies, customer-granted edges and destination
  CREATE; final guards check effective SET/inheritance/CREATE closure. Provider
  ADMIN edges remain by design. Each file owns its transaction and timeout bounds.
- Function definitions are compared by AST; replacement anchors and expected
  predicate counts refuse source drift. The builder cannot turn an arbitrary
  changed runtime body into an accepted equivalent solely by matching a name.

Historical probes in `scripts/test-database.ps1:150`, `:171`, `:233` compare
metadata/protected-row snapshots around real migration refusals and injected
partial-ownership failures. `tests/recovery-compatibility.test.mjs:1` checks
artifact/function identity and maintenance scope. These were inspected, not run.

Residual risks: actual provider hooks/authority are untested; network/process
loss may leave an uncertain remote session; one committed file is not rolled
back by failure in a later file. A session read-only diagnostic tag does not
prove future DDL cleanup. Current zero temporary paths are necessary but vacuous
for roles not yet installed. No present privilege leak from a failed production
compatibility run is demonstrated or ruled out by hypothetical local success.

## 6. Gate 3 — three Unit 22 failures and saved security metadata

| Exact failed check | Correct stage interpretation | Disposition |
| --- | --- | --- |
| missing_reserved_roles | All four absent, consistent with recorded pre-P05/P11 stage. Not evidence that deployed hardening roles were created insecurely. | Expected absence before approved recovery, **FAIL final role inventory**. Do not create them during diagnostics. |
| creator_global_public_function_default | H02 shows global PUBLIC EXECUTE entries for two creator classes: postgres and provider; no client schema-default additions were observed. Empty explicit defaults do not imply deny. | Real future-default review gap. Separate app-creator impact review; never revoke provider-wide defaults automatically. |
| direct_browser_or_service_data_access | At least one inventoried direct data/column/sequence privilege exists for a tested caller. The saved screen supplies only FAIL, not its exact caller/object/grant path. | Real mismatch with intended final server-only boundary. Do not assume public/member exploitation or that it is exclusively service_role. Obtain scoped attribution before correction. |

All seven other screen labels pass, including browser_effective_routine_access.
This does not prove absence of direct data privileges or runtime authorization
bypass. It is finite metadata under the observed roles/stage.

Unit 23: 14 routines, all postgres-owned, all empty search paths; ten API
SECURITY DEFINER and two private SECURITY DEFINER routines. Their owner's saved
role has BYPASSRLS. This is the pre-hardening owner model, not the intended final
bounded executor ownership. Empty search path alone is insufficient acceptance.
Current expected source baseline functions match the saved fingerprints, but
that does not establish every live JWT/actor check or semantic policy behavior.

Unit 3: 22 readable/unfiltered table entries; **21** match the baseline table
fingerprints. `public.gym_settings` differs. Its composite fingerprint does not
identify whether the differing component is owner/ACL/RLS/other relation metadata,
nor prove it caused the direct-data failure. Do not guess that attribution.
No explicit FORCE-RLS flag is returned by this catalog, and an unfiltered result
under a BYPASSRLS actor cannot certify enforcement for application roles. Final
33-table/FORCE/command-policy/least-privilege acceptance remains unverified.

Source: `supabase/recovery/catalog.sql:8`, `:19`;
`supabase/recovery/effective-privileges.sql:16`, `:21`, `:38`, `:45`;
`docs/HOSTED-READINESS-DIAGNOSTIC-PLAN.md:145`, `:154`, `:160`.
Source foundation revokes browser roles without establishing the final executor
model: `supabase/migrations/20261028061728_initial_schema.sql` final access section;
P05 begins table ownership/FORCE changes at `20261110100000_executor_hardening.sql:827`.

Scoped proposal 01 preserves runtime allowlists and refuses remaining inherited
access; it is not a blanket repair for every unknown creator. Proposal 02 affects
all future postgres-created functions in the database, including other schemas;
it needs separate impact/Owner approval. Neither is executed or automatically
applicable at this pre-hardening stage. References:
`supabase/recovery/proposals/01-explicit-routine-acls.sql:25`, `:28`, `:39`;
`supabase/recovery/proposals/02-postgres-future-routine-defaults.sql:15`.
The original strict zero-edge screen and revised ADMIN-exception screen must
remain distinct; neither may be relabelled to erase a discrepancy.

## 7. Gate 4 — exact marker/history reconciliation and legacy limits

All 20 saved history versions match the source prefix through `20261030180000`.
No duplicates/unknown versions were found. The 17 pending filenames and direct
dependencies remain in `docs/production-recovery-plan.md:100`, `:678`; no history
entry is repaired or adopted here.

| Saved present-without-history occurrence | Offline reference comparison | Classification / limitation |
| --- | --- | --- |
| 20261103080000: api.owner_list_membership_plans | One observed overload; identity matches P01. Composite routine fingerprint differs from P01 and later P09-stage reference. | **PRESENT-DIFFERENT / compatibility UNKNOWN**; definition/owner/ACL/format contribution not isolated. No automatic OR REPLACE. |
| 20261103080000: api.owner_save_membership_plan | One observed overload; identity matches P01. Composite routine fingerprint differs from P01 and later P09-stage reference. | **PRESENT-DIFFERENT / compatibility UNKNOWN**; same reconciliation hold. |
| 20261110130000: api.member_enroll_pin | One observed overload; identity and full composite fingerprint match recorded-baseline/P01 reference, not P09 reference. | **PRESENT-OLDER, exact baseline metadata match**; not evidence P09 was applied. Future replacement compatibility remains separately gated. |

The P01 normalized-name index is present with an exact P01-stage reference
fingerprint. Partial P01-like effects therefore extend beyond its two markers;
the marker check alone could not establish that. Neither index presence nor a
routine identity proves how/when/with what SQL those effects were installed.

Routine fingerprint comparison is exact; no normalization of differing definitions,
ACLs or ownership was used. The opaque mismatch might include body formatting or
grants, not necessarily a business-body change. It cannot be called harmless or
malicious from these inputs. Observed single overloads do not replace a complete
type/default/result/dependency review. Index/constraint/body replacement must not
be forced by DROP, IF NOT EXISTS patches or history marking.

Source: `supabase/migrations/20261103080000_owner_membership_plans.sql:29`,
`:37`, `:75`, `:195`; old issuer definition
`supabase/migrations/20261030150000_member_pin_enrollment.sql:3`; replacement
`supabase/migrations/20261110130000_pin_recovery.sql:101`, `:131`.
Unit 19's name-only semantics are at
`docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql:103`;
two migrations have no declaration markers, so 91 occurrences are not a full diff.

### Legacy data remains UNKNOWN

No D-DATA outcomes were supplied. Catalog readability under the saved actor is
not a scan of business invariants. P04 operation/target payment columns, P10
walk-in method and P11 attendance basis columns are absent in the saved catalog.
Thus conditional units 29/30 are not runnable against that snapshot; do not
install prerequisites to run them. Source requirements:
`supabase/recovery/checks.json:54`, `:132`, `:138`.

- Registration/date/payment basis, normalized duplicate plan data, allocations,
  attendance duplicates and exclusion constraints require actual approved checks.
- Audit links/heads/UTC serialization have not been verified on real stored rows.
- Any pre-P14 legacy cash session, including a closed session, blocks current
  source; actual presence is unknown. No evidence was invented to populate dates,
  reasons, receipt targets or opening attestations.
- Legacy NULL methods/bases, overlap/review terms and corrections require separate
  Owner resolution preserving originals; no financial/member/audit repair occurs.

Refusals remain in
`supabase/migrations/20261110110000_membership_lifecycle.sql:36`, `:52`,
`supabase/migrations/20261110160000_receipt_review_corrections.sql:239`,
`supabase/migrations/20261110170000_cash_operations.sql:12`.
Read-only aggregate sources are `supabase/recovery/diagnostics/audit.sql:6` and
`lifecycle-payments.sql:1`; their existence does not authorize execution.

## 8. Gate 5 — recovery plan versus operational evidence

| Requirement | Source plan inspected | Current evidence / acceptance |
| --- | --- | --- |
| File-level failure and cleanup | Recovery plan :530; builder :69; historical ownership/refusal probes | Local synthetic rollback proven historically; hosted runner/provider cleanup UNKNOWN. No rollback executed now. |
| Partial commits / lost acknowledgement | Recovery plan :539, :548 | Stop retries, privately reconcile commit/objects/history; later failure cannot undo earlier commits. Actual runner history behavior UNKNOWN. |
| Forward recovery | Recovery plan :548 | Prefer separately reviewed compatible forward fix; no general safe down-migration. No actual recovery operation run. |
| Backup scope / restore drill | Recovery plan :518; Owner approval package :150 | No actual method/artifact/successful isolated restore evidence supplied here. Do not infer plan entitlement, PITR, cost or recoverability. |
| RPO/RTO and key custody | Recovery plan :520 | No accepted values/custody evidence supplied. DB alone does not restore mobile/HMAC keys, Auth/settings, Edge secrets/bundles or Pages. |
| Traffic exclusion | Recovery plan :394; Owner approval package maintenance/traffic section | Named backend controls/operator/window not evidenced. Hiding UI or disabling authentication/RLS is not acceptable. No setting changed. |
| Locks/time budgets | Recovery plan :421; original P05 :35, P06 :9, P07 :9, P13 :9, P14 :6 | ACCESS EXCLUSIVE risks documented. Compatibility variants add 5s lock/120s statement bounds; real-data duration/overall window and operator abort budget UNKNOWN. |
| Incident ownership / reopening | Recovery plan :557, :565 | Owner/operator/escalation, evidence custody, tested restore/cutover and reopening acceptance still require explicit records. |

The 30s/2s diagnostic limits are not migration-window bounds. The 120s migration
statement limit is not a whole-window guarantee. Restoring a backup can lose
post-backup valid operations and needs separate Owner approval. No production
backup was read/copied and no local synthetic database was restored or created.

## 9. Severity-ranked findings

| ID | Severity | Finding | Required disposition |
| --- | --- | --- | --- |
| CR-01 | Critical release blocker | No accepted hosted authority/runner and no demonstrated operational restore; not a newly proven exploit. | Keep recovery/deployment NO-GO until authority and recovery gates pass independently. |
| CR-02 | High | Two P01 routine composite fingerprints differ despite matching identities; same-version index exists. | Owner-private component/definition reconciliation and exact future procedure; no blind replay/replacement/history marking. |
| CR-03 | High | Direct browser-or-service data screen FAIL plus public.gym_settings metadata difference; exact privilege source unknown. | Narrowly attribute caller/object/grant path without assuming causality or exporting raw ACLs. Any correction requires separate approval. |
| CR-04 | High | Global PUBLIC function defaults and unimplemented final owner/executor model; all current routine owners have BYPASSRLS. | Stage-correct default/ownership/FORCE/runtime acceptance; no provider-wide revoke or security relaxation. |
| CR-05 | High | D-DATA and actual audit/finance/member/cash compatibility absent; four conditional prerequisite columns absent. | Separately approved prerequisite-qualified checks; maintain UNKNOWN, no guessed repair. |
| CR-06 | Medium | Saved outputs lack full execution/source/target/exit-code/approval provenance; ROLLBACK tags are text evidence only. | Owner completes existing provenance references privately; do not rerun broadly merely to fill documentation. |
| CR-07 | Medium | Provider ADMIN exception awaits Owner adoption and actual provider operation evidence. | Complete explicit decision; supported authority rehearsal only after separate authorization, no resource creation now. |
| CR-08 | Low | Older reports still describe all marker identities as unknown and no saved metadata; compatibility README contains an older cached-parser description despite its current pinned-parser prerequisite. | Use this report's scoped supersession and actual loader/source; do not modify approved SQL or overlap reports during this assessment. |

No unauthorized public read/write, financial corruption or exploitable bypass is
claimed solely from a broad metadata FAIL. Conversely, lack of an observed exploit
does not make the intended final boundary acceptable.

## 10. Safe next sequence and authorization boundaries

1. Owner validates existing packet provenance/approval/target/times privately and
   accepts or rejects the Gate 6 design exception. This request authorized only
   this offline review; approval boxes remain unselected.
2. Resolve the now-identified P01/public.gym_settings differences and direct-data
   failure using **narrow newly reviewed metadata follow-up**, if existing private
   Owner evidence cannot explain them. Exact component fingerprints/attribution
   may be needed; no full production function bodies or raw graphs should be sent
   to the Developer. Prepare/approve any additional SQL separately. Repeating all
   eight units is not the default next action.
3. After separate D-DATA approval and established visibility/prerequisites, collect
   baseline audit/registration/plan/cash/finance outcomes. Units 29/30 stay skipped
   on the saved stage. No application verifier/mutation probe or create-to-test.
4. Obtain supported provider/runner answers and separately authorized rehearsal
   against an already approved equivalent environment, plus backup/restore/RPO/
   RTO/key/traffic evidence. No new environment, rehearsal or restore is authorized
   or performed by this assessment.
5. Only after all prerequisites pass, approve truthful reviewed-artifact/history
   mechanics and exact source bytes/operator/window. Preserve all original files
   and 20 recorded versions. Any eventual P01–P04 then P05–P17 compatibility order
   is conditional on reconciling P01 drift first, not permission to execute it.
   Keep traffic closed across partial commits and stop on any uncertain outcome.
6. Future database/configuration/Edge/Pages/opening approvals remain separate.
   Neither metadata PASS nor trust adoption authorizes production changes. Real
   Auth/Edge/PostgREST denial/business/race acceptance and actual Owner production
   reads must precede an eventual operational GO. Prior endpoint gaps remain
   historical; no current deployment state was checked here.

### Criteria to advance to hosted acceptance

- Existing evidence provenance is accepted; all observed differences have exact
  reviewed dispositions without falsifying history or normalizing away drift.
- Actual provider authority and cleanup path are supported, independently
  demonstrated under the accepted trust contract, and approved by Owner/DBA.
- Stage-specific data invariants, audit integrity and final effective ACL/default/
  owner/FORCE-RLS/RPC boundaries pass; unknown results are not waived.
- Exact artifact/runner/history design and failure handling are accepted; backups
  and a real Owner-controlled restore meet agreed RPO/RTO with protected keys.
- Named operators, maintenance/traffic/stop/escalation responsibilities and
  separate approvals exist; full hosted-equivalent application acceptance follows.

**Next authorized action:** Owner review of this single sanitized report and its
explicit trust/provenance decisions. Additional hosted diagnostics, rehearsals,
restore, migrations and releases need separately defined approval. **Phase 5
not complete; Phase 6 deployment entry and production remain NO-GO.**
