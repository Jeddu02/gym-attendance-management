type BrowserHandler = (request: Request) => Response | Promise<Response>;

/** Origin/preflight boundary only. POST authorization and release gates stay inside. */
export function withBrowserCors(
  allowedOrigin: string | undefined,
  handler: BrowserHandler,
): BrowserHandler {
  let validOrigin = false;
  try {
    const url = new URL(allowedOrigin ?? "");
    validOrigin = ["https:", "http:"].includes(url.protocol)
      && url.origin === allowedOrigin && !url.username && !url.password;
  } catch { /* Missing or malformed configuration fails closed. */ }

  const reject = (status: number, error: string) => new Response(JSON.stringify({ error }), {
    status,
    // No CORS allow headers on denied/misconfigured requests.
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store", "Vary": "Origin" },
  });

  return (request) => {
    if (!validOrigin) return reject(503, "SERVICE_UNAVAILABLE");
    if (request.headers.get("Origin") !== allowedOrigin) return reject(403, "ORIGIN_NOT_ALLOWED");
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": allowedOrigin!,
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
          "Cache-Control": "no-store", "Vary": "Origin",
        },
      });
    }
    return handler(request);
  };
}
