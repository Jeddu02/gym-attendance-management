import { isValidMemberId } from "./pin-enrollment.ts";

type OwnerIdentityAttestation = {
  memberId: string;
  identityVerified: true;
  reason: string;
};

export function parseOwnerPinRecoveryInput(
  value: unknown,
): OwnerIdentityAttestation | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  const input = value as Record<string, unknown>;
  if (
    Object.keys(input).sort().join(",") !==
      "identityVerified,memberId,reason" ||
    !isValidMemberId(input.memberId) || input.identityVerified !== true ||
    typeof input.reason !== "string"
  ) return null;
  const reason = input.reason.trim();
  if (reason.length < 5 || reason.length > 500) return null;
  return { memberId: input.memberId, identityVerified: true, reason };
}

export function parseMemberPinResetInput(
  value: unknown,
): { token: string; pin: string } | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  const input = value as Record<string, unknown>;
  if (
    Object.keys(input).sort().join(",") !== "pin,token" ||
    typeof input.token !== "string" ||
    !/^[A-Za-z0-9_-]{43}$/u.test(input.token) ||
    typeof input.pin !== "string" || !/^[0-9]{6}$/u.test(input.pin)
  ) return null;
  return { token: input.token, pin: input.pin };
}

/** Bound actual streamed bytes, including chunked requests without a length. */
export async function readPinRequestBody(request: Request): Promise<unknown> {
  if (
    request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !==
      "application/json"
  ) {
    throw new Error("INVALID_REQUEST");
  }
  const declared = request.headers.get("content-length");
  if (
    declared !== null &&
    (!/^\d+$/u.test(declared) || !Number.isSafeInteger(Number(declared)) ||
      Number(declared) > 2048)
  ) {
    throw new Error("INVALID_REQUEST");
  }
  const reader = request.body?.getReader();
  if (!reader) throw new Error("INVALID_REQUEST");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 2048) {
        await reader.cancel();
        throw new Error("INVALID_REQUEST");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
}

export async function hashPinRecoveryToken(token: string): Promise<string> {
  const bytes = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token)),
  );
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
}
