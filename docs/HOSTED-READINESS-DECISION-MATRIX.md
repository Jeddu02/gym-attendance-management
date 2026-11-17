# GYMFORCE hosted verification decision matrix

Prepared 2026-11-17. Target `alxhytivwybjbkjjdsyn`. **Production NO-GO.**
Use with the [approval package](HOSTED-READINESS-OWNER-APPROVAL.md) and
[diagnostic plan](HOSTED-READINESS-DIAGNOSTIC-PLAN.md). No hosted verification
occurred in preparing this matrix; no approval box is preselected.

## Decision meanings

PROCEED means only the next explicitly authorized diagnostic or isolated step.
STOP means do not run dependent work; preserve private evidence, close the actual
transaction and resolve the cause. PROVIDER means Owner may seek reviewed support
clarification after authorizing contact; it is not permission for a provider fix.
PASS is a narrowly evidenced outcome; FAIL is an observed mismatch; UNKNOWN
covers absent/truncated/inaccessible/stale evidence. A diagnostic PASS never
authorizes mutation or turns the production decision into GO.

| Condition / observation | Decision | Next action / required evidence |
| --- | --- | --- |
| Target, exact SQL bytes, existing session identity or Owner scope unconfirmed | STOP | Confirm privately; no credential sharing or connection created by Developer. |
| PG major differs from the reviewed PG17 path | STOP / PROVIDER | Review actual build/support and isolate compatibility; do not force a guard or upgrade production here. |
| Session uses cli_login_postgres, SET ROLE facade or another actor | STOP for authority certification | Metadata may be usable only in its recorded context. Ask supported existing access path; never create a temp login merely for discovery. |
| Approved metadata query completes with full result and transaction closure | PROCEED | Classify results at the actual stage; next named metadata check only. |
| Error, timeout, cancellation, result truncation, hidden grid or unknown rollback | STOP | Mark UNKNOWN; Owner verifies closure/locks in the actual session. No timeout increases, visibility grants or repeated scans by default. |
| Roles absent on the 20-file baseline | PROCEED with metadata only | Expected possible pre-hardening state, not an automatic authority FAIL/PASS. Future role-creation behavior remains UNKNOWN. |
| Four existing exact provider ADMIN edges, restricted flags, SET/INHERIT false | PROCEED to reviewed authority assessment | Catalog matches the revised at-rest design. Owner trust approval and hosted operation/cleanup rehearsal still required. |
| Original zero-membership contract is required unchanged | STOP / PROVIDER | Documented customer-created ADMIN edges conflict. Qualify a supported unchanged-contract path or redesign separately. |
| Wrong grantor/member/options, extra reserved edge, LOGIN/super/BYPASS role or effective CREATE/SET leak | STOP / PROVIDER as needed | Owner-private exact graph/root cause review. No revoke/grant/role repair under diagnostic approval. |
| Required schema grant option/digest EXECUTE/provider protection uncertain | STOP / PROVIDER | Confirm supported capability on actual actor/environment; missing rows/nulls are UNKNOWN, not false permissions. |
| Provider supplies a supported written answer | PROCEED to approved isolated rehearsal | Answer alone cannot prove project-specific transaction/cleanup success. No production mutation test. |
| Effective browser RPC/private data privilege or unreviewed default/grantee appears | STOP for release | Inventory actual creator/global/schema/inherited source privately. Existing final-stage screen FAIL may be expected before hardening; do not revoke provider grants blindly. |
| ENABLE RLS reported on 22 baseline tables | PROCEED with inventory | Historical narrow PASS only. FORCE/owners/policies/33-table final inventory and hosted denial tests remain UNKNOWN. |
| Unexpected SECURITY DEFINER owner/config/overload or exposed private/public data | STOP | Exact-stage comparison and authorization review; no public RPC grants/config saves to test it. |
| Three historical present marker occurrences still unidentified | STOP for reconciliation/apply | Capture all current tuple identities and overloads privately. Never infer which three from aggregate counts. |
| Present marker has exact reviewed stage definition | PROCEED with reconciliation analysis | Classify PRESENT-EXACT, not migration applied. Resolve omitted effects/history and compatibility inputs before any execution plan. |
| Marker absent / present-old / incompatible / same name different type | STOP for automatic application | Review full affected object set, dependencies and actual definitions. No DROP/IF NOT EXISTS/mark-applied shortcut. |
| Fresh history is not the supplied 20-prefix, has gaps/unknowns or schema/history disagree | STOP | New evidence incident; preserve timestamps/context. No history repair/replay authorized. |
| All hashes match trusted same-stage metadata | PROCEED with remaining gates | Finite metadata match, not data/authority/history certification. Synthetic provider ownership differences cannot be normalized away. |
| Data check prerequisite column absent | STOP that check | Mark UNKNOWN/not runnable; use baseline alternative if separately approved. Do not add a column just to diagnose. |
| Incomplete SELECT / active RLS filtering | STOP aggregate certification | UNKNOWN even if zero rows/booleans look good. Do not add maintenance policy, grant or BYPASS for diagnostics. |
| Audit UTC/predecessor/head failure or legacy finance/membership conflict | STOP for migration | Owner evidence procedure/separately reviewed forward design; no rehash, guessed dates/payment facts or deletion. |
| Pre-P13 dated payment_review term / any pre-P14 legacy drawer row | STOP affected apply | Exact source refusal; later legitimate payment-review history is not automatically an error. Closed drawers still block P14. |
| Legacy attendance basis/method is NULL | STOP automatic backfill | Preserve history and determine consequences with Owner; no guessed basis/method or revived request. |
| All authorized diagnostic statuses PASS | PROCEED to review, not apply | Require supported authority rehearsal, truthful artifact/runner history design, backups/restore, traffic plan and separate change approvals. |
| Backup/restore/RPO/RTO or exact window/abort evidence missing | STOP release | Owner-controlled evidence required. No assumption of free managed backup/PITR or safe down-migration. |
| Future stage commits but next fails / acknowledgement lost | STOP; keep traffic closed | Owner verifies actual state privately, reconciles artifact/history and approves forward recovery. Never rerun blindly. |
| All mandatory production gates evidenced and separately approved | Eligible for a new release decision | This package does not grant it; document exact scope/operator/artifacts and obtain explicit M/C/E/F/O approvals. |

