function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return Uint8Array.from(bytes).buffer as ArrayBuffer;
}

const encoder = new TextEncoder();

function decodeBase64Key(
  name: string,
): Uint8Array {
  const value = Deno.env.get(name);

  if (!value) {
    throw new Error(`Missing server secret: ${name}`);
  }

  const binary = atob(value);
  const bytes = Uint8Array.from(
    binary,
    (character) => character.charCodeAt(0),
  );

  if (bytes.length !== 32) {
    throw new Error(`${name} must decode to 32 bytes`);
  }

  return bytes;
}

/**
 * Accepts Philippine mobile formats such as:
 * 09171234567, +639171234567, and 639171234567.
 * Returns one canonical format: +639171234567.
 */
export function normalizePhilippineMobile(
  input: string,
): string {
  let digits = input.replace(/[\s()-]/g, "");

  if (digits.startsWith("+")) {
    if (!digits.startsWith("+63")) {
      throw new Error("Unsupported mobile-number format");
    }
    digits = digits.slice(1);
  }

  if (digits.startsWith("09") && digits.length === 11) {
    digits = `63${digits.slice(1)}`;
  } else if (digits.startsWith("9") && digits.length === 10) {
    digits = `63${digits}`;
  }

  if (!/^639\d{9}$/.test(digits)) {
    throw new Error("Invalid Philippine mobile number");
  }

  return `+${digits}`;
}

/**
 * Deterministic keyed lookup value.
 * Keep MEMBER_MOBILE_HMAC_KEY_B64 secret.
 */
export async function createMobileLookupHash(
  mobile: string,
): Promise<Uint8Array> {
  const keyBytes = decodeBase64Key(
    "MEMBER_MOBILE_HMAC_KEY_B64",
  );

  const key = await crypto.subtle.importKey(
    "raw",
    toArrayBuffer(keyBytes),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(normalizePhilippineMobile(mobile)),
  );

  return new Uint8Array(signature);
}

/**
 * AES-256-GCM encryption.
 * Stored bytes = 12-byte IV followed by ciphertext and tag.
 * Keep MEMBER_MOBILE_ENCRYPTION_KEY_B64 secret.
 */
export async function encryptMobile(
  mobile: string,
): Promise<Uint8Array> {
  const keyBytes = decodeBase64Key(
    "MEMBER_MOBILE_ENCRYPTION_KEY_B64",
  );

  const key = await crypto.subtle.importKey(
    "raw",
    toArrayBuffer(keyBytes),
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );

  const iv = crypto.getRandomValues(new Uint8Array(12));

  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    encoder.encode(normalizePhilippineMobile(mobile)),
  );

  const encrypted = new Uint8Array(
    iv.length + ciphertext.byteLength,
  );

  encrypted.set(iv, 0);
  encrypted.set(new Uint8Array(ciphertext), iv.length);

  return encrypted;
}

/**
 * Decrypts a mobile number encrypted by encryptMobile().
 * Input format: 12-byte IV followed by AES-GCM ciphertext/tag.
 * Use only inside trusted server-side operations.
 */
export async function decryptMobile(
  encrypted: Uint8Array,
): Promise<string> {
  const ivLength = 12;

  // AES-GCM includes a 16-byte authentication tag.
  if (encrypted.length < ivLength + 17) {
    throw new Error("Invalid encrypted mobile data");
  }

  const keyBytes = decodeBase64Key(
    "MEMBER_MOBILE_ENCRYPTION_KEY_B64",
  );

  const key = await crypto.subtle.importKey(
    "raw",
    toArrayBuffer(keyBytes),
    { name: "AES-GCM" },
    false,
    ["decrypt"],
  );

  const iv = encrypted.slice(0, ivLength);
  const ciphertext = encrypted.slice(ivLength);

  // Authentication failures reject this operation.
  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    ciphertext,
  );

  const mobile = new TextDecoder("utf-8", {
    fatal: true,
  }).decode(plaintext);

  // Confirm the decrypted value uses the expected canonical format.
  const normalized = normalizePhilippineMobile(mobile);

  if (normalized !== mobile) {
    throw new Error("Invalid decrypted mobile format");
  }

  return mobile;
}
