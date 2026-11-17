# A02: Supabase provider compatibility assessment

Prepared 2026-11-16, Asia/Manila. Branch `review/production-recovery`;
baseline `db700c1f42cdf561e3f55d61897ba8eb4948c94e`.
Intended production project: `alxhytivwybjbkjjdsyn` (not connected).

**Decision: NO-GO for unchanged production migrations through the documented
customer execution paths. No suitable provider-operated exception has been
demonstrated.** SQL Editor, a direct postgres connection and CLI migration
transport are not documented superuser execution services. A special supported
provider procedure is UNKNOWN, not established or ruled out by this research.

This research strengthens the earlier conditional Option A assessment: obtain
a precise provider answer before treating it as a viable release strategy.
Do not repeatedly attempt grants or switch tools hoping to acquire authority.

Reviewed `docs/A02-EXECUTOR-HARDENING-REVIEW.md`,
`docs/A02-REMEDIATION-DESIGN.md` and `docs/production-recovery-plan.md`.
Both earlier untracked A02 documents were preserved. Only this report was added.
No production SQL, connection, CLI operation against a project, provisioning,
configuration/role/grant/source change, commit, push, merge or deployment occurred.
Public documentation was researched; no private database metadata was obtained.

## 1. Official evidence and its limits

References were accessed on the preparation date. Claims below concern documented
behavior, not the actual target project's observed role configuration.

### Supabase customer and Dashboard roles