## Current blocker ledger

| Gate | Current status | Evidence boundary |
| --- | --- | --- |
| Local PG17 hardening and regressions | PASS locally | Latest final-review section; eleven refusals, nine races, five init faults, parser/ZIP checks. |
| A02 unchanged customer zero-edge architecture | BLOCKED | Source conflict retained; original migrations untouched. |
| A02 redesigned hosted authority / ADMIN trust | UNKNOWN / REQUIRES OWNER APPROVAL | Native customer fixture succeeds; actual Supabase operator/roles/schema/extension path not tested. |
| A03 actual effective/default/definer/RLS acceptance | UNKNOWN | No full new private hosted inventory; local ten-screen PASS is not hosted evidence. |
| A04 real legacy finance/member/attendance/audit compatibility | UNKNOWN | Existing diagnostics and new baseline supplement prepared; no actual scans. |
| A07 exact three markers / all other effects / history and definitions | UNKNOWN | Historical 88/3 aggregate only; no identity guesses. |
| Existing Edge endpoints | FAIL in earlier observations; current UNKNOWN | Fourteen earlier missing endpoints; no new network probes or release. |
| Backup and real isolated restore | UNKNOWN | Synthetic clusters do not prove production recoverability. |
| Truthful compatibility artifact runner/history strategy | HELD | No adoption, history writes or supported production execution path authorized. |
| Production diagnostics / changes / deployment | NOT AUTHORIZED by this package | Existing per-script approvals are not blanket authority; 03-07 remain held. |

## Evidence packet for a later decision

For each check record privately: UTC time, target/session confirmation, file/block
SHA-256, actual stage and prerequisite verdict, completion/transaction closure,
untruncated result status, evidence custodian and any dependency on another check.
Share only sanitized check labels, classifications/counts and SQLSTATE categories.
Keep raw security graphs, record values, hashes of secrets, full exceptions and
backup/key material out of this repository and chat.

Different diagnostic transactions have different snapshots; record their times
and rerun only under fresh approval if state changed. Read-only verification
cannot make an unavailable DDL privilege or a legacy data fact true.

**Final decision today: NO-GO for production; package ready for Owner review.**
