import { createClient } from "npm:@supabase/supabase-js@2";

import {
  createPinEnrollmentToken,
  isValidMemberId,
} from "../_shared/pin-enrollment.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");

const publishableKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY");

const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const appOrigin = Deno.env.get("APP_ORIGIN");
const pinSetupEnabled = Deno.env.get("PIN_SETUP_ENABLED") === "true";

const corsHeaders = {
  "Access-Control-Allow-Origin": appOrigin ?? "",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
  "Cache-Control": "no-store",
};

function respond(
  status: number,
  body: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
async function readLimitedBody(
  request: Request,
  maxBytes: number,
): Promise<{ ok: true; text: string } | { ok: false }> {
  const reader = request.body?.getReader();

  if (!reader) {
    return { ok: true, text: "" };
  }

  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();

      if (done) break;

      totalBytes += value.byteLength;

      if (totalBytes > maxBytes) {
        await reader.cancel();
        return { ok: false };
      }

      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const combined = new Uint8Array(totalBytes);
  let offset = 0;

  for (const chunk of chunks) {
    combined.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return {
    ok: true,
    text: new TextDecoder().decode(combined),
  };
}
Deno.serve(async (request) => {
  if (!appOrigin) {
    return new Response(
      JSON.stringify({ error: "SERVER_CONFIGURATION_ERROR" }),
      {
        status: 503,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-store",
        },
      },
    );
  }

  if (request.headers.get("Origin") !== appOrigin) {
    return respond(403, { error: "ORIGIN_NOT_ALLOWED" });
  }
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (!pinSetupEnabled) return respond(503, { error: "SERVICE_UNAVAILABLE" });

  if (request.method !== "POST") {
    return respond(405, { error: "METHOD_NOT_ALLOWED" });
  }

  const authorization = request.headers.get("Authorization");

  if (!authorization?.startsWith("Bearer ")) {
    return respond(401, { error: "AUTHENTICATION_REQUIRED" });
  }

  const accessToken = authorization.slice(7).trim();

  if (!accessToken) {
    return respond(401, { error: "AUTHENTICATION_REQUIRED" });
  }

  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    return respond(500, { error: "SERVER_CONFIGURATION_ERROR" });
  }
  if (
    request.headers.get("Content-Type")?.split(";")[0].trim().toLowerCase() !==
      "application/json"
  ) {
    return respond(415, { error: "UNSUPPORTED_MEDIA_TYPE" });
  }

  const contentLength = request.headers.get("Content-Length");

  if (contentLength !== null) {
    const length = Number(contentLength);

    if (!Number.isSafeInteger(length) || length < 0) {
      return respond(400, { error: "INVALID_CONTENT_LENGTH" });
    }

    if (length > 2048) {
      return respond(413, { error: "REQUEST_TOO_LARGE" });
    }
  }
  let body: unknown;

  try {
    const result = await readLimitedBody(request, 2048);

    if (!result.ok) {
      return respond(413, { error: "REQUEST_TOO_LARGE" });
    }

    body = JSON.parse(result.text);
  } catch {
    return respond(400, { error: "INVALID_REQUEST_BODY" });
  }

  if (
    typeof body !== "object" ||
    body === null ||
    Array.isArray(body)
  ) {
    return respond(400, { error: "INVALID_REQUEST_BODY" });
  }

  const input = body as Record<string, unknown>;

  if (
    Object.keys(input).length !== 3 ||
    !isValidMemberId(input.memberId) || input.identityVerified !== true ||
    typeof input.reason !== "string" || input.reason.trim().length < 5 ||
    input.reason.length > 500
  ) {
    return respond(400, { error: "INVALID_MEMBER_ID" });
  }

  try {
    const authClient = createClient(supabaseUrl, publishableKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Verify the actual user represented by the access token.
    const { data: authData, error: authError } = await authClient.auth.getUser(
      accessToken,
    );

    if (authError || !authData.user) {
      return respond(401, { error: "INVALID_AUTHENTICATION" });
    }

    // Generate a cryptographically random one-time token.
    const { rawToken, tokenHash } = await createPinEnrollmentToken();

    // The database independently verifies active owner status.
    const { data, error } = await serviceClient
      .schema("api")
      .rpc("owner_create_verified_pin_enrollment_token", {
        p_actor_user_id: authData.user.id,
        p_member_id: input.memberId,
        p_token_hash: tokenHash,
        p_reason: input.reason.trim(),
      });

    if (error) {
      if (error.code === "42501") {
        return respond(403, { error: "OWNER_ACCESS_REQUIRED" });
      }

      if (error.code === "P0002") {
        return respond(404, { error: "MEMBER_NOT_ELIGIBLE" });
      }

      if (error.code === "22023") {
        return respond(400, { error: "INVALID_ENROLLMENT_REQUEST" });
      }

      return respond(500, { error: "TOKEN_CREATION_FAILED" });
    }

    if (!data || typeof data !== "object" || typeof data.expires_at !== "string") {
      return respond(500, { error: "TOKEN_CREATION_FAILED" });
    }

    // Return the raw token once. Never store or log it.
    return respond(200, {
      token: rawToken,
      expiresAt: data.expires_at,
      purpose: "enrollment",
    });
  } catch {
    return respond(500, { error: "INTERNAL_SERVER_ERROR" });
  }
});
