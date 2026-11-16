-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 7. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


SELECT n.nspname AS schema_name,r.rolname AS caller,
       pg_catalog.has_schema_privilege(r.oid,n.oid,'USAGE') AS can_use,
       pg_catalog.has_schema_privilege(r.oid,n.oid,'CREATE') AS can_create
FROM pg_catalog.pg_namespace n CROSS JOIN pg_catalog.pg_roles r
WHERE n.nspname IN ('api','private','public','extensions') AND r.rolname IN
 ('anon','authenticated','service_role','gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
ORDER BY 1,2;
ROLLBACK;
