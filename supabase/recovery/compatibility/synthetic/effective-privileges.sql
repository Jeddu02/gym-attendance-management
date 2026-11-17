-- Owner-review draft. Catalogs only; no role names outside the source allowlist returned.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
WITH creators AS (
 SELECT oid FROM pg_roles WHERE rolname IN
 ('postgres',current_user,'gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
 UNION SELECT DISTINCT p.proowner FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname IN ('api','private')
 UNION SELECT DISTINCT c.relowner FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('api','private') OR (n.nspname='public' AND c.relname='gym_settings')
 UNION SELECT d.defaclrole FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace
 WHERE d.defaclnamespace=0 OR n.nspname IN ('api','private')
), risks AS (
 SELECT 'browser_effective_routine_access' AS check_name,count(*) AS violations
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN pg_roles r
 WHERE n.nspname IN ('api','private') AND r.rolname IN ('anon','authenticated')
 AND has_function_privilege(r.oid,p.oid,'EXECUTE')
 UNION ALL
 SELECT 'direct_browser_or_service_data_access',count(*) FROM pg_class c
 JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN pg_roles r
 WHERE c.relkind IN ('r','p','v','m','S') AND
 (n.nspname IN ('api','private') OR (n.nspname='public' AND c.relname='gym_settings'))
 AND r.rolname IN ('anon','authenticated','service_role') AND
 CASE WHEN c.relkind='S' THEN has_sequence_privilege(r.oid,c.oid,'USAGE,SELECT,UPDATE')
 ELSE has_table_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
 OR has_any_column_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,REFERENCES') END
 UNION ALL
 SELECT 'reserved_membership_edges',count(*) FROM pg_auth_members m JOIN pg_roles r
 ON r.oid=m.member OR r.oid=m.roleid WHERE r.rolname IN
 ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor') AND NOT (m.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gf_provider_admin')
 AND m.admin_option AND NOT m.inherit_option AND NOT m.set_option)))
 UNION ALL
 SELECT 'unsafe_role_attributes',count(*) FROM pg_roles r WHERE r.rolname IN
 ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
 AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit OR rolreplication OR rolbypassrls)
 UNION ALL
 SELECT 'missing_reserved_roles',4-count(*) FROM pg_roles WHERE rolname IN
 ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
 UNION ALL
 SELECT 'schema_create_paths',count(*) FROM pg_roles r CROSS JOIN pg_namespace n
 WHERE r.rolname IN ('anon','authenticated','service_role','gym_owner_executor','gym_public_executor','gym_checkin_executor','gym_data_owner')
 AND n.nspname IN ('api','private','public') AND has_schema_privilege(r.oid,n.oid,'CREATE')
 UNION ALL
 SELECT 'creator_global_public_function_default',count(*) FROM creators r
 LEFT JOIN pg_default_acl d ON d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype='f'
 CROSS JOIN LATERAL aclexplode(COALESCE(d.defaclacl,acldefault('f',r.oid))) a
 WHERE a.grantee=0 AND a.privilege_type='EXECUTE'
 UNION ALL
 SELECT 'creator_global_client_function_additions',count(*) FROM creators r
 JOIN pg_default_acl d ON d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype='f'
 CROSS JOIN LATERAL aclexplode(d.defaclacl) a JOIN pg_roles grantee ON grantee.oid=a.grantee
 WHERE grantee.rolname IN ('anon','authenticated','service_role') AND a.privilege_type='EXECUTE'
 UNION ALL
 SELECT 'creator_schema_function_default_additions',count(*) FROM creators r
 JOIN pg_default_acl d ON d.defaclrole=r.oid AND d.defaclobjtype='f'
 JOIN pg_namespace n ON n.oid=d.defaclnamespace
 CROSS JOIN LATERAL aclexplode(d.defaclacl) a LEFT JOIN pg_roles grantee ON grantee.oid=a.grantee
 WHERE n.nspname IN ('api','private') AND (a.grantee=0 OR grantee.rolname IN ('anon','authenticated','service_role'))
 UNION ALL
 SELECT 'creator_nonfunction_default_additions',count(*) FROM creators r
 JOIN pg_default_acl d ON d.defaclrole=r.oid AND d.defaclobjtype IN ('r','S','n')
 LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace
 CROSS JOIN LATERAL aclexplode(d.defaclacl) a LEFT JOIN pg_roles grantee ON grantee.oid=a.grantee
 WHERE (d.defaclnamespace=0 OR n.nspname IN ('api','private'))
 AND (a.grantee=0 OR grantee.rolname IN ('anon','authenticated','service_role'))
)
SELECT check_name,CASE WHEN violations=0 THEN 'PASS' ELSE 'FAIL' END AS result FROM risks ORDER BY 1;
ROLLBACK;
