import test from 'node:test';
import assert from 'node:assert/strict';
import { functionErrorMessage } from '../src/lib/function-error.ts';

test('function failures show safe actionable status messages without private response bodies', async () => {
  for (const [status, expected] of [[401, 'session'], [403, 'Access was denied'], [404, 'deployment'], [429, 'Too many'], [500, 'backend'], [503, 'backend']]) {
    const message = await functionErrorMessage({ context: new Response('private SQL and member details', { status }) }, 'fallback');
    assert.ok(message.includes(expected), `${status}: ${message}`);
    assert.equal(message.includes('private'), false);
  }
  for (const error of [Error('private failure'), null, { context: { status: 401 } }, { context: new Response('', { status: 400 }) }]) {
    assert.equal(await functionErrorMessage(error, 'safe fallback'), 'safe fallback');
  }
});