Customer postgres is not a superuser; Supabase permits selected otherwise
restricted operations. These exceptions are not a blanket ownership-transfer
or arbitrary superuser facility. Customer superuser elevation is explicitly
unsupported. [Supabase superuser limitations](https://supabase.com/docs/guides/database/postgres/roles-superuser).

Dashboard SQL executes as postgres. supabase_admin is described as an internal
platform administration role, not a customer migration connection. The elevated
service_role is an API/RLS identity, not proof of database ownership authority.
[Supabase role documentation](https://supabase.com/docs/guides/database/postgres/roles).

### Provider-confirmed membership obstacle

Supabase's PG16+ knowledge-base guidance says custom-role creation gives
postgres an ADMIN membership granted by supabase_admin, with SET/INHERIT off.
Customer postgres cannot remove that provider-granted edge or become
supabase_admin. A revoke may return with a warning while leaving it intact.
Thus command completion alone cannot prove cleanup. This directly conflicts
with GYMFORCE's zero-edge checks when customer postgres creates the roles.
The same guidance describes passwordless CLI access using a temporary login
that belongs to postgres; it does not provide a privileged escape route.
[Supabase membership/grantor guidance](https://supabase.com/kb/troubleshooting/cant-revoke-a-role-membership-granted-by-supabase_admin-d08922).

### CLI and branching are transports, not additional authority

The CLI documents migration application/history recording and a dry-run that
lists proposed migrations. Listing a plan is not execution of permission checks
or a transactional compatibility test. No documented db push option grants
arbitrary superuser authority. [Supabase CLI reference](https://supabase.com/docs/reference/cli/supabase-db-push).

Local installed npm CLI package is **2.122.0**; package.json requests ^2.122.0.
The live reference now describes v3/v4 target-flag changes. Do not copy current
flags into a version-2 runbook or upgrade implicitly. Installed runner behavior
and authenticated effective role must be checked separately in isolation.
Only package metadata was read; the CLI was not invoked.

The branching troubleshooting guide instructs users to check that migrations
do not require superuser privileges; branching is not documented as a way to
obtain elevated execution. No branch was created or reset here.
[Supabase branching migration guidance](https://supabase.com/docs/guides/deployment/branching/troubleshooting).

### supautils does not establish full A02 compatibility

Hosted documentation describes selected configuration exceptions supplied by
supautils. Its upstream README separately describes bounded policy-management
and trigger-drop ownership exceptions. Neither is evidence that hosted customer
postgres can perform all of P05/P11's transfers, remove provider-granted
memberships, change other roles' defaults and pass every assertion. Upstream
features/configuration are not proof of the deployed version or grants.
[Hosted configuration exceptions](https://supabase.com/docs/guides/database/custom-postgres-config),
[Supabase supautils upstream documentation](https://github.com/supabase/supautils#table-ownership-bypass).

Do not install/update/configure extensions or change protected settings to probe
this hypothesis. A policy-only exception would not resolve the other obstacles.

## 2. Required privilege and role-relationship matrix

P05 refers to `supabase/migrations/20261110100000_executor_hardening.sql`;
P11 refers to `supabase/migrations/20261110150000_member_checkin.sql`.
The prior A02 review section 8 indexes every transfer/grant/policy statement.

| Operation / source | Required standard PG17 authority | Conflict with unchanged source / acceptance |
| --- | --- | --- |
| Role creation: P05:19; P11:16 | CREATEROLE or superuser, including permitted attributes | Non-superuser automatic ADMIN edge is rejected at P05:27, :132 and P11:31 |
| Baseline access and locks: P05:35; P11:9 | Suitable relation privileges and access to existing owner objects | Database ownership/CREATEROLE alone is insufficient; P05 expects postgres-owned inputs (:345, :619) |
| 22 P05 table transfers: :827-911 | Existing-owner authority, ability to assume destination and destination-schema CREATE, unless a valid privileged exception applies | Zero memberships and no effective target CREATE at P05:651-655 conflict with ordinary prerequisites |
| 25 P05 function transfers: :1006-1126 | Function ownership plus SET capability and target-schema CREATE, or suitable privileged execution | Same conflict; final API execution identity must remain bounded |
| P11 one table/five function transfers: :57, :103, :124, :163, :184, :219 | Same prerequisites, also for new fourth executor | USAGE granted at :37 is not CREATE; final check at :231-237 rejects CREATE |
| Post-transfer DDL, grants and policies: P05:828-1130; P11:58-88 and routine ACL blocks | Continuing owner or appropriate grant authority | SET-only membership does not automatically inherit privileges as original current_user |
| Extension dependency grant: P05:930 | Grant authority for extensions.digest(bytea,text) | Owning application objects does not prove authority over provider-owned dependencies |
| Default ACLs: P05:1135-1137; P11:38 | Effective authority of target creator role, or suitably privileged execution | ADMIN-only/unswitched SET-only access is insufficient; zero-edge model gives unrelated ordinary actor no path |
| Later data guards: P06 audit :20; P07 lifecycle :32 | Full relevant row visibility plus lock/DDL/function authority | FORCE RLS can filter an ordinary owner; empty filtered data is not a valid integrity PASS |
| Final security | Four restricted NOLOGIN roles, no membership edges, no schema CREATE, narrow ACLs, FORCE RLS | Existing final assertions must remain intact, including P05:1235 and P11:223; no history shortcuts |

PG17 documents the ordinary ownership requirements for
[tables](https://www.postgresql.org/docs/17/sql-altertable.html) and
[functions](https://www.postgresql.org/docs/17/sql-alterfunction.html).
Its [role attributes](https://www.postgresql.org/docs/17/role-attributes.html)
explain creator membership; its
[default privilege rules](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html)
and [upstream ACL implementation](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/catalog/aclchk.c)
distinguish effective owner authority from administration alone.

FORCE RLS constrains ordinary owners, but not superusers/BYPASSRLS roles.
Privilege restrictions and immutable-history triggers are also required because
RLS does not govern every operation. [PG17 row security](https://www.postgresql.org/docs/17/ddl-rowsecurity.html).

## 3. Execution-path assessment

Supported transport does not mean the unchanged migrations are supported by its
SQL identity. FAIL below means a documented/standard authority conflict, not an
observed production execution failure.

| Path | Documented capability | A02 classification |
| --- | --- | --- |
| SQL Editor | Customer postgres executes SQL | FAIL under documented role-creation model; no documented elevation satisfying unchanged sequence |
| Direct psql/customer postgres | Direct SQL under that database role | FAIL for the same standard conflicts; bypassing a pooler does not elevate privileges |
| CLI with database credentials | Applies migrations with a database connection | FAIL for ordinary postgres authority; exact runner/session context still UNKNOWN |
| Passwordless CLI temporary login | Temporary postgres-related access, managed separately from application executors | No demonstrated extra authority; actual context UNKNOWN; not a solution to A02 |
| GitHub CI or hosted branch migration | Automates deployment/migration tasks | No documented superuser entitlement; authority must be proven separately; no provisioning here |
| service_role / Edge / PostgREST | Calls permitted server RPCs; elevated RLS behavior | UNSUITABLE: not a general ownership/role-administration channel; direct protected data access is forbidden by this project |
| supautils selected exceptions | Particular configured operations | UNKNOWN for the installed instance; no documented complete A02 solution |
| Customer SET ROLE to supabase_admin / customer superuser grant | No documented supported entitlement | UNSUPPORTED; do not attempt |
| Special provider-operated release procedure (design Option A) | Not established by the reviewed public documentation | UNKNOWN; cannot schedule or claim compatibility without specific written confirmation and rehearsal |
| Local true-superuser PG17 | Can bypass ordinary checks | Isolated engine control only; not proof of hosted availability or caller security |

Temporary CLI-login infrastructure is distinct from the four application roles.
Do not delete provider-managed roles as cleanup. The dedicated official guidance
describes permission restrictions on deleting these logins; use a supported
Owner/provider process if such access must be closed, and verify the result.
[Supabase CLI-login cleanup guidance](https://supabase.com/kb/troubleshooting/permission-denied-when-deleting-the-cli_login_postgres-role-808bae).

## 4. Minimal read-only diagnostic proposal - NOT EXECUTED

Existing `docs/production-preflight/04-migration-authority.sql` remains unchanged
and on hold, together with scripts 03-07. Neither this report nor earlier approval
of scripts 01/02 authorizes file 04 or the draft below. Obtain explicit Owner
review/approval for exact SQL, target and execution path before using them.

The Owner confirms the project in the Dashboard/connection configuration without
sharing credentials. SQL current_user does not prove a Supabase project ref.
Use the exact intended migration identity/session path; SQL Editor results do
not certify a CLI identity. Do not start a passwordless CLI login merely for
read-only discovery if doing so creates a role: that is an additional mutation
outside this task. Use an already approved connection or mark that path UNKNOWN.

The following optional draft consolidates minimal context, target-role edges,
schema transfer prerequisites and owner-authority counts into one SELECT result.
It reads catalogs only, with explicit read-only transaction and rollback. It
returns no function bodies, policy expressions, password catalogs or business
records. Full output is still private security metadata, including actor names.

```sql
-- DRAFT FOR OWNER REVIEW ONLY. No execution authorized by this report.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '15s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path = pg_catalog;
WITH wanted(name) AS (VALUES
 ('gym_data_owner'), ('gym_owner_executor'),
 ('gym_public_executor'), ('gym_checkin_executor')
), targets AS (
 SELECT w.name, r.oid, r.rolcanlogin, r.rolsuper, r.rolcreatedb,
        r.rolcreaterole, r.rolinherit, r.rolreplication, r.rolbypassrls
 FROM wanted w LEFT JOIN pg_catalog.pg_roles r ON r.rolname = w.name
), role_checks AS (
 SELECT t.name, t.oid IS NOT NULL AS exists,
        CASE WHEN t.oid IS NULL THEN NULL ELSE
         NOT(t.rolcanlogin OR t.rolsuper OR t.rolcreatedb OR t.rolcreaterole
          OR t.rolinherit OR t.rolreplication OR t.rolbypassrls)
        END AS restricted_attributes,
        CASE WHEN t.oid IS NULL THEN NULL ELSE
         pg_catalog.pg_has_role(current_user,t.oid,'SET') END AS actor_can_set,
        CASE WHEN t.oid IS NULL THEN NULL ELSE
         pg_catalog.pg_has_role(current_user,t.oid,'USAGE') END AS actor_inherits,
        (SELECT count(*) FROM pg_catalog.pg_auth_members m
         WHERE m.roleid=t.oid OR m.member=t.oid) AS membership_edges,
        (SELECT count(*) FROM pg_catalog.pg_auth_members m
         JOIN pg_catalog.pg_roles g ON g.oid=m.grantor
         WHERE (m.roleid=t.oid OR m.member=t.oid) AND g.rolsuper)
         AS superuser_granted_edges
 FROM targets t
), schema_checks AS (
 SELECT t.name AS target_owner, s.name AS schema_name,
        n.oid IS NOT NULL AS schema_exists,
        CASE WHEN t.oid IS NULL OR n.oid IS NULL THEN NULL ELSE
         pg_catalog.has_schema_privilege(t.oid,n.oid,'CREATE') END AS can_create
 FROM targets t CROSS JOIN (VALUES ('private'),('api'),('public')) s(name)
 LEFT JOIN pg_catalog.pg_namespace n ON n.nspname=s.name
), owner_checks AS (
 SELECT 'relations'::text AS kind, count(*) AS inventoried,
        count(*) FILTER (WHERE NOT pg_catalog.pg_has_role(
         current_user,c.relowner,'USAGE')) AS lacking_owner_authority
 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind IN ('r','p','S') AND
  (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings'))
 UNION ALL
 SELECT 'routines', count(*), count(*) FILTER (WHERE NOT
  pg_catalog.pg_has_role(current_user,p.proowner,'USAGE'))
 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname IN ('api','private')
)
SELECT pg_catalog.jsonb_build_object(
 'context', (SELECT pg_catalog.jsonb_build_object(
  'effective_role',current_user,'session_role',session_user,
  'postgres_version',pg_catalog.current_setting('server_version_num'),
  'read_only',pg_catalog.current_setting('transaction_read_only'),
  'superuser',r.rolsuper,'createrole',r.rolcreaterole,'bypassrls',r.rolbypassrls,
  'createrole_self_grant',pg_catalog.current_setting('createrole_self_grant',true))
  FROM pg_catalog.pg_roles r WHERE r.rolname=current_user),
 'reserved_roles', (SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)
  ORDER BY x.name) FROM role_checks x),
 'schema_checks', (SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)
  ORDER BY x.target_owner,x.schema_name) FROM schema_checks x),
 'owner_checks', (SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x)
  ORDER BY x.kind) FROM owner_checks x)
) AS private_authority_screen;
ROLLBACK;
```

Expected shape: one JSON cell, four reserved-role entries, twelve schema checks,
two owner-summary entries, and one actor-context object. This describes shape,
not predicted hosted values. A missing role has exists=false and NULL authority
flags; zero counted edges for that missing role is not clean-role acceptance.
Zero inventoried objects is not proof of access. Owner-authority counts do not
prove row visibility, privileges to create objects or provider execution behavior.

Run the entire reviewed unit and retain ROLLBACK. Stop on unexpected errors;
close/rollback the same session and confirm closure, not a new editor session.
If the Editor hides the result, use an already approved stable read-only client
path that returns the result; do not omit rollback or leave a transaction open.
Catalog locks are bounded by the timeouts; no user-table scans are requested.
Missing permission/unsupported version/absent prerequisite means UNKNOWN, not PASS.

Only if the screen identifies an edge whose cleanup matters, request a separately
reviewed catalog query for its grantor and ADMIN/SET/INHERIT options, kept entirely
Owner-private. The screen deliberately omits raw unknown role names and ACL grids.
Do not test cleanup with REVOKE, SET ROLE, DDL or a rollback-wrapped mutation in
production. No diagnostic, including file 04, proves actual DDL compatibility.

## 5. Unverified assumptions to resolve

1. Actual PG17 patch, effective/session operator and inherited privileges, any
   CLI-specific identity, existing reserved roles and all grantor/options edges.
2. Exact hosted baseline/object definitions, owners, creator default ACLs,
   extension grant authority and full-visibility data guards. Aggregate markers
   and enabled RLS do not settle these.
3. Whether Supabase offers a supported narrowly scoped operator procedure for
   these exact operations without customer superuser or lasting role edges;
   availability on the approved plan and any cost remain UNKNOWN.
4. Whether such a procedure accepts unchanged SQL and preserves transaction,
   logging, file hashes, role restrictions and actual runner/history behavior.
5. Whether provider-specific exceptions alter relevant standard semantics in
   the deployed image; upstream README features alone are insufficient evidence.
6. Recovery/backup capability, live data blockers, lock budget and next-release
   maintenance authority. No financial or audit repair is implicitly approved.

For a future Owner-approved provider inquiry, supply only sanitized SQL operation
categories and final invariants. Ask whether the exact automatic memberships can
be avoided/removed, all ownership/default operations supported, final zero-edge
state preserved, and isolated rehearsal offered. Do not send secrets, record
exports or full private catalog grids. No support message was sent here.

## 6. Isolated PG17 validation procedure - all runtime results UNKNOWN

No suitable authorized PG17 target was established in prior discovery. Do not
substitute historical PG18 superuser PASS or provision a resource automatically.
After separate approval, use synthetic objects/records only and match provider
image/extensions, actual actor/session path and pinned runner where possible.

| Step | Test | Acceptance |
| --- | --- | --- |
| I1 | Guard target/version/run ID, pin source hashes and runner; use real non-superuser login | Stable known isolated identity; no production/network fallback |
| I2 | Create synthetic restricted role as ordinary CREATEROLE; inspect all edge grantors/options | Demonstrate automatic membership and unchanged P05/P11 refusal; no waived assertions |
| I3 | Precreate clean roles via isolated trusted admin; test OWNER TO separately with missing SET, target CREATE and old-owner authority | All deficient cases refuse; the complete ordinary prerequisite case succeeds only in a diagnostic fixture |
| I4 | Test post-transfer ALTER/RLS/policies/grants and FOR ROLE defaults using ADMIN-only, SET-only and effective-owner contexts | Distinguish transfer authority from continuing authority and default-ACL rights |
| I5 | Reproduce approved provider mechanism, if one is confirmed; apply unchanged baseline/P01-P17 | All stage and final assertions pass with exact bytes; actual provider path also needs provider-equivalent rehearsal |
| I6 | If fallback revised design is approved later, test its bounded authority and same-transaction cleanup independently | No grants outside allowlist; zero final membership/CREATE leaks; never label revised SQL as unchanged acceptance |
| I7 | Inject controlled failures after role creation/grants/transfers, before cleanup/commit; force timeout/disconnect and lost acknowledgement | Prove rollback, lock/session closure, final graph and earlier-commit state; establish history outcome before retry |
| I8 | Fresh-session checks of migrator, anon/authenticated/service roles and non-Owner Auth identity; actual business/race suites | Intended narrow positives; direct data/privileged RPC and role-assumption denials; payment/audit/check-in rules preserved |
| I9 | Close operator access and verify effective grants, membership paths, provider-job status and next-maintenance procedure | No unapproved residual access or helper; no ad hoc provider-role deletion |

Use `supabase/tests/executor_hardening_assertions.sql` at the P05 checkpoint,
`supabase/tests/member_checkin_behavior.sql` after its prerequisites and
`supabase/tests/final_security_assertions.sql` at final state. Historical
ADMIN-only exceptions and temporary-grant probes are not current acceptance.
Do not nest original files' BEGIN/COMMIT inside a supposed rollback dry run.

## 7. Security/cleanup acceptance and next decision

PASS requires every final reserved role to retain all restricted attributes,
zero incoming/outgoing memberships, no effective schema CREATE, correct
owners/FORCE RLS and narrow column/table/sequence/routine privileges. Verify
creator/global/schema default effects, overloads and provider dependencies.
Keep private tables unexposed and privileged RPCs server-only. Preserve all
financial/audit originals and finalized GYMFORCE business rules.

For an approved temporary-authority design, revoke the exact temporary grants
and edges with legitimate grantor authority before commit, reset role context,
verify effective access and the complete graph, then run unchanged final
assertions. Check the resulting catalog: successful-looking commands alone are
not acceptance. If a grant cannot be revoked, abort; do not add a permanent
exception. A privileged operator's RLS bypass must not be credited as runtime
caller security. Close access via supported processes; no generic DDL helper,
customer elevation, trigger/RLS disabling or history repair is acceptable.

| Decision gate | Status |
| --- | --- |
| Official documentation establishes customer postgres restrictions | PASS, documentary evidence |
| Documented customer paths satisfy unchanged source | FAIL under documented/standard model |
| Special supported provider mechanism | UNKNOWN; none demonstrated by reviewed documentation |
| Actual hosted authority screen | UNKNOWN / NOT RUN |
| Isolated PG17 positive/refusal/cleanup/runner tests | UNKNOWN / NOT RUN |
| Production changes | NO-GO |

**Safest next decision:** retain HOLD. Owner may separately authorize a narrowly
worded provider capability inquiry and review of the proposed diagnostic SQL.
If no supported mechanism is confirmed, stop pursuing unchanged execution and
request a separately scoped redesign under actual hosted constraints. The prior
Option B is also conditional; a customer-only design leaving bootstrap ADMIN
edges cannot satisfy the present zero-edge contract. If that contract cannot
be implemented on the platform, surface the architectural incompatibility for
Owner decision rather than silently weakening security or assuming a paid
service/new platform is approved.

This report ends the research task. No diagnostic execution, source implementation,
production apply, provisioning, commit, push, merge or deployment follows.

Local static verification: the existing cached PG17 parser accepted the draft's
six top-level statements (BEGIN, three SET LOCAL statements, SELECT, ROLLBACK).
Its SELECT AST contains only allowlisted catalog/CTE reads and builtin functions;
no SELECT INTO, locking clause or nested mutation was found. This is syntax/AST
validation, not database execution, catalog resolution or hosted compatibility.
Document references/line bounds/whitespace checks passed; tracked files and the
Git index remain unchanged. Only this report was added during the task.
