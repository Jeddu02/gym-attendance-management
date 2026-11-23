import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdir,rm,writeFile,readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {randomUUID} from 'node:crypto';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createServer} from 'node:http';
import {DurableIngressQueue,localDestination,scheduleLocalCleanup} from '../scripts/recovery/durable-ingress-ops.mjs';
const alert=(minute,kind='denied')=>({minute,kind,count:20,key:`${minute}:${kind}`});
async function fixture(fn){const dir=resolve('.cache','ops-test-'+randomUUID());await mkdir(dir,{recursive:true});try{await fn(dir);}finally{await rm(dir,{recursive:true,force:true});}}
test('durable delivery survives restart, lost acknowledgement and HTTP failure without duplicate sink effects',()=>fixture(async dir=>{
  let sink=new DurableIngressQueue(dir,'sink'),reject=true,lost=false;
  const server=createServer(async(req,res)=>{
    let text='';for await(const b of req)text+=b;
    const a=JSON.parse(text);if(reject){res.writeHead(503).end();return;}
    await sink.enqueue(a,10);if(lost){lost=false;res.destroy();return;}res.end(a.key);
  });await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{
    const deliver=localDestination(`http://127.0.0.1:${server.address().port}/synthetic-alert`);
    let q=new DurableIngressQueue(dir);await q.enqueue(alert(10),10);
    await assert.rejects(q.flush(10,deliver));assert.equal((await q.inspect(10)).pending,1);
    reject=false;lost=true;await assert.rejects(q.flush(10,deliver));assert.equal((await sink.inspect(10)).retained,1);
    sink=new DurableIngressQueue(dir,'sink');q=new DurableIngressQueue(dir);await q.flush(10,deliver);await q.enqueue(alert(10),10);await q.flush(10,deliver);
    assert.equal((await sink.inspect(10)).retained,1);assert.equal((await q.inspect(10)).pending,0);
    assert.doesNotMatch(await readFile(q.file,'utf8'),/capability|password|identifier/);
  }finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
}));
test('independent watchdog process detects stopped heartbeat and deduplicates across restarts',()=>fixture(async dir=>{
  const q=new DurableIngressQueue(dir),watch=new DurableIngressQueue(dir,'watchdog');await q.heartbeat(10);
  const child=minute=>promisify(execFile)(process.execPath,['scripts/recovery/durable-ingress-ops.mjs','watchdog',dir,String(minute)],{windowsHide:true});
  await child(12);assert.equal((await watch.inspect(12)).retained,0);
  await writeFile(q.file+'.lock',''); // Interrupted worker, no unsafe lock stealing.
  await child(13);await child(13);assert.equal((await watch.inspect(13)).pending,1);
  await rm(q.file+'.lock');await q.heartbeat(13);await child(14);assert.equal((await watch.inspect(14)).retained,1);
  await watch.inspect(2893);assert.equal((await watch.inspect(2893)).retained,0);
  await assert.rejects(watch.inspect(2892),/STATE/);
}));
test('queue refuses private/malformed telemetry, concurrent lock, stale temp and corrupted state',()=>fixture(async dir=>{
  const q=new DurableIngressQueue(dir);
  assert.throws(()=>q.enqueue({...alert(10),capability:'not-persisted'},10),/ALERT/);
  await q.enqueue(alert(10),10);await writeFile(q.file+'.lock','');await assert.rejects(q.inspect(10));await rm(q.file+'.lock');
  await writeFile(q.file+'.tmp','');await assert.rejects(q.inspect(10));await rm(q.file+'.tmp');
  await writeFile(q.file,'{"private":"not-valid"}');await assert.rejects(q.inspect(10),/STATE/);
  for(const url of ['https://127.0.0.1/synthetic-alert','http://localhost/synthetic-alert','http://127.0.0.1/other','http://127.0.0.1/synthetic-alert?secret=1'])assert.throws(()=>localDestination(url));
}));
test('serialized scheduler executes idle ticks, reports sanitized failure and stops without overlap',async()=>{
  let calls=0,active=0,max=0;const errors=[];
  const stop=scheduleLocalCleanup(async()=>{calls++;active++;max=Math.max(max,active);try{await new Promise(r=>setTimeout(r,30));if(calls===1)throw Error('private');}finally{active--; }},{intervalMs:25,onFailure:e=>errors.push(e)});
  await new Promise(r=>setTimeout(r,190));await stop();const stopped=calls;await new Promise(r=>setTimeout(r,80));
  assert.ok(calls>=2);assert.equal(calls,stopped);assert.equal(max,1);assert.deepEqual(errors,['MAINTENANCE_UNAVAILABLE']);
});
