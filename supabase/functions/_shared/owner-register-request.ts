export type OwnerRegisterRequestResult =
  | { ok: true; accessToken: string; body: unknown }
  | { ok: false; status: number; error: string };

export async function validateOwnerRegisterRequest(
  request: Request,
  allowedOrigin: string,
): Promise<OwnerRegisterRequestResult> {
  if (request.method !== "POST") {
    return { ok: false, status: 405, error: "METHOD_NOT_ALLOWED" };
  }

  const origin = request.headers.get("Origin");

  if (origin !== allowedOrigin) {
    return { ok: false, status: 403, error: "ORIGIN_NOT_ALLOWED" };
  }

  const contentType = request.headers.get("Content-Type") ?? "";

  if (contentType.split(";")[0].trim().toLowerCase() !== "application/json") {
    return { ok: false, status: 415, error: "UNSUPPORTED_MEDIA_TYPE" };
  }

  const contentLength = request.headers.get("Content-Length");

  if (contentLength !== null) {
    const declaredLength = Number(contentLength);

    if (!Number.isSafeInteger(declaredLength) || declaredLength < 0) {
      return { ok: false, status: 400, error: "INVALID_REQUEST_BODY" };
    }

    if (declaredLength > 2048) {
      return { ok: false, status: 413, error: "REQUEST_TOO_LARGE" };
    }
  }

  const authorization = request.headers.get("Authorization");

  if (!authorization?.startsWith("Bearer ")) {
    return { ok: false, status: 401, error: "AUTHENTICATION_REQUIRED" };
  }

  const accessToken = authorization.slice(7).trim();

  if (!accessToken) {
    return { ok: false, status: 401, error: "AUTHENTICATION_REQUIRED" };
  }

  let body: unknown;

  try {
    const reader = request.body?.getReader();

    if (!reader) {
      return { ok: false, status: 400, error: "INVALID_REQUEST_BODY" };
    }

    const chunks: Uint8Array[] = [];
    let totalBytes = 0;

    try {
      while (true) {
        const { done, value } = await reader.read();

        if (done) break;

        totalBytes += value.length;

        if (totalBytes > 2048) {
          await reader.cancel();
          return { ok: false, status: 413, error: "REQUEST_TOO_LARGE" };
        }

        chunks.push(value);
      }
    } finally {
      reader.releaseLock();
    }

    const combined = new Uint8Array(totalBytes);
    let offset = 0;

    for (const chunk of chunks) {
      combined.set(chunk, offset);
      offset += chunk.length;
    }

    body = JSON.parse(new TextDecoder().decode(combined));
  } catch {
    return { ok: false, status: 400, error: "INVALID_REQUEST_BODY" };
  }

  return { ok: true, accessToken, body };
}
