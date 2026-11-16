-- Structural metadata only. Run separately after protected preflight.
BEGIN READ ONLY;
SET LOCAL search_path=pg_catalog;
SET LOCAL statement_timeout='15s';
SELECT 1 / CASE WHEN current_database()='gymforce_pg18_test'
 AND inet_server_addr()='127.0.0.1'::inet AND inet_server_port()=55432
 AND current_user='postgres' AND session_user='postgres'
 AND (SELECT rolsuper FROM pg_roles WHERE rolname=current_user)
 AND current_setting('gymforce.test_cluster_marker',true)='f497fabb-a12f-4068-b745-8b0729279276'
 AND (pg_control_system()).system_identifier::text='7704603813616068820'
 AND lower(rtrim(replace(current_setting('data_directory'),E'\\','/'),'/'))='c:/users/banco-sual/appdata/local/gymforce-pg18-test/data'
 THEN 1 ELSE 0 END AS identity_guard \gset
WITH expected(table_name,constraint_name,definition) AS (VALUES
('private.attendance_checkins','attendance_exactly_one_subject','check ( ( member_id is not null ) <> ( walkin_request_id is not null ) )'),
('private.attendance_checkins','attendance_status_valid','check ( attendance_status in ( ''valid'' , ''invalidated_payment'' , ''invalidated_correction'' , ''review'' ) )'),
('private.attendance_validity_resolutions','attendance_resolution_reason_not_blank','check ( length ( trim ( reason ) ) > 0 )'),
('private.attendance_validity_resolutions','attendance_resolution_status_valid','check ( prior_status in ( ''valid'' , ''invalidated_payment'' , ''invalidated_correction'' , ''review'' ) and new_status in ( ''valid'' , ''invalidated_payment'' , ''invalidated_correction'' , ''review'' ) )'),
('private.audit_chain_heads','audit_chain_stream_not_blank','check ( length ( trim ( stream_key ) ) > 0 )'),
('private.audit_chain_heads','audit_chain_head_consistent','check ( ( last_event_id is null and last_event_hash is null ) or ( last_event_id is not null and last_event_hash is not null ) )'),
('private.audit_events','audit_event_type_not_blank','check ( length ( trim ( event_type ) ) > 0 )'),
('private.audit_events','audit_subject_type_not_blank','check ( length ( trim ( subject_type ) ) > 0 )'),
('private.cash_drawer_sessions','cash_opening_float_nonnegative','check ( opening_float_php >= 0 )'),
('private.cash_drawer_sessions','cash_drawer_status_valid','check ( session_status in ( ''open'' , ''closed'' ) )'),
('private.cash_drawer_sessions','cash_drawer_close_consistent','check ( ( session_status = ''open'' and closed_at is null and closed_by is null ) or ( session_status = ''closed'' and closed_at is not null and closed_by is not null ) )'),
('private.cash_reconciliation_adjustments','cash_adjustment_nonzero','check ( amount_delta_php <> 0 )'),
('private.cash_reconciliation_adjustments','cash_adjustment_reason_not_blank','check ( length ( trim ( reason ) ) > 0 )'),
('private.cash_reconciliations','reconciliation_expected_cash_nonnegative','check ( expected_cash_php >= 0 )'),
('private.cash_reconciliations','reconciliation_counted_cash_nonnegative','check ( counted_cash_php >= 0 )'),
('private.member_pin_credentials','member_pin_hash_not_blank','check ( length ( trim ( password_hash ) ) > 0 )'),
('private.member_pin_credentials','member_pin_version_positive','check ( credential_version > 0 )'),
('private.member_pin_setup_tokens','pin_token_hash_not_blank','check ( length ( trim ( token_hash ) ) > 0 )'),
('private.member_pin_setup_tokens','pin_token_purpose_valid','check ( token_purpose in ( ''enrollment'' , ''reset'' ) )'),
('private.member_pin_setup_tokens','pin_token_expiry_after_creation','check ( expires_at > created_at )'),
('private.members','members_code_not_blank','check ( length ( trim ( member_code ) ) > 0 )'),
('private.members','members_name_not_blank','check ( length ( trim ( full_name ) ) > 0 )'),
('private.members','members_mobile_lookup_hash_not_empty','check ( octet_length ( mobile_lookup_hash ) > 0 )'),
('private.members','members_mobile_encrypted_not_empty','check ( octet_length ( mobile_encrypted ) > 0 )'),
('private.members','members_status_valid','check ( status in ( ''pending'' , ''active'' , ''suspended'' ) )'),
('private.membership_plans','membership_plan_name_not_blank','check ( length ( trim ( name ) ) > 0 )'),
('private.membership_plans','membership_plan_price_positive','check ( price_php > 0 )'),
('private.membership_purchases','membership_purchase_price_positive','check ( price_php > 0 )'),
('private.membership_purchases','membership_purchase_status_valid','check ( purchase_status in ( ''pending_payment'' , ''pending_activation'' , ''active'' , ''expired'' , ''payment_review'' ) )'),
('private.membership_purchases','membership_purchase_dates_consistent','check ( ( activation_date is null and expiry_date is null ) or ( activation_date is not null and expiry_date is not null and expiry_date >= activation_date ) )'),
('private.owner_access','owner_access_deactivation_consistent','check ( ( is_active and deactivated_at is null ) or ( not is_active ) )'),
('private.payment_allocations','payment_allocation_exactly_one_target','check ( ( membership_purchase_id is not null ) <> ( walkin_request_id is not null ) )'),
('private.payment_corrections','payment_correction_reason_not_blank','check ( length ( trim ( reason ) ) > 0 )'),
('private.payment_corrections','payment_correction_amount_valid','check ( proposed_amount_php is null or proposed_amount_php > 0 )'),
('private.payment_corrections','payment_correction_method_valid','check ( proposed_payment_method is null or proposed_payment_method in ( ''cash'' , ''gcash'' , ''bank_transfer'' ) )'),
('private.payment_corrections','payment_correction_status_valid','check ( correction_status in ( ''proposed'' , ''approved'' , ''rejected'' , ''withdrawn'' ) )'),
('private.payment_events','payment_event_type_not_blank','check ( length ( trim ( event_type ) ) > 0 )'),
('private.payment_records','payment_amount_positive','check ( amount_php > 0 )'),
('private.payment_records','payment_method_valid','check ( payment_method in ( ''cash'' , ''gcash'' , ''bank_transfer'' ) )'),
('private.payment_records','payment_verification_status_valid','check ( verification_status in ( ''recorded'' , ''confirmed'' , ''rejected'' , ''confirmation_voided_in_error'' ) )'),
('private.pin_attempt_buckets','pin_bucket_type_valid','check ( bucket_type in ( ''member_identifier'' , ''trusted_network'' ) )'),
('private.pin_attempt_buckets','pin_identifier_digest_not_blank','check ( length ( trim ( identifier_digest ) ) > 0 )'),
('private.pin_attempt_buckets','pin_failed_attempts_nonnegative','check ( failed_attempts >= 0 )'),
('private.walkin_fee_versions','walkin_fee_positive','check ( fee_php > 0 )'),
('private.walkin_fee_versions','walkin_fee_currency_php','check ( currency = ''PHP'' )'),
('private.walkin_requests','walkin_request_fee_positive','check ( fee_php > 0 )'),
('private.walkin_requests','walkin_request_currency_php','check ( currency = ''PHP'' )'),
('private.walkin_requests','walkin_request_expiry_after_creation','check ( expires_at > created_at )'),
('private.walkin_requests','walkin_request_status_valid','check ( request_status in ( ''pending'' , ''confirmed'' , ''expired'' , ''payment_review'' , ''rejected'' ) )'),
('private.walkin_requests','walkin_confirmation_consistent','check ( ( request_status = ''confirmed'' and confirmed_by is not null and confirmed_at is not null ) or ( request_status <> ''confirmed'' ) )'),
('public.gym_settings','gym_settings_key_not_blank','check ( length ( trim ( setting_key ) ) > 0 )'))
SELECT e.table_name,e.constraint_name,k.oid IS NOT NULL identity_exists,
 COALESCE(k.contype='c' AND k.convalidated AND NOT k.condeferrable AND NOT k.condeferred,false) structural_flags_match,
 (SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_constraintdef(k.oid,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal)) IS NOT DISTINCT FROM e.definition exact_source_definition_matches
FROM expected e LEFT JOIN pg_constraint k ON k.conrelid=to_regclass(e.table_name) AND k.conname=e.constraint_name ORDER BY 1,2;
ROLLBACK;
