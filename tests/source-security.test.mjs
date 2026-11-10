import test from 'node:test';
import assert from 'node:assert/strict';
import {
  checkBrowserSource, checkConfig, checkOwnerHandler, checkPwaSource,
} from '../scripts/check-source-security.mjs';

const config = `[api]
schemas = ["public", "graphql_public", "api"]
auto_expose_new_tables = false
[auth]
enable_signup = false
enable_anonymous_sign_ins = false
[auth.email]
enable_signup = false
[auth.sms]
enable_signup = false
`;

test('supported local config explicitly denies account creation and table auto exposure', () => {
  assert.deepEqual(checkConfig(config), []);
  assert.deepEqual(checkConfig(config.replace('"public", "graphql_public", "api"', '"api", "public", "graphql_public"')), []);
});

for (const [name, mutate, rule] of [
  ['private API schema', (s) => s.replace('"api"]', '"api", "private"]'), 'config-api-schema-allowlist'],
  ['missing schema allowlist', (s) => s.replace(/^schemas.*\n/m, ''), 'config-api-schema-allowlist'],
  ['malformed allowlist', (s) => s.replace('schemas = [', 'schemas = [' + "'private',"), 'config-api-schema-allowlist'],
  ['duplicate allowlist', (s) => s.replace('[auth]', 'schemas = ["public", "graphql_public", "api"]\n[auth]'), 'config-setting-duplicate'],
  ['duplicate API section', (s) => s + '[api]\n', 'config-section-unsupported-or-duplicate'],
  ['quoted unsupported section', (s) => s.replace('[api]', '["api"]'), 'config-section-unsupported-or-duplicate'],
  ['automatic table exposure', (s) => s.replace('auto_expose_new_tables = false', 'auto_expose_new_tables = true'), 'config-auto-exposure'],
  ['anonymous signin', (s) => s.replace('enable_anonymous_sign_ins = false', 'enable_anonymous_sign_ins = true'), 'config-anonymous-signin'],
  ['comment is not signup setting', (s) => s.replace('enable_signup = false', '# enable_signup = false'), 'config-signup:auth'],
  ...['auth', 'auth.email', 'auth.sms'].map((section) => [
    `${section} signup enabled`,
    (s) => s.replace(`[${section}]\nenable_signup = false`, `[${section}]\nenable_signup = true`),
    `config-signup:${section}`,
  ]),
]) {
  test(`rejects ${name}`, () => assert.ok(checkConfig(mutate(config)).includes(rule)));
}

test('browser public configuration and secret-detection guard strings are allowed', () => {
  assert.deepEqual(checkBrowserSource("const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY; key.startsWith('sb_secret_');"), []);
});

for (const [name, source, rule] of [
  ['service env', 'import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY', 'browser-privileged-environment-name'],
  ['computed secret env', 'import.meta.env["VITE_SECRET_KEY"]', 'browser-privileged-environment-name'],
  ['secret key literal', 'const key = "sb_secret_synthetic_test_only"', 'browser-secret-key-literal'],
  ['signup', 'client.auth.signUp({})', 'browser-public-account-creation'],
  ['anonymous signin', 'client.auth.signInAnonymously()', 'browser-public-account-creation'],
  ['private schema', 'client.schema("private").from("members")', 'browser-private-schema'],
  ['local storage', 'localStorage.setItem("member", input)', 'browser-persistence-requires-review'],
  ['indexedDB', 'indexedDB.open("members")', 'browser-persistence-requires-review'],
  ['cache storage', 'caches["open"]("member-data")', 'browser-persistence-requires-review'],
]) {
  test(`browser flags ${name}`, () => assert.ok(checkBrowserSource(source).includes(rule)));
}

test('service-role JWT rejected while ordinary anon JWT is not flagged', () => {
  const jwt = (role) => `eyJhbGciOiJIUzI1NiJ9.${Buffer.from(JSON.stringify({ role })).toString('base64url')}.synthetic_signature`;
  assert.ok(checkBrowserSource(`const key = '${jwt('service_role')}'`).includes('browser-service-role-jwt-literal'));
  assert.deepEqual(checkBrowserSource(`const key = '${jwt('anon')}'`), []);
});

test('shell-only PWA allowed; runtime caches and custom worker settings require review', () => {
  assert.deepEqual(checkPwaSource('VitePWA({ registerType: "prompt" })'), []);
  for (const setting of ['runtimeCaching: []', 'additionalManifestEntries: []', 'strategies: "injectManifest"', 'swSrc: "worker.ts"', 'manifestTransforms: []', 'importScripts: []']) {
    assert.deepEqual(checkPwaSource(`VitePWA({ ${setting} })`), ['pwa-custom-caching-requires-review']);
  }
});

test('Owner structural gate flags deleted Auth call and request-derived actor', () => {
  const safeShape = 'const authData = await authClient.auth.getUser(token); rpc({ p_actor_user_id: authData.user.id });';
  assert.deepEqual(checkOwnerHandler(safeShape), []);
  assert.ok(checkOwnerHandler(safeShape.replace('auth.getUser', 'auth.getSession')).includes('owner-auth-validation-marker-missing'));
  assert.ok(checkOwnerHandler(safeShape.replace('authData.user.id', 'body.actorUserId')).includes('owner-actor-wiring-requires-review'));
  assert.ok(checkOwnerHandler('authClient.auth.getUser(token)').includes('owner-actor-wiring-marker-missing'));
});

test('registration adapter exception is explicit and does not allow arbitrary actor expressions', () => {
  const adapter = 'authClient.auth.getUser(token); rpc({ p_actor_user_id: input.actorUserId });';
  assert.ok(checkOwnerHandler(adapter).includes('owner-actor-wiring-requires-review'));
  assert.deepEqual(checkOwnerHandler(adapter, { registrationService: true }), []);
  assert.ok(checkOwnerHandler(adapter.replace('input.actorUserId', 'body.actorUserId'), { registrationService: true }).includes('owner-actor-wiring-requires-review'));
});
