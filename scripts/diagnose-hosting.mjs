// Read-only public hosting diagnostics. No keys, sessions, data queries or writes.
import { readFile } from 'node:fs/promises';

const [siteArgument, backendArgument] = process.argv.slice(2);
function origin(value) {
  const url = new URL(value);
  if (url.username || url.password || url.search || url.hash || url.pathname !== '/' ||
      (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['127.0.0.1', 'localhost'].includes(url.hostname)))) {
    throw Error('Use an HTTPS origin only (HTTP loopback is allowed for synthetic tests).');
  }
  return url.origin;
}
if (!siteArgument || !backendArgument || process.argv.length !== 4) {
  throw Error('Usage: node scripts/diagnose-hosting.mjs https://SITE.pages.dev https://PROJECT.supabase.co');
}
const site = origin(siteArgument);
const backend = origin(backendArgument);
const config = await readFile(new URL('../supabase/config.toml', import.meta.url), 'utf8');
const functions = [...config.matchAll(/^\[functions\.([\w-]+)\]/gm)].map((match) => match[1]);
let failed = false;
async function probe(label, url, options, validate) {
  try {
    const response = await fetch(url, { ...options, redirect: 'manual', signal: AbortSignal.timeout(15000) });
    const issues = validate(response);
    await response.body?.cancel();
    failed ||= issues.length > 0;
    console.log(`${issues.length ? 'FAIL' : 'PASS'} ${label}: HTTP ${response.status}${issues.length ? `; ${issues.join('; ')}` : ''}`);
  } catch {
    failed = true;
    console.log(`FAIL ${label}: network/TLS/timeout failure (response details suppressed)`);
  }
}
for (const path of ['/', '/entrance', '/pin-setup', '/pin-reset']) {
  await probe(`site ${path}`, site + path, { method: 'GET' }, (response) => {
    const issues = [];
    if (response.status !== 200) issues.push('expected 200; check Pages build, canonical origin and SPA fallback');
    if (!(response.headers.get('Content-Type') ?? '').includes('text/html')) issues.push('expected HTML');
    if (path.startsWith('/pin-') && !(response.headers.get('Cache-Control') ?? '').includes('no-store')) issues.push('missing PIN-page no-store header');
    return issues;
  });
}
for (const name of functions) {
  await probe(name, `${backend}/functions/v1/${name}`, {
    method: 'OPTIONS', headers: { Origin: site, 'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': 'authorization,apikey,content-type,x-client-info' },
  }, (response) => {
    const issues = [];
    if (response.status < 200 || response.status >= 300) issues.push('preflight rejected; check deployment, origin and server configuration');
    if (response.headers.get('Access-Control-Allow-Origin') !== site) issues.push('origin mismatch');
    const methods = (response.headers.get('Access-Control-Allow-Methods') ?? '').split(',').map((item) => item.trim().toUpperCase());
    if (!methods.includes('POST')) issues.push('POST not allowed');
    const allowed = (response.headers.get('Access-Control-Allow-Headers') ?? '').toLowerCase().split(',').map((item) => item.trim());
    if (!['authorization', 'apikey', 'content-type', 'x-client-info'].every((header) => allowed.includes(header))) issues.push('SDK request headers not allowed');
    return issues;
  });
}
console.log('Only public HTML and OPTIONS checked. Auth, RPCs, RLS, release switches and business workflows remain unverified.');
process.exitCode = failed ? 1 : 0;
