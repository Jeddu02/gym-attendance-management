// Local-only forward compatibility artifacts. Never executes SQL or changes history.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { verifySourceManifest } from './compare-catalog.mjs';
const require = createRequire(import.meta.url);
const parser = require('./parser.cjs')(17);
await parser.loadModule();
const root = new URL('../../', import.meta.url);
const manifest = JSON.parse(readFileSync(new URL('supabase/recovery/source-manifest.json', root), 'utf8'));
verifySourceManifest(manifest.migrations);
const roles = "'gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor'";
const provider = process.argv.includes('--synthetic') ? 'gf_provider_admin' : 'supabase_admin';
const output = new URL(`supabase/recovery/compatibility/${provider === 'supabase_admin' ? 'review' : 'synthetic'}/`, root);
mkdirSync(output, { recursive: true });
const sha = text => createHash('sha256').update(text).digest('hex');
const allowedEdge = (alias, temporary = false) => `(${alias}.roleid IN (SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN (${roles}))
 AND ${alias}.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND ((${alias}.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='${provider}')
 AND ${alias}.admin_option AND NOT ${alias}.inherit_option AND NOT ${alias}.set_option)${temporary ? `
 OR (${alias}.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND NOT ${alias}.admin_option AND ${alias}.inherit_option AND ${alias}.set_option)` : ''}))`;

function graphGuard(temporary = false) {
  return `DO $compatibility_graph$
 BEGIN
 IF current_user<>'postgres' OR session_user<>'postgres'
 OR current_setting('server_version_num')::integer/10000<>17
 OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=current_user AND rolcreaterole AND NOT rolsuper ${provider==='gf_provider_admin' ? 'AND NOT rolbypassrls' : ''})
 THEN RAISE EXCEPTION 'Customer PG17 migration identity required'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles r ON r.oid=m.roleid OR r.oid=m.member
 WHERE r.rolname IN (${roles}) AND NOT ${allowedEdge('m', temporary)})
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN (${roles}) AND
 (r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolinherit OR r.rolreplication OR r.rolbypassrls))
 THEN RAISE EXCEPTION 'Unapproved compatibility role graph or attributes'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN (${roles}) AND
 (SELECT count(*) FROM pg_catalog.pg_auth_members m WHERE m.roleid=r.oid AND m.member=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='postgres')
 AND m.grantor=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname='${provider}') AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option)<>1)
 THEN RAISE EXCEPTION 'Required provider ADMIN edge absent or changed'; END IF;
${temporary ? '' : ` IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r CROSS JOIN pg_catalog.pg_namespace n
 WHERE r.rolname IN (${roles}) AND n.nspname IN ('private','api','public','extensions') AND pg_catalog.has_schema_privilege(r.oid,n.oid,'CREATE'))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_policy WHERE polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Unexpected at-rest migration capability'; END IF;`}
 END $compatibility_graph$;`;
}

function prepare({ data = true, publicOwner = false, readTables = [] } = {}) {
  return `${graphGuard(true)}
 DO $compatibility_prepare$ DECLARE r record; BEGIN
 FOR r IN SELECT rolname FROM pg_catalog.pg_roles WHERE rolname IN (${roles}) ORDER BY rolname LOOP
 EXECUTE pg_catalog.format('GRANT %I TO postgres WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY postgres',r.rolname);
${data ? ` IF r.rolname='gym_data_owner' THEN
 EXECUTE 'GRANT CREATE ON SCHEMA private TO gym_data_owner';
${publicOwner ? " EXECUTE 'GRANT CREATE ON SCHEMA public TO gym_data_owner';" : ''}
 ELSE EXECUTE pg_catalog.format('GRANT CREATE ON SCHEMA api TO %I',r.rolname); END IF;` : ''}
 END LOOP;
