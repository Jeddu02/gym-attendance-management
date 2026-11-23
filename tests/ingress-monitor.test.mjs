import test from 'node:test';
import assert from 'node:assert/strict';
import { IngressMonitor, localMaintenanceTick } from '../scripts/recovery/ingress-monitor.mjs';
const row = (minute, patch = {}) => ({ minute, attempts: 30, denied: 20, unavailable: 1, timeouts: 5, ...patch });
test('monitor is disabled by default and detects exact aggregate thresholds', async () => {
  const m = new IngressMonitor();
  assert.equal(await m.evaluate([row(10)], 10), 3);
  assert.equal(m.retained, 0);
  assert.equal(await m.evaluate([row(11, { denied: 19, unavailable: 0, timeouts: 4 })], 11), 0);
});
test('explicit local destination deduplicates and expires bounded telemetry', async () => {
  const sent = [], m = new IngressMonitor(a => sent.push(a));
  await m.evaluate([row(10)], 10); await m.evaluate([row(10)], 10);
  assert.equal(sent.length, 3); assert.equal(m.retained, 3);
  assert.deepEqual(Object.keys(sent[0]).sort(), ['count', 'key', 'kind', 'minute']);
  await m.evaluate([], 2890); assert.equal(m.retained, 0);
  await assert.rejects(m.evaluate([], 2889), /CLOCK/);
});
test('failed delivery remains retryable; malformed/private telemetry fails closed', async () => {
  let fail = true, count = 0;
  const m = new IngressMonitor(() => { if (fail) throw Error('synthetic'); count++; });
  await assert.rejects(m.evaluate([row(10)], 10)); assert.equal(m.retained, 0);
  fail = false; await m.evaluate([row(10)], 10); assert.equal(count, 3);
  for (const value of [[row(10, { capability: 'private' })], [row(10, { denied: NaN })], [row(12)], [row(1)], null])
    await assert.rejects(m.evaluate(value, 10), /INPUT/);
});
test('cleanup failure emits only deduplicated health information without RPC retry', async () => {
  let calls = 0; const deliveries = [], monitor = new IngressMonitor(a => deliveries.push(a));
  for (let i=0;i<2;i++) await assert.rejects(localMaintenanceTick(async () => { calls++; return { error: true }; }, monitor, 10), /MAINTENANCE/);
  assert.equal(calls, 2); assert.equal(deliveries.length, 1);
  assert.deepEqual(deliveries[0], { minute: 10, kind: 'maintenance_unavailable', count: 1, key: '10:maintenance_unavailable' });
});
test('delivery journal remains bounded over 48 hours of every alert category',async()=>{
 const m=new IngressMonitor(()=>{});
 for(let minute=1;minute<=2881;minute++){
  await m.evaluate([row(minute)],minute);await m.failure(minute);
  assert.ok(m.retained<=11520);
 }
 assert.equal(m.retained,11520);
 await m.evaluate([],5761);assert.equal(m.retained,0);
});
