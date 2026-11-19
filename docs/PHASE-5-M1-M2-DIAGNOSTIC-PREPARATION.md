# Phase 5 focused M1/M2 diagnostic preparation

Prepared 2026-11-19, Asia/Manila. Repository `Jeddu02/gym-attendance-management`,
`master`, baseline `ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.
Intended future target: `alxhytivwybjbkjjdsyn`.

**DRAFT — NOT AUTHORIZED FOR EXECUTION. Production NO-GO.** This task prepares
two new catalog-only SQL files and this document. No database connection or SQL
execution, including local SQL, occurred. No existing diagnostic, manifest,
migration, application source, role, permission, history or configuration changed.
Existing untracked work is preserved. No environment was created; no commit,
push or deployment occurred. Owner execution approval remains outstanding.

Final local hardening revises **only these same three files**. The prior M2
review decision REVISE is addressed by predefined-role, mixed SET/inheritance
and implicit database-owner path reporting, plus explicit catalog qualification
in both drafts. This revision supersedes the two previous draft hashes; it does
not change any of the original 30 candidate hashes or approve hosted execution.

## 1. Controlling scope and reused evidence

The definitions of M1 and M2 are those in
[the targeted plan](PHASE-5-TARGETED-REMEDIATION-PLAN.md), sections 2, 4–5,
especially its M1/M2 specifications and decisions O1–O8. This package addresses
CR-02/03 and supplies limited supporting evidence for CR-04. It does not replace
the original 30 units or authorize their execution.

Reuse the sanitized, previously completed private-evidence review in
[the consolidated review](PHASE-5-CONSOLIDATED-COMPATIBILITY-RECOVERY-REVIEW.md),
PE-U01/02/03/19/20/22/23/25. Raw private evidence was not reopened, copied or
exported in this preparation. Its original Owner-controlled directory remains
outside the repository. These are saved observations, not fresh hosted facts:

| Existing evidence | Reused conclusion | Missing evidence this package addresses |
| --- | --- | --- |
| U02/U19 | 20 recorded, 17 unrecorded; three present occurrences are the two P01 plan names and P09's reused enrollment name. | No repeat history/marker scan. Names alone do not prove definitions or migration application. |
| U03 and existing PG17 reference comparison | Both P01 identities match but composite hashes differ; normalized-name index matches; 12 baseline routines match. Enrollment matches the older baseline, not P09. | M1 splits plan-routine contract, definition, body, owner, configuration and ACL contributions. Enrollment needs no new query now. |
| U03 relation comparison | 21/22 table fingerprints match; `public.gym_settings` differs. | M2 exposes kind/owner/ENABLE/FORCE components and hashes its raw ACL, with policy/constraint metadata to support attribution. |
| U22 | Seven PASS, three FAIL: missing roles, creator global function defaults, direct data access. | M2 attributes direct-access violations across the **whole original object/caller scope**. It does not assume gym_settings caused that FAIL. |
| U20/U23 (H01/H02) | Four restricted roles absent; provider edges therefore vacuously absent; global PUBLIC function defaults for two creator classes. | Reuse these results; no repeated provider graph or broad default-ACL dump. This package cannot resolve provider ADMIN authority or global-default remediation. |
| U25 | Old limiter absent, rolling limiter present; not full definition proof. | No repeat limiter diagnostic needed for M1/M2. |

Saved results lack complete target/client/TLS/hash/exit-code provenance. O1 must
address freshness and provenance privately. Missing provenance is not evidence
that prior execution was unauthorized. Separate transactions are separate
snapshots; retain timestamps and reconcile intervening DDL before combining them.

## 2. Minimum new inventory and exact bytes

Two independent files are necessary because M1 and M2 have different scopes,
interpretations and failure handling. Each has exactly one result-producing
SELECT, including its CTEs, inside its own transaction. Do not concatenate them.

| Order / new diagnostic | Exact repository path | SHA-256 of complete raw file bytes |
| --- | --- | --- |
| M1 | `supabase/recovery/diagnostics/m1-plan-routine-components.sql` | `c0477249f71a2ab4065d5b43392dcdd326e919201fee56188331799b0b21390a` |
| M2, after M1 review | `supabase/recovery/diagnostics/m2-data-privilege-attribution.sql` | `b4acd4b9caf0a6d40135a418e7b05e850f953ebe23cecbcf8b70820a0906b6cd` |

Both files are UTF-8 without BOM, LF, final newline. Hashes cover comments and
transaction controls too. No line-ending normalization is permitted for these
new execution-byte contracts. A checkout/editor conversion requires restoring
the reviewed bytes or renewed review, not changing expected hashes to pass.
These drafts are not assigned original unit numbers and are not silently added
to the old approval form, manifests or 30-unit hash list.

### Existing source/hash validation

Fresh offline checks in this task:

- **30/30** original reviewed diagnostic hashes and approval inventory match;
  existing package passes pinned PG17/PG18 static AST checks.
- **75/75** source fingerprints match (37 migrations, 21 Edge entrypoints,
  17 shared modules), using `verifyReviewedSource` and its committed-blob plus
  reviewed-newline policy, not newly calculated replacement expectations.
- **19/19** review and **21/21** synthetic compatibility artifact fingerprints
  match their existing manifests using the same reviewed-source verifier.
- No compatibility builder was run, no artifacts regenerated, no reference
  expectations modified. These are source-integrity results, not hosted proof.

Relevant immutable source:
`supabase/recovery/catalog.sql:8` (relation composite), `:19` (routine composite),
`supabase/recovery/effective-privileges.sql:21` (direct-access screen),
`supabase/migrations/20261103080000_owner_membership_plans.sql:37`, `:75`,
`:195`, `:201` (P01 contracts/revocations/grants),
`supabase/migrations/20261110100000_executor_hardening.sql:827` (later owner/RLS
stage), and `scripts/recovery/parser.cjs:1` (pinned parser loader).

## 3. M1: plan-routine attribution

**Scope:** every `pg_proc` entry, including unexpected kinds/overloads, with
schema `api` and either of the two plan names. No other routine body is inspected.
Immediate incoming/outgoing `pg_depend` edges are included as catalog identifiers,
not descriptions or definitions.

The single column is `diagnostic` (JSONB), with:

| Field | Meaning / expected structure |
| --- | --- |
| format/context | `M1-draft-1`, version, session/effective roles, observation time, isolation, read-only, timeouts, search path. Target project cannot be established from these fields alone. |
| presence | Exactly two requested names, each with total-kind and function counts. No required row is silently omitted. |
| routines[] | One row per observed OID: schema/name/kind, identity arguments, result, language, owner/OID, definer/volatility/strict/leakproof/parallel flags. |
| arguments[] | Ordinal position, name, type/OID, mode; plus input count, input type OIDs and default count. Default **expressions are never returned**. |
| config flags | Empty-search-path and explicit-UTC flags, configuration entry count. Configuration values are not returned. |
| fingerprints | `catalogComposite`, `definition`, `prosrc`, `sqlBodyTree`, `configuration`, `owner`, `aclRaw`, `defaults`, all SHA-256 hex. |
| routineAcl[] | Effective explicit-or-built-in-default ACL entries: grantee identifier/class, grantor OID, EXECUTE and grant option. Unknown grantee names masked as OTHER_ROLE; OIDs permit private correlation. This is ACL metadata, not a full inherited execution test. |
| dependencies[] | Direction, catalog/object/subobject and referenced identifiers, dependency type; these OIDs are local to that database. |

Expected P01 contracts: list `(p_actor_user_id uuid) RETURNS jsonb`; save
`(p_actor_user_id uuid,p_plan_id uuid,p_name text,p_price_php numeric,p_is_active
boolean) RETURNS jsonb`; both PL/pgSQL SECURITY DEFINER, empty search path,
zero argument defaults, service-only external execution, active-Owner validation
and audited mutations for save. Preserve positive exact PHP prices, normalization,
locking, legitimate empty list arrays and all existing business rules.
Original P01 owner stage differs from the later restricted-executor stage;
compare to the correct reference, never to an arbitrary final snapshot.

`catalogComposite` repeats the exact original `catalog.sql` formula:
SHA256 UTF8 of JSONB `{definition:pg_get_functiondef,owner:ownerName,acl:proacl::text}`.
`definition` hashes the deparser output directly; `prosrc` hashes the stored body
text directly. Remaining component hashes wrap their value as JSONB `{value:...}`
before UTF8/SHA256, preserving NULL versus empty. Do not compare hashes from
different recipes. SQL-standard body-tree fingerprints contain database-local
identifiers and are not portable semantic equivalence proofs.

Two **source-only candidate body hashes** were extracted using the pinned PG17
AST from the committed LF P01 source's `AS` string, without executing it:

| Function | SHA-256 of canonical LF source body string |
| --- | --- |
| owner_list_membership_plans | `7d2285eb82c7f2ea029fecc84ee647597fb2cd34d0db8b4bc94fab6db538c959` |
| owner_save_membership_plan | `b8899c66261217223a8b061801f42cea136f9da02a2cef9a481279cc703839bb` |

These are candidate text comparisons, not new hosted/reference composite hashes.
An equal `prosrc` digest establishes equal body text under that byte contract;
a different digest may reflect line endings/formatting or substantive changes.
Never normalize away the original mismatch. Existing reference catalogs retain
only composite fingerprints; separate owner/ACL/config/deparser component
goldens are **not available** from them. No database may be executed in this
task to manufacture those goldens. The Owner may use existing trusted private
component evidence if available; otherwise a separate approved method to obtain
same-version, same-stage reference components is still needed. Source AST
contract/body comparisons and the new hosted components narrow the cause but
cannot, by themselves, establish the complete attribution.

`pg_depend` is incomplete for PL/pgSQL text and dynamic SQL. Absence of an edge
does not prove absence of a caller/dependency. Local callers are
`supabase/functions/owner-list-membership-plans/index.ts` and
`supabase/functions/owner-save-membership-plan/index.ts`; frontend/Edge and
private table/audit dependencies still require source review. If OID edges need
further private name resolution, obtain narrowly scoped approval; do not export
the graph or assume the OIDs are portable.

**Stop/HOLD:** either name absent, extra overload/kind, incompatible arguments or
result, unexpected owner/security/configuration/ACL, unexplained component
mismatch, insufficient reference evidence, or incomplete/truncated output.
Even exact body equality does not prove active-Owner authorization at runtime.
No proposed replacement, DROP or P01 replay follows automatically.

## 4. M2: privilege attribution and gym_settings

**Scope exactly preserves Unit 22's direct-access screen:** callers `anon`,
`authenticated`, `service_role`; relations of kinds `r,p,v,m,S` in `api/private`
plus `public.gym_settings`. Checks enumerate table SELECT/INSERT/UPDATE/DELETE/
TRUNCATE/REFERENCES/TRIGGER, column SELECT/INSERT/UPDATE/REFERENCES and sequence
USAGE/SELECT/UPDATE. Relation-kind CASE guards avoid evaluating a sequence-only
privilege function on a non-sequence. No relation, view or application routine is
executed; all data sources are catalogs or query-local CTEs.

| JSON field | Meaning / interpretation |
| --- | --- |
| format/context | `M2-draft-2`, same transaction context fields as M1. |
| callerPresence | All three names, presence/OID and superuser/INHERIT/BYPASSRLS attributes. Missing caller means UNKNOWN, never a zero-violation PASS. |
| scopeInventory/objectCount | Full scoped relation identifiers, kind, owner OID, ENABLE/FORCE flags. Validate completeness and correct migration stage; empty inventory is UNKNOWN. This is not automatically the final 33-table release allowlist. |
| unit22FailingObjectCallerPairs | Distinct object/caller pairs with any original screened privilege. A positive count reproduces the screen's failure classification for this snapshot. No historical exact count is available for comparison. |
| effectivePrivilegeRows/violations[] | Individual effective privilege rows; column privileges may be supplied by a table grant. Do not add table/column counts and call them distinct grants. Each row carries schema reachability, RLS flags, role attributes and owner inheritance/SET reachability. |
| sources[] within violations | Applicable relation/column ACL grant or predefined-role capability. ACL rows distinguish explicit/default, PUBLIC/DIRECT/INHERITED, grantee, grantor and grantability; predefined rows use origin predefined, path PREDEFINED_EFFECTIVE and NULL grantor (not a fictitious GRANT). A column row includes applicable table-wide grants too. |
| unattributedNonSuperuserRows | Must be zero before claiming attribution complete. Positive value is unexplained access, not permission to correct it. Superuser capability is reported separately. |
| schemaGrantPaths | Relevant schema ACL grants, including effective USAGE and SET-reachable roles; actual per-object schemaUsage is reported independently. No schema USAGE can prevent immediate access, but it does not make an underlying grant acceptable under the contract. |
| relevantMembershipEdges | Edges reachable from the three callers toward scoped ACL grantees/owners, the two data roles, database owner and pg_database_owner. EXPLICIT edges retain grantor/options; IMPLICIT_DATABASE_OWNER edges have NULL grantor/ADMIN and modeled INHERIT/SET true. Recursive UNION deduplicates reachability. This is not a whole-provider graph or an executed permission test. |
| latentSetGrantPaths | ACL grants unavailable now but available by setting a permitted context role and inheriting the grantee there. Reports directSet and setThenInheritContexts (database-local OIDs). It includes mixed SET-then-INHERIT paths; counts remain separate from Unit22. |
| predefinedCapabilityPaths | Three requested special-role presence entries per existing caller: effectiveUsage, directSet, setThenInheritContexts, descriptive schema-USAGE capability and no intrinsic BYPASSRLS. A missing special role is explicit, never an empty success. |
| databaseOwnerPaths | Database/owner OIDs, exact owner identity equality, effective/SET/context paths to that owner role and the pg_database_owner OID. Database ownership does not itself grant all application-table privileges. |
| attributionStatus/catalogVisibility | INCOMPLETE_HOLD if callers/special roles/database/settings/scope are missing or a non-superuser violation lacks a source. Otherwise CANDIDATE_SOURCES_IDENTIFIED_NOT_VERIFIED, **never complete attribution or PASS**. Catalog completeness requires independent Owner attestation. |
| gymSettingsComparisonStatus | Always REQUIRES_TRUSTED_REFERENCE_FINGERPRINTS; observed metadata alone does not explain the earlier mismatch. |
| gymSettings[] | Zero or one relation: kind/owner/OID/ENABLE/FORCE/ACL-null flag, original relation composite, raw ACL component hash, policy command/permissiveness/has-expression flags and composite hashes, constraint kind/validation and original composite hashes. No expressions or constraint definitions returned. |

Use `pg_has_role(...,'USAGE')` for presently inherited privileges and `SET` for
potential role switching. ADMIN does not itself confer ordinary inherited table
access. Role INHERIT attributes alone do not replace PG17 per-membership options.
Ownership reachability is an independent warning/capability, not an invented ACL
source; an owner can have revoked ordinary privileges. BYPASSRLS bypasses row
filtering but **does not grant SQL table privileges**. FORCE RLS does not constrain
a superuser/BYPASSRLS actor in the same way as a normal executor.

PG17's predefined read role supplies SELECT on tables/views/sequences and thus
their applicable column reads. The write role supplies INSERT/UPDATE/DELETE
where those bits are checked (sequence UPDATE, not sequence USAGE). Neither
supplies REFERENCES/TRIGGER/TRUNCATE, grant options or intrinsic RLS bypass.
Both supply schema USAGE. A capability is listed as a current source only when
the engine reports an effective checked privilege and effective role USAGE.
SET-only capabilities never become current privilege sources or alter counts.

Mixed-path example: caller can SET intermediate role B, B inherits the read
role, but caller cannot SET the read role directly. directSet is false while
setThenInheritContexts includes B. `role_paths` explicitly models this two-stage
case using pg_has_role(SET) followed by pg_has_role(USAGE); membership alone or
ADMIN alone is insufficient. The context list can include the caller itself
when already effective; read it alongside effectiveUsage, not as a new grant.
Actual session authorization/SET restrictions are not exercised by this query.

The current database owner's implicit edge to pg_database_owner is modeled from
pg_database.datdba, including inherited paths through that owner. It explains
applicable ACL/ownership paths, not hypothetical rights on every table. A role
named pg_database_owner gets no synthetic all-data source. Superuser sources
remain separate; applicable ACL/predefined candidates are not an exclusive
historical cause attribution. Any unknown catalog restriction remains HOLD.

Semantics checked against official PG17
[predefined-role documentation](https://www.postgresql.org/docs/17/predefined-roles.html),
[privilege inquiry functions](https://www.postgresql.org/docs/17/functions-info.html),
and source implementations
[aclchk.c](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/catalog/aclchk.c)
and [acl.c](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/utils/adt/acl.c).
These references do not prove the actual hosted build or role graph.

The original gym_settings relation composite contains kind, owner, raw ACL,
ENABLE/FORCE, index/view definitions and index valid/ready fields. For its
expected ordinary-table kind the latter four are NULL. Policy/constraint
fingerprints are **separate catalog entries**, not possible causes of that
relation-composite mismatch. They provide security/dependency context only.
NULL ACL uses `acldefault`; an explicitly empty ACL is distinct. Raw ACL order
can change a fingerprint without changing effective privileges; retain both
original evidence and grant-level attribution.

**Stop/HOLD:** missing caller/gym_settings, unexpected kind/scope/owner, unknown
grantee requiring private attribution, any unattributed row, latent SET/owner
path not accepted by the security design, changed/truncated snapshot, timeout or
error. Any direct effective privilege remains a release blocker pending a
separately approved correction. Zero violations on a later snapshot do not
explain an earlier failure without an attributed change record. No REVOKE,
role change, default change or RLS change is authorized by this package.

## 5. Safety, permissions and production limits

Each script is BEGIN REPEATABLE READ READ ONLY; three transaction-local settings
(`statement_timeout=30s`, `lock_timeout=2s`, `search_path=pg_catalog`); one catalog
SELECT; ROLLBACK. No DO, SECURITY DEFINER helper invocation, SET ROLE, writes,
temporary objects, SELECT INTO, row locks, extension installation or DDL.
Hash/deparse functions inspect metadata; they do not execute stored functions,
policy predicates, defaults, views or constraints. No explicit application-table
locks or scans are requested. Ordinary catalog AccessShare locks, CPU/hash/JSON
work and an MVCC snapshot still exist; concurrent catalog DDL may wait/conflict.
M2 can expand with columns, ACLs and membership edges; 30 seconds is per statement,
not an overall transaction/idle-session deadline. Do not silently raise timeouts.

Required permissions: connect to the approved database as the existing approved
actor; read the referenced PG17 catalogs (`pg_proc`, namespace, language, roles,
depend, class, attribute, auth_members, database, index, policy, constraint); execute the
listed built-in metadata/privilege/hash/JSON functions. No application SELECT,
CREATEROLE, ownership transfer, RLS bypass or mutation privilege is required by
these queries. Catalog visibility/function grants must be confirmed by the
Owner; hosted restrictions, unsupported function resolution or permission errors
are **UNKNOWN/HOLD**, not reasons to grant more authority or weaken a query.
No pg_authid/password catalog is read. Pre-existing BYPASSRLS of an operator is
context, not a new requirement or grant.

Catalog relations, ordinary built-in functions/aggregates and explicit cast
types are qualified with pg_catalog in both files, including pg_catalog.int2,
bool, text, oid, jsonb, regclass and "char". COALESCE, CASE, ARRAY, CURRENT_USER
and SESSION_USER are SQL constructs, not unqualified application calls. CTEs
remain query-local unqualified names. This prevents temporary-relation/type
shadowing even though search_path remains exactly pg_catalog. No dynamic SQL,
temporary objects or application helper calls are introduced. Fresh dedicated
sessions are still required for transaction state and cleanup, not merely name
resolution. BEGIN inside an existing transaction would not establish the
intended transaction guarantees; do not reuse a client/backend transaction.

M1 hashes stored function/default/config text, which could contain secrets in a
misconfigured database. It returns no such plaintext; hashes still constitute
sensitive metadata and can allow known-value comparisons. Names, OIDs, ACLs,
owners, role paths and policy/constraint identifiers also expose security
structure. **All raw result JSON stays Owner-private.** No member, financial,
PIN, token, credential, receipt or audit record is selected. Never paste raw
JSON, function definitions, ACL grids, policy text or error logs into chat/Git.

## 6. Reproducible offline validation (no database)

From the existing repository, run the following PowerShell block. It uses only
the already installed pinned parsers (`17.8.2`, `18.1.4`); no cache fallback,
download or SQL connection. If missing/mismatched, stop; dependency installation
is not part of this preparation. This validator is embedded here so no extra
tooling file or approved diagnostic needs modification.

```powershell
@'
const fs=require('node:fs'), assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const base='supabase/recovery/diagnostics/';
const files={
 'm1-plan-routine-components.sql':'c0477249f71a2ab4065d5b43392dcdd326e919201fee56188331799b0b21390a',
 'm2-data-privilege-attribution.sql':'b4acd4b9caf0a6d40135a418e7b05e850f953ebe23cecbcf8b70820a0906b6cd'
};
const funcs=new Set(('acldefault aclexplode array_length clock_timestamp convert_to count current_setting current_database encode '
 +'format_type has_column_privilege has_schema_privilege has_sequence_privilege has_table_privilege '
 +'jsonb_agg jsonb_build_object pg_get_constraintdef pg_get_expr pg_get_function_identity_arguments '
 +'pg_get_function_result pg_get_functiondef pg_get_indexdef pg_get_userbyid pg_get_viewdef pg_has_role sha256 unnest').split(' '));
