import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';

test('hosting diagnostics use only public GET/OPTIONS and reject broken CORS', async () => {
  let deny = false;
  let optionsCount = 0;
  let unexpectedMethod = false;
  const server = createServer((request, response) => {
    unexpectedMethod ||= !['GET', 'OPTIONS'].includes(request.method);
    assert.equal(request.headers.authorization, undefined);
    if (request.method === 'OPTIONS') {
      optionsCount++;
      response.writeHead(204, {
        'Access-Control-Allow-Origin': deny ? 'https://wrong.example.test' : request.headers.origin,
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
      });
      response.end();
    } else {
      response.writeHead(200, { 'Content-Type': 'text/html', 'Cache-Control': 'no-store' });
      response.end('<html><body>Synthetic shell</body></html>');
    }
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  const script = fileURLToPath(new URL('../scripts/diagnose-hosting.mjs', import.meta.url));
  const run = () => promisify(execFile)(process.execPath, [script, url, url], { windowsHide: true, timeout: 60000 });
  try {
    const result = await run();
    assert.ok(result.stdout.includes('Auth, RPCs, RLS, release switches and business workflows remain unverified'));
    assert.equal(optionsCount, 21);
    assert.equal(unexpectedMethod, false);
    deny = true;
    await assert.rejects(run(), (error) => error.code === 1 && error.stdout.includes('origin mismatch'));
  } finally {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
});
