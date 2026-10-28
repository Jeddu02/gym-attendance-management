import { createClient, type SupabaseClient } from '@supabase/supabase-js';

let client: SupabaseClient | undefined;

export class SupabaseConfigurationError extends Error {
  override name = 'SupabaseConfigurationError';
}

function isPrivilegedKey(key: string): boolean {
  if (key.startsWith('sb_secret_')) return true;

  const payload = key.split('.')[1];
  if (!payload) return false;

  try {
    const decodedPayload = JSON.parse(
      atob(payload.replaceAll('-', '+').replaceAll('_', '/')),
    ) as { role?: unknown };
    return decodedPayload.role === 'service_role';
  } catch {
    return false;
  }
}

/**
 * Create the browser client only when a future feature needs it. Keeping this
 * lazy lets the foundation landing page render before local credentials exist.
 */
export function getSupabaseClient(): SupabaseClient {
  if (client) return client;

  const url = import.meta.env.VITE_SUPABASE_URL?.trim();
  const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();

  const missing = [
    !url && 'VITE_SUPABASE_URL',
    !publishableKey && 'VITE_SUPABASE_PUBLISHABLE_KEY',
  ].filter(Boolean);

  if (missing.length > 0) {
    throw new SupabaseConfigurationError(
      `Missing Supabase configuration: ${missing.join(', ')}. ` +
        'Copy .env.example to .env.local and set these values from your Supabase Dashboard.',
    );
  }

  if (!url || !publishableKey) {
    throw new SupabaseConfigurationError(
      'Both VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY are required.',
    );
  }

  if (isPrivilegedKey(publishableKey)) {
    throw new SupabaseConfigurationError(
      'VITE_SUPABASE_PUBLISHABLE_KEY must be a publishable key. Secret and service-role keys must never be used in browser code.',
    );
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(url);
  } catch {
    throw new SupabaseConfigurationError(
      'VITE_SUPABASE_URL must be a valid Supabase project URL.',
    );
  }

  const isLocalhost = ['localhost', '127.0.0.1', '[::1]'].includes(
    parsedUrl.hostname,
  );

  if (
    (parsedUrl.protocol !== 'https:' &&
      !(parsedUrl.protocol === 'http:' && isLocalhost)) ||
    !parsedUrl.hostname ||
    parsedUrl.username ||
    parsedUrl.password
  ) {
    throw new SupabaseConfigurationError(
      'VITE_SUPABASE_URL must use HTTPS (or HTTP on localhost for local development) and must not contain credentials.',
    );
  }

  client = createClient(url, publishableKey);
  return client;
}
