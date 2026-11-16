# Default-privilege investigation and correction proposal

Latest verdict on these five unchanged statements:
[accelerated-review/README.md](accelerated-review/README.md).
They remain a blocked native-only proposal; no privilege change was executed.

**NOT READY for local execution review.** Draft preparation and read-only
investigation only. No GRANT, REVOKE, ALTER DEFAULT PRIVILEGES, ownership change,
fixture or migration was executed. No hosted service was accessed or changed.

## Verified cause, not inferred from flags

Protected identity/SCRAM preflight passed again for the exact approved test
cluster/database/loopback endpoint. Queries `minimal-catalog/10-default-origins.sql`
and `11-browser-boundary.sql` were independently accepted and returned exit 0
in guarded READ ONLY transactions ending in ROLLBACK. They exported only
creator names, object classes, counts and booleans. No raw ACL arrays, settings,
expressions, function arguments/bodies, password verifiers or application rows
were exported. The original nine queries were not silently rerun or broadened.

| Creator | Functions (`f`) | Types (`T`) |
|---|---|---|
| postgres | implicit PUBLIC EXECUTE | implicit PUBLIC USAGE |
| gym_data_owner | implicit PUBLIC EXECUTE | implicit PUBLIC USAGE |
| gym_owner_executor | implicit PUBLIC EXECUTE | implicit PUBLIC USAGE |
| gym_public_executor | implicit PUBLIC EXECUTE | implicit PUBLIC USAGE |
| gym_registration_login | implicit PUBLIC EXECUTE | implicit PUBLIC USAGE |

All ten observations show no explicit global pg_default_acl entry, zero
per-schema entries, equality to PostgreSQL's built-in ACL, the expected PUBLIC
privilege without grant option, no explicit anon/authenticated entry and no
other/escalated grant. This describes the **current** catalog; it cannot prove
that no historical ALTER DEFAULT PRIVILEGES command was ever issued and undone.

