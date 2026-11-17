-- OWNER REVIEW COPY. Owner-only aggregate booleans, no names/IDs/counts.
-- Requires baseline members + membership_plans columns from 01; no application
-- routine is executed. Permission/schema/timeouts mean UNKNOWN; never grant access.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
WITH visibility AS (
 SELECT bool_and(pg_catalog.has_table_privilege(current_user,c.oid,'SELECT')
  AND NOT pg_catalog.row_security_active(c.oid)) AND count(*)=2 AS complete
 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' AND c.relname IN ('members','membership_plans') AND c.relkind IN ('r','p')
), facts AS (
 SELECT NOT EXISTS(SELECT 1 FROM private.members WHERE
   (status='active' AND approved_at IS NULL) OR (status='pending' AND approved_at IS NOT NULL)
   OR approved_at>pg_catalog.clock_timestamp()) AS registration_consistent,
 NOT EXISTS(SELECT 1 FROM private.membership_plans GROUP BY
   lower(btrim(regexp_replace(name,'\s+',' ','g'))) HAVING count(*)>1) AS plan_names_unique
)
SELECT x.check_name,CASE WHEN v.complete IS DISTINCT FROM true THEN 'UNKNOWN'
 WHEN x.ok THEN 'PASS' ELSE 'FAIL' END AS result
FROM visibility v CROSS JOIN facts f CROSS JOIN LATERAL (VALUES
 ('registration_state',f.registration_consistent),('normalized_plan_name_uniqueness',f.plan_names_unique)) x(check_name,ok);

-- Additional explicit blocker in 20261110170000: ANY legacy drawer session
-- causes that migration to refuse. Do not delete/close sessions to bypass it.
SELECT 'cash_procedure_legacy_session_gate' AS check_name,
 CASE WHEN NOT pg_catalog.has_table_privilege(current_user,'private.cash_drawer_sessions','SELECT')
   OR pg_catalog.row_security_active('private.cash_drawer_sessions'::regclass) THEN 'UNKNOWN'
 WHEN EXISTS(SELECT 1 FROM private.cash_drawer_sessions) THEN 'FAIL' ELSE 'PASS' END AS result;
ROLLBACK;
