# A02 remediation design: migration authority without application privilege expansion

Prepared 2026-11-16, Asia/Manila. Branch: `review/production-recovery`.
Source baseline: `db700c1f42cdf561e3f55d61897ba8eb4948c94e`.

**Recommendation: qualify a provider-supported privileged execution path first
(Option A). Production remains NO-GO.** If that path is unavailable, separately
design and test Option B; do not apply the current migrations using ad hoc grants.
Neither option is currently demonstrated in hosted PostgreSQL 17. Customer
superuser access, provider assistance, free-tier availability and cost are not
assumed. If neither option can preserve the required final state, remain on HOLD.

This document is a design, not executable authorization or an apply script.
No SQL was executed, environment provisioned, migration changed, production
permission/configuration changed, or commit/push/merge/deployment performed.
The existing untracked `docs/A02-EXECUTOR-HARDENING-REVIEW.md` is preserved.
Only this new design document is written in this task.

## 1. Root cause and exact authority boundaries

Read alongside `docs/A02-EXECUTOR-HARDENING-REVIEW.md` and
`docs/production-recovery-plan.md` sections 3, 6, 11 and 12. P05 means
`supabase/migrations/20261110100000_executor_hardening.sql`; P11 means
`supabase/migrations/20261110150000_member_checkin.sql`. Line numbers below
refer to the exact baseline source. The prior A02 review's section 8 provides
the complete per-statement ownership/grant/policy operation indexes.

| Exact SQL site | Required authority and conflict |
| --- | --- |
| P05:19 dynamic CREATE ROLE; P11:16 CREATE ROLE | Ordinary CREATEROLE creation produces an automatic ADMIN membership. P05:27, :132 and P11:31 reject every edge involving a reserved role. Creating roles normally cannot satisfy that contract. |
| P05:35; P11:9 LOCK TABLE | Requires appropriate relation privileges; neither CREATEROLE nor database ownership guarantees them. Fail before DDL if the actor lacks baseline authority. |
| P05:651-655 input schema check; :827 first ALTER TABLE OWNER TO | A standard non-superuser transfer needs existing-owner authority, SET capability to the target and target schema CREATE. The source forbids the latter two prerequisites. |
| P05 table transfers :827, :831, :835, :839, :843, :847, :851, :855, :859, :863, :867, :871, :875, :879, :883, :887, :891, :895, :899, :903, :907, :911 | All 22 transfers require the same authority. Attached identity sequences, indexes and row types must retain correct ownership/bindings; no blanket REASSIGN OWNED. |
| P05 function transfers :1006-1126 | 25 explicit transfers: 16 API SECURITY DEFINER entrypoints to Owner/public executors; nine private helpers to data owner with SECURITY INVOKER. Exact signatures appear in the prior review's ownership allowlist. Each transfer needs its function owner/SET/schema authority. |
| P05:828-830 and corresponding table blocks through :914; :916-930; :934-1002; :1007-1130 | After transfer, ENABLE/FORCE RLS, policy creation, grants/revokes and function alteration still need owner or relevant grant authority. SET-only membership with INHERIT FALSE does not retain that authority automatically as the original current_user. Extension digest EXECUTE at :930 also requires valid grant authority on that provider-owned dependency. |
| P05:1135-1137 ALTER DEFAULT PRIVILEGES FOR ROLE | Needs effective target-role authority or privileged execution. ADMIN alone and unswitched SET-only membership are not sufficient. |
| P11:37-38 schema USAGE and FOR ROLE defaults | Schema grant authority and effective check-in-owner default-ACL authority are required before new objects. USAGE is not CREATE. |
| P11:40-45 attendance ALTER/constraint/index; :57 new table OWNER TO; :58-88 RLS/grants/policies | Existing protected-table DDL plus new-object ownership and post-transfer authority are required. |
| P11:103, :124 private helper OWNER TO; :163, :184, :219 API OWNER TO | Five exact function transfers require ordinary transfer prerequisites unless a supported privileged path performs them. Their following revokes/grants also need authority. |
| P05:1235-1238, :1754-1758; P11:223-240 | Final clean-state assertions must run after any candidate temporary authority has been removed. Preserve and extend these checks rather than bypassing them. |

