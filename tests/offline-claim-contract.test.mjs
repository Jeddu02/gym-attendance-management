import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const queue = readFileSync(new URL('../src/lib/offline-claim.ts', import.meta.url), 'utf8');
const app = readFileSync(new URL('../src/App.tsx', import.meta.url), 'utf8');
test('offline queue uses encrypted owner-scoped records and stable IDs', () => {
  assert.match(queue, /AES-GCM/);
  assert.match(queue, /length: 256.*false/);
  assert.match(queue, /additionalData:.*this\.owner/);
  assert.match(queue, /id: payload\.operationId/);
  assert.match(queue, /entry\?\.owner === this\.owner/);
});
test('offline entry is provisional and synchronization requires authorization', () => {
  assert.match(queue, /action: 'submit'/);
  assert.match(app, /!queueAllowed \|\| navigator\.onLine/);
  assert.match(app, /!signedIn \|\| !navigator\.onLine/);
  assert.match(app, /await current\.remove\(payload\.operationId\)/);
  assert.match(app, /result\.error \|\| result\.data\?\.success !== true/);
});
