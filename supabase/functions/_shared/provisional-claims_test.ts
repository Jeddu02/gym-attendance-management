import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { claimOperation } from "./provisional-claims.ts";
const id = "81000000-0000-4000-8000-000000000001";
Deno.test("provisional claim accepts a date assertion without treating it as attendance", () => {
  const input = { action: "submit", operationId: id, memberCode: "MBR-ABCDEF123456", claimedLocalDate: "2024-02-29" };
  assertEquals(claimOperation(input).rpc, "owner_submit_attendance_claim");
  for (const claimedLocalDate of ["2023-02-29", "0000-01-01", "2024-02-30"]) assertThrows(() => claimOperation({ ...input, claimedLocalDate }));
  assertThrows(() => claimOperation({ ...input, attendanceStatus: "valid" }));
  assertThrows(() => claimOperation({ ...input, actorUserId: id }));
});
Deno.test("claim resolution requires explicit current presence choice and reason", () => {
  assertEquals(claimOperation({ action: "resolve", claimId: id, confirmCurrentPresence: false, reason: "Synthetic stale claim review" }).args.p_confirm_current_presence, false);
  assertThrows(() => claimOperation({ action: "resolve", claimId: id, reason: "Synthetic reason" }));
  assertThrows(() => claimOperation({ action: "resolve", claimId: id, confirmCurrentPresence: true, reason: "" }));
});