const catalogs=new Set(('pg_proc pg_namespace pg_language pg_roles pg_depend pg_class pg_attribute '
 +'pg_auth_members pg_index pg_policy pg_constraint pg_database').split(' '));
function inspect(sql,p){
 const s=p.parseSync(sql).stmts.map(x=>x.stmt);
 assert.deepEqual(s.map(x=>Object.keys(x)[0]),['TransactionStmt','VariableSetStmt','VariableSetStmt','VariableSetStmt','SelectStmt','TransactionStmt']);
 assert.equal(s[0].TransactionStmt.kind,'TRANS_STMT_BEGIN');
 assert.deepEqual(s[0].TransactionStmt.options.map(x=>[x.DefElem.defname,
  x.DefElem.arg.A_Const.sval?.sval ?? x.DefElem.arg.A_Const.ival?.ival]),
  [['transaction_isolation','repeatable read'],['transaction_read_only',1]]);
 assert.equal(s[5].TransactionStmt.kind,'TRANS_STMT_ROLLBACK');
 assert.equal(s[5].TransactionStmt.chain,undefined);
 for(const [i,[name,value]] of [['statement_timeout','30s'],['lock_timeout','2s'],['search_path','pg_catalog']].entries()){
  const v=s[i+1].VariableSetStmt;
  assert.equal(v.kind,'VAR_SET_VALUE');assert.equal(v.is_local,true);assert.equal(v.name,name);
  assert.deepEqual(v.args.map(x=>x.A_Const.sval.sval),[value]);
 }
 const ctes=new Set();
 function collect(n){if(!n||typeof n!=='object')return;
  if(n.CommonTableExpr)ctes.add(n.CommonTableExpr.ctename);Object.values(n).forEach(collect);}
 collect(s[4]);
 function walk(n){if(!n||typeof n!=='object')return;
  for(const k of Object.keys(n))assert.ok(!['intoClause','lockingClause'].includes(k)&&(!k.endsWith('Stmt')||k==='SelectStmt'));
  if(n.FuncCall){const f=n.FuncCall.funcname.map(x=>x.String.sval);
   assert.ok(f.length===2&&f[0]==='pg_catalog'&&funcs.has(f[1]));}
  if(n.RangeVar){const r=n.RangeVar;
   assert.ok(r.schemaname==='pg_catalog'?catalogs.has(r.relname):!r.schemaname&&ctes.has(r.relname));}
  if(n.TypeCast){const names=n.TypeCast.typeName.names.map(x=>x.String.sval);
   assert.ok(names.length===2&&names[0]==='pg_catalog'&&['text','oid','jsonb','regclass','int2','bool','char'].includes(names[1]));}
  Object.values(n).forEach(walk);
 }walk(s[4]);return s[4].SelectStmt;
}
// Evaluate only source AST predicate expressions in memory, never SQL.
// This limited JS model does not implement PostgreSQL runtime or SQL NULL logic.
function scalar(c){if(c.isnull)return null;if(c.sval)return c.sval.sval;
 if(c.ival)return c.ival.ival??0;if(c.boolval)return c.boolval.boolval??false;throw Error('Unknown constant');}
