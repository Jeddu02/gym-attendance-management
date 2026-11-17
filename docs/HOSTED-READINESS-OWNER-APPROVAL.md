# GYMFORCE hosted readiness: Owner approval package

Prepared 2026-11-17, Asia/Manila. Intended project `alxhytivwybjbkjjdsyn`.
Branch `review/production-recovery`; unchanged HEAD
`db700c1f42cdf561e3f55d61897ba8eb4948c94e` plus uncommitted local recovery work.

**Production NO-GO. Prepared for review, not authorized to execute.** This package
does not inherit permission to run new diagnostics from earlier approval of
01/02. Production preflight 03-07 remain held. No connection to production,
hosted SQL, project provisioning, support message, deployment or commit occurred.

Read these three documents together:

- [Diagnostic plan](HOSTED-READINESS-DIAGNOSTIC-PLAN.md): exact existing file
  selection, additional SQL, prerequisites, output/privacy rules and byte hashes.
- [Decision matrix](HOSTED-READINESS-DECISION-MATRIX.md): proceed/stop/provider
  escalation rules and current evidence status.
- This file: separate approval scopes and required recovery/operational evidence.

## Evidence and authority boundaries

The current sections of [final local review](PG17-COMPATIBILITY-FINAL-REVIEW.md)
and [final readiness](PRODUCTION-RECOVERY-FINAL-READINESS.md) supersede historical
unavailable-PG17 statements in older A02 reports. They record native 17.12/170012,
three profiles, eleven real legacy refusals, nine concurrency cases, five init
fault tests, pinned-parser clean-room verification and publisher archive checksum.
Application and recovery regression suites passed. These are synthetic local
results, not actual Supabase authority or production data acceptance.

Supplied historical hosted evidence is limited to 20 recorded migrations through
20261030180000, 17 unrecorded versions, 91 marker occurrences (88 absent, three
present without history), ENABLE RLS on 22 inventoried tables and 14 previously
missing HTTP endpoints. Exact present-marker identities, current endpoint state,
full catalog/ACLs/data, backups and hosted execution remain NOT VERIFIED.

The Owner operates production and keeps credentials, raw security metadata,
backups and records private. The Developer reviews source and sanitized results;
their ordinary member identity grants no technical or management access.
Diagnostic authorization is not authorization for live-record investigation or
for creating a new privileged login. Do not share keys, PINs, tokens, passwords,
connection strings, private function bodies or member/payment/audit records.

## A02: exact provider dependency and support questions

The revised local design keeps four NOLOGIN/NOBYPASSRLS execution/data roles:
gym_data_owner, gym_owner_executor, gym_public_executor and gym_checkin_executor.
It accepts one permanent edge per role: grantor supabase_admin, member postgres,
ADMIN=true, SET=false, INHERIT=false. Temporary customer-granted edges have
grantor postgres, ADMIN=false, SET=true, INHERIT=true, then are revoked before
commit along with destination schema CREATE and scoped SELECT maintenance
policies. FORCE RLS and ordinary ownership checks remain active.

