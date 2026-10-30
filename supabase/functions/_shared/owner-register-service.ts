import { normalizePhilippineMobile } from "./member-mobile.ts";
import { parseMemberRegistrationInput } from "./member-registration.ts";

export type OwnerRegisterDependencies = {
  authenticate: (accessToken: string) => Promise<string | null>;
  isActiveOwner: (userId: string) => Promise<boolean>;
  hashMobile: (mobile: string) => Promise<Uint8Array>;
  encryptMobile: (mobile: string) => Promise<Uint8Array>;
  insertMember: (input: {
    actorUserId: string;
    fullName: string;
    mobileLookupHash: Uint8Array;
    mobileEncrypted: Uint8Array;
  }) => Promise<unknown>;
};

export type OwnerRegisterResult = {
  status: number;
  body: Record<string, unknown>;
};

function errorMessage(error: unknown): string {
  if (
    typeof error === "object" &&
    error !== null &&
    "message" in error &&
    typeof error.message === "string"
  ) {
    return error.message;
  }

  return "";
}

export async function registerOwnerMember(
  accessToken: string,
  body: unknown,
  dependencies: OwnerRegisterDependencies,
): Promise<OwnerRegisterResult> {
  let userId: string | null;

  try {
    userId = await dependencies.authenticate(accessToken);
  } catch {
    return {
      status: 503,
      body: { error: "AUTHENTICATION_UNAVAILABLE" },
    };
  }

  if (!userId) {
    return {
      status: 401,
      body: { error: "INVALID_AUTHENTICATION" },
    };
  }

  let registration: ReturnType<typeof parseMemberRegistrationInput>;
  let mobile: string;

  try {
    registration = parseMemberRegistrationInput(body);
    mobile = normalizePhilippineMobile(registration.mobile);
  } catch {
    return {
      status: 400,
      body: { error: "INVALID_REGISTRATION_DETAILS" },
    };
  }

  let activeOwner: boolean;

  try {
    activeOwner = await dependencies.isActiveOwner(userId);
  } catch {
    return {
      status: 503,
      body: { error: "OWNER_VERIFICATION_UNAVAILABLE" },
    };
  }

  if (!activeOwner) {
    return {
      status: 403,
      body: { error: "OWNER_ACCESS_REQUIRED" },
    };
  }

  try {
    const [mobileLookupHash, mobileEncrypted] = await Promise.all([
      dependencies.hashMobile(mobile),
      dependencies.encryptMobile(mobile),
    ]);

    const member = await dependencies.insertMember({
      actorUserId: userId,
      fullName: registration.fullName,
      mobileLookupHash,
      mobileEncrypted,
    });

    return {
      status: 201,
      body: {
        success: true,
        member,
      },
    };
  } catch (error) {
    const message = errorMessage(error);

    if (message.includes("MEMBER_MOBILE_EXISTS")) {
      return {
        status: 409,
        body: { error: "MOBILE_ALREADY_REGISTERED" },
      };
    }

    if (message.includes("OWNER_ACCESS_REQUIRED")) {
      return {
        status: 403,
        body: { error: "OWNER_ACCESS_REQUIRED" },
      };
    }

    return {
      status: 500,
      body: { error: "MEMBER_REGISTRATION_FAILED" },
    };
  }
}
