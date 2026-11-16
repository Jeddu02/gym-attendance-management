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
SELECT n.nspname schema_name,c.relname table_name,r.rolname role_name,
 has_table_privilege(r.oid,c.oid,'SELECT') table_select,has_table_privilege(r.oid,c.oid,'INSERT') table_insert,
 has_table_privilege(r.oid,c.oid,'UPDATE') table_update,has_table_privilege(r.oid,c.oid,'DELETE') table_delete,
 has_table_privilege(r.oid,c.oid,'TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') other_table_privilege,
 has_any_column_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,REFERENCES') any_column_privilege
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN pg_roles r
 WHERE n.nspname IN ('public','private','api','graphql_public') AND c.relkind IN ('r','p') AND r.rolname IN ('anon','authenticated','service_role','gym_data_owner','gym_owner_executor','gym_public_executor','gym_registration_login') ORDER BY 1,2,3;
ROLLBACK;
