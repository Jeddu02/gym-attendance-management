export type LifecycleCommand = {
  rpcName: "owner_approve_member" | "owner_activate_membership_purchase";
  args: Record<string, string>;
  outputKey: "member" | "purchase";
};

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;

/** Never accepts actor IDs, dates, prices or payment assertions from a browser. */
export function parseLifecycleCommand(value: unknown): LifecycleCommand {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("INVALID_LIFECYCLE_REQUEST");
  }
  const input = value as Record<string, unknown>;
  if (input.action === "approve") {
    if (
      Object.keys(input).length !== 3 ||
      typeof input.memberId !== "string" || !uuid.test(input.memberId) ||
      typeof input.reason !== "string" || input.reason.trim().length < 5 ||
      input.reason.length > 500
    ) throw new Error("INVALID_LIFECYCLE_REQUEST");
    return {
      rpcName: "owner_approve_member",
      args: { p_member_id: input.memberId, p_reason: input.reason.trim() },
      outputKey: "member",
    };
  }
  if (input.action === "activate") {
    if (
      Object.keys(input).length !== 2 ||
      typeof input.membershipPurchaseId !== "string" ||
      !uuid.test(input.membershipPurchaseId)
    ) throw new Error("INVALID_LIFECYCLE_REQUEST");
    return {
      rpcName: "owner_activate_membership_purchase",
      args: { p_membership_purchase_id: input.membershipPurchaseId },
      outputKey: "purchase",
    };
  }
  throw new Error("INVALID_LIFECYCLE_REQUEST");
}

/** Return a bounded message; never forward SQL details or personal data. */
export function lifecycleFailure(code: string | undefined): {
  status: number;
  error: string;
} {
  switch (code) {
    case "42501":
      return { status: 403, error: "OWNER_ACCESS_REQUIRED" };
    case "22023":
      return { status: 400, error: "INVALID_LIFECYCLE_REQUEST" };
    case "P0002":
      return { status: 404, error: "LIFECYCLE_RECORD_UNAVAILABLE" };
    case "P0001":
    case "23514":
    case "23505":
    case "23P01":
      return { status: 409, error: "LIFECYCLE_STATE_CONFLICT" };
    case "40001":
    case "40P01":
    case "55P03":
      return { status: 409, error: "LIFECYCLE_RETRY_REQUIRED" };
    default:
      return { status: 503, error: "LIFECYCLE_UNAVAILABLE" };
  }
}