function ev(n,e,has){
 if(n.A_Const)return scalar(n.A_Const);
 if(n.TypeCast)return ev(n.TypeCast.arg,e,has);
 if(n.ColumnRef)return e[n.ColumnRef.fields.map(x=>x.String.sval).join('.')];
 if(n.List)return n.List.items.map(x=>ev(x,e,has));
 if(n.BoolExpr){const b=n.BoolExpr;return b.boolop==='AND_EXPR'?b.args.every(x=>ev(x,e,has)):
  b.boolop==='OR_EXPR'?b.args.some(x=>ev(x,e,has)):!ev(b.args[0],e,has);}
 if(n.NullTest)return n.NullTest.nulltesttype==='IS_NOT_NULL'?ev(n.NullTest.arg,e,has)!=null:ev(n.NullTest.arg,e,has)==null;
 if(n.A_Expr){const a=n.A_Expr,l=ev(a.lexpr,e,has),r=ev(a.rexpr,e,has);
  assert.equal(a.name[0].String.sval,'=');return a.kind==='AEXPR_IN'?r.includes(l):l===r;}
 if(n.FuncCall){assert.deepEqual(n.FuncCall.funcname.map(x=>x.String.sval),['pg_catalog','pg_has_role']);
  return has(...n.FuncCall.args.map(x=>ev(x,e,has)));}
 throw Error('Unsupported model expression');
}
function member(edges,a,b,mode){if(a==null||b==null)return false;
 const seen=new Set([a]);for(const x of seen)for(const edge of edges)
  if(edge.a===x&&(mode==='MEMBER'||(mode==='SET'?edge.set:edge.inherit)))seen.add(edge.b);
 return seen.has(b);
}
function clean(x){if(Array.isArray(x))return x.map(clean);if(!x||typeof x!=='object')return x;
 return Object.fromEntries(Object.entries(x).filter(([k])=>!['location','stmt_location','stmt_len','rexpr_list_start','rexpr_list_end'].includes(k)).map(([k,v])=>[k,clean(v)]));}
