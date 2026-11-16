-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 5. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


-- Explicit/default routine ACLs; unknown grantees are deliberately anonymized.
SELECT n.nspname AS schema_name, p.proname AS routine,
       pg_catalog.pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       CASE WHEN a.grantee=0 THEN 'PUBLIC'
            WHEN r.rolname IN ('postgres','anon','authenticated','service_role',
                 'gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
            THEN r.rolname ELSE 'OTHER_ROLE' END AS grantee,
       a.privilege_type, a.is_grantable
FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
LEFT JOIN pg_catalog.pg_roles r ON r.oid=a.grantee
WHERE n.nspname IN ('api','private') ORDER BY 1,2,3,4;
ROLLBACK;
