import { withBrowserCors } from "../_shared/browser-cors.ts";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { createMobileLookupHash } from "../_shared/member-mobile.ts";
import { verifyMemberPin } from "../_shared/pin-password.ts";
import { readPinRequestBody } from "../_shared/pin-recovery.ts";
import { toPostgresBytea } from "../_shared/postgres-bytea.ts";
import {
  createCheckinIdentifierDigest, decodeCheckinHmacKey, isDevelopmentPinVerifier,
  parseCheckinLimit, parseMemberCheckinInput, publicMemberCheckinOutcome, runMemberCheckin,
} from "../_shared/member-checkin.ts";

const appOrigin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
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

Deno.serve(withBrowserCors(appOrigin, async (request: Request): Promise<Response> => {
  if (!appOrigin) return respond(503);
  if (request.headers.get("Origin") !== appOrigin) return respond(403);
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (!enabled || !url || !serviceKey || !lookupKey || !mobileKeyValid || !globalLimit || !identifierLimit || !isDevelopmentPinVerifier(dummyHash)) return respond(503);
  if (request.method !== "POST") return respond(405);
  let input;
  try { input = parseMemberCheckinInput(await readPinRequestBody(request)); }
  catch { return respond(400); }
  if (!input) return respond(400);
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
        const { data, error } = await service.schema("api").rpc("reserve_member_checkin_request", {
          p_identifier_digest: digest, p_global_limit: globalLimit, p_identifier_limit: identifierLimit,
        });
        if (error) throw new Error("RESERVATION_UNAVAILABLE");
        return data;
      },
      prepare: async (identifier) => {
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
      verify: verifyMemberPin,
      commit: async (memberId, credentialVersion) => {
        // SQL rechecks date, credentials, entitlement and duplicates atomically.
        const { data, error } = await service.schema("api").rpc("commit_member_checkin", {
          p_member_id: memberId, p_credential_version: credentialVersion,
        });
        if (error) throw new Error("COMMIT_UNAVAILABLE");
        return data;
      },
    });
    return respond(result.status, result.accepted, result.retryAfterSeconds ? { "Retry-After": String(result.retryAfterSeconds) } : {});
  } catch { return respond(503); }
}));
