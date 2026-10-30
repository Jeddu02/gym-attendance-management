import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";

import {
  hashMemberPin,
  validateMemberPin,
  verifyMemberPin,
} from "./pin-password.ts";

Deno.test("accepts exactly six numeric digits", () => {
  assertEquals(validateMemberPin("123456"), true);
  assertEquals(validateMemberPin("000000"), true);
  assertEquals(validateMemberPin("12345"), false);
  assertEquals(validateMemberPin("1234567"), false);
  assertEquals(validateMemberPin("12A456"), false);
  assertEquals(validateMemberPin(" 12345"), false);
  assertEquals(validateMemberPin(null), false);
});

Deno.test("creates an encoded Argon2id hash", async () => {
  const hash = await hashMemberPin("123456");

  assert(hash.startsWith("$argon2id$"));
});

Deno.test("uses a fresh salt for each PIN hash", async () => {
  const first = await hashMemberPin("123456");
  const second = await hashMemberPin("123456");

  assertNotEquals(first, second);
});

Deno.test("verifies the correct PIN", async () => {
  const hash = await hashMemberPin("123456");

  assertEquals(await verifyMemberPin("123456", hash), true);
});

Deno.test("rejects an incorrect PIN", async () => {
  const hash = await hashMemberPin("123456");

  assertEquals(await verifyMemberPin("654321", hash), false);
});

Deno.test("rejects malformed PINs and hashes", async () => {
  assertEquals(await verifyMemberPin("12345", "$argon2id$invalid"), false);
  assertEquals(await verifyMemberPin("123456", "not-a-hash"), false);
});
