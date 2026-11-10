import test from 'node:test';
import assert from 'node:assert/strict';
import { formatPhp } from '../src/lib/money.ts';
test('PHP aggregates preserve exact cents beyond safe integer precision', () => {
  assert.equal(formatPhp('9007199254740993.51'), '₱9,007,199,254,740,993.51');
  assert.equal(formatPhp('0'), '₱0.00');
  assert.equal(formatPhp('-12.5'), '-₱12.50');
  for (const input of [Infinity, 9007199254740992, '1e2', '12.001', 'NaN']) assert.throws(() => formatPhp(input));
});
