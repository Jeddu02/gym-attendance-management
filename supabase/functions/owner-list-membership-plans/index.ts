import { createClient } from "npm:@supabase/supabase-js@2";

const allowedOrigin = Deno.env.get("APP_ORIGIN");
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin ?? "",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function checkRequest(request: Request): Response | null {
  if (!allowedOrigin || !supabaseUrl || !publishableKey || !serviceRoleKey) {
    return respond(503, { error: "SERVER_CONFIGURATION_ERROR" });
  }

  if (request.headers.get("Origin") !== allowedOrigin) {
    return respond(403, { error: "ORIGIN_NOT_ALLOWED" });
  }

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return respond(405, { error: "METHOD_NOT_ALLOWED" });
  }

  const contentType = request.headers.get("Content-Type") ?? "";
  if (contentType.split(";")[0].trim().toLowerCase() !== "application/json") {
    return respond(415, { error: "UNSUPPORTED_MEDIA_TYPE" });
  }

  return null;
}

async function readJson(request: Request): Promise<Record<string, unknown> | null> {
  const reader = request.body?.getReader();
  if (!reader) return null;

  const chunks: Uint8Array[] = [];
  let total = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      total += value.length;
      if (total > 2048) {
        await reader.cancel();
        return null;
      }

      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(total);
  let offset = 0;

  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }

  try {
    const value: unknown = JSON.parse(new TextDecoder().decode(bytes));

    if (typeof value !== "object" || value === null || Array.isArray(value)) {
      return null;
    }

    return value as Record<string, unknown>;
  } catch {
    return null;
  }
}

function bearerToken(request: Request): string | null {
  const value = request.headers.get("Authorization") ?? "";

  if (!value.startsWith("Bearer ")) return null;

  return value.slice(7).trim() || null;
}

Deno.serve(async (request: Request) => {
  const early = checkRequest(request);
  if (early) return early;

  const token = bearerToken(request);
  if (!token) {
    return respond(401, { error: "AUTHENTICATION_REQUIRED" });
  }

  const body = await readJson(request);
  if (!body || Object.keys(body).length !== 0) {
    return respond(400, { error: "INVALID_REQUEST_BODY" });
  }

  try {
    const authClient = createClient(supabaseUrl!, publishableKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const serviceClient = createClient(supabaseUrl!, serviceRoleKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: authData, error: authError } =
      await authClient.auth.getUser(token);

    if (authError || !authData.user) {
      return respond(401, { error: "INVALID_AUTHENTICATION" });
    }

    const { data, error } = await serviceClient
      .schema("api")
      .rpc("owner_list_membership_plans", {
        p_actor_user_id: authData.user.id,
      });

    if (error) {
      if (error.code === "42501") {
        return respond(403, { error: "OWNER_ACCESS_REQUIRED" });
      }

      console.error("Membership plan list RPC failed:", error.message);
      return respond(500, { error: "MEMBERSHIP_PLAN_LIST_UNAVAILABLE" });
    }

    return respond(200, {
      plans: Array.isArray(data) ? data : [],
    });
  } catch (error) {
    console.error(
      "Membership plan list failed:",
      error instanceof Error ? error.message : "Unknown error",
    );

    return respond(500, { error: "INTERNAL_SERVER_ERROR" });
  }
});
