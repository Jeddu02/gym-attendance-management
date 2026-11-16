-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 4. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


-- Actual signatures, including unexpected overloads. No prosrc/prosqlbody output.
SELECT n.nspname AS schema_name, p.proname AS routine,
       pg_catalog.pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       pg_catalog.pg_get_function_result(p.oid) AS result_type,
       p.prokind AS kind, l.lanname AS language,
       pg_catalog.pg_get_userbyid(p.proowner) AS owner,
       p.prosecdef AS security_definer, p.provolatile AS volatility,
       COALESCE(p.proconfig @> ARRAY['search_path=""']::text[],false) AS empty_search_path,
       COALESCE(p.proconfig @> ARRAY['TimeZone=UTC']::text[],false) AS explicit_utc
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
JOIN pg_catalog.pg_language l ON l.oid=p.prolang
WHERE n.nspname IN ('api','private') ORDER BY n.nspname,p.proname,p.oid;
ROLLBACK;
