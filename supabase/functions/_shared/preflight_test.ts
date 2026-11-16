// Actual entrypoints, synthetic configuration, captured callbacks, no listeners/network.
const endpoints = ["member-checkin","member-enroll-pin","member-reset-pin","owner-attendance","owner-attendance-claims","owner-cash","owner-create-membership-purchase","owner-create-pin-enrollment-token","owner-create-pin-recovery-token","owner-list-members","owner-list-membership-plans","owner-list-membership-purchases","owner-membership-lifecycle","owner-membership-payments","owner-receipt-review","owner-register-member","owner-reporting","owner-save-membership-plan","owner-status","owner-walkins","public-walkin-request"];
const origin = "https://gym.example.test";
function check(value: unknown, label: string): asserts value { if (!value) throw Error(label); }
function noCors(response: Response, label: string) {
  check(![...response.headers.keys()].some(key => key.startsWith("access-control-allow-")), label + ": CORS allow headers leaked");
  check(response.headers.get("Cache-Control") === "no-store", label + ": no-store missing");
}
Deno.test("all 21 entrypoints enforce preflight, exact origin, missing configuration, Auth and release gates", async () => {
  const discovered: string[] = [];
  for await (const entry of Deno.readDir(new URL("../", import.meta.url))) {
    if (entry.isDirectory && entry.name !== "_shared") {
      await Deno.stat(new URL("../" + entry.name + "/index.ts", import.meta.url));
      discovered.push(entry.name);
    }
  }
  check(discovered.length === 21 && JSON.stringify(discovered.sort()) === JSON.stringify([...endpoints].sort()), "Entrypoint inventory changed; update coverage");
  const serveDescriptor = Object.getOwnPropertyDescriptor(Deno, "serve")!;
  const envDescriptor = Object.getOwnPropertyDescriptor(Deno.env, "get")!;
  const originalFetch = globalThis.fetch;
  let env: Record<string,string> = {};
  let handler: ((request: Request) => Response | Promise<Response>) | undefined;
  let fetches = 0;
  globalThis.fetch = (() => { fetches++; throw Error("Unexpected network attempt"); }) as typeof fetch;
  Object.defineProperty(Deno, "serve", { configurable: true, writable: true, value: (callback: unknown) => { handler = callback as typeof handler; } });
  Object.defineProperty(Deno.env, "get", { configurable: true, writable: true, value: (key: string) => env[key] });
  try {
    for (const scenario of ["origin-only", "configured", "missing-origin-config"]) {
      env = scenario === "missing-origin-config" ? {} : { APP_ORIGIN: origin };
      if (scenario === "configured") Object.assign(env, { SUPABASE_URL: "https://backend.example.test", SUPABASE_ANON_KEY: "synthetic-public", SUPABASE_SERVICE_ROLE_KEY: "synthetic-server" });
      else Object.assign(env, { PIN_SETUP_ENABLED: "true", PIN_RECOVERY_ENABLED: "true", PUBLIC_WALKIN_ENABLED: "true", PUBLIC_MEMBER_CHECKIN_ENABLED: "true", OWNER_OFFLINE_REVIEW_ENABLED: "true" });
      for (const name of endpoints) {
        handler = undefined;
        await import(new URL("../" + name + "/index.ts?cors-regression=" + scenario, import.meta.url).href);
        const callback = handler as ((request: Request) => Response | Promise<Response>) | undefined;
        check(callback, name + ": callback missing");
        const label = name + "/" + scenario;
        const options = await callback(new Request("https://edge.example.test", { method: "OPTIONS", headers: { Origin: origin, "Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "authorization, apikey, content-type, x-client-info" } }));
        if (scenario === "missing-origin-config") { check(options.status === 503, label + ": missing origin config accepted"); noCors(options,label); }
        else {
          check(options.status === 204, label + ": preflight rejected");
          check(options.headers.get("Access-Control-Allow-Origin") === origin, label + ": wrong origin");
          check(options.headers.get("Access-Control-Allow-Methods") === "POST, OPTIONS", label + ": wrong methods");
          check(options.headers.get("Vary") === "Origin" && options.headers.get("Cache-Control") === "no-store", label + ": unsafe cache");
          const allowed = (options.headers.get("Access-Control-Allow-Headers") ?? "").split(/,\s*/);
          for (const header of ["authorization", "apikey", "content-type", "x-client-info"]) check(allowed.includes(header), label + ": missing header " + header);
          check(!options.headers.has("Access-Control-Allow-Credentials"), label + ": credentials allowed");
          for (const badOrigin of ["https://untrusted.example.test", origin + ".evil.test", "null", undefined]) for (const method of ["OPTIONS", "POST"]) {
            const denied = await callback(new Request("https://edge.example.test", { method, headers: badOrigin === undefined ? {} : { Origin: badOrigin } }));
            check(denied.status === 403, label + ": denied origin accepted"); noCors(denied,label);
          }
        }
        const post = await callback(new Request("https://edge.example.test", { method: "POST", headers: { Origin: origin, "Content-Type": "application/json", ...(scenario === "origin-only" ? { Authorization: "Bearer synthetic-token" } : {}) }, body: "{}" }));
        if (scenario === "configured") {
          const gated = ["member-checkin", "member-enroll-pin", "member-reset-pin", "public-walkin-request", "owner-create-pin-enrollment-token", "owner-create-pin-recovery-token", "owner-attendance-claims"].includes(name);
          check(post.status === (gated ? 503 : 401), label + ": Auth/release bypass " + post.status);
        } else check([500,503].includes(post.status), label + ": missing config allowed POST");
        if (scenario === "missing-origin-config") noCors(post,label);
      }
    }
    check(fetches === 0, "Preflight/rejected/disabled request attempted network access");
  } finally {
    globalThis.fetch = originalFetch;
    Object.defineProperty(Deno, "serve", serveDescriptor);
    Object.defineProperty(Deno.env, "get", envDescriptor);
  }
});
