-- Structural metadata only. Run separately after protected preflight.
BEGIN READ ONLY;
SET LOCAL search_path=pg_catalog;
SET LOCAL statement_timeout='15s';
SELECT 1 / CASE WHEN current_database()='gymforce_pg18_test'
 AND inet_server_addr()='127.0.0.1'::inet AND inet_server_port()=55432
 AND current_user='postgres' AND session_user='postgres'
 AND (SELECT rolsuper FROM pg_roles WHERE rolname=current_user)
 AND current_setting('gymforce.test_cluster_marker',true)='f497fabb-a12f-4068-b745-8b0729279276'
 AND (pg_control_system()).system_identifier::text='7704603813616068820'
 AND lower(rtrim(replace(current_setting('data_directory'),E'\\','/'),'/'))='c:/users/banco-sual/appdata/local/gymforce-pg18-test/data'
 THEN 1 ELSE 0 END AS identity_guard \gset
SELECT r.rolname role_name,r.rolcanlogin login,r.rolsuper superuser,r.rolcreatedb createdb,
 r.rolcreaterole createrole,r.rolinherit inherit,r.rolreplication replication,r.rolbypassrls bypassrls,
 n.nspname schema_name,has_schema_privilege(r.oid,n.oid,'USAGE') schema_usage,
 has_schema_privilege(r.oid,n.oid,'CREATE') schema_create,
 EXISTS (SELECT 1 FROM pg_auth_members m WHERE m.member=r.oid OR m.roleid=r.oid) any_membership_edge
 FROM pg_roles r CROSS JOIN pg_namespace n WHERE r.rolname IN ('anon','authenticated','service_role','gym_data_owner','gym_owner_executor','gym_public_executor','gym_registration_login')
 AND n.nspname IN ('public','private','api','extensions','graphql_public') ORDER BY 1,9;
ROLLBACK;
