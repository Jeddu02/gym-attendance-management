import { createClient } from "npm:@supabase/supabase-js@2";

const allowedOrigin = Deno.env.get("APP_ORIGIN");

const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin ?? "",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (request: Request) => {
  if (!allowedOrigin) {
    return new Response(
      JSON.stringify({ error: "Authorization service unavailable" }),
      {
        status: 503,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-store",
        },
      },
    );
  }
  if (request.headers.get("Origin") !== allowedOrigin) {
    return jsonResponse({ error: "Origin not allowed" }, 403);
  }

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");

  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Authentication required" }, 401);
  }

  const accessToken = authorization.slice("Bearer ".length).trim();

  if (!accessToken) {
    return jsonResponse({ error: "Authentication required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    console.error("Missing required server-side Supabase configuration.");
    return jsonResponse(
      { error: "Authorization service unavailable" },
      503,
    );
  }

  try {
    // Validate the caller's token using Supabase Auth.
    const authClient = createClient(supabaseUrl, publishableKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: userData, error: userError } = await authClient.auth.getUser(
      accessToken,
    );

    if (userError || !userData.user) {
      return jsonResponse({ error: "Invalid or expired session" }, 401);
    }

    // Use the verified user ID only. Never trust a user ID from the request.
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: isActiveOwner, error: ownerError } = await adminClient
      .schema("api")
      .rpc("is_active_owner_for_user", {
        p_user_id: userData.user.id,
      });

    if (ownerError || typeof isActiveOwner !== "boolean") {
      console.error(
        "Owner authorization check failed:",
        ownerError?.message ?? "Unexpected RPC response",
      );

      return jsonResponse(
        { error: "Authorization service unavailable" },
        503,
      );
    }

    return jsonResponse({
      authenticated: true,
      isActiveOwner,
      authorizationReady: true,
    });
  } catch (error) {
    console.error(
      "Owner verification request failed:",
      error instanceof Error ? error.message : "Unknown error",
    );

    return jsonResponse(
      { error: "Authorization service unavailable" },
      503,
    );
  }
});
