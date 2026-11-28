const VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';
export type ChallengeResult = 'accepted' | 'denied' | 'unavailable';
export type ChallengeAction = 'member_checkin' | 'walkin_request';
export function isLoopbackUrl(value: string | undefined): boolean {
  try { return ['localhost','127.0.0.1','[::1]'].includes(new URL(value ?? '').hostname); }
  catch { return false; }
}
export function localOnly(origin: string | undefined, backend: string | undefined): boolean {
  return isLoopbackUrl(origin) && isLoopbackUrl(backend);
}
export function splitChallenge(value: unknown): { body: Record<string, unknown>; token: string } | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  const { turnstileToken, ...body } = value as Record<string, unknown>;
  if (typeof turnstileToken !== 'string' || !/^[\x21-\x7e]{1,2048}$/.test(turnstileToken)) return null;
  return { body, token: turnstileToken };
}
export async function verifyTurnstile(token: string, secret: string | undefined, origin: string | undefined,
  action: ChallengeAction, signal?: AbortSignal, transport: typeof fetch = fetch): Promise<ChallengeResult> {
  if (!secret?.trim() || !origin) return 'unavailable';
  let hostname: string;
  try {
    const parsed = new URL(origin);
    if (parsed.protocol !== 'https:' || parsed.origin !== origin || parsed.username || parsed.password) return 'unavailable';
    hostname = parsed.hostname;
  } catch { return 'unavailable'; }
  if (!/^[\x21-\x7e]{1,2048}$/.test(token)) return 'denied';
  try {
    const timeout = AbortSignal.timeout(5000);
    const response = await transport(VERIFY_URL, {
      method: 'POST', redirect: 'error', cache: 'no-store',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({secret, response: token}),
      signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
    });
    if (!response.ok) return 'unavailable';
    const result: unknown = await response.json();
    if (!result || typeof result !== 'object' || Array.isArray(result)) return 'unavailable';
    const r = result as Record<string, unknown>;
    if (r.success !== true) return r.success === false ? 'denied' : 'unavailable';
    return r.hostname === hostname && r.action === action ? 'accepted' : 'denied';
  } catch { return 'unavailable'; }
}
