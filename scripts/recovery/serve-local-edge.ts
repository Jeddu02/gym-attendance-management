// Bind the unchanged actual module to an explicitly loopback-only real server.
// This adapts listen options only; it does not fabricate requests/RPC responses.
const run = Deno.env.get('GYMFORCE_TEST_RUN_ID');
const port = Number(Deno.env.get('GYMFORCE_HTTP_PORT'));
if (!/^[a-f0-9]{32}$/.test(run ?? '') || !Number.isInteger(port) || port < 1024 || port > 65535)
  throw new Error('Isolated HTTP runner required');
const serve = Deno.serve.bind(Deno);
Object.defineProperty(Deno, 'serve', { value: (handler: Deno.ServeHandler) =>
  serve({ hostname: '127.0.0.1', port, onListen() {} }, handler) });
await import('../../supabase/functions/public-walkin-recovery/index.ts');
