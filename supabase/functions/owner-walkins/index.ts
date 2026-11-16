import { withBrowserCors } from "../_shared/browser-cors.ts";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { readPinRequestBody } from "../_shared/pin-recovery.ts";
import { parseOwnerWalkinInput } from "../_shared/walkin-request.ts";

const appOrigin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const headers = {
  "Content-Type": "application/json", "Cache-Control": "no-store", "Vary": "Origin",
  "Access-Control-Allow-Origin": appOrigin ?? "",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};
const respond = (status: number, body: Record<string, unknown>) => new Response(JSON.stringify(body), { status, headers });

Deno.serve(withBrowserCors(appOrigin, async (request: Request): Promise<Response> => {
  if (!appOrigin) return respond(503, { error: "SERVICE_UNAVAILABLE" });
  if (request.headers.get("Origin") !== appOrigin) return respond(403, { error: "ORIGIN_NOT_ALLOWED" });
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (!url || !publishableKey || !serviceKey) return respond(503, { error: "SERVICE_UNAVAILABLE" });
  if (request.method !== "POST") return respond(405, { error: "METHOD_NOT_ALLOWED" });
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ") || !authorization.slice(7).trim()) return respond(401, { error: "AUTHENTICATION_REQUIRED" });
  let input;
  try { input = parseOwnerWalkinInput(await readPinRequestBody(request)); }
  catch { return respond(400, { error: "INVALID_REQUEST" }); }
  if (!input) return respond(400, { error: "INVALID_REQUEST" });
  try {
    const auth = { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false };
    const authClient = createClient(url, publishableKey, { auth });
    const service = createClient(url, serviceKey, { auth });
    const { data: authData, error: authError } = await authClient.auth.getUser(authorization.slice(7).trim());
    if (authError || !authData.user) return respond(401, { error: "INVALID_AUTHENTICATION" });
    // Actor identity comes exclusively from verified Auth, never the payload.
    const args: Record<string, unknown> = { p_actor_user_id: authData.user.id };
    let rpc: string;
    if (input.action === "fee") {
      rpc = "owner_set_walkin_fee";
      Object.assign(args, { p_fee_php: input.feePhp, p_reason: input.reason });
    } else if (input.action === "list") {
      rpc = "owner_list_walkin_requests";
      Object.assign(args, { p_limit: input.limit, p_offset: input.offset });
    } else {
      rpc = "owner_confirm_walkin";
      Object.assign(args, {
        p_request_id: input.requestId, p_operation_id: input.operationId,
        p_amount_php: input.amountPhp, p_payment_method: input.paymentMethod,
        p_evidence_reviewed: input.evidenceReviewed,
      });
    }
    const { data, error } = await service.schema("api").rpc(rpc, args);
    if (error) {
      if (error.code === "42501") return respond(403, { error: "OWNER_ACCESS_REQUIRED" });
      if (error.code === "22023") return respond(400, { error: "INVALID_WALKIN_REQUEST" });
      if (error.code === "P0002") return respond(404, { error: "WALKIN_REQUEST_UNAVAILABLE" });
      if (["P0001", "23505", "23514"].includes(error.code)) return respond(409, { error: "WALKIN_CONFLICT" });
      console.error("Owner walk-in RPC unavailable", /^[A-Z0-9]{5,10}$/.test(error.code ?? "") ? error.code : "UNKNOWN");
      return respond(503, { error: "SERVICE_UNAVAILABLE" });
    }
    if (data === null || typeof data !== "object" || (input.action === "list" && !Array.isArray(data))) return respond(503, { error: "SERVICE_UNAVAILABLE" });
    if (input.action === "fee") return respond(200, { success: true, fee: data });
    if (input.action === "list") return respond(200, { success: true, requests: data });
    return respond(200, { success: true, result: data });
  } catch { return respond(503, { error: "SERVICE_UNAVAILABLE" }); }
}));
