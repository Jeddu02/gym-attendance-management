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
WITH expected(index_name,parent_name,definition) AS (VALUES
('private.members_status_idx','private.members','create index members_status_idx on private . members using btree ( status )'),
('private.audit_events_created_at_idx','private.audit_events','create index audit_events_created_at_idx on private . audit_events using btree ( created_at desc )'),
('private.audit_events_actor_created_idx','private.audit_events','create index audit_events_actor_created_idx on private . audit_events using btree ( actor_user_id , created_at desc )'),
('private.membership_purchases_member_idx','private.membership_purchases','create index membership_purchases_member_idx on private . membership_purchases using btree ( member_id , created_at desc )'),
('private.membership_purchases_plan_idx','private.membership_purchases','create index membership_purchases_plan_idx on private . membership_purchases using btree ( plan_id )'),
('private.payment_allocations_membership_idx','private.payment_allocations','create index payment_allocations_membership_idx on private . payment_allocations using btree ( membership_purchase_id ) where membership_purchase_id is not null'),
('private.payment_allocations_walkin_idx','private.payment_allocations','create index payment_allocations_walkin_idx on private . payment_allocations using btree ( walkin_request_id ) where walkin_request_id is not null'),
('private.payment_events_payment_created_idx','private.payment_events','create index payment_events_payment_created_idx on private . payment_events using btree ( payment_id , created_at )'),
('private.payment_corrections_payment_idx','private.payment_corrections','create index payment_corrections_payment_idx on private . payment_corrections using btree ( payment_id , proposed_at desc )'),
('private.attendance_one_member_valid_checkin_per_day','private.attendance_checkins','create unique index attendance_one_member_valid_checkin_per_day on private . attendance_checkins using btree ( member_id , gym_local_date ) where member_id is not null and attendance_status = ''valid'''),
('private.attendance_one_checkin_per_walkin','private.attendance_checkins','create unique index attendance_one_checkin_per_walkin on private . attendance_checkins using btree ( walkin_request_id ) where walkin_request_id is not null'),
('private.attendance_date_idx','private.attendance_checkins','create index attendance_date_idx on private . attendance_checkins using btree ( gym_local_date desc )'),
('private.attendance_member_date_idx','private.attendance_checkins','create index attendance_member_date_idx on private . attendance_checkins using btree ( member_id , gym_local_date desc ) where member_id is not null'),
('private.member_pin_setup_tokens_member_idx','private.member_pin_setup_tokens','create index member_pin_setup_tokens_member_idx on private . member_pin_setup_tokens using btree ( member_id , created_at desc )'),
('private.member_pin_setup_tokens_expiry_idx','private.member_pin_setup_tokens','create index member_pin_setup_tokens_expiry_idx on private . member_pin_setup_tokens using btree ( expires_at ) where consumed_at is null'),
('private.pin_attempt_buckets_blocked_idx','private.pin_attempt_buckets','create index pin_attempt_buckets_blocked_idx on private . pin_attempt_buckets using btree ( blocked_until ) where blocked_until is not null'),
('private.cash_drawer_only_one_open_session','private.cash_drawer_sessions','create unique index cash_drawer_only_one_open_session on private . cash_drawer_sessions using btree ( ( session_status ) ) where session_status = ''open'''),
('private.cash_reconciliations_date_idx','private.cash_reconciliations','create index cash_reconciliations_date_idx on private . cash_reconciliations using btree ( reconciled_at desc )'),
('private.cash_adjustments_reconciliation_idx','private.cash_reconciliation_adjustments','create index cash_adjustments_reconciliation_idx on private . cash_reconciliation_adjustments using btree ( reconciliation_id , created_at )'),
('private.audit_events_stream_created_idx','private.audit_events','create index audit_events_stream_created_idx on private . audit_events using btree ( stream_key , created_at , id )'),
('private.member_pin_setup_tokens_active_enrollment_idx','private.member_pin_setup_tokens','create index member_pin_setup_tokens_active_enrollment_idx on private . member_pin_setup_tokens using btree ( member_id ) where token_purpose = ''enrollment'' and consumed_at is null'),
('private.pin_enrollment_global_rate_limit_events_requested_at_idx','private.pin_enrollment_global_rate_limit_events','create index pin_enrollment_global_rate_limit_events_requested_at_idx on private . pin_enrollment_global_rate_limit_events using btree ( requested_at )'),
('private.membership_plans_normalized_name_uidx','private.membership_plans','create unique index membership_plans_normalized_name_uidx on private . membership_plans using btree ( pg_catalog . lower ( pg_catalog . btrim ( pg_catalog . regexp_replace ( name , ''\s+'' , '' '' , ''g'' ) ) ) )'),
('private.payment_records_operation_id_uidx','private.payment_records','create unique index payment_records_operation_id_uidx on private . payment_records using btree ( operation_id )'),
('private.payment_records_membership_idx','private.payment_records','create index payment_records_membership_idx on private . payment_records using btree ( target_membership_purchase_id , created_at desc ) where target_membership_purchase_id is not null'),
('private.payment_records_membership_external_reference_uidx','private.payment_records','create unique index payment_records_membership_external_reference_uidx on private . payment_records using btree ( payment_method , pg_catalog . lower ( pg_catalog . btrim ( external_reference ) ) ) where target_membership_purchase_id is not null and nullif ( pg_catalog . btrim ( external_reference ) , '''' ) is not null'),
('private.payment_records_pending_membership_uidx','private.payment_records','create unique index payment_records_pending_membership_uidx on private . payment_records using btree ( target_membership_purchase_id ) where target_membership_purchase_id is not null and verification_status = ''recorded'''),
('private.payment_allocations_membership_purchase_uidx','private.payment_allocations','create unique index payment_allocations_membership_purchase_uidx on private . payment_allocations using btree ( membership_purchase_id ) where membership_purchase_id is not null'))
SELECT e.index_name,i.indexrelid IS NOT NULL identity_exists,
 COALESCE(i.indrelid=to_regclass(e.parent_name) AND i.indisvalid AND i.indisready AND i.indislive,false) structural_flags_match,
 (SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_indexdef(i.indexrelid,0,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal)) IS NOT DISTINCT FROM e.definition exact_source_definition_matches
FROM expected e LEFT JOIN pg_index i ON i.indexrelid=to_regclass(e.index_name) ORDER BY 1;
ROLLBACK;
