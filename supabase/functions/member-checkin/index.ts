import { withBrowserCors } from "../_shared/browser-cors.ts";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { createMobileLookupHash } from "../_shared/member-mobile.ts";
import { verifyMemberPin } from "../_shared/pin-password.ts";
import { readPinRequestBody } from "../_shared/pin-recovery.ts";
import { localOnly, splitChallenge, verifyTurnstile } from "../_shared/turnstile.ts";
import { toPostgresBytea } from "../_shared/postgres-bytea.ts";
import {
  createCheckinIdentifierDigest, decodeCheckinHmacKey, isDevelopmentPinVerifier,
  parseCheckinLimit, parseMemberCheckinInput, publicMemberCheckinOutcome, runMemberCheckin,
} from "../_shared/member-checkin.ts";

const appOrigin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const local = localOnly(appOrigin, url);
const challengeSecret = Deno.env.get("TURNSTILE_SECRET_KEY");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Default disabled. Explicit development limits/keys/dummy verifier do not imply
// approved production abuse controls, gateway trust or a production release.
const enabled = Deno.env.get("PUBLIC_MEMBER_CHECKIN_ENABLED") === "true";
const lookupKey = decodeCheckinHmacKey(Deno.env.get("PUBLIC_CHECKIN_LOOKUP_HMAC_KEY_B64"));
const mobileKeyValid = decodeCheckinHmacKey(Deno.env.get("MEMBER_MOBILE_HMAC_KEY_B64")) !== null;
const globalLimit = parseCheckinLimit(Deno.env.get("CHECKIN_GLOBAL_LIMIT_PER_MINUTE"));
const identifierLimit = parseCheckinLimit(Deno.env.get("CHECKIN_IDENTIFIER_LIMIT_PER_MINUTE"));
// Supply an independently generated development Argon2id verifier. Never use
// any member verifier as a dummy and never store/log its plaintext input.
const dummyHash = Deno.env.get("DUMMY_PIN_HASH");
const headers = {
  "Content-Type": "application/json", "Cache-Control": "no-store", "Vary": "Origin",
  "Access-Control-Allow-Origin": appOrigin ?? "",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};
const respond = (status: number, accepted = false, extra: Record<string, string> = {}) => new Response(JSON.stringify(publicMemberCheckinOutcome(accepted)), { status, headers: { ...headers, ...extra } });

// Fixed diagnostic codes only. Never include identifiers, PINs, tokens, keys,
 // provider responses, RPC payloads or exception details.
type FailureStage = "disabled" | "backend_config" | "lookup_key" | "mobile_key" |
  "global_limit" | "identifier_limit" | "dummy_verifier" | "challenge_secret" |
  "challenge_unavailable" | "service_init" | "reservation" | "preparation" |
  "pin_verification" | "commit";
function reportUnavailable(stage: FailureStage) {
  console.warn("MEMBER_CHECKIN_UNAVAILABLE:" + stage);
  return respond(503);
}

Deno.serve(withBrowserCors(appOrigin, async (request: Request): Promise<Response> => {
  if (!appOrigin) return respond(503);
  if (request.headers.get("Origin") !== appOrigin) return respond(403);
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (!enabled) return reportUnavailable("disabled");
  if (!url || !serviceKey) return reportUnavailable("backend_config");
  if (!lookupKey) return reportUnavailable("lookup_key");
  if (!mobileKeyValid) return reportUnavailable("mobile_key");
  if (!globalLimit) return reportUnavailable("global_limit");
  if (!identifierLimit) return reportUnavailable("identifier_limit");
  if (!isDevelopmentPinVerifier(dummyHash)) return reportUnavailable("dummy_verifier");
  if (request.method !== "POST") return respond(405);
  let input;
  let challengeToken: string | undefined;
  try {
    const raw = await readPinRequestBody(request, local ? 2048 : 8192);
    if (local) input = parseMemberCheckinInput(raw);
    else {
      const challenge = splitChallenge(raw);
      if (!challenge) return respond(400);
      challengeToken = challenge.token;
      input = parseMemberCheckinInput(challenge.body);
    }
  }
  catch { return respond(400); }
  if (!input) return respond(400);
  if (!local) {
    if (!challengeSecret?.trim()) return reportUnavailable("challenge_secret");
    const verified = await verifyTurnstile(challengeToken ?? "", challengeSecret, appOrigin, "member_checkin", request.signal);
    if (verified !== "accepted") return verified === "denied" ? respond(400) : reportUnavailable("challenge_unavailable");
  }
  let stage: FailureStage = "service_init";
  try {
    const service = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
      global: { headers: { "Cache-Control": "no-store" } },
    });
    const digest = await createCheckinIdentifierDigest(input.identifier, lookupKey);
    // Reserve before member lookup and expensive Argon2 work. No forwarded IP
    // headers or browser-provided identifiers/limits gain trust here.
    const result = await runMemberCheckin(input, dummyHash, {
      reserve: async () => {
        stage = "reservation";
        const { data, error } = await service.schema("api").rpc("reserve_member_checkin_request", {
          p_identifier_digest: digest, p_global_limit: globalLimit, p_identifier_limit: identifierLimit,
        });
        if (error) throw new Error("RESERVATION_UNAVAILABLE");
        return data;
      },
      prepare: async (identifier) => {
        stage = "preparation";
        const mobileHash = identifier.kind === "mobile" ? toPostgresBytea(await createMobileLookupHash(identifier.value)) : null;
        const { data, error } = await service.schema("api").rpc("prepare_member_checkin", {
          p_member_code: identifier.kind === "member_code" ? identifier.value : null,
          p_mobile_lookup_hash: mobileHash,
        });
        if (error) throw new Error("PREPARATION_UNAVAILABLE");
        return data;
      },
      // Unknown identifiers perform the same KDF class against a separate dummy.
      // Timing similarity still needs synthetic abuse/load measurement.
      verify: async (pin, hash) => {
        stage = "pin_verification";
        return await verifyMemberPin(pin, hash);
      },
      commit: async (memberId, credentialVersion) => {
        stage = "commit";
        // SQL rechecks date, credentials, entitlement and duplicates atomically.
        const { data, error } = await service.schema("api").rpc("commit_member_checkin", {
          p_member_id: memberId, p_credential_version: credentialVersion,
        });
        if (error) throw new Error("COMMIT_UNAVAILABLE");
        return data;
      },
    });
    if (result.status === 503) return reportUnavailable(stage);
    return respond(result.status, result.accepted, result.retryAfterSeconds ? { "Retry-After": String(result.retryAfterSeconds) } : {});
  } catch { return reportUnavailable(stage); }
}));
