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
SELECT n.nspname schema_name,p.proname object_name,p.oid object_oid,p.prokind kind,
 pg_get_userbyid(p.proowner) owner,l.lanname language_name,p.prosecdef security_definer,
 p.proisstrict strict,p.proretset returns_set,p.proleakproof leakproof,p.provolatile volatility,p.proparallel parallel,
 p.pronargs input_count,p.pronargdefaults default_count,
 (p.proconfig=ARRAY['search_path=""']::text[]) exact_empty_search_path,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') service_execute
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang
 WHERE n.nspname IN ('public','private','api','graphql_public') ORDER BY 1,2,3;
ROLLBACK;
