-- Privilege metadata booleans only; no definitions, settings, bodies or credentials.
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
 EXISTS (SELECT 1 FROM pg_default_acl d WHERE d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype=k.kind::"char") explicit_global_entry,
 (SELECT count(*) FROM pg_default_acl d WHERE d.defaclrole=r.oid AND d.defaclnamespace<>0 AND d.defaclobjtype=k.kind::"char") schema_entry_count,
 COALESCE((SELECT d.defaclacl FROM pg_default_acl d WHERE d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype=k.kind::"char"),acldefault(k.kind::"char",r.oid))=acldefault(k.kind::"char",r.oid) equals_builtin_acl,
 EXISTS (SELECT 1 FROM aclexplode(COALESCE((SELECT d.defaclacl FROM pg_default_acl d WHERE d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype=k.kind::"char"),acldefault(k.kind::"char",r.oid))) a WHERE a.grantee=0 AND NOT a.is_grantable AND a.privilege_type=CASE k.kind WHEN 'f' THEN 'EXECUTE' ELSE 'USAGE' END) public_builtin_privilege,
 EXISTS (SELECT 1 FROM aclexplode(COALESCE((SELECT d.defaclacl FROM pg_default_acl d WHERE d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype=k.kind::"char"),acldefault(k.kind::"char",r.oid))) a JOIN pg_roles browser ON browser.oid=a.grantee WHERE browser.rolname IN ('anon','authenticated')) explicit_browser_grant,
 EXISTS (SELECT 1 FROM aclexplode(COALESCE((SELECT d.defaclacl FROM pg_default_acl d WHERE d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype=k.kind::"char"),acldefault(k.kind::"char",r.oid))) a WHERE a.grantee NOT IN (0,r.oid) OR (a.grantee=0 AND (a.is_grantable OR a.privilege_type<>CASE k.kind WHEN 'f' THEN 'EXECUTE' ELSE 'USAGE' END))) other_or_escalated_grant
FROM pg_roles r CROSS JOIN (VALUES ('f'),('T')) k(kind)
WHERE r.rolname IN ('postgres','gym_data_owner','gym_owner_executor','gym_public_executor','gym_registration_login') ORDER BY 1,2;
ROLLBACK;
