-- DRAFT — NOT AUTHORIZED FOR EXECUTION. Owner-private catalog metadata only.
-- Same caller/relation scope as Unit 22; no application records are read.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
WITH RECURSIVE callers AS (
 SELECT r.* FROM pg_catalog.pg_roles r WHERE r.rolname IN ('anon','authenticated','service_role')
), special_roles AS (
 SELECT w.name,r.oid FROM (VALUES ('pg_read_all_data'),('pg_write_all_data'),('pg_database_owner')) w(name)
 LEFT JOIN pg_catalog.pg_roles r ON r.rolname=w.name
), database_context AS (
 SELECT d.oid,d.datdba FROM pg_catalog.pg_database d WHERE d.datname=pg_catalog.current_database()
), membership_edges AS (
 SELECT m.roleid,m.member,m.grantor,m.admin_option,m.inherit_option,m.set_option,
 'EXPLICIT'::pg_catalog.text AS edge_kind FROM pg_catalog.pg_auth_members m
 UNION ALL
 SELECT s.oid,d.datdba,NULL::pg_catalog.oid,NULL::pg_catalog.bool,true,true,'IMPLICIT_DATABASE_OWNER'::pg_catalog.text
 FROM database_context d CROSS JOIN special_roles s WHERE s.name='pg_database_owner' AND s.oid IS NOT NULL
), objects AS (
 SELECT c.*,n.nspname,n.nspacl,n.nspowner FROM pg_catalog.pg_class c
 JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind IN ('r','p','v','m','S') AND
 (n.nspname IN ('api','private') OR (n.nspname='public' AND c.relname='gym_settings'))
), checks AS (
 SELECT c.oid AS object_oid,r.oid AS caller_oid,'table'::pg_catalog.text AS scope,
 NULL::pg_catalog.int2 AS column_number,v.privilege
 FROM objects c CROSS JOIN callers r CROSS JOIN
 (VALUES ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) v(privilege)
 WHERE CASE WHEN c.relkind='S' THEN false ELSE pg_catalog.has_table_privilege(r.oid,c.oid,v.privilege) END
 UNION ALL
 SELECT c.oid,r.oid,'column',a.attnum,v.privilege
 FROM objects c JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
 CROSS JOIN callers r CROSS JOIN (VALUES ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) v(privilege)
 WHERE CASE WHEN c.relkind='S' THEN false ELSE pg_catalog.has_column_privilege(r.oid,c.oid,a.attnum,v.privilege) END
 UNION ALL
 SELECT c.oid,r.oid,'sequence',NULL::pg_catalog.int2,v.privilege
 FROM objects c CROSS JOIN callers r CROSS JOIN (VALUES ('USAGE'),('SELECT'),('UPDATE')) v(privilege)
 WHERE CASE WHEN c.relkind='S' THEN pg_catalog.has_sequence_privilege(r.oid,c.oid,v.privilege) ELSE false END
), acl_entries AS (
 SELECT c.oid AS object_oid,'relation'::pg_catalog.text AS origin,NULL::pg_catalog.int2 AS column_number,
 c.relacl IS NULL AS implicit_default,a.*
 FROM objects c CROSS JOIN LATERAL
 pg_catalog.aclexplode(COALESCE(c.relacl,pg_catalog.acldefault(CASE WHEN c.relkind='S' THEN 's'::pg_catalog."char" ELSE 'r'::pg_catalog."char" END,c.relowner))) a
 UNION ALL
 SELECT c.oid,'column',x.attnum,false,a.* FROM objects c
 JOIN pg_catalog.pg_attribute x ON x.attrelid=c.oid AND x.attnum>0 AND NOT x.attisdropped
 CROSS JOIN LATERAL pg_catalog.aclexplode(x.attacl) a
 UNION ALL
 SELECT c.oid,'schema',NULL::pg_catalog.int2,c.nspacl IS NULL,a.* FROM objects c
 CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(c.nspacl,pg_catalog.acldefault('n',c.nspowner))) a
), reach(caller_oid,role_oid) AS (
 SELECT oid,oid FROM callers
 UNION
 SELECT q.caller_oid,m.roleid FROM reach q JOIN membership_edges m ON m.member=q.role_oid
), targets(role_oid) AS (
 SELECT grantee FROM acl_entries WHERE grantee<>0
 UNION SELECT relowner FROM objects
 UNION SELECT nspowner FROM objects
 UNION SELECT oid FROM special_roles WHERE oid IS NOT NULL
 UNION SELECT datdba FROM database_context
), towards(role_oid) AS (
 SELECT role_oid FROM targets
 UNION SELECT m.member FROM towards t JOIN membership_edges m ON m.roleid=t.role_oid
), set_contexts AS (
 SELECT r.oid AS caller_oid,x.oid AS context_oid FROM callers r CROSS JOIN pg_catalog.pg_roles x
 WHERE pg_catalog.pg_has_role(r.oid,x.oid,'SET')
), role_paths AS (
 SELECT r.oid AS caller_oid,t.role_oid,
 pg_catalog.pg_has_role(r.oid,t.role_oid,'USAGE') AS effective_usage,
 pg_catalog.pg_has_role(r.oid,t.role_oid,'SET') AS direct_set,
 ARRAY(SELECT sc.context_oid FROM set_contexts sc WHERE sc.caller_oid=r.oid
  AND pg_catalog.pg_has_role(sc.context_oid,t.role_oid,'USAGE') ORDER BY sc.context_oid) AS set_context_oids
 FROM callers r CROSS JOIN targets t
), source_rows AS (
 SELECT q.object_oid,q.caller_oid,q.scope,q.column_number,q.privilege,
 e.origin,e.implicit_default,e.grantee,e.grantor,e.is_grantable,
 CASE WHEN e.grantee=0 THEN 'PUBLIC' WHEN e.grantee=q.caller_oid THEN 'DIRECT' ELSE 'INHERITED' END AS path
 FROM checks q JOIN acl_entries e ON e.object_oid=q.object_oid AND e.privilege_type=q.privilege
 WHERE (e.origin='relation' OR (q.scope='column' AND e.origin='column' AND e.column_number=q.column_number))
 AND CASE WHEN e.grantee=0 THEN true ELSE pg_catalog.pg_has_role(q.caller_oid,e.grantee,'USAGE') END
 UNION ALL
 -- Predefined roles confer these ordinary rights even without an object ACL.
 -- They do not confer sequence USAGE, REFERENCES, TRIGGER, TRUNCATE or grant options.
 SELECT q.object_oid,q.caller_oid,q.scope,q.column_number,q.privilege,
 'predefined'::pg_catalog.text,false,s.oid,NULL::pg_catalog.oid,false,'PREDEFINED_EFFECTIVE'::pg_catalog.text
 FROM checks q CROSS JOIN special_roles s
 WHERE s.oid IS NOT NULL AND pg_catalog.pg_has_role(q.caller_oid,s.oid,'USAGE')
 AND ((s.name='pg_read_all_data' AND q.privilege='SELECT')
  OR (s.name='pg_write_all_data' AND q.privilege IN ('INSERT','UPDATE','DELETE')))
), violations AS (
 SELECT q.*,c.nspname,c.relname,c.relkind,a.attname,r.rolname,
 r.rolsuper,r.rolbypassrls,c.relrowsecurity,c.relforcerowsecurity,
 pg_catalog.has_schema_privilege(r.oid,c.relnamespace,'USAGE') AS schema_usage,
 pg_catalog.pg_has_role(r.oid,c.relowner,'USAGE') AS inherits_owner,
 pg_catalog.pg_has_role(r.oid,c.relowner,'SET') AS can_set_owner,
 COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'origin',e.origin,'implicitDefault',e.implicit_default,'granteeOid',e.grantee,
  'grantee',CASE WHEN e.grantee=0 THEN 'PUBLIC'
   WHEN g.rolname IN ('postgres','anon','authenticated','service_role','gym_data_owner',
    'gym_owner_executor','gym_public_executor','gym_checkin_executor',
    'pg_read_all_data','pg_write_all_data','pg_database_owner') THEN g.rolname ELSE 'OTHER_ROLE' END,
  'grantorOid',e.grantor,'grantable',e.is_grantable,
  'path',e.path)
  ORDER BY e.origin,e.grantee,e.grantor,e.is_grantable)
 FROM source_rows e LEFT JOIN pg_catalog.pg_roles g ON g.oid=e.grantee
 WHERE e.object_oid=q.object_oid AND e.caller_oid=q.caller_oid AND e.scope=q.scope
 AND e.column_number IS NOT DISTINCT FROM q.column_number AND e.privilege=q.privilege),'[]'::pg_catalog.jsonb) AS sources
 FROM checks q JOIN objects c ON c.oid=q.object_oid JOIN callers r ON r.oid=q.caller_oid
 LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid=q.object_oid AND a.attnum=q.column_number
), settings AS (
 SELECT c.*,i.indisvalid,i.indisready FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 LEFT JOIN pg_catalog.pg_index i ON i.indexrelid=c.oid WHERE n.nspname='public' AND c.relname='gym_settings'
)
SELECT pg_catalog.jsonb_build_object(
 'format','M2-draft-2','serverVersion',pg_catalog.current_setting('server_version_num'),
 'effectiveRole',current_user,'connectionRole',session_user,
 'readOnly',pg_catalog.current_setting('transaction_read_only'),'isolation',pg_catalog.current_setting('transaction_isolation'),
 'statementTimeout',pg_catalog.current_setting('statement_timeout'),'lockTimeout',pg_catalog.current_setting('lock_timeout'),
 'searchPath',pg_catalog.current_setting('search_path'),'observedAt',pg_catalog.clock_timestamp(),
 'callerPresence',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name',w.name,'present',r.oid IS NOT NULL,
  'oid',r.oid,'superuser',r.rolsuper,'inheritAttribute',r.rolinherit,'bypassRls',r.rolbypassrls) ORDER BY w.name)
  FROM (VALUES ('anon'),('authenticated'),('service_role')) w(name) LEFT JOIN callers r ON r.rolname=w.name),
 'objectCount',(SELECT pg_catalog.count(*) FROM objects),
 'scopeInventory',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('schema',c.nspname,'name',c.relname,
  'oid',c.oid,'kind',c.relkind,'ownerOid',c.relowner,'rls',c.relrowsecurity,'force',c.relforcerowsecurity)
  ORDER BY c.nspname,c.relname) FROM objects c),'[]'::pg_catalog.jsonb),
 'unit22FailingObjectCallerPairs',(SELECT pg_catalog.count(*) FROM
  (SELECT DISTINCT object_oid,caller_oid FROM checks) x),
 'effectivePrivilegeRows',(SELECT pg_catalog.count(*) FROM checks),
 'unattributedNonSuperuserRows',(SELECT pg_catalog.count(*) FROM violations WHERE NOT rolsuper AND sources='[]'::pg_catalog.jsonb),
 'attributionStatus',CASE WHEN (SELECT pg_catalog.count(*) FROM callers)<>3
  OR EXISTS(SELECT 1 FROM special_roles WHERE oid IS NULL)
  OR (SELECT pg_catalog.count(*) FROM database_context)<>1 OR (SELECT pg_catalog.count(*) FROM settings)<>1
  OR NOT EXISTS(SELECT 1 FROM objects)
  OR EXISTS(SELECT 1 FROM violations WHERE NOT rolsuper AND sources='[]'::pg_catalog.jsonb)
  THEN 'INCOMPLETE_HOLD' ELSE 'CANDIDATE_SOURCES_IDENTIFIED_NOT_VERIFIED' END,
 'catalogVisibility','REQUIRES_OWNER_ATTESTATION_NO_AUTOMATIC_COMPLETE_ATTRIBUTION',
 'gymSettingsComparisonStatus','REQUIRES_TRUSTED_REFERENCE_FINGERPRINTS',
 'predefinedCapabilityPaths',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'caller',r.rolname,'role',s.name,'present',s.oid IS NOT NULL,'roleOid',s.oid,
  'effectiveUsage',p.effective_usage,'directSet',p.direct_set,'setThenInheritContexts',p.set_context_oids,
  'grantsSchemaUsage',s.name IN ('pg_read_all_data','pg_write_all_data'),
  'bypassesRlsByItself',false) ORDER BY r.rolname,s.name)
  FROM callers r CROSS JOIN special_roles s
  LEFT JOIN role_paths p ON p.caller_oid=r.oid AND p.role_oid=s.oid),'[]'::pg_catalog.jsonb),
 'databaseOwnerPaths',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'caller',r.rolname,'databaseOid',d.oid,'ownerOid',d.datdba,'isDatabaseOwner',r.oid=d.datdba,
  'effectiveOwnerRole',p.effective_usage,'canSetOwnerRole',p.direct_set,
  'setThenInheritOwnerContexts',p.set_context_oids,
  'implicitDatabaseOwnerRoleOid',s.oid,'doesNotGrantAllTablePrivileges',true) ORDER BY r.rolname)
  FROM callers r CROSS JOIN database_context d CROSS JOIN special_roles s
  LEFT JOIN role_paths p ON p.caller_oid=r.oid AND p.role_oid=d.datdba
  WHERE s.name='pg_database_owner'),'[]'::pg_catalog.jsonb),
 'latentSetGrantPaths',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'schema',c.nspname,'object',c.relname,'origin',e.origin,'columnNumber',e.column_number,
  'caller',r.rolname,'granteeOid',e.grantee,'grantorOid',e.grantor,
  'privilege',e.privilege_type,'grantable',e.is_grantable,
  'directSet',p.direct_set,'setThenInheritContexts',p.set_context_oids)
  ORDER BY c.nspname,c.relname,r.rolname,e.origin,e.column_number,e.grantee,e.privilege_type,e.grantor)
  FROM acl_entries e JOIN objects c ON c.oid=e.object_oid CROSS JOIN callers r
  JOIN role_paths p ON p.caller_oid=r.oid AND p.role_oid=e.grantee
  WHERE NOT p.effective_usage AND COALESCE(pg_catalog.array_length(p.set_context_oids,1),0)>0),'[]'::pg_catalog.jsonb),
 'violations',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'schema',nspname,'object',relname,'kind',relkind,'objectOid',object_oid,
  'caller',rolname,'scope',scope,'column',attname,'privilege',privilege,
  'schemaUsage',schema_usage,'superuser',rolsuper,'bypassRls',rolbypassrls,
  'inheritsOwner',inherits_owner,'canSetOwner',can_set_owner,
  'rls',relrowsecurity,'force',relforcerowsecurity,'sources',sources)
  ORDER BY nspname,relname,rolname,scope,column_number,privilege) FROM violations),'[]'::pg_catalog.jsonb),
 'schemaGrantPaths',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('schema',x.nspname,
  'caller',x.rolname,'granteeOid',x.grantee,'grantorOid',x.grantor,'privilege',x.privilege_type,
  'grantable',x.is_grantable,'implicitDefault',x.implicit_default,'public',x.grantee=0,
  'effective',x.effective,'setReachable',x.set_reachable)
  ORDER BY x.nspname,x.rolname,x.grantee,x.privilege_type,x.grantor)
  FROM (SELECT DISTINCT c.nspname,r.rolname,e.grantee,e.grantor,e.privilege_type,e.is_grantable,e.implicit_default,
   CASE WHEN e.grantee=0 THEN true ELSE pg_catalog.pg_has_role(r.oid,e.grantee,'USAGE') END AS effective,
   CASE WHEN e.grantee=0 THEN false ELSE pg_catalog.pg_has_role(r.oid,e.grantee,'SET') END AS set_reachable
   FROM objects c JOIN acl_entries e ON e.object_oid=c.oid AND e.origin='schema' CROSS JOIN callers r
   WHERE CASE WHEN e.grantee=0 THEN true ELSE pg_catalog.pg_has_role(r.oid,e.grantee,'MEMBER') END) x),'[]'::pg_catalog.jsonb),
 'relevantMembershipEdges',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'caller',r.rolname,'memberOid',m.member,'roleOid',m.roleid,'grantorOid',m.grantor,
  'admin',m.admin_option,'inherit',m.inherit_option,'set',m.set_option,'edgeKind',m.edge_kind,
  'effectiveUsageToRole',pg_catalog.pg_has_role(r.oid,m.roleid,'USAGE'),
  'effectiveSetToRole',pg_catalog.pg_has_role(r.oid,m.roleid,'SET')) ORDER BY r.rolname,m.member,m.roleid,m.grantor)
  FROM reach q JOIN callers r ON r.oid=q.caller_oid JOIN membership_edges m ON m.member=q.role_oid
  WHERE m.roleid IN (SELECT role_oid FROM towards)),'[]'::pg_catalog.jsonb),
 'gymSettings',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'oid',c.oid,'kind',c.relkind,'owner',pg_catalog.pg_get_userbyid(c.relowner),'ownerOid',c.relowner,
  'rls',c.relrowsecurity,'force',c.relforcerowsecurity,'aclIsNull',c.relacl IS NULL,
  'catalogComposite',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('kind',c.relkind,'owner',pg_catalog.pg_get_userbyid(c.relowner),
   'acl',c.relacl::pg_catalog.text,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,
   'index',CASE WHEN c.relkind='i' THEN pg_catalog.pg_get_indexdef(c.oid) ELSE NULL END,
   'view',CASE WHEN c.relkind IN ('v','m') THEN pg_catalog.pg_get_viewdef(c.oid) ELSE NULL END,
   'valid',c.indisvalid,'ready',c.indisready)::pg_catalog.text,'UTF8')),'hex'),
  'aclRawSha256',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('value',c.relacl::pg_catalog.text)::pg_catalog.text,'UTF8')),'hex'),
  'policies',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name',p.polname,'command',p.polcmd,
   'permissive',p.polpermissive,'hasUsing',p.polqual IS NOT NULL,'hasCheck',p.polwithcheck IS NOT NULL,
   'fingerprint',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('command',p.polcmd,'permissive',p.polpermissive,
    'using',pg_catalog.pg_get_expr(p.polqual,p.polrelid),'check',pg_catalog.pg_get_expr(p.polwithcheck,p.polrelid),
    'roles',ARRAY(SELECT CASE WHEN x=0 THEN 'PUBLIC' ELSE pg_catalog.pg_get_userbyid(x) END
     FROM pg_catalog.unnest(p.polroles) x ORDER BY 1))::pg_catalog.text,'UTF8')),'hex')) ORDER BY p.polname)
   FROM pg_catalog.pg_policy p WHERE p.polrelid=c.oid),'[]'::pg_catalog.jsonb),
  'constraints',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name',k.conname,'kind',k.contype,
   'validated',k.convalidated,'fingerprint',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'definition',pg_catalog.pg_get_constraintdef(k.oid),'valid',k.convalidated)::pg_catalog.text,'UTF8')),'hex')) ORDER BY k.conname)
   FROM pg_catalog.pg_constraint k WHERE k.conrelid=c.oid),'[]'::pg_catalog.jsonb)
 ) ORDER BY c.oid) FROM settings c),'[]'::pg_catalog.jsonb)
) AS diagnostic;
ROLLBACK;
