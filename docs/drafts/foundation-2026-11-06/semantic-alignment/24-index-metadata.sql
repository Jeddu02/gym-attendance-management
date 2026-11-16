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
WITH expected(index_name,parent_name,key_position,column_name,type_name,opclass_name,options,is_unique,key_count) AS (VALUES
('private.members_status_idx','private.members',1,'status','text','text_ops',0,false,1),
('private.audit_events_created_at_idx','private.audit_events',1,'created_at','timestamp with time zone','timestamptz_ops',3,false,1),
('private.audit_events_actor_created_idx','private.audit_events',1,'actor_user_id','uuid','uuid_ops',0,false,2),
('private.audit_events_actor_created_idx','private.audit_events',2,'created_at','timestamp with time zone','timestamptz_ops',3,false,2),
('private.membership_purchases_member_idx','private.membership_purchases',1,'member_id','uuid','uuid_ops',0,false,2),
('private.membership_purchases_member_idx','private.membership_purchases',2,'created_at','timestamp with time zone','timestamptz_ops',3,false,2),
('private.membership_purchases_plan_idx','private.membership_purchases',1,'plan_id','uuid','uuid_ops',0,false,1),
('private.payment_allocations_membership_idx','private.payment_allocations',1,'membership_purchase_id','uuid','uuid_ops',0,false,1),
('private.payment_allocations_walkin_idx','private.payment_allocations',1,'walkin_request_id','uuid','uuid_ops',0,false,1),
('private.payment_events_payment_created_idx','private.payment_events',1,'payment_id','uuid','uuid_ops',0,false,2),
('private.payment_events_payment_created_idx','private.payment_events',2,'created_at','timestamp with time zone','timestamptz_ops',0,false,2),
('private.payment_corrections_payment_idx','private.payment_corrections',1,'payment_id','uuid','uuid_ops',0,false,2),
('private.payment_corrections_payment_idx','private.payment_corrections',2,'proposed_at','timestamp with time zone','timestamptz_ops',3,false,2),
('private.attendance_one_member_valid_checkin_per_day','private.attendance_checkins',1,'member_id','uuid','uuid_ops',0,true,2),
('private.attendance_one_member_valid_checkin_per_day','private.attendance_checkins',2,'gym_local_date','date','date_ops',0,true,2),
('private.attendance_one_checkin_per_walkin','private.attendance_checkins',1,'walkin_request_id','uuid','uuid_ops',0,true,1),
('private.attendance_date_idx','private.attendance_checkins',1,'gym_local_date','date','date_ops',3,false,1),
('private.attendance_member_date_idx','private.attendance_checkins',1,'member_id','uuid','uuid_ops',0,false,2),
('private.attendance_member_date_idx','private.attendance_checkins',2,'gym_local_date','date','date_ops',3,false,2),
('private.member_pin_setup_tokens_member_idx','private.member_pin_setup_tokens',1,'member_id','uuid','uuid_ops',0,false,2),
('private.member_pin_setup_tokens_member_idx','private.member_pin_setup_tokens',2,'created_at','timestamp with time zone','timestamptz_ops',3,false,2),
('private.member_pin_setup_tokens_expiry_idx','private.member_pin_setup_tokens',1,'expires_at','timestamp with time zone','timestamptz_ops',0,false,1),
('private.pin_attempt_buckets_blocked_idx','private.pin_attempt_buckets',1,'blocked_until','timestamp with time zone','timestamptz_ops',0,false,1),
('private.cash_drawer_only_one_open_session','private.cash_drawer_sessions',1,'session_status','text','text_ops',0,true,1),
('private.cash_reconciliations_date_idx','private.cash_reconciliations',1,'reconciled_at','timestamp with time zone','timestamptz_ops',3,false,1),
('private.cash_adjustments_reconciliation_idx','private.cash_reconciliation_adjustments',1,'reconciliation_id','uuid','uuid_ops',0,false,2),
('private.cash_adjustments_reconciliation_idx','private.cash_reconciliation_adjustments',2,'created_at','timestamp with time zone','timestamptz_ops',0,false,2),
('private.audit_events_stream_created_idx','private.audit_events',1,'stream_key','text','text_ops',0,false,3),
('private.audit_events_stream_created_idx','private.audit_events',2,'created_at','timestamp with time zone','timestamptz_ops',0,false,3),
('private.audit_events_stream_created_idx','private.audit_events',3,'id','bigint','int8_ops',0,false,3),
('private.member_pin_setup_tokens_active_enrollment_idx','private.member_pin_setup_tokens',1,'member_id','uuid','uuid_ops',0,false,1),
('private.pin_enrollment_global_rate_limit_events_requested_at_idx','private.pin_enrollment_global_rate_limit_events',1,'requested_at','timestamp with time zone','timestamptz_ops',0,false,1),
('private.membership_plans_normalized_name_uidx','private.membership_plans',1,'','text','text_ops',0,true,1),
('private.payment_records_operation_id_uidx','private.payment_records',1,'operation_id','uuid','uuid_ops',0,true,1),
('private.payment_records_membership_idx','private.payment_records',1,'target_membership_purchase_id','uuid','uuid_ops',0,false,2),
('private.payment_records_membership_idx','private.payment_records',2,'created_at','timestamp with time zone','timestamptz_ops',3,false,2),
('private.payment_records_membership_external_reference_uidx','private.payment_records',1,'payment_method','text','text_ops',0,true,2),
('private.payment_records_membership_external_reference_uidx','private.payment_records',2,'','text','text_ops',0,true,2),
('private.payment_records_pending_membership_uidx','private.payment_records',1,'target_membership_purchase_id','uuid','uuid_ops',0,true,1),
('private.payment_allocations_membership_purchase_uidx','private.payment_allocations',1,'membership_purchase_id','uuid','uuid_ops',0,true,1))
SELECT e.index_name,e.key_position,
 COALESCE(i.indrelid=to_regclass(e.parent_name) AND i.indisvalid AND i.indisready AND i.indislive AND i.indisunique=e.is_unique AND NOT i.indisprimary AND NOT i.indisexclusion AND i.indimmediate AND NOT i.indnullsnotdistinct AND i.indnkeyatts=e.key_count AND i.indnatts=e.key_count,false) index_flags_match,
 COALESCE(i.indkey[e.key_position-1]=CASE WHEN e.column_name='' THEN 0 ELSE a.attnum END,false) key_identity_matches,
 COALESCE(ka.atttypid=to_regtype(e.type_name),false) key_type_matches,
 COALESCE(o.opcname=e.opclass_name AND ns.nspname='pg_catalog' AND am.amname='btree' AND o.opcdefault,false) default_operator_class_matches,
 COALESCE(i.indoption[e.key_position-1]=e.options,false) key_order_nulls_match,
 COALESCE(i.indcollation[e.key_position-1]=CASE WHEN e.type_name='text' THEN 'pg_catalog."default"'::regcollation::oid ELSE 0::oid END,false) collation_matches
FROM expected e LEFT JOIN pg_index i ON i.indexrelid=to_regclass(e.index_name)
LEFT JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attname=e.column_name AND a.attnum>0 AND NOT a.attisdropped
LEFT JOIN pg_attribute ka ON ka.attrelid=i.indexrelid AND ka.attnum=e.key_position AND NOT ka.attisdropped
LEFT JOIN pg_opclass o ON o.oid=i.indclass[e.key_position-1]
LEFT JOIN pg_namespace ns ON ns.oid=o.opcnamespace
LEFT JOIN pg_am am ON am.oid=o.opcmethod
ORDER BY 1,2;
ROLLBACK;
