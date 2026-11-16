import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { createPinEnrollmentToken } from "../_shared/pin-enrollment.ts";
import {
  parseOwnerPinRecoveryInput,
  readPinRequestBody,
} from "../_shared/pin-recovery.ts";

const appOrigin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// DEVELOPMENT ONLY: Owner production approval and abuse/load testing remain gates.
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
const respond = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers });

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
  if (!enabled || !url || !publishableKey || !serviceKey) return respond(503, { error: "SERVICE_UNAVAILABLE" });
  if (request.method !== "POST") {
    return respond(405, { error: "METHOD_NOT_ALLOWED" });
  }
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ") || !authorization.slice(7).trim()) {
    return respond(401, { error: "AUTHENTICATION_REQUIRED" });
  }
  let input;
  try {
    input = parseOwnerPinRecoveryInput(await readPinRequestBody(request));
  } catch {
    return respond(400, { error: "INVALID_REQUEST" });
  }
  if (!input) return respond(400, { error: "INVALID_REQUEST" });
  try {
    const auth = {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    };
    const authClient = createClient(url, publishableKey, { auth });
    const service = createClient(url, serviceKey, { auth });
    const { data: authData, error: authError } = await authClient.auth.getUser(
      authorization.slice(7).trim(),
    );
    if (authError || !authData.user) {
      return respond(401, { error: "INVALID_AUTHENTICATION" });
    }
    const { rawToken, tokenHash } = await createPinEnrollmentToken();
    const { data, error } = await service.schema("api").rpc(
      "owner_create_pin_recovery_token",
      {
        p_actor_user_id: authData.user.id,
        p_member_id: input.memberId,
        p_token_hash: tokenHash,
        p_reason: input.reason,
      },
    );
    if (error) {
      if (error.code === "42501") {
        return respond(403, { error: "OWNER_ACCESS_REQUIRED" });
      }
      if (error.code === "P0002" || error.code === "22023") {
        return respond(400, { error: "RECOVERY_UNAVAILABLE" });
      }
      return respond(503, { error: "SERVICE_UNAVAILABLE" });
    }
    if (
      !data || typeof data !== "object" || typeof data.expiresAt !== "string" ||
      data.purpose !== "reset" || !Number.isFinite(Date.parse(data.expiresAt))
    ) return respond(503, { error: "SERVICE_UNAVAILABLE" });
    // Returned once to the Owner for the in-person handoff. Never log/cache it.
    return respond(200, {
      token: rawToken,
      expiresAt: data.expiresAt,
      purpose: "reset",
    });
  } catch {
    return respond(503, { error: "SERVICE_UNAVAILABLE" });
  }
});
