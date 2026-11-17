-- OWNER REVIEW REQUIRED. Catalog-only, single JSON result; no execution approval.
-- Evaluates the proposed boundary, not the unchanged zero-membership contract.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path = pg_catalog;
WITH reserved AS (
 SELECT oid,rolname,rolcanlogin,rolsuper,rolcreatedb,rolcreaterole,rolinherit,rolreplication,rolbypassrls
 FROM pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
), edges AS (
 SELECT m.*,m.roleid IN (SELECT oid FROM reserved)
 AND m.member=(SELECT oid FROM pg_roles WHERE rolname='postgres')
 AND m.grantor=(SELECT oid FROM pg_roles WHERE rolname='supabase_admin')
 AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option AS approved_provider_edge
 FROM pg_auth_members m WHERE m.roleid IN (SELECT oid FROM reserved) OR m.member IN (SELECT oid FROM reserved)
)
SELECT jsonb_build_object(
 'serverMajor',current_setting('server_version_num')::integer/10000,
 'readOnly',current_setting('transaction_read_only'),
 'actorMatches',current_user='postgres' AND session_user='postgres',
 'actor',(SELECT jsonb_build_object('superuser',rolsuper,'createrole',rolcreaterole,'bypassRls',rolbypassrls) FROM pg_roles WHERE rolname=current_user),
 'schemaGrantAuthority',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,
   'ownsOrInheritsOwner',pg_has_role(current_user,n.nspowner,'USAGE'),
   'canGrantUsage',has_schema_privilege(current_user,n.oid,'USAGE WITH GRANT OPTION')) ORDER BY n.nspname)
   FROM pg_namespace n WHERE n.nspname IN ('api','private','public','extensions')),
 'digestDependency',(SELECT jsonb_build_object('present',p.oid IS NOT NULL,
   'ownerExecutorCanExecute',has_function_privilege(r.oid,p.oid,'EXECUTE'))
   FROM (VALUES(1)) fixture(dummy) LEFT JOIN pg_proc p ON p.oid=to_regprocedure('extensions.digest(bytea,text)')
   LEFT JOIN pg_roles r ON r.rolname='gym_owner_executor'),
 'reservedPresent',(SELECT count(*) FROM reserved),
 'unsafeReservedAttributes',(SELECT count(*) FROM reserved WHERE rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit OR rolreplication OR rolbypassrls),
 'approvedProviderEdges',(SELECT count(*) FROM edges WHERE approved_provider_edge IS TRUE),
 'unexpectedEdges',(SELECT count(*) FROM edges WHERE approved_provider_edge IS NOT TRUE),
 'reservedSchemaCreatePaths',(SELECT count(*) FROM reserved r CROSS JOIN pg_namespace n WHERE n.nspname IN ('api','private','public','extensions') AND has_schema_privilege(r.oid,n.oid,'CREATE')),
 'missingProviderEdges',(SELECT count(*) FROM reserved r WHERE NOT EXISTS(SELECT 1 FROM edges e WHERE e.roleid=r.oid AND e.approved_provider_edge IS TRUE)),
 'operatorSetOrInheritPaths',(SELECT count(*) FROM reserved r WHERE pg_has_role(current_user,r.oid,'SET') OR pg_has_role(current_user,r.oid,'USAGE')),
 'maintenancePolicies',(SELECT count(*) FROM pg_policy WHERE polname='gf_compatibility_read'),
 'decision','NOT_HOSTED_COMPATIBILITY_PROOF') AS compatibility;
ROLLBACK;
