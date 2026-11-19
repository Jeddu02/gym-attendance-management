export type PaymentMethod = 'cash' | 'gcash' | 'bank_transfer';
export type WalkinRequest = {
  id: string;
  feePhp: string | number;
  currency: 'PHP';
  paymentMethod: PaymentMethod;
  createdAt: string;
  expiresAt: string;
};

/** Mirror the existing endpoint formats; never read capabilities from queries. */
export function privatePinToken(fragment: string, purpose: 'enrollment' | 'reset'): string {
  const candidate = new URLSearchParams(fragment.replace(/^#/, '')).get('token') ?? '';
  const pattern = purpose === 'reset' ? /^[A-Za-z0-9_-]{43}$/ : /^[A-Za-z0-9_-]{40,128}$/;
  return pattern.test(candidate) ? candidate : '';
}

/** Validate server snapshots without using device time to decide eligibility. */
export function parseWalkinRequest(value: unknown, method: PaymentMethod): WalkinRequest | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const request = value as Record<string, unknown>;
  if (typeof request.id !== 'string'
    || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(request.id)
    || request.currency !== 'PHP' || request.paymentMethod !== method
    || !['cash', 'gcash', 'bank_transfer'].includes(method)
    || !['string', 'number'].includes(typeof request.feePhp)
    || !/^(?:0|[1-9][0-9]{0,9})(?:\.[0-9]{1,2})?$/.test(String(request.feePhp))
    || Number(request.feePhp) <= 0
    || typeof request.createdAt !== 'string' || typeof request.expiresAt !== 'string') return null;
  const timestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/;
  if (!timestamp.test(request.createdAt) || !timestamp.test(request.expiresAt)) return null;
  const created = Date.parse(request.createdAt), expires = Date.parse(request.expiresAt);
  if (!Number.isFinite(created) || !Number.isFinite(expires) || expires <= created) return null;
  return {
    id: request.id, feePhp: request.feePhp as string | number, currency: 'PHP', paymentMethod: method,
    createdAt: request.createdAt, expiresAt: request.expiresAt,
  };
}
