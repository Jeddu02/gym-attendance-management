/** Never render server messages: they may contain private records or SQL details. */
export async function functionErrorMessage(error: unknown, fallback: string): Promise<string> {
  const context = error && typeof error === 'object' && 'context' in error ? error.context : undefined;
  if (!(context instanceof Response)) return fallback;
  if (context.status === 401) return 'Your session could not be verified. Sign in again and retry.';
  if (context.status === 403) return 'Access was denied. The Owner must check account authorization and the allowed website origin.';
  if (context.status === 429) return 'Too many requests. Wait a moment before trying again.';
  if (context.status === 404) return 'The service or record is unavailable. The Owner must check the backend deployment.';
  if (context.status >= 500) return 'The backend service is unavailable. The Owner must check its deployment and configuration, then retry.';
  return fallback;
}
