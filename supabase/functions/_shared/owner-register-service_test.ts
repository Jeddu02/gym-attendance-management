import { assertEquals } from "jsr:@std/assert@1";

import {
  type OwnerRegisterDependencies,
  registerOwnerMember,
} from "./owner-register-service.ts";

function createDependencies(
  overrides: Partial<OwnerRegisterDependencies> = {},
): OwnerRegisterDependencies {
  return {
    authenticate: () => Promise.resolve("owner-user-id"),
    isActiveOwner: () => Promise.resolve(true),
    hashMobile: () => Promise.resolve(new Uint8Array(32).fill(1)),
    encryptMobile: () => Promise.resolve(new Uint8Array(40).fill(2)),
    insertMember: () =>
      Promise.resolve({
        id: "member-id",
        member_code: "MBR-TEST123456",
        status: "pending",
      }),
    ...overrides,
  };
}

const validBody = {
  fullName: "Test Member",
  mobile: "09171234567",
};

Deno.test("registers a member for an authenticated active owner", async () => {
  let inserted = false;

  const result = await registerOwnerMember(
    "valid-token",
    validBody,
    createDependencies({
      insertMember: (input) => {
        inserted = true;
        assertEquals(input.actorUserId, "owner-user-id");
        assertEquals(input.fullName, "Test Member");
        assertEquals(input.mobileLookupHash.length, 32);
        return Promise.resolve({ id: "member-id", status: "pending" });
      },
    }),
  );

  assertEquals(inserted, true);
  assertEquals(result.status, 201);
  assertEquals(result.body.success, true);
});

Deno.test("rejects invalid authentication", async () => {
  const result = await registerOwnerMember(
    "invalid-token",
    validBody,
    createDependencies({
      authenticate: () => Promise.resolve(null),
    }),
  );

  assertEquals(result.status, 401);
  assertEquals(result.body.error, "INVALID_AUTHENTICATION");
});

Deno.test("returns unavailable when authentication service fails", async () => {
  const result = await registerOwnerMember(
    "token",
    validBody,
    createDependencies({
      authenticate: () => Promise.reject(new Error("network failure")),
    }),
  );

  assertEquals(result.status, 503);
  assertEquals(result.body.error, "AUTHENTICATION_UNAVAILABLE");
});

Deno.test("rejects invalid registration details", async () => {
  const result = await registerOwnerMember(
    "token",
    { fullName: "", mobile: "invalid" },
    createDependencies(),
  );

  assertEquals(result.status, 400);
  assertEquals(result.body.error, "INVALID_REGISTRATION_DETAILS");
});

Deno.test("blocks inactive owners before encryption or insertion", async () => {
  let encryptionCalled = false;
  let insertionCalled = false;

  const result = await registerOwnerMember(
    "token",
    validBody,
    createDependencies({
      isActiveOwner: () => Promise.resolve(false),
      encryptMobile: () => {
        encryptionCalled = true;
        return Promise.resolve(new Uint8Array(40));
      },
      insertMember: () => {
        insertionCalled = true;
        return Promise.resolve({});
      },
    }),
  );

  assertEquals(result.status, 403);
  assertEquals(result.body.error, "OWNER_ACCESS_REQUIRED");
  assertEquals(encryptionCalled, false);
  assertEquals(insertionCalled, false);
});

Deno.test("returns unavailable when owner verification fails", async () => {
  const result = await registerOwnerMember(
    "token",
    validBody,
    createDependencies({
      isActiveOwner: () => Promise.reject(new Error("database unavailable")),
    }),
  );

  assertEquals(result.status, 503);
  assertEquals(result.body.error, "OWNER_VERIFICATION_UNAVAILABLE");
});

Deno.test("maps duplicate mobile errors to conflict", async () => {
  const result = await registerOwnerMember(
    "token",
    validBody,
    createDependencies({
      insertMember: () => Promise.reject(new Error("MEMBER_MOBILE_EXISTS")),
    }),
  );

  assertEquals(result.status, 409);
  assertEquals(result.body.error, "MOBILE_ALREADY_REGISTERED");
});

Deno.test("does not expose unexpected database errors", async () => {
  const result = await registerOwnerMember(
    "token",
    validBody,
    createDependencies({
      insertMember: () =>
        Promise.reject(new Error("sensitive database details")),
    }),
  );

  assertEquals(result.status, 500);
  assertEquals(result.body.error, "MEMBER_REGISTRATION_FAILED");
});
