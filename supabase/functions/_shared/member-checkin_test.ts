import { assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";
import {
  createCheckinIdentifierDigest, decodeCheckinHmacKey, isDevelopmentPinVerifier,
  normalizeCheckinIdentifier, parseCheckinCandidate, parseCheckinLimit,
  parseMemberCheckinInput, publicMemberCheckinOutcome, runMemberCheckin,
} from "./member-checkin.ts";

const code = "MBR-ABCDEF012345";
const pin = "012345";
const hash = "$argon2id$v=19$m=65536,t=3,p=1$" + btoa("s".repeat(16)).replaceAll("=", "") + "$" + btoa("h".repeat(32)).replaceAll("=", "");

Deno.test("member check-in canonicalizes member code/mobile without treating UUID as Member ID", () => {
  assertEquals(normalizeCheckinIdentifier(" mbr-abcdef012345 "), { kind: "member_code", value: code });
  for (const value of ["09171234567", "+639171234567", "639171234567", "(0917) 123-4567"]) {
    assertEquals(normalizeCheckinIdentifier(value), { kind: "mobile", value: "+639171234567" });
  }
  for (const value of [null, "", "bad", "00000000-0000-4000-8000-000000000001", "MBR-abcdef", "x".repeat(81), "0917\n1234567"]) assertEquals(normalizeCheckinIdentifier(value), null);
});

Deno.test("member check-in payload rejects actor, member UUID, date and credential overrides", () => {
  assertEquals(parseMemberCheckinInput({ identifier: code, pin }), { identifier: { kind: "member_code", value: code }, pin });
  for (const value of [null, [], {}, { identifier: code, pin: 123456 }, { identifier: code, pin: "12345" },
    { identifier: code, pin: "１２３４５６" }, { identifier: code, pin, memberId: "forged" },
    { identifier: code, pin, actorUserId: "forged" }, { identifier: code, pin, date: "2026-01-01" },
    { identifier: code, pin, credentialVersion: 1 }, { identifier: code, pin, globalLimit: 100 }]) {
    assertEquals(parseMemberCheckinInput(value), null);
  }
});

Deno.test("identifier limits and HMAC key are explicit bounded server configuration", () => {
  for (const value of [undefined, "", "0", "101", "01", "1.0", " 1"]) assertEquals(parseCheckinLimit(value), null);
  assertEquals(parseCheckinLimit("1"), 1);
  assertEquals(parseCheckinLimit("100"), 100);
  assertEquals(decodeCheckinHmacKey(btoa("k".repeat(32)))?.length, 32);
  for (const value of [undefined, "", "not-base64", btoa("k".repeat(16))]) assertEquals(decodeCheckinHmacKey(value), null);
});

Deno.test("HMAC digest joins identifier variants while separating keys and identifier domains", async () => {
  const key = new Uint8Array(32).fill(7);
  const normalized = normalizeCheckinIdentifier("09171234567")!;
  const first = await createCheckinIdentifierDigest(normalized, key);
  assertEquals(first.length, 64);
  assertEquals(first, await createCheckinIdentifierDigest(normalizeCheckinIdentifier("+639171234567")!, key));
  assertNotEquals(first, await createCheckinIdentifierDigest(normalized, new Uint8Array(32).fill(8)));
  assertNotEquals(first, await createCheckinIdentifierDigest({ kind: "member_code", value: normalized.value }, key));
  await assertRejects(() => createCheckinIdentifierDigest(normalized, new Uint8Array(16)));
});

Deno.test("candidate parsing refuses unbounded KDFs and response strips all private state", () => {
  assertEquals(isDevelopmentPinVerifier(hash), true);
  assertEquals(isDevelopmentPinVerifier(hash.replace("m=65536", "m=999999999")), false);
  const candidate = { memberId: "00000000-0000-4000-8000-000000000001", credentialVersion: 1, passwordHash: hash };
  assertEquals(parseCheckinCandidate(candidate), candidate);
  for (const value of [null, [], { ...candidate, memberId: "bad" }, { ...candidate, credentialVersion: 0 }, { ...candidate, passwordHash: "bad" }]) assertEquals(parseCheckinCandidate(value), null);
  assertEquals(publicMemberCheckinOutcome(false), { success: false, message: "CHECKIN_UNAVAILABLE" });
  assertEquals(publicMemberCheckinOutcome(true), { success: true, message: "CHECKIN_ACCEPTED" });
  assertEquals(Object.keys(publicMemberCheckinOutcome(true)).sort(), ["message", "success"]);
});

Deno.test("rate rejection precedes lookup and expensive PIN verification", async () => {
  const calls: string[] = [];
  const result = await runMemberCheckin(parseMemberCheckinInput({ identifier: code, pin })!, hash, {
    reserve: async () => { calls.push("reserve"); return { allowed: false, retryAfterSeconds: 5 }; },
    prepare: async () => { calls.push("prepare"); return null; },
    verify: async () => { calls.push("verify"); return false; },
    commit: async () => { calls.push("commit"); return { accepted: true }; },
  });
  assertEquals(calls, ["reserve"]);
  assertEquals(result, { status: 429, accepted: false, retryAfterSeconds: 5 });
});

Deno.test("unknown identifier uses dummy verification and never commits even if dummy matches", async () => {
  const calls: string[] = [];
  const result = await runMemberCheckin(parseMemberCheckinInput({ identifier: code, pin })!, hash, {
    reserve: async () => { calls.push("reserve"); return { allowed: true }; },
    prepare: async () => { calls.push("prepare"); return null; },
    verify: async (value, verifier) => { calls.push("verify"); assertEquals(value, pin); assertEquals(verifier, hash); return true; },
    commit: async () => { calls.push("commit"); return { accepted: true }; },
  });
  assertEquals(calls, ["reserve", "prepare", "verify"]);
  assertEquals(result, { status: 400, accepted: false });
});

Deno.test("PIN denial and ineligible commit share the same public outcome; accepted replay stays generic", async () => {
  const candidate = { memberId: "00000000-0000-4000-8000-000000000001", credentialVersion: 3, passwordHash: hash };
  const input = parseMemberCheckinInput({ identifier: code, pin })!;
  for (const matches of [false, true]) {
    let commits = 0;
    const result = await runMemberCheckin(input, hash, {
      reserve: async () => ({ allowed: true }), prepare: async () => candidate,
      verify: async () => matches,
      commit: async (memberId, version) => { commits++; assertEquals(memberId, candidate.memberId); assertEquals(version, 3); return { accepted: false, memberName: "must never escape" }; },
    });
    assertEquals(commits, matches ? 1 : 0);
    assertEquals(result, { status: 400, accepted: false });
  }
  const accepted = await runMemberCheckin(input, hash, {
    reserve: async () => ({ allowed: true }), prepare: async () => candidate, verify: async () => true,
    commit: async () => ({ accepted: true, duplicate: true, memberId: candidate.memberId }),
  });
  assertEquals(accepted, { status: 200, accepted: true });
  assertEquals(publicMemberCheckinOutcome(accepted.accepted), { success: true, message: "CHECKIN_ACCEPTED" });
});