${readTables.length ? ` FOR r IN SELECT n.nspname,c.relname FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind IN ('r','p') AND c.relforcerowsecurity AND n.nspname='private' AND c.relname IN (${readTables.map(x => `'${x}'`).join(',')}) LOOP
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.nspname,r.relname)) AND p.polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Unexpected maintenance policy'; END IF;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_policy p WHERE p.polrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.nspname,r.relname)) AND NOT p.polpermissive)
 THEN RAISE EXCEPTION 'Unreviewed restrictive policy prevents full-visibility proof'; END IF;
 EXECUTE pg_catalog.format('CREATE POLICY gf_compatibility_read ON %I.%I FOR SELECT TO postgres USING (CURRENT_USER = ''postgres''::name AND SESSION_USER = ''postgres''::name)',r.nspname,r.relname);
 END LOOP;` : ''}
 END $compatibility_prepare$;`;
}

function cleanup() {
  return `DO $compatibility_cleanup$ DECLARE r record; BEGIN
 FOR r IN SELECT n.nspname,c.relname FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE p.polname='gf_compatibility_read' AND (n.nspname='private' OR (n.nspname='public' AND c.relname='gym_settings')) LOOP
 EXECUTE pg_catalog.format('DROP POLICY gf_compatibility_read ON %I.%I',r.nspname,r.relname);
 END LOOP;
 FOR r IN SELECT rolname FROM pg_catalog.pg_roles WHERE rolname IN (${roles}) ORDER BY rolname LOOP
 EXECUTE pg_catalog.format('REVOKE CREATE ON SCHEMA private,api,public FROM %I',r.rolname);
 EXECUTE pg_catalog.format('REVOKE %I FROM postgres GRANTED BY postgres',r.rolname);
 END LOOP;
 END $compatibility_cleanup$;
 ${graphGuard()}
 DO $compatibility_closed$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles r CROSS JOIN pg_catalog.pg_namespace n WHERE r.rolname IN (${roles})
 AND n.nspname IN ('private','api','public') AND pg_catalog.has_schema_privilege(r.oid,n.oid,'CREATE'))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN (${roles}) AND
 (pg_catalog.pg_has_role('postgres',r.oid,'SET') OR pg_catalog.pg_has_role('postgres',r.oid,'USAGE')))
 OR EXISTS(SELECT 1 FROM pg_catalog.pg_policy WHERE polname='gf_compatibility_read')
 THEN RAISE EXCEPTION 'Temporary migration authority leaked'; END IF;
 END $compatibility_closed$;`;
}

// Only membership predicates inside source DO assertion queries change. Bodies of
// every CREATE FUNCTION must remain byte-identical, checked via the parsed AST.
function adaptGraph(text, temporary = true) {
  let count = 0;
  const result = text.replace(/(FROM (?:pg_catalog\.)?pg_auth_members (\w+)[\s\S]*?WHERE (\w+)\.rolname(?: IN\s*\([^)]*\)|='[^']*'|=actor))/g,
    (_, prefix, alias) => { count++; return `${prefix} AND NOT ${allowedEdge(alias, temporary)}`; });
  return { text: result, count };
}
const once = (text, anchor, replacement) => {
  if (text.split(anchor).length !== 2) throw new Error('Compatibility anchor drift');
  return text.replace(anchor, replacement);
};
const normalize = value => Array.isArray(value) ? value.map(normalize)
  : value && typeof value === 'object' ? Object.fromEntries(Object.entries(value).filter(([key]) => !['location','stmt_location','stmt_len'].includes(key)).map(([key, child]) => [key,normalize(child)])) : value;
const functionBodies = sql => parser.parseSync(sql).stmts.filter(x => x.stmt.CreateFunctionStmt)
  .map(x => normalize(x.stmt.CreateFunctionStmt));
const records = [];
function save(file, original, sql, edits, originalHash = sha(original)) {
  parser.parseSync(sql);
  if (JSON.stringify(functionBodies(original.replace(/\r\n/g, '\n'))) !== JSON.stringify(functionBodies(sql))) throw new Error('Application routine body changed');
  const header = `-- LOCAL REVIEW ARTIFACT. NOT A MIGRATION-HISTORY ENTRY OR PRODUCTION AUTHORIZATION.\n-- Original source preserved; provider=${provider}; source SHA-256=${originalHash}\n`;
  const final = header + sql;
  writeFileSync(new URL(file, output), final);
  records.push({ file, originalSha256: originalHash, compatibilitySha256: sha(final), membershipPredicates: edits,
    functionBodiesPreserved: true, historyAction: 'NONE', provider });
}
for (const item of manifest.migrations.filter(x => x.version >= '20261110100000')) {
  const original = readFileSync(new URL('supabase/migrations/' + item.file, root), 'utf8').replace(/^\uFEFF/, '');
  let { text: sql, count } = adaptGraph(original.replace(/\r\n/g, '\n'));
  const expectedCount = { '20261110100000':3, '20261110110000':1, '20261110120000':1, '20261110140000':1, '20261110150000':1 }[item.version] ?? 0;
  if (count !== expectedCount) throw new Error('Membership assertion inventory drift');
  sql = once(sql, 'BEGIN;', `BEGIN;\nSET LOCAL search_path=pg_catalog;\nSET LOCAL lock_timeout='5s';\nSET LOCAL statement_timeout='120s';\n${graphGuard()}`);
  if (item.version === '20261110100000') {
    sql = once(sql, 'ALTER TABLE private.attendance_checkins OWNER TO gym_data_owner;', `${prepare({ data: true, publicOwner: true })}\nALTER TABLE private.attendance_checkins OWNER TO gym_data_owner;`);
    sql = once(sql, 'GRANT EXECUTE ON FUNCTION extensions.digest(bytea,text) TO gym_owner_executor;',
      `-- Provider ACL is not customer-owned: verify effective dependency access, never impersonate its grantor.\nDO $digest_access$ BEGIN IF NOT pg_catalog.has_function_privilege('gym_owner_executor','extensions.digest(bytea,text)','EXECUTE') THEN RAISE EXCEPTION 'Provider digest EXECUTE unavailable'; END IF; END $digest_access$;\nGRANT CREATE ON SCHEMA private TO gym_data_owner;\nGRANT CREATE ON SCHEMA api TO gym_owner_executor,gym_public_executor;`);
    sql = once(sql, "SET LOCAL gymforce.assertion_profile='proposed_owner_executor';", `${cleanup()}\nSET LOCAL gymforce.assertion_profile='proposed_owner_executor';`);
  } else {
    const readTables = {
      '20261110103000':['audit_events','audit_chain_heads'],
      '20261110110000':['members','membership_purchases','payment_records','payment_allocations','payment_events'],
      '20261110160000':['membership_purchases'],
      '20261110170000':['cash_drawer_sessions']
    }[item.version] ?? [];
    sql = once(sql, graphGuard(), `${graphGuard()}\n${prepare({ readTables })}`);
    if (item.version === '20261110150000') {
      // Old owners are assumed for the lock. New verifier is prepared only after its source role guard.
      sql = once(sql, 'ALTER DEFAULT PRIVILEGES FOR ROLE gym_checkin_executor',
        `GRANT gym_checkin_executor TO postgres WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY postgres;\nGRANT CREATE ON SCHEMA api TO gym_checkin_executor;\nALTER DEFAULT PRIVILEGES FOR ROLE gym_checkin_executor`);
      sql = once(sql, 'DO $verifier_boundaries$', `${cleanup()}\nDO $verifier_boundaries$`);
    } else sql = once(sql, 'COMMIT;', `${cleanup()}\nCOMMIT;`);
  }
  save(item.file, original, sql, count, item.sha256);
}
const proposal = readFileSync(new URL('supabase/recovery/proposals/01-explicit-routine-acls.sql', root), 'utf8');
let adapted = adaptGraph(proposal.replace(/\r\n/g, '\n'));
adapted.text = once(adapted.text, 'BEGIN;', `BEGIN;\nSET LOCAL search_path=pg_catalog;\n${graphGuard()}\n${prepare({ data: false })}`);
adapted.text = once(adapted.text, 'COMMIT;', `${cleanup()}\nCOMMIT;`);
save('01-explicit-routine-acls.sql', proposal, adapted.text, adapted.count);
for (const file of ['executor_hardening_assertions.sql','member_checkin_behavior.sql','final_security_assertions.sql']) {
  const original = readFileSync(new URL('supabase/tests/' + file, root), 'utf8');
  const { text, count } = adaptGraph(original.replace(/\r\n/g, '\n'), false);
  if (count !== 1) throw new Error('Assertion variant membership inventory drift');
  writeFileSync(new URL(file, output), text);
  records.push({ file, assertionVariant: true, originalSha256: sha(original), compatibilitySha256: sha(text), membershipPredicates: count });
}
let screen = readFileSync(new URL('supabase/recovery/effective-privileges.sql', root), 'utf8').replace(/\r\n/g, '\n');
const graphScreen = screen.match(/SELECT 'reserved_membership_edges',[\s\S]*?WHERE r\.rolname IN\s*\([^)]*\)/)?.[0];
if (!graphScreen) throw new Error('Reserved graph screen drift');
screen = once(screen, graphScreen, `${graphScreen} AND NOT ${allowedEdge('m')}`);
writeFileSync(new URL('effective-privileges.sql', output), screen);
records.push({ file:'effective-privileges.sql', originalSha256:sha(readFileSync(new URL('supabase/recovery/effective-privileges.sql',root))), compatibilitySha256:sha(screen), assertionVariant:true });
const diagnosticOriginal = readFileSync(new URL('supabase/recovery/diagnostics/compatibility-authority.sql',root),'utf8');
const diagnostic = provider==='supabase_admin' ? diagnosticOriginal : once(diagnosticOriginal,"rolname='supabase_admin'",`rolname='${provider}'`);
parser.parseSync(diagnostic);
writeFileSync(new URL('compatibility-authority.sql',output),diagnostic);
records.push({ file:'compatibility-authority.sql', originalSha256:sha(diagnosticOriginal), compatibilitySha256:sha(diagnostic), readOnly:true });
if (provider === 'gf_provider_admin') {
  const body = `BEGIN; SET LOCAL search_path=pg_catalog; SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='30s';
 ${graphGuard()} ${prepare({ readTables:['members'] })}
 DO $rls_proof$ DECLARE affected integer; BEGIN
 IF NOT pg_catalog.row_security_active('private.members'::regclass) OR NOT EXISTS(SELECT 1 FROM private.members)
 THEN RAISE EXCEPTION 'FORCE RLS or full-visibility fixture absent'; END IF;
 BEGIN
 INSERT INTO private.members(member_code,full_name,mobile_lookup_hash,mobile_encrypted,status)
 VALUES('GF-COMPAT-RLS','Synthetic fixture',decode(repeat('fe',32),'hex'),decode('01','hex'),'pending');
 RAISE EXCEPTION 'Temporary SELECT policy permitted INSERT';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE private.members SET full_name=full_name;
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'Temporary SELECT policy permitted UPDATE'; END IF;
 END $rls_proof$;
 ${cleanup()} ROLLBACK;`;
  parser.parseSync(body);
  writeFileSync(new URL('maintenance-rls-proof.sql', output),body);
  records.push({ file:'maintenance-rls-proof.sql', compatibilitySha256:sha(body), syntheticOnly:true });
  const versions = manifest.migrations.filter(x=>x.recordedInSuppliedHistory).map(x=>`('${x.version}')`).join(',');
  const historyFile = `-- Isolated SQL-query fixture, not migration runner history or applied-source evidence.
