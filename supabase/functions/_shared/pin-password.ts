import { argon2id, argon2Verify } from "npm:hash-wasm@4.12.0";

const ARGON2_OPTIONS = {
  parallelism: 1,
  iterations: 3,
  memorySize: 65536,
  hashLength: 32,
  outputType: "encoded" as const,
};

export function validateMemberPin(value: unknown): value is string {
  return typeof value === "string" && /^[0-9]{6}$/u.test(value);
}

export async function hashMemberPin(pin: string): Promise<string> {
  if (!validateMemberPin(pin)) {
    throw new Error("INVALID_PIN");
  }

  const salt = crypto.getRandomValues(new Uint8Array(16));

  const hash = await argon2id({
    password: pin,
    salt,
    ...ARGON2_OPTIONS,
  });

  if (typeof hash !== "string" || !hash.startsWith("$argon2id$")) {
    throw new Error("ARGON2_HASH_FAILED");
  }

  return hash;
}

export async function verifyMemberPin(
  pin: string,
  encodedHash: string,
): Promise<boolean> {
  if (
    !validateMemberPin(pin) ||
    typeof encodedHash !== "string" ||
    !encodedHash.startsWith("$argon2id$")
  ) {
    return false;
  }

  return await argon2Verify({
    password: pin,
    hash: encodedHash,
  });
}
