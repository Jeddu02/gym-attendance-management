// Real Deno module imports with the server callback captured: no listener, keys,
// Auth calls, data requests or release flags. Tests the disabled deployment path.
Deno.test("release-gated handlers expose unavailable responses after safe preflight", async () => {
  const serveDescriptor = Object.getOwnPropertyDescriptor(Deno, "serve")!;
  const envDescriptor = Object.getOwnPropertyDescriptor(Deno.env, "get")!;
  const origin = "https://gym.example.test";
  let handler: ((request: Request) => Promise<Response>) | undefined;
  Object.defineProperty(Deno, "serve", { configurable: true, writable: true, value: (callback: unknown) => {
    handler = callback as (request: Request) => Promise<Response>;
  } });
  Object.defineProperty(Deno.env, "get", { configurable: true, writable: true, value: (key: string) => key === "APP_ORIGIN" ? origin : undefined });
  try {
    for (const name of ["owner-membership-payments", "owner-walkins", "public-walkin-request", "member-checkin", "member-enroll-pin", "member-reset-pin", "owner-create-pin-enrollment-token", "owner-create-pin-recovery-token"]) {
      handler = undefined;
      await import(new URL(`../${name}/index.ts`, import.meta.url).href);
      const callback = handler as ((request: Request) => Promise<Response>) | undefined;
      if (!callback) throw Error(`${name}: server callback missing`);
      const options = await callback(new Request("https://edge.example.test", { method: "OPTIONS", headers: { Origin: origin } }));
      if (!options.ok || options.headers.get("Access-Control-Allow-Origin") !== origin) throw Error(`${name}: preflight rejected`);
      const denied = await callback(new Request("https://edge.example.test", { method: "OPTIONS", headers: { Origin: "https://untrusted.example.test" } }));
      if (denied.status !== 403) throw Error(`${name}: untrusted origin accepted`);
      const disabled = await callback(new Request("https://edge.example.test", { method: "POST", headers: { Origin: origin } }));
      if (disabled.status !== 503 || disabled.headers.get("Access-Control-Allow-Origin") !== origin || disabled.headers.get("Cache-Control") !== "no-store") throw Error(`${name}: disabled POST not safely exposed`);
    }
  } finally {
    Object.defineProperty(Deno, "serve", serveDescriptor);
    Object.defineProperty(Deno.env, "get", envDescriptor);
  }
});
