// Synthetic-only barriers. Never installed by a migration or application server.
import assert from 'node:assert/strict';
export async function qualifyCommitFaults({sql, database, rpc, call, reset, capability, count, runId}) {
  const protectedState = () => sql(`SELECT md5(string_agg(v, '|' ORDER BY v)) FROM (
    SELECT 'p:'||row_to_json(t)::text v FROM private.payment_records t UNION ALL
    SELECT 'al:'||row_to_json(t)::text FROM private.payment_allocations t UNION ALL
    SELECT 'pe:'||row_to_json(t)::text FROM private.payment_events t UNION ALL
    SELECT 'm:'||row_to_json(t)::text FROM private.members t UNION ALL
    SELECT 'mp:'||row_to_json(t)::text FROM private.membership_purchases t UNION ALL
    SELECT 'a:'||row_to_json(t)::text FROM private.attendance_checkins t UNION ALL
    SELECT 'e:'||row_to_json(t)::text FROM private.audit_events t UNION ALL
    SELECT 'h:'||row_to_json(t)::text FROM private.audit_chain_heads t
  ) s`);
  // Both triggers use invoker authority and preserve every existing guard.
  const install = (table, deferred) => sql(`CREATE FUNCTION private.gf_http_fault() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
    BEGIN IF pg_catalog.current_database()<>'gymforce_batch1_synthetic' OR pg_catalog.current_setting('gymforce.synthetic_run_id',true) IS DISTINCT FROM '${runId}' THEN RAISE EXCEPTION 'Synthetic barrier refused'; END IF;
    PERFORM pg_catalog.pg_sleep(10); RETURN NEW; END $f$;
    REVOKE ALL ON FUNCTION private.gf_http_fault() FROM PUBLIC,anon,authenticated,service_role;
    CREATE ${deferred?'CONSTRAINT ':''}TRIGGER gf_http_fault ${deferred?'AFTER':'BEFORE'} INSERT ON private.${table}
    ${deferred?'DEFERRABLE INITIALLY DEFERRED ':''}FOR EACH ROW EXECUTE FUNCTION private.gf_http_fault();`);
  const remove = table => sql(`DROP TRIGGER IF EXISTS gf_http_fault ON private.${table}; DROP FUNCTION IF EXISTS private.gf_http_fault();`);
  for (const [label,table,deferred,terminate] of [
    ['mid-business-disconnect','walkin_requests',false,true],
    ['pre-commit-disconnect','walkin_creation_operations',true,true],
    ['statement-timeout','walkin_requests',false,false],
  ]) {
    console.log(`BEGIN commit fault ${label}`);
    await reset(); await sql('DELETE FROM private.walkin_request_rate_events');
    const cap=capability(), before=await count(), history=await protectedState();
    await install(table,deferred);
    let killer;
    try {
      if(terminate) {
        killer=database(`\n\\echo HTTP_LOCK_READY
        DO $k$ DECLARE target integer; deadline timestamptz:=clock_timestamp()+interval '12 seconds'; BEGIN
        LOOP PERFORM pg_catalog.pg_stat_clear_snapshot(); SELECT pid INTO target FROM pg_catalog.pg_stat_activity WHERE usename='gf_http_transport'
          AND wait_event='PgSleep' AND (query LIKE '%public_walkin_execute%' OR query ILIKE 'COMMIT%') LIMIT 1;
          EXIT WHEN target IS NOT NULL; IF clock_timestamp()>deadline THEN RAISE EXCEPTION 'Barrier not observed'; END IF; PERFORM pg_sleep(.005); END LOOP;
        IF NOT pg_catalog.pg_terminate_backend(target) THEN RAISE EXCEPTION 'Disconnect failed'; END IF; END $k$;`,true);
        await killer.ready;killer.c.stdin.end();
      }
      const response=await call(cap); assert.equal(response.status,503,label);
      if(killer) await killer.done;
    } finally { await remove(table); }
    assert.equal(await count(),before,label+' binding rollback');
    assert.equal(await protectedState(),history,label+' protected history unchanged');
    assert.ok(Number(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds'))>=1,'Independent charge persists');
    await reset(); assert.equal((await call(cap,'lookup')).status,404);
    await reset(); assert.equal((await call(cap)).status,201);
    await reset(); assert.equal((await call(cap)).status,200);
    assert.equal(await count(),before+1,'Uncertain retry creates once');
    assert.equal(await protectedState(),history,'Public retry creates no payment/attendance');
    console.log(`PASS commit fault ${label}: real SQL barrier, actual HTTP 503, observed rollback and independent charge; lookup/retry/replay creates one binding.`);
  }
  // Verify actual JWT gateway rejection independently of unavailable GoTrue.
  for(const token of ['not-a-jwt','eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjF9.invalid']) {
    assert.equal((await rpc('public_walkin_admit',{},token)).status,401);
  }
}
export async function qualifyFinancialFaults({sql,database,rpc,call,reset,capability,runId,owner,randomUUID}) {
  for(const [table,deferred] of [['payment_records',false],['attendance_checkins',true]]) {
    await reset();await sql('DELETE FROM private.walkin_request_rate_events');
    const request=(await call(capability())).data.request;
    assert.ok(request?.id);
    const op=randomUUID(),args={p_actor_user_id:owner,p_request_id:request.id,p_operation_id:op,p_amount_php:125,p_payment_method:'cash',p_evidence_reviewed:true};
    const snapshot=()=>sql(`SELECT md5(jsonb_build_array(
      (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM private.payment_records t),
      (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM private.payment_allocations t),
      (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM private.payment_events t),
      (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM private.attendance_checkins t),
      (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM private.audit_events t),
      (SELECT jsonb_agg(to_jsonb(t) ORDER BY stream_key) FROM private.audit_chain_heads t))::text)`);
    const before=await snapshot();
    await sql(`CREATE FUNCTION private.gf_financial_fault() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$ BEGIN
      IF pg_catalog.current_database()<>'gymforce_batch1_synthetic' OR pg_catalog.current_setting('gymforce.synthetic_run_id',true) IS DISTINCT FROM '${runId}' THEN RAISE EXCEPTION 'Synthetic financial guard'; END IF;
      PERFORM pg_catalog.pg_sleep(10); RETURN NEW; END $f$;
      REVOKE ALL ON FUNCTION private.gf_financial_fault() FROM PUBLIC,anon,authenticated,service_role;
      CREATE ${deferred?'CONSTRAINT ':''}TRIGGER gf_financial_fault ${deferred?'AFTER':'BEFORE'} INSERT ON private.${table}
      ${deferred?'DEFERRABLE INITIALLY DEFERRED ':''}FOR EACH ROW EXECUTE FUNCTION private.gf_financial_fault();`);
    const killer=database(`\n\\echo HTTP_LOCK_READY
      DO $k$ DECLARE target integer;deadline timestamptz:=clock_timestamp()+interval '12 seconds'; BEGIN LOOP
      PERFORM pg_catalog.pg_stat_clear_snapshot(); SELECT pid INTO target FROM pg_catalog.pg_stat_activity WHERE usename='gf_http_transport' AND wait_event='PgSleep' AND (query LIKE '%owner_confirm_walkin%' OR query ILIKE 'COMMIT%') LIMIT 1;
      EXIT WHEN target IS NOT NULL;IF clock_timestamp()>deadline THEN RAISE EXCEPTION 'Financial barrier not observed';END IF;PERFORM pg_sleep(.005);END LOOP;
      IF NOT pg_terminate_backend(target) THEN RAISE EXCEPTION 'Financial disconnect failed';END IF;END $k$;`,true);
    await killer.ready;killer.c.stdin.end();
    try {assert.ok((await rpc('owner_confirm_walkin',args)).status>=400);await killer.done;}
    finally {await sql(`DROP TRIGGER gf_financial_fault ON private.${table};DROP FUNCTION private.gf_financial_fault();`);}
    assert.equal(await snapshot(),before,'Payment, attendance and audit hashes roll back together');
    assert.equal((await rpc('owner_confirm_walkin',args)).status,200);
    assert.equal((await rpc('owner_confirm_walkin',args)).status,200);
    assert.equal(await sql(`SELECT count(*) FROM private.payment_records WHERE operation_id='${op}'::uuid`),'1');
    assert.equal(await sql(`SELECT count(*) FROM private.attendance_checkins WHERE walkin_request_id='${request.id}'::uuid`),'1');
    console.log(`PASS financial ${deferred?'pre-commit':'mid-business'} backend interruption: protected ledger/attendance/audit snapshot unchanged; actual RPC retry/replay creates one payment and attendance. Owner Auth still not included.`);
  }
}
export async function qualifyHttpClock({sql,rpc,reset,digest,capability}) {
  await reset();await sql("UPDATE private.walkin_ingress_state SET last_second=floor(extract(epoch FROM clock_timestamp()))::bigint+3600");
  assert.equal((await rpc('public_walkin_admit')).data.status,'unavailable');
  await reset();await sql("UPDATE private.walkin_ingress_state SET day_number=floor(extract(epoch FROM clock_timestamp()))::bigint/86400-1,day_attempts=2000");
  assert.equal((await rpc('public_walkin_admit')).data.status,'allowed');
  assert.equal(await sql('SELECT day_attempts FROM private.walkin_ingress_state'),'1');
  for(const [seconds,status] of [[59,'denied'],[61,'allowed']]) {
    await reset();await sql(`UPDATE private.walkin_ingress_seconds SET second_number=floor(extract(epoch FROM clock_timestamp()))::bigint-${seconds},attempts=120 WHERE slot=mod(floor(extract(epoch FROM clock_timestamp()))::bigint-${seconds},61)`);
    assert.equal((await rpc('public_walkin_admit')).data.status,status);
  }
  await reset();const d=digest(capability()),slot=parseInt(d.slice(2,5),16),tickets=[];
  for(let i=0;i<2;i++)tickets.push((await rpc('public_walkin_admit')).data.ticket);
  await sql(`UPDATE private.walkin_ingress_buckets SET tokens=1,lookup_tokens=2,updated_at=clock_timestamp() WHERE slot=${slot}`);
  const bound=await Promise.all(tickets.map(t=>rpc('public_walkin_bind',{p_ticket:t,p_digest:d,p_action:'create',p_method:'cash'})));
  assert.deepEqual(bound.map(r=>r.data.status).sort(),['allowed','denied']);
  console.log('PASS persisted HTTP clock-relative backward denial, prior UTC-day reset, 59/61s sliding window and simultaneous final-token bind contention. No wall-clock midnight or exact 60s cutover claim.');
}
export async function qualifyAttemptMatrix({origin,sql,reset,capability,count}) {
  const endpoint=origin+'/functions/v1/public-walkin-recovery';
  for(const size of [2047,2048,2049]) {
    await reset();await sql('DELETE FROM private.walkin_request_rate_events');
    const before=await count(),base=JSON.stringify({action:'create',capability:capability(),paymentMethod:'cash'});
    const response=await fetch(endpoint,{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body:base.padEnd(size,' ')});
    assert.equal(response.status,size<=2048?201:400);
    assert.equal(await count(),before+(size<=2048?1:0));
    assert.equal(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds'),'1');
  }
  for(const [body,type] of [['{','application/json'],['null','application/json'],['{}','application/json'],['{}','text/plain']]) {
    await reset();const before=await count();
    assert.equal((await fetch(endpoint,{method:'POST',headers:{Origin:origin,'Content-Type':type},body})).status,400);
    assert.equal(await count(),before);assert.equal(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds'),'1');
  }
  await reset();const rejected=await fetch(endpoint,{method:'POST',headers:{Origin:'https://invalid.example','Content-Type':'application/json'},body:'{}'});
  assert.equal(rejected.status,403);assert.equal(rejected.headers.get('access-control-allow-origin'),null);
  assert.equal((await fetch(endpoint,{headers:{Origin:origin}})).status,405);
  assert.equal(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds'),'0');
  console.log('PASS persisted all-attempt boundaries: valid 2047/2048 bytes commit once, 2049/malformed/schema/header rejection charged with no binding; disallowed Origin and GET remain outside POST admission.');
}
export async function qualifyIndependentLoad({sql,call,reset,capability,count}) {
  const before=await count(),observations=[];
  await reset();const hot=capability();
  const keyed=await Promise.all(Array.from({length:8},()=>call(hot,'lookup')));
  assert.ok(keyed.every(r=>[404,429,503].includes(r.status)));
  const recovered=keyed.filter(r=>r.status===404).length;
  assert.ok(recovered>=1&&recovered<=2,'Hot-key lookup budget');
  assert.equal(Number(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds')),8);
  observations.push({scope:'eight-concurrent-hot-key',attempts:8,allowed:recovered,denied:keyed.filter(r=>r.status===429).length,unavailable:keyed.filter(r=>r.status===503).length});
  await reset();const start=Number(await sql('SELECT floor(extract(epoch FROM clock_timestamp()))'));
  const waves=[];
  // Never more than eight HTTP attempts in flight. The gateway round-robins the
  // unchanged module in two independent Deno processes against one database.
  for(let wave=0;wave<3;wave++)waves.push(...await Promise.all(Array.from({length:8},()=>call(capability(),'lookup'))));
  const end=Number(await sql('SELECT floor(extract(epoch FROM clock_timestamp()))'));
  assert.ok(end-start<10,'Burst campaign must fit within one trailing ten-second interval');
  assert.ok(waves.every(r=>[404,429,503].includes(r.status)));
  assert.ok(waves.filter(r=>r.status===404).length<=20);
  assert.ok(waves.filter(r=>r.status===429).length>=4);
  assert.equal(Number(await sql('SELECT sum(attempts) FROM private.walkin_ingress_seconds')),24);
  assert.equal(await count(),before,'Lookup load cannot create business records');
  observations.push({scope:'three-eight-request-waves',attempts:24,seconds:end-start,allowed:waves.filter(r=>r.status===404).length,denied:waves.filter(r=>r.status===429).length,unavailable:waves.filter(r=>r.status===503).length});
  console.log('PASS persisted two-process HTTP load: eight hot-key attempts bounded by lookup budget; 24 rotating-key attempts in three eight-request waves enforce global burst without business creation.');
  return observations;
}
