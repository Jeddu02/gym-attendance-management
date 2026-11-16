-- OWNER REVIEW COPY. Not executed against production by Codex.
-- Catalog reads only. No function bodies, policy expressions, defaults, secrets,
-- PIN material, member records or payment records are returned.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;

-- Run through the intended migration connection; SQL Editor may use another role.
SELECT current_user AS effective_role, session_user AS connection_role,
       current_setting('server_version_num') AS postgres_version_number,
       current_setting('transaction_read_only') AS read_only;

SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;

SELECT n.nspname AS schema_name, pg_get_userbyid(n.nspowner) AS owner
FROM pg_catalog.pg_namespace n WHERE n.nspname IN ('api','private','extensions')
ORDER BY n.nspname;

-- Actual signatures, including unexpected overloads. No prosrc/prosqlbody output.
SELECT n.nspname AS schema_name, p.proname AS routine,
       pg_catalog.pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       pg_catalog.pg_get_function_result(p.oid) AS result_type,
       p.prokind AS kind, l.lanname AS language,
       pg_catalog.pg_get_userbyid(p.proowner) AS owner,
       p.prosecdef AS security_definer, p.provolatile AS volatility,
       COALESCE(p.proconfig @> ARRAY['search_path=""']::text[],false) AS empty_search_path,
       COALESCE(p.proconfig @> ARRAY['TimeZone=UTC']::text[],false) AS explicit_utc
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
JOIN pg_catalog.pg_language l ON l.oid=p.prolang
WHERE n.nspname IN ('api','private') ORDER BY n.nspname,p.proname,p.oid;

