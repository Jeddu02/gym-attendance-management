import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { cashOperation } from "./cash-operations.ts";
const id = "71000000-0000-4000-8000-000000000001";
Deno.test("cash opening requires explicit attestation and allows exact zero float", () => {
  const input = { action: "open", operationId: id, openingFloatPhp: "0.00", attested: true };
  assertEquals(cashOperation(input).args.p_opening_float_php, "0.00");
  for (const openingFloatPhp of [0, "-1", "1e2", "1.001"]) assertThrows(() => cashOperation({ ...input, openingFloatPhp }));
  assertThrows(() => cashOperation({ ...input, attested: false }));
  assertThrows(() => cashOperation({ ...input, businessDate: "2020-01-01" }));
});
Deno.test("cash close denies expected total overrides and undocumented variance", () => {
  const input = { action: "close", drawerId: id, countedCashPhp: "25.00", reason: "Synthetic counted variance", evidenceReference: "SYNTHETIC" };
  assertEquals(cashOperation(input).rpc, "owner_close_cash_drawer");
  assertThrows(() => cashOperation({ ...input, expectedCashPhp: "25.00" }));
  assertThrows(() => cashOperation({ ...input, evidenceReference: "" }));
  assertThrows(() => cashOperation({ action: "list", limit: "50" }));
});
