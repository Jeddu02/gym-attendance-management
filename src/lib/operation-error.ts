/** Only explicit rejection responses permit editing a financial retry payload. */
export function operationWasRejected(error: unknown): boolean {
  if (!error || typeof error !== 'object' || !('context' in error) || !(error.context instanceof Response)) return false;
  return [400, 401, 403, 404, 409].includes(error.context.status);
}
