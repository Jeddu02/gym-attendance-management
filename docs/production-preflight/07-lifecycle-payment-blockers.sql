-- CONDITIONAL OWNER REVIEW COPY. Do not run until 01 confirms payment_records
-- has operation_id and target_membership_purchase_id (introduced by pending
-- 20261103120000). On the reported 20-migration baseline this may be UNRUNNABLE.
-- Do not add columns just to run this check. Missing/denied/timeout = UNKNOWN.
-- These are exact lifecycle preconditions plus unique-index candidate checks;
-- they are not a complete financial reconciliation or a repair operation.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
WITH visibility AS (
 SELECT bool_and(pg_catalog.has_table_privilege(current_user,c.oid,'SELECT')
  AND NOT pg_catalog.row_security_active(c.oid)) AND count(*)=5 AS complete
 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' AND c.relname IN
 ('members','membership_purchases','payment_records','payment_allocations','payment_events') AND c.relkind IN ('r','p')
), facts AS (
 SELECT NOT EXISTS(
  SELECT 1 FROM private.membership_purchases p LEFT JOIN private.members m ON m.id=p.member_id
  WHERE ((p.purchase_status IN ('active','expired')) IS DISTINCT FROM
         (p.activation_date IS NOT NULL AND p.expiry_date IS NOT NULL))
    OR (p.activation_date IS NOT NULL AND p.expiry_date <>
         (p.activation_date::timestamp+interval '1 month')::date-1)
    OR (p.purchase_status IN ('pending_activation','active','expired') AND
       (m.approved_at IS NULL OR NOT EXISTS(
         SELECT 1 FROM private.payment_allocations a JOIN private.payment_records r ON r.id=a.payment_id
         JOIN private.payment_events e ON e.payment_id=r.id AND e.event_type='payment.confirmed'
         WHERE a.membership_purchase_id=p.id AND r.target_membership_purchase_id=p.id
           AND r.verification_status='confirmed' AND r.amount_php=p.price_php)))) AS lifecycle_consistent,
 NOT EXISTS(SELECT 1 FROM private.payment_records WHERE target_membership_purchase_id IS NOT NULL
   AND NULLIF(btrim(external_reference),'') IS NOT NULL
   GROUP BY payment_method,lower(btrim(external_reference)) HAVING count(*)>1) AS payment_references_unique,
 NOT EXISTS(SELECT 1 FROM private.payment_records WHERE target_membership_purchase_id IS NOT NULL
   AND verification_status='recorded' GROUP BY target_membership_purchase_id HAVING count(*)>1) AS pending_attempts_unique,
 NOT EXISTS(SELECT 1 FROM private.payment_allocations WHERE membership_purchase_id IS NOT NULL
   GROUP BY membership_purchase_id HAVING count(*)>1) AS allocations_unique,
 NOT EXISTS(SELECT 1 FROM private.payment_records WHERE operation_id IS NULL)
   AND NOT EXISTS(SELECT 1 FROM private.payment_records GROUP BY operation_id HAVING count(*)>1) AS operation_ids_unique
)
SELECT x.check_name,CASE WHEN v.complete IS DISTINCT FROM true THEN 'UNKNOWN'
 WHEN x.ok THEN 'PASS' ELSE 'FAIL' END AS result
FROM visibility v CROSS JOIN facts f CROSS JOIN LATERAL (VALUES
 ('lifecycle_dates_and_payment_basis',f.lifecycle_consistent),('payment_reference_uniqueness',f.payment_references_unique),
 ('pending_payment_attempt_uniqueness',f.pending_attempts_unique),('purchase_allocation_uniqueness',f.allocations_unique),
 ('payment_operation_ids',f.operation_ids_unique)) x(check_name,ok);
ROLLBACK;
