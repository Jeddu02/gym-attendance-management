import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseReportCommand } from "./owner-reporting.ts";

Deno.test("income and reminder reports reject privileged fields and unbounded windows", () => {
  assertEquals(parseReportCommand({ action: "income", fromDate: "2024-02-29", toDate: "2024-02-29" }).outputKey, "income");
  assertEquals(parseReportCommand({ action: "expiry", windowDays: 0 }).args.p_window_days, 0);
  assertThrows(() => parseReportCommand({ action: "income", fromDate: "2024-01-01", toDate: "2025-01-01" }));
  assertThrows(() => parseReportCommand({ action: "expiry", windowDays: 32 }));
  assertThrows(() => parseReportCommand({ action: "expiry", windowDays: 7, actorUserId: "forged" }));
});
Deno.test("summary accepts no actor or additional privileged fields", () => {
  assertEquals(parseReportCommand({ action: "summary" }), {
    rpcName: "owner_dashboard_summary",
    args: {},
    outputKey: "summary",
  });
  assertThrows(() =>
    parseReportCommand({ action: "summary", actorUserId: "forged" })
  );
});
Deno.test("audit accepts bounded pagination and empty date controls", () => {
  assertEquals(
    parseReportCommand({ action: "audit", fromDate: "", toDate: "" }),
    {
      rpcName: "owner_list_audit_events",
      args: {
        p_search: null,
        p_from_date: null,
        p_to_date: null,
        p_limit: 50,
        p_offset: 0,
      },
      outputKey: "events",
    },
  );
});
Deno.test("audit rejects impossible dates and reversed date ranges", () => {
  for (
    const range of [{ fromDate: "2025-02-29" }, { toDate: "2026-04-31" }, {
      fromDate: "2026-11-11",
      toDate: "2026-11-10",
    }, { fromDate: "0000-01-01" }]
  ) {
    assertThrows(
      () => parseReportCommand({ action: "audit", ...range }),
      Error,
      "INVALID_REPORT_REQUEST",
    );
  }
  assertEquals(
    parseReportCommand({ action: "audit", fromDate: "2024-02-29" }).args
      .p_from_date,
    "2024-02-29",
  );
});
Deno.test("audit rejects client actor, raw SQL and unbounded export requests", () => {
  for (
    const extra of [
      { p_actor_user_id: "forged" },
      { sql: "SELECT *" },
      { limit: 101 },
      { limit: 0 },
      { offset: -1 },
      { offset: 100001 },
      { offset: 0.5 },
      { search: "x".repeat(81) },
    ]
  ) {
    assertThrows(
      () => parseReportCommand({ action: "audit", ...extra }),
      Error,
      "INVALID_REPORT_REQUEST",
    );
  }
});
