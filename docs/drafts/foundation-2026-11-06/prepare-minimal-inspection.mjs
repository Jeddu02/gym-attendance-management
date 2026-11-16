// FILESYSTEM ONLY. Writes fixed, reviewable queries. Never invokes PostgreSQL.
import fs from 'node:fs';
import path from 'node:path';
import { directory } from './source-contract.mjs';
const guard = `-- Structural metadata only. Run separately after protected preflight.
BEGIN READ ONLY;
SET LOCAL search_path=pg_catalog;
SET LOCAL statement_timeout='15s';
SELECT 1 / CASE WHEN current_database()='gymforce_pg18_test'
 AND inet_server_addr()='127.0.0.1'::inet AND inet_server_port()=55432
 AND current_user='postgres' AND session_user='postgres'
 AND (SELECT rolsuper FROM pg_roles WHERE rolname=current_user)
 AND current_setting('gymforce.test_cluster_marker',true)='f497fabb-a12f-4068-b745-8b0729279276'
 AND (pg_control_system()).system_identifier::text='7704603813616068820'
 AND lower(rtrim(replace(current_setting('data_directory'),E'\\\\','/'),'/'))='c:/users/banco-sual/appdata/local/gymforce-pg18-test/data'
 THEN 1 ELSE 0 END AS identity_guard \\gset
`;
const scope = "n.nspname IN ('public','private','api','graphql_public')";
const roles = "('anon','authenticated','service_role','gym_data_owner','gym_owner_executor','gym_public_executor','gym_registration_login')";
const queries = {
 '01-identity-counts': `SELECT current_database() database, inet_server_addr()::text host, inet_server_port() port,
 current_user actor, current_setting('transaction_read_only') read_only,
 (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ${scope} AND c.relkind IN ('r','p')) tables,
 (SELECT count(*) FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ${scope} AND k.contype<>'n') constraints,
 (SELECT count(*) FROM pg_index i JOIN pg_class c ON c.oid=i.indrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ${scope}) indexes,
 (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE ${scope}) routines;`,
 '02-tables': `SELECT n.nspname schema_name,c.relname object_name,c.relkind kind,pg_get_userbyid(c.relowner) owner,
 c.relrowsecurity rls,c.relforcerowsecurity force_rls
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE ${scope} AND c.relkind IN ('r','p','S') ORDER BY 1,2;`,
 '03-constraints-indexes': `SELECT 'constraint' category,n.nspname schema_name,t.relname table_name,k.conname object_name,
 k.contype::text kind,k.convalidated valid,k.condeferrable deferrable,k.condeferred deferred,
 NULL::boolean ready,NULL::boolean unique_key,NULL::boolean primary_key,NULL::boolean exclusion
 FROM pg_constraint k JOIN pg_class t ON t.oid=k.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE ${scope} AND k.contype<>'n'
 UNION ALL
 SELECT 'index',n.nspname,t.relname,c.relname,'i',i.indisvalid,NULL,NULL,i.indisready,i.indisunique,i.indisprimary,i.indisexclusion
 FROM pg_index i JOIN pg_class t ON t.oid=i.indrelid JOIN pg_class c ON c.oid=i.indexrelid
 JOIN pg_namespace n ON n.oid=t.relnamespace WHERE ${scope} ORDER BY 1,2,3,4;`,
 '04-columns': `SELECT n.nspname schema_name,c.relname table_name,a.attname column_name,a.attnum ordinal,
 format_type(a.atttypid,a.atttypmod) type_name,a.attnotnull not_null,a.attidentity identity_kind,
 a.attgenerated generated_kind,a.atthasdef has_default_or_generated_expression
 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE ${scope} AND c.relkind IN ('r','p') AND a.attnum>0 AND NOT a.attisdropped ORDER BY 1,2,4;`,
 '05-routines': `SELECT n.nspname schema_name,p.proname object_name,p.oid object_oid,p.prokind kind,
 pg_get_userbyid(p.proowner) owner,l.lanname language_name,p.prosecdef security_definer,
 p.proisstrict strict,p.proretset returns_set,p.proleakproof leakproof,p.provolatile volatility,p.proparallel parallel,
 p.pronargs input_count,p.pronargdefaults default_count,
 (p.proconfig=ARRAY['search_path=""']::text[]) exact_empty_search_path,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') service_execute
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang
 WHERE ${scope} ORDER BY 1,2,3;`,
 '06-table-privileges': `SELECT n.nspname schema_name,c.relname table_name,r.rolname role_name,
 has_table_privilege(r.oid,c.oid,'SELECT') table_select,has_table_privilege(r.oid,c.oid,'INSERT') table_insert,
 has_table_privilege(r.oid,c.oid,'UPDATE') table_update,has_table_privilege(r.oid,c.oid,'DELETE') table_delete,
 has_table_privilege(r.oid,c.oid,'TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') other_table_privilege,
 has_any_column_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,REFERENCES') any_column_privilege
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN pg_roles r
 WHERE ${scope} AND c.relkind IN ('r','p') AND r.rolname IN ${roles} ORDER BY 1,2,3;`,
 '07-triggers-rules': `SELECT 'trigger' category,n.nspname schema_name,c.relname table_name,t.tgname object_name,t.tgenabled::text enabled
 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE ${scope} AND NOT t.tgisinternal
 UNION ALL
 SELECT 'rule',n.nspname,c.relname,r.rulename,r.ev_enabled::text
 FROM pg_rewrite r JOIN pg_class c ON c.oid=r.ev_class JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ${scope} ORDER BY 1,2,3,4;`,
 '08-default-privileges': `SELECT r.rolname creator,k.kind,
 EXISTS (SELECT 1 FROM aclexplode(COALESCE((SELECT d.defaclacl FROM pg_default_acl d
 WHERE d.defaclrole=r.oid AND d.defaclnamespace=0 AND d.defaclobjtype=k.kind::"char"),acldefault(k.kind::"char",r.oid))) a
 WHERE a.grantee<>r.oid) non_owner_global_default,
 EXISTS (SELECT 1 FROM pg_default_acl d JOIN pg_namespace n ON n.oid=d.defaclnamespace,
 LATERAL aclexplode(d.defaclacl) a WHERE d.defaclrole=r.oid AND d.defaclobjtype=k.kind::"char"
 AND n.nspname IN ('private','api','public','graphql_public') AND a.grantee<>r.oid) non_owner_schema_default
 FROM pg_roles r CROSS JOIN (VALUES ('r'),('S'),('f'),('T')) k(kind)
 WHERE r.rolname IN ('postgres','gym_data_owner','gym_owner_executor','gym_public_executor','gym_registration_login') ORDER BY 1,2;`,
 '09-role-schema-privileges': `SELECT r.rolname role_name,r.rolcanlogin login,r.rolsuper superuser,r.rolcreatedb createdb,
 r.rolcreaterole createrole,r.rolinherit inherit,r.rolreplication replication,r.rolbypassrls bypassrls,
 n.nspname schema_name,has_schema_privilege(r.oid,n.oid,'USAGE') schema_usage,
 has_schema_privilege(r.oid,n.oid,'CREATE') schema_create,
 EXISTS (SELECT 1 FROM pg_auth_members m WHERE m.member=r.oid OR m.roleid=r.oid) any_membership_edge
 FROM pg_roles r CROSS JOIN pg_namespace n WHERE r.rolname IN ${roles}
 AND n.nspname IN ('public','private','api','extensions','graphql_public') ORDER BY 1,9;`
};
const target=path.join(directory,'minimal-catalog'); fs.mkdirSync(target,{recursive:true});
for(const [name,query] of Object.entries(queries)) {
  const sql=guard+query+'\nROLLBACK;\n';
  fs.writeFileSync(path.join(target,name+'.sql'),sql);
  if(name==='01-identity-counts') fs.writeFileSync(path.join(directory,'inspect-catalog.sql'),sql);
}
console.log('Prepared nine fixed structural queries. No connections or SQL execution.');
