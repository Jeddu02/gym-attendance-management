import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { receiptReviewOperation } from "./receipt-review.ts";
const id = "61000000-0000-4000-8000-000000000001";
const base = { reason: "Original bank evidence reviewed", evidenceReference: "SYNTHETIC-1" };
Deno.test("receipt operations require explicit verified evidence and exact decimal amount", () => {
  const input = { action: "record", operationId: id, amountPhp: "125.00", paymentMethod: "cash", evidenceReviewed: true, ...base };
  assertEquals(receiptReviewOperation(input).args.p_amount_php, "125.00");
  for (const amountPhp of [125, "1e2", "125.001", "-1", "0"]) assertThrows(() => receiptReviewOperation({ ...input, amountPhp }));
  assertThrows(() => receiptReviewOperation({ ...input, evidenceReviewed: false }));
  assertThrows(() => receiptReviewOperation({ ...input, actorUserId: id }));
});
Deno.test("correction cannot default physical receipt status or omit documented reason", () => {
  assertEquals(receiptReviewOperation({ action: "void", paymentId: id, receiptStillReceived: false, ...base }).args.p_receipt_still_received, false);
  assertThrows(() => receiptReviewOperation({ action: "void", paymentId: id, ...base }));
  assertThrows(() => receiptReviewOperation({ action: "verify", paymentId: id, ...base, evidenceReviewed: true, reason: "" }));
  assertThrows(() => receiptReviewOperation({ action: "list", offset: 100001 }));
});
Deno.test("reviewed allocation requires exactly one target and explicit current walk-in presence", () => {
  const input = { action: "allocate", paymentId: id, purchaseId: id, walkinRequestId: null, confirmCurrentPresence: false, ...base };
  assertEquals(receiptReviewOperation(input).rpc, "owner_allocate_verified_receipt");
  assertThrows(() => receiptReviewOperation({ ...input, walkinRequestId: id }));
  assertThrows(() => receiptReviewOperation({ ...input, purchaseId: null }));
  assertThrows(() => receiptReviewOperation({ ...input, purchaseId: null, walkinRequestId: id }));
  assertEquals(receiptReviewOperation({ ...input, purchaseId: null, walkinRequestId: id, confirmCurrentPresence: true }).args.p_confirm_current_presence, true);
});
