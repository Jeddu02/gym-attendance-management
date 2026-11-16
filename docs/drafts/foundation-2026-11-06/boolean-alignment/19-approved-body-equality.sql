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
WITH expected(name,signature,approved_digest) AS (VALUES
('api.append_audit_event','api.append_audit_event(text, uuid, text, text, text, jsonb)','7a05ca54592137c75b9adda7023516a8'),
('api.is_active_owner_for_user','api.is_active_owner_for_user(uuid)','830f29066e37d9f2593c3cd99878ae93'),
('api.member_enroll_pin','api.member_enroll_pin(text, text)','6bf1d4a963b2b853ba9cdc7cb582c342'),
('api.owner_confirm_membership_payment','api.owner_confirm_membership_payment(uuid, uuid, boolean)','ce58f4473d75469ef2676f232794dce0'),
('api.owner_create_membership_purchase','api.owner_create_membership_purchase(uuid, uuid, uuid)','f8f310bd5576274401706c5213c6746d'),
('api.owner_create_pin_enrollment_token','api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone)','7a226978d83e191643a436c829f9dd07'),
('api.owner_list_members','api.owner_list_members(uuid, text, text, integer, integer)','342dd9a2131e068c1a849694b053ebdf'),
('api.owner_list_membership_payments','api.owner_list_membership_payments(uuid, text, text, integer, integer)','6ac0d61dfc24c15123812ec788294197'),
('api.owner_list_membership_plans','api.owner_list_membership_plans(uuid)','fc3ed2be2834b6458f2835bfc18d9b4e'),
('api.owner_list_membership_purchases','api.owner_list_membership_purchases(uuid, text, text, integer, integer)','d6fd6f1ba099afe317dcf1606d49d64f'),
('api.owner_record_membership_payment','api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)','c21766acb601a8b92dc26d59f73be2a3'),
('api.owner_register_member','api.owner_register_member(uuid, text, bytea, bytea)','e56b20e809c8dfcebd782d4e8aa5fbb5'),
('api.owner_reject_membership_payment','api.owner_reject_membership_payment(uuid, uuid, text)','b55e7879cbae6d9074264826ed75eac0'),
('api.owner_save_membership_plan','api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)','c128144cda372362b26ec91dc64fd6fa'),
('api.reserve_pin_enrollment_request','api.reserve_pin_enrollment_request()','ed1a67d4a3cd30fed31a0ee36222eb5b'),
('api.verify_audit_stream','api.verify_audit_stream(text)','f7c5cdb53ec4cf2d845e38f404df5fb9'),
('private.audit_events_chain_insert','private.audit_events_chain_insert()','6fa6a434395de93250213752513ffb34'),
('private.compute_audit_event_hash','private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone)','a0635caf0c329b24571bd68df684f69f'),
('private.guard_membership_payment_allocation','private.guard_membership_payment_allocation()','4836529309d8c518d42d24b9d191d6d5'),
('private.guard_membership_payment_record_insert','private.guard_membership_payment_record_insert()','edaae9f3a89330d4e55ce37d7d16d074'),
('private.guard_membership_payment_record_update','private.guard_membership_payment_record_update()','9386192bae0b7aec6e34fce2e2aadbda'),
('private.guard_purchase_pending_activation','private.guard_purchase_pending_activation()','c3467a65c399cf75243d4e3e9e31b36c'),
('private.is_active_owner','private.is_active_owner()','76af3203b0fe03c30e1eb6d8264a04e6'),
('private.prevent_audit_event_mutation','private.prevent_audit_event_mutation()','d835b9b2db211d2439e03ec9d8a6337d'),
('private.prevent_payment_history_mutation','private.prevent_payment_history_mutation()','0ad4feeac81403c334c6665ff018485e'))
SELECT e.name routine_name,p.oid IS NOT NULL identity_exists,
 COALESCE(md5(p.prosrc)=e.approved_digest,false) approved_source_body_matches
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature) ORDER BY 1;
ROLLBACK;
