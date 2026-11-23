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
  PUBLIC_WALKIN_ENABLED: 'true', WALKIN_REQUEST_LIMIT_PER_MINUTE: '5',
};
let generation = 0;

async function loadHandler(name, env) {
  const file = new URL(`../supabase/functions/${name}/index.ts`, import.meta.url);
  let handler;
  globalThis.Deno = { env: { get: (key) => env[key] }, serve: (optionsOrCallback, callback) => { if (typeof optionsOrCallback === 'function') { assert.equal(callback, undefined); handler = optionsOrCallback; } else { assert.equal(typeof optionsOrCallback, 'object'); assert.ok(Number.isInteger(optionsOrCallback.port) && optionsOrCallback.port > 0 && optionsOrCallback.port <= 65535, 'Invalid Deno HTTP port'); handler = callback; } assert.equal(typeof handler, 'function', 'Deno.serve requires a request handler'); } };
  let source = stripTypeScriptTypes(await readFile(file, 'utf8'));
  source = source.replace(/from\s+(["'])([^"']+)\1/g, (_match, _quote, specifier) => {
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

test('owner-status grants only verified active owners and fails closed', async () => {
  const originalDeno = globalThis.Deno;
  const originalFetch = globalThis.fetch;
  let authorized = true;
  let authValid = true;
  let malformed = false;
  let rpcCalls = 0;
  globalThis.fetch = async (input, init) => {
    const url = new URL(typeof input === 'string' ? input : input.url ?? input.href);
    assert.equal(url.origin, baseEnv.SUPABASE_URL);
    if (url.pathname === '/auth/v1/user')
      return Response.json(authValid ? { id: actor } : { message: 'invalid session' }, { status: authValid ? 200 : 401 });
    assert.equal(url.pathname, '/rest/v1/rpc/is_active_owner_for_user');
    assert.equal(new Headers(init.headers).get('Content-Profile'), 'api');
    assert.equal(new Headers(init.headers).get('apikey'), baseEnv.SUPABASE_SERVICE_ROLE_KEY);
    assert.deepEqual(JSON.parse(init.body), { p_user_id: actor });
    rpcCalls++;
    return Response.json(malformed ? { unexpected: true } : authorized);
  };
  try {
    const handler = await loadHandler('owner-status', baseEnv);
    assert.equal((await handler(request({}, { method: 'OPTIONS' }))).status, 204);
    assert.equal((await handler(request({}, { origin: 'https://untrusted.example.test' }))).status, 403);
    assert.equal((await handler(request({}, { method: 'GET' }))).status, 405);
    assert.equal(rpcCalls, 0, 'Preflight, foreign origins and wrong methods must not reach authorization RPC');
    const unconfigured = await loadHandler('owner-status', { APP_ORIGIN: origin });
    assert.equal((await unconfigured(request({}))).status, 503);
    assert.equal(rpcCalls, 0, 'Missing backend configuration must fail closed');
    assert.equal((await handler(request({}, { auth: false }))).status, 401);
    assert.equal(rpcCalls, 0);
    authValid = false;
    assert.equal((await handler(request({}))).status, 401);
    assert.equal(rpcCalls, 0);
    authValid = true;
    authorized = false;
    const denied = await handler(request({}));
    assert.equal(denied.status, 200);
    assert.deepEqual(await denied.json(), { authenticated: true, isActiveOwner: false, authorizationReady: true });
    authorized = true;
    const allowed = await handler(request({}));
    assert.equal(allowed.status, 200);
    assert.deepEqual(await allowed.json(), { authenticated: true, isActiveOwner: true, authorizationReady: true });
    malformed = true;
    const unavailable = await handler(request({}));
    assert.equal(unavailable.status, 503);
    assert.equal((await unavailable.text()).includes('unexpected'), false);
    assert.equal(unavailable.headers.get('Cache-Control'), 'no-store');
  } finally {
    globalThis.fetch = originalFetch;
    if (originalDeno === undefined) delete globalThis.Deno;
    else globalThis.Deno = originalDeno;
  }
});

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
    const created = await publicHandler(request({ paymentMethod: 'cash' }, { auth: false }));
    assert.equal(created.status, 200);
    const data = await created.json();
    assert.equal(data.request.privateField, undefined);
    assert.deepEqual(calls.at(-1), { rpc: 'public_create_walkin_request', args: { p_payment_method: 'cash', p_request_limit: 5 } });
    rpcError = { code: 'P0001', message: 'WALKIN_RATE_LIMITED' };
    assert.equal((await publicHandler(request({ paymentMethod: 'cash' }))).status, 429);
  } finally {
    globalThis.fetch = originalFetch;
    if (originalDeno === undefined) delete globalThis.Deno; else globalThis.Deno = originalDeno;
  }
});
