// Executes the real handler source with the installed SDK and synthetic HTTP.
// This is a Node adapter, not certification of hosted Deno/JWT/PostgREST behavior.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';

const origin = 'https://gym.example.test';
const actor = '91000000-0000-4000-8000-000000000002';
const baseEnv = {
  APP_ORIGIN: origin, SUPABASE_URL: 'https://backend.example.test',
  SUPABASE_ANON_KEY: 'synthetic-public-key', SUPABASE_SERVICE_ROLE_KEY: 'synthetic-server-key',
  PUBLIC_WALKIN_ENABLED: 'true', WALKIN_REQUEST_LIMIT_PER_MINUTE: '5', TURNSTILE_SECRET_KEY: 'synthetic-turnstile-secret',
};
let generation = 0;

async function loadHandler(name, env) {
  const file = new URL(`../supabase/functions/${name}/index.ts`, import.meta.url);
  let handler;
  globalThis.Deno = { env: { get: (key) => env[key] }, serve: (callback) => { handler = callback; } };
  let source = stripTypeScriptTypes(await readFile(file, 'utf8'));
  source = source.replace(/from\s+(["'])([^"']+)\1/g, (_match, _quote, specifier) => {
    // This check-in boundary test stops before any password work. A sentinel makes
    // accidental KDF invocation observable without resolving Deno's npm: import.
    if (name === 'member-checkin' && specifier === '../_shared/pin-password.ts') {
      const sentinel = 'export async function verifyMemberPin(){globalThis.checkinKdfCalls++;throw Error("UNEXPECTED_KDF");}';
      return 'from ' + JSON.stringify('data:text/javascript;base64,' + Buffer.from(sentinel).toString('base64'));
    }
    const target = specifier.startsWith('npm:')
      ? import.meta.resolve('@supabase/supabase-js') : new URL(specifier, file).href;
    return `from ${JSON.stringify(target)}`;
  });
  await import(`data:text/javascript;base64,${Buffer.from(source + `\n// test generation ${++generation}`).toString('base64')}`);
  assert.equal(typeof handler, 'function');
  return handler;
}

function request(body, options = {}) {
  return new Request('https://edge.example.test', {
    method: options.method ?? 'POST',
    headers: { Origin: options.origin ?? origin, 'Content-Type': 'application/json',
      ...(options.auth === false ? {} : { Authorization: 'Bearer synthetic-owner-token' }) },
    ...(options.method === 'OPTIONS' ? {} : { body: JSON.stringify(body) }),
  });
}

test('A05 Owner lists preserve arrays and reject malformed RPC successes without details', async () => {
  const originalDeno = globalThis.Deno;
  const originalFetch = globalThis.fetch;
  let result;
  let rpcError = null;
  let authValid = true;
  let rpcCalls = 0;
  globalThis.fetch = async (input, init) => {
    const url = new URL(typeof input === 'string' ? input : input.url ?? input.href);
    assert.equal(url.origin, baseEnv.SUPABASE_URL, 'No external network allowed');
    if (url.pathname === '/auth/v1/user') return Response.json(authValid ? { id: actor } : { message: 'synthetic denial' }, { status: authValid ? 200 : 401 });
    assert.ok(url.pathname.startsWith('/rest/v1/rpc/'));
    assert.equal(new Headers(init.headers).get('Content-Profile'), 'api');
    assert.equal(JSON.parse(init.body).p_actor_user_id, actor);
    rpcCalls++;
    return Response.json(rpcError ?? result, { status: rpcError ? 400 : 200 });
  };
  try {
    for (const [name, key, row] of [
      ['owner-list-members', 'members', { id: actor, memberCode: 'MBR-ABCDEF123456', fullName: 'Synthetic member', status: 'pending', createdAt: '2026-11-16T00:00:00Z' }],
      ['owner-list-membership-plans', 'plans', { id: actor, name: 'Synthetic monthly', pricePhp: '350.00', isActive: true }],
      ['owner-list-membership-purchases', 'purchases', { id: actor, memberName: 'Synthetic member', purchaseStatus: 'pending_payment', pricePhp: '350.00' }],
    ]) {
      const handler = await loadHandler(name, baseEnv);
      for (const valid of [[], [row]]) {
        result = valid;
        const response = await handler(request({}));
        assert.equal(response.status, 200, `${name}: legitimate array rejected`);
        assert.deepEqual((await response.json())[key], valid);
        assert.equal(response.headers.get('Cache-Control'), 'no-store');
      }
      for (const malformed of [{ privateMarker: 'synthetic-private-detail' }, { [key]: [] }, null, 'synthetic-private-detail', 42, true, false]) {
        result = malformed;
        const response = await handler(request({}));
        assert.equal(response.status, 503, `${name}: malformed RPC success accepted`);
        assert.deepEqual(await response.json(), { error: 'SERVICE_UNAVAILABLE' });
        assert.equal(response.headers.get('Cache-Control'), 'no-store');
      }
      rpcError = { code: '42501', message: 'synthetic-private-detail' };
      const forbidden = await handler(request({}));
      assert.equal(forbidden.status, 403, `${name}: SQL Owner restriction lost`);
      assert.equal((await forbidden.text()).includes('synthetic-private-detail'), false);
      rpcError = null;
      const previous = rpcCalls;
      assert.equal((await handler(request({}, { auth: false }))).status, 401);
      authValid = false;
      assert.equal((await handler(request({}))).status, 401);
      authValid = true;
      assert.equal(rpcCalls, previous, 'Invalid/missing Auth reached RPC');
    }
  } finally {
    globalThis.fetch = originalFetch;
    if (originalDeno === undefined) delete globalThis.Deno;
    else globalThis.Deno = originalDeno;
  }
});

test('payment and walk-in handlers preserve CORS, verified actors, RPC boundaries and safe failures', async () => {
  const originalDeno = globalThis.Deno;
  const originalFetch = globalThis.fetch;
  let calls = [];
  let rpcResult = [];
  let rpcError = null;
  let authValid = true;
  globalThis.fetch = async (input, init) => {
    const url = new URL(typeof input === 'string' ? input : input.url ?? input.href);
    if (url.href === 'https://challenges.cloudflare.com/turnstile/v0/siteverify') {
      assert.equal(JSON.parse(init.body).secret, 'synthetic-turnstile-secret');
      return Response.json({success: JSON.parse(init.body).response === 'synthetic-turnstile-token', hostname: 'gym.example.test', action: 'walkin_request'});
    }
    assert.equal(url.origin, 'https://backend.example.test', 'No external network allowed');
    if (url.pathname === '/auth/v1/user') {
      calls.push({ auth: true });
      return Response.json(authValid ? { id: actor } : { message: 'invalid token' }, { status: authValid ? 200 : 401 });
    }
    assert.ok(url.pathname.startsWith('/rest/v1/rpc/'));
    const headers = new Headers(init?.headers);
    assert.equal(headers.get('Content-Profile'), 'api');
    assert.equal(headers.get('apikey'), baseEnv.SUPABASE_SERVICE_ROLE_KEY);
    calls.push({ rpc: url.pathname.split('/').at(-1), args: JSON.parse(init.body) });
    return Response.json(rpcError ?? rpcResult, { status: rpcError ? 400 : 200 });
  };
  try {
    for (const name of ['owner-membership-payments', 'owner-walkins', 'public-walkin-request']) {
      const disabled = await loadHandler(name, { APP_ORIGIN: origin });
      assert.equal((await disabled(request(null, { method: 'OPTIONS' }))).status, 204, `${name}: preflight without backend configuration`);
      assert.equal((await disabled(request({}, { origin: 'https://untrusted.example.test', method: 'OPTIONS' }))).status, 403);
      assert.equal((await disabled(request({}))).status, 503, 'No release switch or secret bypass');
      assert.equal(calls.length, 0);
    }
    for (const [name, rpc, result] of [
      ['owner-membership-payments', 'owner_list_membership_payments', { payments: [], payablePurchases: [] }],
      ['owner-walkins', 'owner_list_walkin_requests', []],
    ]) {
      const handler = await loadHandler(name, baseEnv);
      assert.equal((await handler(request({ action: 'list' }, { auth: false }))).status, 401);
      assert.equal(calls.length, 0);
      rpcResult = result;
      const response = await handler(request({ action: 'list' }));
      assert.equal(response.status, 200);
      assert.equal(response.headers.get('Cache-Control'), 'no-store');
      assert.equal((await response.json()).success, true);
      assert.equal(calls.at(-1).rpc, rpc);
      assert.equal(calls.at(-1).args.p_actor_user_id, actor);
      calls = [];
      authValid = false;
      assert.equal((await handler(request({ action: 'list' }))).status, 401);
      assert.equal(calls.some((call) => call.rpc), false);
      authValid = true;
      rpcError = { code: '42501', message: 'private details' };
      const forbidden = await handler(request({ action: 'list' }));
      assert.equal(forbidden.status, 403);
      assert.equal((await forbidden.text()).includes('private details'), false);
      rpcError = null;
      calls = [];
    }
    const publicHandler = await loadHandler('public-walkin-request', baseEnv);
    assert.equal((await publicHandler(request({ paymentMethod: 'cash', feePhp: '1' }))).status, 400);
    assert.equal(calls.length, 0);
    rpcResult = { id: '91000000-0000-4000-8000-000000000003', feePhp: '100.00', currency: 'PHP', paymentMethod: 'cash', createdAt: '2026-11-11T02:00:00Z', expiresAt: '2026-11-11T02:15:00Z', privateField: 'never expose' };
    assert.equal((await publicHandler(request({ paymentMethod: 'cash' }, { auth: false }))).status, 400);
    assert.equal(calls.length, 0);
    const created = await publicHandler(request({ paymentMethod: 'cash', turnstileToken: 'synthetic-turnstile-token' }, { auth: false }));
    assert.equal(created.status, 200);
    const data = await created.json();
    assert.equal(data.request.privateField, undefined);
    assert.deepEqual(calls.at(-1), { rpc: 'public_create_walkin_request', args: { p_payment_method: 'cash', p_request_limit: 5 } });
    rpcError = { code: 'P0001', message: 'WALKIN_RATE_LIMITED' };
    assert.equal((await publicHandler(request({ paymentMethod: 'cash', turnstileToken: 'synthetic-turnstile-token' }))).status, 429);
  } finally {
    globalThis.fetch = originalFetch;
    if (originalDeno === undefined) delete globalThis.Deno; else globalThis.Deno = originalDeno;
  }
});


test('hosted member check-in verifies challenge before any database or KDF work', async () => {
  const originalDeno = globalThis.Deno;
  const originalFetch = globalThis.fetch;
  const oldKdfCalls = globalThis.checkinKdfCalls;
  globalThis.checkinKdfCalls = 0;
  const key = Buffer.alloc(32, 17).toString('base64');
  // Synthetic format-valid verifier; no password verification occurs in this test.
  const dummy = '$argon2id$v=19$m=65536,t=3,p=1$' + Buffer.alloc(16, 3).toString('base64').replace(/=+$/, '') + '$' + key.replace(/=+$/, '');
  const env = {
    ...baseEnv, PUBLIC_MEMBER_CHECKIN_ENABLED: 'true',
    PUBLIC_CHECKIN_LOOKUP_HMAC_KEY_B64: key,
    MEMBER_MOBILE_HMAC_KEY_B64: Buffer.alloc(32, 19).toString('base64'),
    DUMMY_PIN_HASH: dummy, CHECKIN_GLOBAL_LIMIT_PER_MINUTE: '30',
    CHECKIN_IDENTIFIER_LIMIT_PER_MINUTE: '5',
  };
  const input = { identifier: 'MBR-ABCDEF123456', pin: '123456' };
  const success = { success: true, hostname: 'gym.example.test', action: 'member_checkin' };
  let provider = success;
  let failProvider = false;
  let order = [];
  globalThis.fetch = async (input, init) => {
    const url = new URL(typeof input === 'string' ? input : input.url ?? input.href);
    if (url.href === 'https://challenges.cloudflare.com/turnstile/v0/siteverify') {
      order.push('verify');
      assert.deepEqual(JSON.parse(init.body), { secret: env.TURNSTILE_SECRET_KEY, response: 'synthetic-token' });
      if (failProvider) throw new Error('synthetic transport failure');
      return Response.json(provider);
    }
    assert.equal(url.origin, env.SUPABASE_URL);
    assert.equal(url.pathname, '/rest/v1/rpc/reserve_member_checkin_request');
    order.push('reserve');
    const args = JSON.parse(init.body);
    assert.match(args.p_identifier_digest, /^[0-9a-f]{64}$/);
    assert.equal(args.p_global_limit, 30);
    assert.equal(args.p_identifier_limit, 5);
    return Response.json({ allowed: false, retryAfterSeconds: 5 });
  };
  try {
    const handler = await loadHandler('member-checkin', env);
    const valid = { ...input, turnstileToken: 'synthetic-token' };
    const verifyOutcome = async (handler, body, status, expectedOrder, options = {}) => {
      order = [];
      const response = await handler(request(body, { auth: false, ...options }));
      assert.equal(response.status, status);
      assert.deepEqual(order, expectedOrder);
      assert.equal(globalThis.checkinKdfCalls, 0);
      if (status !== 403) assert.deepEqual(await response.json(), { success: false, message: 'CHECKIN_UNAVAILABLE' });
      return response;
    };
    await verifyOutcome(handler, input, 400, []);
    await verifyOutcome(handler, { ...valid, pin: 'abc' }, 400, []);
    await verifyOutcome(handler, { ...valid, unexpected: true }, 400, []);
    await verifyOutcome(handler, { ...valid, turnstileToken: 'a'.repeat(2049) }, 400, []);
    await verifyOutcome(handler, valid, 403, [], { origin: 'https://untrusted.example.test' });
    for (const denial of [
      { success: false, 'error-codes': ['timeout-or-duplicate'] },
      { ...success, hostname: 'untrusted.example.test' },
      { ...success, action: 'walkin_request' },
    ]) {
      provider = denial;
      await verifyOutcome(handler, valid, 400, ['verify']);
    }
    provider = {};
    await verifyOutcome(handler, valid, 503, ['verify']);
    provider = success;
    failProvider = true;
    await verifyOutcome(handler, valid, 503, ['verify']);
    failProvider = false;
    const missing = await loadHandler('member-checkin', { ...env, TURNSTILE_SECRET_KEY: undefined });
    await verifyOutcome(missing, valid, 503, []);
    const disabled = await loadHandler('member-checkin', { ...env, PUBLIC_MEMBER_CHECKIN_ENABLED: 'false' });
    await verifyOutcome(disabled, valid, 503, []);
    const limited = await verifyOutcome(handler, valid, 429, ['verify', 'reserve']);
    assert.equal(limited.headers.get('Retry-After'), '5');
    // Simulate the provider rejecting reuse of the previously consumed token.
    provider = { success: false, 'error-codes': ['timeout-or-duplicate'] };
    await verifyOutcome(handler, valid, 400, ['verify']);
  } finally {
    globalThis.fetch = originalFetch;
    if (originalDeno === undefined) delete globalThis.Deno; else globalThis.Deno = originalDeno;
    if (oldKdfCalls === undefined) delete globalThis.checkinKdfCalls; else globalThis.checkinKdfCalls = oldKdfCalls;
  }
});
