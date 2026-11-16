-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 14. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


SELECT n.nspname AS schema_name,c.relname AS relation,k.conname AS constraint_name,
       k.contype AS type,k.convalidated AS validated
FROM pg_catalog.pg_constraint k JOIN pg_catalog.pg_class c ON c.oid=k.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='private' ORDER BY 1,2,3;
ROLLBACK;
