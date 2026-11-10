import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  lifecycleFailure,
  parseLifecycleCommand,
} from "./membership-lifecycle.ts";

const id = "00000000-0000-4000-8000-000000000010";
Deno.test("approval accepts only member ID and bounded documented reason", () => {
  assertEquals(
    parseLifecycleCommand({
      action: "approve",
      memberId: id,
      reason: "  Verified in person  ",
    }),
    {
      rpcName: "owner_approve_member",
      args: { p_member_id: id, p_reason: "Verified in person" },
      outputKey: "member",
    },
  );
});
Deno.test("activation has no browser dates or payment assertions", () => {
  assertEquals(
    parseLifecycleCommand({ action: "activate", membershipPurchaseId: id }),
    {
      rpcName: "owner_activate_membership_purchase",
      args: { p_membership_purchase_id: id },
      outputKey: "purchase",
    },
  );
});
for (
  const extra of [
    "actorUserId",
    "p_actor_user_id",
    "activationDate",
    "expiryDate",
    "approvedAt",
    "paymentConfirmed",
    "pricePhp",
  ]
) {
  Deno.test(`rejects client-controlled privileged field ${extra}`, () => {
    assertThrows(
      () =>
        parseLifecycleCommand({
          action: "activate",
          membershipPurchaseId: id,
          [extra]: "untrusted",
        }),
      Error,
      "INVALID_LIFECYCLE_REQUEST",
    );
    assertThrows(
      () =>
        parseLifecycleCommand({
          action: "approve",
          memberId: id,
          reason: "Verified in person",
          [extra]: "untrusted",
        }),
      Error,
      "INVALID_LIFECYCLE_REQUEST",
    );
  });
}
Deno.test("malformed IDs, actions and approval evidence fail without echoing input", () => {
  for (
    const input of [
      null,
      [],
      "private input",
      {},
      { action: "cancel" },
      { action: "activate", membershipPurchaseId: "not a UUID" },
      { action: "approve", memberId: id, reason: "    " },
      { action: "approve", memberId: id, reason: "x".repeat(501) },
    ]
  ) {
    const error = assertThrows(() => parseLifecycleCommand(input), Error);
    assertEquals(error.message, "INVALID_LIFECYCLE_REQUEST");
  }
});
Deno.test("SQL failures produce bounded, non-sensitive public errors", () => {
  assertEquals(lifecycleFailure("42501"), {
    status: 403,
    error: "OWNER_ACCESS_REQUIRED",
  });
  assertEquals(lifecycleFailure("23514"), {
    status: 409,
    error: "LIFECYCLE_STATE_CONFLICT",
  });
  assertEquals(lifecycleFailure("40P01"), {
    status: 409,
    error: "LIFECYCLE_RETRY_REQUIRED",
  });
  assertEquals(lifecycleFailure(undefined), {
    status: 503,
    error: "LIFECYCLE_UNAVAILABLE",
  });
});