-- Explicit/default routine ACLs; unknown grantees are deliberately anonymized.
SELECT n.nspname AS schema_name, p.proname AS routine,
       pg_catalog.pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       CASE WHEN a.grantee=0 THEN 'PUBLIC'
            WHEN r.rolname IN ('postgres','anon','authenticated','service_role',
                 'gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
            THEN r.rolname ELSE 'OTHER_ROLE' END AS grantee,
       a.privilege_type, a.is_grantable
FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
LEFT JOIN pg_catalog.pg_roles r ON r.oid=a.grantee
WHERE n.nspname IN ('api','private') ORDER BY 1,2,3,4;

-- Effective permissions account for inherited privileges, not just ACL text.
SELECT n.nspname AS schema_name,p.proname AS routine,
       pg_catalog.pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       r.rolname AS caller, pg_catalog.has_function_privilege(r.oid,p.oid,'EXECUTE') AS can_execute
FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
CROSS JOIN pg_catalog.pg_roles r
WHERE n.nspname IN ('api','private') AND r.rolname IN
 ('anon','authenticated','service_role','gym_owner_executor','gym_public_executor','gym_checkin_executor')
ORDER BY 1,2,3,4;

SELECT n.nspname AS schema_name,r.rolname AS caller,
       pg_catalog.has_schema_privilege(r.oid,n.oid,'USAGE') AS can_use,
       pg_catalog.has_schema_privilege(r.oid,n.oid,'CREATE') AS can_create
FROM pg_catalog.pg_namespace n CROSS JOIN pg_catalog.pg_roles r
WHERE n.nspname IN ('api','private','public','extensions') AND r.rolname IN
 ('anon','authenticated','service_role','gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
ORDER BY 1,2;

-- Future-object ACL metadata. Global defaults matter as well as schema defaults.
SELECT CASE WHEN d.defaclnamespace=0 THEN 'GLOBAL' ELSE n.nspname END AS schema_scope,
 CASE WHEN owner_role.rolname IN ('postgres','gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
      THEN owner_role.rolname ELSE 'OTHER_ROLE' END AS creator_role,
 d.defaclobjtype AS object_type,
 CASE WHEN a.grantee=0 THEN 'PUBLIC'
      WHEN grantee.rolname IN ('anon','authenticated','service_role','postgres','gym_data_owner',
           'gym_owner_executor','gym_public_executor','gym_checkin_executor')
      THEN grantee.rolname ELSE 'OTHER_ROLE' END AS grantee,
 a.privilege_type,a.is_grantable
FROM pg_catalog.pg_default_acl d
JOIN pg_catalog.pg_roles owner_role ON owner_role.oid=d.defaclrole
LEFT JOIN pg_catalog.pg_namespace n ON n.oid=d.defaclnamespace
CROSS JOIN LATERAL pg_catalog.aclexplode(d.defaclacl) a
LEFT JOIN pg_catalog.pg_roles grantee ON grantee.oid=a.grantee
WHERE (d.defaclnamespace=0 OR n.nspname IN ('api','private','public'))
 AND owner_role.rolname IN ('postgres','gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
ORDER BY 1,2,3,4;

SELECT n.nspname AS schema_name,c.relname AS relation,c.relkind,
       pg_catalog.pg_get_userbyid(c.relowner) AS owner,
       c.relrowsecurity AS rls_enabled,c.relforcerowsecurity AS rls_forced,
       pg_catalog.row_security_active(c.oid) AS rls_filters_current_role
FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE c.relkind IN ('r','p') AND (n.nspname IN ('api','private')
 OR (n.nspname='public' AND c.relname='gym_settings')) ORDER BY 1,2;

SELECT n.nspname AS schema_name,c.relname AS relation,r.rolname AS caller,
       pg_catalog.has_table_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') AS any_table_privilege,
       pg_catalog.has_any_column_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,REFERENCES') AS any_column_privilege
FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN pg_catalog.pg_roles r
WHERE c.relkind IN ('r','p') AND (n.nspname='private'
 OR (n.nspname='public' AND c.relname='gym_settings'))
 AND r.rolname IN ('anon','authenticated','service_role') ORDER BY 1,2,3;

-- Policy metadata only; expression bodies can contain private constants.
SELECT n.nspname AS schema_name,c.relname AS relation,p.polname AS policy,
       p.polcmd AS command,p.polpermissive AS permissive,
       p.polqual IS NOT NULL AS has_using,p.polwithcheck IS NOT NULL AS has_check,
       ARRAY(SELECT CASE WHEN x.role_oid=0 THEN 'PUBLIC'
            WHEN r.rolname IN ('postgres','anon','authenticated','service_role',
                 'gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
            THEN r.rolname ELSE 'OTHER_ROLE' END
            FROM unnest(p.polroles) x(role_oid)
            LEFT JOIN pg_catalog.pg_roles r ON r.oid=x.role_oid ORDER BY 1) AS roles
FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings') ORDER BY 1,2,3;

-- No expressions/defaults/trigger arguments are exposed by these inventories.
SELECT n.nspname AS schema_name,c.relname AS relation,a.attname AS column_name,
       pg_catalog.format_type(a.atttypid,a.atttypmod) AS type,a.attnotnull AS not_null
FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_class c ON c.oid=a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE c.relkind IN ('r','p') AND n.nspname='private' AND a.attnum>0 AND NOT a.attisdropped
ORDER BY 1,2,a.attnum;

SELECT n.nspname AS schema_name,c.relname AS relation,t.tgname AS trigger,
       t.tgenabled AS enabled,t.tgfoid::regprocedure::text AS routine
FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE NOT t.tgisinternal AND (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')) ORDER BY 1,2,3;

SELECT n.nspname AS schema_name,c.relname AS relation,k.conname AS constraint_name,
       k.contype AS type,k.convalidated AS validated
FROM pg_catalog.pg_constraint k JOIN pg_catalog.pg_class c ON c.oid=k.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='private' ORDER BY 1,2,3;

SELECT n.nspname AS schema_name,c.relname AS relation,i.relname AS index_name,
       x.indisvalid AS valid,x.indisready AS ready,x.indisunique AS unique_index
FROM pg_catalog.pg_index x JOIN pg_catalog.pg_class c ON c.oid=x.indrelid
JOIN pg_catalog.pg_class i ON i.oid=x.indexrelid
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='private' ORDER BY 1,2,3;
ROLLBACK;
