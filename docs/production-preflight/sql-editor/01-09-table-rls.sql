-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 9. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


SELECT n.nspname AS schema_name,c.relname AS relation,c.relkind,
       pg_catalog.pg_get_userbyid(c.relowner) AS owner,
       c.relrowsecurity AS rls_enabled,c.relforcerowsecurity AS rls_forced,
       pg_catalog.row_security_active(c.oid) AS rls_filters_current_role
FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE c.relkind IN ('r','p') AND (n.nspname IN ('api','private')
 OR (n.nspname='public' AND c.relname='gym_settings')) ORDER BY 1,2;
ROLLBACK;
