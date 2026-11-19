import { spawn, execFileSync } from 'node:child_process';
import { realpath, stat } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Only the fresh synthetic-cluster runner supplies these values. Never accept
// a connection URL or a pre-existing/local/hosted application database.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const runId = process.env.GYMFORCE_TEST_RUN_ID;
const psql = process.env.GYMFORCE_TEST_PSQL;
const connection = process.env.GYMFORCE_TEST_CONNECTION;
const directory = process.env.GYMFORCE_TEST_DATA_DIRECTORY;
const database = 'gymforce_batch1_synthetic';
const administrativeUser = process.argv.includes('--compatibility-fixture') ? 'gf_provider_admin' : 'postgres';
const owner = '00000000-0000-4000-8000-000000000001';
const member = '10000000-0000-4000-8000-000000000011';
const plan = '10000000-0000-4000-8000-000000000012';
const purchase = '10000000-0000-4000-8000-000000000013';
const operation = '10000000-0000-4000-8000-000000000014';
const token = 'b'.repeat(64);
const phc = '$argon2id$v=19$m=65536,t=3,p=1$c3ludGhldGljLXNhbHQ$ZmFrZS12ZXJpZmllci1ub3QtYS1yZWFsLXBpbg';
const quote = (value) => "'" + value.replaceAll("'", "''") + "'";
let guard;
let stage = 'target-validation';
const children = new Set();

async function validateTarget() {
  if (!/^[a-f0-9]{32}$/.test(runId ?? '') || !connection || !psql || !directory) throw Error('target variables');
  if (Object.keys(process.env).some((name) => /^PG/i.test(name))) throw Error('inherited PostgreSQL configuration');
  const expected = resolve(root, '.cache', `security-test-${runId}`, 'data');
  if (resolve(directory).toLowerCase() !== expected.toLowerCase() ||
      (await realpath(expected)).toLowerCase() !== expected.toLowerCase()) throw Error('target directory');
  execFileSync('git', ['-C', root, 'check-ignore', '--', `.cache/security-test-${runId}/data`], { stdio: 'ignore' });
  const passfile = resolve(expected, '..', 'pgpass.conf').replaceAll('\\', '/');
  // Parse precisely the runner's limited libpq format; reject extra connection
  // parameters/options/service files and paths containing quote escapes.
  const match = /^host=127\.0\.0\.1 port=(\d+) dbname=gymforce_batch1_synthetic user=postgres passfile='([^'\\]+)' require_auth=scram-sha-256 connect_timeout=5$/.exec(connection.replace(`user=${administrativeUser} `, 'user=postgres '));
  if (!match || Number(match[1]) < 1024 || Number(match[1]) > 65535 || match[2].toLowerCase() !== passfile.toLowerCase()) throw Error('connection allowlist');
  if (!(await stat(psql)).isFile() || !(await stat(resolve(expected, '..', 'pgpass.conf'))).isFile()) throw Error('missing local runner files');
  guard = `SET statement_timeout='20s'; SET lock_timeout='15s';
DO $guard$ BEGIN
 IF current_database() <> '${database}' OR session_user <> '${administrativeUser}' OR current_user <> '${administrativeUser}'
 OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet OR inet_server_port() <> ${Number(match[1])}
 OR current_setting('gymforce.synthetic_run_id',true) IS DISTINCT FROM '${runId}'
 OR lower(replace(current_setting('data_directory'),chr(92),'/')) <> lower(${quote(expected.replaceAll('\\', '/'))})
 THEN RAISE EXCEPTION 'Synthetic target guard rejected'; END IF;
END $guard$;`;
}

