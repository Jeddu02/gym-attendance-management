import test from 'node:test';
import assert from 'node:assert/strict';
import { privatePinToken, parseWalkinRequest } from '../src/lib/public-entry-contract.ts';
import { parseMemberPinResetInput } from '../supabase/functions/_shared/pin-recovery.ts';
import { createPinEnrollmentToken } from '../supabase/functions/_shared/pin-enrollment.ts';
import { parsePositiveWalkinPhp } from '../supabase/functions/_shared/walkin-request.ts';

test('reset fragment validation agrees with the actual server parser at token-length boundaries', () => {
  for (const size of [0, 39, 40, 42, 43, 44, 128, 129]) {
    const token = 'A'.repeat(size);
    assert.equal(Boolean(privatePinToken('#token=' + token, 'reset')),
      Boolean(parseMemberPinResetInput({ token, pin: '123456' })));
  }
  for (const token of ['A'.repeat(42) + '+', 'A'.repeat(42) + '/', 'A'.repeat(42) + '=']) {
    assert.equal(privatePinToken('#token=' + encodeURIComponent(token), 'reset'), '');
  }
});

test('server-generated private tokens remain usable for both purposes', async () => {
  const { rawToken } = await createPinEnrollmentToken();
  assert.equal(rawToken.length, 43);
  for (const purpose of ['enrollment', 'reset']) assert.equal(privatePinToken('#token=' + rawToken, purpose), rawToken);
});

test('enrollment retains its existing length contract and ignores unrelated fragment keys', () => {
  for (const size of [39, 40, 43, 128, 129]) {
    assert.equal(Boolean(privatePinToken('#token=' + 'A'.repeat(size), 'enrollment')), size >= 40 && size <= 128);
  }
  assert.equal(privatePinToken('#other=value', 'enrollment'), '');
});

const request = {
  id: '91000000-0000-4000-8000-000000000001', feePhp: '100.00', currency: 'PHP',
  paymentMethod: 'cash', createdAt: '2026-11-19T01:00:00+00:00', expiresAt: '2026-11-19T01:15:00+00:00',
};
test('walk-in snapshots accept every approved method and exact positive cent amounts', () => {
  for (const paymentMethod of ['cash', 'gcash', 'bank_transfer']) {
    for (const feePhp of ['0.01', '100.00', '9999999999.99', 100]) {
      const input = { ...request, paymentMethod, feePhp };
      assert.deepEqual(parseWalkinRequest(input, paymentMethod), input);
    }
  }
  // Old snapshots remain displayable; only the server can decide confirmation/expiry.
  assert.deepEqual(parseWalkinRequest(request, 'cash'), request);
});

test('malformed walk-in responses never become pending payment references', () => {
  const mutations = [
    { id: '' }, { id: 'not-a-server-id' }, { currency: 'USD' }, { paymentMethod: 'gcash' },
    ...[true, false, null, {}, [], '', ' ', '1e2', '0x64', '00.01', '0100', '0', '-1', '1.001', Infinity, NaN, '10000000000'].map(feePhp => ({ feePhp })),
    { createdAt: true }, { expiresAt: null }, { createdAt: '2026' }, { expiresAt: 'invalid' },
    { expiresAt: request.createdAt }, { expiresAt: '2026-11-19T00:59:59Z' },
  ];
  for (const patch of mutations) assert.equal(parseWalkinRequest({ ...request, ...patch }, 'cash'), null);
  for (const value of [null, false, [], 'request']) assert.equal(parseWalkinRequest(value, 'cash'), null);
});

test('walk-in parsing retains only the public snapshot fields', () => {
  assert.deepEqual(parseWalkinRequest({ ...request, unrelated: 'synthetic' }, 'cash'), request);
});

test('frontend walk-in cents contract agrees with the actual server amount parser', () => {
  for (const feePhp of ['0', '0.01', '1', '1.2', '1.23', '01', '1.234', '1e2', '-1', '9999999999.99', '10000000000']) {
    assert.equal(Boolean(parseWalkinRequest({ ...request, feePhp }, 'cash')), Boolean(parsePositiveWalkinPhp(feePhp)));
  }
});
