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
SELECT k.conname object_name,
 k.convalidated AND k.conenforced AND NOT k.condeferrable AND NOT k.condeferred AND k.conislocal AND k.coninhcount=0 core_flags_match,
 k.connoinherit exclusion_is_non_inheritable,
 (SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(pg_get_constraintdef(k.oid,false),$lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\.[0-9]+)?|::|<>|<=|>=|&&|!=|\|\||[^[:space:]]$lex$,'g') WITH ORDINALITY token(part,ordinal))='exclude using gist ( member_id with = , daterange ( activation_date , expiry_date , ''[]'' :: text ) with && ) where ( ( ( activation_date is not null ) and ( expiry_date is not null ) ) )' default_opclass_omission_candidate_matches,
 COALESCE(i.indclass[0]=(SELECT o.oid FROM pg_opclass o JOIN pg_namespace n ON n.oid=o.opcnamespace JOIN pg_am am ON am.oid=o.opcmethod WHERE n.nspname='extensions' AND o.opcname='gist_uuid_ops' AND am.amname='gist' AND o.opcintype='uuid'::regtype AND o.opcdefault),false) uuid_opclass_matches,
 COALESCE(i.indclass[1]=(SELECT o.oid FROM pg_opclass o JOIN pg_namespace n ON n.oid=o.opcnamespace JOIN pg_am am ON am.oid=o.opcmethod WHERE n.nspname='pg_catalog' AND o.opcname='range_ops' AND am.amname='gist' AND o.opcintype='anyrange'::regtype AND o.opcdefault),false) range_opclass_matches,
 k.conexclop=ARRAY['pg_catalog.=(uuid,uuid)'::regoperator::oid,'pg_catalog.&&(anyrange,anyrange)'::regoperator::oid] operators_match,
 i.indisvalid AND i.indisready AND i.indislive AND i.indisexclusion AND i.indnkeyatts=2 AND i.indnatts=2 backing_index_matches
FROM pg_constraint k JOIN pg_index i ON i.indexrelid=k.conindid
WHERE k.conrelid='private.membership_purchases'::regclass AND k.conname='membership_purchases_no_overlapping_periods' AND k.contype='x';
ROLLBACK;
