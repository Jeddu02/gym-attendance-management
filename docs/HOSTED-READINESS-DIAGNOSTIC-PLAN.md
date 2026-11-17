# GYMFORCE hosted readiness diagnostic plan

Prepared 2026-11-17. Intended project `alxhytivwybjbkjjdsyn`.
**REVIEW COPY. No hosted execution authorized or performed.** Use with the
[approval form](HOSTED-READINESS-OWNER-APPROVAL.md) and
[decision matrix](HOSTED-READINESS-DECISION-MATRIX.md). Only these three new
documents are written in this task; existing SQL, migrations and tools are preserved.

## 1. Execution and evidence rules

Owner confirms project in the Dashboard/approved connection configuration;
catalog SQL cannot prove the project reference. Use an existing approved
connection, not a passwordless CLI path that creates a login. H01 identity must
be observed through the same intended operator/client path. SQL Editor commonly
executes as postgres, but a result there does not certify another CLI session.
[Official role documentation](https://supabase.com/docs/guides/database/postgres/roles).

Every proposed SQL unit retains explicit REPEATABLE READ READ ONLY, 30s statement
and 2s lock limits, pg_catalog search path and ROLLBACK. No production SQL is
executed to validate this package. New blocks H01-H03 are complete standalone
units; select/copy their entire block only after exact-byte approval. They return
one result set each. Existing files are run separately, unchanged, only if named
in the approval. Do not concatenate files or wrap transaction-owning files in an
outer transaction. Do not run a selected SELECT without its wrapper.

If SQL Editor hides results or exposes only the last SELECT, use an already
approved Owner-controlled client supporting complete results and same-session
transaction closure. In particular, registration-plan-cash.sql has two SELECTs;
the first result must not be discarded. Do not remove ROLLBACK, assume a later
editor click shares the backend, or install a client/change access without approval.

On any error/timeout/truncation/cancellation, stop dependent work, mark UNKNOWN,
rollback/close that actual session and confirm lock release privately. No grants,
new roles, temporary policies, RLS changes, schema changes or longer timeouts to
make a diagnostic run. Missing tables/columns/types/roles are explicit prerequisites,
not permission to create them. Different files use different snapshots: record
UTC times/actor/stage and revalidate only under approved conditions if state changes.

Full security metadata is Owner-private. Share sanitized labels/status/counts and
approved source object identifiers only. No credentials, raw function bodies,
policy expressions, member/payment/audit rows, PIN verifiers/tokens or full errors.
Even zero/boolean business results are confidential. Identifier names/arguments
and OIDs may reveal internal structure; do not publish grids or commit exports.

## 2. Ordered approved-candidate inventory and output contracts

All statuses below are proposed workflow expectations, not production findings.
Original preflight 03-07 remain held; equivalent recovery copies also need their
own approval. Existing 01/02 authorization does not automatically authorize their
split variants, new blocks, or every file in a directory.

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

No proposal SQL, migration/compatibility variant, assertion SQL or test fixture is
a diagnostic. Exclude both `proposals/*.sql`, all 13 compatibility migration
variants, `supabase/tests/*`, maintenance-rls-proof.sql and history-fixture.sql.
The last two mutate synthetic objects despite their verification names.

## 3. Exact standalone supplements for Owner review

### H01 — existing operator context (metadata authorization)

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
SELECT jsonb_build_object(
 'serverVersion',current_setting('server_version'),
 'serverVersionNum',current_setting('server_version_num'),
 'readOnly',current_setting('transaction_read_only'),
 'observedAtUtc',to_char(clock_timestamp() AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS'),
 'sessionIsPostgres',session_user='postgres',
 'effectiveIsPostgres',current_user='postgres',
 'sameSessionRole',session_user=current_user,
 'actorFlags',(SELECT jsonb_build_object('superuser',rolsuper,'createRole',rolcreaterole,
  'bypassRls',rolbypassrls,'inherit',rolinherit) FROM pg_roles WHERE rolname=current_user),
 'decision','CONTEXT_ONLY_NOT_HOSTED_AUTHORITY_PROOF') AS context;
ROLLBACK;
```

### H02 — inherited graph, creator defaults and routine security (metadata authorization)

No application function bodies or policy/default expressions are returned.
The recursive graph follows membership edges without assuming INHERIT/SET;
flags are returned for private interpretation. Effective permissions still need
the separate has_* screens. Unknown role names are suppressed; OIDs link their
creator/grantee/member records without exporting potential user-identifying names.
Provider/global default entries are evidence, not an automatic revoke list.

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
WITH RECURSIVE wanted(name) AS (VALUES
 ('anon'),('authenticated'),('service_role'),('postgres'),('gym_data_owner'),
 ('gym_owner_executor'),('gym_public_executor'),('gym_checkin_executor')
), callers AS (
 SELECT w.name,r.oid FROM wanted w LEFT JOIN pg_roles r ON r.rolname=w.name
), reach(root,role_oid) AS (
 SELECT oid,oid FROM callers WHERE oid IS NOT NULL
 UNION
 SELECT q.root,m.roleid FROM reach q JOIN pg_auth_members m ON m.member=q.role_oid
), creators AS (
 SELECT proowner AS oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname IN ('api','private')
 UNION SELECT c.relowner FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('api','private') OR (n.nspname='public' AND c.relname='gym_settings')
 UNION SELECT d.defaclrole FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace
 WHERE d.defaclnamespace=0 OR n.nspname IN ('api','private','public')
 UNION SELECT oid FROM pg_roles WHERE rolname IN ('postgres',current_user)
), defaults AS (
 SELECT c.oid AS creator,'GLOBAL'::text AS scope,'f'::"char" AS kind,
  COALESCE(d.defaclacl,acldefault('f',c.oid)) AS acl,d.oid IS NULL AS implicit
 FROM creators c LEFT JOIN pg_default_acl d
 ON d.defaclrole=c.oid AND d.defaclnamespace=0 AND d.defaclobjtype='f'
 UNION ALL
 SELECT d.defaclrole,COALESCE(n.nspname::text,'GLOBAL'),d.defaclobjtype,d.defaclacl,false
 FROM pg_default_acl d JOIN creators c ON c.oid=d.defaclrole
 LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace
 WHERE (d.defaclnamespace=0 OR n.nspname IN ('api','private','public'))
 AND NOT(d.defaclnamespace=0 AND d.defaclobjtype='f')
), labels AS (
 SELECT r.oid,CASE WHEN r.rolname IN (SELECT name FROM wanted)
  OR r.rolname='supabase_admin' THEN r.rolname ELSE 'OTHER_ROLE' END AS label FROM pg_roles r
)
SELECT jsonb_build_object(
 'requiredRoles',(SELECT jsonb_agg(jsonb_build_object('role',name,'present',oid IS NOT NULL) ORDER BY name) FROM callers),
 'creators',(SELECT jsonb_agg(jsonb_build_object('oid',c.oid,'label',l.label) ORDER BY c.oid)
  FROM creators c LEFT JOIN labels l ON l.oid=c.oid),
 'reachableMemberships',(SELECT COALESCE(jsonb_agg(to_jsonb(e) ORDER BY e.member,e.roleid,e.grantor),'[]'::jsonb)
  FROM (SELECT DISTINCT m.member,ml.label AS member_label,m.roleid,rl.label AS role_label,
   m.grantor,gl.label AS grantor_label,m.admin_option,m.inherit_option,m.set_option
   FROM pg_auth_members m JOIN reach q ON q.role_oid=m.member
   LEFT JOIN labels ml ON ml.oid=m.member LEFT JOIN labels rl ON rl.oid=m.roleid
   LEFT JOIN labels gl ON gl.oid=m.grantor) e),
 'defaultAcl',(SELECT COALESCE(jsonb_agg(to_jsonb(a) ORDER BY a.creator,a.scope,a.kind,a.grantee),'[]'::jsonb)
  FROM (SELECT d.creator,cl.label AS creator_label,d.scope,d.kind,d.implicit,
   x.grantee,CASE WHEN x.grantee=0 THEN 'PUBLIC' ELSE gl.label END AS grantee_label,
   x.privilege_type,x.is_grantable FROM defaults d
   CROSS JOIN LATERAL aclexplode(d.acl) x LEFT JOIN labels cl ON cl.oid=d.creator
   LEFT JOIN labels gl ON gl.oid=x.grantee) a),
 'routines',(SELECT COALESCE(jsonb_agg(to_jsonb(a) ORDER BY a.schema_name,a.routine,a.identity_arguments),'[]'::jsonb)
  FROM (SELECT n.nspname AS schema_name,p.proname AS routine,
   pg_get_function_identity_arguments(p.oid) AS identity_arguments,p.prokind AS kind,
   p.proowner AS owner_oid,l.label AS owner_label,p.prosecdef AS security_definer,
   r.rolsuper AS owner_superuser,r.rolbypassrls AS owner_bypass,
   COALESCE(p.proconfig @> ARRAY['search_path=""']::text[],false) AS empty_search_path,
   COALESCE(p.proconfig @> ARRAY['TimeZone=UTC']::text[],false) AS explicit_utc
   FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   LEFT JOIN labels l ON l.oid=p.proowner LEFT JOIN pg_roles r ON r.oid=p.proowner
   WHERE n.nspname IN ('api','private')) a),
 'decision','PRIVATE_METADATA_REVIEW_REQUIRED_NOT_SECURITY_CERTIFICATION') AS security;
ROLLBACK;
```

Interpretation: missing expected roles, non-function routine kinds, unexpected
definer owner/search path/ACL or unknown creator/grantee chains are HOLD items.
Do not call a function merely because its catalog metadata says EXECUTE=true.
Caller EXECUTE plus schema USAGE and SQL authorization must all match the actual
stage. Implicit global PUBLIC function EXECUTE is explicitly inventoried even
with no pg_default_acl row. Schema defaults add to global defaults; reassignment
of owner does not change which creator's defaults applied. H02 does not certify
implicit defaults for every non-function object class; inspect the existing
catalog/type/sequence/data permissions and private follow-up if such exposure is
suspected. No broad provider-wide default correction is proposed.

### H03 — baseline finance and attendance (data authorization, prerequisite-gated)

Confirm baseline columns/types before approval:
payment_allocations(payment_id,membership_purchase_id,walkin_request_id),
payment_records(id,verification_status,amount_php),
attendance_checkins(member_id,walkin_request_id,gym_local_date,checked_in_at,attendance_status),
walkin_requests(id,request_status,fee_php,currency).
No operation_id, target_membership_purchase_id, membership_purchase_id attendance
column or requested_payment_method is required. These seven checks complement,
not replace, lifecycle/receipt-void/final allocation review. A valid member's
actual eligibility cannot be inferred without the later basis and financial data.

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
WITH visibility AS (
 SELECT count(*)=4 AND bool_and(has_table_privilege(current_user,c.oid,'SELECT')
  AND NOT row_security_active(c.oid)) AS complete
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' AND c.relkind IN ('r','p') AND c.relname IN
 ('payment_allocations','payment_records','attendance_checkins','walkin_requests')
), checks(check_name,ok) AS (VALUES
 ('receipt_allocation_once',NOT EXISTS(SELECT 1 FROM private.payment_allocations GROUP BY payment_id HAVING count(*)>1)),
 ('membership_allocation_once',NOT EXISTS(SELECT 1 FROM private.payment_allocations WHERE membership_purchase_id IS NOT NULL GROUP BY membership_purchase_id HAVING count(*)>1)),
 ('walkin_allocation_once',NOT EXISTS(SELECT 1 FROM private.payment_allocations WHERE walkin_request_id IS NOT NULL GROUP BY walkin_request_id HAVING count(*)>1)),
 ('one_valid_daily_member_checkin',NOT EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id IS NOT NULL AND attendance_status='valid' GROUP BY member_id,gym_local_date HAVING count(*)>1)),
 ('walkin_attendance_once',NOT EXISTS(SELECT 1 FROM private.attendance_checkins WHERE walkin_request_id IS NOT NULL GROUP BY walkin_request_id HAVING count(*)>1)),
 ('valid_walkin_confirmed_exact_basis',NOT EXISTS(
   SELECT 1 FROM private.attendance_checkins a WHERE a.walkin_request_id IS NOT NULL AND a.attendance_status='valid'
   AND NOT EXISTS(SELECT 1 FROM private.walkin_requests w
    JOIN private.payment_allocations x ON x.walkin_request_id=w.id
    JOIN private.payment_records p ON p.id=x.payment_id
    WHERE w.id=a.walkin_request_id AND w.request_status='confirmed' AND w.currency='PHP'
    AND p.verification_status='confirmed' AND p.amount_php=w.fee_php))),
 ('stored_day_matches_manila_timestamp',NOT EXISTS(SELECT 1 FROM private.attendance_checkins
   WHERE gym_local_date IS DISTINCT FROM (checked_in_at AT TIME ZONE 'Asia/Manila')::date))
)
SELECT jsonb_agg(jsonb_build_object('check_name',check_name,'result',
 CASE WHEN v.complete IS DISTINCT FROM true THEN 'UNKNOWN' WHEN ok THEN 'PASS' ELSE 'FAIL' END)
 ORDER BY check_name) AS baseline_checks FROM checks CROSS JOIN visibility v;
ROLLBACK;
```

FAIL means private basis/definition review; the timestamp/date comparison is an
investigative anomaly screen, not automatic correction. Never retrofit the new
15-minute lifetime or fee/method/basis onto old rows, revive expired walk-ins,
delete duplicate financial history, restore invalidated attendance automatically,
or infer confirmation from a recorded receipt. Pending/unallocated/void money
must remain distinct from confirmed income and eligibility.

## 4. A07: exact partial-marker identification and stage reconciliation

1. Refresh version history privately and compare with the supplied 20-version
   prefix using `node scripts/recovery/compare-history.mjs <private-history.json>`.
   Shell placeholders are not literal commands. Applied version numbers do not
   certify applied SQL bytes. New gaps/unknown versions/history mismatch => STOP.
2. Owner runs the approved MARKERS file and keeps all 91 result rows privately.
   Filter its displayed result offline for history_recorded=false and
   object_present=true. Record **each tuple** (version,kind,object_name,column_name)
   and observation; do not merge repeated routine-name occurrences into three
   distinct objects. If current counts differ from historical 88/3, retain both
   observation times and investigate; do not force the old count.
3. For each present routine, use SPLIT01 routine inventory to identify every
   exact overload/signature, kind, return, owner/config and effective/explicit
   ACL, then its private catalog fingerprint. Function-name presence alone is
   insufficient. For columns/relations, match type/default/constraints/indexes/
   triggers/policies/owners/RLS and dependencies to the source stage.
4. Classification ledger per tuple: ABSENT, PRESENT-EXACT,
   PRESENT-OLDER-COMPATIBLE, PRESENT-INCOMPATIBLE or UNKNOWN; each with reference
   version/artifact hash, stage, dependency result and observation timestamp.
   Exact object identity is not a declaration that its migration is applied.
5. Cover unmarked effects too: P05 hardening and P06 audit timezone have no
   declaration markers; indexes, grants, default ACLs, roles, constraints,
   policies and replacements require full catalog/source review. Some baseline
   routines share pending marker names; do not infer new implementation presence.
6. Compare only trusted PG17 same-stage references with explicit original versus
   revised execution profile/source manifests. Native synthetic provider/schema
   differences are not evidence of production drift by themselves and cannot be
   normalized away to declare equality. Exact privately reviewed definitions and
   a supported hosted-equivalent reference are needed for final acceptance.

Offline tools (never connect): `scripts/recovery/compare-catalog.mjs` reports
EXACT_METADATA/ABSENT/PRESENT_DIFFERENT/UNEXPECTED while retaining HOLD and
NOT_VERIFIED history/data/authority. `scripts/recovery/plan-checks.mjs` returns
READY_FOR_OWNER_REVIEW only for present, readable, unfiltered prerequisite columns.
Use the intended next migration version, e.g. 20261103120000 for pre-P04 planning;
later conditional screens remain UNKNOWN until their inputs actually exist.
No planner status grants execution approval.

Pre-stage diagnostics are not permanent health checks: dated payment_review may
be legitimate retained history after P13, and legacy NULL bases may be deliberately
preserved. Interpret against the actual intended P01-P17 order, not final-state
assumptions or missing-history arithmetic. Partial/manual installs require a
separate reviewed reconciliation design; no automatic replay, destructive
deduplication, changed migration bytes or mark-applied shortcut is authorized.

## 5. Read-only, privacy, cost and coverage review

| Unit | Read-only/sensitive behavior | Failure or load considerations |
| --- | --- | --- |
| H01/H02, history, split inventories, authority/effective/legacy metadata | Transaction-local settings and catalog SELECTs only; no application RPC. H02 suppresses unknown role names. Full outputs still private. | Missing schema/role/privilege/version, unusual catalog objects, result truncation => UNKNOWN. Recursive graph/catalog scans can grow; 30s/2s limits remain. |
| catalog.sql | Built-in pg_get_* definitions/ACLs/expressions used internally then SHA-256; only fingerprints and metadata returned. | Not a complete pg_depend/effective security proof. Custom metadata may contain sensitive identifiers. Finite fingerprints are not authenticity signatures. |
| H03, registration, lifecycle, additional | Read business rows internally, emit only named statuses. Existing additional file uses a read-only DO block solely to check visibility and raise errors; no DDL/RPC. | No hidden mutations identified. Missing prerequisites/permission errors mean UNKNOWN; full scans/grouping/overlap joins may be expensive. |
| audit.sql | Recomputes version-1 UTC hash internally with built-ins; no verifier/append function, hash writes or stream IDs returned. | Materialized event scan/window/sort can be expensive. PASS establishes internal consistency under this contract, not independent proof against an authorized rewriter or external anchoring. |

No query requests row/advisory/exclusive locks, EXPLAIN ANALYZE, SET ROLE or
persistent SET. Ordinary catalog reads and data AccessShare locks can wait behind
DDL or briefly delay it. Read-only does not mean zero load or zero external
platform query logging. Run one at a time in an approved quiet window. Stop on
timeouts; rescheduling/revised queries need review, not automatic timeout growth.

Unknown grantees or policy meanings may require a further Owner-private review;
this package does not export bodies or policy constants to resolve them. Read-only
catalog evidence cannot prove DDL permissions, future cleanup, actual JWT/RPC
authorization or all dynamic dependencies. Those need approved isolated tests.

### Sanitized result handoff

```text
Check ID / exact source SHA-256 / UTC observation:
Target and actual actor/client privately confirmed: PASS / FAIL / UNKNOWN
Intended source stage and prerequisites: ...
Complete untruncated result and same-session transaction closure: ...
Outcome: PASS / FAIL / UNKNOWN, narrow check labels only
Marker tuple/source identifiers and classification counts (if approved): ...
Private evidence custodian/reference (no uploaded grid): ...
Error: sanitized SQLSTATE/category only
Next decision: PROCEED NAMED DIAGNOSTIC / STOP / OWNER SUPPORT INQUIRY
```

## 6. Exact source-byte inventory and static validation

The table below pins proposed existing SQL, not proof of production execution.
H01-H03 block hashes are listed separately. Changed bytes require renewed review.
SQL is approved by exact file/block and actor, not by filename alone. Any local
hash or read-only AST PASS remains distinct from hosted execution approval.

| SQL file or embedded block | SHA-256 |
| --- | --- |
| `docs/production-preflight/sql-editor/01-01-identity.sql` | `ec2ae5068417de800407c4fc3a4b6c42a3b81d9343a224a48dc12d28ae142f18` |
| `docs/production-preflight/sql-editor/01-02-migration-history.sql` | `0f68ecadba3b65beb5107a8497e76973de276d58ae0e503ee0f2abfbb906e5a2` |
| `docs/production-preflight/sql-editor/01-03-schemas.sql` | `accea708dec33e38eea1673b79ff3c21cd96c5d31833fbad50444840eb89ec04` |
| `docs/production-preflight/sql-editor/01-04-routines.sql` | `50d815a047c48f35d5001f0a825ce679bc6ebf874ea31cd11905d494a062bbbc` |
| `docs/production-preflight/sql-editor/01-05-routine-acls.sql` | `c2e4359b1c6dfb1f800c8e8d0dc22ab7fbde935358ace1ea7a8af2e26ad28e0a` |
| `docs/production-preflight/sql-editor/01-06-routine-permissions.sql` | `2c140b40743119cd219595d5dbc7afb3a0f91ad6c28e95dfdccc01ccd3a6f76f` |
| `docs/production-preflight/sql-editor/01-07-schema-permissions.sql` | `ead08012da6869e6878d30b7d011b5a7fccb6d05fa44bd1edc98e275c33e8c8d` |
| `docs/production-preflight/sql-editor/01-08-default-acls.sql` | `694c079db19c118793d726c0abd458a73b3ca56fd1672ae1ae863927130cb008` |
| `docs/production-preflight/sql-editor/01-09-table-rls.sql` | `8144c90e46ee7763df79aa2b06b1fc2e142f1496863126eef3b1241ee93255d1` |
| `docs/production-preflight/sql-editor/01-10-table-permissions.sql` | `b37dfc50a9bbf51a9c946563176466ab35b0871f63f1b1d0a04c4b1159d0e7d3` |
| `docs/production-preflight/sql-editor/01-11-policies.sql` | `077a49111cbe6579f08803d8281d37872423cd33e1251249624337ff4481da86` |
| `docs/production-preflight/sql-editor/01-12-columns.sql` | `4fc5cfa7c15d7c750474a61896d75e8062d931d87b5f8bd93f6192f28bd25038` |
| `docs/production-preflight/sql-editor/01-13-triggers.sql` | `372743b4fc21ac68b2ab006c3b05ada592b61916db6f5b13e5070a6c5fe078fe` |
| `docs/production-preflight/sql-editor/01-14-constraints.sql` | `81e3ba555247fb1376cd364bd1831f670418782d2c037f92d6a589569d20d3cd` |
| `docs/production-preflight/sql-editor/01-15-indexes.sql` | `410fb2525972b1dd43b7236544a32a77ad3771b948a3288af3508426c9e2ba14` |
| `docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql` | `71bca850a5ddb76ffbb15ab32a28c2bcca86209fa107bd5cbd00f5f82a14ba76` |
| `supabase/recovery/history.sql` | `38195ddb8a3f01b8d8a8b65b1560b04c3e2d78fb086a77f782fd7f957ad6ebe9` |
| `supabase/recovery/catalog.sql` | `8e564aa33500db90e52c9582a669699348489908656fe4cc5f7298a0acee4eef` |
| `supabase/recovery/effective-privileges.sql` | `43bfad19d3a7b3b2dc41c87d0414c89e025a27c09190fd659442c1465f7febad` |
| `supabase/recovery/diagnostics/compatibility-authority.sql` | `7ef743624536dc44098e1341c49426868b3338f1c5879d97fe7e25c662ab2cc2` |
| `supabase/recovery/diagnostics/migration-authority.sql` | `7be262a2d013824ba12aa1ce4a452ddcc4fc211b588c607ecf5728510f8b14ea` |
| `supabase/recovery/diagnostics/legacy-dependencies.sql` | `a8b352b01cf27de47424a0396f4aeee71173244862cac1c727d132036f8ed19f` |
| `supabase/recovery/diagnostics/registration-plan-cash.sql` | `9a0b31dd2c674d641cf8e6432c0e382f08f4b7543d10b2cddbbba292e085922a` |
| `supabase/recovery/diagnostics/audit.sql` | `baf6c309770944b4a0153f344eab2a31265aa3df1af3215d2f7d537b7e45ed4d` |
| `supabase/recovery/diagnostics/lifecycle-payments.sql` | `0d5afa002dfac8b133d02be1be98d473a3b5ee6b3dac6cf84ab49761a47c3809` |
| `supabase/recovery/diagnostics/additional-legacy-blockers.sql` | `d2361a019c4716ea1f5b38bc5c795a384030fd9215d7100c0531f057fd4d5602` |
| `supabase/recovery/compatibility/review/effective-privileges.sql` | `88f2d95127f4e996ac938e4235d28108fc9052caf9d6c6906b8738c3f3f2a7a6` |
| `H01` | `7f6aea263b9d7305bd60554e398dd607e426c80774bd92875975429e468804be` |
| `H02` | `ee124d5d1cc5a28cd846982c7de029aa75e104096c9e42cc6d80f39746f6fa5c` |
| `H03` | `ec5fe157c88734e8b1f4c31e1136fa19b1eb1e6a8227e15c2428b16230f30d02` |

Static review: PG17 and PG18 parsers accepted all 30 units (27 existing files + three new blocks); top-level statements are transaction control, transaction-local settings, SELECT, and the one existing visibility-only DO. No SQL was executed. New blocks contain no DO. All retain READ ONLY/timeouts/ROLLBACK. Existing DO body was manually reviewed for visibility checks/RAISE only. Parsing is not hosted permission/data validation.
