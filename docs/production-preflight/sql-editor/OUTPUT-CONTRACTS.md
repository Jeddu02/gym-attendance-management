# Output contracts and execution order

These are exact column headers and expected shapes, not fabricated production
values. Metadata row counts are unknown unless explicitly fixed. Successful
execution and security acceptance are separate conclusions. Preserve NULLs;
do not turn missing rows into false or an empty successful checklist.

## 01-01-identity.sql

Source: 01-catalog.sql, diagnostic result 1.

Exact output columns, in order:

`effective_role | connection_role | postgres_version_number | read_only`

Exactly one row. effective_role is current_user; connection_role is session_user. postgres_version_number is server_version_num as text, not a compatibility PASS. read_only must be the text on. Privately verify the expected roles before proceeding. This SQL does not independently identify the hosted project.

## 01-02-migration-history.sql

Source: 01-catalog.sql, diagnostic result 2.

Exact output columns, in order:

`version`

One row per recorded migration version in ascending order. Owner supplied 20 versions; that is a comparison baseline, not a hard-coded expected live result. Report extra/missing version counts. No migration SQL or history repair is returned or performed.

## 01-03-schemas.sql

Source: 01-catalog.sql, diagnostic result 3.

Exact output columns, in order:

`schema_name | owner`

Zero to three rows: existing api/private/extensions schemas and their actual owner names. Missing names mean absent schemas, not a successful complete prerequisite check. Ownership names are sensitive security metadata.

## 01-04-routines.sql

Source: 01-catalog.sql, diagnostic result 4.

Exact output columns, in order:

`schema_name | routine | identity_arguments | result_type | kind | language | owner | security_definer | volatility | empty_search_path | explicit_utc`

One row per routine in api/private, including overloads and unexpected routines. identity_arguments identifies argument names/types; result_type describes the result, never result records. kind uses PostgreSQL prokind codes (f=function, p=procedure, a=aggregate, w=window). language and owner identify implementation metadata. security_definer is a boolean; volatility uses i/s/v codes. empty_search_path and explicit_utc test exact proconfig entries, with NULL config mapped to false. False does not prove an unsafe effective configuration: differently spelled/equivalent settings can fail these exact-entry checks. No bodies or all-settings dump.

## 01-05-routine-acls.sql

Source: 01-catalog.sql, diagnostic result 5.

Exact output columns, in order:

`schema_name | routine | identity_arguments | grantee | privilege_type | is_grantable`

One row per expanded routine ACL item, with function defaults substituted if its ACL is NULL. grantee is PUBLIC, an allowlisted role name or OTHER_ROLE. privilege_type and is_grantable describe that ACL entry. No rows is not proof of deny: compare with routine inventory and effective permission output.

## 01-06-routine-permissions.sql

Source: 01-catalog.sql, diagnostic result 6.

Exact output columns, in order:

`schema_name | routine | identity_arguments | caller | can_execute`

One row per routine and existing allowlisted caller role. can_execute is effective PostgreSQL function privilege, including inherited/PUBLIC access; it is not the complete ability to call through PostgREST. Missing roles produce no rows. Schema USAGE, handler authentication and runtime RLS need separate interpretation. Under the prepared final boundary anon/authenticated execution should be denied; service_role requires only the intended narrow RPC access after prerequisites are reviewed.

## 01-07-schema-permissions.sql

Source: 01-catalog.sql, diagnostic result 7.

Exact output columns, in order:

`schema_name | caller | can_use | can_create`

One row per existing selected schema and existing allowlisted caller. can_use and can_create are effective schema USAGE/CREATE privileges. Missing roles/schemas are omitted rather than shown as false. Evaluate private/application access against the approved final boundary; extensions/public schema permissions may reflect provider infrastructure and are not all required to be false.

## 01-08-default-acls.sql

Source: 01-catalog.sql, diagnostic result 8.

Exact output columns, in order:

`schema_scope | creator_role | object_type | grantee | privilege_type | is_grantable`

One row per expanded matching default ACL entry. schema_scope GLOBAL represents namespace OID zero; creator_role and grantee preserve original masking. object_type is a PostgreSQL default-ACL object code (for example f=routines, r=tables, S=sequences). privilege_type/is_grantable describe explicit future-object rules. Zero rows does not mean future access is denied: implicit defaults and global-plus-schema rules still matter.

## 01-09-table-rls.sql

Source: 01-catalog.sql, diagnostic result 9.

