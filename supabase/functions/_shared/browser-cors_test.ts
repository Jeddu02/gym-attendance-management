import { withBrowserCors } from "./browser-cors.ts";

Deno.test("browser CORS rejects malformed origin configuration without invoking business handler", async () => {
  let calls = 0;
  for (const origin of [undefined, "", "*", "null", "https://gym.example.test/", "https://user:pass@gym.example.test", "file:///tmp", "https://gym.example.test/path"]) {
    const handler = withBrowserCors(origin, () => { calls++; return new Response(); });
    const response = await handler(new Request("https://edge.example.test", { method: "OPTIONS", headers: { Origin: "https://gym.example.test" } }));
    if (response.status !== 503 || response.headers.has("Access-Control-Allow-Origin")) throw Error("Unsafe origin configuration accepted");
  }
  if (calls !== 0) throw Error("Business handler invoked on rejected configuration");
});

Deno.test("accepted POST delegates to original authorization and preserves its response", async () => {
  const origin = "https://gym.example.test";
  const denied = new Response(JSON.stringify({ error: "AUTHENTICATION_REQUIRED" }), { status: 401 });
  let calls = 0;
  const handler = withBrowserCors(origin, () => { calls++; return denied; });
  const callCount = () => calls;
  const options = await handler(new Request(origin, { method: "OPTIONS", headers: { Origin: origin } }));
  if (options.status !== 204 || callCount() !== 0) throw Error("Preflight invoked business handler");
  const response = await handler(new Request(origin, { method: "POST", headers: { Origin: origin } }));
  if (callCount() !== 1 || response !== denied) throw Error("Authorization response bypassed or replaced");
});
