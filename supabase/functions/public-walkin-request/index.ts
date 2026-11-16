import { withBrowserCors } from "../_shared/browser-cors.ts";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { readPinRequestBody } from "../_shared/pin-recovery.ts";
import { isValidMemberId } from "../_shared/pin-enrollment.ts";
import { parsePositiveWalkinPhp, parsePublicWalkinInput, parseWalkinRequestLimit } from "../_shared/walkin-request.ts";

const appOrigin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Global development abuse control only. Production shared-network/DoS tests
// and Owner-controlled release configuration remain required before enabling.
const enabled = Deno.env.get("PUBLIC_WALKIN_ENABLED") === "true";
const requestLimit = parseWalkinRequestLimit(Deno.env.get("WALKIN_REQUEST_LIMIT_PER_MINUTE"));
const headers = {
  "Content-Type": "application/json", "Cache-Control": "no-store", "Vary": "Origin",
  "Access-Control-Allow-Origin": appOrigin ?? "",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};
const respond = (status: number, body: Record<string, unknown>) => new Response(JSON.stringify(body), { status, headers });

Deno.serve(withBrowserCors(appOrigin, async (request: Request): Promise<Response> => {
  if (!appOrigin) return respond(503, { error: "REQUEST_UNAVAILABLE" });
  if (request.headers.get("Origin") !== appOrigin) return respond(403, { error: "REQUEST_UNAVAILABLE" });
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (!enabled || !requestLimit || !url || !serviceKey) return respond(503, { error: "REQUEST_UNAVAILABLE" });
  if (request.method !== "POST") return respond(405, { error: "REQUEST_UNAVAILABLE" });
  let input;
  try { input = parsePublicWalkinInput(await readPinRequestBody(request)); }
  catch { return respond(400, { error: "REQUEST_UNAVAILABLE" }); }
  if (!input) return respond(400, { error: "REQUEST_UNAVAILABLE" });
  try {
    const service = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
      global: { headers: { "Cache-Control": "no-store" } },
    });
    // SQL assigns fee version, PHP amount, UUID and server timestamps atomically
    // with its rolling global reservation. No forwarded IP is trusted here.
    const { data, error } = await service.schema("api").rpc("public_create_walkin_request", {
      p_payment_method: input.paymentMethod, p_request_limit: requestLimit,
    });
    if (error) {
      if (error.code === "P0001" && error.message === "WALKIN_RATE_LIMITED") return respond(429, { error: "REQUEST_UNAVAILABLE" });
      console.error("Public walk-in RPC unavailable", error.message === "WALKIN_FEE_UNAVAILABLE" ? "WALKIN_FEE_UNAVAILABLE" : /^[A-Z0-9]{5,10}$/.test(error.code ?? "") ? error.code : "UNKNOWN");
      return respond(503, { error: "REQUEST_UNAVAILABLE" });
    }
    if (!data || typeof data !== "object" || Array.isArray(data) ||
      !isValidMemberId(data.id) || data.currency !== "PHP" || data.paymentMethod !== input.paymentMethod ||
      typeof data.createdAt !== "string" || typeof data.expiresAt !== "string" ||
      !Number.isFinite(Date.parse(data.createdAt)) || !Number.isFinite(Date.parse(data.expiresAt)) ||
      Date.parse(data.expiresAt) <= Date.parse(data.createdAt) ||
      !["number", "string"].includes(typeof data.feePhp) ||
      !parsePositiveWalkinPhp(String(data.feePhp))) return respond(503, { error: "REQUEST_UNAVAILABLE" });
    // Allowlist only this caller's provisional, nonpersonal request metadata.
    return respond(200, { success: true, request: {
      id: data.id, feePhp: data.feePhp, currency: "PHP", paymentMethod: data.paymentMethod,
      createdAt: data.createdAt, expiresAt: data.expiresAt,
    } });
  } catch { return respond(503, { error: "REQUEST_UNAVAILABLE" }); }
}));
