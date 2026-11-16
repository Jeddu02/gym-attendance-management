-- OWNER REVIEW REQUIRED. Prepared only; no production execution authorized here.
-- Source: ../02-unrecorded-object-markers.sql, result set 1. SELECT text preserved exactly.
-- Run the entire file separately only after approval; retain the final ROLLBACK.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;

WITH expected(version,kind,object_name,column_name) AS (VALUES
 ('20261103080000','routine_name','api.owner_list_membership_plans',''),
 ('20261103080000','routine_name','api.owner_save_membership_plan',''),
 ('20261103100000','routine_name','api.owner_create_membership_purchase',''),
 ('20261103110000','routine_name','api.owner_list_membership_purchases',''),
 ('20261103120000','routine_name','private.guard_membership_payment_record_insert',''),
 ('20261103120000','routine_name','private.guard_membership_payment_record_update',''),
 ('20261103120000','routine_name','private.guard_membership_payment_allocation',''),
 ('20261103120000','routine_name','private.prevent_payment_history_mutation',''),
 ('20261103120000','routine_name','private.guard_purchase_pending_activation',''),
 ('20261103120000','routine_name','api.owner_record_membership_payment',''),
 ('20261103120000','routine_name','api.owner_confirm_membership_payment',''),
 ('20261103120000','routine_name','api.owner_reject_membership_payment',''),
 ('20261103120000','routine_name','api.owner_list_membership_payments',''),
 ('20261103120000','routine_name','api.owner_list_membership_purchases',''),
 ('20261103120000','column','private.payment_records','operation_id'),
 ('20261110110000','routine_name','private.membership_inclusive_expiry',''),
 ('20261110110000','routine_name','private.membership_payment_confirmed_at',''),
 ('20261110110000','routine_name','private.membership_activation_dates',''),
 ('20261110110000','routine_name','private.guard_member_registration_approval',''),
 ('20261110110000','routine_name','private.guard_membership_lifecycle',''),
 ('20261110110000','routine_name','api.owner_approve_member',''),
 ('20261110110000','routine_name','api.owner_activate_membership_purchase',''),
 ('20261110120000','routine_name','api.owner_dashboard_summary',''),
 ('20261110120000','routine_name','api.owner_list_audit_events',''),
 ('20261110130000','routine_name','api.owner_create_verified_pin_enrollment_token',''),
 ('20261110130000','routine_name','api.owner_create_pin_recovery_token',''),
 ('20261110130000','routine_name','api.member_reset_pin',''),
 ('20261110130000','routine_name','api.member_enroll_pin',''),
 ('20261110140000','routine_name','private.prevent_walkin_history_mutation',''),
 ('20261110140000','routine_name','private.guard_walkin_request_snapshot',''),
 ('20261110140000','routine_name','private.guard_walkin_allocation',''),
 ('20261110140000','routine_name','private.guard_paid_walkin_attendance',''),
 ('20261110140000','routine_name','private.guard_walkin_receipt_review',''),
 ('20261110140000','routine_name','api.owner_set_walkin_fee',''),
 ('20261110140000','routine_name','api.public_create_walkin_request',''),
 ('20261110140000','routine_name','api.owner_list_walkin_requests',''),
 ('20261110140000','routine_name','api.owner_confirm_walkin',''),
 ('20261110140000','relation','private.walkin_request_rate_events',''),
 ('20261110140000','relation','private.receipt_review',''),
 ('20261110140000','column','private.walkin_requests','requested_payment_method'),
 ('20261110150000','routine_name','private.member_checkin_eligible_purchase',''),
 ('20261110150000','routine_name','private.guard_member_attendance_basis',''),
 ('20261110150000','routine_name','api.reserve_member_checkin_request',''),
 ('20261110150000','routine_name','api.prepare_member_checkin',''),
 ('20261110150000','routine_name','api.commit_member_checkin',''),
 ('20261110150000','relation','private.member_checkin_rate_events',''),
 ('20261110150000','column','private.attendance_checkins','membership_purchase_id'),
 ('20261110153000','routine_name','api.owner_list_attendance',''),
 ('20261110160000','routine_name','private.assert_receipt_review_owner',''),
 ('20261110160000','routine_name','private.is_receipt_verified',''),
 ('20261110160000','routine_name','api.owner_verify_actual_receipt',''),
 ('20261110160000','routine_name','api.owner_record_actual_receipt',''),
 ('20261110160000','routine_name','api.owner_list_receipt_review',''),
 ('20261110160000','routine_name','private.guard_membership_payment_record_update',''),
 ('20261110160000','routine_name','private.guard_membership_lifecycle',''),
 ('20261110160000','routine_name','private.guard_attendance_payment_invalidation',''),
 ('20261110160000','routine_name','api.owner_void_payment_confirmation',''),
 ('20261110160000','routine_name','private.membership_activation_dates',''),
 ('20261110160000','relation','private.receipt_verifications',''),
 ('20261110160000','relation','private.payment_confirmation_voids',''),
 ('20261110160000','relation','private.receipt_verification_voids',''),
 ('20261110160000','relation','private.receipt_replacement_links',''),
 ('20261110170000','routine_name','private.guard_cash_session',''),
 ('20261110170000','routine_name','api.owner_open_cash_drawer',''),
 ('20261110170000','routine_name','api.owner_close_cash_drawer',''),
 ('20261110170000','routine_name','api.owner_list_cash_drawers',''),
 ('20261110170000','relation','private.cash_reconciliation_receipts',''),
 ('20261110170000','column','private.cash_drawer_sessions','business_date'),
 ('20261110170000','column','private.cash_drawer_sessions','operation_id'),
 ('20261110170000','column','private.cash_reconciliations','reason'),
 ('20261110170000','column','private.cash_reconciliations','evidence_reference'),
 ('20261110180000','routine_name','api.owner_submit_attendance_claim',''),
 ('20261110180000','routine_name','api.owner_resolve_attendance_claim',''),
 ('20261110180000','routine_name','api.owner_list_attendance_claims',''),
 ('20261110180000','relation','private.owner_attendance_claims',''),
 ('20261110180000','relation','private.owner_claim_resolutions',''),
 ('20261110190000','routine_name','private.receipt_membership_target_matches',''),
 ('20261110190000','routine_name','api.owner_allocate_verified_receipt',''),
 ('20261110190000','routine_name','private.guard_membership_payment_allocation',''),
 ('20261110190000','routine_name','private.guard_purchase_pending_activation',''),
 ('20261110190000','routine_name','private.membership_payment_confirmed_at',''),
 ('20261110190000','routine_name','private.member_checkin_eligible_purchase',''),
 ('20261110190000','routine_name','api.owner_dashboard_summary',''),
 ('20261110190000','routine_name','private.guard_walkin_allocation',''),
 ('20261110190000','routine_name','api.owner_list_membership_payments',''),
 ('20261110190000','routine_name','api.owner_list_membership_purchases',''),
 ('20261110190000','relation','private.receipt_allocation_reviews',''),
 ('20261110200000','routine_name','api.owner_income_report',''),
 ('20261110200000','routine_name','api.owner_expiry_reminders',''),
 ('20261110200000','routine_name','api.owner_list_payable_purchases',''),
 ('20261103120000','column','private.payment_records','target_membership_purchase_id')
), observed AS (
 SELECT e.*,EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations h WHERE h.version::text=e.version) AS history_recorded,
 CASE WHEN e.kind='routine_name' THEN EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname=split_part(e.object_name,'.',1) AND p.proname=split_part(e.object_name,'.',2) AND p.prokind='f')
 WHEN e.kind='relation' THEN EXISTS(SELECT 1 FROM pg_catalog.pg_class c WHERE c.oid=pg_catalog.to_regclass(e.object_name) AND c.relkind IN ('r','p'))
 ELSE EXISTS(SELECT 1 FROM pg_catalog.pg_attribute a WHERE a.attrelid=pg_catalog.to_regclass(e.object_name)
  AND a.attname=e.column_name AND a.attnum>0 AND NOT a.attisdropped) END AS object_present
 FROM expected e
)
SELECT version,kind,object_name,NULLIF(column_name,'') AS column_name,history_recorded,object_present,
 CASE WHEN history_recorded THEN 'RECORDED: definition still needs verification'
 WHEN object_present THEN 'PRESENT_WITHOUT_HISTORY: older definition or manual drift possible'
 ELSE 'ABSENT_WITHOUT_HISTORY' END AS observation
FROM observed ORDER BY version,kind,object_name,column_name;
ROLLBACK;
