-- OWNER REVIEW REQUIRED. Run through the intended migration connection.
-- SQL Editor results do not establish the identity/authority of a CLI connection.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path = pg_catalog;
WITH actor AS (
 SELECT rolsuper,rolcreaterole,rolbypassrls,
 current_user=session_user AS same_session_actor
 FROM pg_roles WHERE rolname=current_user
), reserved AS (
 SELECT name,r.oid,
 CASE WHEN r.oid IS NULL THEN NULL ELSE pg_has_role(current_user,r.oid,'SET') END AS actor_can_set,
 CASE WHEN r.oid IS NULL THEN NULL ELSE pg_has_role(current_user,r.oid,'USAGE') END AS actor_inherits,
 (SELECT count(*) FROM pg_auth_members m WHERE m.roleid=r.oid OR m.member=r.oid) AS membership_edges,
 (SELECT count(*) FROM pg_namespace n WHERE n.nspname IN ('api','private','public')
    AND has_schema_privilege(r.oid,n.oid,'CREATE')) AS schema_create_paths
 FROM (VALUES ('gym_data_owner'),('gym_owner_executor'),('gym_public_executor'),('gym_checkin_executor')) names(name)
 LEFT JOIN pg_roles r ON r.rolname=names.name
)
SELECT jsonb_build_object(
 'serverMajor', current_setting('server_version_num')::integer/10000,
 'readOnly', current_setting('transaction_read_only'),
 'actor', (SELECT to_jsonb(actor) FROM actor),
 'reserved', (SELECT jsonb_agg(jsonb_build_object('role',name,'present',oid IS NOT NULL,
   'actorCanSet',actor_can_set,'actorInherits',actor_inherits,
   'membershipEdges',membership_edges,
   'schemaCreatePaths',CASE WHEN oid IS NULL THEN NULL ELSE schema_create_paths END) ORDER BY name) FROM reserved),
 'decision','AUTHORITY_NOT_PROVEN_BY_CATALOG') AS authority;
ROLLBACK;