Source clarification: the prior A02 review section 2 says P11 does not itself
fully check schema CREATE. P11 **does** explicitly deny private/api/public CREATE
at lines 231-237. This design uses that stronger actual exit contract. The prior
document is not edited here. P11's no-membership guard is at entry; a candidate
design must additionally verify membership cleanup at exit.

PG17's automatic creator ADMIN edge is bootstrap-superuser granted and cannot
simply be removed by the creating non-superuser. Empty createrole_self_grant
does not suppress it; that setting controls additional SET/INHERIT capabilities.
NOLOGIN and NOINHERIT do not establish absence of role-assumption paths.
[PG17 role attributes](https://www.postgresql.org/docs/17/role-attributes.html).

Ordinary table/function ownership transfer requires more than CREATEROLE.
Changing owner also changes a SECURITY DEFINER function's execution identity.
[PG17 ALTER TABLE](https://www.postgresql.org/docs/17/sql-altertable.html),
[PG17 ALTER FUNCTION](https://www.postgresql.org/docs/17/sql-alterfunction.html).
Default ACL authorization checks effective role privileges; defaults apply to
the creator, not retroactively to objects transferred to another owner.
[PG17 default privileges](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html),
[PG17 upstream ACL implementation](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/catalog/aclchk.c).

## 2. Remediation options

| Option | Mechanism | Security implications | Operational requirement / source effect |
| --- | --- | --- | --- |
| A - supported privileged release execution | Owner-authorized provider-operated mechanism with demonstrated authority executes the exact unchanged migration files, with their own transactions and assertions | Avoids introducing application memberships/schema CREATE or a new tenant-accessible privileged routine. Migration operator itself is highly trusted and must be tightly scoped operationally. Ordinary customer postgres cannot be presumed equivalent. | Provider must confirm support and exact execution identity/capabilities, allowlist, logging, recovery and runner/history handling. Rehearse P01-P17 on PG17. No SQL migration change needed if the entire unchanged sequence passes. Availability UNKNOWN. |
| B - explicit, bounded authority lifecycle in revised migration design | Clean entry validation, provider-assisted clean role bootstrap, narrowly authorized temporary authority during each reviewed mutation phase, complete cleanup, unchanged strict final contract before commit | More complex and riskier: authority exists during migration, and failures/other sessions can expose privilege leaks if not atomic. Requires deliberate continuing DDL authority, data-guard visibility and grantor-aware cleanup. No permanent runtime broadening permitted. | Requires separate source authorization for P05/P11 and affected later files/runner/tests. Ordinary customer SQL alone is not proven capable of establishing/removing all required authority. Existing migrations cannot be made compatible just by a prelude. |

Option B is a real design alternative with prerequisites, not a ready-to-run
customer-only workaround. Provider-assisted role creation/cleanup or another
supported trusted mechanism is necessary wherever the ordinary operator cannot
remove bootstrap-granted edges or perform an operation. If that cannot be
provided, Option B is also blocked. Do not treat role-admin grants as harmless
because SET/INHERIT are initially false: ADMIN can enable further grants.

Rejected alternatives: retain ADMIN-only exceptions permanently; make executors
LOGIN/SUPERUSER/BYPASSRLS/CREATEROLE; grant PUBLIC schema CREATE; rely on broad
table privileges instead of ownership; change schema owners to manufacture
CREATE; disable FORCE RLS; expose a generic DDL SECURITY DEFINER endpoint; delete
assertions; mark history applied; or use the browser/service role as migrator.

## 3. Recommended design: Option A with a strict qualification gate

### A1 - qualify without production mutations

Owner confirms, privately and through an approved provider channel, whether a
supported execution service exists that can satisfy **all** relevant operations.
Ask about capabilities and scope, never credentials. Confirm PG17 version,
extensions/event-trigger restrictions, function/extension grant authority, role
creation behavior, default ACL changes, full-visibility audit/data guards,
transaction boundaries and migration-history bookkeeping. A platform assertion
that a role has CREATEROLE is not sufficient evidence.

Supabase documents that customer postgres is not a superuser and has selected
extra privileges. Those extras do not establish an arbitrary privileged release
mechanism. Nothing here requests elevation of the customer role or assumes a
provider operator is available on the approved service plan.
[Supabase customer-role limitations](https://supabase.com/docs/guides/database/postgres/roles-superuser).

### A2 - isolated acceptance before scheduling

Run unchanged source under the exact supported authority/runner in an approved
isolated PG17 environment with synthetic baseline and legacy refusal cases.
Demonstrate both positive replay and negative caller tests. A true local
superuser may establish standard capability, but does not prove the provider
service or production configuration behaves identically. Match both layers.

Pin hashes for all 37 files, source commit, runner, operation allowlists and
configuration references. Preserve 20 recorded versions; reconcile the 17
unrecorded versions and three present marker occurrences separately. No runner
may skip a refused migration, fabricate history or silently retry a lost commit.

### A3 - approved release authority, without runtime grants

Only after separate approval, the trusted operator executes reviewed original
files in chronological order with the recovery plan's per-file checkpoints.
No temporary executor memberships or schema CREATE grants are needed merely
to satisfy standard superuser checks **if** the demonstrated mechanism bypasses
those checks. Do not add grants unnecessarily. Existing strict role/catalog
assertions remain active, and all genuine legacy-data refusals still halt.

The release window excludes application mutations through approved controls;
UI hiding alone is insufficient. Operator access is Owner/provider controlled,
never assigned to the Developer's ordinary member identity, browser credentials,
Edge service identity or any executor role. Do not change provider-owned object
ownership, grant customer superuser, or create a permanent privileged helper.

### A4 - close authority and prove final state

End the temporary operator job/session and revoke any separately granted
project/operator access according to the provider-supported mechanism. Verify
job completion, access expiry/removal, no surviving sessions with temporary
authority and a fresh-session effective privilege check. Do not revoke or alter
provider infrastructure roles blindly. If the mechanism needs tenant grants,
they require an explicit manifest/cleanup design before A can be accepted.

Database final checks must show no reserved-role membership edges, no executor
schema CREATE, exact owners/FORCE RLS/ACLs and no new privileged helper. Provider
operator access existing outside the application role graph is a separate trust
boundary; it does not authorize permanent membership in application roles.

## 4. Option B detailed design requirements if A is unavailable

This section specifies required future changes; it does not authorize or edit
them. Keep immutable source fingerprints and obtain a separate reconciliation
decision before changing any migration already applied elsewhere. A later
migration cannot fix authority needed by an earlier migration that cannot run.
Do not inject a hidden prelude, renumber history or claim a replacement was the
original applied file.

### B1 - role bootstrap and strict entry

Use a demonstrated privileged bootstrap path to create clean reserved NOLOGIN
roles without surviving automatic ADMIN edges. Existing role attributes,
owners, grants, memberships and dependencies must match the exact stage; refuse
drift. In P11, precreated check-in role must be unused, satisfying lines 18-25.
No temporary membership/CREATE grant may precede the unchanged clean-entry
checks. Only after they pass may a revised, explicitly reviewed mutation phase
introduce listed authority. Preserve role attributes throughout.

### B2 - bounded authority phase

Build a per-statement authority manifest: object identity, current owner,
destination owner/schema, required authority, grantor, actor/session, lifetime,
cleanup inverse and verification. Include post-transfer ALTER/POLICY/GRANT and
FOR ROLE defaults, not just OWNER TO. Possible mechanisms, subject to proof:

- Temporary SET-only authority with explicit role-context changes for each
  owner operation; defaults execute in the target current-role context.
- Temporary effective inherited owner authority while the designated migrator
  remains current_user, plus SET capability for transfers. This is stronger
  authority and demands equally strict cleanup and concurrency isolation.

Neither mechanism alone solves locks, provider extension grants, data guards
under FORCE RLS or the grantor's ability to remove every membership. A trusted
grantor must be able to issue and revoke exactly the intended edges. Merely
granting ADMIN to the migrator to bootstrap the design creates another edge
that also needs removal; it is not a solution to the original automatic edge.

Target CREATE, if required for transfers, is temporary and limited to the
specific private/api/public schema required by each object. Never change schema
owners or grant CREATE to PUBLIC/browser/service roles. Existing executor
USAGE and intended data privileges are independent and must remain intact.

A SECURITY DEFINER function cannot be used as a generic SET ROLE wrapper:
PostgreSQL disallows SET ROLE inside SECURITY DEFINER functions. If provider
installation of fixed privileged operations is the only possible mechanism,
that requires its own reviewed allowlist, secure schema/search_path, restricted
EXECUTE, no arbitrary SQL/object names, bounded lifetime and removal. This is
not permission to install such a helper and may be less desirable than Option A.
[PG17 SET ROLE](https://www.postgresql.org/docs/17/sql-set-role.html).

### B3 - full-visibility guards without weakening RLS

P06 directly reads private audit events/heads and alters their hash helper;
P07 directly checks legacy membership/payment state. FORCE RLS still applies
to ordinary data owners. Temporary ownership membership or SELECT alone does
not prove full visibility, and executing all business SQL as an executor changes
CURRENT_USER policy behavior. Each guard must retain its exact validation meaning.

Require a demonstrably authorized full-visibility execution path for the guard,
or a separately designed fixed diagnostic mechanism under suitable trusted
authority. No disabling RLS, granting application BYPASSRLS, universal policy or
filtered empty-table PASS. If full visibility cannot be achieved safely, stop;
do not weaken guards to make an otherwise ordinary-role design run.

### B4 - cleanup before assertions and commit

For a candidate revised P05, place the bounded authority phase after complete
entry validation (original mutation block begins at :827), and finish cleanup
before the final profile/assertions (original :1139). For candidate P11, it must
follow the clean role check but precede FOR ROLE defaults (:38); cleanup must
complete before the existing verifier-boundaries check (:223). Add an explicit
zero-membership exit check for all four roles, in addition to unchanged final
cross-phase assertions. Do not allow authority to survive a file's COMMIT.

Cleanup must run in the same transaction as grants and DDL under a compatible
runner. Record exact membership grantors, options and dependent grants; revoke
the temporary edges from the actor, not just SET/INHERIT options. Reset role
context before checking, revoke listed target-schema CREATE grants, remove any
temporary grant options/object privileges and remove candidate-only helpers.
If grantor identity requires provider assistance, the mechanism must support
atomic cleanup; a promised later session is insufficient. No unreviewed CASCADE.

Compare effective privileges and catalog edges with the approved final manifest.
PUBLIC/inherited/schema-owner access can make an ACL-text REVOKE insufficient.
Require zero edges where either member or roleid is reserved; recursively check
SET/INHERIT reachability from application identities and test direct login as
the migrator in a fresh session. Explicit cleanup failure aborts the transaction.
An administrator is not exempt from the final membership graph.

Role contexts/settings can be transaction-local; grants/memberships are not
automatically transaction-local and require revoke or transaction rollback.
A successful COMMIT with forgotten grants is a security failure. A lock/statement
timeout or disconnect is not evidence of rollback: the trusted operator must
prove transaction closure, lock release and absence of privilege leakage.

## 5. Migration changes and compatibility across the remaining sequence

| Stage | Option A | Option B required future scope |
| --- | --- | --- |
| Recorded 20 files; P01-P04 | Preserve exact source/history; reconcile baseline | Same; do not alter baseline owners to force later assertions |
| P05 | No source change if qualified supported execution passes | Explicit entry/mutation/cleanup/exit lifecycle, exact 22-table/25-routine transfers, defaults and dependent ownership; preserved bodies, ACL/RLS and strict final checks |
| P06 audit timezone | Same authority must read/lock audit and alter helper | Resolve full-visibility guard and function-owner authority; never rehash stored events |
| P07 lifecycle | Full integrity checks and transferred-object DDL | Resolve locks, actual row visibility, helper creation/transfer, policy/default needs; no guessed data repair |
| P08-P10 | Exact owner/public runtime contracts | Repeat bounded authority for new/replaced routines and new tables; after each file remove temporary authority |
| P11 | Exact fourth-role guard/defaults/transfers/checks | Bootstrap unused role; bounded authority; five function and one table transfers; explicit final membership check plus original verifier/CREATE checks |
| P12-P17 | Execute exact source under qualified authority | Review every later new/replaced function/table/policy and correction/reporting guard; repeated transfer and ownership requirements remain |
| Runner and assertions | Demonstrate per-file commits/history semantics; unchanged final checks | Add non-superuser/session-context/failure tests and phase-aware authority assertions; preserve strict final contract. Historical ADMIN-only exceptions are not current acceptance |

See `supabase/migrations/20261110103000_audit_timezone.sql:9`, `:20`, `:31`;
`supabase/migrations/20261110110000_membership_lifecycle.sql:9`, `:32`, `:60`;
and the complete later-site index in the prior A02 review. Do not release a
partial schema to application traffic or selectively deploy handlers during
reconciliation. Unchanged final code depends on P17 as well as earlier objects.

## 6. Permanent security invariants

These are final-state requirements, not permissions to relax checks temporarily
without an approved Option B design:

- All four reserved roles remain NOLOGIN, NOSUPERUSER, NOCREATEDB, NOCREATEROLE,
  NOINHERIT, NOREPLICATION and NOBYPASSRLS. No incoming or outgoing role
  membership, including ADMIN-only, remains in the current final contract.
- No executor schema CREATE or ownership of provider schemas; private tables
  stay owned by gym_data_owner with ENABLE and FORCE RLS. Final release targets
  33 protected tables, not just P05's 22.
- API SECURITY DEFINER ownership remains bounded to the intended executors;
  private helpers remain invokers; qualified objects/empty search_path remain.
  Verify overloads and creator/global/schema defaults as well as explicit ACLs.
- Browser roles have no protected-data access or privileged RPC execution;
  service_role transports approved server RPC calls without direct protected
  table/column/sequence access. Runtime roles never receive migration authority.
- Current verified Owner identity is checked server-side and within privileged
  RPCs. Exact money, approval/payment-before-access, immutable receipts/audit,
  no refunds/free memberships/checkout, current-date claim rules, 15-minute
  provisional walk-ins and one valid daily Manila member check-in remain intact.
- No PIN/token/credential material appears in logs, client outputs or diagnostic
  exports. Full role/ACL outputs remain Owner-private; report only sanitized gates.

## 7. Isolated PostgreSQL 17 validation plan

No PG17 runtime tests ran for this document. Prior discovery found only local
PG18 and no reachable Docker daemon. Do not install/start/provision an environment
under this task. Obtain separate approval for a matching isolated target first.
Use synthetic identities/data only and actual non-superuser login sessions;
superuser SET ROLE probes do not certify the intended login/session path.

| Test | Setup/action | Acceptance criterion | Current result |
| --- | --- | --- | --- |
| V01 environment/actor | Pin PG17 patch, extensions, provider mechanism, runner, hashes, session_user/current_user, role attributes and self-grant setting | Confirm expected target/authority before mutations; no secrets in output | UNKNOWN |
| V02 original refusal | Run unchanged P05 with a non-superuser CREATEROLE actor and absent roles; separately repeat P11 after synthetic compatible predecessors | Automatic membership causes explicit refusal; no surviving transactional roles/schema or invented history | UNKNOWN |
| V03 prerequisite isolation | On synthetic table/function test no SET, no target CREATE, no old-owner authority, ADMIN-only defaults, unswitched SET-only defaults | Each insufficient-authority case refuses; distinguish engine error from application guard | UNKNOWN |
| V04 supported positive path | A: full unchanged replay under qualified supported authority. B: separately reviewed candidate replay with exact manifest | All files, stage checks and final assertions pass; no manual assertion bypass/fixture repair | UNKNOWN |
| V05 continuing authority | Test DDL, policy creation, function metadata, default ACLs and grants after OWNER TO | Correct actor/owner authority throughout; SET-only assumption not mistaken for inherited authority | UNKNOWN |
| V06 cleanup | Test membership edges for all grantors/options, schema CREATE via direct/PUBLIC/inherited/owner paths, direct privileges and helper lifetime | Exact final manifest; zero reserved edges; no temporary helper/access. Fresh-session role-assumption attempts refuse | UNKNOWN |
| V07 security and RLS | Actual restricted callers, forged/non-Owner actor, direct service/browser table/column/sequence/RPC attempts; valid authorized server paths | Narrow positives only; force-RLS owner behavior and caller filtering proven independently of privileged migrator | UNKNOWN |
| V08 complete data guards | Seed compatible and incompatible synthetic UTC audit, lifecycle, duplicate allocation/overlap, legacy drawer and receipt states | Compatible replay succeeds; every deliberate legacy refusal remains; guard visibility cannot yield false empty PASS | UNKNOWN |
| V09 injected failures | Candidate failures before/after role creation, after temporary grants, after first transfer, before cleanup, during cleanup and before COMMIT | Same-session rollback; clean role/grant graph, original objects intact, locks released; earlier committed files explicitly accounted for | UNKNOWN |
| V10 timeout/disconnect/lost acknowledgement | Controlled cancellation/lock contention, disconnect before commit and lost response after commit | Actual commit outcome established before retry; per-file runner/history behavior proved; no automatic history repair | UNKNOWN |
| V11 business/race regression | Full synthetic P01-P17 business, audit append, payment/receipt correction, credential/check-in, void/claim and concurrency suites | Existing finalized rules preserved, append-only originals and exact financial semantics retained | UNKNOWN |
| V12 release/future maintenance | End provider job or revoke manifest authority; reconnect migrator and runtime identities; rehearse next reviewed maintenance operation separately | No residual authority or bypass; future maintenance path documented without permanent runtime expansion | UNKNOWN |

Require stage-specific `supabase/tests/executor_hardening_assertions.sql`,
`supabase/tests/member_checkin_behavior.sql` and
`supabase/tests/final_security_assertions.sql` plus new actor/cleanup tests.
The old `supabase/tests/database_owner_migration_procedure.sql:152` probe grants
temporary authority and does not establish unchanged migration compatibility.
The old foundation ADMIN-only exception must not override current final checks.
Adapt isolated harnesses only after separate implementation approval.

Expected negative tests must pass by refusing, and must be reported separately
from successful replay. Capture hashes, actor/context, sanitized SQLSTATE,
transaction outcome and individual invariant results. Never treat a successful
DDL, empty filtered aggregate or local superuser suite as hosted acceptance.

## 8. Owner decisions, hosted assumptions and GO/NO-GO

| Unresolved item | Required confirmation/approval |
| --- | --- |
| Supported authority mechanism | Does provider support Option A with unchanged zero-membership/no-CREATE source on the approved plan? Exact capability, availability and cost remain UNKNOWN |
| Intended operator/session | Actual current/session roles, existing ownership, role/grant authority, extension ACL authority, creator defaults and provider restrictions; approved private diagnostic results only |
| Role state | Attributes, grantors/options, all incoming/outgoing edges, dependencies and P11 unused-role prerequisites; no assumptions from role names |
| Runner | Stable session, transaction/DDL semantics, handling source BEGIN/COMMIT, sanitized logging, fail-fast/history bookkeeping and acknowledgement recovery |
| Isolated environment | Separate Owner approval for PG17 access/provisioning and synthetic testing; no production copies to Developer machines |
| Option choice | Approve A qualification first; if unsupported, explicitly scope B source/authority/test design and any provider bootstrap. Do not silently weaken the final membership rule |
| Production reconciliation | Identify three present marker occurrences; resolve exact definitions/default ACLs, audit/data and backup/restore blockers independently |
| Operational execution | Later explicit approval of source bytes, operator, maintenance controls, lock/duration budget, backup/recovery point, abort/cleanup and verification plan |

**GO for Owner review of this design only. NO-GO for production execution or
source implementation.** The recommended path preserves unchanged final
security and source assertions if supported; that support is unproven. Option B
is a separately gated fallback, not evidence the current hosted customer role
can execute the SQL. No temporary permission scheme is accepted until both
successful replay and failure cleanup have passed in the intended environment.

Stop after this document. Do not run diagnostics, migrations, membership/ACL
changes, history repair, deployment, commit, merge or push on its authority.
