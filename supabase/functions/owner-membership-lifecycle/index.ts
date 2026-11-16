import { withBrowserCors } from "../_shared/browser-cors.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  lifecycleFailure,
  parseLifecycleCommand,
} from "../_shared/membership-lifecycle.ts";
import { validateOwnerRegisterRequest } from "../_shared/owner-register-request.ts";

const origin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

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

Deno.serve(withBrowserCors(origin, async (request: Request) => {
  if (!origin || !url || !publishableKey || !serviceKey) {
    return respond(503, { error: "SERVER_CONFIGURATION_ERROR" });
  }
  if (request.headers.get("Origin") !== origin) {
    return respond(403, { error: "ORIGIN_NOT_ALLOWED" });
  }
  if (request.method === "OPTIONS") {
    const result = respond(200, {});
    return new Response(null, { status: 204, headers: result.headers });
  }
  const validated = await validateOwnerRegisterRequest(request, origin);
  if (!validated.ok) {
    return respond(validated.status, { error: validated.error });
  }
  try {
    const authClient = createClient(url, publishableKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: userData, error: authError } = await authClient.auth.getUser(
      validated.accessToken,
    );
    if (authError || !userData.user) {
      return respond(401, { error: "INVALID_AUTHENTICATION" });
    }
    let command;
    try {
      command = parseLifecycleCommand(validated.body);
    } catch {
      return respond(400, { error: "INVALID_LIFECYCLE_REQUEST" });
    }
    const serviceClient = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data, error } = await serviceClient.schema("api").rpc(
      command.rpcName,
      { p_actor_user_id: userData.user.id, ...command.args },
    );
    // SQL independently checks that this verified identity remains active Owner.
    if (error) {
      const failure = lifecycleFailure(error.code);
      return respond(failure.status, { error: failure.error });
    }
    if (!data || typeof data !== "object" || !data.id) {
      return respond(503, { error: "LIFECYCLE_UNAVAILABLE" });
    }
    return respond(200, { success: true, [command.outputKey]: data });
  } catch {
    return respond(503, { error: "LIFECYCLE_UNAVAILABLE" });
  }
}));
