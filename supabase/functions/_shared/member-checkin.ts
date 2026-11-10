import { normalizePhilippineMobile } from "./member-mobile.ts";
import { isValidMemberId } from "./pin-enrollment.ts";

export type CheckinIdentifier = { kind: "member_code" | "mobile"; value: string };
export type MemberCheckinInput = { identifier: CheckinIdentifier; pin: string };

export function normalizeCheckinIdentifier(value: unknown): CheckinIdentifier | null {
  if (typeof value !== "string" || value.length > 80 ||
    Array.from(value).some((character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127)) return null;
  const identifier = value.trim();
  if (!identifier) return null;
  const code = identifier.toUpperCase();
  // Existing server-generated codes. Do not interpret identifiers as member UUIDs.
  if (/^MBR-[0-9A-F]{12}$/u.test(code)) return { kind: "member_code", value: code };
  try { return { kind: "mobile", value: normalizePhilippineMobile(identifier) }; }
  catch { return null; }
}

export function parseMemberCheckinInput(value: unknown): MemberCheckinInput | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
  const input = value as Record<string, unknown>;
  if (Object.keys(input).sort().join(",") !== "identifier,pin" ||
    typeof input.pin !== "string" || !/^[0-9]{6}$/u.test(input.pin)) return null;
  const identifier = normalizeCheckinIdentifier(input.identifier);
  return identifier ? { identifier, pin: input.pin } : null;
}

export function parseCheckinLimit(value: string | undefined): number | null {
  if (!value || !/^[1-9][0-9]{0,2}$/u.test(value)) return null;
  const limit = Number(value);
  return limit <= 100 ? limit : null;
}

export function decodeCheckinHmacKey(value: string | undefined): Uint8Array | null {
  if (!value || !/^[A-Za-z0-9+/]{43}=$/u.test(value)) return null;
  try {
    const binary = atob(value);
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    return bytes.byteLength === 32 ? bytes : null;
  } catch { return null; }
}

export async function createCheckinIdentifierDigest(identifier: CheckinIdentifier, bytes: Uint8Array): Promise<string> {
  if (bytes.byteLength !== 32) throw new Error("INVALID_SERVER_KEY");
  const key = await crypto.subtle.importKey("raw", Uint8Array.from(bytes).buffer, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${identifier.kind}:${identifier.value}`));
  return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Match the existing development KDF, preventing unbounded verifier parameters. */
export function isDevelopmentPinVerifier(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const match = /^\$argon2id\$v=19\$m=65536,t=3,p=1\$([A-Za-z0-9+/]{22}(?:==)?)\$([A-Za-z0-9+/]{43}=?)$/u.exec(value);
  if (!match) return false;
  try { return atob(match[1]).length === 16 && atob(match[2]).length === 32; }
  catch { return false; }
}

export type CheckinCandidate = { memberId: string; credentialVersion: number; passwordHash: string };
export function parseCheckinCandidate(value: unknown): CheckinCandidate | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
  const candidate = value as Record<string, unknown>;
  if (!isValidMemberId(candidate.memberId) || typeof candidate.credentialVersion !== "number" ||
    !Number.isSafeInteger(candidate.credentialVersion) || candidate.credentialVersion < 1 || candidate.credentialVersion > 2147483647 ||
    !isDevelopmentPinVerifier(candidate.passwordHash)) return null;
  return { memberId: candidate.memberId, credentialVersion: candidate.credentialVersion, passwordHash: candidate.passwordHash };
}

/** All public outcomes are constructed locally; never forward RPC objects. */
export function publicMemberCheckinOutcome(accepted: boolean): { success: boolean; message: string } {
  return accepted ? { success: true, message: "CHECKIN_ACCEPTED" } : { success: false, message: "CHECKIN_UNAVAILABLE" };
}

type CheckinDependencies = {
  reserve: () => Promise<unknown>;
  prepare: (identifier: CheckinIdentifier) => Promise<unknown>;
  verify: (pin: string, verifier: string) => Promise<boolean>;
  commit: (memberId: string, credentialVersion: number) => Promise<unknown>;
};
type CheckinResult = { status: 200 | 400 | 429 | 503; accepted: boolean; retryAfterSeconds?: number };

/** Injectable order/denial contract; callbacks must throw on infrastructure errors. */
export async function runMemberCheckin(input: MemberCheckinInput, dummyHash: string, dependencies: CheckinDependencies): Promise<CheckinResult> {
  try {
    const rate = await dependencies.reserve();
    if (typeof rate !== "object" || rate === null || !("allowed" in rate) || typeof rate.allowed !== "boolean") return { status: 503, accepted: false };
    if (!rate.allowed) {
      if (!("retryAfterSeconds" in rate) || typeof rate.retryAfterSeconds !== "number" ||
        !Number.isInteger(rate.retryAfterSeconds) || rate.retryAfterSeconds < 1 || rate.retryAfterSeconds > 60) return { status: 503, accepted: false };
      return { status: 429, accepted: false, retryAfterSeconds: rate.retryAfterSeconds };
    }
    const prepared = await dependencies.prepare(input.identifier);
    const candidate = parseCheckinCandidate(prepared);
    // A missing candidate still incurs verification against a separate dummy.
    const matches = await dependencies.verify(input.pin, candidate?.passwordHash ?? dummyHash);
    if (prepared !== null && !candidate) return { status: 503, accepted: false };
    if (!candidate || !matches) return { status: 400, accepted: false };
    const committed = await dependencies.commit(candidate.memberId, candidate.credentialVersion);
    if (typeof committed !== "object" || committed === null || !("accepted" in committed) || typeof committed.accepted !== "boolean") return { status: 503, accepted: false };
    return committed.accepted ? { status: 200, accepted: true } : { status: 400, accepted: false };
  } catch { return { status: 503, accepted: false }; }
}
