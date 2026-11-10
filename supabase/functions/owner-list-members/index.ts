import { createClient } from "npm:@supabase/supabase-js@2";

const allowedOrigin = Deno.env.get("APP_ORIGIN");
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin ?? "",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
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

async function readLimitedBody(request: Request): Promise<unknown> {
  const reader = request.body?.getReader();
  if (!reader) throw new Error("INVALID_BODY");

  const chunks: Uint8Array[] = [];
  let total = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > 2048) {
        await reader.cancel();
        throw new Error("BODY_TOO_LARGE");
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
  return JSON.parse(new TextDecoder().decode(bytes));
}

Deno.serve(async (request: Request) => {
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

  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return respond(401, { error: "AUTHENTICATION_REQUIRED" });
  }
  const accessToken = authorization.slice(7).trim();
  if (!accessToken) return respond(401, { error: "AUTHENTICATION_REQUIRED" });

  let input: Record<string, unknown>;
  try {
    const body = await readLimitedBody(request);
    if (typeof body !== "object" || body === null || Array.isArray(body)) {
      return respond(400, { error: "INVALID_REQUEST_BODY" });
    }
    input = body as Record<string, unknown>;
  } catch (error) {
    return respond(
      error instanceof Error && error.message === "BODY_TOO_LARGE" ? 413 : 400,
      { error: "INVALID_REQUEST_BODY" },
    );
  }

  const allowedKeys = new Set(["search", "status", "limit", "offset"]);
  if (Object.keys(input).some((key) => !allowedKeys.has(key))) {
    return respond(400, { error: "INVALID_REQUEST_BODY" });
  }

  const search = input.search ?? "";
  const status = input.status ?? "all";
  const limit = input.limit ?? 50;
  const offset = input.offset ?? 0;

  if (
    typeof search !== "string" || search.length > 80 ||
    typeof status !== "string" ||
    !["all", "pending", "active", "suspended"].includes(status) ||
    !Number.isInteger(limit) || (limit as number) < 1 ||
    (limit as number) > 100 ||
    !Number.isInteger(offset) || (offset as number) < 0 ||
    (offset as number) > 100000
  ) {
    return respond(400, { error: "INVALID_MEMBER_FILTER" });
  }

  try {
    const authClient = createClient(supabaseUrl, publishableKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: authData, error: authError } = await authClient.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) {
      return respond(401, { error: "INVALID_AUTHENTICATION" });
    }

    const { data, error } = await serviceClient
      .schema("api")
      .rpc("owner_list_members", {
        p_actor_user_id: authData.user.id,
        p_search: search || null,
        p_status: status,
        p_limit: limit,
        p_offset: offset,
      });

    if (error) {
      if (error.code === "42501") {
        return respond(403, { error: "OWNER_ACCESS_REQUIRED" });
      }
      console.error("Owner member-list RPC failed:", error.code ?? "UNKNOWN");
      return respond(500, { error: "MEMBER_LIST_UNAVAILABLE" });
    }

    return respond(200, {
      members: Array.isArray(data) ? data : [],
    });
  } catch (error) {
    console.error(
      "Owner member-list request failed:",
      error instanceof Error ? error.name : "UNKNOWN",
    );
    return respond(500, { error: "INTERNAL_SERVER_ERROR" });
  }
});
