-- Draft Owner-only aggregate diagnostics. Missing prerequisites/visibility = UNKNOWN, never repair data.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
DO $visibility$
DECLARE name text; target regclass;
BEGIN
 FOREACH name IN ARRAY ARRAY['payment_allocations','membership_purchases','attendance_checkins','walkin_requests'] LOOP
  target:=to_regclass('private.'||name);
  IF target IS NULL OR NOT has_table_privilege(current_user,target,'SELECT')
   OR row_security_active(target) THEN RAISE EXCEPTION 'UNKNOWN: complete diagnostic visibility required'; END IF;
 END LOOP;
END $visibility$;
SELECT check_name,CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS result FROM (VALUES
 ('walkin_allocation_uniqueness',NOT EXISTS(SELECT 1 FROM private.payment_allocations
  WHERE walkin_request_id IS NOT NULL GROUP BY walkin_request_id HAVING count(*)>1)),
 ('dated_payment_review_terms',NOT EXISTS(SELECT 1 FROM private.membership_purchases
  WHERE purchase_status='payment_review' AND activation_date IS NOT NULL)),
 ('replacement_overlap_predicate',NOT EXISTS(SELECT 1 FROM private.membership_purchases a
  JOIN private.membership_purchases b ON a.member_id=b.member_id AND a.id<b.id
  WHERE a.activation_date IS NOT NULL AND a.expiry_date IS NOT NULL AND a.purchase_status<>'payment_review'
  AND b.activation_date IS NOT NULL AND b.expiry_date IS NOT NULL AND b.purchase_status<>'payment_review'
  AND daterange(a.activation_date,a.expiry_date,'[]') && daterange(b.activation_date,b.expiry_date,'[]'))),
 ('legacy_member_attendance_basis',NOT EXISTS(SELECT 1 FROM private.attendance_checkins
  WHERE member_id IS NOT NULL AND membership_purchase_id IS NULL)),
 ('legacy_walkin_method_snapshot',NOT EXISTS(SELECT 1 FROM private.walkin_requests
  WHERE requested_payment_method IS NULL))
) x(check_name,ok) ORDER BY 1;
ROLLBACK;
