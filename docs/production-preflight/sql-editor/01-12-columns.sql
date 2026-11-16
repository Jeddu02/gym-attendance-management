-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 12. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


-- No expressions/defaults/trigger arguments are exposed by these inventories.
SELECT n.nspname AS schema_name,c.relname AS relation,a.attname AS column_name,
       pg_catalog.format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull AS not_null
FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_class c ON c.oid=a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE c.relkind IN ('r','p') AND n.nspname='private' AND a.attnum>0 AND NOT a.attisdropped
ORDER BY 1,2,a.attnum;
ROLLBACK;
