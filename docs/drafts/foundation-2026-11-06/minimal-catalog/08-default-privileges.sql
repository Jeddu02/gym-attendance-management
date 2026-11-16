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
SELECT r.rolname creator,k.kind,
 EXISTS (SELECT 1 FROM aclexplode(COALESCE((SELECT d.defaclacl FROM pg_default_acl d
 WHERE d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype=k.kind::"char"),acldefault(k.kind::"char",r.oid))) a
 WHERE a.grantee<>r.oid) non_owner_global_default,
 EXISTS (SELECT 1 FROM pg_default_acl d JOIN pg_namespace n ON n.oid=d.defaclnamespace,
 LATERAL aclexplode(d.defaclacl) a WHERE d.defaclrole=r.oid AND d.defaclobjtype=k.kind::"char"
 AND n.nspname IN ('private','api','public','graphql_public') AND a.grantee<>r.oid) non_owner_schema_default
 FROM pg_roles r CROSS JOIN (VALUES ('r'),('S'),('f'),('T')) k(kind)
 WHERE r.rolname IN ('postgres','gym_data_owner','gym_owner_executor','gym_public_executor','gym_registration_login') ORDER BY 1,2;
ROLLBACK;
