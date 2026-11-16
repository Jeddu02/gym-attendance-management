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
WITH expected(table_name,trigger_name,definition) AS (VALUES
('private.audit_events','audit_events_chain_insert_trigger','create trigger audit_events_chain_insert_trigger before insert on private . audit_events for each row execute function private . audit_events_chain_insert ( )'),
('private.audit_events','audit_events_no_truncate','create trigger audit_events_no_truncate before truncate on private . audit_events for each statement execute function private . prevent_audit_event_mutation ( )'),
('private.audit_events','audit_events_no_update_delete','create trigger audit_events_no_update_delete before delete or update on private . audit_events for each row execute function private . prevent_audit_event_mutation ( )'),
('private.membership_purchases','membership_purchase_requires_confirmed_payment','create trigger membership_purchase_requires_confirmed_payment before insert or update on private . membership_purchases for each row execute function private . guard_purchase_pending_activation ( )'),
('private.payment_allocations','payment_allocations_no_truncate','create trigger payment_allocations_no_truncate before truncate on private . payment_allocations for each statement execute function private . prevent_payment_history_mutation ( )'),
('private.payment_allocations','payment_allocations_no_update_delete','create trigger payment_allocations_no_update_delete before delete or update on private . payment_allocations for each row execute function private . prevent_payment_history_mutation ( )'),
('private.payment_allocations','payment_allocations_validate_membership','create trigger payment_allocations_validate_membership before insert on private . payment_allocations for each row execute function private . guard_membership_payment_allocation ( )'),
('private.payment_events','payment_events_no_truncate','create trigger payment_events_no_truncate before truncate on private . payment_events for each statement execute function private . prevent_payment_history_mutation ( )'),
('private.payment_events','payment_events_no_update_delete','create trigger payment_events_no_update_delete before delete or update on private . payment_events for each row execute function private . prevent_payment_history_mutation ( )'),
('private.payment_records','payment_records_guard_update','create trigger payment_records_guard_update before update on private . payment_records for each row execute function private . guard_membership_payment_record_update ( )'),
('private.payment_records','payment_records_no_delete','create trigger payment_records_no_delete before delete on private . payment_records for each row execute function private . prevent_payment_history_mutation ( )'),
('private.payment_records','payment_records_no_truncate','create trigger payment_records_no_truncate before truncate on private . payment_records for each statement execute function private . prevent_payment_history_mutation ( )'),
('private.payment_records','payment_records_validate_membership_insert','create trigger payment_records_validate_membership_insert before insert on private . payment_records for each row execute function private . guard_membership_payment_record_insert ( )'))
SELECT e.table_name,e.trigger_name,t.oid IS NOT NULL identity_exists,
 COALESCE(t.tgenabled='O' AND NOT t.tgisinternal,false) enabled_matches,
 (SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_triggerdef(t.oid,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal)) IS NOT DISTINCT FROM e.definition exact_source_definition_matches
FROM expected e LEFT JOIN pg_trigger t ON t.tgrelid=to_regclass(e.table_name) AND t.tgname=e.trigger_name ORDER BY 1,2;
ROLLBACK;
