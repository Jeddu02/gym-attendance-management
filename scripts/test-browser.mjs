// Local UI smoke tests only. APIs are synthetic CDP fixtures, not Auth/RLS proof.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile, access } from 'node:fs/promises';
import { resolve, isAbsolute } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:net';
import { setTimeout as delay } from 'node:timers/promises';
const root = resolve(import.meta.dirname, '..');
const run = resolve(root, '.cache', `browser-test-${randomUUID()}`);
await mkdir(run, { recursive: true });
const browserPath = process.env.CHROME_PATH ?? (process.platform === 'win32' ? 'C:/Program Files/Google/Chrome/Application/chrome.exe' : '/usr/bin/chromium');
if (!isAbsolute(browserPath)) throw Error('CHROME_PATH must be an absolute executable path');
await access(browserPath);
const reservation = createServer();
await new Promise((done) => reservation.listen(0, '127.0.0.1', done));
const port = reservation.address().port;
await new Promise((done) => reservation.close(done));
const origin = `http://127.0.0.1:${port}`;
const syntheticEnvironment = { ...process.env, VITE_SUPABASE_URL: origin, VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_synthetic_browser_test' };
const production = process.argv.includes('--production');
if (production) {
  const build = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'build', '--outDir', resolve(run, 'dist')], {
    cwd: root, windowsHide: true, stdio: 'ignore', env: syntheticEnvironment,
  });
  const code = await new Promise((done) => build.once('exit', done));
  assert.equal(code, 0, 'Synthetic production build failed');
}
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', ...(production ? ['preview', '--outDir', resolve(run, 'dist')] : []), '--host', '127.0.0.1', '--port', String(port), '--strictPort'], {
  cwd: root, windowsHide: true, stdio: 'ignore', env: syntheticEnvironment,
});
let browser; let socket; let sequence = 0;
const pending = new Map(); const errors = []; const observed = []; let externalAttempts = 0;
let paymentFailure = true; let walkinFailure = true; let publicUnavailable = true;
let ownerStatusCalls = 0; let ownerStatusGate; let ownerStatusDenied = false;
let publicResponsePatch = null; let publicCalls = 0; let resetCalls = 0;
const claimAttempts = [];
const recoverySnapshots = new Map();
let expectedResetToken = 'A'.repeat(43); let resetSuccess = false;
let memberNetworkFailure = false;
let publicNetworkFailure = false;
const unavailableRoutes = new Set(['owner-list-members', 'owner-list-membership-plans', 'owner-list-membership-purchases', 'owner-attendance', 'owner-receipt-review', 'owner-cash', 'owner-attendance-claims']);
async function until(check, description, timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) { if (await check()) return; await delay(100); }
  throw Error(`Timed out: ${description}`);
}
function cdp(method, params = {}, sessionId) {
  const id = ++sequence;
  return new Promise((resolveCall, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(Error(`CDP timeout: ${method}; recent local events: ${observed.slice(-8).join(', ')}`)); }, method === 'Page.navigate' ? 45000 : 15000);
    pending.set(id, { resolve: (value) => { clearTimeout(timer); resolveCall(value); }, reject });
    socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  });
}
async function evaluate(expression) {
  const value = await cdp('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (value.exceptionDetails) throw Error('Browser evaluation failed');
  return value.result.value;
}
async function navigate(path) { await cdp('Page.navigate', { url: origin + path }); }
async function textIncludes(value) { return evaluate(`document.body?.innerText.includes(${JSON.stringify(value)}) ?? false`); }
try {
  await until(async () => { try { return (await fetch(origin, { signal: AbortSignal.timeout(2000) })).ok; } catch { return false; } }, 'local Vite');
  await mkdir(resolve(run, 'profile'), { recursive: true });
  browser = spawn(browserPath, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-background-networking', '--disable-sync', '--disable-extensions', '--disable-component-update', '--remote-debugging-port=0', `--user-data-dir=${resolve(run, 'profile')}`, 'about:blank'], { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
  let startupStderr = '';
  const captureStartup = (chunk) => { startupStderr = (startupStderr + chunk).slice(-8000); };
  browser.stderr.on('data', captureStartup);
  let debugPort;
  try {
    await until(async () => { try { debugPort = Number((await readFile(resolve(run, 'profile/DevToolsActivePort'), 'utf8')).split('\n')[0]); return debugPort > 0; } catch { return false; } }, 'isolated browser');
  } catch (error) {
    // Startup is about:blank; never retain stderr from pages handling private inputs.
    await writeFile(resolve(run, 'browser-startup-error.log'), startupStderr);
    throw error;
  } finally { browser.stderr.off('data', captureStartup); browser.stderr.resume(); }
  const targets = await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();
  const target = targets.find((item) => item.type === 'page');
  assert.ok(target?.webSocketDebuggerUrl.startsWith(`ws://127.0.0.1:${debugPort}/`));
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((done, reject) => { socket.addEventListener('open', done, { once: true }); socket.addEventListener('error', reject, { once: true }); });
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    if (message.method) observed.push(message.method);
    if (message.id) {
      const item = pending.get(message.id); if (!item) return;
      pending.delete(message.id); if (message.error) item.reject(Error('CDP request rejected')); else item.resolve(message.result);
    } else if (message.method === 'Runtime.exceptionThrown') errors.push('Uncaught browser exception');
    else if (message.method === 'Fetch.requestPaused') void handleRequest(message.params, message.sessionId).catch(() => errors.push('Fixture routing failure'));
  });
  async function handleRequest({ requestId, request }, sessionId) {
    const send = (method, params) => cdp(method, params, sessionId);
    const url = new URL(request.url);
    if (url.origin !== origin) { externalAttempts++; await send('Fetch.failRequest', { requestId, errorReason: 'BlockedByClient' }); return; }
    const respond = async (status, body) => send('Fetch.fulfillRequest', { requestId, responseCode: status, responseHeaders: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Cache-Control', value: 'no-store' }], body: Buffer.from(JSON.stringify(body)).toString('base64') });
    if (url.pathname.startsWith('/functions/v1/') && unavailableRoutes.has(url.pathname.split('/').at(-1))) { await respond(503, { error: 'SERVICE_UNAVAILABLE' }); return; }
    if (url.pathname === '/auth/v1/token') {
      const user = { id: '91000000-0000-4000-8000-000000000002', aud: 'authenticated', role: 'authenticated', email: 'owner@example.test', app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() };
      const payload = { sub: user.id, aud: 'authenticated', role: 'authenticated', exp: Math.floor(Date.now()/1000)+3600, iat: Math.floor(Date.now()/1000) };
      const access_token = [ { alg: 'HS256', typ: 'JWT' }, payload ].map((part) => Buffer.from(JSON.stringify(part)).toString('base64url')).join('.') + '.c3ludGhldGlj';
      await respond(200, { access_token, token_type: 'bearer', refresh_token: 'synthetic-refresh-only', expires_in: 3600, user });
    } else if (url.pathname === '/auth/v1/logout') await respond(200, {});
    else if (url.pathname === '/functions/v1/owner-status') {
      ownerStatusCalls++;
      if (ownerStatusGate) await ownerStatusGate;
      await respond(200, { authenticated: true, isActiveOwner: !ownerStatusDenied, authorizationReady: true });
    }
    else if (url.pathname === '/functions/v1/owner-reporting') {
      const { action } = JSON.parse(request.postData);
      if (action === 'audit') { await respond(200, { success: true, events: [] }); return; }
      await respond(200, action === 'income' ? { success: true, income: [] } : action === 'expiry' ? { success: true, expiries: [] } : { success: true, summary: { totalMembers: 0, approvedMembers: 0, currentEntitlements: 0, todayValidCheckins: 0, confirmedMembershipIncomePhp: '0.00', confirmedWalkinIncomePhp: '0.00' } });
    } else if (url.pathname === '/functions/v1/owner-membership-payments') {
      const input = JSON.parse(request.postData);
      if (paymentFailure) { await respond(503, { error: 'SERVICE_UNAVAILABLE' }); return; }
      if (input.action === 'payable') {
        assert.equal(input.limit, 50);
        const purchases = Array.from({length: input.offset === 0 ? 50 : 2}, (_, index) => ({id:`91000000-0000-4000-8000-${(input.offset+index+1).toString(16).padStart(12,'0')}`,memberName:'Synthetic payable member',memberCode:'MBR-ABCDEF123456',planName:'Synthetic monthly',pricePhp:'350.00'}));
        await respond(200, { success: true, purchases });
      } else { assert.equal(input.action, 'list'); await respond(200, { success: true, result: {payments:[],payablePurchases:[]} }); }
    }
    else if (url.pathname === '/functions/v1/owner-list-members') await respond(200, { success: true, members: [] });
    else if (url.pathname === '/functions/v1/owner-list-membership-plans') await respond(200, { success: true, plans: [] });
    else if (url.pathname === '/functions/v1/owner-list-membership-purchases') await respond(200, { success: true, purchases: [] });
    else if (url.pathname === '/functions/v1/owner-walkins') await respond(walkinFailure ? 403 : 200, walkinFailure ? { error: 'OWNER_ACCESS_REQUIRED' } : { success: true, requests: [] });
    else if (url.pathname === '/functions/v1/owner-attendance') await respond(200, { success: true, attendance: [] });
    else if (url.pathname === '/functions/v1/owner-attendance-claims' && JSON.parse(request.postData).action === 'submit') {
      claimAttempts.push(JSON.parse(request.postData));
      if (claimAttempts.length === 1) await respond(503, { error: 'SERVICE_UNAVAILABLE' });
      else if (claimAttempts.length === 2) await respond(200, { success: true });
      else await respond(200, { success: true, result: { id: '91000000-0000-4000-8000-000000000009', provisional: true, replayed: true } });
    }
    else if (['/functions/v1/owner-receipt-review','/functions/v1/owner-cash','/functions/v1/owner-attendance-claims'].includes(url.pathname)) await respond(200, { success: true, result: [] });
    else if (url.pathname === '/functions/v1/member-checkin') {
      const input = JSON.parse(request.postData);
      assert.deepEqual(Object.keys(input).sort(), ['identifier', 'pin']);
      if (memberNetworkFailure) { await send('Fetch.failRequest', { requestId, errorReason: 'ConnectionReset' }); return; }
      await respond(400, { success: false, message: 'CHECKIN_UNAVAILABLE' });
    } else if (url.pathname === '/functions/v1/public-walkin-recovery') {
      const input = JSON.parse(request.postData);
      assert.match(input.capability, /^[A-Za-z0-9_-]{43}$/);
      assert.ok(['create','lookup'].includes(input.action));
      const existing = recoverySnapshots.get(input.capability);
      if (input.action === 'create') {
        publicCalls++;
        assert.deepEqual(Object.keys(input).sort(), ['action','capability','paymentMethod']);
        assert.equal(input.paymentMethod, 'cash');
        if (!existing) recoverySnapshots.set(input.capability, { id: '91000000-0000-4000-8000-000000000001', feePhp: '100.00', currency: 'PHP', paymentMethod: 'cash', createdAt: new Date().toISOString(), expiresAt: new Date(Date.now()+900000).toISOString() });
      } else assert.deepEqual(Object.keys(input).sort(), ['action','capability']);
      if (publicNetworkFailure) { await send('Fetch.failRequest', { requestId, errorReason: 'ConnectionReset' }); return; }
      if (publicUnavailable) { await respond(503, { error: 'REQUEST_UNAVAILABLE' }); return; }
      const snapshot = recoverySnapshots.get(input.capability);
      if (!snapshot) { await respond(404, {error:'NO_RECOVERABLE_OUTCOME'}); return; }
      await respond(existing || input.action === 'lookup' ? 200 : 201, { success: true, classification: existing || input.action === 'lookup' ? 'PROVISIONAL_RECOVERED' : 'PROVISIONAL_CREATED', request: {...snapshot,...publicResponsePatch} });
    } else if (url.pathname === '/functions/v1/member-reset-pin') {
      resetCalls++;
      assert.equal(JSON.parse(request.postData).token, expectedResetToken);
      await respond(resetSuccess ? 200 : 503, resetSuccess ? { success: true } : { error: 'SERVICE_UNAVAILABLE' });
    } else if (url.pathname === '/functions/v1/member-enroll-pin') await respond(503, { error: 'SERVICE_UNAVAILABLE' });
    else if (url.pathname.startsWith('/functions/') || url.pathname.startsWith('/auth/')) await respond(503, { error: 'SYNTHETIC_UNAVAILABLE' });
    else await send('Fetch.continueRequest', { requestId });
  }
  await cdp('Page.enable'); await cdp('Runtime.enable');
  await cdp('Fetch.enable', { patterns: [{ urlPattern: '*' }] });
  await cdp('Emulation.setDeviceMetricsOverride', { width: 375, height: 812, deviceScaleFactor: 1, mobile: true });
  const browserVersion = await cdp('Browser.getVersion');
  await cdp('Emulation.setUserAgentOverride', { userAgent: `Mozilla/5.0 (Linux; Android 14; Synthetic Test Device) AppleWebKit/537.36 (KHTML, like Gecko) ${browserVersion.product.replace('HeadlessChrome', 'Chrome')} Mobile Safari/537.36`, platform: 'Android' });
  await cdp('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
  await navigate('/entrance');
  try {
    await until(() => textIncludes('Member ID or registered mobile number'), 'entrance form', production ? 15000 : 60000);
  } catch (error) {
    // Initial page only: before any identity/PIN/payment entry or Auth fixture.
    await writeFile(resolve(run, 'entrance-startup.json'), JSON.stringify({
      initialPage: await evaluate('({ title: document.title, text: document.body?.innerText.slice(0, 2000), scripts: document.scripts.length, ready: document.readyState, resources: performance.getEntriesByType("resource").map(item=>({path:new URL(item.name).pathname,duration:item.duration})) })'),
      runtimeExceptions: errors.length, externalAttempts,
    }, null, 2));
    console.log(`Initial synthetic page diagnostic retained in .cache/${run.split(/[\\/]/).at(-1)}/entrance-startup.json`);
    throw error;
  }
  if (production) {
    // Prompt-mode workers do not claim the first document. Await activation,
    // then navigate once to become controlled before testing subsequent routes.
    // Final checks still independently verify control and cache contents.
    try {
      await until(() => evaluate(`(async () => (await navigator.serviceWorker.getRegistrations()).some(registration => registration.active?.state === 'activated'))()`), 'initial production shell activation', 45000);
      if (!await evaluate('navigator.serviceWorker.controller !== null')) {
        await navigate('/entrance');
        await until(() => textIncludes('Member ID or registered mobile number'), 'controlled entrance form');
      }
      await until(() => evaluate('navigator.serviceWorker.controller !== null'), 'initial production shell worker');
    } catch (error) {
      console.log('Synthetic worker diagnostic:', await evaluate(`(async () => ({ controlled: !!navigator.serviceWorker.controller, registrations: (await navigator.serviceWorker.getRegistrations()).map(registration => ({ scope: new URL(registration.scope).pathname, installing: registration.installing?.state, waiting: registration.waiting?.state, active: registration.active?.state })) }))()`));
      throw error;
    }
  }
  assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), true);
  assert.equal(await evaluate('document.querySelector("#checkin-pin").type'), 'password');
  await evaluate(`(() => { const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; for (const [id,value] of [['checkin-identifier','MBR-ABCDEF123456'],['checkin-pin','123456']]) { const el=document.getElementById(id); set.call(el,value); el.dispatchEvent(new Event('input',{bubbles:true})); } })()`);
  await evaluate('document.querySelector("#entrance-member-panel form").requestSubmit()');
  await until(() => evaluate('document.querySelector("#checkin-pin").value === ""'), 'PIN cleared after denial');
  memberNetworkFailure = true;
  await evaluate(`(() => { const el=document.getElementById('checkin-pin'); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(el,'123456');el.dispatchEvent(new Event('input',{bubbles:true})); })()`);
  await evaluate('document.querySelector("#entrance-member-panel form").requestSubmit()');
  await until(async () => await textIncludes('Reconnect and retry') && await evaluate('document.querySelector("#checkin-pin").value === "" && !document.querySelector("#entrance-member-panel button[type=submit]").disabled'), 'Interrupted request clears PIN and releases the form');
  memberNetworkFailure = false;
  const touchTarget = await evaluate('(() => { const r=document.getElementById("entrance-walkin-tab").getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2}; })()');
  await cdp('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [touchTarget] });
  await cdp('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await until(() => textIncludes('Request a walk-in visit'), 'walk-in tab');
  await until(()=>evaluate('!document.querySelector("#entrance-walkin-panel button[type=submit]").disabled'),'Recovery storage ready');
  await evaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()');
  async function assertUncertainCreation(previous) {
    await until(async () => publicCalls === previous + 1 && await textIncludes('The request outcome could not be verified.')
      && await evaluate('document.querySelector("#entrance-walkin-panel button[type=submit]").disabled'), 'Uncertain creation blocks another attempt');
    assert.equal(await textIncludes('Awaiting Owner confirmation'), false);
    await evaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit(); document.querySelector("#entrance-walkin-panel form").requestSubmit()');
    await delay(150);
    assert.equal(publicCalls, previous + 1, 'Programmatic repeated submit must not dispatch again');
  }
  async function freshSyntheticWalkinPage() {
    // Test-only fixture reset. Production never clears uncertain operations.
    await evaluate(`new Promise((resolve,reject)=>{ const r=indexedDB.deleteDatabase('gymforce-walkin-recovery-v1'); r.onsuccess=()=>resolve(true); r.onerror=()=>reject(new Error('Synthetic storage reset failed')); })`);
    await navigate('/entrance');
    await until(() => textIncludes('Member ID or registered mobile number'), 'Fresh synthetic document');
    await evaluate('document.getElementById("entrance-walkin-tab").click()');
    await until(() => evaluate('Boolean(document.querySelector("#entrance-walkin-panel button[type=submit]")) && !document.querySelector("#entrance-walkin-panel button[type=submit]").disabled'), 'Fresh synthetic walk-in form/storage');
  }
  await assertUncertainCreation(0);
  assert.equal(await textIncludes('Awaiting Owner confirmation'), false);
  publicUnavailable = false;
  for (const patch of [{ id: '' }, { feePhp: true }, { feePhp: '1.001' }, { paymentMethod: 'gcash' }, { expiresAt: '2000-01-01T00:00:00Z' }]) {
    await freshSyntheticWalkinPage();
    publicResponsePatch = patch;
    const previous = publicCalls;
    await evaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()');
    await assertUncertainCreation(previous);
  }
  await freshSyntheticWalkinPage();
  publicNetworkFailure = true;
  const beforeLostResponse = publicCalls;
  await evaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()');
  await assertUncertainCreation(beforeLostResponse);
  await evaluate('document.getElementById("entrance-member-tab").click(); document.getElementById("entrance-walkin-tab").click()');
  assert.equal(await evaluate('document.querySelector("#entrance-walkin-panel button[type=submit]").disabled'), true);
  // A real second tab must recover the same durable operation, not create anew.
  const secondTarget = await cdp('Target.createTarget', { url: 'about:blank' });
  try {
    const attached = await cdp('Target.attachToTarget', { targetId: secondTarget.targetId, flatten: true });
    const secondSend = (method, params) => cdp(method, params, attached.sessionId);
    const secondEvaluate = async expression => {
      const result = await secondSend('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
      assert.equal(result.exceptionDetails, undefined);
      return result.result.value;
    };
    await secondSend('Fetch.enable', { patterns: [{ urlPattern: '*' }] });
    await secondSend('Page.navigate', { url: origin + '/entrance' });
    await until(() => secondEvaluate('Boolean(document.getElementById("entrance-walkin-tab"))'), 'Second real tab entrance');
    await secondEvaluate('document.getElementById("entrance-walkin-tab").click()');
    await until(() => secondEvaluate('Boolean(document.querySelector("#entrance-walkin-panel form"))'), 'Second tab walk-in form');
    const beforeSecondTab = publicCalls;
    await until(() => secondEvaluate('Boolean([...document.querySelectorAll("button")].find(b=>b.textContent==="Recover existing request"))'), 'Persisted operation recovery');
    await secondEvaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()');
    await delay(150);
    assert.equal(publicCalls,beforeSecondTab,'Second tab must not allocate a fresh operation');
    publicNetworkFailure = false;
    publicResponsePatch = null;
    await secondEvaluate('[...document.querySelectorAll("button")].find(b=>b.textContent==="Recover existing request").click()');
    await until(()=>secondEvaluate('document.body.innerText.includes("Awaiting Owner confirmation")'),'Second tab recovers original provisional outcome');
    assert.equal(await evaluate('document.querySelector("#entrance-walkin-panel button[type=submit]").disabled'), true);
    console.log('PASS: real second tab uses durable browser operation and lookup, no new creation; synthetic HTTP only.');
    await freshSyntheticWalkinPage();
    await secondSend('Page.navigate', {url:origin+'/entrance'});
    await until(()=>secondEvaluate('Boolean(document.getElementById("entrance-walkin-tab"))'),'Second tab fresh allocation fixture');
    await secondEvaluate('document.getElementById("entrance-walkin-tab").click()');
    await until(()=>secondEvaluate('Boolean(document.querySelector("#entrance-walkin-panel button[type=submit]")) && !document.querySelector("#entrance-walkin-panel button[type=submit]").disabled'),'Both tabs ready to allocate');
    const beforeRace=recoverySnapshots.size;
    await Promise.all([
      evaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()'),
      secondEvaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()'),
    ]);
    await until(async()=>await textIncludes('Awaiting Owner confirmation') && await secondEvaluate('document.body.innerText.includes("Awaiting Owner confirmation")'),'Two-tab allocation/replay');
    assert.equal(recoverySnapshots.size,beforeRace+1,'Atomic browser allocation must share one capability across tabs');
    console.log('PASS: two real browser tabs racing initial allocation share one operation (synthetic HTTP; native SQL uniqueness tested separately).');
  } finally {
    await cdp('Target.closeTarget', { targetId: secondTarget.targetId });
  }
  publicNetworkFailure = false;
  await navigate('/entrance');
  await until(()=>textIncludes('Member ID or registered mobile number'),'Reloaded entrance');
  await evaluate('document.getElementById("entrance-walkin-tab").click()');
  publicResponsePatch = null;
  const beforeReloadedAttempt = publicCalls;
  await until(()=>textIncludes('Recover existing request'),'Reload recovery UI');
  await evaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()');
  await evaluate('[...document.querySelectorAll("button")].find(b=>b.textContent==="Recover existing request").click()');
  await until(() => textIncludes('Awaiting Owner confirmation'), 'provisional request');
  assert.equal(publicCalls, beforeReloadedAttempt, 'Reload must not dispatch a new creation');
  assert.equal(await textIncludes('This request does not confirm payment or attendance.'), true);
  const image = await cdp('Page.captureScreenshot', { format: 'png' });
  await writeFile(resolve(run, 'entrance-mobile.png'), Buffer.from(image.data, 'base64'));
  const storageFault = await cdp('Page.addScriptToEvaluateOnNewDocument', {source:'Object.defineProperty(globalThis,"indexedDB",{configurable:true,value:undefined});'});
  const beforeStorageFailure=publicCalls;
  await navigate('/entrance');
  await until(()=>textIncludes('Member ID or registered mobile number'),'Storage-failure fixture entrance');
  await evaluate('document.getElementById("entrance-walkin-tab").click()');
  await until(()=>textIncludes('Recovery storage is unavailable.'),'Storage-unavailable safe feedback');
  assert.equal(await evaluate('document.querySelector("#entrance-walkin-panel button[type=submit]").disabled'),true);
  await evaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()');
  await delay(100);
  assert.equal(publicCalls,beforeStorageFailure,'Unavailable storage must not dispatch a creation');
  await cdp('Page.removeScriptToEvaluateOnNewDocument',{identifier:storageFault.identifier});
  console.log('PASS: unavailable browser recovery storage fails closed without dispatch.');
  await navigate('/pin-setup#token=' + 'A'.repeat(43));
  await until(() => evaluate('location.hash === "" && document.querySelectorAll("input[type=password]").length === 2'), 'setup fragment removed and masked PIN');
  for (const size of [40, 42, 44, 128]) {
    await navigate('/pin-reset#token=' + 'A'.repeat(size));
    await until(async () => await textIncludes('Ask the Owner for a new private PIN link') && await evaluate('location.hash === ""'), 'invalid reset link rejected before form entry');
    assert.equal(await evaluate('location.hash === "" && document.querySelectorAll("input[type=password]").length === 0'), true);
    assert.equal(resetCalls, 0, 'Malformed reset tokens never cause requests');
  }
  await navigate('/pin-reset#token=' + 'A'.repeat(43));
  await until(() => evaluate('location.hash === "" && document.querySelectorAll("input[type=password]").length === 2'), 'valid reset link accepted');
  await evaluate(`(() => { const set=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set; for(const id of ['member-pin','confirm-member-pin']) { const el=document.getElementById(id);set.call(el,'123456');el.dispatchEvent(new Event('input',{bubbles:true})); } })()`);
  await evaluate('document.querySelector("form").requestSubmit()');
  await until(() => textIncludes('PIN service is unavailable'), 'reset failure is visible');
  assert.equal(resetCalls, 1);
  await until(() => evaluate('Array.from(document.querySelectorAll("input[type=password]")).every(input=>input.value==="")'), 'Reset failure clears both PIN fields');
  await evaluate(`(() => { window.syntheticPageMarker = 'same-document'; const set=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set; for(const id of ['member-pin','confirm-member-pin']) { const el=document.getElementById(id);set.call(el,'123456');el.dispatchEvent(new Event('input',{bubbles:true})); } })()`);
  expectedResetToken = 'B'.repeat(43);
  await navigate('/pin-reset#token=' + expectedResetToken);
  await until(() => evaluate('location.hash === "" && Array.from(document.querySelectorAll("input[type=password]")).every(input=>input.value==="") && !document.body.innerText.includes("PIN service is unavailable")'), 'Replacement private link clears stale fields and errors');
  assert.equal(await evaluate('window.syntheticPageMarker'), 'same-document', 'Replacement must be handled without reloading the page');
  resetSuccess = true;
  await evaluate(`(() => { const set=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set; for(const id of ['member-pin','confirm-member-pin']) { const el=document.getElementById(id);set.call(el,'123456');el.dispatchEvent(new Event('input',{bubbles:true})); } })()`);
  await evaluate('document.querySelector("form").requestSubmit()');
  await until(() => textIncludes('Your PIN request is complete'), 'Replacement token reaches the actual frontend request');
  assert.equal(resetCalls, 2);
  await navigate('/pin-reset#token=' + 'C'.repeat(43));
  await until(() => evaluate('location.hash === "" && document.querySelectorAll("input[type=password]").length === 2 && !document.body.innerText.includes("Your PIN request is complete")'), 'New private link clears prior completion state');
  await navigate('/');
  await until(() => textIncludes('Sign in'), 'signed-out Owner screen');
  if (!production) {
    const result = await evaluate(`(async () => {
      const { OfflineClaimQueue } = await import('/src/lib/offline-claim.ts');
      const owner = crypto.randomUUID();
      const a = await OfflineClaimQueue.open(owner);
      const second = await OfflineClaimQueue.open(owner);
      const add = queue => queue.add('MBR-ABCDEF123456', '2026-11-24', Date.now() + 60000);
      const inserted = await Promise.all([add(a), add(second)]);
      second.clear();
      if (inserted.filter(Boolean).length !== 1) throw Error('Concurrent duplicate claim');
      const first = await a.first(); a.clear();
      const b = await OfflineClaimQueue.open(owner);
      const recovered = await b.first();
      const other = await OfflineClaimQueue.open(crypto.randomUUID());
      await other.remove(first.operationId);
      const isolated = other.size === 0 && (await b.first()).operationId === first.operationId;
      const db = await new Promise((resolve,reject) => { const req = indexedDB.open('gymforce-offline-claims-v1'); req.onsuccess=()=>resolve(req.result); req.onerror=()=>reject(req.error); });
      const read = (store,id) => new Promise((resolve,reject) => { const req=db.transaction(store).objectStore(store).get(id); req.onsuccess=()=>resolve(req.result); req.onerror=()=>reject(req.error); });
      const row = await read('claims', first.operationId);
      const key = await read('keys', owner);
      const encrypted = row.ciphertext instanceof ArrayBuffer && !JSON.stringify(row).includes('MBR-ABCDEF123456') && !JSON.stringify(row).includes('2026-11-24') && key.extractable === false;
      db.close();
      await b.remove(first.operationId);
      const empty = b.size === 0;
      b.clear(); other.clear();
      return { recovered: JSON.stringify(first) === JSON.stringify(recovered), isolated, empty, encrypted };
    })()`);
    assert.deepEqual(result, { recovered: true, isolated: true, empty: true, encrypted: true });
    console.log('PASS: real browser queue reopen, owner isolation and acknowledged deletion.');
  }
  assert.equal(await evaluate('document.querySelector(".dashboard") === null'), true);
  await evaluate(`(() => { const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; for (const [id,value] of [['email','owner@example.test'],['password','synthetic-ui-only']]) { const el=document.getElementById(id); set.call(el,value); el.dispatchEvent(new Event('input',{bubbles:true})); } })()`);
  await evaluate('document.querySelector("form").requestSubmit()');
  await until(() => textIncludes('Owner access verified'), 'synthetic Owner UI session');
  const recoveries = {
    Members: [['Member directory unavailable.'], ['No members found'], ['owner-list-members']],
    Memberships: [['Plan directory unavailable.', 'Purchase history unavailable.'], ['No membership plans yet', 'No purchases found'], ['owner-list-membership-plans', 'owner-list-membership-purchases']],
    'Receipt review': [['Receipt history unavailable.'], ['No receipts on this page.'], ['owner-receipt-review']],
    'Cash drawer': [['Cash history unavailable.'], ['No drawers recorded.'], ['owner-cash']],
    'Presence review': [['Presence review unavailable.'], ['No claims on this page.'], ['owner-attendance-claims']],
    Attendance: [['Attendance history unavailable.'], ['No check-ins found'], ['owner-attendance']],
  };
  for (const [label, heading] of [['Members','Member directory'],['Memberships','Plan directory'],['Payments','Payment details'],['Walk-ins','Request history'],['Receipt review','Actual receipts and corrections'],['Cash drawer','Physical cash drawer'],['Presence review','Provisional presence claims'],['Attendance','Recorded check-ins'],['Audit history','Recorded events'],['Reports','Confirmed income by day and method'],['Settings','Permanent entrance QR']]) {
    await evaluate(`Array.from(document.querySelectorAll('nav button')).find(button => button.innerText.trim().endsWith(${JSON.stringify(label)})).click()`);
    await until(() => textIncludes(heading), `Owner ${label} rendering`);
    assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), true, `mobile overflow: ${label}`);
    if (recoveries[label]) {
      const [failures, emptyMessages, routes] = recoveries[label];
      for (const failure of failures) await until(() => textIncludes(failure), `${label}: load failure`);
      for (const empty of emptyMessages) assert.equal(await textIncludes(empty), false, `${label}: failure must not imply empty data`);
      routes.forEach((route) => unavailableRoutes.delete(route));
      await evaluate(`Array.from(document.querySelectorAll('button')).filter(button => button.innerText.trim().startsWith('Refresh') && !button.disabled).forEach(button => button.click())`);
      for (const empty of emptyMessages) await until(() => textIncludes(empty), `${label}: empty after recovery`);
      for (const failure of failures) assert.equal(await textIncludes(failure), false, `${label}: previous failure cleared`);
    }
    if (label === 'Payments') {
      await until(() => textIncludes('Use Refresh payments to retry.'), 'payable purchase failure');
      await until(() => textIncludes('Payment history unavailable. Refresh history to retry.'), 'history failure');
      assert.equal(await textIncludes('No payment records found'), false);
      paymentFailure = false;
      await evaluate(`Array.from(document.querySelectorAll('button')).find(button => button.innerText === 'Refresh payments').click()`);
      await until(() => evaluate('document.querySelector(".purchase-form select")?.options.length === 50'), 'first payable purchase page');
      await until(() => textIncludes('No payment records found'), 'successful empty history');
      assert.equal(await textIncludes('backend service is unavailable'), false, 'retry clears both independent load errors');
      await evaluate(`Array.from(document.querySelectorAll('button')).find(button => button.innerText === 'Next purchases').click()`);
      await until(() => evaluate('document.querySelector(".purchase-form select")?.options.length === 2'), 'next payable purchase page');
      const previousCalls = ownerStatusCalls;
      let finishVerification;
      ownerStatusGate = new Promise((resolveGate) => { finishVerification = resolveGate; });
      try {
        await evaluate('window.paymentFormBeforeFocus = document.querySelector(".purchase-form"); window.dispatchEvent(new Event("focus"));');
        await until(() => ownerStatusCalls > previousCalls, 'focus rechecks Owner access');
        assert.equal(await evaluate('document.querySelector(".dashboard")?.hidden'), false, 'focus keeps the dashboard visible during verification');
        assert.equal(await textIncludes('Restoring your secure owner session'), false, 'focus does not show the session-restoring screen');
        assert.equal(await evaluate('document.querySelector(".purchase-form") === window.paymentFormBeforeFocus'), true, 'focus keeps the current form mounted during verification');
      } finally {
        finishVerification();
        ownerStatusGate = undefined;
      }
      assert.equal(await evaluate('document.querySelector(".purchase-form") === window.paymentFormBeforeFocus'), true, 'focus preserves the payment form');
      assert.equal(await evaluate('document.querySelector(".purchase-form select").options.length'), 2, 'focus preserves payment pagination');
      assert.equal(await evaluate('new URLSearchParams(location.search).get("section")'), 'payments');
    }
    if (label === 'Walk-ins') {
      await until(() => textIncludes('Access was denied'), 'Owner walk-in authorization feedback');
      assert.equal(await textIncludes('No requests on this page.'), false);
      walkinFailure = false;
      await evaluate(`Array.from(document.querySelectorAll('button')).find(button => button.innerText === 'Refresh requests').click()`);
      await until(() => textIncludes('No requests on this page.'), 'successful empty walk-in history');
      assert.equal(await textIncludes('Access was denied'), false);
    }
  }
  const setOffline = offline => cdp('Network.emulateNetworkConditions', { offline, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
  await cdp('Network.enable');
  await setOffline(true);
  await until(() => textIncludes('Offline provisional claim'), 'verified owner enters offline mode');
  assert.equal(await evaluate('!!document.querySelector(".dashboard, #password")'), false);
  const fillClaim = () => evaluate(`(() => {
    const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    const inputs = document.querySelectorAll('form input');
    for (const [input, value] of [[inputs[0], 'MBR-ABCDEF123456'], [inputs[1], '2026-11-23']]) {
      set.call(input, value);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }
    document.querySelector('form').requestSubmit();
  })()`);
  await fillClaim();
  await until(() => textIncludes('1 pending. Saved'), 'offline claim retained');
  await fillClaim();
  await until(() => textIncludes('1 pending. A claim'), 'duplicate prevented');
  await evaluate('window.realNow = Date.now; Date.now = () => window.realNow() + 901000');
  await fillClaim();
  await until(() => textIncludes('Offline authorization expired'), 'expired lease blocks entry');
  await evaluate('Date.now = window.realNow');
  let releaseReconnect;
  ownerStatusGate = new Promise(resolveGate => { releaseReconnect = resolveGate; });
  const beforeReconnect = ownerStatusCalls;
  try {
    await setOffline(false);
    await until(() => ownerStatusCalls > beforeReconnect, 'fresh owner check after reconnect');
    assert.equal(await evaluate('!!document.querySelector(".dashboard")'), false);
  } finally { releaseReconnect(); ownerStatusGate = undefined; }
  await until(() => textIncludes('Permanent entrance QR'), 'settings navigation restored');
  assert.equal(claimAttempts.length, 0);
  for (let attempt = 1; attempt <= 3; attempt++) {
    await evaluate("Array.from(document.querySelectorAll('button')).find(b => b.innerText === 'Synchronize pending claims').click()");
    await until(() => claimAttempts.length === attempt, 'manual retry sent');
    await until(() => textIncludes(attempt < 3 ? '1 pending offline claims. Synchronization unconfirmed' : '0 pending offline claims. Claims synchronized'), 'only a valid acknowledgement removes claim');
  }
  assert.deepEqual(claimAttempts[0], claimAttempts[1]);
  assert.deepEqual(claimAttempts[0], claimAttempts[2]);
  await evaluate(`(() => { const el=document.querySelector('input[type=url]'); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(el,'https://gym.example.test'); el.dispatchEvent(new Event('input',{bubbles:true})); })()`);
  await until(() => evaluate('document.querySelector("input[readonly]")?.value === "https://gym.example.test/entrance"'), 'exact QR destination');
  await evaluate('document.querySelector("input[type=checkbox]").click()');
  await evaluate('document.querySelector(".purchase-form").requestSubmit()');
  await until(() => evaluate(`document.querySelector('[aria-label="Generated entrance QR preview"] img')?.src.startsWith('data:image/png;base64,')`), 'local QR preview');
  await cdp('Emulation.setDeviceMetricsOverride', { width: 1280, height: 900, deviceScaleFactor: 1, mobile: false });
  const ownerImage = await cdp('Page.captureScreenshot', { format: 'png' });
  await writeFile(resolve(run, 'owner-qr-desktop.png'), Buffer.from(ownerImage.data, 'base64'));
  if (production) {
    await until(() => evaluate('navigator.serviceWorker.controller !== null'), 'production shell service worker');
    const manifest = await cdp('Page.getAppManifest');
    assert.deepEqual(manifest.errors, [], 'Chrome must parse the generated manifest');
    const manifestData = JSON.parse(manifest.data);
    assert.equal(manifestData.display, 'standalone');
    assert.equal(await evaluate('window.isSecureContext'), true, 'Loopback is a secure-context exception, not hosted HTTPS evidence');
    const installability = await cdp('Page.getInstallabilityErrors');
    assert.deepEqual(installability.installabilityErrors, [], 'No installability errors in this desktop Chrome emulation');
    await writeFile(resolve(run, 'pwa-qualification.json'), JSON.stringify({ browser: browserVersion.product, emulation: 'Android UA, mobile viewport and touch; not physical Android', manifest: manifestData, installability }, null, 2));
    const cached = await evaluate(`(async () => { const found=[]; for (const key of await caches.keys()) { const cache=await caches.open(key); for (const request of await cache.keys()) found.push(new URL(request.url).pathname); } return found; })()`);
    assert.ok(cached.length > 0);
    assert.equal(cached.some((path) => /functions|auth|pin-setup|pin-reset|entrance/.test(path)), false, 'Sensitive/public submissions must not enter the app shell cache');
    assert.ok(cached.every((path) => path === '/index.html' || path === '/pwa.svg' || path === '/manifest.webmanifest' || path === '/registerSW.js' || path.startsWith('/assets/')), 'Only static app shell entries may be cached');
    // Change only this run's generated worker. No force-activation message.
    const workerPath = resolve(run, 'dist/sw.js');
    const beforeUpdateForm = await evaluate('document.querySelector("input[type=url]").value');
    await evaluate('window.phase58CurrentForm = true');
    await writeFile(workerPath, (await readFile(workerPath, 'utf8')) + '\n// synthetic update qualification\n');
    await evaluate('(async () => { const r=await navigator.serviceWorker.getRegistration(); await r.update(); })()');
    await until(() => textIncludes('A GYMFORCE update is ready.'), 'Verified Owner sees waiting-update notice');
    await cdp('Emulation.setDeviceMetricsOverride', { width: 375, height: 812, deviceScaleFactor: 1, mobile: true });
    await evaluate('Array.from(document.querySelectorAll("button")).find(b=>b.textContent === "How to apply safely").click()');
    assert.equal(await textIncludes('Finish or resolve pending operations first.'), true);
    assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), true, 'Update instructions fit the mobile viewport');
    const updateImage = await cdp('Page.captureScreenshot', { format: 'png' });
    await writeFile(resolve(run, 'owner-update-mobile.png'), Buffer.from(updateImage.data, 'base64'));
    assert.equal(await evaluate('document.querySelector("input[type=url]").value'), beforeUpdateForm);
    assert.equal(await evaluate('window.phase58CurrentForm'), true);
    assert.equal(await evaluate('(async () => { const r=await navigator.serviceWorker.getRegistration(); return r.waiting?.state === "installed" && navigator.serviceWorker.controller?.state === "activated"; })()'), true);
    await navigate('/entrance');
    await until(() => textIncludes('Member ID or registered mobile number'), 'entrance before offline transition');
    assert.equal(await textIncludes('A GYMFORCE update is ready.'), false, 'Public page must not show Owner update UI');
    await cdp('Network.enable');
    await cdp('Network.emulateNetworkConditions', { offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0 });
    await until(() => textIncludes('Nothing will be queued or confirmed offline.'), 'offline entrance notice');
    assert.equal(await evaluate('navigator.onLine === false && document.querySelector("#entrance-member-panel button[type=submit]").disabled'), true);
    const beforeOfflineWalkin = publicCalls;
    await evaluate('document.getElementById("entrance-walkin-tab").click()');
    await until(() => evaluate('document.querySelector("#entrance-walkin-panel button[type=submit]")?.disabled === true'), 'offline walk-in creation disabled');
    assert.equal(publicCalls, beforeOfflineWalkin, 'Offline UI must not submit or queue public requests');
    await evaluate('window.phase57BeforeNavigation = true');
    await navigate('/entrance?synthetic-offline-navigation=1');
    await until(() => evaluate('location.search === "?synthetic-offline-navigation=1" && window.phase57BeforeNavigation === undefined && navigator.onLine === false && document.body.innerText.includes("Nothing will be queued or confirmed offline.")'), 'Cold document navigation uses the offline static shell');
    await cdp('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
    // Explicitly leave the only controlled document, as closing app windows does.
    await cdp('Page.navigate', { url: 'about:blank' });
    await delay(500);
    await navigate('/entrance');
    await until(() => evaluate('(async () => { const r=await navigator.serviceWorker.getRegistration(); return !r.waiting && r.active?.state === "activated" && navigator.serviceWorker.controller !== null; })()'), 'Waiting update activates naturally after clients leave');
    console.log(`PASS: manifest parsed, secure loopback context, Android UA/touch emulation, interrupted request recovery, offline cold navigation, Owner-only waiting-update notice, preserved form and natural activation after clients leave. Installability diagnostic entries: ${installability.installabilityErrors.length}; details are synthetic local evidence.`);
    console.log('PASS: browser offline transition disables public check-in/walk-in submissions; no request or offline queue created.');
    console.log('PASS: production shell worker controls the page; observed caches contain only static assets/index, no API/Auth/PIN/entrance submissions. Real-device install/update QA remains open.');
  }
  await cdp('Page.navigate', { url: 'about:blank' });
  await navigate('/?section=settings');
  await until(() => textIncludes('Permanent entrance QR'), 'Owner reload restores section after verification');
  const beforeSignOut = ownerStatusCalls;
  let releaseVerification;
  ownerStatusGate = new Promise(resolveGate => { releaseVerification = resolveGate; });
  try {
    await evaluate('window.dispatchEvent(new Event("focus"))');
    await until(() => ownerStatusCalls > beforeSignOut, 'pending owner verification before sign-out');
    await evaluate("document.querySelector('.signout-button').click()");
    await until(() => textIncludes('Sign in'), 'manual sign-out hides management');
  } finally { releaseVerification(); ownerStatusGate = undefined; }
  await evaluate("window.dispatchEvent(new Event('focus'))");
  await until(() => evaluate('!!document.querySelector("#email") && !document.querySelector(".dashboard")'), 'stale authorization cannot restore management');
  await evaluate(`(() => { const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; for (const [id,value] of [['email','owner@example.test'],['password','synthetic-ui-only']]) { const el=document.getElementById(id); set.call(el,value); el.dispatchEvent(new Event('input',{bubbles:true})); } })()`);
  await evaluate('document.querySelector("form").requestSubmit()');
  await until(() => textIncludes('Owner access verified'), 'explicit sign-in restores management');
  ownerStatusDenied = true;
  await evaluate('window.dispatchEvent(new Event("focus"))');
  await until(() => evaluate('!document.querySelector(".dashboard") && document.body.innerText.includes("Sign in")'), 'revoked Owner access removes the dashboard');
  assert.equal(await evaluate('new URLSearchParams(location.search).has("section")'), false, 'denied Owner recheck clears the section');
  assert.equal(errors.length, 0, errors.join('; '));
  assert.equal(externalAttempts, 0, 'All app network must remain on the synthetic loopback origin');
  console.log('PASS: mobile entrance/all Owner navigation without overflow, failed-list recovery and empty-state distinctions, seven uncertain public outcomes locked against repeated submit, five malformed walk-in snapshots rejected without false pending confirmation, payable pagination, PIN clearing, provisional walk-in, four invalid reset-link lengths blocked, valid reset failure/secret clearing, same-document replacement links clear stale fields/errors/completion and use the replacement token, fragment removal, signed-out screen, exact local QR preview and no external app requests. Synthetic API/Auth fixtures only; no Auth/RLS certification.');
  console.log(`Synthetic screenshot retained in .cache/${run.split(/[\\/]/).at(-1)}/entrance-mobile.png`);
} finally {
  if (socket?.readyState === WebSocket.OPEN) { try { await cdp('Browser.close'); } catch { /* closing terminates its socket */ } socket.close(); }
  browser?.kill(); server.kill();
  for (const item of pending.values()) item.resolve({});
}
