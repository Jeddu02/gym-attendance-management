// Builds SQL text only. Never opens a database connection or starts a process.
import { directory, read, statements, digest } from './source-contract.mjs';
import { buildAlignedContract } from './aligned-contract.mjs';
import fs from 'node:fs';
import path from 'node:path';
export function hardeningBlock(contract=buildAlignedContract()) {
  const expected=JSON.stringify(contract);
  return `DO $offline_contract$
DECLARE
    contract jsonb := $contract_json$${expected}$contract_json$::jsonb;
    item jsonb; col jsonb; key_entry jsonb; obj oid; actual text; normalized text; wanted text;
    creator text; namespace_name text; object_kind text; creator_oid oid;
    lex_pattern text := $lex$'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\\.[0-9]+)?|::|<>|<=|>=|&&|!=|\\|\\||[^[:space:]]$lex$;
BEGIN
    IF current_setting('server_version_num')::integer / 10000 <> 18 THEN
      RAISE EXCEPTION 'Aligned catalog assertions require the reviewed native PostgreSQL 18 target';
    END IF;
    -- Native profile has NO public/graphql_public functions or procedures.
    -- No provider exemption is inferred from a name or presumed extension.
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
       WHERE n.nspname IN ('public','graphql_public')) THEN
        RAISE EXCEPTION 'Unexpected exposed function/procedure: native profile allows none';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace n,
       LATERAL pg_catalog.aclexplode(COALESCE(n.nspacl,pg_catalog.acldefault('n',n.nspowner))) acl
       WHERE n.nspname IN ('public','private','api','graphql_public','extensions')
         AND acl.privilege_type='CREATE' AND acl.grantee<>n.nspowner
         AND acl.grantee<>(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')) THEN
      RAISE EXCEPTION 'Unapproved schema-creating principal';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace n
       WHERE n.nspname IN ('private','api') AND n.nspowner<>(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')) THEN
        RAISE EXCEPTION 'Application schema owner drift';
    END IF;
    FOREACH creator IN ARRAY ARRAY['anon','authenticated','service_role','gym_registration_login','gym_data_owner','gym_owner_executor','gym_public_executor'] LOOP
      FOREACH namespace_name IN ARRAY ARRAY['public','private','api','graphql_public','extensions'] LOOP
        IF pg_catalog.to_regnamespace(namespace_name) IS NOT NULL
           AND pg_catalog.has_schema_privilege(creator,namespace_name,'CREATE') THEN
          RAISE EXCEPTION 'Unapproved schema CREATE: % / %',creator,namespace_name;
        END IF;
      END LOOP;
    END LOOP;
    -- Every creator independently: implicit global defaults plus additive schema defaults.
    -- No default ACL changes here. Function EXECUTE remains owner-only.
    -- Only unmodified implicit PUBLIC type USAGE is accepted: not table/RPC access.
    FOR creator IN SELECT jsonb_array_elements_text(contract->'creators') LOOP
      SELECT oid INTO creator_oid FROM pg_catalog.pg_roles WHERE rolname=creator;
      IF creator_oid IS NULL THEN RAISE EXCEPTION 'Missing reviewed creator %',creator; END IF;
      FOREACH object_kind IN ARRAY ARRAY['r','S','f','T'] LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.aclexplode(COALESCE(
          (SELECT d.defaclacl FROM pg_catalog.pg_default_acl d WHERE d.defaclrole=creator_oid
           AND d.defaclnamespace=0 AND d.defaclobjtype=object_kind::pg_catalog."char"),
          pg_catalog.acldefault(object_kind::pg_catalog."char",creator_oid))) acl
          WHERE acl.grantee<>creator_oid
            AND NOT (object_kind='T' AND acl.grantee=0 AND acl.privilege_type='USAGE' AND NOT acl.is_grantable
              AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_default_acl implicit_type
                WHERE implicit_type.defaclrole=creator_oid AND implicit_type.defaclnamespace=0
                  AND implicit_type.defaclobjtype='T'))) THEN
          RAISE EXCEPTION 'Unsafe effective global default ACL: creator % kind %',creator,object_kind;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_default_acl d JOIN pg_catalog.pg_namespace n ON n.oid=d.defaclnamespace,
          LATERAL pg_catalog.aclexplode(d.defaclacl) acl
          WHERE d.defaclrole=creator_oid AND d.defaclobjtype=object_kind::pg_catalog."char"
            AND n.nspname IN ('private','api','public','graphql_public') AND acl.grantee<>creator_oid) THEN
          RAISE EXCEPTION 'Unsafe additive schema default ACL: creator % kind %',creator,object_kind;
        END IF;
      END LOOP;
    END LOOP;
    FOR item IN SELECT value FROM jsonb_array_elements(contract->'tables') LOOP
      obj := pg_catalog.to_regclass(item->>'name');
      IF obj IS NULL THEN RAISE EXCEPTION 'Missing contract table'; END IF;
      IF (SELECT count(*) FROM pg_catalog.pg_attribute WHERE attrelid=obj AND attnum>0 AND NOT attisdropped)
         <>jsonb_array_length(item->'columns') THEN RAISE EXCEPTION 'Column inventory mismatch: %',item->>'name'; END IF;
      FOR col IN SELECT value FROM jsonb_array_elements(item->'columns') LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a WHERE a.attrelid=obj AND a.attname=col->>'name'
          AND a.attnum>0 AND NOT a.attisdropped AND a.attnotnull=(col->>'not_null')::boolean
          AND a.attidentity::text=col->>'identity' AND a.attgenerated::text=col->>'generated') THEN
          RAISE EXCEPTION 'Column nullability/identity/generated mismatch: %.%',item->>'name',col->>'name';
        END IF;
        SELECT pg_catalog.format_type(a.atttypid,a.atttypmod) INTO actual FROM pg_catalog.pg_attribute a
          WHERE a.attrelid=obj AND a.attname=col->>'name';
        SELECT string_agg(CASE WHEN left(m[1],1) IN ('''','"') THEN m[1] ELSE lower(m[1]) END,' ' ORDER BY ordinal) INTO normalized
          FROM pg_catalog.regexp_matches(actual,lex_pattern,'g') WITH ORDINALITY token(m,ordinal);
        IF normalized IS DISTINCT FROM col->>'type' THEN RAISE EXCEPTION 'Column type drift'; END IF;
        SELECT pg_catalog.pg_get_expr(d.adbin,d.adrelid,false) INTO actual FROM pg_catalog.pg_attrdef d
          JOIN pg_catalog.pg_attribute a ON a.attrelid=d.adrelid AND a.attnum=d.adnum
          WHERE a.attrelid=obj AND a.attname=col->>'name';
        SELECT string_agg(CASE WHEN left(m[1],1) IN ('''','"') THEN m[1] ELSE lower(m[1]) END,' ' ORDER BY ordinal) INTO normalized
          FROM pg_catalog.regexp_matches(actual,lex_pattern,'g') WITH ORDINALITY token(m,ordinal);
        IF normalized IS DISTINCT FROM col->>'catalog_default' THEN
          RAISE EXCEPTION 'Column default/generated expression drift (verified catalog contract): %.%',item->>'name',col->>'name';
        END IF;
      END LOOP;
      -- PostgreSQL 18 NOT NULL catalog constraints are represented by attnotnull above.
      IF (SELECT count(*) FROM pg_catalog.pg_constraint WHERE conrelid=obj AND contype<>'n')
         <>jsonb_array_length(item->'constraints') THEN RAISE EXCEPTION 'Constraint inventory drift'; END IF;
      FOR col IN SELECT value FROM jsonb_array_elements(item->'constraints') LOOP
        SELECT pg_catalog.pg_get_constraintdef(c.oid,false) INTO actual FROM pg_catalog.pg_constraint c
          WHERE c.conrelid=obj AND c.conname=col->>'name' AND c.contype::text=col->>'kind'
            AND c.convalidated AND c.conislocal AND c.coninhcount=0 AND c.conenforced
            AND (col->>'no_inherit' IS NULL OR c.connoinherit=(col->>'no_inherit')::boolean)
            AND c.condeferrable=(col->>'deferrable')::boolean AND c.condeferred=(col->>'deferred')::boolean;
        SELECT string_agg(CASE WHEN left(m[1],1) IN ('''','"') THEN m[1] ELSE lower(m[1]) END,' ' ORDER BY ordinal) INTO normalized
          FROM pg_catalog.regexp_matches(actual,lex_pattern,'g') WITH ORDINALITY token(m,ordinal);
        IF normalized IS DISTINCT FROM col->>'catalog_definition' THEN
          RAISE EXCEPTION 'Constraint definition drift (verified catalog contract): %',col->>'name';
        END IF;
        IF col->>'kind'='x' AND NOT EXISTS (
          SELECT 1 FROM pg_catalog.pg_constraint ck JOIN pg_catalog.pg_index ix ON ix.indexrelid=ck.conindid
          JOIN pg_catalog.pg_class ic ON ic.oid=ix.indexrelid JOIN pg_catalog.pg_am am ON am.oid=ic.relam
          WHERE ck.conrelid=obj AND ck.conname=col->>'name' AND am.amname=col->'exclusion'->>'method'
            AND ix.indnkeyatts=2 AND ix.indnatts=2 AND ix.indisexclusion
            AND ix.indkey[0]=(SELECT attnum FROM pg_catalog.pg_attribute WHERE attrelid=obj AND attname='member_id')
            AND ix.indkey[1]=0
            AND ck.conexclop=(SELECT array_agg(pg_catalog.to_regoperator(value)::oid ORDER BY ord)
              FROM jsonb_array_elements_text(col->'exclusion'->'operators') WITH ORDINALITY e(value,ord))
            AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(col->'exclusion'->'opclasses') WITH ORDINALITY e(v,ord)
              WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_opclass oc JOIN pg_catalog.pg_namespace ns ON ns.oid=oc.opcnamespace
                WHERE oc.oid=ix.indclass[e.ord::integer-1] AND ns.nspname=e.v->>'schema' AND oc.opcname=e.v->>'name'
                  AND oc.opcintype=pg_catalog.to_regtype(e.v->>'type') AND oc.opcdefault AND oc.opcmethod=am.oid))
        ) THEN RAISE EXCEPTION 'Exclusion opclass/operator/key drift'; END IF;
      END LOOP;
      IF EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c JOIN pg_catalog.pg_index i ON i.indexrelid=c.conindid
        WHERE c.conrelid=obj AND c.contype IN ('p','u','x') AND
          (NOT i.indisvalid OR NOT i.indisready OR NOT i.indislive OR
           i.indisprimary IS DISTINCT FROM (c.contype='p') OR
           i.indisunique IS DISTINCT FROM (c.contype IN ('p','u')) OR
           i.indisexclusion IS DISTINCT FROM (c.contype='x') OR
           i.indimmediate IS DISTINCT FROM (NOT c.condeferrable))) THEN
        RAISE EXCEPTION 'Constraint-backed index metadata drift';
      END IF;
      IF EXISTS (SELECT 1 FROM pg_catalog.pg_rewrite WHERE ev_class=obj) THEN RAISE EXCEPTION 'Unexpected table rewrite rule'; END IF;
    END LOOP;
    FOR item IN SELECT value FROM jsonb_array_elements(contract->'indexes') LOOP
      SELECT pg_catalog.pg_get_indexdef(c.oid,0,false) INTO actual FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_index i ON i.indexrelid=c.oid WHERE c.oid=pg_catalog.to_regclass(item->>'name')
          AND i.indrelid=pg_catalog.to_regclass(item->>'parent') AND i.indisvalid AND i.indisready AND i.indislive
          AND i.indisunique=(item->>'unique')::boolean
          AND NOT i.indisprimary AND NOT i.indisexclusion AND i.indimmediate AND NOT i.indnullsnotdistinct
          AND i.indnkeyatts=jsonb_array_length(item->'keys') AND i.indnatts=jsonb_array_length(item->'keys');
      SELECT string_agg(CASE WHEN left(m[1],1) IN ('''','"') THEN m[1] ELSE lower(m[1]) END,' ' ORDER BY ordinal) INTO normalized
        FROM pg_catalog.regexp_matches(actual,lex_pattern,'g') WITH ORDINALITY token(m,ordinal);
      IF normalized IS DISTINCT FROM item->>'catalog_definition' THEN RAISE EXCEPTION 'Explicit index definition drift: %',item->>'name'; END IF;
      FOR key_entry IN SELECT value FROM jsonb_array_elements(item->'keys') LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_index ix
          JOIN pg_catalog.pg_attribute ka ON ka.attrelid=ix.indexrelid AND ka.attnum=(key_entry->>'position')::integer AND NOT ka.attisdropped
          JOIN pg_catalog.pg_opclass oc ON oc.oid=ix.indclass[(key_entry->>'position')::integer-1]
          JOIN pg_catalog.pg_namespace ns ON ns.oid=oc.opcnamespace JOIN pg_catalog.pg_am am ON am.oid=oc.opcmethod
          WHERE ix.indexrelid=pg_catalog.to_regclass(item->>'name') AND am.amname='btree' AND ns.nspname='pg_catalog'
            AND oc.opcname=key_entry->>'opclass' AND oc.opcdefault AND oc.opcintype=pg_catalog.to_regtype(key_entry->>'type')
            AND ka.atttypid=pg_catalog.to_regtype(key_entry->>'type')
            AND ix.indkey[(key_entry->>'position')::integer-1]=CASE WHEN key_entry->>'column'='' THEN 0
              ELSE (SELECT attnum FROM pg_catalog.pg_attribute WHERE attrelid=ix.indrelid AND attname=key_entry->>'column' AND NOT attisdropped) END
            AND ix.indoption[(key_entry->>'position')::integer-1]=(key_entry->>'options')::integer
            AND ix.indcollation[(key_entry->>'position')::integer-1]=CASE WHEN key_entry->>'collation' IS NULL THEN 0::oid
              ELSE pg_catalog.to_regcollation(key_entry->>'collation')::oid END
        ) THEN RAISE EXCEPTION 'Explicit index key/opclass/order/collation drift'; END IF;
      END LOOP;
    END LOOP;
    -- Exact full index inventory (constraint-backed definitions checked via constraints).
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_index i JOIN pg_catalog.pg_class t ON t.oid=i.indrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace
      WHERE n.nspname IN ('private','public') AND NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_constraint c WHERE c.conindid=i.indexrelid AND c.conrelid=i.indrelid
        AND c.contype IN ('p','u','x')) AND NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(contract->'indexes') e
        WHERE pg_catalog.to_regclass(e->>'name')=i.indexrelid)) THEN RAISE EXCEPTION 'Unexpected index'; END IF;
    IF (SELECT count(*) FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('private','public') AND NOT t.tgisinternal)
      <>jsonb_array_length(contract->'triggers') THEN RAISE EXCEPTION 'Unexpected/missing user trigger'; END IF;
    FOR item IN SELECT value FROM jsonb_array_elements(contract->'routines') LOOP
      obj := pg_catalog.to_regprocedure(item->>'signature');
      IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_language l ON l.oid=p.prolang
        WHERE p.oid=obj AND p.prokind::text=item->>'kind' AND l.lanname=item->>'language'
          AND p.proisstrict=(item->>'strict')::boolean AND p.proretset=(item->>'returns_set')::boolean
          AND p.provolatile::text=item->>'volatility' AND p.proparallel::text=item->>'parallel'
          AND p.proleakproof=(item->>'leakproof')::boolean AND p.prosupport=0 AND p.provariadic=0
          AND p.probin IS NULL AND p.prosqlbody IS NULL AND p.pronargs=jsonb_array_length(item->'input_types')
          AND p.pronargdefaults=(item->>'default_count')::integer
          AND p.protrftypes IS NULL AND p.procost=(item->>'cost')::real AND p.prorows=(item->>'rows')::real
          AND COALESCE(to_jsonb(p.proargnames),'[]'::jsonb)=item->'argument_names') THEN
        RAISE EXCEPTION 'Routine execution metadata drift: %',item->>'name';
      END IF;
      IF (SELECT COALESCE(to_jsonb(p.proargmodes),'null'::jsonb) FROM pg_catalog.pg_proc p WHERE p.oid=obj)
         IS DISTINCT FROM (CASE WHEN jsonb_array_length(item->'output_types')=0 THEN 'null'::jsonb
         ELSE (SELECT jsonb_agg(mode ORDER BY ordinal) FROM (
           SELECT 'i'::text mode, ordinality ordinal FROM jsonb_array_elements(item->'input_types') WITH ORDINALITY
           UNION ALL SELECT 't',ordinality+jsonb_array_length(item->'input_types')
             FROM jsonb_array_elements(item->'output_types') WITH ORDINALITY) modes) END) THEN
        RAISE EXCEPTION 'Routine argument modes drift';
      END IF;
      IF (SELECT COALESCE(jsonb_agg(pg_catalog.format_type(a.type_oid,NULL) ORDER BY a.ordinality),'[]'::jsonb)
          FROM pg_catalog.pg_proc p,
          LATERAL unnest(COALESCE(p.proallargtypes,p.proargtypes::oid[])) WITH ORDINALITY a(type_oid,ordinality)
          WHERE p.oid=obj) IS DISTINCT FROM ((item->'input_types')||(item->'output_types')) THEN
        RAISE EXCEPTION 'Routine input/output argument types drift';
      END IF;
      SELECT pg_catalog.pg_get_function_result(obj) INTO actual;
      SELECT string_agg(CASE WHEN left(m[1],1) IN ('''','"') THEN m[1] ELSE lower(m[1]) END,' ' ORDER BY ordinal) INTO normalized
        FROM pg_catalog.regexp_matches(actual,lex_pattern,'g') WITH ORDINALITY token(m,ordinal);
      IF normalized IS DISTINCT FROM item->>'result' THEN RAISE EXCEPTION 'Routine result drift'; END IF;
      SELECT COALESCE(pg_catalog.pg_get_expr(p.proargdefaults,0,false),'') INTO actual FROM pg_catalog.pg_proc p WHERE p.oid=obj;
      SELECT COALESCE(string_agg(CASE WHEN left(m[1],1) IN ('''','"') THEN m[1] ELSE lower(m[1]) END,' ' ORDER BY ordinal),'') INTO normalized
        FROM pg_catalog.regexp_matches(actual,lex_pattern,'g') WITH ORDINALITY token(m,ordinal);
      IF normalized IS DISTINCT FROM item->>'catalog_argument_defaults' THEN RAISE EXCEPTION 'Routine default argument drift'; END IF;
      IF EXISTS (SELECT 1 FROM pg_catalog.pg_depend d WHERE d.classid='pg_catalog.pg_proc'::regclass
        AND d.objid=obj AND d.deptype='e') THEN RAISE EXCEPTION 'Unexpected routine extension membership'; END IF;
    END LOOP;
END;
$offline_contract$;`;
}
if (process.argv.includes('--write')) {
  const block=hardeningBlock();
  for (const file of ['foundation_assertions.sql.draft','20261106120000_owner_executor_foundation.sql.draft']) {
    const target=path.join(directory,file); let sql=read(target);
    sql=sql.replace(/DO \$offline_contract\$[\s\S]*?\$offline_contract\$;\r?\n/g,'');
    sql=sql.replace(/\$dependency_assertions\$;/g, match => match+'\n'+block+'\n');
    fs.writeFileSync(target,sql);
  }
  console.log('Rendered draft assertion text only; no SQL executed.');
}
// Explicit, review-only baseline update. Never called by either validator/test runner.
if (process.argv.includes('--freeze-statements-after-review')) {
  const reviewed={};
  for(const file of ['foundation_assertions.sql.draft','20261106120000_owner_executor_foundation.sql.draft','default-function-privileges.sql.draft']) {
    reviewed[file]=statements(read(path.join(directory,file))).map(s=>({kind:s.slice(0,2).join(' ').slice(0,80),sha256:digest(s.join(' '))}));
  }
  fs.writeFileSync(path.join(directory,'statement-manifest.json'),JSON.stringify(reviewed,null,2)+'\n');
  console.log('Froze draft statement inventory for review only. Not a SQL parser proof.');
}
