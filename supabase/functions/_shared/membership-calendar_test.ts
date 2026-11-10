import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  calculateMembershipTerm,
  gymLocalDate,
  oneCalendarMonthTerm,
} from "./membership-calendar.ts";

const instant = (value: string) => new Date(value);

for (
  const [activationDate, nextTermStart, inclusiveExpiry] of [
    ["2023-01-31", "2023-02-28", "2023-02-27"],
    ["2024-01-31", "2024-02-29", "2024-02-28"],
    ["2023-02-28", "2023-03-28", "2023-03-27"],
    ["2024-02-29", "2024-03-29", "2024-03-28"],
    ["2024-03-31", "2024-04-30", "2024-04-29"],
    ["2024-12-31", "2025-01-31", "2025-01-30"],
    ["2024-11-01", "2024-12-01", "2024-11-30"],
    ["2100-01-31", "2100-02-28", "2100-02-27"],
    ["2000-01-31", "2000-02-29", "2000-02-28"],
  ]
) {
  Deno.test(`Option A calendar term starting ${activationDate}`, () => {
    assertEquals(oneCalendarMonthTerm(activationDate), {
      activationDate,
      nextTermStart,
      inclusiveExpiry,
    });
  });
}

Deno.test("gym date changes at Manila midnight, independent of UTC date", () => {
  assertEquals(gymLocalDate(instant("2026-11-10T15:59:59.999Z")), "2026-11-10");
  assertEquals(gymLocalDate(instant("2026-11-10T16:00:00.000Z")), "2026-11-11");
  assertEquals(gymLocalDate(instant("2026-12-31T16:00:00.000Z")), "2027-01-01");
});

Deno.test("delayed payment confirmation cannot backdate initial activation", () => {
  assertEquals(
    calculateMembershipTerm({
      registrationApprovedAt: instant("2026-01-30T02:00:00Z"),
      fullPaymentConfirmedAt: instant("2026-01-30T16:00:00Z"),
    }),
    {
      activationDate: "2026-01-31",
      nextTermStart: "2026-02-28",
      inclusiveExpiry: "2026-02-27",
    },
  );
});

Deno.test("approval after payment sets the later gym-local activation date", () => {
  assertEquals(
    calculateMembershipTerm({
      registrationApprovedAt: instant("2026-04-04T16:01:00Z"),
      fullPaymentConfirmedAt: instant("2026-04-01T00:00:00Z"),
    }).activationDate,
    "2026-04-05",
  );
});

Deno.test("early renewal starts the day after current inclusive expiry", () => {
  assertEquals(
    calculateMembershipTerm({
      registrationApprovedAt: instant("2026-01-01T00:00:00Z"),
      fullPaymentConfirmedAt: instant("2026-01-20T00:00:00Z"),
      existingInclusiveExpiry: "2026-01-30",
    }),
    {
      activationDate: "2026-01-31",
      nextTermStart: "2026-02-28",
      inclusiveExpiry: "2026-02-27",
    },
  );
});

Deno.test("payment on inclusive expiry still extends consecutively", () => {
  assertEquals(
    calculateMembershipTerm({
      registrationApprovedAt: instant("2024-01-01T00:00:00Z"),
      fullPaymentConfirmedAt: instant("2024-02-28T15:59:59.999Z"),
      existingInclusiveExpiry: "2024-02-28",
    }).activationDate,
    "2024-02-29",
  );
});

Deno.test("lapsed renewal uses new confirmed payment date, leaving gap intact", () => {
  assertEquals(
    calculateMembershipTerm({
      registrationApprovedAt: instant("2026-01-01T00:00:00Z"),
      fullPaymentConfirmedAt: instant("2026-02-03T16:00:00Z"),
      existingInclusiveExpiry: "2026-01-30",
    }).activationDate,
    "2026-02-04",
  );
});

Deno.test("lapsed renewal approval after payment also prevents backdating", () => {
  assertEquals(
    calculateMembershipTerm({
      registrationApprovedAt: instant("2026-03-09T16:00:00Z"),
      fullPaymentConfirmedAt: instant("2026-03-02T00:00:00Z"),
      existingInclusiveExpiry: "2026-02-27",
    }).activationDate,
    "2026-03-10",
  );
});

Deno.test("consecutive clamped terms use actual expiry rather than original day", () => {
  const first = oneCalendarMonthTerm("2023-01-31");
  assertEquals(
    calculateMembershipTerm({
      registrationApprovedAt: instant("2023-01-31T00:00:00Z"),
      fullPaymentConfirmedAt: instant("2023-02-20T00:00:00Z"),
      existingInclusiveExpiry: first.inclusiveExpiry,
    }),
    {
      activationDate: "2023-02-28",
      nextTermStart: "2023-03-28",
      inclusiveExpiry: "2023-03-27",
    },
  );
});

Deno.test("rejects malformed and impossible calendar dates without normalization", () => {
  for (
    const value of [
      "",
      "2023-02-29",
      "2024-02-30",
      "2024-04-31",
      "2024-13-01",
      "2024-00-01",
      "0000-01-01",
      "2024-1-01",
      "2024-01-01T00:00:00Z",
    ]
  ) {
    assertThrows(() => oneCalendarMonthTerm(value), RangeError);
  }
  assertThrows(() =>
    calculateMembershipTerm({
      registrationApprovedAt: instant("2026-01-01T00:00:00Z"),
      fullPaymentConfirmedAt: instant("2026-01-01T00:00:00Z"),
      existingInclusiveExpiry: "2026-02-30",
    }), RangeError);
});

Deno.test("rejects invalid instants and calendar overflow", () => {
  assertThrows(() => gymLocalDate(new Date(NaN)), RangeError);
  assertThrows(() =>
    calculateMembershipTerm({
      registrationApprovedAt: new Date(NaN),
      fullPaymentConfirmedAt: instant("2026-01-01T00:00:00Z"),
    }), RangeError);
  assertThrows(() => oneCalendarMonthTerm("9999-12-31"), RangeError);
});
