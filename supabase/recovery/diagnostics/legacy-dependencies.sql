-- OWNER REVIEW REQUIRED. Catalog-only, read-only; never a removal list.
-- Source: recorded 20261030170000 replaces the old aggregate limiter table.
-- The zero-argument RPC is recreated by that file and remains required.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path = pg_catalog;
WITH target AS (
 SELECT to_regclass('private.pin_enrollment_global_rate_limits') AS oid
), findings AS (
 SELECT 'superseded_aggregate_limiter_table' AS check_name,
 CASE WHEN oid IS NULL THEN 'ABSENT_EXPECTED'
      ELSE 'PRESENT_REQUIRES_PRIVATE_REVIEW_NO_REMOVAL_AUTHORIZED' END AS result,
 (SELECT count(*) FROM pg_depend d WHERE d.refclassid='pg_class'::regclass AND d.refobjid=target.oid) AS dependency_count,
 (SELECT count(*) FROM pg_policy p WHERE p.polrelid=target.oid) AS policy_count,
 (SELECT count(*) FROM pg_trigger t WHERE t.tgrelid=target.oid AND NOT t.tgisinternal) AS trigger_count
 FROM target
 UNION ALL
 SELECT 'rolling_limiter_table',
 CASE WHEN to_regclass('private.pin_enrollment_global_rate_limit_events') IS NULL THEN 'MISSING_REQUIRED' ELSE 'PRESENT_DEFINITION_NOT_VERIFIED' END,
 NULL::bigint,NULL::bigint,NULL::bigint
 UNION ALL
 SELECT 'rolling_limiter_rpc',
 CASE WHEN to_regprocedure('api.reserve_pin_enrollment_request()') IS NULL THEN 'MISSING_REQUIRED' ELSE 'PRESENT_DEFINITION_NOT_VERIFIED' END,
 NULL::bigint,NULL::bigint,NULL::bigint
)
SELECT jsonb_agg(to_jsonb(findings) ORDER BY check_name) AS legacy_inventory FROM findings;
ROLLBACK;
