import { isValidMemberId } from "./pin-enrollment.ts";

export type WalkinPaymentMethod = "cash" | "gcash" | "bank_transfer";
export type OwnerWalkinInput =
  | { action: "fee"; feePhp: string; reason: string }
  | { action: "list"; limit: number; offset: number }
  | { action: "confirm"; requestId: string; operationId: string; amountPhp: string; paymentMethod: WalkinPaymentMethod; evidenceReviewed: boolean };

const isMethod = (value: unknown): value is WalkinPaymentMethod =>
  value === "cash" || value === "gcash" || value === "bank_transfer";
const record = (value: unknown): Record<string, unknown> | null =>
  typeof value === "object" && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null;
const keys = (value: Record<string, unknown>, allowed: string[]) =>
  Object.keys(value).every((key) => allowed.includes(key));

/** Exact cents: reject exponent notation, rounding, zero and numeric inputs. */
export function parsePositiveWalkinPhp(value: unknown): string | null {
  if (typeof value !== "string" || !/^(?:0|[1-9][0-9]{0,9})(?:\.[0-9]{1,2})?$/u.test(value)) return null;
  const [whole, decimal = ""] = value.split(".");
  const fraction = decimal.padEnd(2, "0");
  const cents = BigInt(whole) * 100n + BigInt(fraction);
  return cents > 0n && cents <= 999999999999n ? `${whole}.${fraction}` : null;
}

export function parseOwnerWalkinInput(value: unknown): OwnerWalkinInput | null {
  const input = record(value);
  if (!input) return null;
  if (input.action === "fee") {
    if (!keys(input, ["action", "feePhp", "reason"]) || typeof input.reason !== "string") return null;
    const feePhp = parsePositiveWalkinPhp(input.feePhp);
    const reason = input.reason.trim();
    if (!feePhp || reason.length < 5 || reason.length > 500) return null;
    return { action: "fee", feePhp, reason };
  }
  if (input.action === "list") {
    if (!keys(input, ["action", "limit", "offset"])) return null;
    const limit = input.limit === undefined ? 50 : input.limit;
    const offset = input.offset === undefined ? 0 : input.offset;
    if (typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100 ||
      typeof offset !== "number" || !Number.isInteger(offset) || offset < 0 || offset > 100000) return null;
    return { action: "list", limit, offset };
  }
  if (input.action === "confirm") {
    if (!keys(input, ["action", "requestId", "operationId", "amountPhp", "paymentMethod", "evidenceReviewed"]) ||
      !isValidMemberId(input.requestId) || !isValidMemberId(input.operationId) ||
      !isMethod(input.paymentMethod) || typeof input.evidenceReviewed !== "boolean") return null;
    const amountPhp = parsePositiveWalkinPhp(input.amountPhp);
    if (!amountPhp) return null;
    return { action: "confirm", requestId: input.requestId, operationId: input.operationId, amountPhp, paymentMethod: input.paymentMethod, evidenceReviewed: input.evidenceReviewed };
  }
  return null;
}

export function parsePublicWalkinInput(value: unknown): { paymentMethod: WalkinPaymentMethod } | null {
  const input = record(value);
  if (!input || Object.keys(input).length !== 1 || !isMethod(input.paymentMethod)) return null;
  return { paymentMethod: input.paymentMethod };
}

/** Operational development value must be explicitly set; no implied threshold. */
export function parseWalkinRequestLimit(value: string | undefined): number | null {
  if (!value || !/^[1-9][0-9]{0,2}$/u.test(value)) return null;
  const limit = Number(value);
  return limit <= 100 ? limit : null;
}