These are ordinary PostgreSQL defaults, not inherited creator configuration.
Default object privileges use the role actually creating an object; they are
not inherited from that role's memberships. Ownership transfer does not apply
the destination owner's creation defaults retroactively. See PostgreSQL
[18 ALTER DEFAULT PRIVILEGES](https://www.postgresql.org/docs/18/sql-alterdefaultprivileges.html)
and [17 ALTER DEFAULT PRIVILEGES](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html).
Bootstrap creates the restricted roles but does not change their creator
defaults. The 24 active migrations contain no default-ACL hardening commands.

## Exposure and policy distinction

Fresh query 11 found **zero executable scoped routines, zero schema-reachable
routines and zero directly privileged protected tables** for both anon and
authenticated. Earlier query 06 also found no direct table/column rights across
all seven harness roles, while the 16 current API routines retain explicit
service_role execution. This is scoped SQL privilege evidence, not hosted API,
JWT or end-to-end authorization certification.

1. **Acceptable built-in type default:** PUBLIC type USAGE permits dependencies
   on a type when creating other schema objects; it grants neither table rows
   nor RPC execution. It does not control every use of type values in queries.
   With the current no-CREATE/no-direct-data/server-only boundary, blanket
   rejection of that built-in privilege was an overbroad draft expectation,
   not evidence of leaked member data. See [PostgreSQL privileges](https://www.postgresql.org/docs/18/ddl-priv.html).
2. **Function hardening requirement:** Built-in PUBLIC EXECUTE is not database
   corruption or a demonstrated current exposure. It is a future-object risk
   against the intended explicit server-only RPC model: a newly created exposed
   routine could be callable until its grants are restricted. Retain the strict
   function-default requirement as defense in depth. New RPC transactions must
   still revoke PUBLIC and grant service_role/exact nested callers explicitly.
3. **Explicit unexpected grants:** None were observed. Any named browser grant,
   unreviewed role grant, grant option or schema-specific additive grant remains
   a refusal. The type exception does not permit these.

The corrected draft accepts only PUBLIC USAGE without grant option for a type
when **no explicit global type-default entry exists**. All other non-owner
global defaults and every non-owner schema addition remain denied. A stricter
owner-only type default is also accepted; there is no reason to restore PUBLIC
if a later approved policy has already removed it. Explicitly adding PUBLIC
type grants is not covered by the exception and requires separate review.

Thus the original ten flags divide into **five incorrect type-policy failures**
and **five genuine failures of the chosen future-function hardening target**.
No database grant was changed to obtain that classification. The target still
refuses the current function defaults; five blockers remain.

## Exact proposed change, outside active migrations

`default-function-privileges.sql.draft` contains an unconditional DRAFT ONLY
exception immediately after BEGIN, strict native identity/role/baseline checks,
five explicit commands and postconditions. It must not be submitted to psql.
The exact proposed privilege changes are:

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_data_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_owner_executor REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_public_executor REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_registration_login REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
```

No IN SCHEMA is used: a schema-specific REVOKE cannot subtract the built-in
global grant. “Global” here means all schemas **in the connected database** for
objects created by the named role, not other databases or cluster-wide role
attributes. FUNCTIONS includes future procedures/aggregates; PostgreSQL does
not allow separate function/procedure default ACLs. No type/table/sequence/
schema/object ACL, role membership, existing function body or current RPC grant
is proposed to change. See [default-ACL scope](https://www.postgresql.org/docs/18/sql-alterdefaultprivileges.html).

The five roles are the reviewed creator inventory, not five new login paths.
The restricted roles currently have no schema CREATE; hardening their defaults
does not grant it. Although current migrations run as postgres, each creator
must be checked independently for future controlled creation paths. Authorized
existing server functions keep their ACLs and execution rights: ALTER DEFAULT
PRIVILEGES affects only objects subsequently created by the specified creator.
Future non-owner helper/API callers need their own explicit grants, atomically.

The proposal refuses any drift from the observed absent function/type default
entries rather than normalizing unknown grants. A future approved runner must
freshly preflight protected identity, PG_VERSION and SCRAM, enforce `-X -w -v
ON_ERROR_STOP=1`, propagate native failures, and verify reserved attributes and
zero memberships. None of that authorizes execution now; no runner was built.

## Provider impact and rollback requirements

This is **native test database only**, not a hosted Supabase migration. Changing
postgres defaults affects its future objects in every schema in that database,
including future extension/provider installation or upgrades. Those operations
may expect PUBLIC execution; never compensate by granting PUBLIC to whole
schemas. Existing extension functions remain unchanged, and the ownership
proposal's explicit `extensions.digest(bytea,text)` executor grant is preserved.
Hosted ownership authority, creator identities, default ACLs, extensions and
API gateway behavior need Owner-controlled review and separate deployment
approval. No hosted privileges or free-tier behavior is assumed.

Before any separately approved isolated test:

- Owner approves the exact draft revisions, maintenance window, synthetic-data
  scope and recovery plan. Capture a protected, Owner-controlled backup/recovery
  record of the existing test database and exact role/default/object ACL state;
  do not log credential material. No backup/dump was performed in this task.
- Revalidate current absence of default entries, all relevant additive entries,
  active object ACLs, identity and source hashes. Stop on drift. Prevent other
  DDL/extension upgrades during testing.
- Initially test the reviewed changes and synthetic checks in one transaction
  ending in ROLLBACK, under separate mutation authorization. Any failure stops
  the client and rolls the complete transaction back. Never reapply the old 24
  migrations, reset the database, or delete existing data to obtain success.
- If a later separately approved revision is committed, verify effective
  function defaults owner-only for each creator, no additive non-owner grants,
  unchanged type defaults and unchanged existing routine/object ACLs. Verify
  every authorized Owner/PIN/audit nested call still works, forbidden callers
  fail, row locks/trigger writes remain atomic and failures roll back.

Pre-commit failure recovery is ROLLBACK. Post-commit recovery requires a fresh
scope review and Owner approval. For the **exact observed built-in baseline
only**, the semantic inverse default changes would be:

```sql
-- Documentation only; NOT authorized rollback commands.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_data_owner GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_owner_executor GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_public_executor GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE gym_registration_login GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
```

These restore the deliberately removed future default only; they do not repair
or change objects created while the stricter defaults were active. They can
reintroduce the future-function risk and must never run automatically or against
a baseline that had pre-existing hardened defaults. Compare effective ACL
semantics and protected evidence; do not force pg_default_acl rows to appear or
disappear using catalog writes, DROP OWNED or a reset.

## Remaining verification without applying anything

| Check | Safe next evidence | Current limitation |
|---|---|---|
| Expressions/default values and index predicates | Separate narrow server-side equality booleans against exact approved expressions | Do not export raw/deparsed expressions; source/cast/IN/ANY/TRIM alignment unresolved |
| Complete routine signatures | Per-allowlisted-signature existence/type/mode/result booleans using approved source signatures | No argument values, raw defaults, body/config export; counts alone do not certify signatures |
| Constraint/index/trigger definition equivalence | Separate allowlisted expected-definition comparisons returning booleans only | Do not turn snapshot hashes/names into semantic proof |
| Executor capabilities | Source call graph/grant review and catalog privilege booleans | Post-migration restricted-role behavior, nested RPCs, triggers, row locks and concurrency need later authorized synthetic mutation tests |
| SQL/PLpgSQL grammar and semantics | Suitable independently reviewed offline parser, or later separately approved isolated runtime tests | No parser certified these drafts; DO/DDL cannot be certified by a generic SELECT PREPARE test |
| Supabase compatibility | Owner-controlled hosted/staging inventory and separately reviewed procedure | Local PostgreSQL 18 does not prove PostgreSQL 17/provider/API compatibility |

All existing ownership/lifecycle blockers remain visible. No approval,
activation, renewal, payment-void or Attendance behavior was implemented.

## Actual validation and files

PASS: existing draft static checks; all **31 original negative subprocesses**
each exit 1 with the expected reason; positive control exit 0; nine new pure
classification tests; existing security configuration checks; **38/38 cached
Deno tests**; structural observation comparison. All 24 original migrations and
four protected original harness/assertion sources match baseline hashes. No
draft SQL block or proposal was executed. Lint, typecheck and build/PWA also
passed, exit 0; generated build files remain ignored. They do not validate SQL.

Changed draft artifacts: source-contract.mjs, schema-contract.json,
render-hardening.mjs, both ownership/assertion SQL drafts,
statement-manifest.json, check-offline.mjs, compare-minimal-catalog.mjs,
minimal-catalog/findings.json, validate-offline.ps1, README.md,
technical-review-2026-11-06.md and minimal-catalog/README.md.
Added: minimal-catalog/10-default-origins.sql, minimal-catalog/10-observed.csv,
minimal-catalog/11-browser-boundary.sql, minimal-catalog/11-observed.csv,
default-privilege-classification.mjs, default-privilege-classification.test.mjs,
default-function-privileges.sql.draft and this reviewable proposal. Existing
bootstrap, role setup, 24 active migrations, active assertions, UI and unrelated
workspace work are unchanged. No commit, push or deployment occurred.

Reviewed SQL SHA-256: ownership/executor draft
`757191c2bc34a31956f2393110705136182370b7350cebd98cf77d0cb1266832`;
phase-aware assertions
`00797aa8b8aa4444604085c96dee3e940687c28428a204ecd160f4fbf8da684b`;
new default-function proposal
`573ac1e964377a25922bb8556c5e0d84dbbe29a277ea758eab1e700b46658331`.
Earlier review hashes remain historical, not the current draft revision.
