-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 6. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


-- Effective permissions account for inherited privileges, not just ACL text.
SELECT n.nspname AS schema_name,p.proname AS routine,
       pg_catalog.pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       r.rolname AS caller, pg_catalog.has_function_privilege(r.oid,p.oid,'EXECUTE') AS can_execute
FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
CROSS JOIN pg_catalog.pg_roles r
WHERE n.nspname IN ('api','private') AND r.rolname IN
 ('anon','authenticated','service_role','gym_owner_executor','gym_public_executor','gym_checkin_executor')
ORDER BY 1,2,3,4;
ROLLBACK;
