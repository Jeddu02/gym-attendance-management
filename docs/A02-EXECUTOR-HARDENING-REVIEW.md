# A02: restricted executor and ownership-transfer review

Prepared 2026-11-16, Asia/Manila. Source branch: `review/production-recovery`.
Reviewed commit: `db700c1f42cdf561e3f55d61897ba8eb4948c94e`.
Production reference, for context only: `alxhytivwybjbkjjdsyn`.

**A02 decision: NO-GO for production application of the unchanged migration sequence.**
Standard PostgreSQL 17 non-superuser permissions conflict with the migration's
simultaneous no-membership/no-schema-CREATE assertions and ownership transfers.
This is a source/documentation-confirmed incompatibility, not a reproduced hosted
failure. The actual hosted operator, provider-specific permissions and any
privileged execution mechanism remain UNKNOWN. SQL Editor's role name
`postgres`, CREATEROLE, database ownership and service-role API access are not
proof of superuser or ownership-transfer authority.

Only this report was created. No database SQL was executed, no environment was
provisioned or started, and no migration, application source, role, grant,
configuration, history, production record or deployment was changed. No secrets
were requested or read. No commit/push/merge was performed. The earlier recovery
report remains a historical baseline; this report narrows its A02 finding.

## 1. Evidence and scope

The working tree was clean and the branch/commit matched the requested baseline
at investigation start. Reviewed both complete target files, their security
assertions and related migration/test source. The operation indexes below locate
all matching statements in the two target migrations; later-migration ownership
operations are indexed separately. Line references are for the reviewed commit.

- `supabase/migrations/20261110100000_executor_hardening.sql` (P05).
- `supabase/migrations/20261110150000_member_checkin.sql` (P11).
- Related baseline security/audit, lifecycle, PIN, walk-in, receipt, cash, claims,
  allocation and reporting migration ownership/grant patterns.
- `supabase/tests/executor_hardening_assertions.sql`,
  `supabase/tests/executor_behavior.sql`,
  `supabase/tests/member_checkin_behavior.sql`,
  `supabase/tests/final_security_assertions.sql`,
  `supabase/tests/database_security_foundation_assertions.sql`,
  `supabase/tests/database_owner_migration_procedure.sql`, and
  `scripts/test-database.ps1`.
- `docs/production-preflight/04-migration-authority.sql` and the supplied evidence
  summarized in `docs/production-recovery-plan.md` sections 3, 4, 6, 11 and 12.
  No new production result grids or migration-actor results were supplied.

Official PostgreSQL 17 documentation and upstream PG17 source were consulted for
permission rules, alongside Supabase's documented customer-role limitations.
Those establish standard behavior, not the target project's current attributes.

## 2. Root causes and source findings

### A02.1 - HIGH: role creation immediately conflicts with membership refusal

P05 creates three roles with NOLOGIN, NOSUPERUSER, NOCREATEDB, NOCREATEROLE,
NOINHERIT, NOREPLICATION and NOBYPASSRLS at lines 14-24. Its catalog check at
lines 27-30 rejects **every** membership touching those roles, including an
ADMIN-only edge from a trusted migration operator. The same invariant is checked
again at lines 132-135 and 1235-1238.

On PG17 a non-superuser CREATEROLE creator automatically receives an ADMIN-only
membership in each role it creates. The default edge has SET FALSE and INHERIT
FALSE, but it is still a membership. Accordingly, ordinary role creation reaches
P05's explicit refusal before its table transfers. P11 repeats this pattern for
`gym_checkin_executor` at lines 11-33. This is deterministic under documented
standard behavior if the role is absent and the creator is a non-superuser.
No runtime execution is claimed here.

