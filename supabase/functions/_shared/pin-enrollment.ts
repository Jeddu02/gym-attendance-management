export interface PinEnrollmentToken {
  rawToken: string;
  tokenHash: string;
}

export async function createPinEnrollmentToken(): Promise<PinEnrollmentToken> {
  const randomBytes = crypto.getRandomValues(new Uint8Array(32));

  const rawToken = btoa(
    Array.from(randomBytes, (byte) => String.fromCharCode(byte)).join(""),
  )
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");

  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(rawToken),
  );

  const tokenHash = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");

  return { rawToken, tokenHash };
}

export function isValidMemberId(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu
      .test(value);
}
