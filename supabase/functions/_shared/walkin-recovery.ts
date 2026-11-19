import { parsePositiveWalkinPhp, type WalkinPaymentMethod } from "./walkin-request.ts";

export type RecoveryInput = { action: "lookup"; capability: string } |
  { action: "create"; capability: string; paymentMethod: WalkinPaymentMethod };

export function capabilityBytes(value: unknown): Uint8Array | null {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{43}$/.test(value)) return null;
  try {
    const raw = atob(value.replaceAll("-", "+").replaceAll("_", "/") + "=");
    const canonical = btoa(raw).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
    return raw.length === 32 && canonical === value ? Uint8Array.from(raw, c => c.charCodeAt(0)) : null;
  } catch { return null; }
}
export function parseRecoveryInput(value: unknown): RecoveryInput | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const v = value as Record<string, unknown>;
  if (!capabilityBytes(v.capability)) return null;
  if (v.action === "lookup" && Object.keys(v).sort().join(",") === "action,capability")
    return { action: "lookup", capability: v.capability as string };
  if (v.action === "create" && Object.keys(v).sort().join(",") === "action,capability,paymentMethod"
    && ["cash", "gcash", "bank_transfer"].includes(v.paymentMethod as string))
    return { action: "create", capability: v.capability as string, paymentMethod: v.paymentMethod as WalkinPaymentMethod };
  return null;
}
export async function capabilityDigest(capability: string): Promise<string> {
  const bytes = capabilityBytes(capability);
  if (!bytes) throw new Error("INVALID_REQUEST");
  const prefix = new TextEncoder().encode("gymforce:walkin-recovery:v1\0");
  const input = new Uint8Array(prefix.length + bytes.length);
  input.set(prefix); input.set(bytes, prefix.length);
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", input));
  return "\\x" + Array.from(hash, b => b.toString(16).padStart(2, "0")).join("");
}

/** Only the reviewed classification and provisional snapshot may cross this boundary. */
export function recoveryResponse(value: unknown, input: RecoveryInput): { status: number; body: Record<string, unknown> } | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const v = value as Record<string, unknown>;
  const negative: Record<string, number> = { OPERATION_CONFLICT: 409, RECOVERY_CLOSED: 410, NO_RECOVERABLE_OUTCOME: 404 };
  if (typeof v.classification !== "string") return null;
  if (Object.hasOwn(negative, v.classification)) return { status: negative[v.classification], body: { error: v.classification } };
  if (!["PROVISIONAL_CREATED", "PROVISIONAL_RECOVERED"].includes(v.classification)
    || (input.action === "lookup" && v.classification !== "PROVISIONAL_RECOVERED")) return null;
  if (!v.request || typeof v.request !== "object" || Array.isArray(v.request)) return null;
  const r = v.request as Record<string, unknown>;
  if (typeof r.id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(r.id)
    || r.currency !== "PHP" || !["cash", "gcash", "bank_transfer"].includes(r.paymentMethod as string)
    || (input.action === "create" && r.paymentMethod !== input.paymentMethod)
    || typeof r.feePhp !== "string" || !parsePositiveWalkinPhp(r.feePhp)
    || typeof r.createdAt !== "string" || typeof r.expiresAt !== "string"
    || !Number.isFinite(Date.parse(r.createdAt)) || !Number.isFinite(Date.parse(r.expiresAt))
    || Date.parse(r.expiresAt) <= Date.parse(r.createdAt)) return null;
  return { status: v.classification === "PROVISIONAL_CREATED" ? 201 : 200, body: {
    success: true, classification: v.classification, request: {
      id: r.id, feePhp: r.feePhp, currency: "PHP", paymentMethod: r.paymentMethod, createdAt: r.createdAt, expiresAt: r.expiresAt,
    },
  } };
}
