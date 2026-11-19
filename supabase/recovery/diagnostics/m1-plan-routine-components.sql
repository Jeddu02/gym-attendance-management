-- DRAFT — NOT AUTHORIZED FOR EXECUTION. Owner-private catalog metadata only.
-- One result; no bodies, default expressions or configuration values returned.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL search_path=pg_catalog;
WITH wanted(name) AS (VALUES ('owner_list_membership_plans'),('owner_save_membership_plan')),
routines AS (
 SELECT p.*, n.nspname, l.lanname
 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 JOIN pg_catalog.pg_language l ON l.oid=p.prolang
 WHERE n.nspname='api' AND p.proname IN (SELECT name FROM wanted)
), details AS (
 SELECT p.oid, p.proname,
 pg_catalog.jsonb_build_object(
  'oid',p.oid,'schema',p.nspname,'name',p.proname,'kind',p.prokind,
  'identity',pg_catalog.pg_get_function_identity_arguments(p.oid),
  'result',pg_catalog.pg_get_function_result(p.oid),'language',p.lanname,
  'owner',pg_catalog.pg_get_userbyid(p.proowner),'ownerOid',p.proowner,
  'securityDefiner',p.prosecdef,'volatility',p.provolatile,
  'strict',p.proisstrict,'leakproof',p.proleakproof,'parallel',p.proparallel,
  'inputCount',p.pronargs,'defaultCount',p.pronargdefaults,
  'inputTypeOids',p.proargtypes::pg_catalog.oid[],
  'arguments',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'position',a.pos,'typeOid',a.type_oid,'type',pg_catalog.format_type(a.type_oid,NULL),
    'name',p.proargnames[a.pos],
    'mode',COALESCE(p.proargmodes[a.pos]::pg_catalog.text,'i')) ORDER BY a.pos)
   FROM pg_catalog.unnest(COALESCE(p.proallargtypes,p.proargtypes::pg_catalog.oid[]))
    WITH ORDINALITY a(type_oid,pos)),'[]'::pg_catalog.jsonb),
  'emptySearchPath',COALESCE(p.proconfig @> ARRAY['search_path=""']::pg_catalog.text[],false),
  'explicitUtc',COALESCE(p.proconfig @> ARRAY['TimeZone=UTC']::pg_catalog.text[],false),
  'configEntryCount',COALESCE(pg_catalog.array_length(p.proconfig,1),0),
  'aclIsNull',p.proacl IS NULL,
  'fingerprints',pg_catalog.jsonb_build_object(
   'catalogComposite',CASE WHEN p.prokind IN ('f','p') THEN
    pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('definition',pg_catalog.pg_get_functiondef(p.oid),
     'owner',pg_catalog.pg_get_userbyid(p.proowner),'acl',p.proacl::pg_catalog.text)::pg_catalog.text,'UTF8')),'hex') END,
   'definition',CASE WHEN p.prokind IN ('f','p') THEN
    pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.pg_get_functiondef(p.oid),'UTF8')),'hex') END,
   'prosrc',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(p.prosrc,'UTF8')),'hex'),
   'sqlBodyTree',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('value',p.prosqlbody::pg_catalog.text)::pg_catalog.text,'UTF8')),'hex'),
   'configuration',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('value',p.proconfig)::pg_catalog.text,'UTF8')),'hex'),
   'owner',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('value',pg_catalog.pg_get_userbyid(p.proowner))::pg_catalog.text,'UTF8')),'hex'),
   'aclRaw',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('value',p.proacl::pg_catalog.text)::pg_catalog.text,'UTF8')),'hex'),
   'defaults',pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(pg_catalog.jsonb_build_object('value',pg_catalog.pg_get_expr(p.proargdefaults,0))::pg_catalog.text,'UTF8')),'hex')
  ),
  'routineAcl',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'granteeOid',a.grantee,'grantee',CASE WHEN a.grantee=0 THEN 'PUBLIC'
    WHEN r.rolname IN ('postgres','anon','authenticated','service_role','gym_data_owner',
     'gym_owner_executor','gym_public_executor','gym_checkin_executor') THEN r.rolname ELSE 'OTHER_ROLE' END,
   'grantorOid',a.grantor,'privilege',a.privilege_type,'grantable',a.is_grantable)
   ORDER BY a.grantee,a.grantor,a.privilege_type,a.is_grantable)
   FROM pg_catalog.aclexplode(COALESCE(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
   LEFT JOIN pg_catalog.pg_roles r ON r.oid=a.grantee),'[]'::pg_catalog.jsonb),
  'dependencies',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
   'direction',d.direction,'classOid',d.classid,'objectOid',d.objid,'subId',d.objsubid,
   'referenceClassOid',d.refclassid,'referenceOid',d.refobjid,'referenceSubId',d.refobjsubid,
   'type',d.deptype) ORDER BY d.direction,d.classid,d.objid,d.objsubid,d.refclassid,d.refobjid,d.refobjsubid,d.deptype)
   FROM (SELECT 'outgoing'::pg_catalog.text AS direction,x.* FROM pg_catalog.pg_depend x
     WHERE x.classid='pg_catalog.pg_proc'::pg_catalog.regclass AND x.objid=p.oid
    UNION ALL SELECT 'incoming'::pg_catalog.text,x.* FROM pg_catalog.pg_depend x
     WHERE x.refclassid='pg_catalog.pg_proc'::pg_catalog.regclass AND x.refobjid=p.oid) d),'[]'::pg_catalog.jsonb)
 ) AS detail
 FROM routines p
)
SELECT pg_catalog.jsonb_build_object(
 'format','M1-draft-1','serverVersion',pg_catalog.current_setting('server_version_num'),
 'effectiveRole',current_user,'connectionRole',session_user,
 'readOnly',pg_catalog.current_setting('transaction_read_only'),
 'isolation',pg_catalog.current_setting('transaction_isolation'),
 'statementTimeout',pg_catalog.current_setting('statement_timeout'),'lockTimeout',pg_catalog.current_setting('lock_timeout'),
 'searchPath',pg_catalog.current_setting('search_path'),'observedAt',pg_catalog.clock_timestamp(),
 'presence',(SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name',w.name,
  'totalKinds',(SELECT pg_catalog.count(*) FROM routines p WHERE p.proname=w.name),
  'functions',(SELECT pg_catalog.count(*) FROM routines p WHERE p.proname=w.name AND p.prokind='f')) ORDER BY w.name) FROM wanted w),
 'routines',COALESCE((SELECT pg_catalog.jsonb_agg(detail ORDER BY proname,oid) FROM details),'[]'::pg_catalog.jsonb)
) AS diagnostic;
ROLLBACK;
