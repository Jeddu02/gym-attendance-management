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
SELECT 'constraint' category,n.nspname schema_name,t.relname table_name,k.conname object_name,
 k.contype::text kind,k.convalidated valid,k.condeferrable deferrable,k.condeferred deferred,
 NULL::boolean ready,NULL::boolean unique_key,NULL::boolean primary_key,NULL::boolean exclusion
 FROM pg_constraint k JOIN pg_class t ON t.oid=k.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE n.nspname IN ('public','private','api','graphql_public') AND k.contype<>'n'
 UNION ALL
 SELECT 'index',n.nspname,t.relname,c.relname,'i',i.indisvalid,NULL,NULL,i.indisready,i.indisunique,i.indisprimary,i.indisexclusion
 FROM pg_index i JOIN pg_class t ON t.oid=i.indrelid JOIN pg_class c ON c.oid=i.indexrelid
 JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('public','private','api','graphql_public') ORDER BY 1,2,3,4;
ROLLBACK;
