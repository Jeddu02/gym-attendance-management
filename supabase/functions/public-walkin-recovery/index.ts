import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { withBrowserCors } from "../_shared/browser-cors.ts";
import { readPinRequestBody } from "../_shared/pin-recovery.ts";
import { parseWalkinRequestLimit } from "../_shared/walkin-request.ts";
import { capabilityDigest, parseRecoveryInput, recoveryResponse } from "../_shared/walkin-recovery.ts";

const origin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const enabled = Deno.env.get("PUBLIC_WALKIN_ENABLED") === "true";
const limit = parseWalkinRequestLimit(Deno.env.get("WALKIN_REQUEST_LIMIT_PER_MINUTE"));
let isolatedBackend = false;
try { isolatedBackend = ["127.0.0.1", "localhost", "[::1]"].includes(new URL(url ?? "").hostname); } catch { /* fail closed */ }
// Local implementation only: the all-attempt ingress architecture/limits remain
// an explicit release blocker. Do not enable this bundle on hosted systems.
Deno.serve(withBrowserCors(origin, async (request: Request) => {
  const respond = (status: number, body: Record<string, unknown>) => new Response(JSON.stringify(body), {
    status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store", "Vary": "Origin", "Access-Control-Allow-Origin": origin! },
  });
  if (request.method !== "POST") return respond(405, { error: "REQUEST_UNAVAILABLE" });
  if (!isolatedBackend || !enabled || !url || !key || !limit) return respond(503, { error: "REQUEST_UNAVAILABLE" });
  let input;
  try { input = parseRecoveryInput(await readPinRequestBody(request)); }
  catch { return respond(400, { error: "INVALID_REQUEST" }); }
  if (!input) return respond(400, { error: "INVALID_REQUEST" });
  try {
    const digest = await capabilityDigest(input.capability);
    const service = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
    const { data, error } = await service.schema("api").rpc(
      input.action === "create" ? "public_create_walkin_request_v2" : "public_lookup_walkin_request",
      input.action === "create" ? { p_capability_digest: digest, p_payment_method: input.paymentMethod, p_request_limit: limit }
        : { p_capability_digest: digest },
    );
    if (error) return respond(error.code === "P0001" && error.message === "WALKIN_RATE_LIMITED" ? 429 : 503, { error: "REQUEST_UNAVAILABLE" });
    const result = recoveryResponse(data, input);
    return result ? respond(result.status, result.body) : respond(503, { error: "REQUEST_UNAVAILABLE" });
  } catch { return respond(503, { error: "REQUEST_UNAVAILABLE" }); }
}));
