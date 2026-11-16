-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 8. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


-- Future-object ACL metadata. Global defaults matter as well as schema defaults.
SELECT CASE WHEN d.defaclnamespace=0 THEN 'GLOBAL' ELSE n.nspname END AS schema_scope,
 CASE WHEN owner_role.rolname IN ('postgres','gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
      THEN owner_role.rolname ELSE 'OTHER_ROLE' END AS creator_role,
 d.defaclobjtype AS object_type,
 CASE WHEN a.grantee=0 THEN 'PUBLIC'
      WHEN grantee.rolname IN ('anon','authenticated','service_role','postgres','gym_data_owner',
           'gym_owner_executor','gym_public_executor','gym_checkin_executor')
      THEN grantee.rolname ELSE 'OTHER_ROLE' END AS grantee,
 a.privilege_type,a.is_grantable
FROM pg_catalog.pg_default_acl d
JOIN pg_catalog.pg_roles owner_role ON owner_role.oid=d.defaclrole
LEFT JOIN pg_catalog.pg_namespace n ON n.oid=d.defaclnamespace
CROSS JOIN LATERAL pg_catalog.aclexplode(d.defaclacl) a
LEFT JOIN pg_catalog.pg_roles grantee ON grantee.oid=a.grantee
WHERE (d.defaclnamespace=0 OR n.nspname IN ('api','private','public'))
 AND owner_role.rolname IN ('postgres','gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
ORDER BY 1,2,3,4;
ROLLBACK;