Supabase documents provider-granted ADMIN memberships for customer-created roles
on PG16+, their SET/INHERIT settings and the customer's inability to remove them.
It also describes passwordless CLI temporary login roles. These facts support the
design premise; they do not establish this project's actual actor, grant options
or transaction behavior. [Official grantor guidance](https://supabase.com/kb/troubleshooting/cant-revoke-a-role-membership-granted-by-supabase_admin-d08922).

Exact implementation references: `scripts/recovery/build-compatibility.mjs`
(allowedEdge/graphGuard/prepare/cleanup), the two compatibility manifests and
`supabase/recovery/diagnostics/compatibility-authority.sql`. Original P05/P11
zero-edge migrations still conflict with ordinary customer role creation. No
generic privileged RPC, provider impersonation or new BYPASS privilege is a solution.

Owner support inquiry draft below is **not sent**. Request capability clarification,
not permission changes or execution. Include only approved source excerpts and
sanitized facts; no raw production graph, records or credentials.

1. For this project's actual PG17 build, does customer postgres role creation
   produce exactly the documented supabase_admin ADMIN edge with SET/INHERIT off?
   Are pre-existing reserved roles subject to different grantor/options behavior?
2. Is customer self-grant `WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY
   postgres`, followed by revoking only that customer-granted edge in the same
   transaction, supported? What provider hooks/restrictions affect rollback?
3. Can that actor perform ordinary ALTER OWNER and ALTER DEFAULT PRIVILEGES FOR
   the restricted roles using transaction-scoped membership and destination
   CREATE, leaving no effective SET/INHERIT/CREATE afterward? Do schema/extension
   protections require a different supported design?
4. Can the existing operator grant needed extensions-schema USAGE, and do executor
   roles already have effective EXECUTE on extensions.digest(bytea,text)? The
   design refuses unavailable access and does not grant on a provider-owned function.
5. Which approved connection preserves both session_user and current_user as
   postgres? Does the intended CLI path create a temporary login or change session
   identity? Do not initiate passwordless CLI authorization merely to discover this.
6. Are the exact transactional Owner-session SELECT policies for P06/P07/P13/P14
   and ownership operations compatible with hosted FORCE RLS and supautils?
   Clarify existing operator BYPASS/inherited privileges; no request to add them.
7. What supported backup/restore path preserves or reconstructs application roles,
   grantors, ACL/defaults, Auth identity links and migration metadata under the
   actual plan? What limits/costs apply? No resource or paid feature is authorized.
8. What supported execution/bookkeeping path records the actual compatibility
   artifact provenance without falsely adopting altered SQL as original migration
   bytes? No history repair or mark-applied operation is requested.

Public docs already establish the general ADMIN restriction. Questions 1-6 require
project/runner-specific confirmation or an explicitly approved hosted-equivalent
rehearsal; SQL metadata alone cannot prove DDL success/rollback. Questions 7-8
require operational answers and Owner decisions. If no supported path meets the
accepted security boundary, stop and commission another design; do not weaken it.

## Approval scopes (none granted by this document)

| Approval ID | Scope | Exclusions |
| --- | --- | --- |
| D-META | Listed metadata/read-only SQL only, exact file/block hashes and intended existing Owner connection | No data scans, role creation, configuration writes, permission changes, application RPC calls or migrations. |
| D-DATA | Named conditional read-only aggregate files/blocks, after verified prerequisites and full visibility | No raw row exports, corrections, restored visibility through grants/policies, mutating verification, or backfills. |
| S-ASK | Owner sends the reviewed support inquiry | No request for support to change roles/run migrations; no automatic transmission by Developer. |
| I-REHEARSE | Specific existing isolated target, operator, source hashes and synthetic scenarios | No production SQL or paid/cloud provisioning. Real-backup restore testing needs its own restricted approval. |
| B-CAPTURE / B-RESTORE | Owner-controlled backup capture and separately approved isolated restore drill | Neither is part of diagnostics; no live dump on Developer machines or automatic production restore/cutover. |
| M-APPLY | Future exact migration/compatibility/default-ACL artifact plan, runner/history strategy, maintenance window | Not granted by any diagnostic PASS or support answer. No blanket db push, reset, history edit or forced rerun. |
| C-CONFIG / E-EDGE / F-PAGES | Future named hosted settings, Edge bundles or frontend release | Separate from M-APPLY and each other; no public/PIN/claim feature activation by implication. |
| O-OPEN | Operational opening after all mandatory tests/Owner reads | Local regression success alone is insufficient. |

### Diagnostic authorization form

Complete separately for D-META and D-DATA; unchecked means NOT AUTHORIZED.

- [ ] Owner confirms target project, existing access path and operator identity.
- [ ] Exact file paths and SHA-256 / embedded block IDs and SHA-256 are recorded.
- [ ] Approved subset and execution order are named; no folder-wide approval.
- [ ] Version/table/column/role/type prerequisites and actual source stage reviewed.
- [ ] READ ONLY transaction, local 30s statement/2s lock limits and same-session
  rollback are retained; no statement selection without the wrapper.
- [ ] Diagnostic window, one-file-at-a-time operation, completion time and stop
  conditions are agreed. Any rerun/change of bytes/actor needs recorded review.
- [ ] Full outputs stay Owner-private; only sanitized status/categories leave custody.
- [ ] D-DATA additionally has full SELECT and no active RLS filtering on every
  referenced relation; insufficient visibility means UNKNOWN, never new grants.
- [ ] Errors/truncation/missing prerequisites stop dependent checks; SQL Editor
  result/session limitations and an already approved alternative client are resolved.

```text
Approval ID: D-META / D-DATA
Owner / date / time window:
Target and existing operator/client confirmed privately:
Authorized file paths or SQL block IDs, SHA-256 values, exact order:
Prerequisites / stage confirmed:
Private evidence custodian and sanitized reporting route:
Statement/lock limits; cancellation/same-session rollback procedure:
Explicit exclusions: migrations, grants/roles/RLS/config/data changes, deployments,
  backup/restore, temp-login creation, history repair and feature activation.
Owner decision: APPROVE NAMED DIAGNOSTICS / HOLD
```

## Required backup, restore and maintenance evidence (future gates)

Supabase's backup documentation distinguishes plan-dependent managed backups,
free-tier export recommendations, custom-role password handling and Storage
object coverage. Verify the actual project entitlement; do not assume free PITR
or automatically buy a plan. [Official backup guidance](https://supabase.com/docs/guides/platform/backups).

| Gate | Required private evidence / sanitized outcome |
| --- | --- |
| Backup capability | Owner identifies actual supported method, scope/exclusions, retention, recovery operator and cost/plan limits. Record cutoff UTC/Manila and agreed RPO/RTO. Missing free-compatible recovery capability is HOLD, not permission to purchase. |
| Backup artifact | Owner-authorized successful capture, completion/checksum/size, encryption and access custody, off-system copy, restore compatibility and captured migration/schema stage. Do not put dumps, role-password material or key bytes in Git/chat. |
| Coverage beyond database | Record protected custody/recovery references for mobile encryption/HMAC keys, Auth mappings/settings, applicable Storage objects, Edge bundles/secrets, api exposure/origin, Pages build/environment and source/artifact manifests. Database restore alone is insufficient. |
| Restore drill | Separately approved isolated Owner-controlled restore, no production cutover; timestamps/duration and RPO/RTO achieved; original audit/hash/head and finance/member/attendance integrity, roles/FORCE/ACL/defaults/extension/Auth links and app compatibility verified privately. Synthetic replay is not a real-backup restore drill. Real records must not reach Developer machines. |
| Migration execution identity | Supported actor/runner path, exact transactional behavior and bookkeeping/lost-ack handling demonstrated in the approved equivalent environment, including no persistent temporary authority. |
| Maintenance window | Named operator/approver, target/source hashes, verified recent recovery point, bounded duration, lock/wait budget and staged checkpoints. P05 exclusively locks 22 baseline tables; other stages lock audit/finance/membership/attendance/cash. Production volumes/timing remain unknown. |
| Traffic control | Separately approved controls stop Owner/public business mutations at the backend; UI hiding is inadequate. Existing auth/RLS/integrity guards stay enabled. Diagnostics approval does not authorize changing feature gates or traffic settings. |
| Abort/recovery | Stop on refusal/unknown outcome, rollback the actual session, confirm lock release privately and reconcile prior commits. No blind retry, ledger editing, delete-to-pass, rehash or unreviewed reverse DDL. Owner alone approves any restore and its data-loss/cutover scope. |
| Reopening | Real isolated Auth/Edge/PostgREST success/negative/race acceptance, current bundles/Pages SHA, actual Owner authorized production reads and separately approved operational parameters. No synthetic live financial transactions. |

Approval of evidence collection is distinct from approval to take a backup,
restore one, change traffic controls or apply SQL. If an isolated target/resource
is unavailable, record UNKNOWN and request precise separate authorization.

**Stop for Owner review. Diagnostics are proposed only; production remains NO-GO.**
