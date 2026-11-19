import test from 'node:test';
import assert from 'node:assert/strict';
import {readIngressBody} from '../supabase/functions/_shared/walkin-ingress.ts';
const make=body=>new Request('http://127.0.0.1',{method:'POST',headers:{'Content-Type':'application/json'},body});
test('actual ingress reader bounds streamed bytes, encoding and UTF-8',async()=>{
 for(const n of [2047,2048])assert.deepEqual(await readIngressBody(make('{}'+' '.repeat(n-2)),new AbortController().signal),{});
 for(const body of ['{}'+' '.repeat(2047),'{',new Uint8Array([0xff])])await assert.rejects(readIngressBody(make(body),new AbortController().signal));
 const compressed=make('{}');compressed.headers.set('Content-Encoding','gzip');await assert.rejects(readIngressBody(compressed,new AbortController().signal));
 const lying=make('{}');lying.headers.set('Content-Length','2049');await assert.rejects(readIngressBody(lying,new AbortController().signal));
});
test('actual slow-body cancellation is bounded and cancels the reader',async()=>{
 let cancelled=false;
 const body=new ReadableStream({cancel(){cancelled=true;}});
 const request=new Request('http://127.0.0.1',{method:'POST',headers:{'Content-Type':'application/json'},body,duplex:'half'});
 await assert.rejects(readIngressBody(request,AbortSignal.timeout(30)),{name:'AbortError'});
 assert.equal(cancelled,true);
});

test('early rejection attempts cancellation without awaiting failing or stalled cleanup',async()=>{
 for(const headers of [{'Content-Length':'2049'},{'Content-Length':'invalid'},{'Content-Encoding':'gzip'},{'Content-Type':'text/plain'}]) {
  let calls=0;
  const body=new ReadableStream({cancel(){calls++;return Promise.reject(new Error('cleanup unavailable'));}});
  const r=new Request('http://127.0.0.1',{method:'POST',headers:{'Content-Type':'application/json',...headers},body,duplex:'half'});
  await assert.rejects(readIngressBody(r,new AbortController().signal),{message:'INVALID_REQUEST'});
  assert.equal(calls,1);
 }
 const stalled=new Request('http://127.0.0.1',{method:'POST',headers:{'Content-Type':'text/plain'},body:new ReadableStream({cancel(){return new Promise(()=>{});}}),duplex:'half'});
 await assert.rejects(readIngressBody(stalled,new AbortController().signal),{message:'INVALID_REQUEST'});
});
test('locked, consumed and absent bodies reject safely',async()=>{
 const locked=make('{}');const held=locked.body.getReader();
 await assert.rejects(readIngressBody(locked,new AbortController().signal),{message:'INVALID_REQUEST'});
 held.releaseLock();await locked.body.cancel();
 const used=make('{}');await used.text();await assert.rejects(readIngressBody(used,new AbortController().signal));
 const empty=new Request('http://127.0.0.1',{method:'POST',headers:{'Content-Type':'application/json'}});
 await assert.rejects(readIngressBody(empty,new AbortController().signal),{message:'INVALID_REQUEST'});
});
