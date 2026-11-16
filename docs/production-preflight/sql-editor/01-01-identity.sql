-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../01-catalog.sql, result set 1. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;


-- Run through the intended migration connection; SQL Editor may use another role.
SELECT current_user AS effective_role, session_user AS connection_role,
       current_setting('server_version_num') AS postgres_version_number,
       current_setting('transaction_read_only') AS read_only;
ROLLBACK;