The bootstrap superuser grants this automatic edge; the creating CREATEROLE user
cannot simply remove or edit that particular grant. Additional self-grants do not
remove it. `createrole_self_grant` can add SET/INHERIT capability; setting it empty
does not suppress the implicit ADMIN relationship. Both settings still conflict
with an assertion forbidding every edge. NOINHERIT does not remove memberships
or SET paths. [PG17 role attributes](https://www.postgresql.org/docs/17/role-attributes.html),
[PG17 createrole_self_grant](https://www.postgresql.org/docs/17/runtime-config-client.html#GUC-CREATEROLE-SELF-GRANT).

Precreating roles through a genuine privileged administrator can avoid this
creation branch, but does not resolve A02.2-A02.4. P11 also rejects preexisting
roles with ownership or listed ACL dependencies (lines 18-25); it is not a
general reuse mechanism for an already active role.

### A02.2 - HIGH: required transfer authority is incompatible with assertions

P05's input checks require no effective CREATE on private/api/public for the
reserved roles (lines 651-655), then transfer the first table at line 827 and
the other tables/routines through line 1126. The output check repeats the CREATE
refusal at lines 1754-1758. No intermediate grant of destination schema CREATE,
role membership, SET ROLE, or privileged transfer helper is present.

Ordinary PG17 table/function ownership changes require current-owner authority,
the ability to SET ROLE to the new owner, and CREATE for the new owner in the
object's schema. An ownerless membership graph cannot supply that SET path.
Existing schema ownership or PUBLIC/inherited CREATE also counts as effective
CREATE and would fail P05's assertion. USAGE alone is insufficient. Thus, even
with safely precreated memberless roles, an ordinary authorized object owner
cannot execute P05's first transfer under the asserted state.
[PG17 ALTER TABLE](https://www.postgresql.org/docs/17/sql-altertable.html),
[PG17 ALTER FUNCTION](https://www.postgresql.org/docs/17/sql-alterfunction.html).

P11 has the same destination-owner requirement for its new rate table and five
functions (lines 57, 103, 124, 163, 184 and 219). Its new role receives schema
USAGE, not CREATE (line 37). P11 does not independently assert every possible
schema CREATE exposure for the new role; the final cross-phase assertion does
at `supabase/tests/final_security_assertions.sql:10`. That omission cannot make
schema CREATE a safe workaround.

### A02.3 - HIGH: authority is needed after transfer, not just at OWNER TO

P05 executes ENABLE/FORCE RLS and REVOKE immediately after changing each table
owner (for example lines 827-830). Later policy creation and grants also need
ownership/grant authority. After a non-superuser transfers an object away,
SET-only membership with INHERIT FALSE does not automatically supply continuing
owner privileges while current_user stays the original actor. Function metadata
changes/revocations following transfer have the same issue (lines 1006-1010).

An approved future design must account for every subsequent DDL/ACL statement:
inherited owner authority, deliberate role context changes, or a suitably
privileged controlled executor. A temporary SET-only membership and CREATE grant
around OWNER TO alone are not a complete solution. Broad table grants are not
equivalent to ownership. FORCE RLS also continues to constrain ordinary owners'
data access; ownership alone is not a data-migration bypass.

P05 expects the input tables/routines to be owned by `postgres`, not an arbitrary
new migration login (`executor_hardening.sql:345`, `:619`). An actor that can
create objects but lacks the existing owner's privileges may fail earlier on
locks/assertions/DDL. Do not reassign the baseline just to satisfy this check.

### A02.4 - HIGH: default ACL changes need a separate authority path

P05 changes future function defaults FOR ROLE each reserved role at lines
1135-1137; P11 does this at line 38. PG17's implementation checks
`has_privs_of_role(GetUserId(), target_role)` and rejects unauthorized callers.
ADMIN alone or SET-only membership while remaining another current_user is not
sufficient. Effective inherited authority or execution as that role can satisfy
ordinary checks, but the current zero-membership model supplies neither to a
separate non-superuser actor. A genuine superuser bypasses ordinary checks.
[PG17 upstream aclchk.c, ExecAlterDefaultPrivilegesStmt](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/catalog/aclchk.c),
[PG17 default privileges](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html).

Default privileges belong to the creator/current role. ALTER OWNER does not
apply the destination owner's defaults retroactively, and CREATE OR REPLACE can
retain an existing ACL. P05/P11's default revocations do not certify objects
created by postgres/another operator. Per-schema default grants can add access
on top of global defaults. A future authority fix must preserve explicit narrow
routine ACLs and separately resolve A03 creator-default uncertainties.

### A02.5 - MEDIUM: historical probes are not the current authority contract

- `database_security_foundation_assertions.sql:15` requires a local superuser.
  Lines 59-78 allow a postgres ADMIN TRUE/SET FALSE/INHERIT FALSE edge. Current
  P05/P11 and `final_security_assertions.sql:20` reject all reserved-role edges.
  This historical exception is not authority to weaken current assertions.
- `database_owner_migration_procedure.sql:148` describes an approximation. Lines
  152-154 grant temporary SET-only membership and private/public schema CREATE;
  lines 181-184 transfer probe objects while current_user remains postgres.
  That is a different context from unchanged P05 and does not prove post-transfer
  DDL, function transfers, cross-role default ACLs or runner compatibility.
  Its old 20-private-table inventory at line 49 also differs from later release
  inventories; do not run it as current production acceptance.
- `scripts/test-database.ps1:2` defaults to PG18, initializes a fresh postgres
  cluster at line 109 and guards both current_user/session_user as postgres at
  lines 79-86. It has no non-superuser migration-actor mode. SET ROLE in behavior
  tests tests callers, not the authority used to apply migrations. P05-stage
  acceptance at lines 141-147 and final assertions remain valuable, but earlier
  local-superuser PASS cannot certify hosted PG17 execution.

## 3. PG17 compatibility matrix

PASS/FAIL here describes the specified standard permission scenario, not an
executed database test. All actual hosted outcomes remain UNKNOWN until proven.

| Operation/scenario | Genuine superuser | Ordinary non-superuser / CREATEROLE actor | Existing source consequence |
| --- | --- | --- | --- |
| Create restricted NOLOGIN roles | Can create them without the non-superuser creator edge | CREATEROLE needed; implicit ADMIN membership created | P05/P11 FAIL their no-membership assertion after ordinary creation |
| Change existing role attributes | Can administer roles | Generally CREATEROLE plus ADMIN for another ordinary role; protected attributes have additional restrictions | No ALTER ROLE in the migration set; unsafe existing attributes deliberately refuse |
| ADMIN-only relationship | Can administer directly | Does not itself inherit object privileges or allow SET ROLE | Even this relationship is rejected; ignoring it would not solve transfers |
| NOINHERIT or NOLOGIN | Neither restricts superuser's authority | NOLOGIN prevents login; NOINHERIT does not prohibit SET via a valid SET grant | Neither is proof that other principals cannot assume the executor |
| SET ROLE to destination | Can select any role | Requires SET-enabled membership path; existing-owner status/CREATEROLE alone insufficient | Memberless target roles cannot supply an ordinary actor's path |
| Transfer table/function ownership | Ordinary ownership restrictions bypassed | Requires existing-owner authority, SET capability and target schema CREATE | P05's input state prohibits prerequisites; P11 repeats the transfer pattern |
| ALTER/FORCE/POLICY/GRANT after transfer | Can continue | Must retain/reacquire appropriate new-owner/grant authority | Existing code never changes actor context or grants that authority |
| FOR ROLE default privilege changes | Can change any ordinary target's defaults | Requires effective target-role privileges/current role, not ADMIN alone | No compatible ordinary authority path established |
| FORCE RLS | Can set it; superuser still bypasses row filtering | Table owner can set it; ordinary owner then subject to policies | Preserve FORCE; successful admin reads do not prove caller RLS |
| SECURITY DEFINER invocation | Can invoke regardless of normal privilege checks | Needs function EXECUTE/schema access; body runs as its owner | Allows narrow runtime access without caller membership; does not grant migration DDL authority |
| Customer hosted role named postgres | Role name proves nothing about actual superuser status | Supabase documents customer postgres is not a superuser, with selected extra privileges | UNKNOWN provider-specific path; standard CREATEROLE behavior is insufficient |

Role administration is separate from ownership of tables/functions. Database
ownership, including implicit `pg_database_owner` effects on public schema,
does not confer ownership of every existing object. Neither SQL Editor nor a
CLI automatically changes those rules. [PG17 ALTER ROLE](https://www.postgresql.org/docs/17/sql-alterrole.html),
[PG17 SET ROLE](https://www.postgresql.org/docs/17/sql-set-role.html),
[Supabase superuser limitations](https://supabase.com/docs/guides/database/postgres/roles-superuser).

FORCE RLS does not constrain superusers/BYPASSRLS roles, and policies do not
govern TRUNCATE/REFERENCES. Retain privilege denials and immutable-history
triggers as well as RLS. CURRENT_USER-based executor policies are only safe in
combination with verified server actors and checked RPC bodies; they do not
authenticate an Owner by themselves.
[PG17 row security](https://www.postgresql.org/docs/17/ddl-rowsecurity.html).

## 4. Isolated environment and test results

| Check actually performed | Result | Evidence/limit |
| --- | --- | --- |
| Branch/HEAD/clean initial status | PASS | Exact requested branch and commit; no preexisting changes |
| Local runtime discovery | PASS, narrow | Installed PostgreSQL directory contains version 18 only; postgres/psql not on PATH |
| Existing usable Docker PG17 environment | UNKNOWN / unavailable | Docker CLI exists; daemon named pipe unavailable; restricted CLI config access also reported. No engine started, image pulled or configuration read to bypass restriction |
| Matching PG17 non-superuser environment | UNKNOWN / NOT RUN | No suitable already-authorized environment established |
| Standard permission conflict | FAIL compatibility, static | PG17 official rules plus exact source assertions described above |
| Unchanged P05/P11 migration execution under PG17 non-superuser | UNKNOWN / NOT RUN | No SQL sent to any database |
| Actual Supabase actor/provider authority | UNKNOWN | No hosted connection or production SQL |
| Existing PG18 superuser suite | Historical PASS only | Recorded in recovery report; not rerun or relabeled as PG17 evidence |

No PG18 database was started as a substitute and no protected old test cluster
was reopened. Source test parsing or Node/Deno application suites cannot settle
database ownership semantics, so they were not presented as A02 execution tests.

### Exact required isolated test protocol (not executed; not production SQL)

Obtain approval for a disposable PG17 environment first. Use one fresh synthetic
database/role namespace per case; preserve logs privately without password
catalogs or live data. Match target PG17 patch/extensions/provider behavior and
exact intended runner. Tests may mutate only the authorized disposable target.
Do not wrap whole migration files in an outer rollback: they own their commits.
Use actual non-superuser login connections; superuser-session SET ROLE alone
does not prove a real connection's SET/session authority.

| Case | Exact setup/action | Required observation; current result |
| --- | --- | --- |
| T01 identity | Direct connection as synthetic non-superuser creator; verify server_version_num 170000-179999, current_user=session_user, rolsuper=false, rolcreaterole=true, rolbypassrls=false; record createrole_self_grant | Guard must pass before SQL; UNKNOWN |
| T02 implicit membership | As that creator, CREATE ROLE a fresh synthetic target with all seven restricted attributes used by P05; inspect pg_auth_members roleid/member/grantor/admin_option/inherit_option/set_option | With default self-grant setting, ADMIN true/SET false/INHERIT false; exact P05/P11 membership predicates must detect it; UNKNOWN |
| T03 unchanged refusal | Prepare synthetic recorded baseline plus P01-P04; run exact P05 bytes as eligible non-superuser actor with absent reserved roles; separately, prepare accepted through-P10 state via isolated administrator and run unchanged P11 as non-superuser | Expected refusal at reserved-role membership guard; capture sanitized SQLSTATE, then prove transaction rollback and no new role/object/history effects; UNKNOWN |
| T04 precreated memberless role | Isolated administrator creates target roles without membership; actor owns a synthetic schema/table and function; target has no schema CREATE and actor has no SET path; attempt table and function OWNER TO independently | Both ordinary transfers must fail with insufficient privilege (42501); UNKNOWN |
| T05 separate transfer prerequisites | On separate synthetic objects, test (a) schema CREATE only/no SET, (b) SET-only membership/no target CREATE, (c) both with current-owner authority, (d) both but no current-owner authority | (a),(b),(d) refuse; (c) transfers. These explanatory microcases are not a route around unchanged migration assertions; UNKNOWN |
| T06 post-transfer continuity | After successful microcase (c), remain original current_user with SET true/INHERIT false; attempt ENABLE/FORCE RLS, policy creation, function alteration and object grants on transferred objects | No automatic new-owner authority; owner-only operations refuse unless another legitimate authority exists. Test each separately; UNKNOWN |
| T07 default ACL authority | Test FOR ROLE defaults as unrelated actor, ADMIN-only actor, SET-only actor without switching, effective inherited owner, and target current_user | First three refuse under standard PG17; effective owner/current-role cases succeed. Verify new functions' ACLs separately from transferred/replaced functions; UNKNOWN |
| T08 creator setting | Repeat T02 in separate isolated cases with createrole_self_grant empty/set/inherit | Extra SET/INHERIT changes do not eliminate the automatic ADMIN edge or satisfy zero-edge assertion; UNKNOWN |
| T09 final security | After any separately approved candidate replay, run unchanged stage-specific and final assertions; negative tests as anon/authenticated/service_role and real non-Owner Auth identity | No reserved memberships/CREATE leaks; NOLOGIN/non-bypass; FORCE RLS; no direct protected data; only approved RPC EXECUTE; UNKNOWN |
| T10 full later chain | Replay baseline and P01-P17 with exact candidate authority path and runner; exercise ownership plus lifecycle/receipt/audit/check-in behavior/races with synthetic records | No new authority gaps, no raw credential exposure, correct payment-before-access and one valid daily check-in; UNKNOWN |
| T11 abort/acknowledgement | Inject controlled permission failure before transfer, after transfer and before cleanup/commit in candidate-only fixture; simulate lost client acknowledgement | Same-session rollback/lock release; no surviving temporary privileges; distinguish schema commit/history acknowledgement without history repair; UNKNOWN |

Keep expected refusal tests separate from positive acceptance. Never comment out
assertions or manually repair their fixture state midway to make the unchanged
migration appear to pass. Record exact input hashes, operator and session role,
source/runner versions, phase, SQLSTATE, commit state and final-state checks.
Do not export connection strings, verifiers or record bodies.

## 5. Secure remediation options (design review only)

### Option A - provider-supported privileged execution of unchanged source

Determine whether the Owner has a supported provider-operated execution path
that can perform the full sequence with genuine required authority while
retaining every current assertion. This is the least source-invasive option if
available; its availability, cost/free-tier suitability, scope and operational
approval are UNKNOWN. Do not request customer superuser elevation, provider
credentials or a service-role key. A general SQL Editor session is not proof.

Test the complete unchanged chain under the exact supported mechanism,
including role creation, post-transfer DDL, defaults and later data guards.
Provider privileges can mask caller bugs, so runtime negative tests still use
restricted callers. Never leave a privileged helper reachable by application
roles, extend the provider mechanism to uncontrolled SQL, or run the application
as a privileged migration actor.

### Option B - separately designed bounded migration authority lifecycle

If the hosted platform supports no suitable unchanged path, a new source design
is required. It would have to distinguish entry/final invariants from precisely
bounded, reviewed intermediate authority; this cannot be achieved by an external
GRANT prelude alone because unchanged input assertions reject it. Do not merely
delete guards or weaken the final model. No such source change is authorized here.

A future design must specify:

1. Who creates roles and how automatic creator memberships are handled. PG17's
   bootstrap-granted ADMIN edge may require provider cooperation to remove;
   do not promise customer self-revocation. Leaving it as an exception changes
   the current final trust contract and is not recommended as a silent fix.
2. Exact object allowlists, operator/session context and existing-owner authority;
   narrow, temporary schema CREATE only if needed, never PUBLIC/browser grants.
3. Continuing authority after each transfer. SET-only authority requires explicit
   context planning; inherited authority is more powerful and must be bounded.
   Account for FORCE-RLS data guards in later migrations without disabling RLS.
4. Default-ACL execution context and creator defaults, plus explicit final ACLs.
   A fixed, reviewed transfer procedure would itself be a privileged security
   surface requiring provider-supported installation, strict arguments/no
   arbitrary SQL, transaction scope, audit and guaranteed removal.
5. Same-transaction cleanup, zero final memberships/no executor schema CREATE,
   full unchanged final security assertions, rollback/error/lost-ack behavior
   and continued ability to perform future reviewed maintenance.

This is a candidate architecture, not a claim that ordinary Supabase permissions
can implement it. If no permitted mechanism can meet all conditions, retain HOLD.

### Rejected shortcuts

Do not grant superuser/BYPASSRLS/LOGIN/CREATEROLE to executors, permanently grant
SET/INHERIT/ADMIN paths, keep schema CREATE, alter schema owners to manufacture
CREATE, disable FORCE RLS, use service-role direct data access, expose a general
SECURITY DEFINER DDL runner, bypass assertions, replay recorded migrations,
rename/drop conflicting roles, or repair migration history to claim success.
Retaining an ADMIN-only edge is not harmless: its administrator can arrange
additional grants. It would be a separate security redesign, not A02 acceptance.

## 6. Later migration effects and recovery risks

- P06 (`20261110103000_audit_timezone.sql:9`, `:20`, `:32`) needs audit-table
  lock/read authority and alteration of a data-owner function. After P05,
  ordinary former ownership does not suffice. FORCE RLS must not filter audit
  checks into a misleading empty PASS; no rehash/backfill is authorized.
- P07 (`20261110110000_membership_lifecycle.sql:9`, `:32`, `:60`, `:68`) needs
  locks, full-visibility integrity checks, ALTER on transferred tables and new
  helper ownership. Repairing only P05's first OWNER TO would leave this blocked.
- P08-P10 and P12-P17 create/replace executor-owned routines, add policies or
  transfer new tables. Existing executor-owned functions require proper owner
  authority for CREATE OR REPLACE; CREATE privilege alone is insufficient.
- P11 adds the fourth role and an early FOR ROLE default-ACL operation before
  its new objects. Its verifier hash access remains confined to the trusted
  check-in executor and server-only prepare RPC. Never broaden that access to
  solve migration execution.
- P05 transfers 22 tables/25 routines; later source targets 33 protected tables.
  Preserve identity sequences, dependent index/type ownership, trigger/constraint
  bindings and the final inventory. Do not use REASSIGN OWNED across provider
  objects. New authority must not change ledger, audit, PIN or lifecycle bodies.
- P05/P11 use explicit transactions and 5s lock/120s statement timeouts. P05
  takes ACCESS EXCLUSIVE on 22 tables; P11 on attendance. Refusal rolls back an
  uncommitted transaction, but the operator must prove same-session cleanup;
  earlier committed files remain committed. Do not infer migration-runner
  history atomicity or blindly retry after a lost response.
- Removing required maintenance authority can intentionally prevent future DDL.
  Plan future releases before approval; runtime least privilege remains required.
  A restore is not a permission fix, and no destructive recovery is authorized.

## 7. Required Owner decisions and acceptance

| Gate | Current result | Required decision/evidence |
| --- | --- | --- |
| Standard non-superuser unchanged P05/P11 compatibility | FAIL, source/PG17 rules | Do not approve unchanged customer-role execution based on CREATEROLE alone |
| Actual hosted operator/provider mechanism | UNKNOWN | Owner-private role/config evidence via separately approved diagnostic path; file 04 is a screen, not proof or new execution approval |
| Existing authorized PG17 synthetic target | UNKNOWN/unavailable | Approve a suitable isolated environment/access before testing; no provisioning done here |
| Remediation option and authority contract | HOLD | Choose supported privileged path investigation or separately scoped source design; approve exact scope, intermediate authority and cleanup |
| Full isolated PG17 runner/security/recovery acceptance | UNKNOWN | T01-T11 plus unchanged final assertions; no substitutions from local superuser tests |
| A03 defaults, production drift/data and backup blockers | UNKNOWN/open | Separate evidence and Owner approval; solving A02 does not solve them |
| Production execution, history, deployment | HOLD | Separate final approved plan/window/bytes/operator after all gates pass |

Final acceptance requires NOLOGIN/non-superuser/non-bypass executors, no reserved
role memberships in the final current model, no executor schema CREATE, correct
FORCE RLS and least-privilege table/column/sequence/function policies, api-only
server RPC execution, verified Owner authorization, preserved audit/payment
history, and no unverified access or refunds. The runtime and migration actors
must remain distinct. Owner approval cannot substitute for missing technical proof.

**Final A02 recommendation: NO-GO.** The standard permission contradiction is
confirmed statically; hosted compatibility and PG17 execution remain UNKNOWN.
Stop for Owner review. No production operation or source remediation is authorized
by this report.

## 8. Source operation indexes

The generated indexes below give exact statement-start lines for the reviewed
files. They include all top-level grants/revocations, ownership/security changes,
policies, schema/default privileges and role-creation sites in P05/P11. Multi-line
statements continue in the source; catalog assertion code is discussed above.
There are no ALTER ROLE statements, SET ROLE statements or role-membership
GRANT/REVOKE statements in either migration (or in the other local migrations).
SET LOCAL search_path/timeouts/assertion_profile are settings, not SET ROLE.


### supabase/migrations/20261110100000_executor_hardening.sql

| Operation category | Statement/guard start lines |
| --- | --- |
| Role creation (1) | 19 |
| Role attribute or membership guards (11) | 24, 27, 30, 129, 132, 135, 1232, 1235, 1238, 1946, 1956 |
| Ownership transfers (47) | 827, 831, 835, 839, 843, 847, 851, 855, 859, 863, 867, 871, 875, 879, 883, 887, 891, 895, 899, 903, 907, 911, 1006, 1011, 1016, 1021, 1026, 1031, 1036, 1041, 1046, 1051, 1056, 1061, 1066, 1071, 1076, 1081, 1086, 1091, 1096, 1101, 1106, 1111, 1116, 1121, 1126 |
| Schema privileges (6) | 923, 924, 925, 926, 927, 928 |
| Future defaults (3) | 1135, 1136, 1137 |
| Security mode (25) | 1007, 1012, 1017, 1022, 1027, 1032, 1037, 1042, 1047, 1052, 1057, 1062, 1067, 1072, 1077, 1082, 1087, 1092, 1097, 1102, 1107, 1112, 1117, 1122, 1127 |
| RLS enable/force (44) | 828, 829, 832, 833, 836, 837, 840, 841, 844, 845, 848, 849, 852, 853, 856, 857, 860, 861, 864, 865, 868, 869, 872, 873, 876, 877, 880, 881, 884, 885, 888, 889, 892, 893, 896, 897, 900, 901, 904, 905, 908, 909, 912, 913 |
| Executor policies (34) | 936, 938, 940, 942, 944, 946, 948, 950, 952, 954, 956, 958, 960, 962, 964, 966, 968, 970, 972, 974, 976, 978, 980, 982, 984, 986, 988, 990, 992, 994, 996, 998, 1000, 1002 |
| All explicit grants (including column/function/dependency grants) (64) | 925, 926, 927, 928, 930, 935, 937, 939, 941, 943, 945, 947, 949, 951, 953, 955, 957, 959, 961, 963, 965, 967, 969, 971, 973, 975, 977, 979, 981, 983, 985, 987, 989, 991, 993, 995, 997, 999, 1001, 1010, 1015, 1020, 1025, 1030, 1035, 1040, 1045, 1050, 1055, 1060, 1065, 1070, 1075, 1080, 1085, 1090, 1095, 1100, 1105, 1110, 1115, 1120, 1125, 1130 |
| All explicit revocations (table, sequence, function, schema) (52) | 830, 834, 838, 842, 846, 850, 854, 858, 862, 866, 870, 874, 878, 882, 886, 890, 894, 898, 902, 906, 910, 914, 916, 918, 920, 923, 924, 1009, 1014, 1019, 1024, 1029, 1034, 1039, 1044, 1049, 1054, 1059, 1064, 1069, 1074, 1079, 1084, 1089, 1094, 1099, 1104, 1109, 1114, 1119, 1124, 1129 |

Ownership allowlist (one row per explicit transfer):

| Line | Object and target |
| --- | --- |
| 827 | `ALTER TABLE private.attendance_checkins OWNER TO gym_data_owner` |
| 831 | `ALTER TABLE private.attendance_validity_resolutions OWNER TO gym_data_owner` |
| 835 | `ALTER TABLE private.audit_chain_heads OWNER TO gym_data_owner` |
| 839 | `ALTER TABLE private.audit_events OWNER TO gym_data_owner` |
| 843 | `ALTER TABLE private.cash_drawer_sessions OWNER TO gym_data_owner` |
| 847 | `ALTER TABLE private.cash_reconciliation_adjustments OWNER TO gym_data_owner` |
| 851 | `ALTER TABLE private.cash_reconciliations OWNER TO gym_data_owner` |
| 855 | `ALTER TABLE private.member_pin_credentials OWNER TO gym_data_owner` |
| 859 | `ALTER TABLE private.member_pin_setup_tokens OWNER TO gym_data_owner` |
| 863 | `ALTER TABLE private.members OWNER TO gym_data_owner` |
| 867 | `ALTER TABLE private.membership_plans OWNER TO gym_data_owner` |
| 871 | `ALTER TABLE private.membership_purchases OWNER TO gym_data_owner` |
| 875 | `ALTER TABLE private.owner_access OWNER TO gym_data_owner` |
| 879 | `ALTER TABLE private.payment_allocations OWNER TO gym_data_owner` |
| 883 | `ALTER TABLE private.payment_corrections OWNER TO gym_data_owner` |
| 887 | `ALTER TABLE private.payment_events OWNER TO gym_data_owner` |
| 891 | `ALTER TABLE private.payment_records OWNER TO gym_data_owner` |
| 895 | `ALTER TABLE private.pin_attempt_buckets OWNER TO gym_data_owner` |
| 899 | `ALTER TABLE private.pin_enrollment_global_rate_limit_events OWNER TO gym_data_owner` |
| 903 | `ALTER TABLE private.walkin_fee_versions OWNER TO gym_data_owner` |
| 907 | `ALTER TABLE private.walkin_requests OWNER TO gym_data_owner` |
| 911 | `ALTER TABLE public.gym_settings OWNER TO gym_data_owner` |
| 1006 | `ALTER FUNCTION api.append_audit_event(text, uuid, text, text, text, jsonb) OWNER TO gym_owner_executor` |
| 1011 | `ALTER FUNCTION api.is_active_owner_for_user(uuid) OWNER TO gym_owner_executor` |
| 1016 | `ALTER FUNCTION api.member_enroll_pin(text, text) OWNER TO gym_public_executor` |
| 1021 | `ALTER FUNCTION api.owner_confirm_membership_payment(uuid, uuid, boolean) OWNER TO gym_owner_executor` |
| 1026 | `ALTER FUNCTION api.owner_create_membership_purchase(uuid, uuid, uuid) OWNER TO gym_owner_executor` |
| 1031 | `ALTER FUNCTION api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone) OWNER TO gym_owner_executor` |
| 1036 | `ALTER FUNCTION api.owner_list_members(uuid, text, text, integer, integer) OWNER TO gym_owner_executor` |
| 1041 | `ALTER FUNCTION api.owner_list_membership_payments(uuid, text, text, integer, integer) OWNER TO gym_owner_executor` |
| 1046 | `ALTER FUNCTION api.owner_list_membership_plans(uuid) OWNER TO gym_owner_executor` |
| 1051 | `ALTER FUNCTION api.owner_list_membership_purchases(uuid, text, text, integer, integer) OWNER TO gym_owner_executor` |
| 1056 | `ALTER FUNCTION api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text) OWNER TO gym_owner_executor` |
| 1061 | `ALTER FUNCTION api.owner_register_member(uuid, text, bytea, bytea) OWNER TO gym_owner_executor` |
| 1066 | `ALTER FUNCTION api.owner_reject_membership_payment(uuid, uuid, text) OWNER TO gym_owner_executor` |
| 1071 | `ALTER FUNCTION api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean) OWNER TO gym_owner_executor` |
| 1076 | `ALTER FUNCTION api.reserve_pin_enrollment_request() OWNER TO gym_public_executor` |
| 1081 | `ALTER FUNCTION api.verify_audit_stream(text) OWNER TO gym_owner_executor` |
| 1086 | `ALTER FUNCTION private.audit_events_chain_insert() OWNER TO gym_data_owner` |
| 1091 | `ALTER FUNCTION private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone) OWNER TO gym_data_owner` |
| 1096 | `ALTER FUNCTION private.guard_membership_payment_allocation() OWNER TO gym_data_owner` |
| 1101 | `ALTER FUNCTION private.guard_membership_payment_record_insert() OWNER TO gym_data_owner` |
| 1106 | `ALTER FUNCTION private.guard_membership_payment_record_update() OWNER TO gym_data_owner` |
| 1111 | `ALTER FUNCTION private.guard_purchase_pending_activation() OWNER TO gym_data_owner` |
| 1116 | `ALTER FUNCTION private.is_active_owner() OWNER TO gym_data_owner` |
| 1121 | `ALTER FUNCTION private.prevent_audit_event_mutation() OWNER TO gym_data_owner` |
| 1126 | `ALTER FUNCTION private.prevent_payment_history_mutation() OWNER TO gym_data_owner` |

### supabase/migrations/20261110150000_member_checkin.sql

| Operation category | Statement/guard start lines |
| --- | --- |
| Role creation (1) | 16 |
| Role attribute or membership guards (2) | 31, 33 |
| Ownership transfers (6) | 57, 103, 124, 163, 184, 219 |
| Schema privileges (1) | 37 |
| Future defaults (1) | 38 |
| Security mode (5) | 91, 108, 131, 171, 189 |
| RLS enable/force (2) | 58, 59 |
| Executor policies (12) | 65, 66, 67, 70, 72, 74, 76, 78, 80, 82, 86, 87 |
| All explicit grants (including column/function/dependency grants) (16) | 37, 62, 64, 69, 73, 75, 77, 79, 81, 83, 88, 105, 126, 165, 186, 221 |
| All explicit revocations (table, sequence, function, schema) (7) | 60, 61, 104, 125, 164, 185, 220 |

Ownership allowlist (one row per explicit transfer):

| Line | Object and target |
| --- | --- |
| 57 | `ALTER TABLE private.member_checkin_rate_events OWNER TO gym_data_owner` |
| 103 | `ALTER FUNCTION private.member_checkin_eligible_purchase(uuid,timestamptz) OWNER TO gym_data_owner` |
| 124 | `ALTER FUNCTION private.guard_member_attendance_basis() OWNER TO gym_data_owner` |
| 163 | `ALTER FUNCTION api.reserve_member_checkin_request(text,integer,integer) OWNER TO gym_checkin_executor` |
| 184 | `ALTER FUNCTION api.prepare_member_checkin(text,bytea) OWNER TO gym_checkin_executor` |
| 219 | `ALTER FUNCTION api.commit_member_checkin(uuid,integer) OWNER TO gym_checkin_executor` |

### Related migration authority sites

These are every subsequent local migration with an explicit or dynamic OWNER TO,
role creation or default-privilege statement. Dynamic loops are cited at their
source line and operate on their source allowlist, not on arbitrary objects.
All other local migrations were scanned for these patterns; none adds a SET ROLE,
ALTER ROLE or role-membership grant to bridge the authority gap.

| Migration path | Relevant source lines |
| --- | --- |
| `supabase/migrations/20261110110000_membership_lifecycle.sql` | 68, 86, 145, 167, 209, 249, 297 |
| `supabase/migrations/20261110120000_owner_reporting.sql` | 74, 119 |
| `supabase/migrations/20261110130000_pin_recovery.sql` | 131, 132, 133 |
| `supabase/migrations/20261110140000_walkin_operations.sql` | 45, 68, 110, 161, 186, 211, 231, 257, 285, 308, 394 |
| `supabase/migrations/20261110150000_member_checkin.sql` | 16, 38, 57, 103, 124, 163, 184, 219 |
| `supabase/migrations/20261110153000_owner_attendance.sql` | 47 |
| `supabase/migrations/20261110160000_receipt_review_corrections.sql` | 50, 73, 86, 270, 384 |
| `supabase/migrations/20261110170000_cash_operations.sql` | 26, 63, 147 |
| `supabase/migrations/20261110180000_provisional_claims.sql` | 24, 119 |
| `supabase/migrations/20261110190000_receipt_allocation_review.sql` | 18, 38, 105 |
| `supabase/migrations/20261110200000_operational_reports.sql` | 53, 75 |
