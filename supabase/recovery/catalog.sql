-- DRAFT Owner review required for any hosted execution. No function bodies/rows returned.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
WITH objects AS (
 SELECT 'relation|'||n.nspname||'|'||c.relname AS key,
 encode(sha256(convert_to(jsonb_build_object('kind',c.relkind,'owner',pg_get_userbyid(c.relowner),
 'acl',c.relacl::text,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,
 'index',CASE WHEN c.relkind='i' THEN pg_get_indexdef(c.oid) ELSE NULL END,
 'view',CASE WHEN c.relkind IN ('v','m') THEN pg_get_viewdef(c.oid) ELSE NULL END,
 'valid',i.indisvalid,'ready',i.indisready)::text,'UTF8')),'hex') AS fingerprint,
 CASE WHEN c.relkind IN ('r','p') THEN has_table_privilege(current_user,c.oid,'SELECT') END AS readable,
 CASE WHEN c.relkind IN ('r','p') THEN row_security_active(c.oid) END AS filtered
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 LEFT JOIN pg_index i ON i.indexrelid=c.oid
 WHERE n.nspname IN ('api','private') OR (n.nspname='public' AND c.relname='gym_settings')
 UNION ALL
 SELECT 'routine|'||n.nspname||'|'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
 encode(sha256(convert_to(jsonb_build_object('definition',pg_get_functiondef(p.oid),
 'owner',pg_get_userbyid(p.proowner),'acl',p.proacl::text)::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname IN ('api','private') AND p.prokind IN ('f','p')
 UNION ALL
 SELECT 'column|'||n.nspname||'|'||c.relname||'|'||a.attname,
 encode(sha256(convert_to(jsonb_build_object('type',format_type(a.atttypid,a.atttypmod),'notnull',a.attnotnull,
 'identity',a.attidentity,'generated',a.attgenerated,'acl',a.attacl::text,
 'default',pg_get_expr(d.adbin,d.adrelid))::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
 WHERE a.attnum>0 AND NOT a.attisdropped AND
 (n.nspname IN ('api','private') OR (n.nspname='public' AND c.relname='gym_settings'))
 UNION ALL
 SELECT 'constraint|'||n.nspname||'|'||c.relname||'|'||k.conname,
 encode(sha256(convert_to(jsonb_build_object('definition',pg_get_constraintdef(k.oid),'valid',k.convalidated)::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')
 UNION ALL
 SELECT 'trigger|'||n.nspname||'|'||c.relname||'|'||t.tgname,
 encode(sha256(convert_to(jsonb_build_object('definition',pg_get_triggerdef(t.oid),'enabled',t.tgenabled)::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE NOT t.tgisinternal AND (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings'))
 UNION ALL
 SELECT 'policy|'||n.nspname||'|'||c.relname||'|'||p.polname,
 encode(sha256(convert_to(jsonb_build_object('command',p.polcmd,'permissive',p.polpermissive,
 'using',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid),
 'roles',ARRAY(SELECT CASE WHEN x=0 THEN 'PUBLIC' ELSE pg_get_userbyid(x) END
 FROM unnest(p.polroles) x ORDER BY 1))::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')
 UNION ALL
 SELECT 'schema|'||n.nspname,encode(sha256(convert_to(jsonb_build_object('owner',pg_get_userbyid(n.nspowner),'acl',n.nspacl::text)::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_namespace n WHERE n.nspname IN ('api','private','public','extensions')
 UNION ALL
 SELECT 'role|'||r.rolname,encode(sha256(convert_to(jsonb_build_object('login',r.rolcanlogin,'super',r.rolsuper,
 'createdb',r.rolcreatedb,'createrole',r.rolcreaterole,'inherit',r.rolinherit,
 'replication',r.rolreplication,'bypass',r.rolbypassrls,
 'memberships',ARRAY(SELECT concat_ws('|',pg_get_userbyid(m.roleid),pg_get_userbyid(m.member),
 pg_get_userbyid(m.grantor),m.admin_option,m.inherit_option,m.set_option)
 FROM pg_auth_members m WHERE m.roleid=r.oid OR m.member=r.oid ORDER BY 1))::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_roles r WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
 UNION ALL
 SELECT 'default|'||pg_get_userbyid(d.defaclrole)::text||'|'||COALESCE(n.nspname::text,'GLOBAL')||'|'||d.defaclobjtype::text,
 encode(sha256(convert_to(d.defaclacl::text,'UTF8')),'hex'),NULL,NULL FROM pg_default_acl d
 LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace
 WHERE d.defaclnamespace=0 OR n.nspname IN ('api','private','public')
 UNION ALL
 SELECT 'sequence|'||n.nspname||'|'||c.relname,
 encode(sha256(convert_to(jsonb_build_object('type',format_type(s.seqtypid,NULL),'start',s.seqstart,
 'increment',s.seqincrement,'min',s.seqmin,'max',s.seqmax,'cache',s.seqcache,'cycle',s.seqcycle)::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_sequence s JOIN pg_class c ON c.oid=s.seqrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='private'
 UNION ALL
 SELECT 'type|'||n.nspname||'|'||t.typname,
 encode(sha256(convert_to(jsonb_build_object('kind',t.typtype,'owner',pg_get_userbyid(t.typowner),'acl',t.typacl::text)::text,'UTF8')),'hex'),NULL,NULL
 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname IN ('api','private')
)
SELECT jsonb_build_object('format',1,'fingerprintAlgorithm','sha256','serverMajor',current_setting('server_version_num')::integer/10000,
 'objects',COALESCE(jsonb_agg(to_jsonb(o) ORDER BY o.key),'[]'::jsonb)) AS private_catalog
FROM objects o;
ROLLBACK;
