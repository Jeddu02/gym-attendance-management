import {
  assert,
  assertEquals,
  assertMatch,
  assertNotEquals,
} from "jsr:@std/assert@1";

import { createPinEnrollmentToken, isValidMemberId } from "./pin-enrollment.ts";

Deno.test("generates a URL-safe enrollment token", async () => {
  const result = await createPinEnrollmentToken();

  assert(result.rawToken.length > 30);
  assertMatch(result.rawToken, /^[A-Za-z0-9_-]+$/u);
});

Deno.test("generates a 64-character hexadecimal SHA-256 hash", async () => {
  const result = await createPinEnrollmentToken();

  assertMatch(result.tokenHash, /^[0-9a-f]{64}$/u);
});

Deno.test("generates unique tokens", async () => {
  const first = await createPinEnrollmentToken();
  const second = await createPinEnrollmentToken();

  assertNotEquals(first.rawToken, second.rawToken);
  assertNotEquals(first.tokenHash, second.tokenHash);
});

Deno.test("validates member UUIDs", () => {
  assertEquals(
    isValidMemberId("11111111-1111-4111-8111-111111111111"),
    true,
  );

  assertEquals(isValidMemberId("not-a-uuid"), false);
  assertEquals(isValidMemberId(""), false);
  assertEquals(isValidMemberId(null), false);
  assertEquals(isValidMemberId(123), false);
});
