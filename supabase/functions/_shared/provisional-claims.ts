import { isValidMemberId } from "./pin-enrollment.ts";
export function claimOperation(value: unknown): { rpc: string; args: Record<string, unknown> } {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("INVALID_REQUEST");
  const input = value as Record<string, unknown>;
  const exact = (keys: string[]) => { if (Object.keys(input).some((key) => !keys.includes(key))) throw Error("INVALID_REQUEST"); };
  if (input.action === "list") {
    exact(["action", "limit", "offset"]);
    const limit = input.limit ?? 50; const offset = input.offset ?? 0;
    if (typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100 || typeof offset !== "number" || !Number.isInteger(offset) || offset < 0 || offset > 100000) throw Error("INVALID_REQUEST");
    return { rpc: "owner_list_attendance_claims", args: { p_limit: limit, p_offset: offset } };
  }
  if (input.action === "submit") {
    exact(["action", "operationId", "memberCode", "claimedLocalDate"]);
    if (!isValidMemberId(input.operationId) || typeof input.memberCode !== "string" || !/^MBR-[0-9A-F]{12}$/u.test(input.memberCode)
      || typeof input.claimedLocalDate !== "string" || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/u.test(input.claimedLocalDate) || input.claimedLocalDate.startsWith("0000")) throw Error("INVALID_REQUEST");
    const date = new Date(`${input.claimedLocalDate}T00:00:00Z`);
    if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0,10) !== input.claimedLocalDate) throw Error("INVALID_REQUEST");
    return { rpc: "owner_submit_attendance_claim", args: { p_operation_id: input.operationId, p_member_code: input.memberCode, p_claimed_local_date: input.claimedLocalDate } };
  }
  if (input.action === "resolve") {
    exact(["action", "claimId", "confirmCurrentPresence", "reason"]);
    if (!isValidMemberId(input.claimId) || typeof input.confirmCurrentPresence !== "boolean" || typeof input.reason !== "string" || input.reason.trim().length < 5 || input.reason.trim().length > 500) throw Error("INVALID_REQUEST");
    return { rpc: "owner_resolve_attendance_claim", args: { p_claim_id: input.claimId, p_confirm_current_presence: input.confirmCurrentPresence, p_reason: input.reason.trim() } };
  }
  throw Error("INVALID_REQUEST");
}
