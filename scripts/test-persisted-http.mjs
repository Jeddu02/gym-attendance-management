// Real loopback HTTP integration, invoked only by the guarded fresh PG17 runner.
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { createServer, request as httpRequest } from 'node:http';
import { createServer as netServer } from 'node:net';
import { readFile, writeFile, realpath, rm, readdir, access } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { createHash, createHmac, randomBytes, randomUUID } from 'node:crypto';
import { IngressMonitor, localMaintenanceTick } from './recovery/ingress-monitor.mjs';
import {qualifyCommitFaults,qualifyFinancialFaults,qualifyHttpClock,qualifyAttemptMatrix,qualifyIndependentLoad} from './recovery/qualify-http-faults.mjs';
import {DurableIngressQueue, scheduleLocalCleanup,localDestination} from './recovery/durable-ingress-ops.mjs';
import {mkdir} from 'node:fs/promises';
const root = resolve(import.meta.dirname, '..');
const runId = process.env.GYMFORCE_TEST_RUN_ID, directory = process.env.GYMFORCE_TEST_DATA_DIRECTORY;
const connection = process.env.GYMFORCE_TEST_CONNECTION, psql = process.env.GYMFORCE_TEST_PSQL;
const children = new Set(), sockets = new Set(), results = [];
const run = resolve(root, '.cache', `security-test-${runId}`);
const config = resolve(run, 'http-postgrest.conf'), profile = resolve(run, 'http-browser');
const owner = '00000000-0000-4000-8000-000000000001';
const quote = s => "'" + s.replaceAll("'", "''") + "'";
let transportCreated=false, targetValidated=false;
const poolConfig=resolve(run,'http-pool-probe.conf');let stopScheduler;
let lastRpc, lastSqlState, executedSourceHash, qualifiedSources, loadEvidence;
let guard, stage = 'preflight', gateway, alertServer, browserSocket, fault = '', observedCommit, browser;
const sha = b => createHash('sha256').update(b).digest('hex');
async function until(check, label, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (await check()) return; await new Promise(r => setTimeout(r, 50)); }
  throw Error(label);
}
function launch(file, args, env = process.env) {
  const c = spawn(file, args, { cwd: root, env, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
  children.add(c); c.stdin.on('error', () => {}); c.stdout.resume(); c.stderr.resume();
  c.on('error', () => {}); c.on('exit', () => children.delete(c)); return c;
}
function database(sql, hold = false) {
  const c = spawn(psql, ['-X', '-w', '-qAt', '-v', 'ON_ERROR_STOP=1', '-v','VERBOSITY=sqlstate', '-d', connection], { cwd: root, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
  children.add(c); let out = '', readyResolve;
  const ready = new Promise(r => { readyResolve = r; });
  c.stdout.on('data', b => { out += b; if (out.includes('HTTP_LOCK_READY')) readyResolve(); });
  c.stderr.on('data',b=>{const code=/ERROR:\s+([A-Z0-9]{5})/.exec(b.toString());if(code)lastSqlState=code[1];}); c.stdin.on('error', () => {});
  const done = new Promise((yes, no) => {
    c.on('error', () => { readyResolve(); no(Error('SQL transport unavailable')); });
    c.on('close', code => { readyResolve(); children.delete(c); if (code) no(Error('Guarded SQL failed')); else yes(out.trim()); });
  });
  void done.catch(() => {});
  c.stdin.write(`${guard}\n${sql}\n`); if (!hold) c.stdin.end();
  return { c, ready, done };
}
async function sql(text) { return database(text).done; }
async function freePort() {
  const s = netServer(); await new Promise(r => s.listen(0, '127.0.0.1', r));
  const p = s.address().port; await new Promise(r => s.close(r)); return p;
}
const reset = `UPDATE private.walkin_ingress_state SET last_second=0,day_number=0,day_attempts=0;
UPDATE private.walkin_ingress_seconds SET second_number=0,attempts=0;
UPDATE private.walkin_ingress_buckets SET updated_at='epoch',tokens=3,lookup_tokens=2;
UPDATE private.walkin_ingress_leases SET ticket=NULL,expires_at=NULL,digest=NULL,action=NULL,method=NULL,fingerprint=NULL;`;
const capability = () => randomBytes(32).toString('base64url');
const digest = cap => '\\x' + sha(Buffer.concat([Buffer.from('gymforce:walkin-recovery:v1\0'), Buffer.from(cap, 'base64url')]));
const count = async () => Number(await sql('SELECT count(*) FROM private.walkin_creation_operations'));
function pass(id, detail) {
  const status=[13,14].includes(id)?'PARTIAL':'PASS';
  results.push({ id,status,scopedCheck:'PASS',detail });
  console.log(`PASS persisted HTTP check ${id} (scenario acceptance ${status}): ${detail}`);
}
try {
  if (!/^[a-f0-9]{32}$/.test(runId ?? '') || !connection || !psql || !directory || !process.argv.includes('--compatibility-fixture')) throw Error('Runner required');
  if (Object.keys(process.env).some(n => /^PG/i.test(n))) throw Error('Inherited PG settings');
  if ((await realpath(directory)).toLowerCase() !== resolve(run, 'data').toLowerCase()) throw Error('Directory mismatch');
  execFileSync('git', ['check-ignore', '--', `.cache/security-test-${runId}/data`], { cwd: root, stdio: 'ignore' });
  const match = /^host=127\.0\.0\.1 port=(\d+) dbname=gymforce_batch1_synthetic user=gf_provider_admin passfile='([^'\\]+)' require_auth=scram-sha-256 connect_timeout=5$/.exec(connection);
  if (!match || match[2].toLowerCase() !== resolve(run, 'pgpass.conf').replaceAll('\\', '/').toLowerCase()) throw Error('Connection allowlist');
  guard = `SET statement_timeout='20s'; SET lock_timeout='2s'; DO $g$ BEGIN
 IF current_database()<>'gymforce_batch1_synthetic' OR session_user<>'gf_provider_admin' OR current_user<>'gf_provider_admin'
 OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet OR inet_server_port()<>${Number(match[1])}
 OR current_setting('gymforce.synthetic_run_id',true) IS DISTINCT FROM '${runId}'
 OR lower(replace(current_setting('data_directory'),chr(92),'/'))<>lower(${quote(resolve(run, 'data').replaceAll('\\', '/'))})
 OR current_setting('server_version_num')<>'170012' THEN RAISE EXCEPTION 'HTTP synthetic guard refused'; END IF; END $g$;`;
  assert.equal(await sql('SELECT 1'), '1'); targetValidated=true;
  executedSourceHash=sha(await readFile(import.meta.filename));
  qualifiedSources={};
  for(const file of ['scripts/recovery/qualify-http-faults.mjs','scripts/recovery/durable-ingress-ops.mjs','scripts/recovery/ingress-monitor.mjs','scripts/recovery/serve-local-edge.ts'])qualifiedSources[file]=sha(await readFile(resolve(root,file)));
  const pgBin = dirname(psql), postgrest = resolve(root, '.cache/tools/postgrest-v16.6-win-x64/payload/postgrest.exe');
  assert.equal(sha(await readFile(postgrest)), 'd5ed992d11573fcd3154e2f6114dec65fe436cfcd9623d8b4e23364788aac43b');
  assert.deepEqual((await readdir(dirname(postgrest))).sort(),['postgrest.exe'],'Unexpected application DLL search contents');
  const dependencyHashes={
    'libpq.dll':'d87674d536cb8fcc4897f8d6a1c8445675e33447ca0e6ebac210559029f19d04',
    'libintl-9.dll':'87fbcee976b4b051e0f3f11a6a2fd5613b42ddb2b97716d069942828f2840d13',
    'libiconv-2.dll':'6fce90bc8ea4b730e897e8d5bcd4cbb1e83a7f5083e1d2f82acde8c49b1ea41f',
    'libssl-3-x64.dll':'45a45bc89cd4c6621f84da60356c64a69140bf61b027cc9858c36ea37d7f74c1',
    'libcrypto-3-x64.dll':'8efe1edb434ea9f44f1fbb9be38374857e33666d4aab058a6413e6db566f1baf',
  };
  for(const [name,hash] of Object.entries(dependencyHashes)){
    assert.equal(sha(await readFile(resolve(pgBin,name))),hash,'PG17 qualified library drift');
    let systemOverride=false;try{await access(resolve(process.env.SystemRoot,'System32',name));systemOverride=true;}catch{/* expected absent */}
    assert.equal(systemOverride,false,'Unreviewed DLL search precedence');
  }
  const childPath = `${pgBin};${process.env.PATH}`;
  assert.match(execFileSync(postgrest, ['--version'], { env: { ...process.env, PATH: childPath }, windowsHide: true, timeout:15000 }).toString(), /PostgREST 16\.6/);
  const deno = resolve(process.env.LOCALAPPDATA, 'Microsoft/WinGet/Packages/DenoLand.Deno_Microsoft.Winget.Source_8wekyb3d8bbwe/deno.exe');
  assert.match(execFileSync(deno, ['--version'], { windowsHide: true, timeout:15000 }).toString(), /deno 2\.9\./);
  assert.match(process.version, /^v24\./);
  const restPort = await freePort(), edgePort = await freePort(), edgePort2=await freePort(), poolPort=await freePort(), vitePort = await freePort(), frontPort = await freePort();
  const origin = `http://127.0.0.1:${frontPort}`, rest = `http://127.0.0.1:${restPort}`, edge = `http://127.0.0.1:${edgePort}`;
  const signing = randomBytes(48).toString('base64url'), password = randomBytes(32).toString('hex');
  const jwt = (role,lifetime=1800) => {
    const head = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const body = Buffer.from(JSON.stringify({ role, exp: Math.floor(Date.now()/1000)+lifetime })).toString('base64url');
    return `${head}.${body}.${createHmac('sha256', signing).update(`${head}.${body}`).digest('base64url')}`;
  };
  const service = jwt('service_role'), anon = jwt('anon');
  stage = 'transport-role';
  await sql(`DO $probe$ BEGIN
   BEGIN
    CREATE ROLE gf_http_refusal_probe NOLOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
    EXECUTE 'GRANT gf_http_missing_role TO gf_http_refusal_probe';
    RAISE EXCEPTION 'Expected transport grant refusal';
   EXCEPTION WHEN undefined_object THEN NULL; END;
   IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='gf_http_refusal_probe') THEN RAISE EXCEPTION 'Transport grant rollback leaked role'; END IF;
   END $probe$;`);
  console.log('PASS HTTP authority fault: refused grant rolls back temporary role without residual membership.');
  await sql(`BEGIN; CREATE ROLE gf_http_transport LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE PASSWORD ${quote(password)};
GRANT service_role,anon TO gf_http_transport WITH INHERIT FALSE, SET TRUE; COMMIT;`);
  transportCreated=true;
  // Test-only invoker probe: no data access and the same outer 1s SQL timer.
  await sql(`CREATE FUNCTION api.gf_http_pool_hold() RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$ BEGIN
   IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS DISTINCT FROM '${runId}' THEN RAISE EXCEPTION 'Synthetic pool guard'; END IF;
   PERFORM pg_catalog.pg_sleep(2); END $f$;
   REVOKE ALL ON FUNCTION api.gf_http_pool_hold() FROM PUBLIC,anon,authenticated;
   GRANT EXECUTE ON FUNCTION api.gf_http_pool_hold() TO service_role;`);
  const dburi = `postgresql://gf_http_transport:${password}@127.0.0.1:${match[1]}/gymforce_batch1_synthetic?options=${encodeURIComponent('-c statement_timeout=1000 -c lock_timeout=100')}`;
  await writeFile(config, `db-uri = "${dburi}"\ndb-schemas = "api"\ndb-anon-role = "anon"\njwt-secret = "${signing}"\nserver-host = "127.0.0.1"\nserver-port = ${restPort}\ndb-pool = 2\ndb-pool-acquisition-timeout = 1\ndb-tx-end = "commit"\nlog-level = "crit"\n`);
  launch(postgrest, [config], { ...process.env, PATH: childPath });
  const rpc = async (name, args = {}, token = service) => {
    const response = await fetch(`${rest}/rpc/${name}`, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'Content-Profile': 'api' }, body: JSON.stringify(args), signal: AbortSignal.timeout(7000) });
    let data; try { data = await response.json(); } catch { data = null; }
    lastRpc={name,status:response.status,code:typeof data?.code==='string'&&/^[A-Z0-9]+$/.test(data.code)?data.code:null};
    return { status: response.status, data, error: !response.ok };
  };
  stage = 'postgrest-start';
  await until(async () => { try { return (await rpc('public_walkin_observe', { p_kind: 'unavailable' })).status === 204; } catch { return false; } }, 'PostgREST readiness');
  await resetState();
  let edgeToggle=0;
  gateway = createServer(async (req, res) => {
    try {
      const route = req.url ?? '/', isEdge = route.startsWith('/functions/v1/public-walkin-recovery');
      const destination = route.startsWith('/rest/v1/') ? rest + route.slice('/rest/v1'.length) : isEdge ? `http://127.0.0.1:${edgeToggle++%2?edgePort2:edgePort}/` : `http://127.0.0.1:${vitePort}${route}`;
      const requestFault = isEdge ? fault : '';
      if (isEdge) fault = '';
      if (requestFault === 'drop-before') { req.resume(); res.destroy(); return; }
      const chunks = []; for await (const chunk of req) chunks.push(chunk);
      const headers = { ...req.headers }; delete headers.host; delete headers.connection; delete headers['content-length']; delete headers['accept-encoding'];
      const upstream = await fetch(destination, { method: req.method, headers, ...(req.method === 'GET' || req.method === 'HEAD' ? {} : { body: Buffer.concat(chunks) }) });
      const body = Buffer.from(await upstream.arrayBuffer());
      if (requestFault === 'drop-after') { observedCommit = JSON.parse(body.toString()); res.destroy(); return; }
      res.statusCode = upstream.status; upstream.headers.forEach((v, k) => { if (!['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(k)) res.setHeader(k, v); });
      res.end(body);
    } catch { if (!res.headersSent) res.statusCode = 503; res.end(); }
  });
  gateway.on('connection', socket => { sockets.add(socket); socket.on('close', () => sockets.delete(socket)); });
  await new Promise(r => gateway.listen(frontPort, '127.0.0.1', r));
  for(const port of [edgePort,edgePort2]) {
  launch(deno, ['run', '--cached-only', '--node-modules-dir=manual', '--allow-read=supabase/functions,node_modules', `--allow-net=127.0.0.1:${frontPort},127.0.0.1:${port}`, '--allow-env=GYMFORCE_TEST_RUN_ID,GYMFORCE_HTTP_PORT,APP_ORIGIN,SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,PUBLIC_WALKIN_ENABLED,WALKIN_REQUEST_LIMIT_PER_MINUTE', 'scripts/recovery/serve-local-edge.ts'], {
    ...process.env, GYMFORCE_HTTP_PORT: String(port), APP_ORIGIN: origin, SUPABASE_URL: origin, SUPABASE_SERVICE_ROLE_KEY: service, PUBLIC_WALKIN_ENABLED: 'true', WALKIN_REQUEST_LIMIT_PER_MINUTE: '10',
  });
  stage = 'edge-start';
  await until(async () => { try { return (await fetch(`http://127.0.0.1:${port}`, { method: 'OPTIONS', headers: { Origin: origin } })).status === 204; } catch { return false; } }, 'Independent Deno readiness');
  }
  const call = async (cap, action = 'create', method = 'cash') => {
    const response = await fetch(`${origin}/functions/v1/public-walkin-recovery`, { method: 'POST', headers: { Origin: origin, 'Content-Type': 'application/json' }, body: JSON.stringify({ action, capability: cap, ...(action === 'create' ? { paymentMethod: method } : {}) }), signal: AbortSignal.timeout(12000) });
    return { status: response.status, data: await response.json() };
  };
  async function resetState() { await sql(reset); }
  // Isolate the existing mutable rate-event fixture; no financial/audit rows removed.
  await sql('DELETE FROM private.walkin_request_rate_events');
  stage = 'first-replay-conflict';
  const cap = capability(), before = await count(), created = await call(cap);
  assert.equal(created.status, 201); assert.equal(await count(), before+1); pass(1, 'actual Edge/PostgREST commit creates one binding');
  assert.equal((await call(cap)).status, 200); assert.equal(await count(), before+1); pass(2, 'identical HTTP replay retains one binding');
  assert.equal((await call(cap, 'create', 'gcash')).status, 409); assert.equal(await count(), before+1); pass(3, 'conflict preserves original binding');
  await resetState(); const concurrent = capability(), old = await count();
  const simultaneous = await Promise.all([call(concurrent), call(concurrent)]);
  assert.deepEqual(simultaneous.map(r => r.status).sort(), [200, 201]); assert.equal(await count(), old+1); pass(4, 'concurrent actual HTTP creates once');
  stage = 'network-faults'; await resetState(); const pre = capability(), preCount = await count(); fault = 'drop-before';
  await assert.rejects(call(pre)); assert.equal(await count(), preCount); assert.equal((await call(pre, 'lookup')).status, 404); pass(7, 'real proxy connection loss before dispatch persists no binding');
  const post = capability(), postCount=await count(); fault = 'drop-after'; await assert.rejects(call(post));
  assert.ok(observedCommit.request.id);assert.equal(await count(),postCount+1);
  await sql("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename='gf_http_transport' AND state='idle'");
  // A severed pooled connection may correctly reject its next use. Qualify
  // reconnect with bounded health probes, never by automatically retrying create.
  await until(async()=>(await Promise.all([rpc('public_walkin_observe',{p_kind:'timeout'}),rpc('public_walkin_observe',{p_kind:'timeout'})])).every(r=>r.status===204),'Post-commit pool reconnect');
  const recovered = await call(post, 'lookup');
  assert.equal(recovered.status, 200); assert.equal(recovered.data.request.id, observedCommit.request.id); assert.equal(await count(),postCount+1); pass(8, 'real committed response dropped, idle DB connection terminated; same capability recovers original binding');
  stage = 'rollback'; await resetState(); const rollback = capability();
  await sql('UPDATE private.walkin_ingress_capacity SET bindings=0');
  const requests = Number(await sql('SELECT count(*) FROM private.walkin_requests'));
  assert.equal((await call(rollback)).status, 503);
  assert.equal(Number(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds')), 1);
  assert.equal(Number(await sql('SELECT count(*) FROM private.walkin_requests')), requests);
  await sql('UPDATE private.walkin_ingress_capacity SET bindings=(SELECT count(*) FROM private.walkin_creation_operations)'); pass(10, 'business refusal rolls back orphan request while separate admission charge commits');
  stage = 'timeout'; await resetState();
  const held = database('BEGIN; SELECT id FROM private.walkin_ingress_capacity FOR UPDATE;\n\\echo HTTP_LOCK_READY', true); await held.ready;
  try { assert.equal((await call(capability())).status, 503); } finally { held.c.stdin.end('ROLLBACK;\n'); await held.done; }
  assert.equal((await call(cap, 'lookup')).status, 200); pass(9, 'real lock timeout refuses business and pooled transport subsequently recovers');
  stage='commit-barriers';
  await qualifyCommitFaults({sql,database,rpc,call,reset:resetState,capability,count,runId});
  assert.equal((await rpc('public_walkin_admit',{},jwt('service_role',-60))).status,401);
  console.log('PASS real PostgREST invalid/expired JWT rejection; no GoTrue authentication claim.');
  await resetState();await sql('DELETE FROM private.walkin_request_rate_events');
  stage='pool-pressure';
  const sleepers=[rpc('gf_http_pool_hold'),rpc('gf_http_pool_hold')];
  await until(async()=>await sql("SELECT count(*) FROM pg_stat_activity WHERE usename='gf_http_transport' AND wait_event='PgSleep'")==='2','Two actual pooled SQL requests',1000);
  const queued=await rpc('public_walkin_observe',{p_kind:'timeout'});
  const cancelled=await Promise.all(sleepers);
  assert.ok(cancelled.every(r=>r.error&&r.data?.code==='57014'));
  assert.ok(queued.status===204||(queued.error&&queued.data?.code==='PGRST003'));
  assert.equal((await rpc('public_walkin_observe',{p_kind:'timeout'})).status,204);
  console.log('PASS persisted pool pressure: two real pooled SQL calls cancelled by 1s timer; queued request classified and pool recovered. Acquisition-timeout refusal depends on timer ordering.');
  stage='deterministic-pool-exhaustion';
  // Separate probe only: unchanged business guards refuse its 6s timer.
  await sql(`CREATE FUNCTION api.gf_http_pool_long_hold() RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$ BEGIN
    IF current_database()<>'gymforce_batch1_synthetic' OR current_setting('gymforce.synthetic_run_id',true) IS DISTINCT FROM '${runId}' THEN RAISE EXCEPTION 'Synthetic pool guard'; END IF;
    PERFORM pg_catalog.pg_sleep(4); END $f$;
    REVOKE ALL ON FUNCTION api.gf_http_pool_long_hold() FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION api.gf_http_pool_long_hold() TO service_role;`);
  await writeFile(poolConfig,(await readFile(config,'utf8')).replace('statement_timeout%3D1000','statement_timeout%3D6000').replace(`server-port = ${restPort}`,`server-port = ${poolPort}`).replace('db-pool = 2','db-pool = 1'));
  launch(postgrest,[poolConfig],{...process.env,PATH:childPath});
  const poolRpc=async(name)=>{const r=await fetch(`http://127.0.0.1:${poolPort}/rpc/${name}`,{method:'POST',headers:{Authorization:`Bearer ${service}`,'Content-Type':'application/json','Content-Profile':'api'},body:'{}',signal:AbortSignal.timeout(7000)});return {status:r.status,text:await r.text()};};
  await until(async()=>{try{return JSON.parse((await poolRpc('public_walkin_admit')).text).code==='55000';}catch{return false;}},'Probe pool readiness');
  const busy=poolRpc('gf_http_pool_long_hold');
  await until(async()=>await sql("SELECT count(*) FROM pg_stat_activity WHERE usename='gf_http_transport' AND wait_event='PgSleep'")==='1','Probe pool occupied');
  const exhausted=await poolRpc('gf_http_pool_long_hold');assert.equal(JSON.parse(exhausted.text).code,'PGRST003');
  assert.equal((await busy).status,204);
  assert.equal(JSON.parse((await poolRpc('public_walkin_admit')).text).code,'55000','Business refuses unqualified probe timer');
  console.log('PASS deterministic pool acquisition timeout PGRST003 and recovery: separate one-slot probe, protected business timer refusal preserved.');
  stage='interrupted-body';await resetState();const beforeInterrupted=await count();
  const interrupted=httpRequest(edge,{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'}});
  interrupted.on('error',()=>{});interrupted.write('{');
  try{await until(async()=>Number(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds'))===1,'Admission before incomplete body');}
  finally{interrupted.destroy();}
  assert.equal(await count(),beforeInterrupted);
  assert.equal(Number(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds')),1);
  console.log('PASS persisted interrupted HTTP body: committed admission survives client disconnect; no business binding created.');
  stage = 'expiry-denial';
  assert.ok([401,403].includes((await rpc('public_walkin_admit', {}, anon)).status));
  assert.ok((await rpc('public_create_walkin_request_v2', { p_capability_digest: digest(cap), p_payment_method: 'cash', p_request_limit: 10 })).status >= 400);
  assert.equal((await call(capability(), 'lookup')).status, 404); pass(12, 'anonymous and ungated RPC denial; unknown lookup reveals no outcome');
  await resetState();
  const lease = (await rpc('public_walkin_admit')).data.ticket;
  await sql(`UPDATE private.walkin_ingress_leases SET expires_at=clock_timestamp()-interval '1 second' WHERE ticket=${quote(lease)}::uuid`);
  assert.equal((await rpc('public_walkin_execute', { p_ticket: lease, p_digest: digest(cap), p_action: 'lookup', p_method: null })).status, 403);
  assert.equal((await call(cap, 'lookup')).status, 200);
  const expiredCapability=capability(), expiryBefore=await count();
  // Valid historical synthetic snapshot, not an update/revival or a backdated
  // attendance/payment. The unchanged trigger enforces exactly fifteen minutes.
  await sql(`DO $expired$ DECLARE f uuid:=gen_random_uuid();r uuid:=gen_random_uuid();created timestamptz:=clock_timestamp()-interval '16 minutes';BEGIN
   INSERT INTO private.walkin_fee_versions(id,fee_php,currency,effective_from,created_by,created_at) VALUES(f,125,'PHP',created-interval '1 minute','${owner}',created-interval '1 minute');
   INSERT INTO private.walkin_requests(id,fee_version_id,fee_php,currency,created_at,expires_at,requested_payment_method) VALUES(r,f,125,'PHP',created,created+interval '15 minutes','cash');
   INSERT INTO private.walkin_creation_operations VALUES(1,${quote(digest(expiredCapability))}::bytea,'cash',sha256(convert_to('gymforce:walkin-create:v1'||chr(10)||'paymentMethod=cash'||chr(10),'UTF8')),r,created);
   END $expired$;`);
  assert.equal((await call(expiredCapability,'lookup')).status,410);
  assert.equal((await call(expiredCapability)).status,410);
  assert.equal(await count(),expiryBefore+1);
  pass(11, 'expired lease denied and reclaimed; valid expired synthetic request returns HTTP 410 for lookup/replay without replacement');
  stage = 'owner-reconciliation'; await resetState();
  const op = randomUUID(), confirmation = { p_actor_user_id: owner, p_request_id: created.data.request.id, p_operation_id: op, p_amount_php: 125, p_payment_method: 'cash', p_evidence_reviewed: true };
  assert.equal((await rpc('owner_confirm_walkin',{...confirmation,p_actor_user_id:randomUUID()})).status,403);
  const confirmed = await rpc('owner_confirm_walkin', confirmation); assert.equal(confirmed.status, 200);
  const duplicate = await rpc('owner_confirm_walkin', confirmation); assert.equal(duplicate.status, 200);
  assert.equal(await sql(`SELECT count(*) FROM private.payment_records WHERE operation_id=${quote(op)}::uuid`), '1');
  assert.equal(await sql(`SELECT count(*) FROM private.attendance_checkins WHERE walkin_request_id=${quote(created.data.request.id)}::uuid`), '1');
  pass(13, 'actual service-only Owner SQL RPC reconciliation; Owner Auth Edge chain not included'); pass(15, 'same confirmation operation leaves one payment and attendance');
  stage='financial-barriers';
  await qualifyFinancialFaults({sql,database,rpc,call,reset:resetState,capability,runId,owner,randomUUID});
  stage='http-clock';await qualifyHttpClock({sql,rpc,reset:resetState,digest,capability});
  stage='two-process-load';loadEvidence=await qualifyIndependentLoad({sql,call,reset:resetState,capability,count});
  stage='attempt-matrix';await qualifyAttemptMatrix({origin,sql,reset:resetState,capability,count});
  stage = 'limits'; await resetState();
  const tickets = []; for (let i=0;i<8;i++) { const a = await rpc('public_walkin_admit'); assert.equal(a.data.status, 'allowed'); tickets.push(a.data.ticket); }
  assert.equal((await rpc('public_walkin_admit')).data.status, 'denied');
  await resetState(); await sql("UPDATE private.walkin_ingress_state SET day_number=floor(extract(epoch FROM clock_timestamp()))::bigint/86400,day_attempts=2000");
  assert.equal((await call(capability())).status, 429);
  await resetState(); for(let i=0;i<21;i++) { const a = await rpc('public_walkin_admit'); assert.equal(a.data.status, i<20?'allowed':'denied'); if(i<20)await rpc('public_walkin_finish',{p_ticket:a.data.ticket,p_kind:'denied'}); }
  await resetState();
  await sql("UPDATE private.walkin_ingress_seconds SET second_number=floor(extract(epoch FROM clock_timestamp()))::bigint-20,attempts=120 WHERE slot=mod(floor(extract(epoch FROM clock_timestamp()))::bigint-20,61)");
  assert.equal((await call(capability())).status,429);
  await resetState();const lookupLimited=capability();
  assert.equal((await call(lookupLimited,'lookup')).status,404);
  assert.equal((await call(lookupLimited,'lookup')).status,404);
  assert.equal((await call(lookupLimited,'lookup')).status,429);
  await resetState(); const keyed=capability();
  assert.equal((await call(keyed)).status,201);
  assert.equal((await call(keyed)).status,200);
  assert.equal((await call(keyed)).status,200);
  assert.equal((await call(keyed)).status,429);
  pass(14, 'real HTTP daily/burst/keyed/eight-lease limits; native tests cover refill/final-token/clock boundaries');
  stage = 'maintenance'; await resetState();
  await sql('UPDATE private.walkin_ingress_minutes SET minute_number=0,attempts=0,denied=0,unavailable=0,timeouts=0');
  await sql("UPDATE private.walkin_ingress_minutes SET minute_number=floor(extract(epoch FROM clock_timestamp())/60)::bigint-2881,denied=99 WHERE slot=0");
  const delivered = [], monitor = new IngressMonitor(a => delivered.push(a));
  const tick = () => localMaintenanceTick(() => rpc('public_walkin_maintenance'), monitor, Math.floor(Date.now()/60000));
  await tick(); assert.equal(await sql('SELECT count(*) FROM private.walkin_ingress_minutes WHERE denied=99'), '0');
  const maintenanceLease=(await rpc('public_walkin_admit')).data.ticket;
  await sql(`UPDATE private.walkin_ingress_leases SET expires_at=clock_timestamp()-interval '1 second' WHERE ticket=${quote(maintenanceLease)}::uuid`);
  const leaseLock=database(`BEGIN; SELECT slot FROM private.walkin_ingress_leases WHERE ticket=${quote(maintenanceLease)}::uuid FOR UPDATE;\n\\echo HTTP_LOCK_READY`,true); await leaseLock.ready;
  try{await tick();assert.equal(await sql(`SELECT count(*) FROM private.walkin_ingress_leases WHERE ticket=${quote(maintenanceLease)}::uuid`),'1');}
  finally{leaseLock.c.stdin.end('ROLLBACK;\n');await leaseLock.done;}
  await tick();assert.equal(await sql(`SELECT count(*) FROM private.walkin_ingress_leases WHERE ticket=${quote(maintenanceLease)}::uuid`),'0');
  console.log('PASS operational lease cleanup: locked expired lease skipped; unlocked expired generation reclaimed via actual maintenance RPC.');
  await sql("UPDATE private.walkin_ingress_minutes SET minute_number=floor(extract(epoch FROM clock_timestamp())/60)::bigint,denied=20,timeouts=5,unavailable=1 WHERE slot=mod(floor(extract(epoch FROM clock_timestamp())/60)::bigint,2880)");
  await tick(); await tick(); assert.equal(delivered.length, 3);
  assert.ok([401,403].includes((await rpc('public_walkin_maintenance', {}, anon)).status));
  // Timeout must roll back the cleanup, surface health failure, then recover.
  await sql("UPDATE private.walkin_ingress_minutes SET minute_number=floor(extract(epoch FROM clock_timestamp())/60)::bigint-2881,denied=98 WHERE slot=0");
  const cleanupLock=database('BEGIN; SELECT slot FROM private.walkin_ingress_minutes WHERE slot=0 FOR UPDATE;\n\\echo HTTP_LOCK_READY',true); await cleanupLock.ready;
  try { await assert.rejects(tick(),/MAINTENANCE/); assert.equal(await sql('SELECT count(*) FROM private.walkin_ingress_minutes WHERE denied=98'),'1'); }
  finally {cleanupLock.c.stdin.end('ROLLBACK;\n');await cleanupLock.done;}
  await tick(); assert.equal(await sql('SELECT count(*) FROM private.walkin_ingress_minutes WHERE denied=98'),'0');
  assert.equal(delivered.filter(a=>a.kind==='maintenance_unavailable').length,1);
  console.log('PASS operational HTTP: explicit idle tick clears old aggregate bins, real RPC counters trigger three deduplicated local alerts; anonymous maintenance denied. No production scheduler/destination.');
  stage='durable-idle-operations';
  const opsDir=resolve(run,'aggregate-ops');await mkdir(opsDir);
  const durable=new DurableIngressQueue(opsDir);
  const durableMonitor=new IngressMonitor(a=>durable.enqueue(a,Math.floor(Date.now()/60000)));
  let scheduled=0;
  stopScheduler=scheduleLocalCleanup(async()=>{
    await localMaintenanceTick(()=>rpc('public_walkin_maintenance'),durableMonitor,Math.floor(Date.now()/60000));
    await durable.heartbeat(Math.floor(Date.now()/60000));scheduled++;
  },{intervalMs:100,onFailure:()=>{}});
  await until(()=>scheduled>=2,'Actual scheduled maintenance ticks');await stopScheduler();stopScheduler=null;
  assert.ok((await durable.inspect(Math.floor(Date.now()/60000))).heartbeat!==null);
  const sink=new DurableIngressQueue(opsDir,'sink');
  alertServer=createServer(async(req,res)=>{
    try {
      if(req.method!=='POST'||req.url!=='/synthetic-alert')throw Error('Local sink route');
      let body='';for await(const chunk of req){body+=chunk;if(body.length>1024)throw Error('Local sink bound');}
      const alert=JSON.parse(body);await sink.enqueue(alert,Math.floor(Date.now()/60000));res.end(alert.key);
    }catch{res.writeHead(503).end();}
  });
  alertServer.on('connection',socket=>{sockets.add(socket);socket.on('close',()=>sockets.delete(socket));});
  await new Promise(r=>alertServer.listen(0,'127.0.0.1',r));
  const deliver=localDestination(`http://127.0.0.1:${alertServer.address().port}/synthetic-alert`);
  await durable.flush(Math.floor(Date.now()/60000),deliver);
  const deliveredCount=(await sink.inspect(Math.floor(Date.now()/60000))).retained;assert.ok(deliveredCount>=3);
  await new DurableIngressQueue(opsDir).flush(Math.floor(Date.now()/60000),deliver);
  assert.equal((await sink.inspect(Math.floor(Date.now()/60000))).retained,deliveredCount);
  console.log('PASS scheduled idle maintenance: actual RPCs, serialized ticks, durable aggregate queue/heartbeat, real loopback durable sink and restart deduplication.');
  stage = 'browser'; await resetState();
  launch(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', String(vitePort), '--strictPort'], { ...process.env, VITE_SUPABASE_URL: origin, VITE_SUPABASE_PUBLISHABLE_KEY: anon });
  await until(async () => { try { return (await fetch(`http://127.0.0.1:${vitePort}`)).ok; } catch { return false; } }, 'Vite');
  browser = launch('C:/Program Files/Google/Chrome/Application/chrome.exe', ['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--disable-sync','--disable-extensions','--disable-component-update','--remote-debugging-port=0','--remote-debugging-address=127.0.0.1',`--user-data-dir=${profile}`,'about:blank']);
  let debugPort; await until(async () => { try { debugPort = Number((await readFile(resolve(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]); return debugPort>0; } catch { return false; } }, 'Chrome');
  const pages = await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();
  const debuggerUrl=pages.find(p => p.type==='page').webSocketDebuggerUrl;
  assert.ok(debuggerUrl.startsWith(`ws://127.0.0.1:${debugPort}/`));
  browserSocket = new WebSocket(debuggerUrl);
  await new Promise(r => browserSocket.addEventListener('open', r, { once: true }));
  let seq=0;const pending=new Map();
  browserSocket.addEventListener('message', e => { const m=JSON.parse(e.data);if(m.id&&pending.has(m.id)){pending.get(m.id)(m);pending.delete(m.id);} });
  const cdp=(method,params={},sessionId)=>new Promise((yes,no)=>{const id=++seq,timer=setTimeout(()=>{pending.delete(id);no(Error('CDP timeout'));},15000);pending.set(id,m=>{clearTimeout(timer);m.error?no(Error('CDP failed')):yes(m.result);});browserSocket.send(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})}));});
  const first=await cdp('Target.attachToTarget',{targetId:pages.find(p=>p.type==='page').id,flatten:true});
  const evaluate=async(expression,sessionId=first.sessionId)=>{const r=await cdp('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true},sessionId);if(r.exceptionDetails)throw Error('Browser evaluation');return r.result.value;};
  await cdp('Page.navigate',{url:origin+'/entrance'},first.sessionId);
  await until(()=>evaluate("!!document.querySelector('#entrance-walkin-tab')"),'Entrance');
  await evaluate("document.querySelector('#entrance-walkin-tab').click()");
  await until(()=>evaluate("!!document.querySelector('button[type=submit]:not(:disabled)')"),'Storage readiness');
  const browserBefore=await count();await evaluate("document.querySelector('button[type=submit]').click()");
  await until(()=>evaluate("document.body.innerText.includes('Request reference')"),'Committed browser request');
  assert.equal(await count(),browserBefore+1);
  const tab=await cdp('Target.createTarget',{url:origin+'/entrance'}), second=await cdp('Target.attachToTarget',{targetId:tab.targetId,flatten:true});
  await until(()=>evaluate("!!document.querySelector('#entrance-walkin-tab')",second.sessionId),'Second tab');
  await evaluate("document.querySelector('#entrance-walkin-tab').click()",second.sessionId);
  await until(()=>evaluate("[...document.querySelectorAll('button')].some(b=>b.textContent==='Recover existing request')",second.sessionId),'Durable recovery');
  await evaluate("[...document.querySelectorAll('button')].find(b=>b.textContent==='Recover existing request').click()",second.sessionId);
  await until(()=>evaluate("document.body.innerText.includes('Request reference')",second.sessionId),'Second tab recovery');
  assert.equal(await count(),browserBefore+1);pass(5,'two real browser tabs recover one persisted binding through actual HTTP');
  await cdp('Page.reload',{},first.sessionId);await until(()=>evaluate("!!document.querySelector('#entrance-walkin-tab')"),'Reload');
  await evaluate("document.querySelector('#entrance-walkin-tab').click()");
  await until(()=>evaluate("[...document.querySelectorAll('button')].some(b=>b.textContent==='Recover existing request')"),'Reload recovery');
  await evaluate("[...document.querySelectorAll('button')].find(b=>b.textContent==='Recover existing request').click()");
  await until(()=>evaluate("document.body.innerText.includes('Request reference')"),'Reload persisted outcome');
  assert.equal(await count(),browserBefore+1);pass(6,'browser reload retains capability and recovers same committed request');
  assert.equal(sha(await readFile(import.meta.filename)),executedSourceHash,'Harness source changed during execution');
  for(const [file,hash] of Object.entries(qualifiedSources))assert.equal(sha(await readFile(resolve(root,file))),hash,'Qualification source changed during execution');
  await writeFile(resolve(run,'persisted-http-results.json'),JSON.stringify({harnessSha256:executedSourceHash,qualifiedSources,loadEvidence,transport:'Chrome -> actual Deno module -> PostgREST 16.6 -> PG17.12',results,limitations:['Owner Auth Edge not included','Deno is not Supabase isolate equivalence','Two independent Deno processes, not hosted isolates','Native tests supplement HTTP limits/clock','No external alert delivery or production scheduler']},null,2));
} catch(error) {
  if(error?.code==='ERR_ASSERTION') console.error(`ASSERTION category ${typeof error.actual==='number'?error.actual:'non-numeric'} expected ${typeof error.expected==='number'?error.expected:'non-numeric'}`);
  console.error(`FAIL persisted HTTP at ${stage}; last RPC category ${JSON.stringify(lastRpc)}, last SQLSTATE ${lastSqlState??'none'}; private SQL/config/response details suppressed.`);process.exitCode=1;
} finally {
  await stopScheduler?.();
  browserSocket?.close();for(const socket of sockets)socket.destroy();gateway?.close();alertServer?.close();
  for(const child of [...children]) { try { execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore',windowsHide:true}); } catch { child.kill(); } }
  await Promise.all([...children].map(c=>new Promise(r=>{if(c.exitCode!==null||c.signalCode!==null)r();else c.once('close',r);} )));
  if(transportCreated){
    try{
      await until(async()=>await sql("SELECT count(*) FROM pg_stat_activity WHERE usename='gf_http_transport'")==='0','Transport sessions closed');
      assert.equal(await sql("DROP FUNCTION IF EXISTS api.gf_http_pool_hold(),api.gf_http_pool_long_hold(); REVOKE service_role,anon FROM gf_http_transport; DROP ROLE gf_http_transport; SELECT count(*) FROM pg_roles WHERE rolname='gf_http_transport'"),'0');
    }catch{console.error('FAIL HTTP transport role/session cleanup; restricted synthetic cluster retained.');process.exitCode=1;}
  }
  if(targetValidated){
    await rm(config,{force:true});await rm(poolConfig,{force:true});
    if(profile.startsWith(run+'\\')||profile.startsWith(run+'/')) await rm(profile,{recursive:true,force:true,maxRetries:5,retryDelay:200});
  }
  console.log(targetValidated?'HTTP harness cleanup: owned processes stopped; credential config and browser capability profile removed.':'HTTP preflight refused before resource creation; no cleanup target touched.');
}
