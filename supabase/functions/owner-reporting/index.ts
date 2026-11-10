import { createClient } from "npm:@supabase/supabase-js@2";
import { validateOwnerRegisterRequest } from "../_shared/owner-register-request.ts";
import { parseReportCommand } from "../_shared/owner-reporting.ts";
const origin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
const serverKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
function respond(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": origin ?? "",
      "Access-Control-Allow-Headers":
        "authorization, apikey, content-type, x-client-info",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Vary": "Origin",
    },
  });
}
Deno.serve(async (request: Request) => {
  if (!origin || !url || !publicKey || !serverKey) {
    return respond(503, { error: "SERVER_CONFIGURATION_ERROR" });
  }
  if (request.headers.get("Origin") !== origin) {
    return respond(403, { error: "ORIGIN_NOT_ALLOWED" });
  }
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: respond(200, {}).headers,
    });
  }
  const validated = await validateOwnerRegisterRequest(request, origin);
  if (!validated.ok) {
    return respond(validated.status, { error: validated.error });
  }
  try {
    const authClient = createClient(url, publicKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: authError } = await authClient.auth.getUser(
      validated.accessToken,
    );
    if (authError || !userData.user) {
      return respond(401, { error: "INVALID_AUTHENTICATION" });
    }
    let command;
    try {
      command = parseReportCommand(validated.body);
    } catch {
      return respond(400, { error: "INVALID_REPORT_REQUEST" });
    }
    const serviceClient = createClient(url, serverKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await serviceClient.schema("api").rpc(
      command.rpcName,
      { p_actor_user_id: userData.user.id, ...command.args },
    );
    if (error) {
      return respond(
        error.code === "42501" ? 403 : error.code === "22023" ? 400 : 503,
        {
          error: error.code === "42501"
            ? "OWNER_ACCESS_REQUIRED"
            : "REPORT_UNAVAILABLE",
        },
      );
    }
    if (
      data === null ||
      (["events", "income", "expiries"].includes(command.outputKey) && !Array.isArray(data)) ||
      (command.outputKey === "summary" &&
        (typeof data !== "object" || Array.isArray(data)))
    ) return respond(503, { error: "REPORT_UNAVAILABLE" });
    return respond(200, { success: true, [command.outputKey]: data });
  } catch {
    return respond(503, { error: "REPORT_UNAVAILABLE" });
  }
});
