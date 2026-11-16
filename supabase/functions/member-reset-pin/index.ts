import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { hashMemberPin } from "../_shared/pin-password.ts";
import {
  hashPinRecoveryToken,
  parseMemberPinResetInput,
  readPinRequestBody,
} from "../_shared/pin-recovery.ts";

const appOrigin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Same development-only gate as issuance. Production thresholds are unapproved.
const enabled = Deno.env.get("PIN_RECOVERY_ENABLED") === "true";
const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "Vary": "Origin",
  "Access-Control-Allow-Origin": appOrigin ?? "",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
};
const respond = (
  status: number,
  body: Record<string, unknown>,
  extra: Record<string, string> = {},
) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, ...extra },
  });

Deno.serve(async (request: Request): Promise<Response> => {
  if (!appOrigin) {
    return respond(503, { error: "SERVICE_UNAVAILABLE" });
  }
  if (request.headers.get("Origin") !== appOrigin) {
    return respond(403, { error: "ORIGIN_NOT_ALLOWED" });
  }
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (!enabled || !url || !serviceKey) return respond(503, { error: "SERVICE_UNAVAILABLE" });
  if (request.method !== "POST") {
    return respond(405, { error: "METHOD_NOT_ALLOWED" });
  }
  let input;
  try {
    input = parseMemberPinResetInput(await readPinRequestBody(request));
  } catch {
    return respond(400, { error: "SETUP_UNAVAILABLE" });
  }
  if (!input) return respond(400, { error: "SETUP_UNAVAILABLE" });
  try {
    const service = createClient(url, serviceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
      global: { headers: { "Cache-Control": "no-store" } },
    });
    // Reuse the existing development rolling-window limiter BEFORE Argon2id.
    const { data: rate, error: rateError } = await service.schema("api").rpc(
      "reserve_pin_enrollment_request",
    );
    if (
      rateError || !rate || typeof rate !== "object" ||
      typeof rate.allowed !== "boolean"
    ) return respond(503, { error: "SERVICE_UNAVAILABLE" });
    if (!rate.allowed) {
      if (
        !Number.isInteger(rate.retryAfterSeconds) ||
        rate.retryAfterSeconds < 1 || rate.retryAfterSeconds > 60
      ) return respond(503, { error: "SERVICE_UNAVAILABLE" });
      return respond(429, { error: "TOO_MANY_REQUESTS" }, {
        "Retry-After": String(rate.retryAfterSeconds),
      });
    }
    if (
      !Number.isInteger(rate.remaining) || rate.remaining < 0 ||
      rate.remaining > 29
    ) return respond(503, { error: "SERVICE_UNAVAILABLE" });
    const tokenHash = await hashPinRecoveryToken(input.token);
    const passwordHash = await hashMemberPin(input.pin);
    const { data, error } = await service.schema("api").rpc(
      "member_reset_pin",
      { p_token_hash: tokenHash, p_password_hash: passwordHash },
    );
    if (error) {
      if (error.code === "P0001" || error.code === "22023") {
        return respond(400, { error: "SETUP_UNAVAILABLE" });
      }
      return respond(503, { error: "SERVICE_UNAVAILABLE" });
    }
    if (!data || typeof data !== "object" || data.success !== true) {
      return respond(503, { error: "SERVICE_UNAVAILABLE" });
    }
    return respond(200, { success: true, message: "PIN_RESET_COMPLETE" });
  } catch {
    return respond(503, { error: "SERVICE_UNAVAILABLE" });
  }
});
