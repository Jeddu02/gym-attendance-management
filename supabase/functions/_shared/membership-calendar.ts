/**
 * Pure Option A calendar arithmetic. This module enables no purchase workflow.
 * Callers must supply authoritative server approval/payment instants and the
 * validated entitlement expiry, never browser timestamps or asserted payment.
 * Owner authorization, full payment, duplicate/overlapping purchases and limits
 * on advance renewal must be checked separately in an atomic server operation.
 */
export type MembershipTerm = {
  activationDate: string;
  nextTermStart: string;
  inclusiveExpiry: string;
};

const gymDateFormatter = new Intl.DateTimeFormat("en-US", {
  timeZone: "Asia/Manila",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

function dateOnly(date: Date): string {
  const year = date.getUTCFullYear();
  if (year < 1 || year > 9999 || !Number.isFinite(date.getTime())) {
    throw new RangeError("Calendar date is outside the supported range");
  }
  return date.toISOString().slice(0, 10);
}

function parseDate(value: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/u.test(value)) {
    throw new RangeError("Expected a valid YYYY-MM-DD calendar date");
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  if (dateOnly(date) !== value) {
    throw new RangeError("Expected a valid YYYY-MM-DD calendar date");
  }
  return date;
}

function shiftDay(value: string, days: number): string {
  const date = parseDate(value);
  date.setUTCDate(date.getUTCDate() + days);
  return dateOnly(date);
}

/** Extract a gym business date from an already verified server instant. */
export function gymLocalDate(instant: Date): string {
  if (!(instant instanceof Date) || !Number.isFinite(instant.getTime())) {
    throw new RangeError("Expected a valid server instant");
  }
  const parts = gymDateFormatter.formatToParts(instant);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((entry) => entry.type === type)!.value;
  const value = `${part("year").padStart(4, "0")}-${part("month")}-${
    part("day")
  }`;
  // Reject eras and out-of-range years instead of normalizing invalid dates.
  parseDate(value);
  if (instant.getUTCFullYear() < 1) {
    throw new RangeError("Calendar date is outside the supported range");
  }
  return value;
}

/** Advance one calendar month, clamp its day, then subtract one day for expiry. */
export function oneCalendarMonthTerm(activationDate: string): MembershipTerm {
  const activation = parseDate(activationDate);
  const next = new Date(activation.getTime());
  next.setUTCDate(1);
  next.setUTCMonth(next.getUTCMonth() + 1);
  const finalDay = new Date(next.getTime());
  finalDay.setUTCMonth(finalDay.getUTCMonth() + 1);
  finalDay.setUTCDate(0);
  next.setUTCDate(Math.min(activation.getUTCDate(), finalDay.getUTCDate()));
  const nextTermStart = dateOnly(next);
  return {
    activationDate,
    nextTermStart,
    inclusiveExpiry: shiftDay(nextTermStart, -1),
  };
}

/**
 * Select the later approval/full-payment business date. A still-current term
 * extends consecutively; a lapsed term starts on the new eligible date.
 * This calculates dates only and does not authorize an advance purchase.
 */
export function calculateMembershipTerm(input: {
  registrationApprovedAt: Date;
  fullPaymentConfirmedAt: Date;
  existingInclusiveExpiry?: string;
}): MembershipTerm {
  const approvedDate = gymLocalDate(input.registrationApprovedAt);
  const paidDate = gymLocalDate(input.fullPaymentConfirmedAt);
  const eligibleDate = approvedDate > paidDate ? approvedDate : paidDate;
  const expiry = input.existingInclusiveExpiry;
  if (expiry !== undefined) parseDate(expiry);
  return oneCalendarMonthTerm(
    expiry !== undefined && expiry >= eligibleDate
      ? shiftDay(expiry, 1)
      : eligibleDate,
  );
}
