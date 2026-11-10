import { assertEquals } from "jsr:@std/assert@1";
import { validateOwnerRegisterRequest } from "./owner-register-request.ts";

const allowedOrigin = "http://localhost:5173";

Deno.test("rejects JSON-looking media type suffixes", async () => {
  const result = await validateOwnerRegisterRequest(
    new Request("http://localhost", {
      method: "POST",
      headers: {
        Origin: allowedOrigin,
        Authorization: "Bearer synthetic",
        "Content-Type": "application/json-invalid",
      },
      body: "{}",
    }),
    allowedOrigin,
  );
  assertEquals(result, {
    ok: false,
    status: 415,
    error: "UNSUPPORTED_MEDIA_TYPE",
  });
});

Deno.test("rejects methods other than POST", async () => {
  const request = new Request("http://localhost", { method: "GET" });
  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: false,
    status: 405,
    error: "METHOD_NOT_ALLOWED",
  });
});

Deno.test("rejects missing authorization", async () => {
  const request = new Request("http://localhost", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Origin: allowedOrigin,
    },
    body: JSON.stringify({}),
  });

  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: false,
    status: 401,
    error: "AUTHENTICATION_REQUIRED",
  });
});

Deno.test("rejects an empty bearer token", async () => {
  const request = new Request("http://localhost", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer ",
      Origin: allowedOrigin,
    },
    body: JSON.stringify({}),
  });

  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: false,
    status: 401,
    error: "AUTHENTICATION_REQUIRED",
  });
});

Deno.test("rejects malformed JSON", async () => {
  const request = new Request("http://localhost", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
      Origin: allowedOrigin,
    },
    body: "{invalid-json",
  });

  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: false,
    status: 400,
    error: "INVALID_REQUEST_BODY",
  });
});

Deno.test("accepts a valid request and extracts its token and body", async () => {
  const body = { fullName: "Test Member", mobile: "09171234567" };

  const request = new Request("http://localhost", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
      Origin: allowedOrigin,
    },
    body: JSON.stringify(body),
  });

  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: true,
    accessToken: "test-token",
    body,
  });
});

Deno.test("rejects a mismatched origin", async () => {
  const request = new Request("http://localhost", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
      Origin: "https://unexpected.example",
    },
    body: JSON.stringify({}),
  });

  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: false,
    status: 403,
    error: "ORIGIN_NOT_ALLOWED",
  });
});

Deno.test("rejects a non-JSON content type", async () => {
  const request = new Request("http://localhost", {
    method: "POST",
    headers: {
      "Content-Type": "text/plain",
      Authorization: "Bearer test-token",
      Origin: allowedOrigin,
    },
    body: "{}",
  });

  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: false,
    status: 415,
    error: "UNSUPPORTED_MEDIA_TYPE",
  });
});

Deno.test("rejects a request with no origin header", async () => {
  const request = new Request("http://localhost", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
    },
    body: JSON.stringify({}),
  });

  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: false,
    status: 403,
    error: "ORIGIN_NOT_ALLOWED",
  });
});

Deno.test("rejects request bodies larger than 2048 bytes", async () => {
  const request = new Request("http://localhost", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
      Origin: allowedOrigin,
    },
    body: JSON.stringify({
      fullName: "A".repeat(3000),
      mobile: "09171234567",
    }),
  });

  const result = await validateOwnerRegisterRequest(request, allowedOrigin);

  assertEquals(result, {
    ok: false,
    status: 413,
    error: "REQUEST_TOO_LARGE",
  });
});
