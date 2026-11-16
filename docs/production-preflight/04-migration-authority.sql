-- OWNER REVIEW COPY. Catalog probes only; no SET ROLE, memberships or DDL.
-- Run through the exact intended migration connection, not merely SQL Editor.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='15s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
SELECT current_user AS effective_role,session_user AS connection_role,
 current_setting('server_version_num') AS postgres_version_number,
 r.rolsuper AS effective_role_is_superuser,r.rolcreaterole AS can_create_roles,
 r.rolbypassrls AS bypasses_rls
FROM pg_catalog.pg_roles r WHERE r.rolname=current_user;

WITH expected(name) AS (VALUES ('gym_data_owner'),('gym_owner_executor'),
 ('gym_public_executor'),('gym_checkin_executor'))
SELECT e.name AS reserved_role,r.oid IS NOT NULL AS exists,
 CASE WHEN r.oid IS NULL THEN NULL ELSE
  NOT(r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR
      r.rolinherit OR r.rolreplication OR r.rolbypassrls) END AS safe_attributes,
 CASE WHEN r.oid IS NULL THEN NULL ELSE pg_catalog.pg_has_role(current_user,r.oid,'SET') END AS actor_can_set_role,
 CASE WHEN r.oid IS NULL THEN NULL ELSE EXISTS(
   SELECT 1 FROM pg_catalog.pg_auth_members a WHERE a.roleid=r.oid OR a.member=r.oid)
 END AS any_membership_edge
FROM expected e LEFT JOIN pg_catalog.pg_roles r ON r.rolname=e.name ORDER BY 1;

SELECT r.rolname AS target_owner,n.nspname AS schema_name,
 pg_catalog.has_schema_privilege(r.oid,n.oid,'CREATE') AS target_has_schema_create
FROM pg_catalog.pg_roles r CROSS JOIN pg_catalog.pg_namespace n
WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
 AND n.nspname IN ('api','private','public') ORDER BY 1,2;

-- Ownership prerequisites for protected existing objects; no object changes.
SELECT n.nspname AS schema_name,c.relname AS relation,c.relkind,
 c.relowner=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=current_user) AS directly_owned_by_actor,
 pg_catalog.pg_has_role(current_user,c.relowner,'USAGE') AS actor_has_owner_privileges
FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE c.relkind IN ('r','p','S') AND (n.nspname='private'
 OR (n.nspname='public' AND c.relname='gym_settings')) ORDER BY 1,2;

-- This is only a standard-PostgreSQL prerequisite screen, never a DDL proof.
SELECT CASE WHEN r.rolsuper THEN 'UNKNOWN: superuser detected; full isolated migration rehearsal still required'
 ELSE 'UNKNOWN: non-superuser; reconcile standard ownership rules with no-membership/no-CREATE invariants in isolation'
 END AS ownership_compatibility
FROM pg_catalog.pg_roles r WHERE r.rolname=current_user;
ROLLBACK;
