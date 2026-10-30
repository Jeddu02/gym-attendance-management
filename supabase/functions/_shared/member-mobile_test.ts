import {
  createMobileLookupHash,
  decryptMobile,
  encryptMobile,
} from "./member-mobile.ts";

const testKey = btoa(
  String.fromCharCode(...Array.from({ length: 32 }, (_, i) => i + 1)),
);

Deno.test("mobile encryption round-trip preserves canonical mobile", async () => {
  Deno.env.set("MEMBER_MOBILE_ENCRYPTION_KEY_B64", testKey);

  try {
    const encrypted = await encryptMobile("09171234567");
    const decrypted = await decryptMobile(encrypted);

    if (decrypted !== "+639171234567") {
      throw new Error("Decrypted mobile does not match canonical format");
    }
  } finally {
    Deno.env.delete("MEMBER_MOBILE_ENCRYPTION_KEY_B64");
  }
});

Deno.test("mobile encryption uses a fresh IV for every encryption", async () => {
  Deno.env.set("MEMBER_MOBILE_ENCRYPTION_KEY_B64", testKey);

  try {
    const first = await encryptMobile("09171234567");
    const second = await encryptMobile("09171234567");

    if (first.length !== second.length) {
      throw new Error("Unexpected encrypted payload length");
    }

    if (first.every((byte, index) => byte === second[index])) {
      throw new Error("Encryption reused the same output");
    }
  } finally {
    Deno.env.delete("MEMBER_MOBILE_ENCRYPTION_KEY_B64");
  }
});

Deno.test("mobile lookup hash is deterministic for equivalent formats", async () => {
  Deno.env.set("MEMBER_MOBILE_HMAC_KEY_B64", testKey);

  try {
    const first = await createMobileLookupHash("09171234567");
    const second = await createMobileLookupHash("+639171234567");

    if (
      first.length !== 32 ||
      !first.every((byte, index) => byte === second[index])
    ) {
      throw new Error("Equivalent mobile numbers must have matching hashes");
    }
  } finally {
    Deno.env.delete("MEMBER_MOBILE_HMAC_KEY_B64");
  }
});

Deno.test("mobile decryption rejects modified ciphertext", async () => {
  Deno.env.set("MEMBER_MOBILE_ENCRYPTION_KEY_B64", testKey);

  try {
    const encrypted = await encryptMobile("09171234567");
    encrypted[encrypted.length - 1] ^= 1;

    let rejected = false;

    try {
      await decryptMobile(encrypted);
    } catch {
      rejected = true;
    }

    if (!rejected) {
      throw new Error("Modified ciphertext was accepted");
    }
  } finally {
    Deno.env.delete("MEMBER_MOBILE_ENCRYPTION_KEY_B64");
  }
});