function start(sql, { hold = false, application = '' } = {}) {
  const child = spawn(psql, ['-X', '-w', '-qAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose', '-d', connection], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
  children.add(child);
  let stdout = '', stderr = '';
  let readyResolve;
  const ready = new Promise((resolveReady) => { readyResolve = resolveReady; });
  child.stdout.on('data', (part) => {
    stdout += part.toString();
    if (stdout.includes('GYMFORCE_LOCK_READY')) readyResolve(true);
  });
  child.stderr.on('data', (part) => { stderr += part.toString(); });
  const done = new Promise((resolveDone) => {
    child.on('error', () => { readyResolve(false); resolveDone({ code: -1, stdout: '', stderr: '' }); });
    child.on('close', (code) => { children.delete(child); readyResolve(false); resolveDone({ code, stdout, stderr }); });
  });
  // Every subprocess receives the endpoint/marker/path guard in its own session.
  child.stdin.on('error', () => {});
  child.stdin.write(`${guard}\nSET application_name=${quote(application)};\n${sql}\n`);
  if (!hold) child.stdin.end();
  return { child, done, ready };
}

async function query(sql) {
  const result = await start(sql).done;
  if (result.code !== 0) throw Error('unexpected SQL failure');
  return result.stdout.trim();
}

async function race(label, lock, statements, expectedFailure) {
  const blocker = start(`BEGIN; ${lock};\n\\echo GYMFORCE_LOCK_READY`, { hold: true });
  const timeout = setTimeout(() => blocker.child.kill(), 15000);
  try {
    if (!await blocker.ready) throw Error('lock setup');
    const prefix = `gf-${runId}-${label}-`;
    const racers = statements.map((sql, index) => start(`BEGIN; SET LOCAL ROLE service_role; ${sql}; COMMIT;`, { application: prefix + index }));
    // Prove both clients reached a database lock before releasing the blocker;
    // timing alone is not evidence that concurrent calls overlapped.
    let waiting = false;
    for (let attempt = 0; attempt < 80; attempt++) {
      const count = await query(`SELECT count(*) FROM pg_stat_activity WHERE application_name IN (${quote(prefix + '0')},${quote(prefix + '1')}) AND wait_event_type='Lock';`);
      if (count === '2') { waiting = true; break; }
      await new Promise((resolveWait) => setTimeout(resolveWait, 50));
    }
    blocker.child.stdin.end('COMMIT;\n');
    if ((await blocker.done).code !== 0 || !waiting) throw Error('concurrency overlap not established');
    const results = await Promise.all(racers.map((entry) => entry.done));
    const failed = results.filter((entry) => entry.code !== 0);
    if (expectedFailure) {
      if (expectedFailure === '54000') {
        if (failed.length !== 1 || !failed[0].stderr.includes('ERROR:  54000:')) throw Error('capacity race refusal');
      } else if (failed.length !== 1 || !new RegExp(`ERROR:\\s+P0001:\\s+${expectedFailure}(?:\\r?\\n|$)`).test(failed[0].stderr)) throw Error('unexpected race outcome');
    } else if (failed.length) throw Error('unexpected race failure');
    console.log(`PASS: synthetic ${label} race (two blocked sessions observed).`);
  } finally {
    clearTimeout(timeout);
    blocker.child.stdin.end();
  }
}

async function operationRaces() {
  stage = 'operation-race-fixtures';
  await query(`SET ROLE service_role; SELECT api.owner_activate_membership_purchase('${owner}','${purchase}');`);
  const checkin = `SELECT api.commit_member_checkin('${member}',1)`;
  stage = 'daily-checkin';
  await race('daily-checkin', `SELECT id FROM private.members WHERE id='${member}' FOR UPDATE`, [checkin,checkin]);
  await query(`DO $assert$ BEGIN IF (SELECT count(*) FROM private.attendance_checkins WHERE member_id='${member}' AND attendance_status='valid')<>1
   OR (SELECT count(*) FROM private.audit_events WHERE event_type='member.checked_in' AND details->>'member_id'='${member}')<>1
   THEN RAISE EXCEPTION 'Daily check-in race cardinality'; END IF; END $assert$;`);

  await query(`SET ROLE service_role; SELECT api.owner_set_walkin_fee('${owner}',100,'Synthetic operation-race fee');`);
  const request = JSON.parse(await query(`SET ROLE service_role; SELECT api.public_create_walkin_request('cash',100);`));
  const walkinOp = '11000000-0000-4000-8000-000000000001';
  const confirm = `SELECT api.owner_confirm_walkin('${owner}',${quote(request.id)},'${walkinOp}',100,'cash',true)`;
  stage = 'walkin-confirm';
  await race('walkin-confirm', `SELECT id FROM private.walkin_requests WHERE id=${quote(request.id)} FOR UPDATE`, [confirm,confirm]);
  await query(`DO $assert$ BEGIN IF (SELECT count(*) FROM private.payment_records WHERE operation_id='${walkinOp}')<>1
   OR (SELECT count(*) FROM private.attendance_checkins WHERE walkin_request_id=${quote(request.id)})<>1 THEN RAISE EXCEPTION 'Walk-in race cardinality'; END IF; END $assert$;`);

  const reviewedPurchase = JSON.parse(await query(`SET ROLE service_role; SELECT api.owner_create_membership_purchase('${owner}','${member}','${plan}');`));
  const receipt = JSON.parse(await query(`SET ROLE service_role; SELECT api.owner_record_actual_receipt('${owner}',gen_random_uuid(),500,'cash','Synthetic allocation race receipt','SYNTHETIC-RACE',true,NULL);`));
  const allocate = `SELECT api.owner_allocate_verified_receipt('${owner}',${quote(receipt.paymentId)},${quote(reviewedPurchase.id)},NULL,'Synthetic allocation race review','SYNTHETIC-RACE',false)`;
  stage = 'receipt-allocation';
  await race('receipt-allocation', `SELECT id FROM private.members WHERE id='${member}' FOR UPDATE`, [allocate,allocate]);
  await query(`DO $assert$ BEGIN IF (SELECT count(*) FROM private.receipt_allocation_reviews WHERE payment_id=${quote(receipt.paymentId)})<>1
   OR (SELECT count(*) FROM private.payment_allocations WHERE payment_id=${quote(receipt.paymentId)})<>1
   OR (SELECT count(*) FROM private.payment_events WHERE payment_id=${quote(receipt.paymentId)} AND event_type='payment.confirmed')<>1
   THEN RAISE EXCEPTION 'Reviewed allocation race cardinality'; END IF; END $assert$;`);

  async function paidMember(hex) {
    const m = JSON.parse(await query(`SET ROLE service_role; SELECT api.owner_register_member('${owner}','Synthetic operation race member',decode(repeat('${hex}',32),'hex'),decode(repeat('${hex}',32),'hex'));`));
    await query(`SET ROLE service_role; SELECT api.owner_approve_member('${owner}',${quote(m.id)},'Synthetic approved race registration');`);
    const p = JSON.parse(await query(`SET ROLE service_role; SELECT api.owner_create_membership_purchase('${owner}',${quote(m.id)},'${plan}');`));
    const r = JSON.parse(await query(`SET ROLE service_role; SELECT api.owner_record_membership_payment('${owner}',gen_random_uuid(),${quote(p.id)},500,'cash',NULL);`));
    await query(`SET ROLE service_role; SELECT api.owner_confirm_membership_payment('${owner}',${quote(r.id)},true); SELECT api.owner_activate_membership_purchase('${owner}',${quote(p.id)});`);
    return {m,p,r};
  }
  const presence = await paidMember('e1');
  const claim = JSON.parse(await query(`SET ROLE service_role; SELECT api.owner_submit_attendance_claim('${owner}',gen_random_uuid(),${quote(presence.m.member_code)},(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date);`));
  const resolveClaim = `SELECT api.owner_resolve_attendance_claim('${owner}',${quote(claim.id)},true,'Synthetic current presence race confirmed')`;
  stage = 'claim-confirm';
  await race('claim-confirm', `SELECT id FROM private.members WHERE id=${quote(presence.m.id)} FOR UPDATE`, [resolveClaim,resolveClaim]);
  await query(`DO $assert$ BEGIN IF (SELECT count(*) FROM private.owner_claim_resolutions WHERE claim_id=${quote(claim.id)})<>1
   OR (SELECT count(*) FROM private.attendance_checkins WHERE member_id=${quote(presence.m.id)})<>1 THEN RAISE EXCEPTION 'Claim race cardinality'; END IF; END $assert$;`);

  const corrected = await paidMember('e2');
  const raceToken = 'cd'.repeat(32);
  await query(`SET ROLE service_role; SELECT api.owner_create_verified_pin_enrollment_token('${owner}',${quote(corrected.m.id)},'${raceToken}','Synthetic in-person race identity'); SELECT api.member_enroll_pin('${raceToken}',${quote(phc)});`);
  stage = 'void-checkin';
  await race('void-checkin', `SELECT id FROM private.members WHERE id=${quote(corrected.m.id)} FOR UPDATE`, [
    `SELECT api.commit_member_checkin(${quote(corrected.m.id)},1)`,
    `SELECT api.owner_void_payment_confirmation('${owner}',${quote(corrected.r.id)},'Synthetic erroneous receipt race','SYNTHETIC-RACE',false)`,
  ]);
  await query(`DO $assert$ BEGIN IF EXISTS(SELECT 1 FROM private.attendance_checkins WHERE member_id=${quote(corrected.m.id)} AND attendance_status<>'invalidated_payment')
   OR NOT EXISTS(SELECT 1 FROM private.payment_confirmation_voids WHERE payment_id=${quote(corrected.r.id)})
   OR (SELECT count(*) FROM private.attendance_checkins WHERE member_id=${quote(corrected.m.id)})>1 THEN RAISE EXCEPTION 'Void/check-in race left valid or duplicated attendance'; END IF; END $assert$;
   SET ROLE service_role; DO $audit$ DECLARE stream text; valid boolean; BEGIN
    FOR stream IN SELECT unnest(ARRAY['attendance','walkins','payments','members']) LOOP
     SELECT is_valid INTO valid FROM api.verify_audit_stream(stream); IF valid IS DISTINCT FROM true THEN RAISE EXCEPTION 'Operation race audit chain invalid'; END IF;
    END LOOP; END $audit$;`);
  console.log('PASS: operation-race cardinality, same-operation retries, void eligibility exclusion and audit streams. Synthetic SQL only.');
}

try {
  await validateTarget();
  if (process.argv.includes('--ingress')) {
    stage='ingress';
    const reset=`UPDATE private.walkin_ingress_state SET last_second=0,day_number=0,day_attempts=0;
UPDATE private.walkin_ingress_seconds SET second_number=0,attempts=0;
UPDATE private.walkin_ingress_leases SET ticket=NULL,expires_at=NULL,digest=NULL,action=NULL,method=NULL,fingerprint=NULL;`;
    const admission="SET statement_timeout='1s'; SET lock_timeout='100ms'; SET ROLE service_role; SELECT api.public_walkin_admit();";
    await query(reset);
    const clients=Array.from({length:8},()=>start('BEGIN;\n\\echo GYMFORCE_LOCK_READY',{hold:true}));
    if(!(await Promise.all(clients.map(c=>c.ready))).every(Boolean))throw Error('ingress barrier');
    for(const client of clients)client.child.stdin.end("SET LOCAL statement_timeout='1s'; SET LOCAL lock_timeout='100ms'; SET LOCAL ROLE service_role; SELECT api.public_walkin_admit(); COMMIT;\n");
    const results=await Promise.all(clients.map(c=>c.done));
    let allowed=0;
    for(const result of results){
      if(result.code!==0){if(!result.stderr.includes('55P03'))throw Error('unexpected admission failure');continue;}
      const line=result.stdout.split('\n').find(x=>x.startsWith('{'));
      if(!line)throw Error('missing admission result');
      const value=JSON.parse(line);if(value.status==='allowed')allowed++;else if(value.status!=='denied')throw Error('unexpected admission classification');
    }
    if(Number(await query('SELECT count(*) FROM private.walkin_ingress_leases WHERE ticket IS NOT NULL'))!==allowed||allowed<1||allowed>8)throw Error('lease race cardinality');
    for(let i=allowed;i<8;i++)if(JSON.parse(await query(admission)).status!=='allowed')throw Error('slot fill');
    if(JSON.parse(await query(admission)).status!=='denied')throw Error('ninth lease');
    await query(reset);
    const original=JSON.parse(await query(admission)).ticket;
    await query(`UPDATE private.walkin_ingress_leases SET expires_at=clock_timestamp()+interval '1 second' WHERE ticket=${quote(original)}::uuid`);
    const held=start(`BEGIN; SELECT slot FROM private.walkin_ingress_leases WHERE ticket=${quote(original)}::uuid FOR UPDATE;\n\\echo GYMFORCE_LOCK_READY`,{hold:true});
    try{
      if(!await held.ready)throw Error('lease lock');
      let expired=false;
      for(let i=0;i<30;i++){
        if(await query(`SELECT clock_timestamp()>=expires_at FROM private.walkin_ingress_leases WHERE ticket=${quote(original)}::uuid`)==='t'){expired=true;break;}
        await new Promise(done=>setTimeout(done,50));
      }
      if(!expired)throw Error('lease did not expire while lock held');
      const replacement=JSON.parse(await query(admission));
      if(replacement.status!=='allowed'||replacement.ticket===original)throw Error('reclaimed locked lease');
      if(await query(`SELECT count(*) FROM private.walkin_ingress_leases WHERE ticket=${quote(original)}::uuid`)!=='1')throw Error('locked lease erased');
    }finally{held.child.stdin.end('ROLLBACK;\n');await held.done;}
    stage='ingress-aba';
    const reusedSlot=await query(`SELECT slot FROM private.walkin_ingress_leases WHERE ticket=${quote(original)}::uuid`);
    // Occupy other slots so this proves same-slot reuse, not merely new UUIDs.
    await query(`UPDATE private.walkin_ingress_leases SET ticket=coalesce(ticket,gen_random_uuid()),expires_at=clock_timestamp()+interval '1 minute' WHERE ticket IS DISTINCT FROM ${quote(original)}::uuid`);
    const renewed=JSON.parse(await query(admission)).ticket;
    if(await query(`SELECT slot FROM private.walkin_ingress_leases WHERE ticket=${quote(renewed)}::uuid`)!==reusedSlot)throw Error('ABA fixture did not reuse same slot');
    await query(`SET statement_timeout='1s'; SET lock_timeout='100ms'; SET ROLE service_role; SELECT api.public_walkin_finish(${quote(original)}::uuid,'denied');`);
    if(renewed===original||await query(`SELECT count(*) FROM private.walkin_ingress_leases WHERE ticket=${quote(renewed)}::uuid`)!=='1'||await query(`SELECT count(*) FROM private.walkin_ingress_leases WHERE ticket=${quote(original)}::uuid`)!=='0')throw Error('ABA stale finish erased renewed generation');
    await query(reset);

    // Two real psql transactions compete for one token under the global lock.
    stage='ingress-final-token';
    const tickets=[];
    for(let i=0;i<2;i++)tickets.push(JSON.parse(await query(admission)).ticket);
    await query("UPDATE private.walkin_ingress_buckets SET tokens=1,updated_at=clock_timestamp(),lookup_tokens=2 WHERE slot=2730");
    const tokenClients=tickets.map(()=>start('BEGIN;\n\\echo GYMFORCE_LOCK_READY',{hold:true}));
    if(!(await Promise.all(tokenClients.map(c=>c.ready))).every(Boolean))throw Error('token barrier');
    tokenClients.forEach((c,i)=>c.child.stdin.end(`SET LOCAL statement_timeout='1s'; SET LOCAL lock_timeout='100ms'; SET LOCAL ROLE service_role; SELECT api.public_walkin_bind(${quote(tickets[i])}::uuid,decode(repeat('aa',32),'hex'),'create','cash'); COMMIT;\n`));
    const tokenResults=await Promise.all(tokenClients.map(c=>c.done));
    if(tokenResults.some(r=>r.code!==0))throw Error('token client failure');
    const tokenStatuses=tokenResults.map(r=>JSON.parse(r.stdout.split('\n').find(x=>x.startsWith('{'))).status).sort();
    if(tokenStatuses.join(',')!=='allowed,denied')throw Error('token classifications');
    if(await query("SELECT count(*) FROM private.walkin_ingress_leases WHERE digest=decode(repeat('aa',32),'hex')")!=='1')throw Error('final token double consumption');
    await query(reset);
    // Reuse guarded SQL fixture source, preserving triggers and hash assertions.
    stage='ingress-capacity-fixture';
    const source=readFileSync(resolve(root,'supabase/tests/public_walkin_ingress.sql'),'utf8');
    const hashFunction=source.match(/CREATE FUNCTION pg_temp\.protected_hash\(\)[\s\S]*?\$f\$;/)?.[0];
    const seed=source.match(/DO \$capacity\$[\s\S]*?END \$capacity\$;/)?.[0];
    if(!hashFunction||!seed)throw Error('capacity fixture source missing');
    await query(`SET statement_timeout='60s'; ${hashFunction} ${seed}`);
    const operations=[];
    for(const byte of ['ab','ac']){
      const ticket=JSON.parse(await query(admission)).ticket;
      await query(`SET statement_timeout='1s'; SET lock_timeout='100ms'; SET ROLE service_role; SELECT api.public_walkin_bind(${quote(ticket)}::uuid,decode(repeat('${byte}',32),'hex'),'create','cash')`);
      operations.push(`SET LOCAL statement_timeout='5s'; SET LOCAL lock_timeout='500ms'; SELECT api.public_walkin_execute(${quote(ticket)}::uuid,decode(repeat('${byte}',32),'hex'),'create','cash')`);
    }
    stage='ingress-final-capacity';
    await race('ingress-final-capacity','SELECT id FROM private.walkin_ingress_capacity WHERE id=1 FOR UPDATE',operations,'54000');
    if(await query('SELECT count(*) FROM private.walkin_creation_operations')!=='10000'||await query('SELECT bindings FROM private.walkin_ingress_capacity')!=='10000')throw Error('final capacity race drift');
    await query(reset);
    console.log('PASS: barrier-released native token clients and two blocked capacity clients compete for the final slots; exactly one binding wins each race. No multi-isolate HTTP claim.');
    console.log('PASS: eight barrier-released native admission clients respect slot cardinality; ninth lease refused; expired locked lease skipped without erasure. SQL transport only, not Edge/PostgREST integration.');
  } else if (process.argv.includes('--public-recovery')) {
    stage = 'public-recovery';
    const digest = `decode(repeat('65',32),'hex')`;
    const create = `SELECT api.public_create_walkin_request_v2(${digest},'cash',100)`;
    const before = Number(await query('SELECT count(*) FROM private.walkin_requests'));
    await query(`SET ROLE service_role; SELECT api.owner_set_walkin_fee('${owner}',125,'Synthetic recovery race fee')`);
    await race('public-recovery-identical', `SELECT pg_advisory_xact_lock(hashtextextended('gymforce-walkin-recovery:v1:'||repeat('65',32),0))`, [create, create]);
    const replay = JSON.parse(await query(`SET ROLE service_role; ${create}`));
    if (replay.classification !== 'PROVISIONAL_RECOVERED' || Number(await query('SELECT count(*) FROM private.walkin_requests')) !== before + 1) throw Error('recovery race cardinality');
    const lookup = JSON.parse(await query(`SET ROLE service_role; SELECT api.public_lookup_walkin_request(${digest})`));
    if (JSON.stringify(lookup.request) !== JSON.stringify(replay.request)) throw Error('lost response recovery');
    const conflict = JSON.parse(await query(`SET ROLE service_role; SELECT api.public_create_walkin_request_v2(${digest},'gcash',100)`));
    if (conflict.classification !== 'OPERATION_CONFLICT') throw Error('conflict accepted');
    await query(`BEGIN; SET LOCAL ROLE service_role; SELECT api.public_create_walkin_request_v2(decode(repeat('66',32),'hex'),'cash',100); ROLLBACK`);
    if (await query("SELECT count(*) FROM private.walkin_creation_operations WHERE capability_digest=decode(repeat('66',32),'hex')") !== '0') throw Error('rollback binding');
    const pending = start(`BEGIN; SET LOCAL ROLE service_role; SELECT api.public_create_walkin_request_v2(decode(repeat('70',32),'hex'),'cash',100);\n\\echo GYMFORCE_LOCK_READY`,{hold:true});
    if(!await pending.ready)throw Error('uncommitted recovery setup');
    pending.child.kill(); await pending.done;
    if(await query("SELECT count(*) FROM private.walkin_creation_operations WHERE capability_digest=decode(repeat('70',32),'hex')")!=='0')throw Error('connection loss committed pending operation');
    const blocker=start(`BEGIN; SELECT pg_advisory_xact_lock(hashtextextended('gymforce-walkin-recovery:v1:'||repeat('71',32),0));\n\\echo GYMFORCE_LOCK_READY`,{hold:true});
    try {
      if(!await blocker.ready)throw Error('recovery timeout blocker');
      const timed=start("BEGIN; SET LOCAL statement_timeout='100ms'; SET LOCAL ROLE service_role; SELECT api.public_create_walkin_request_v2(decode(repeat('71',32),'hex'),'cash',100); COMMIT;");
      const timeout=await timed.done;
      if(timeout.code===0||!timeout.stderr.includes('57014'))throw Error('recovery timeout not refused');
    } finally {blocker.child.stdin.end('ROLLBACK;\n');await blocker.done;}
    if(await query("SELECT count(*) FROM private.walkin_creation_operations WHERE capability_digest=decode(repeat('71',32),'hex')")!=='0')throw Error('timed out operation persisted');
    const confirmationOperation='61000000-0000-4000-8000-000000000001';
    const confirmation=`SELECT api.owner_confirm_walkin('${owner}',${quote(replay.request.id)},'${confirmationOperation}',125,'cash',true)`;
    stage='recovery-owner';
    await race('recovery-owner',
      `SELECT pg_advisory_xact_lock(hashtextextended('gymforce-walkin-recovery:v1:'||repeat('65',32),0)); SELECT id FROM private.walkin_requests WHERE id=${quote(replay.request.id)} FOR UPDATE`,
      [create,confirmation]);
    if(JSON.parse(await query(`SET ROLE service_role; SELECT api.public_lookup_walkin_request(${digest})`)).classification!=='RECOVERY_CLOSED')throw Error('confirmed recovery disclosure');
    const ownerReplay=JSON.parse(await query(`SET ROLE service_role; ${confirmation}`));
    if(ownerReplay.replayed!==true || await query(`SELECT count(*) FROM private.payment_records WHERE operation_id='${confirmationOperation}'`)!=='1'
      || await query(`SELECT count(*) FROM private.attendance_checkins WHERE walkin_request_id=${quote(replay.request.id)}`)!=='1'
      || await query(`SELECT count(*) FROM private.payment_allocations WHERE walkin_request_id=${quote(replay.request.id)}`)!=='1')throw Error('recovery/confirmation cardinality');
    console.log('PASS: public recovery committed-row concurrency, conflict, lost-response lookup and rollback (synthetic SQL transport).');
    console.log('PASS: pre-commit psql connection loss and statement timeout leave no recovery binding.');
  } else if (process.argv.includes('--operations')) {
    await operationRaces();
  } else {
  // Administrator fixture creation is intentionally separate from application
  // approval/activation behavior, which this phase does not implement.
  stage = 'fixture-setup';
  await query(`BEGIN; DO $fixture$ BEGIN
 IF EXISTS(SELECT 1 FROM private.owner_access) OR EXISTS(SELECT 1 FROM private.members)
 OR EXISTS(SELECT 1 FROM private.membership_plans) OR EXISTS(SELECT 1 FROM private.membership_purchases)
 OR EXISTS(SELECT 1 FROM private.payment_records) THEN RAISE EXCEPTION 'Fresh fixture state required'; END IF;
END $fixture$;
INSERT INTO private.owner_access(user_id,is_active) VALUES('${owner}',true);
INSERT INTO private.members(id,member_code,full_name,mobile_lookup_hash,mobile_encrypted,status,approved_at)
 VALUES('${member}','SYNTHETIC-RACE-ONLY','Synthetic concurrency fixture',decode(repeat('b1',32),'hex'),decode(repeat('b2',32),'hex'),'active',clock_timestamp());
INSERT INTO private.membership_plans(id,name,price_php) VALUES('${plan}','Synthetic concurrency plan',500);
INSERT INTO private.membership_purchases(id,member_id,plan_id,price_php) VALUES('${purchase}','${member}','${plan}',500);
SET LOCAL ROLE service_role;
SELECT api.owner_create_pin_enrollment_token('${owner}','${member}','${token}',clock_timestamp()+interval '15 minutes');
SELECT api.owner_save_membership_plan('${owner}',NULL,'Synthetic audit-race seed',500,true);
COMMIT;`);

  const record = `SELECT api.owner_record_membership_payment('${owner}','${operation}','${purchase}',500,'cash',NULL)`;
  stage = 'payment-record';
  await race('payment-record', `SELECT id FROM private.membership_purchases WHERE id='${purchase}' FOR UPDATE`, [record, record], 'PAYMENT_AWAITING_DECISION');
  const payment = await query(`SELECT id FROM private.payment_records WHERE operation_id='${operation}';`);
  if (!/^[0-9a-f-]{36}$/.test(payment)) throw Error('receipt count');
  const replay = JSON.parse(await query(`SET ROLE service_role; ${record};`));
  if (replay.id !== payment || replay.replayed !== true) throw Error('idempotent replay');
  const confirm = `SELECT api.owner_confirm_membership_payment('${owner}','${payment}',true)`;
  stage = 'payment-confirm';
  await race('payment-confirm', `SELECT id FROM private.payment_records WHERE id='${payment}' FOR UPDATE`, [confirm, confirm], 'PAYMENT_NOT_AWAITING_DECISION');
  stage = 'token-redeem';
  await race('token-redeem', `SELECT id FROM private.member_pin_setup_tokens WHERE token_hash='${token}' FOR UPDATE`, [0, 1].map(() => `SELECT api.member_enroll_pin('${token}',${quote(phc)})`), 'INVALID_OR_EXPIRED_TOKEN');
  stage = 'audit-append';
  await race('audit-append', "SELECT stream_key FROM private.audit_chain_heads WHERE stream_key='membership_plans' FOR UPDATE",
    [0, 1].map((index) => `SELECT api.owner_save_membership_plan('${owner}',NULL,'Synthetic audit-race ${index}',500,true)`));
  stage = 'final-invariants';
  await query(`DO $assert$ BEGIN
 IF (SELECT count(*) FROM private.payment_records WHERE operation_id='${operation}')<>1
 OR (SELECT count(*) FROM private.payment_allocations WHERE payment_id='${payment}')<>1
 OR (SELECT count(*) FROM private.payment_events WHERE payment_id='${payment}' AND event_type='payment.confirmed')<>1
 OR (SELECT count(*) FROM private.member_pin_credentials WHERE member_id='${member}')<>1
 OR (SELECT count(*) FROM private.member_pin_setup_tokens WHERE token_hash='${token}' AND consumed_at IS NOT NULL)<>1
 OR (SELECT count(*) FROM private.membership_plans WHERE name IN ('Synthetic audit-race 0','Synthetic audit-race 1'))<>2
 OR (SELECT count(*) FROM private.audit_events WHERE stream_key='membership_plans')<>3
 THEN RAISE EXCEPTION 'Race cardinality invalid'; END IF;
END $assert$; SET ROLE service_role;
DO $audit$ DECLARE stream text; valid boolean; n bigint; BEGIN
 FOREACH stream IN ARRAY ARRAY['members','payments','membership_plans','member-pin:${member}'] LOOP
 SELECT is_valid,checked_events INTO valid,n FROM api.verify_audit_stream(stream);
 IF valid IS DISTINCT FROM true OR n IS NULL OR n=0 THEN RAISE EXCEPTION 'Audit chain invalid'; END IF;
 END LOOP;
END $audit$;`);
  console.log('PASS: synthetic race cardinality, identical retry and audit-chain assertions. Native SQL only; no JWT/Edge or production certification.');
  }
} catch {
  console.error(`FAIL: synthetic database concurrency checks at ${stage}; target guard, overlap or invariant failed. SQL and connection details suppressed.`);
  process.exitCode = 1;
} finally {
  for (const child of children) child.kill();
}
