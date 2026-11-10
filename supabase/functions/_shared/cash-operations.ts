import { parsePositiveWalkinPhp } from "./walkin-request.ts";
import { isValidMemberId } from "./pin-enrollment.ts";
const cashAmount = (value: unknown): string | null => value === "0" || value === "0.0" || value === "0.00" ? "0.00" : parsePositiveWalkinPhp(value);
export function cashOperation(value: unknown): { rpc: string; args: Record<string, unknown> } {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("INVALID_REQUEST");
  const input = value as Record<string, unknown>;
  const exact = (keys: string[]) => { if (Object.keys(input).some((key) => !keys.includes(key))) throw Error("INVALID_REQUEST"); };
  if (input.action === "list") {
    exact(["action", "limit", "offset"]);
    const limit = input.limit ?? 50; const offset = input.offset ?? 0;
    if (typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100 || typeof offset !== "number" || !Number.isInteger(offset) || offset < 0 || offset > 100000) throw Error("INVALID_REQUEST");
    return { rpc: "owner_list_cash_drawers", args: { p_limit: limit, p_offset: offset } };
  }
  if (input.action === "open") {
    exact(["action", "operationId", "openingFloatPhp", "attested"]);
    const amount = cashAmount(input.openingFloatPhp);
    if (!isValidMemberId(input.operationId) || !amount || input.attested !== true) throw Error("INVALID_REQUEST");
    return { rpc: "owner_open_cash_drawer", args: { p_operation_id: input.operationId, p_opening_float_php: amount, p_attested: true } };
  }
  if (input.action === "close") {
    exact(["action", "drawerId", "countedCashPhp", "reason", "evidenceReference"]);
    const amount = cashAmount(input.countedCashPhp);
    if (!isValidMemberId(input.drawerId) || !amount || typeof input.reason !== "string" || input.reason.trim().length < 5 || input.reason.trim().length > 500
      || typeof input.evidenceReference !== "string" || !input.evidenceReference.trim() || input.evidenceReference.trim().length > 300) throw Error("INVALID_REQUEST");
    return { rpc: "owner_close_cash_drawer", args: { p_drawer_id: input.drawerId, p_counted_cash_php: amount, p_reason: input.reason.trim(), p_evidence_reference: input.evidenceReference.trim() } };
  }
  throw Error("INVALID_REQUEST");
}