\\set ON_ERROR_STOP on
BEGIN;
DO $guard$ BEGIN IF current_database()<>'gymforce_batch1_synthetic' OR current_user<>'gf_provider_admin'
OR current_setting('gymforce.synthetic_run_id',true) IS NULL OR to_regnamespace('supabase_migrations') IS NOT NULL
THEN RAISE EXCEPTION 'Fresh synthetic history fixture required'; END IF; END $guard$;
CREATE SCHEMA supabase_migrations;
CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY);
INSERT INTO supabase_migrations.schema_migrations(version) VALUES ${versions};
COMMIT;
\\ir ../../history.sql
BEGIN;
DROP TABLE supabase_migrations.schema_migrations;
DROP SCHEMA supabase_migrations;
COMMIT;
`;
  const fixture = historyFile;
  writeFileSync(new URL('history-fixture.sql',output),fixture);
  records.push({ file:'history-fixture.sql', compatibilitySha256:sha(fixture), syntheticOnly:true });
}
writeFileSync(new URL('manifest.json',output), JSON.stringify({ format:1, provider, sourceManifest:manifest.migrations, productionAuthorization:false, records },null,2)+'\n');
console.log(`PASS: ${records.length} review artifacts; unchanged runtime bodies; provider=${provider}; no SQL executed, no history changes.`);
