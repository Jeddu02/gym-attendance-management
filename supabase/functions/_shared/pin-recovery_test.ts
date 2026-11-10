import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  hashPinRecoveryToken,
  parseMemberPinResetInput,
  parseOwnerPinRecoveryInput,
  readPinRequestBody,
} from "./pin-recovery.ts";

const ownerInput = {
  memberId: "00000000-0000-4000-8000-000000000001",
  identityVerified: true,
  reason: " In-person identity verified ",
};
const resetInput = { token: "a".repeat(43), pin: "012345" };

Deno.test("Owner attestation requires exact fields, explicit true and bounded reason", () => {
  assertEquals(parseOwnerPinRecoveryInput(ownerInput), {
    ...ownerInput,
    reason: "In-person identity verified",
  });
  for (
    const invalid of [
      null,
      [],
      {},
      { ...ownerInput, identityVerified: false },
      { ...ownerInput, identityVerified: "true" },
      { ...ownerInput, reason: "    " },
      { ...ownerInput, reason: "x".repeat(501) },
      { ...ownerInput, reason: "1234" },
      { ...ownerInput, memberId: "invalid" },
      { ...ownerInput, actorUserId: "forged" },
      { ...ownerInput, expiresAt: "2099-01-01" },
      { ...ownerInput, method: "remote" },
    ]
  ) {
    assertEquals(parseOwnerPinRecoveryInput(invalid), null);
  }
});

Deno.test("reset accepts a six-digit string PIN and exact token payload only", () => {
  assertEquals(parseMemberPinResetInput(resetInput), resetInput);
  for (
    const invalid of [
      null,
      [],
      {},
      { ...resetInput, pin: 123456 },
      { ...resetInput, pin: "12345" },
      { ...resetInput, pin: "１２３４５６" },
      { ...resetInput, pin: "1234567" },
      { ...resetInput, token: "a".repeat(42) },
      { ...resetInput, token: "!".repeat(43) },
      { ...resetInput, memberId: ownerInput.memberId },
      { ...resetInput, credentialVersion: 99 },
    ]
  ) {
    assertEquals(parseMemberPinResetInput(invalid), null);
  }
});

Deno.test("request reader checks actual streamed byte size and UTF-8, not just declared length", async () => {
  const request = (body: string, headers: Record<string, string> = {}) =>
    new Request("https://synthetic.invalid", {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body,
    });
  assertEquals(
    await readPinRequestBody(request(JSON.stringify(resetInput))),
    resetInput,
  );
  await assertRejects(() =>
    readPinRequestBody(
      request("{}", { "Content-Type": "application/json-invalid" }),
    )
  );
  await assertRejects(() =>
    readPinRequestBody(request("{}", { "Content-Length": "3000" }))
  );
  await assertRejects(() =>
    readPinRequestBody(request("x".repeat(2049), { "Content-Length": "1" }))
  );
  await assertRejects(() =>
    readPinRequestBody(request(JSON.stringify({ text: "漢".repeat(700) })))
  );
  await assertRejects(() => readPinRequestBody(request("not-json")));
  let cancelled = false;
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(2049));
    },
    cancel() {
      cancelled = true;
    },
  });
  await assertRejects(() =>
    readPinRequestBody(
      new Request("https://synthetic.invalid", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: stream,
      }),
    )
  );
  assertEquals(cancelled, true);
});

Deno.test("token digest uses SHA-256 without returning token material", async () => {
  assertEquals(
    await hashPinRecoveryToken("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});
