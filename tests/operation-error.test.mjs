import test from 'node:test';
import assert from 'node:assert/strict';
import { operationWasRejected } from '../src/lib/operation-error.ts';
test('uncertain transport/server failures preserve the same operation ID and payload', () => {
  for (const error of [null, Error('network'), { context: new Response('', {status:503}) }, { context: {status:409} }]) assert.equal(operationWasRejected(error), false);
  assert.equal(operationWasRejected({ context: new Response('', {status:409}) }), true);
  assert.equal(operationWasRejected({ context: new Response('', {status:403}) }), true);
});
