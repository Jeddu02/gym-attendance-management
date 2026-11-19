import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createHash } from 'node:crypto';
import { capabilityDigest, parseRecoveryInput } from '../supabase/functions/_shared/walkin-recovery.ts';
import { checkBrowserSource, checkReviewedRecoveryStorage } from '../scripts/check-source-security.mjs';
const origin='https://gym.example.test', capability='A'.repeat(43);
let generation=0;
async function handler(env) {
  let callback; globalThis.Deno={env:{get:key=>env[key]},serve:value=>{callback=value;}};
  const file=new URL('../supabase/functions/public-walkin-recovery/index.ts',import.meta.url);
  const code=stripTypeScriptTypes(await readFile(file,'utf8')).replace(/from\s+(["'])([^"']+)\1/g,(_m,_q,s)=>`from ${JSON.stringify(s.startsWith('npm:')?import.meta.resolve('@supabase/supabase-js'):new URL(s,file).href)}`);
  await import(`data:text/javascript;base64,${Buffer.from(code+`\n//${generation++}`).toString('base64')}`);
  return callback;
}
const request=(body,method='POST',requestOrigin=origin)=>new Request('https://edge.example.test',{method,headers:{Origin:requestOrigin,'Content-Type':'application/json'},...(method==='OPTIONS'?{}:{body:JSON.stringify(body)})});
test('real recovery handler preserves preflight, exact origin, config and local-only boundary',async()=>{
  const old=globalThis.Deno;
  try {
    const run=await handler({APP_ORIGIN:origin});
    assert.equal((await run(request({},'OPTIONS'))).status,204);
    const denied=await run(request({},'OPTIONS','https://evil.example.test'));
    assert.equal(denied.status,403); assert.equal(denied.headers.has('Access-Control-Allow-Origin'),false);
    assert.equal((await run(request({}))).status,503);
    const hosted=await handler({APP_ORIGIN:origin,SUPABASE_URL:'https://backend.example.test',SUPABASE_SERVICE_ROLE_KEY:'synthetic',PUBLIC_WALKIN_ENABLED:'true',WALKIN_REQUEST_LIMIT_PER_MINUTE:'5'});
    assert.equal((await hosted(request({action:'lookup',capability}))).status,503);
  } finally {globalThis.Deno=old;}
});
test('real recovery handler hashes capability and allowlists RPC outcomes without retry',async()=>{
  const oldDeno=globalThis.Deno, oldFetch=globalThis.fetch; let calls=0, result;
  const snapshot={id:'91000000-0000-4000-8000-000000000001',feePhp:'125.00',currency:'PHP',paymentMethod:'cash',createdAt:'2026-11-19T00:00:00Z',expiresAt:'2026-11-19T00:15:00Z'};
  globalThis.fetch=async(input,init)=>{
    const url=new URL(typeof input==='string'?input:input.url??input.href);
    assert.equal(url.origin,'http://127.0.0.1:54321');calls++;
    const args=JSON.parse(init.body);assert.equal(args.p_capability_digest,await capabilityDigest(capability));
    assert.equal(JSON.stringify(args).includes(capability),false);
    return Response.json(result);
  };
  try {
    const run=await handler({APP_ORIGIN:origin,SUPABASE_URL:'http://127.0.0.1:54321',SUPABASE_SERVICE_ROLE_KEY:'synthetic',PUBLIC_WALKIN_ENABLED:'true',WALKIN_REQUEST_LIMIT_PER_MINUTE:'5'});
    for(const [classification,status]of [['PROVISIONAL_CREATED',201],['PROVISIONAL_RECOVERED',200],['OPERATION_CONFLICT',409],['RECOVERY_CLOSED',410],['NO_RECOVERABLE_OUTCOME',404]]) {
      result={classification,request:{...snapshot,receiptId:'private-marker'},secret:'private-marker'};
      const response=await run(request({action:'create',capability,paymentMethod:'cash'}));
      assert.equal(response.status,status);assert.equal(response.headers.get('Cache-Control'),'no-store');
      assert.equal((await response.text()).includes('private-marker'),false);
    }
    for(result of [null,{},[],{classification:'PROVISIONAL_CREATED',request:{}}])assert.equal((await run(request({action:'create',capability,paymentMethod:'cash'}))).status,503);
    assert.equal(calls,9,'No automatic transport retry');
    assert.equal((await run(request({action:'lookup',capability,requestId:snapshot.id}))).status,400);
    for(const body of ['{','x'.repeat(3000)]) {
      const invalid=new Request('https://edge.example.test',{method:'POST',headers:{Origin:origin,'Content-Type':'application/json'},body});
      assert.equal((await run(invalid)).status,400);
    }
    assert.equal(calls,9);
  } finally {globalThis.Deno=oldDeno;globalThis.fetch=oldFetch;}
});
test('recovery canonical input rejects noncanonical trailing bits',()=>{
  assert.equal(parseRecoveryInput({action:'lookup',capability:'A'.repeat(42)+'B'}),null);
});
test('capability digest matches independently derived domain-separated bytes',async()=>{
  const expected=createHash('sha256').update(Buffer.concat([Buffer.from('gymforce:walkin-recovery:v1\0'),Buffer.alloc(32)])).digest('hex');
  assert.equal(await capabilityDigest(capability),'\\x'+expected);
});
test('B1 source exception is hash-scoped and does not permit arbitrary persistence',async()=>{
  const manifest=JSON.parse(await readFile(new URL('../supabase/recovery/phase61/source-manifest.json',import.meta.url),'utf8'));
  const expected=manifest.files.find(row=>row.file==='src/lib/walkin-recovery-store.ts').sha256;
  const text=await readFile(new URL('../src/lib/walkin-recovery-store.ts',import.meta.url),'utf8');
  assert.ok(checkBrowserSource(text).includes('browser-persistence-requires-review'));
  assert.deepEqual(checkReviewedRecoveryStorage(text,expected),[]);
  assert.deepEqual(checkReviewedRecoveryStorage(text.replaceAll('\n','\r\n'),expected),[]);
  assert.ok(checkReviewedRecoveryStorage(text+'\nlocalStorage.setItem("member",input)',expected).includes('browser-recovery-storage-fingerprint'));
});
