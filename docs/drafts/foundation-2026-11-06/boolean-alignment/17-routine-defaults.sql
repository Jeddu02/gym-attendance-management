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
WITH expected(routine_name,signature,defaults) AS (VALUES
('api.append_audit_event','api.append_audit_event(text, uuid, text, text, text, jsonb)','null , ''{}'' :: jsonb'),
('api.is_active_owner_for_user','api.is_active_owner_for_user(uuid)',''),
('api.member_enroll_pin','api.member_enroll_pin(text, text)',''),
('api.owner_confirm_membership_payment','api.owner_confirm_membership_payment(uuid, uuid, boolean)',''),
('api.owner_create_membership_purchase','api.owner_create_membership_purchase(uuid, uuid, uuid)',''),
('api.owner_create_pin_enrollment_token','api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone)',''),
('api.owner_list_members','api.owner_list_members(uuid, text, text, integer, integer)','null , ''all'' , 50 , 0'),
('api.owner_list_membership_payments','api.owner_list_membership_payments(uuid, text, text, integer, integer)','null , ''all'' , 50 , 0'),
('api.owner_list_membership_plans','api.owner_list_membership_plans(uuid)',''),
('api.owner_list_membership_purchases','api.owner_list_membership_purchases(uuid, text, text, integer, integer)','null , ''all'' , 50 , 0'),
('api.owner_record_membership_payment','api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)','null'),
('api.owner_register_member','api.owner_register_member(uuid, text, bytea, bytea)',''),
('api.owner_reject_membership_payment','api.owner_reject_membership_payment(uuid, uuid, text)',''),
('api.owner_save_membership_plan','api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)',''),
('api.reserve_pin_enrollment_request','api.reserve_pin_enrollment_request()',''),
('api.verify_audit_stream','api.verify_audit_stream(text)',''),
('private.audit_events_chain_insert','private.audit_events_chain_insert()',''),
('private.compute_audit_event_hash','private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone)',''),
('private.guard_membership_payment_allocation','private.guard_membership_payment_allocation()',''),
('private.guard_membership_payment_record_insert','private.guard_membership_payment_record_insert()',''),
('private.guard_membership_payment_record_update','private.guard_membership_payment_record_update()',''),
('private.guard_purchase_pending_activation','private.guard_purchase_pending_activation()',''),
('private.is_active_owner','private.is_active_owner()',''),
('private.prevent_audit_event_mutation','private.prevent_audit_event_mutation()',''),
('private.prevent_payment_history_mutation','private.prevent_payment_history_mutation()',''))
SELECT e.routine_name,p.oid IS NOT NULL identity_exists,
 COALESCE((SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_expr(p.proargdefaults,0,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal)),'')=e.defaults exact_source_defaults_match
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature) ORDER BY 1;
ROLLBACK;
