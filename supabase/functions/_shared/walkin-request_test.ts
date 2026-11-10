import { assertEquals } from "jsr:@std/assert@1";
import { parseOwnerWalkinInput, parsePositiveWalkinPhp, parsePublicWalkinInput, parseWalkinRequestLimit } from "./walkin-request.ts";

const id = "00000000-0000-4000-8000-000000000001";
const confirm = { action: "confirm", requestId: id, operationId: id, amountPhp: "150.00", paymentMethod: "cash", evidenceReviewed: true } as const;

Deno.test("walk-in money preserves exact cents without implicit rounding", () => {
  for (const [value, expected] of [["1", "1.00"], ["0.01", "0.01"], ["25.5", "25.50"], ["9999999999.99", "9999999999.99"]]) assertEquals(parsePositiveWalkinPhp(value), expected);
  for (const value of [0, 1, null, "", "0", "0.00", "-1", "+1", " 1", "01", ".50", "1.", "1e2", "1.001", "10000000000", "NaN", "Infinity"]) assertEquals(parsePositiveWalkinPhp(value), null);
});

Deno.test("Owner walk-in actions deny actor/date/snapshot overrides and require receipt attestation fields", () => {
  assertEquals(parseOwnerWalkinInput(confirm), confirm);
  assertEquals(parseOwnerWalkinInput({ action: "list" }), { action: "list", limit: 50, offset: 0 });
  assertEquals(parseOwnerWalkinInput({ action: "fee", feePhp: "100", reason: " Synthetic fee decision " }), { action: "fee", feePhp: "100.00", reason: "Synthetic fee decision" });
  for (const value of [null, [], {}, { ...confirm, actorUserId: id }, { ...confirm, createdAt: "2026-01-01" },
    { ...confirm, expiry: "2026-01-01" }, { ...confirm, feeVersionId: id }, { ...confirm, paymentMethod: "card" },
    { ...confirm, evidenceReviewed: "true" }, { ...confirm, evidenceReviewed: undefined }, { ...confirm, operationId: "bad" },
    { action: "list", limit: 101 }, { action: "list", offset: -1 }, { action: "list", limit: null },
    { action: "fee", feePhp: "100", reason: "bad" }, { action: "fee", feePhp: "100", reason: "x".repeat(501) }]) {
    assertEquals(parseOwnerWalkinInput(value), null);
  }
});

Deno.test("public request can select payment method only and cannot choose price or identity", () => {
  for (const paymentMethod of ["cash", "gcash", "bank_transfer"]) assertEquals(parsePublicWalkinInput({ paymentMethod }), { paymentMethod });
  for (const value of [null, [], {}, { paymentMethod: "card" }, { paymentMethod: "cash", memberId: id },
    { paymentMethod: "cash", feePhp: "1" }, { paymentMethod: "cash", operationId: id }, { paymentMethod: "cash", requestLimit: 100 },
    { paymentMethod: "cash", expiresAt: "2099-01-01" }]) assertEquals(parsePublicWalkinInput(value), null);
});

Deno.test("development public request limiter has no default and accepts only explicit bounded integers", () => {
  assertEquals(parseWalkinRequestLimit("1"), 1);
  assertEquals(parseWalkinRequestLimit("100"), 100);
  for (const value of [undefined, "", "0", "101", "-1", "01", "1.0", "1e1", " 10", "Infinity"]) assertEquals(parseWalkinRequestLimit(value), null);
});
