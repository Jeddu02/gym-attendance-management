// Local UI smoke tests only. APIs are synthetic CDP fixtures, not Auth/RLS proof.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile, access } from 'node:fs/promises';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:net';
import { setTimeout as delay } from 'node:timers/promises';
const root = resolve(import.meta.dirname, '..');
const run = resolve(root, '.cache', `browser-test-${randomUUID()}`);
await mkdir(run, { recursive: true });
const browserPath = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
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
async function until(check, description, timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) { if (await check()) return; await delay(100); }
  throw Error(`Timed out: ${description}`);
}
function cdp(method, params = {}) {
  const id = ++sequence;
  return new Promise((resolveCall, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(Error(`CDP timeout: ${method}; recent local events: ${observed.slice(-8).join(', ')}`)); }, method === 'Page.navigate' ? 45000 : 15000);
    pending.set(id, { resolve: (value) => { clearTimeout(timer); resolveCall(value); }, reject });
    socket.send(JSON.stringify({ id, method, params }));
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
  await until(async () => { try { return (await fetch(origin)).ok; } catch { return false; } }, 'local Vite');
  browser = spawn(browserPath, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-background-networking', '--disable-sync', '--disable-extensions', '--disable-component-update', '--remote-debugging-port=0', `--user-data-dir=${resolve(run, 'profile')}`, 'about:blank'], { windowsHide: true, stdio: 'ignore' });
  let debugPort;
  await until(async () => { try { debugPort = Number((await readFile(resolve(run, 'profile/DevToolsActivePort'), 'utf8')).split('\n')[0]); return debugPort > 0; } catch { return false; } }, 'isolated browser');
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
    else if (message.method === 'Fetch.requestPaused') void handleRequest(message.params).catch(() => errors.push('Fixture routing failure'));
  });
  async function handleRequest({ requestId, request }) {
    const url = new URL(request.url);
    if (url.origin !== origin) { externalAttempts++; await cdp('Fetch.failRequest', { requestId, errorReason: 'BlockedByClient' }); return; }
    const respond = async (status, body) => cdp('Fetch.fulfillRequest', { requestId, responseCode: status, responseHeaders: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Cache-Control', value: 'no-store' }], body: Buffer.from(JSON.stringify(body)).toString('base64') });
    if (url.pathname === '/auth/v1/token') {
      const user = { id: '91000000-0000-4000-8000-000000000002', aud: 'authenticated', role: 'authenticated', email: 'owner@example.test', app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() };
      const payload = { sub: user.id, aud: 'authenticated', role: 'authenticated', exp: Math.floor(Date.now()/1000)+3600, iat: Math.floor(Date.now()/1000) };
      const access_token = [ { alg: 'HS256', typ: 'JWT' }, payload ].map((part) => Buffer.from(JSON.stringify(part)).toString('base64url')).join('.') + '.c3ludGhldGlj';
      await respond(200, { access_token, token_type: 'bearer', refresh_token: 'synthetic-refresh-only', expires_in: 3600, user });
    } else if (url.pathname === '/functions/v1/owner-status') await respond(200, { authenticated: true, isActiveOwner: true, authorizationReady: true });
    else if (url.pathname === '/functions/v1/owner-reporting') {
      const { action } = JSON.parse(request.postData);
      await respond(200, action === 'income' ? { success: true, income: [] } : action === 'expiry' ? { success: true, expiries: [] } : { success: true, summary: { totalMembers: 0, approvedMembers: 0, currentEntitlements: 0, todayValidCheckins: 0, confirmedMembershipIncomePhp: '0.00', confirmedWalkinIncomePhp: '0.00' } });
    } else if (url.pathname === '/functions/v1/owner-membership-payments') {
      const input = JSON.parse(request.postData);
      if (input.action === 'payable') {
        assert.equal(input.limit, 50);
        const purchases = Array.from({length: input.offset === 0 ? 50 : 2}, (_, index) => ({id:`91000000-0000-4000-8000-${(input.offset+index+1).toString(16).padStart(12,'0')}`,memberName:'Synthetic payable member',memberCode:'MBR-ABCDEF123456',planName:'Synthetic monthly',pricePhp:'350.00'}));
        await respond(200, { success: true, purchases });
      } else { assert.equal(input.action, 'list'); await respond(200, { success: true, result: {payments:[],payablePurchases:[]} }); }
    }
    else if (url.pathname === '/functions/v1/owner-attendance') await respond(200, { success: true, attendance: [] });
    else if (['/functions/v1/owner-receipt-review','/functions/v1/owner-cash','/functions/v1/owner-attendance-claims'].includes(url.pathname)) await respond(200, { success: true, result: [] });
    else if (url.pathname === '/functions/v1/member-checkin') {
      const input = JSON.parse(request.postData);
      assert.deepEqual(Object.keys(input).sort(), ['identifier', 'pin']);
      await respond(400, { success: false, message: 'CHECKIN_UNAVAILABLE' });
    } else if (url.pathname === '/functions/v1/public-walkin-request') {
      assert.deepEqual(JSON.parse(request.postData), { paymentMethod: 'cash' });
      await respond(200, { success: true, request: { id: '91000000-0000-4000-8000-000000000001', feePhp: '100.00', currency: 'PHP', paymentMethod: 'cash', createdAt: new Date().toISOString(), expiresAt: new Date(Date.now()+900000).toISOString() } });
    } else if (url.pathname === '/functions/v1/member-enroll-pin') await respond(503, { error: 'SERVICE_UNAVAILABLE' });
    else if (url.pathname.startsWith('/functions/') || url.pathname.startsWith('/auth/')) await respond(503, { error: 'SYNTHETIC_UNAVAILABLE' });
    else await cdp('Fetch.continueRequest', { requestId });
  }
  await cdp('Page.enable'); await cdp('Runtime.enable');
  await cdp('Fetch.enable', { patterns: [{ urlPattern: '*' }] });
  await cdp('Emulation.setDeviceMetricsOverride', { width: 375, height: 812, deviceScaleFactor: 1, mobile: true });
  await navigate('/entrance');
  await until(() => textIncludes('Member ID or registered mobile number'), 'entrance form');
  assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), true);
  assert.equal(await evaluate('document.querySelector("#checkin-pin").type'), 'password');
  await evaluate(`(() => { const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; for (const [id,value] of [['checkin-identifier','MBR-ABCDEF123456'],['checkin-pin','123456']]) { const el=document.getElementById(id); set.call(el,value); el.dispatchEvent(new Event('input',{bubbles:true})); } })()`);
  await evaluate('document.querySelector("#entrance-member-panel form").requestSubmit()');
  await until(() => evaluate('document.querySelector("#checkin-pin").value === ""'), 'PIN cleared after denial');
  await evaluate('document.getElementById("entrance-walkin-tab").click()');
  await until(() => textIncludes('Request a walk-in visit'), 'walk-in tab');
  await evaluate('document.querySelector("#entrance-walkin-panel form").requestSubmit()');
  await until(() => textIncludes('Awaiting Owner confirmation'), 'provisional request');
  assert.equal(await textIncludes('This request does not confirm payment or attendance.'), true);
  const image = await cdp('Page.captureScreenshot', { format: 'png' });
  await writeFile(resolve(run, 'entrance-mobile.png'), Buffer.from(image.data, 'base64'));
  await navigate('/pin-setup#token=' + 'A'.repeat(43));
  await until(() => evaluate('location.hash === "" && document.querySelectorAll("input[type=password]").length === 2'), 'setup fragment removed and masked PIN');
  await navigate('/');
  await until(() => textIncludes('Sign in'), 'signed-out Owner screen');
  assert.equal(await evaluate('document.querySelector(".dashboard") === null'), true);
  await evaluate(`(() => { const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set; for (const [id,value] of [['email','owner@example.test'],['password','synthetic-ui-only']]) { const el=document.getElementById(id); set.call(el,value); el.dispatchEvent(new Event('input',{bubbles:true})); } })()`);
  await evaluate('document.querySelector("form").requestSubmit()');
  await until(() => textIncludes('Owner access verified'), 'synthetic Owner UI session');
  for (const [label, heading] of [['Payments','Payment details'],['Receipt review','Actual receipts and corrections'],['Cash drawer','Physical cash drawer'],['Presence review','Provisional presence claims'],['Attendance','Recorded check-ins'],['Reports','Confirmed income by day and method'],['Settings','Permanent entrance QR']]) {
    await evaluate(`Array.from(document.querySelectorAll('nav button')).find(button => button.innerText.trim().endsWith(${JSON.stringify(label)})).click()`);
    await until(() => textIncludes(heading), `Owner ${label} rendering`);
    assert.equal(await evaluate('document.documentElement.scrollWidth <= window.innerWidth'), true, `mobile overflow: ${label}`);
    if (label === 'Payments') {
      await until(() => evaluate('document.querySelector(".purchase-form select")?.options.length === 50'), 'first payable purchase page');
      await evaluate(`Array.from(document.querySelectorAll('button')).find(button => button.innerText === 'Next purchases').click()`);
      await until(() => evaluate('document.querySelector(".purchase-form select")?.options.length === 2'), 'next payable purchase page');
    }
  }
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
    const cached = await evaluate(`(async () => { const found=[]; for (const key of await caches.keys()) { const cache=await caches.open(key); for (const request of await cache.keys()) found.push(new URL(request.url).pathname); } return found; })()`);
    assert.ok(cached.length > 0);
    assert.equal(cached.some((path) => /functions|auth|pin-setup|pin-reset|entrance/.test(path)), false, 'Sensitive/public submissions must not enter the app shell cache');
    assert.ok(cached.every((path) => path === '/index.html' || path === '/pwa.svg' || path === '/manifest.webmanifest' || path === '/registerSW.js' || path.startsWith('/assets/')), 'Only static app shell entries may be cached');
    console.log('PASS: production shell worker controls the page; observed caches contain only static assets/index, no API/Auth/PIN/entrance submissions. Real-device install/update QA remains open.');
  }
  assert.equal(errors.length, 0, errors.join('; '));
  assert.equal(externalAttempts, 0, 'All app network must remain on the synthetic loopback origin');
  console.log('PASS: mobile entrance/Owner modules without overflow, PIN clearing, provisional walk-in, setup fragment removal, signed-out screen, synthetic Owner navigation, exact local QR preview and no external app requests. Synthetic API/Auth fixtures only; no Auth/RLS certification.');
  console.log(`Synthetic screenshot retained in .cache/${run.split(/[\\/]/).at(-1)}/entrance-mobile.png`);
} finally {
  if (socket?.readyState === WebSocket.OPEN) { try { await cdp('Browser.close'); } catch { /* closing terminates its socket */ } socket.close(); }
  browser?.kill(); server.kill();
  for (const item of pending.values()) item.resolve({});
}
