import { normalizePhilippineMobile } from "./member-mobile.ts";

/** The accepted public registration payload. It is input only, never persisted here. */
export interface MemberRegistrationInput {
  fullName: string;
  mobile: string;
}

function containsControlCharacter(value: string): boolean {
  for (const character of value) {
    const codePoint = character.codePointAt(0);
    if (codePoint !== undefined && (codePoint <= 0x1f || codePoint === 0x7f)) {
      return true;
    }
  }
  return false;
}

/**
 * Validate untrusted JSON and normalize fields for a trusted server operation.
 * Errors intentionally avoid echoing submitted values (which may contain PII).
 */
export function parseMemberRegistrationInput(
  value: unknown,
): MemberRegistrationInput {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("Invalid registration details");
  }

  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).some((key) => key !== "fullName" && key !== "mobile") ||
    typeof record.fullName !== "string" ||
    typeof record.mobile !== "string"
  ) {
    throw new Error("Invalid registration details");
  }

  const fullName = record.fullName.trim();
  if (
    fullName.length === 0 ||
    fullName.length > 120 ||
    containsControlCharacter(fullName)
  ) {
    throw new Error("Invalid registration details");
  }

  let mobile: string;
  try {
    mobile = normalizePhilippineMobile(record.mobile);
  } catch {
    throw new Error("Invalid registration details");
  }

  return { fullName, mobile };
}
