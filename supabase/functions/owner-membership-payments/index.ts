import { withBrowserCors } from "../_shared/browser-cors.ts";
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

type Input = Record<string, unknown>;

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
  if (!allowedOrigin) {
    return respond(503, { error: "SERVER_CONFIGURATION_ERROR" });
  }
  if (request.headers.get("Origin") !== allowedOrigin) {
    return respond(403, { error: "ORIGIN_NOT_ALLOWED" });
  }
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (!supabaseUrl || !publishableKey || !serviceRoleKey) return respond(503, { error: "SERVER_CONFIGURATION_ERROR" });
  if (request.method !== "POST") return respond(405, { error: "METHOD_NOT_ALLOWED" });
  const contentType = request.headers.get("Content-Type") ?? "";
  if (contentType.split(";")[0].trim().toLowerCase() !== "application/json") {
    return respond(415, { error: "UNSUPPORTED_MEDIA_TYPE" });
  }
  return null;
}

async function readJson(request: Request): Promise<Input | null> {
  const reader = request.body?.getReader();
  if (!reader) return null;
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > 4096) {
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
    return typeof value === "object" && value !== null && !Array.isArray(value)
      ? value as Input
      : null;
  } catch {
    return null;
  }
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function onlyKeys(input: Input, allowed: string[]): boolean {
  const accepted = new Set(allowed);
  return Object.keys(input).every((key) => accepted.has(key));
}

function paymentError(error: { code?: string; message?: string }): Response {
  const message = error.message ?? "";
  if (error.code === "42501") return respond(403, { error: "OWNER_ACCESS_REQUIRED" });
  if (error.code === "P0002" || message.includes("PAYMENT_NOT_FOUND") || message.includes("MEMBERSHIP_PURCHASE_NOT_FOUND")) {
    return respond(404, { error: "PAYMENT_OR_PURCHASE_NOT_FOUND" });
  }
  if (error.code === "23505") return respond(409, { error: "DUPLICATE_PAYMENT" });
  if (error.code === "23514") return respond(409, { error: message.split(" ")[0] || "PAYMENT_INTEGRITY_CONFLICT" });
  if (error.code === "P0001" || message.includes("PAYMENT_") || message.includes("PURCHASE_")) {
    return respond(409, { error: message.split(" ")[0] || "PAYMENT_CONFLICT" });
  }
  if (error.code === "22023") return respond(400, { error: message.split(" ")[0] || "INVALID_PAYMENT_REQUEST" });
  console.error("Owner membership payment RPC failed:", error.code ?? "UNKNOWN");
  return respond(500, { error: "MEMBERSHIP_PAYMENT_UNAVAILABLE" });
}

