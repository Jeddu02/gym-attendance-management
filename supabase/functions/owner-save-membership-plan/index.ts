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
  if (!body) {
    return respond(400, { error: "INVALID_REQUEST_BODY" });
  }

  const allowedKeys = new Set(["id", "name", "pricePhp", "isActive"]);

  if (Object.keys(body).some((key) => !allowedKeys.has(key))) {
    return respond(400, { error: "INVALID_REQUEST_BODY" });
  }

  const id = body.id ?? null;
  const name = body.name;

  const priceText = typeof body.pricePhp === "string"
    ? body.pricePhp
    : typeof body.pricePhp === "number" && Number.isFinite(body.pricePhp)
    ? String(body.pricePhp)
    : "";

  const priceNumber = Number(priceText);

  const validUuid = typeof id === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(id);

  if (
    (id !== null && !validUuid) ||
    typeof name !== "string" ||
    name.trim().length === 0 ||
    name.length > 120 ||
    !/^\d{1,10}(?:\.\d{1,2})?$/.test(priceText) ||
    !Number.isFinite(priceNumber) ||
    priceNumber <= 0 ||
    priceNumber > 9999999999.99 ||
    typeof body.isActive !== "boolean"
  ) {
    return respond(400, { error: "INVALID_MEMBERSHIP_PLAN" });
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
      .rpc("owner_save_membership_plan", {
        p_actor_user_id: authData.user.id,
        p_plan_id: id,
        p_name: name,
        p_price_php: priceText,
        p_is_active: body.isActive,
      });

    if (error) {
      if (error.code === "42501") {
        return respond(403, { error: "OWNER_ACCESS_REQUIRED" });
      }

      if (error.message.includes("MEMBERSHIP_PLAN_NAME_EXISTS")) {
        return respond(409, { error: "MEMBERSHIP_PLAN_NAME_EXISTS" });
      }

      if (error.message.includes("MEMBERSHIP_PLAN_NOT_FOUND")) {
        return respond(404, { error: "MEMBERSHIP_PLAN_NOT_FOUND" });
      }

      if (error.code === "22023") {
        return respond(400, { error: "INVALID_MEMBERSHIP_PLAN" });
      }

      console.error("Membership plan save RPC failed:", error.code ?? "UNKNOWN");
      return respond(500, { error: "MEMBERSHIP_PLAN_SAVE_UNAVAILABLE" });
    }

    return respond(200, {
      success: true,
      plan: data,
    });
  } catch (error) {
    console.error(
      "Membership plan save failed:",
      error instanceof Error ? error.name : "UNKNOWN",
    );

    return respond(500, { error: "INTERNAL_SERVER_ERROR" });
  }
});
