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
('private.cash_reconciliations','cash_reconciliations_drawer_session_id_key','unique ( drawer_session_id )'),
('private.member_pin_setup_tokens','member_pin_setup_tokens_token_hash_key','unique ( token_hash )'),
('private.members','members_member_code_key','unique ( member_code )'),
('private.members','members_mobile_lookup_hash_key','unique ( mobile_lookup_hash )'),
('private.payment_allocations','payment_allocations_payment_id_key','unique ( payment_id )'),
('private.pin_attempt_buckets','pin_bucket_unique_window','unique ( bucket_type , identifier_digest , window_started_at )'))
SELECT e.table_name,e.constraint_name,k.oid IS NOT NULL identity_exists,
 COALESCE(k.contype='u' AND k.convalidated AND NOT k.condeferrable AND NOT k.condeferred,false) structural_flags_match,
 (SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_constraintdef(k.oid,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal)) IS NOT DISTINCT FROM e.definition exact_source_definition_matches
FROM expected e LEFT JOIN pg_constraint k ON k.conrelid=to_regclass(e.table_name) AND k.conname=e.constraint_name ORDER BY 1,2;
ROLLBACK;