Deno.serve(withBrowserCors(allowedOrigin, async (request: Request) => {
  const early = checkRequest(request);
  if (early) return early;

  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || !authorization.slice(7).trim()) {
    return respond(401, { error: "AUTHENTICATION_REQUIRED" });
  }
  const token = authorization.slice(7).trim();
  const input = await readJson(request);
  if (!input || typeof input.action !== "string") {
    return respond(400, { error: "INVALID_REQUEST_BODY" });
  }

  let rpcName: string;
  let rpcArgs: Record<string, unknown>;
  let outputKey: string;

  if (input.action === "payable") {
    if (!onlyKeys(input, ["action", "search", "limit", "offset"])) return respond(400, { error: "INVALID_REQUEST_BODY" });
    const search = input.search ?? ""; const limit = input.limit ?? 50; const offset = input.offset ?? 0;
    if (typeof search !== "string" || search.length > 80 || typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100
      || typeof offset !== "number" || !Number.isInteger(offset) || offset < 0 || offset > 100000) return respond(400, { error: "INVALID_PAYMENT_FILTER" });
    rpcName = "owner_list_payable_purchases"; rpcArgs = { p_search: search.trim() || null, p_limit: limit, p_offset: offset }; outputKey = "purchases";
  } else if (input.action === "list") {
    if (!onlyKeys(input, ["action", "search", "status", "limit", "offset"])) {
      return respond(400, { error: "INVALID_REQUEST_BODY" });
    }
    const search = input.search ?? "";
    const status = input.status ?? "all";
    const limit = input.limit ?? 50;
    const offset = input.offset ?? 0;
    if (
      typeof search !== "string" || search.length > 80 ||
      typeof status !== "string" || !["all", "recorded", "confirmed", "rejected", "confirmation_voided_in_error"].includes(status) ||
      typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100 ||
      typeof offset !== "number" || !Number.isInteger(offset) || offset < 0 || offset > 100000
    ) return respond(400, { error: "INVALID_PAYMENT_FILTER" });
    rpcName = "owner_list_membership_payments";
    rpcArgs = {
      p_search: search || null,
      p_status: status,
      p_limit: limit,
      p_offset: offset,
    };
    outputKey = "result";
  } else if (input.action === "record") {
    if (!onlyKeys(input, ["action", "operationId", "membershipPurchaseId", "amountPhp", "paymentMethod", "externalReference"])) {
      return respond(400, { error: "INVALID_REQUEST_BODY" });
    }
    const amountPhp = input.amountPhp;
    const paymentMethod = input.paymentMethod;
    const externalReference = input.externalReference ?? "";
    if (
      !isUuid(input.operationId) || !isUuid(input.membershipPurchaseId) ||
      typeof amountPhp !== "string" || !/^\d{1,10}(?:\.\d{1,2})?$/.test(amountPhp) || Number(amountPhp) <= 0 ||
      typeof paymentMethod !== "string" || !["cash", "gcash", "bank_transfer"].includes(paymentMethod) ||
      typeof externalReference !== "string" || externalReference.length > 120
    ) return respond(400, { error: "INVALID_MEMBERSHIP_PAYMENT" });
    rpcName = "owner_record_membership_payment";
    rpcArgs = {
      p_operation_id: input.operationId,
      p_membership_purchase_id: input.membershipPurchaseId,
      p_amount_php: amountPhp,
      p_payment_method: paymentMethod,
      p_external_reference: externalReference.trim() || null,
    };
    outputKey = "payment";
  } else if (input.action === "confirm") {
    if (!onlyKeys(input, ["action", "paymentId", "evidenceReviewed"]) ||
      !isUuid(input.paymentId) || typeof input.evidenceReviewed !== "boolean") {
      return respond(400, { error: "INVALID_PAYMENT_CONFIRMATION" });
    }
    rpcName = "owner_confirm_membership_payment";
    rpcArgs = {
      p_payment_id: input.paymentId,
      p_evidence_reviewed: input.evidenceReviewed,
    };
    outputKey = "confirmation";
  } else if (input.action === "reject") {
    if (!onlyKeys(input, ["action", "paymentId", "reason"]) ||
      !isUuid(input.paymentId) || typeof input.reason !== "string" ||
      input.reason.trim().length < 5 || input.reason.length > 500) {
      return respond(400, { error: "INVALID_PAYMENT_REJECTION" });
    }
    rpcName = "owner_reject_membership_payment";
    rpcArgs = { p_payment_id: input.paymentId, p_reason: input.reason.trim() };
    outputKey = "rejection";
  } else {
    return respond(400, { error: "INVALID_PAYMENT_ACTION" });
  }

  try {
    const authClient = createClient(supabaseUrl!, publishableKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const serviceClient = createClient(supabaseUrl!, serviceRoleKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser(token);
    if (authError || !authData.user) return respond(401, { error: "INVALID_AUTHENTICATION" });

    const { data, error } = await serviceClient.schema("api").rpc(rpcName, {
      p_actor_user_id: authData.user.id,
      ...rpcArgs,
    });
    if (error) return paymentError(error);
    return respond(200, { success: true, [outputKey]: data });
  } catch (error) {
    console.error("Owner membership payment request failed:", error instanceof Error ? error.name : "Unknown error");
    return respond(500, { error: "INTERNAL_SERVER_ERROR" });
  }
}));
