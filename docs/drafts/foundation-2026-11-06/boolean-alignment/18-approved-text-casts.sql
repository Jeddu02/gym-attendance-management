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
WITH expected_columns(table_name,column_name,expression) AS (VALUES
('private.attendance_checkins','attendance_status','''valid'' :: text'),
('private.cash_drawer_sessions','session_status','''open'' :: text'),
('private.members','status','''pending'' :: text'),
('private.membership_purchases','purchase_status','''pending_payment'' :: text'),
('private.payment_corrections','correction_status','''proposed'' :: text'),
('private.payment_records','verification_status','''recorded'' :: text'),
('private.walkin_fee_versions','currency','''PHP'' :: text'),
('private.walkin_requests','currency','''PHP'' :: text'),
('private.walkin_requests','request_status','''pending'' :: text')), expected_routines(name,signature,defaults) AS (VALUES
('api.append_audit_event','api.append_audit_event(text, uuid, text, text, text, jsonb)','null :: text , ''{}'' :: jsonb'),
('api.owner_list_members','api.owner_list_members(uuid, text, text, integer, integer)','null :: text , ''all'' :: text , 50 , 0'),
('api.owner_list_membership_payments','api.owner_list_membership_payments(uuid, text, text, integer, integer)','null :: text , ''all'' :: text , 50 , 0'),
('api.owner_list_membership_purchases','api.owner_list_membership_purchases(uuid, text, text, integer, integer)','null :: text , ''all'' :: text , 50 , 0'),
('api.owner_record_membership_payment','api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)','null :: text'))
SELECT 'column' category,e.table_name||'.'||e.column_name object_name,
 a.attnum IS NOT NULL identity_exists,
 (SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_expr(d.adbin,d.adrelid,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal)) IS NOT DISTINCT FROM e.expression approved_text_cast_matches
FROM expected_columns e LEFT JOIN pg_attribute a ON a.attrelid=to_regclass(e.table_name) AND a.attname=e.column_name AND a.attnum>0 AND NOT a.attisdropped
 LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
UNION ALL
SELECT 'routine',e.name,p.oid IS NOT NULL,
 COALESCE((SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_expr(p.proargdefaults,0,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal)),'')=e.defaults
FROM expected_routines e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature) ORDER BY 1,2;
ROLLBACK;
