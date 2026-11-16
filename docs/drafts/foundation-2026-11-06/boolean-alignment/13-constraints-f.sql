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
('private.attendance_checkins','attendance_checkins_member_id_fkey','foreign key ( member_id ) references private . members ( id ) on delete restrict'),
('private.attendance_checkins','attendance_checkins_walkin_request_id_fkey','foreign key ( walkin_request_id ) references private . walkin_requests ( id ) on delete restrict'),
('private.attendance_validity_resolutions','attendance_validity_resolutions_attendance_id_fkey','foreign key ( attendance_id ) references private . attendance_checkins ( id ) on delete restrict'),
('private.attendance_validity_resolutions','attendance_validity_resolutions_resolved_by_fkey','foreign key ( resolved_by ) references auth . users ( id ) on delete restrict'),
('private.audit_events','audit_events_actor_user_id_fkey','foreign key ( actor_user_id ) references auth . users ( id ) on delete restrict'),
('private.cash_drawer_sessions','cash_drawer_sessions_opened_by_fkey','foreign key ( opened_by ) references auth . users ( id ) on delete restrict'),
('private.cash_drawer_sessions','cash_drawer_sessions_closed_by_fkey','foreign key ( closed_by ) references auth . users ( id ) on delete restrict'),
('private.cash_reconciliation_adjustments','cash_reconciliation_adjustments_reconciliation_id_fkey','foreign key ( reconciliation_id ) references private . cash_reconciliations ( id ) on delete restrict'),
('private.cash_reconciliation_adjustments','cash_reconciliation_adjustments_recorded_by_fkey','foreign key ( recorded_by ) references auth . users ( id ) on delete restrict'),
('private.cash_reconciliations','cash_reconciliations_drawer_session_id_fkey','foreign key ( drawer_session_id ) references private . cash_drawer_sessions ( id ) on delete restrict'),
('private.cash_reconciliations','cash_reconciliations_reconciled_by_fkey','foreign key ( reconciled_by ) references auth . users ( id ) on delete restrict'),
('private.member_pin_credentials','member_pin_credentials_member_id_fkey','foreign key ( member_id ) references private . members ( id ) on delete restrict'),
('private.member_pin_setup_tokens','member_pin_setup_tokens_member_id_fkey','foreign key ( member_id ) references private . members ( id ) on delete restrict'),
('private.membership_purchases','membership_purchases_member_id_fkey','foreign key ( member_id ) references private . members ( id ) on delete restrict'),
('private.membership_purchases','membership_purchases_plan_id_fkey','foreign key ( plan_id ) references private . membership_plans ( id ) on delete restrict'),
('private.owner_access','owner_access_user_id_fkey','foreign key ( user_id ) references auth . users ( id ) on delete restrict'),
('private.payment_allocations','payment_allocations_payment_id_fkey','foreign key ( payment_id ) references private . payment_records ( id ) on delete restrict'),
('private.payment_allocations','payment_allocations_membership_purchase_id_fkey','foreign key ( membership_purchase_id ) references private . membership_purchases ( id ) on delete restrict'),
('private.payment_allocations','payment_allocations_allocated_by_fkey','foreign key ( allocated_by ) references auth . users ( id ) on delete restrict'),
('private.payment_allocations','payment_allocations_walkin_request_fk','foreign key ( walkin_request_id ) references private . walkin_requests ( id ) on delete restrict'),
('private.payment_corrections','payment_corrections_payment_id_fkey','foreign key ( payment_id ) references private . payment_records ( id ) on delete restrict'),
('private.payment_corrections','payment_corrections_proposed_by_fkey','foreign key ( proposed_by ) references auth . users ( id ) on delete restrict'),
('private.payment_corrections','payment_corrections_decided_by_fkey','foreign key ( decided_by ) references auth . users ( id ) on delete restrict'),
('private.payment_events','payment_events_payment_id_fkey','foreign key ( payment_id ) references private . payment_records ( id ) on delete restrict'),
('private.payment_events','payment_events_actor_user_id_fkey','foreign key ( actor_user_id ) references auth . users ( id ) on delete restrict'),
('private.payment_records','payment_records_recorded_by_fkey','foreign key ( recorded_by ) references auth . users ( id ) on delete restrict'),
('private.payment_records','payment_records_target_membership_purchase_id_fkey','foreign key ( target_membership_purchase_id ) references private . membership_purchases ( id ) on delete restrict'),
('private.walkin_fee_versions','walkin_fee_versions_created_by_fkey','foreign key ( created_by ) references auth . users ( id ) on delete restrict'),
('private.walkin_requests','walkin_requests_fee_version_id_fkey','foreign key ( fee_version_id ) references private . walkin_fee_versions ( id ) on delete restrict'),
('private.walkin_requests','walkin_requests_confirmed_by_fkey','foreign key ( confirmed_by ) references auth . users ( id ) on delete restrict'))
SELECT e.table_name,e.constraint_name,k.oid IS NOT NULL identity_exists,
 COALESCE(k.contype='f' AND k.convalidated AND NOT k.condeferrable AND NOT k.condeferred,false) structural_flags_match,
 (SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_constraintdef(k.oid,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal)) IS NOT DISTINCT FROM e.definition exact_source_definition_matches
FROM expected e LEFT JOIN pg_constraint k ON k.conrelid=to_regclass(e.table_name) AND k.conname=e.constraint_name ORDER BY 1,2;
ROLLBACK;
