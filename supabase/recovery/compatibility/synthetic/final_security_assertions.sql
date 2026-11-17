-- Cross-phase current-state security invariants. Read-only, no record output.
BEGIN READ ONLY;
SET LOCAL statement_timeout='30s';
DO $final_boundary$
DECLARE item record; actor text;
BEGIN
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='api') THEN
  RAISE EXCEPTION 'Approved API schema must contain routines only, no table/view/sequence data endpoints';
 END IF;
 FOREACH actor IN ARRAY ARRAY['anon','authenticated','service_role','gym_owner_executor','gym_public_executor','gym_checkin_executor'] LOOP
  IF has_schema_privilege(actor,'api','CREATE') OR has_schema_privilege(actor,'private','CREATE') THEN
   RAISE EXCEPTION 'Application actor may create schema objects';
  END IF;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY['gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'] LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=actor AND NOT rolcanlogin AND NOT rolsuper
    AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolinherit AND NOT rolreplication AND NOT rolbypassrls) THEN
   RAISE EXCEPTION 'Unsafe or absent application execution role';
  END IF;
  IF EXISTS(SELECT 1 FROM pg_auth_members m JOIN pg_roles role_info ON role_info.oid=m.roleid OR role_info.oid=m.member WHERE role_info.rolname=actor AND NOT (m.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'))
 AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='gf_provider_admin')
 AND m.admin_option AND NOT m.inherit_option AND NOT m.set_option)))) THEN
   RAISE EXCEPTION 'Application role membership violates isolated executor boundary';
  END IF;
 END LOOP;
 FOR item IN SELECT c.oid,c.relowner,c.relrowsecurity,c.relforcerowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE c.relkind IN ('r','p') AND (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')) LOOP
  IF NOT item.relrowsecurity OR NOT item.relforcerowsecurity OR item.relowner<>(SELECT oid FROM pg_roles WHERE rolname='gym_data_owner') THEN
   RAISE EXCEPTION 'Application ownership/RLS invariant failed';
  END IF;
  FOREACH actor IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
   IF has_table_privilege(actor,item.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
     OR has_any_column_privilege(actor,item.oid,'SELECT,INSERT,UPDATE,REFERENCES') THEN
    RAISE EXCEPTION 'Direct application data grant to browser/service role';
   END IF;
  END LOOP;
 END LOOP;
 FOR item IN SELECT p.*,n.nspname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('api','private') LOOP
  IF NOT (COALESCE(item.proconfig,ARRAY[]::text[]) @> ARRAY['search_path=""']::text[]) THEN
   RAISE EXCEPTION 'Application routine has unreviewed search path';
  END IF;
  IF item.nspname='api' AND (NOT item.prosecdef OR item.proowner NOT IN
      (SELECT oid FROM pg_roles WHERE rolname IN ('gym_owner_executor','gym_public_executor','gym_checkin_executor'))) THEN
   RAISE EXCEPTION 'API routine execution identity is unsafe';
  END IF;
  IF item.nspname='private' AND (item.prosecdef OR item.proowner<>(SELECT oid FROM pg_roles WHERE rolname='gym_data_owner')) THEN
   RAISE EXCEPTION 'Private helper execution identity is unsafe';
  END IF;
  IF EXISTS(SELECT 1 FROM aclexplode(COALESCE(item.proacl,acldefault('f',item.proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE') THEN
   RAISE EXCEPTION 'PUBLIC may execute application routine';
  END IF;
  FOREACH actor IN ARRAY ARRAY['anon','authenticated'] LOOP
   IF has_function_privilege(actor,item.oid,'EXECUTE') THEN RAISE EXCEPTION 'Browser can execute private application RPC'; END IF;
  END LOOP;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamptz)'::regprocedure
   AND proconfig @> ARRAY['TimeZone=UTC']::text[]) THEN
  RAISE EXCEPTION 'Canonical audit timezone is not fixed to UTC';
 END IF;
END $final_boundary$;
ROLLBACK;
\echo 'PASS: final cross-phase executor, table RLS, direct-data denial, routine and audit-timezone invariants.'
