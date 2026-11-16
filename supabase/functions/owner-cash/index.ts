import { withBrowserCors } from "../_shared/browser-cors.ts";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { validateOwnerRegisterRequest } from "../_shared/owner-register-request.ts";
import { cashOperation } from "../_shared/cash-operations.ts";

const origin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const publicKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
const serverKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const headers = { "Content-Type": "application/json", "Cache-Control": "no-store", "Vary": "Origin",
  "Access-Control-Allow-Origin": origin ?? "", "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info" };
const respond = (status: number, body: Record<string, unknown>) => new Response(JSON.stringify(body), { status, headers });

Deno.serve(withBrowserCors(origin, async (request: Request): Promise<Response> => {
  if (!origin || !url || !publicKey || !serverKey) return respond(503, { error: "SERVICE_UNAVAILABLE" });
  if (request.headers.get("Origin") !== origin) return respond(403, { error: "ORIGIN_NOT_ALLOWED" });
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  const validated = await validateOwnerRegisterRequest(request, origin);
  if (!validated.ok) return respond(validated.status, { error: validated.error });
  try {
    let operation;
    try { operation = cashOperation(validated.body); } catch { return respond(400, { error: "INVALID_REQUEST" }); }
    const auth = { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false };
    const authClient = createClient(url, publicKey, { auth });
    const { data: authData, error: authError } = await authClient.auth.getUser(validated.accessToken);
    if (authError || !authData.user) return respond(401, { error: "INVALID_AUTHENTICATION" });
    const server = createClient(url, serverKey, { auth });
    const { data, error } = await server.schema("api").rpc(operation.rpc, { ...operation.args, p_actor_user_id: authData.user.id });
    if (error) return respond(error.code === "42501" ? 403 : error.code === "22023" ? 409 : error.code === "P0002" ? 404 : 503,
      { error: error.code === "42501" ? "OWNER_ACCESS_REQUIRED" : "CASH_REVIEW_UNAVAILABLE" });
    return respond(200, { success: true, result: data });
  } catch { return respond(503, { error: "SERVICE_UNAVAILABLE" }); }
}));
