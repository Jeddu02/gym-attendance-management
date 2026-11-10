import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseAttendanceFilters } from "./owner-attendance.ts";

Deno.test("attendance defaults request history across all validity states", () => {
  assertEquals(parseAttendanceFilters({}), {
    p_search: null, p_from_date: null, p_to_date: null, p_status: "all", p_limit: 50, p_offset: 0,
  });
});

Deno.test("attendance normalizes blank dates and trims search without accepting actor input", () => {
  assertEquals(parseAttendanceFilters({ search: "  SAMPLE-001  ", fromDate: "", toDate: null, limit: 100, offset: 100000 }), {
    p_search: "SAMPLE-001", p_from_date: null, p_to_date: null, p_status: "all", p_limit: 100, p_offset: 100000,
  });
  for (const input of [{ actorUserId: "other-user" }, { p_actor_user_id: "other-user" }, { action: "delete" }, { rawDetails: true }]) {
    assertThrows(() => parseAttendanceFilters(input), Error, "INVALID_ATTENDANCE_FILTERS");
  }
});

Deno.test("attendance accepts each existing validity status and inclusive single date", () => {
  for (const status of ["all", "valid", "invalidated_payment", "invalidated_correction", "review"]) {
    assertEquals(parseAttendanceFilters({ status, fromDate: "2024-02-29", toDate: "2024-02-29" }).p_status, status);
  }
});

Deno.test("attendance rejects invalid calendar dates and reversed date range", () => {
  for (const value of ["2023-02-29", "2024-04-31", "2024-13-01", "0000-01-01", "2024-1-01", "2024-01-01T00:00:00Z", true]) {
    assertThrows(() => parseAttendanceFilters({ fromDate: value }), Error, "INVALID_ATTENDANCE_FILTERS");
    assertThrows(() => parseAttendanceFilters({ toDate: value }), Error, "INVALID_ATTENDANCE_FILTERS");
  }
  assertThrows(() => parseAttendanceFilters({ fromDate: "2026-11-11", toDate: "2026-11-10" }), Error, "INVALID_ATTENDANCE_FILTERS");
});

Deno.test("attendance rejects malformed shapes, unknown states and pagination coercion", () => {
  for (const input of [null, [], true, "all", { search: null }, { search: "x".repeat(81) }, { status: "invalid" }, { status: null }, { limit: 0 }, { limit: 101 }, { limit: "50" }, { limit: 1.5 }, { limit: null }, { offset: -1 }, { offset: 100001 }, { offset: "0" }, { offset: 0.5 }, { offset: Infinity }]) {
    assertThrows(() => parseAttendanceFilters(input), Error, "INVALID_ATTENDANCE_FILTERS");
  }
});