function composite(ast,keys){const found=[];
 function walk(n){if(!n||typeof n!=='object')return;const f=n.FuncCall;
  if(f?.funcname.at(-1).String.sval==='jsonb_build_object'&&f.args.length===keys.length*2&&
   keys.every((k,i)=>f.args[i*2].A_Const?.sval?.sval===k))found.push(n);
  Object.values(n).forEach(walk);}
 walk(ast);assert.equal(found.length,1);return found[0];}
function formula(n){const x=clean(n);
 function walk(v){if(!v||typeof v!=='object')return;
  for(const a of [v.FuncCall?.funcname,v.TypeCast?.typeName.names])if(a?.[0]?.String?.sval==='pg_catalog')a.shift();
  const f=v.ColumnRef?.fields;if(f?.[0]?.String?.sval==='c'&&['indisvalid','indisready'].includes(f[1]?.String?.sval))f[0].String.sval='i';
  Object.values(v).forEach(walk);}
 walk(x);return x;}
function reviewM2(sql,p){
 const root=inspect(sql,p),cs=Object.fromEntries(root.withClause.ctes.map(x=>[x.CommonTableExpr.ctename,x.CommonTableExpr.ctequery.SelectStmt]));
 const where=q=>p.parseSync('SELECT 1 WHERE '+q).stmts[0].stmt.SelectStmt.whereClause;
 assert.deepEqual(clean(cs.callers.whereClause),clean(where("r.rolname IN ('anon','authenticated','service_role')")));
 assert.deepEqual(clean(cs.objects.whereClause),clean(where("c.relkind IN ('r','p','v','m','S') AND (n.nspname IN ('api','private') OR (n.nspname='public' AND c.relname='gym_settings'))")));
 const leaves=q=>q.op==='SETOP_UNION'?[...leaves(q.larg),...leaves(q.rarg)]:[q];
 const branches=leaves(cs.checks);assert.equal(branches.length,3);
 const rights=[['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'],['SELECT','INSERT','UPDATE','REFERENCES'],['USAGE','SELECT','UPDATE']];
 const whereExpected=["CASE WHEN c.relkind='S' THEN false ELSE pg_catalog.has_table_privilege(r.oid,c.oid,v.privilege) END",
  "CASE WHEN c.relkind='S' THEN false ELSE pg_catalog.has_column_privilege(r.oid,c.oid,a.attnum,v.privilege) END",
  "CASE WHEN c.relkind='S' THEN pg_catalog.has_sequence_privilege(r.oid,c.oid,v.privilege) ELSE false END"];
 branches.forEach((q,i)=>{assert.deepEqual(clean(q.whereClause),clean(where(whereExpected[i])));
  const found=[];function walk(n){if(!n||typeof n!=='object')return;if(n.valuesLists)found.push(n.valuesLists);Object.values(n).forEach(walk);}walk(q);
  assert.equal(found.length,1);assert.deepEqual(found[0].map(x=>scalar(x.List.items[0].A_Const)),rights[i]);});
 assert.deepEqual(clean(cs.set_contexts.whereClause),clean(where("pg_catalog.pg_has_role(r.oid,x.oid,'SET')")));
 const fields=Object.fromEntries(cs.role_paths.targetList.map(x=>[x.ResTarget.name,x.ResTarget.val]));
 assert.deepEqual(clean(fields.effective_usage),clean(where("pg_catalog.pg_has_role(r.oid,t.role_oid,'USAGE')")));
 assert.deepEqual(clean(fields.direct_set),clean(where("pg_catalog.pg_has_role(r.oid,t.role_oid,'SET')")));
 const contextWhere=fields.set_context_oids.SubLink.subselect.SelectStmt.whereClause;
 assert.deepEqual(clean(contextWhere),clean(where("sc.caller_oid=r.oid AND pg_catalog.pg_has_role(sc.context_oid,t.role_oid,'USAGE')")));
 const top=root.targetList[0].ResTarget.val.FuncCall.args;
 const output=key=>top[top.findIndex(x=>x.A_Const?.sval?.sval===key)+1];
 const failWhere=output('unattributedNonSuperuserRows').SubLink.subselect.SelectStmt.whereClause;
 assert.equal(ev(failWhere,{rolsuper:false,sources:'[]'},()=>false),true);
 assert.equal(ev(failWhere,{rolsuper:true,sources:'[]'},()=>false),false);
 assert.equal(ev(failWhere,{rolsuper:false,sources:'[source]'},()=>false),false);
 assert.ok(JSON.stringify(output('attributionStatus')).includes('INCOMPLETE_HOLD'));
 assert.ok(JSON.stringify(output('attributionStatus')).includes('CANDIDATE_SOURCES_IDENTIFIED_NOT_VERIFIED'));
 const expectedHold="CASE WHEN (SELECT pg_catalog.count(*) FROM callers)<>3 OR EXISTS(SELECT 1 FROM special_roles WHERE oid IS NULL) OR (SELECT pg_catalog.count(*) FROM database_context)<>1 OR (SELECT pg_catalog.count(*) FROM settings)<>1 OR NOT EXISTS(SELECT 1 FROM objects) OR EXISTS(SELECT 1 FROM violations WHERE NOT rolsuper AND sources='[]'::pg_catalog.jsonb) THEN 'INCOMPLETE_HOLD' ELSE 'CANDIDATE_SOURCES_IDENTIFIED_NOT_VERIFIED' END";
 assert.deepEqual(clean(output('attributionStatus')),clean(p.parseSync('SELECT '+expectedHold).stmts[0].stmt.SelectStmt.targetList[0].ResTarget.val));
 assert.equal(output('catalogVisibility').A_Const.sval.sval,'REQUIRES_OWNER_ATTESTATION_NO_AUTOMATIC_COMPLETE_ATTRIBUTION');
 assert.equal(output('gymSettingsComparisonStatus').A_Const.sval.sval,'REQUIRES_TRUSTED_REFERENCE_FINGERPRINTS');
 const originalCount=output('unit22FailingObjectCallerPairs').SubLink.subselect.SelectStmt;
 assert.equal(originalCount.fromClause[0].RangeSubselect.subquery.SelectStmt.fromClause[0].RangeVar.relname,'checks');
 assert.equal(originalCount.fromClause[0].RangeSubselect.subquery.SelectStmt.distinctClause.length,1);
 assert.equal(cs.membership_edges.rarg.targetList[6].ResTarget.val.TypeCast.arg.A_Const.sval.sval,'IMPLICIT_DATABASE_OWNER');
 const pred=cs.source_rows.rarg.whereClause;
 let tests=3;
 const source=(edges,name,oid,privilege)=>ev(pred,{'q.caller_oid':1,'q.privilege':privilege,'s.name':name,'s.oid':oid},(...a)=>member(edges,...a));
 const inherited=[{a:1,b:2,inherit:true,set:false},{a:2,b:3,inherit:true,set:false}];
 for(const privilege of ['SELECT','INSERT','UPDATE','DELETE','USAGE','REFERENCES','TRIGGER','TRUNCATE']){
  assert.equal(source(inherited,'pg_read_all_data',3,privilege),privilege==='SELECT');tests++;
  assert.equal(source(inherited,'pg_write_all_data',3,privilege),['INSERT','UPDATE','DELETE'].includes(privilege));tests++;
 }
 const setOnly=[{a:1,b:3,inherit:false,set:true}],adminOnly=[{a:1,b:3,inherit:false,set:false,admin:true}];
 for(const edges of [setOnly,adminOnly,[]]){assert.equal(source(edges,'pg_read_all_data',3,'SELECT'),false);tests++;}
 assert.equal(source(inherited,'pg_read_all_data',null,'SELECT'),false);tests++;
 assert.equal(source(inherited,'pg_database_owner',3,'SELECT'),false);tests++;
 function contexts(edges){return [1,2,3].filter(x=>ev(cs.set_contexts.whereClause,{'r.oid':1,'x.oid':x},(...a)=>member(edges,...a)))
  .filter(x=>ev(contextWhere,{'sc.caller_oid':1,'r.oid':1,'sc.context_oid':x,'t.role_oid':3},(...a)=>member(edges,...a)));}
 const mixed=[{a:1,b:2,inherit:false,set:true},{a:2,b:3,inherit:true,set:false}];
 assert.equal(member(mixed,1,3,'SET'),false);tests++;
 assert.deepEqual(contexts(mixed),[2]);tests++;
 assert.deepEqual(contexts(setOnly),[3]);tests++;
 assert.deepEqual(contexts(adminOnly),[]);tests++;
 assert.deepEqual(contexts([{a:1,b:2,inherit:false,set:false},{a:2,b:3,inherit:true,set:false}]),[]);tests++;
 // Model the implicit database-owner edge: role 2 owns the DB, role 3 is pg_database_owner.
 const db=[{a:1,b:2,inherit:true,set:false},{a:2,b:3,inherit:true,set:true}];
 assert.equal(member(db,1,3,'USAGE'),true);tests++;
 assert.equal(source(db,'pg_database_owner',3,'SELECT'),false);tests++;
 return tests;
}
(async()=>{
 let positives=0,negatives=0,edgeCases=0,attributionMutations=0,formulaChecks=0;
 for(const major of [17,18]){
  const p=require('./scripts/recovery/parser.cjs')(major);await p.loadModule();
  const old=p.parseSync(fs.readFileSync('supabase/recovery/catalog.sql','utf8'));
  for(const [file,hash] of Object.entries(files)){
   const bytes=fs.readFileSync(base+file),sql=bytes.toString('utf8');
   assert.equal(createHash('sha256').update(bytes).digest('hex'),hash);
   assert.ok(!sql.includes('\r')&&!sql.startsWith('\uFEFF')&&sql.endsWith('\n'));
   inspect(sql,p);positives++;
   const keys=file.startsWith('m1-')?['definition','owner','acl']:['kind','owner','acl','rls','force','index','view','valid','ready'];
   assert.deepEqual(formula(composite(p.parseSync(sql),keys)),formula(composite(old,keys)));formulaChecks++;
   if(file.startsWith('m2-')){
    edgeCases+=reviewM2(sql,p);
    const bad=[
     sql.replace("q.privilege IN ('INSERT','UPDATE','DELETE')","q.privilege IN ('INSERT','UPDATE','DELETE','SELECT')"),
     sql.replace("q.privilege='SELECT'","q.privilege='USAGE'"),
     sql.replace("pg_catalog.pg_has_role(q.caller_oid,s.oid,'USAGE')","pg_catalog.pg_has_role(q.caller_oid,s.oid,'SET')"),
     sql.replace("pg_catalog.pg_has_role(r.oid,x.oid,'SET')","pg_catalog.pg_has_role(r.oid,x.oid,'USAGE')"),
     sql.replace("pg_catalog.pg_has_role(sc.context_oid,t.role_oid,'USAGE')","pg_catalog.pg_has_role(sc.context_oid,t.role_oid,'SET')"),
     sql.replace("WHERE NOT rolsuper AND sources='[]'","WHERE false AND sources='[]'"),
     sql.replace("('r','p','v','m','S')","('r','p')"),
     sql.replace("('anon','authenticated','service_role')","('anon','authenticated')"),
     sql.replace("OR EXISTS(SELECT 1 FROM special_roles WHERE oid IS NULL)","OR false"),
     sql.replace("(SELECT pg_catalog.count(*) FROM callers)<>3","false")
    ];
    for(const changed of bad){assert.notEqual(changed,sql);assert.throws(()=>reviewM2(changed,p));attributionMutations++;}
   }
   const changed=[
    sql.replace('READ ONLY;','READ WRITE;'),sql.replace('ROLLBACK;','COMMIT;'),
    sql.replace('SET LOCAL statement_timeout','SET statement_timeout'),
    sql.replace("statement_timeout='30s'","statement_timeout='0'"),
    sql.replace("lock_timeout='2s'","lock_timeout='30s'"),
    sql.replace('search_path=pg_catalog','search_path=public'),
    sql.replace('AS diagnostic;','AS diagnostic INTO public.forbidden;'),
    sql.replace('pg_catalog.clock_timestamp()','pg_catalog.pg_sleep(1)'),
    sql.replace('pg_catalog.pg_roles','public.member_records'),
    sql.replace('pg_catalog.pg_roles','pg_roles'),
    sql.replace('pg_catalog.clock_timestamp()','clock_timestamp()'),
    sql.replace('::pg_catalog.text','::text'),
    sql.replace(/WITH(?: RECURSIVE)? /,'WITH RECURSIVE injected AS (DELETE FROM pg_catalog.pg_proc RETURNING *), ')
   ];
   for(const bad of changed){assert.notEqual(bad,sql);assert.throws(()=>inspect(bad,p));negatives++;}
  }
 }console.log(`PASS: ${positives} file/grammar checks; ${negatives} unsafe mutations rejected; ${edgeCases} predicate/model edge checks; ${attributionMutations} attribution mutations rejected; ${formulaChecks} original composite formulas preserved. No SQL executed.`);
})().catch(e=>{console.error(e.message);process.exitCode=1;});
'@ | node
```

The guard compares scalar AST values, excluding parser location offsets. It
requires qualified catalog relations, built-ins and explicit types, rejecting
nested mutations and INTO/locking clauses. Raw SHA-256 is checked first. Thirteen
unsafe variants per file/grammar exercise rejection. Actual M2 source AST
predicates are evaluated against synthetic in-memory role graphs; separate
assertions pin the original caller/object/privilege scopes, fail-closed guards
and SET-then-INHERIT semantics. Ten attribution/scope mutations per grammar
must fail. This is a limited JavaScript predicate model, **not PostgreSQL SQL
execution**, full SQL NULL semantics, session authorization or hosted testing.
Composite payload ASTs are compared to the unchanged catalog.sql recipes,
ignoring explicit pg_catalog qualification and the derived index-field alias;
no fingerprint expectations are recalculated to make drift disappear.

Also run `node scripts/recovery/validate-hosted-package.mjs` to recheck all 30
old hashes/ASTs, and `git diff --check`. Broad regression suites are unnecessary
because no executable application or migration behavior was changed.

Actual final-hardening results: **PASS 4/4** new file/grammar checks (two files,
two grammars); **PASS 52/52** unsafe variants rejected; **PASS 62/62** predicate/model
checks (31 per grammar); **PASS 20/20** attribution/scope mutations rejected;
**PASS 4/4** original composite payload comparisons; **PASS 30/30** existing
diagnostic hashes and their PG17/18 static checks; **PASS 75/75** source and
**40/40** artifact fingerprint checks. The embedded block above was extracted
and run verbatim with Node, including its hash checks. Fresh file whitespace
and Git diff checks passed. **Runtime SQL name/type resolution, hosted catalog
permissions, cost, result completeness and session cleanup are NOT VERIFIED**;
no SQL was executed to test them. These drafts need Owner/DBA review before
execution approval. Static success does not imply hosted PASS.

## 7. Owner/DBA execution approval checklist — all unapproved

Final **source-level** assessment, pending separate execution authorization:

| Draft | Decision | Benefit / remaining limitation |
| --- | --- | --- |
| M1, exact revised hash in section 2 | **APPROVABLE FOR SEPARATE READ-ONLY EXECUTION** | Qualified catalog access; original composite plus contract/body/config/owner/ACL components. Trusted same-stage component references remain missing; this is evidence collection, not a declaration of equivalent hosted definitions or effective RPC authorization. |
| M2-draft-2, exact revised hash in section 2 | **APPROVABLE FOR SEPARATE READ-ONLY EXECUTION** | Attributes candidate ACL, predefined and implicit database-owner paths, including mixed SET/INHERIT, without changing Unit22 counts. Missing visibility/reference evidence stays HOLD/unverified. No actual SET ROLE, policy execution or full authorization test is performed. |

For both: existing Owner-controlled client qualification, fresh dedicated
transaction/backend, verified TLS/project/identity, private complete output,
timeouts, stop/cleanup responsibility and explicit O3 authorization below remain
prerequisites. Hosted runtime compatibility and performance are **NOT VERIFIED**.
An APPROVABLE design decision is neither authorization nor a diagnostic-session
GO. Old draft hashes must not be used for these revised files.

- [ ] **O1:** confirm evidence provenance/freshness, accepted source/artifact stage
  and whether adequate existing private component results avoid any new execution.
- [ ] **O3 scope:** approve exactly M1 then M2, the complete two files and raw
  hashes above, all private result fields and acknowledged limits. Any change
  requires review again. This is not approval for other units or any mutation.
- [ ] Confirm target `alxhytivwybjbkjjdsyn` from Owner dashboard connection details;
  database name/host and actual execution/session role **OWNER TO CONFIRM**.
  SQL context cannot independently prove the project reference.
- [ ] Existing approved client and version **OWNER TO CONFIRM**. Use a dedicated
  Owner-controlled psql process per file, verified TLS (`verify-full` plus trusted
  CA), password prompt/private credential handling, `-X`, `ON_ERROR_STOP=1`,
  complete unaligned result capture. No connection secrets in commands/repository.
  Existing client guide qualification is not assumed to have passed.
- [ ] Asia/Manila execution date/start/end and maximum elapsed duration
  **OWNER TO CONFIRM**; one quiet metadata window, no concurrent schema changes.
- [ ] Private evidence custodian, restricted storage location and authorized
  viewers **OWNER TO CONFIRM**. Retention/disposal date and method
  **OWNER TO CONFIRM**. Never put raw results in this repository or chat.
- [ ] Owner/DBA confirms existing applicable diagnostic/recovery prerequisites,
  cancellation owner, session-cleanup capability and operational evidence policy;
  this preparation does not establish backup/restore capability.
- [ ] Accept all stop conditions, private error handling, no retries on uncertain
  closure and no automatic follow-up correction or privilege grant.
- [ ] Owner name, explicit decision and approval timestamp **OWNER TO COMPLETE**;
  no signature or approval is supplied here.

**Conditional procedure, only after that approval:** verify raw file hashes and
target/client/identity first; start a fresh psql process with startup files
disabled and error-stop enabled; send the entire unchanged M1 file. Keep its
complete one-row JSON, command tags BEGIN/SET/SET/SET/ROLLBACK, client exit status,
times, source hash and target/client attestation privately. Review context and
presence/contracts before authorizing continuation to M2. Run unchanged M2 in a
new dedicated process, with independent capture and review. Do not splice a
ROLLBACK out to make a grid visible; previous SQL Editor result/cancellation
limitations remain. Do not assume separate SQL Editor clicks share a session.

On successful completion require final ROLLBACK tag, exit 0, complete JSON and
process exit. On SQL error/timeout/cancellation, **stop**. In an interactive
same-session client issue ROLLBACK then close it; in a dedicated noninteractive
error-stop process close/terminate that known process and await its exit, so the
connection's uncommitted read-only transaction is abandoned. If cancellation,
connection loss or server-side closure is uncertain, the Owner must verify that
exact backend/transaction and lock release through an already authorized
administrative path before retry. A later SQL Editor ROLLBACK is not proof.
Do not kill unrelated sessions or add unapproved hosted monitoring SQL here.

## 8. Sanitized reporting and remaining decisions

Owner sends only source-approved names, comparison classifications and counts:

```text
Target confirmed / approved actor-client-window / private provenance reference: CONFIRMED or UNKNOWN
M1 file/hash verified; complete result/rollback/process exit: YES/NO/UNKNOWN
Requested names: 2; expected overloads/contracts: PASS/FAIL/UNKNOWN
List / save components: body [equal/different/unknown]; definition/config/owner/ACL/defaults [attributed/unexplained]
Dependencies and reference stage accepted: YES/NO/UNKNOWN
M2 file/hash verified; complete result/rollback/process exit: YES/NO/UNKNOWN
Three callers and expected scoped inventory complete: YES/NO/UNKNOWN
Violating object/caller pairs: count; unattributed rows: count; latent SET warnings: count
Grant origin classes: direct/PUBLIC/inherited/owner-capability/superuser/UNKNOWN (counts only)
gym_settings difference: kind/owner/ACL/ENABLE/FORCE/representation/UNKNOWN
Provider-controlled correction needed: YES/NO/UNKNOWN (no role graph)
Unexpected errors/partial output/uncertain closure: sanitized category only
Decision: HOLD for private attribution / request separate correction design / request provider guidance
```

Even if both diagnostics complete and every difference is attributed, these
remain **BLOCKED or NOT VERIFIED**: supported provider-controlled ADMIN/ownership
authority (O2/O5), final restricted-role/security contract and complete effective
RPC/default-ACL acceptance (O4), honest compatibility/history strategy (O7),
legacy finance/member/attendance/cash and audit-chain compatibility (D1), real
backup/restore/RPO/RTO evidence (O6), controlled execution and deployment (O8),
and hosted business/security/race acceptance. M2 metadata flags do not validate
policy predicates or execute negative permission tests. No four missing roles
are created; no defaults corrected; no financial/audit data is examined.

**Next action:** Owner/DBA reviews these exact drafts, resolves the reference
component/provenance gaps and completes O3's identity/client/window/privacy/
cleanup fields before separately approving any execution. Static preparation
is not hosted compatibility certification. **Production remains NO-GO.**