Exact output columns, in order:

`schema_name | relation | relkind | owner | rls_enabled | rls_forced | rls_filters_current_role`

One row per matching ordinary/partitioned table (relkind r/p) in api/private or public.gym_settings. owner is actual relation owner. rls_enabled and rls_forced are table flags. rls_filters_current_role reflects the executing diagnostic role, not anon/authenticated. A privileged diagnostic role can yield false even while RLS is enabled/forced. Under the intended final configuration protected application tables require RLS; API should contain routines only. This result does not test policy behavior.

## 01-10-table-permissions.sql

Source: 01-catalog.sql, diagnostic result 10.

Exact output columns, in order:

`schema_name | relation | caller | any_table_privilege | any_column_privilege`

One row per protected table and existing anon/authenticated/service_role role. any_table_privilege is true if ANY named table privilege is held; it does not mean every listed privilege is held. any_column_privilege similarly means ANY relevant column privilege. It does not identify which privilege/column. Intended final direct browser/service-role application-data privileges are denied. Missing roles/tables produce no rows and cannot count as deny.

## 01-11-policies.sql

Source: 01-catalog.sql, diagnostic result 11.

Exact output columns, in order:

`schema_name | relation | policy | command | permissive | has_using | has_check | roles`

One row per matching policy. command is PostgreSQL policy command code (*=all, r=select, a=insert, w=update, d=delete). permissive is boolean. has_using/has_check indicate expression presence only, not safety or truth. roles is the original masked role-name array, including PUBLIC where applicable. No expressions returned. Missing policies can be safe default deny or an incomplete executor configuration; inspect prerequisites separately.

## 01-12-columns.sql

Source: 01-catalog.sql, diagnostic result 12.

Exact output columns, in order:

`schema_name | relation | column_name | type | not_null`

One row per non-dropped user column in private ordinary/partitioned tables, ordered by relation then attribute position. type is the formatted PostgreSQL type; not_null is the catalog NOT NULL flag. No defaults, expressions or column values. Names such as PIN/token column names reveal structure only, but should remain private.

## 01-13-triggers.sql

Source: 01-catalog.sql, diagnostic result 13.

Exact output columns, in order:

`schema_name | relation | trigger | enabled | routine`

One row per non-internal trigger on private relations or public.gym_settings. enabled uses O=origin/local, D=disabled, R=replica, A=always. routine is the trigger function regprocedure signature rendered using pg_catalog search path. Names/signatures may be schema-qualified. No trigger arguments or bodies returned; enabled O is normal and is not a failure.

## 01-14-constraints.sql

Source: 01-catalog.sql, diagnostic result 14.

Exact output columns, in order:

`schema_name | relation | constraint_name | type | validated`

One row per relation constraint in private. type is PostgreSQL contype (for example p=primary key, u=unique, f=foreign key, c=check, x=exclusion; other runtime codes may occur). validated is the recorded validation flag, not proof of correct business logic. Unvalidated constraints require review; missing expected constraints also need review. No constraint expressions.

## 01-15-indexes.sql

Source: 01-catalog.sql, diagnostic result 15.

Exact output columns, in order:

`schema_name | relation | index_name | valid | ready | unique_index`

One row per private index. valid and ready are independent pg_index flags; false requires investigation. unique_index describes whether that index is unique; false is normal for a non-unique index. Owner previously reported 51 rows with valid/ready both true. Do not require every index to be unique or infer the other 14 results from this grid.

## 02-01-unrecorded-object-markers.sql

Source: 02-unrecorded-object-markers.sql, diagnostic result 1.

Exact output columns, in order:

`version | kind | object_name | column_name | history_recorded | object_present | observation`

Exactly 91 marker rows across 17 migration versions from the preserved VALUES list, unless execution fails or UI truncates. kind is routine_name/relation/column. object_name is schema-qualified source metadata; column_name is NULL for non-column markers. history_recorded checks version presence, object_present checks only name/kind/column presence. Routine presence accepts ANY function overload, regardless of signature/body/owner/grants; relations must be ordinary/partitioned tables, columns non-dropped user attributes. observation is exactly one of RECORDED: definition still needs verification; PRESENT_WITHOUT_HISTORY: older definition or manual drift possible; ABSENT_WITHOUT_HISTORY. RECORDED takes precedence even if object_present=false: flag that as drift separately. Repeated objects occur in different migrations, so marker counts are not unique-object counts. No definition correctness or full schema-diff claim.

