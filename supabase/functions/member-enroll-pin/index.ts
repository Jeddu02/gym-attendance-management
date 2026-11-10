import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { hashMemberPin, validateMemberPin } from "../_shared/pin-password.ts";
import { readPinRequestBody } from "../_shared/pin-recovery.ts";

const APP_ORIGIN = Deno.env.get("APP_ORIGIN");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const PIN_SETUP_ENABLED = Deno.env.get("PIN_SETUP_ENABLED") === "true";

const corsHeaders = {
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Cache-Control": "no-store",
  "Content-Type": "application/json",
  "Vary": "Origin",
};

function response(
  status: number,
  body: Record<string, unknown>,
  origin?: string,
  extraHeaders?: Record<string, string>,
): Response {
  const headers = new Headers(corsHeaders);

  if (origin && origin === APP_ORIGIN) {
    headers.set("Access-Control-Allow-Origin", origin);
  }

  for (const [key, value] of Object.entries(extraHeaders ?? {})) {
    headers.set(key, value);
  }

  return new Response(JSON.stringify(body), { status, headers });
}

async function hashEnrollmentToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );

  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get("origin") ?? undefined;

  if (!APP_ORIGIN || !SUPABASE_URL || !SERVICE_ROLE_KEY || !PIN_SETUP_ENABLED) {
    return response(503, { error: "SERVICE_UNAVAILABLE" });
  }

  if (origin && origin !== APP_ORIGIN) {
    return response(403, { error: "ORIGIN_NOT_ALLOWED" });
  }

  if (request.method === "OPTIONS") {
    if (origin !== APP_ORIGIN) {
      return new Response(null, { status: 403 });
    }

    return new Response(null, {
      status: 204,
      headers: {
        ...corsHeaders,
        "Access-Control-Allow-Origin": origin,
      },
    });
  }

  if (request.method !== "POST") {
    return response(405, { error: "METHOD_NOT_ALLOWED" }, origin);
  }

  const contentLength = request.headers.get("content-length");

  if (contentLength !== null) {
    const declaredLength = Number(contentLength);

    if (!Number.isSafeInteger(declaredLength) || declaredLength < 0) {
      return response(400, { error: "INVALID_REQUEST" }, origin);
    }

    if (declaredLength > 2048) {
      return response(413, { error: "REQUEST_TOO_LARGE" }, origin);
    }
  }

  let body: unknown;

  try {
    body = await readPinRequestBody(request);
  } catch {
    return response(400, { error: "INVALID_REQUEST" }, origin);
  }

  if (
    typeof body !== "object" ||
    body === null ||
    Array.isArray(body)
  ) {
    return response(400, { error: "INVALID_REQUEST" }, origin);
  }

  const payload = body as Record<string, unknown>;
  const keys = Object.keys(payload).sort();

  if (
    keys.length !== 2 ||
    keys[0] !== "pin" ||
    keys[1] !== "token" ||
    typeof payload.token !== "string" ||
    payload.token.length < 40 ||
    payload.token.length > 128 ||
    !/^[A-Za-z0-9_-]+$/u.test(payload.token) ||
    !validateMemberPin(payload.pin)
  ) {
    return response(400, { error: "INVALID_REQUEST" }, origin);
  }

  try {
    const supabase = createClient(
      SUPABASE_URL,
      SERVICE_ROLE_KEY,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUrl: false,
        },
        global: {
          headers: {
            "Cache-Control": "no-store",
          },
        },
      },
    );

    // Reserve a global rolling-window slot before expensive Argon2id work.
    const { data: rateLimit, error: rateLimitError } = await supabase
      .schema("api")
      .rpc("reserve_pin_enrollment_request");

    if (rateLimitError) {
      return response(503, { error: "SERVICE_UNAVAILABLE" }, origin);
    }

    if (
      typeof rateLimit !== "object" ||
      rateLimit === null ||
      typeof rateLimit.allowed !== "boolean"
    ) {
      return response(503, { error: "SERVICE_UNAVAILABLE" }, origin);
    }

    if (rateLimit.allowed === false) {
      const retryAfter = rateLimit.retryAfterSeconds;

      if (
        typeof retryAfter !== "number" ||
        !Number.isInteger(retryAfter) ||
        retryAfter < 1 ||
        retryAfter > 60
      ) {
        return response(503, { error: "SERVICE_UNAVAILABLE" }, origin);
      }

      return response(
        429,
        { error: "TOO_MANY_REQUESTS" },
        origin,
        { "Retry-After": String(retryAfter) },
      );
    }

    if (
      typeof rateLimit.remaining !== "number" ||
      !Number.isInteger(rateLimit.remaining) ||
      rateLimit.remaining < 0 ||
      rateLimit.remaining > 29
    ) {
      return response(503, { error: "SERVICE_UNAVAILABLE" }, origin);
    }

    // Only rate-limited requests can reach these expensive operations.
    const tokenHash = await hashEnrollmentToken(payload.token);
    const passwordHash = await hashMemberPin(payload.pin);

    const { data, error } = await supabase
      .schema("api")
      .rpc("member_enroll_pin", {
        p_token_hash: tokenHash,
        p_password_hash: passwordHash,
      });

    if (error) {
      if (error.code === "P0001" || error.code === "22023") {
        return response(
          400,
          { error: "ENROLLMENT_UNAVAILABLE" },
          origin,
        );
      }

      return response(503, { error: "SERVICE_UNAVAILABLE" }, origin);
    }

    if (
      typeof data !== "object" ||
      data === null ||
      data.success !== true
    ) {
      return response(503, { error: "SERVICE_UNAVAILABLE" }, origin);
    }

    return response(
      200,
      {
        success: true,
        message: "PIN_ENROLLMENT_COMPLETE",
      },
      origin,
    );
  } catch {
    return response(503, { error: "SERVICE_UNAVAILABLE" }, origin);
  }
});
