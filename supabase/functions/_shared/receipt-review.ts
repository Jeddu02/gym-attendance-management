import { parsePositiveWalkinPhp } from "./walkin-request.ts";

const uuid = (value: unknown): value is string => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(value);
export function receiptReviewOperation(value: unknown): { rpc: string; args: Record<string, unknown> } {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("INVALID_REQUEST");
  const input = value as Record<string, unknown>;
  const exact = (keys: string[]) => { if (Object.keys(input).some((key) => !keys.includes(key))) throw Error("INVALID_REQUEST"); };
  if (input.action === "list") {
    exact(["action", "limit", "offset"]);
    const limit = input.limit ?? 50; const offset = input.offset ?? 0;
    if (!Number.isInteger(limit) || Number(limit) < 1 || Number(limit) > 100 || !Number.isInteger(offset) || Number(offset) < 0 || Number(offset) > 100000) throw Error("INVALID_REQUEST");
    return { rpc: "owner_list_receipt_review", args: { p_limit: limit, p_offset: offset } };
  }
  if (typeof input.reason !== "string" || input.reason.trim().length < 5 || input.reason.trim().length > 500
    || typeof input.evidenceReference !== "string" || !input.evidenceReference.trim() || input.evidenceReference.trim().length > 300) throw Error("INVALID_REQUEST");
  const args: Record<string, unknown> = { p_reason: input.reason.trim(), p_evidence_reference: input.evidenceReference.trim() };
  if (input.action === "record") {
    exact(["action", "operationId", "amountPhp", "paymentMethod", "reason", "evidenceReference", "evidenceReviewed", "replacesPaymentId"]);
    if (!uuid(input.operationId) || !["cash", "gcash", "bank_transfer"].includes(String(input.paymentMethod))
      || input.evidenceReviewed !== true || (input.replacesPaymentId != null && !uuid(input.replacesPaymentId))) throw Error("INVALID_REQUEST");
    const amount = parsePositiveWalkinPhp(input.amountPhp);
    if (!amount) throw Error("INVALID_REQUEST");
    Object.assign(args, { p_operation_id: input.operationId, p_amount_php: amount, p_payment_method: input.paymentMethod,
      p_evidence_reviewed: true, p_replaces_payment_id: input.replacesPaymentId ?? null });
    return { rpc: "owner_record_actual_receipt", args };
  }
  if (!uuid(input.paymentId)) throw Error("INVALID_REQUEST");
  args.p_payment_id = input.paymentId;
  if (input.action === "allocate") {
    exact(["action", "paymentId", "purchaseId", "walkinRequestId", "confirmCurrentPresence", "reason", "evidenceReference"]);
    const purchaseId = input.purchaseId ?? null; const requestId = input.walkinRequestId ?? null;
    if ((purchaseId === null) === (requestId === null) || (purchaseId !== null && !uuid(purchaseId))
      || (requestId !== null && !uuid(requestId)) || typeof input.confirmCurrentPresence !== "boolean"
      || (requestId !== null && !input.confirmCurrentPresence) || (purchaseId !== null && input.confirmCurrentPresence)) throw Error("INVALID_REQUEST");
    Object.assign(args, { p_membership_purchase_id: purchaseId, p_walkin_request_id: requestId, p_confirm_current_presence: input.confirmCurrentPresence });
    return { rpc: "owner_allocate_verified_receipt", args };
  }
  if (input.action === "verify") {
    exact(["action", "paymentId", "reason", "evidenceReference", "evidenceReviewed"]);
    if (input.evidenceReviewed !== true) throw Error("INVALID_REQUEST");
    args.p_evidence_reviewed = true;
    return { rpc: "owner_verify_actual_receipt", args };
  }
  if (input.action === "void") {
    exact(["action", "paymentId", "reason", "evidenceReference", "receiptStillReceived"]);
    if (typeof input.receiptStillReceived !== "boolean") throw Error("INVALID_REQUEST");
    args.p_receipt_still_received = input.receiptStillReceived;
    return { rpc: "owner_void_payment_confirmation", args };
  }
  throw Error("INVALID_REQUEST");
}
