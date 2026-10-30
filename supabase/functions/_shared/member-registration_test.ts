import { parseMemberRegistrationInput } from "./member-registration.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, received ${
        JSON.stringify(actual)
      }`,
    );
  }
}

function assertInvalidRegistration(callback: () => unknown): void {
  let caught: unknown;
  try {
    callback();
  } catch (error) {
    caught = error;
  }

  if (!(caught instanceof Error)) {
    throw new Error("Expected registration validation to reject the input");
  }
  assertEquals(caught.message, "Invalid registration details");
}

Deno.test("registration input trims name and canonicalizes mobile", () => {
  assertEquals(
    parseMemberRegistrationInput({
      fullName: "  Sample Member  ",
      mobile: "0917 123 4567",
    }),
    { fullName: "Sample Member", mobile: "+639171234567" },
  );
});

Deno.test("registration input rejects malformed or unexpected fields", () => {
  for (
    const input of [
      null,
      [],
      { fullName: " ", mobile: "09171234567" },
      { fullName: "A\nB", mobile: "09171234567" },
      { fullName: "A".repeat(121), mobile: "09171234567" },
      { fullName: "Sample", mobile: "123" },
      { fullName: "Sample", mobile: "09171234567", status: "active" },
    ]
  ) {
    assertInvalidRegistration(() => parseMemberRegistrationInput(input));
  }
});

Deno.test("registration validation errors do not echo submitted PII", () => {
  assertInvalidRegistration(() =>
    parseMemberRegistrationInput({
      fullName: "Sensitive Sample Name",
      mobile: "not-a-phone-number",
    })
  );
});
