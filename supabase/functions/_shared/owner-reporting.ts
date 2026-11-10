type Command = {
  rpcName: string;
  args: Record<string, string | number | null>;
  outputKey: string;
};
function date(value: unknown): string | null {
  if (value === undefined || value === null || value === "") return null;
  if (
    typeof value !== "string" || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/u.test(value) ||
    value.startsWith("0000")
  ) throw Error("INVALID_REPORT_REQUEST");
  const parsed = new Date(`${value}T00:00:00Z`);
  if (
    !Number.isFinite(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== value
  ) throw Error("INVALID_REPORT_REQUEST");
  return value;
}
export function parseReportCommand(value: unknown): Command {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw Error("INVALID_REPORT_REQUEST");
  }
  const input = value as Record<string, unknown>;
  if (input.action === "summary" && Object.keys(input).length === 1) {
    return {
      rpcName: "owner_dashboard_summary",
      args: {},
      outputKey: "summary",
    };
  }
  if (input.action === "income") {
    if (Object.keys(input).some((key) => !["action", "fromDate", "toDate"].includes(key))) throw Error("INVALID_REPORT_REQUEST");
    const from = date(input.fromDate); const through = date(input.toDate);
    if (from !== null && through !== null && (from > through || (Date.parse(through)-Date.parse(from))/86400000>365)) throw Error("INVALID_REPORT_REQUEST");
    return { rpcName: "owner_income_report", args: { p_from_date: from, p_to_date: through }, outputKey: "income" };
  }
  if (input.action === "expiry") {
    if (Object.keys(input).some((key) => !["action", "windowDays", "limit", "offset"].includes(key))) throw Error("INVALID_REPORT_REQUEST");
    const window = input.windowDays; const limit = input.limit ?? 50; const offset = input.offset ?? 0;
    if (typeof window !== "number" || !Number.isInteger(window) || window<0 || window>31
      || typeof limit !== "number" || !Number.isInteger(limit) || limit<1 || limit>100
      || typeof offset !== "number" || !Number.isInteger(offset) || offset<0 || offset>100000) throw Error("INVALID_REPORT_REQUEST");
    return { rpcName: "owner_expiry_reminders", args: { p_window_days: window, p_limit: limit, p_offset: offset }, outputKey: "expiries" };
  }
  if (
    input.action !== "audit" ||
    Object.keys(input).some((key) =>
      !["action", "search", "fromDate", "toDate", "limit", "offset"].includes(
        key,
      )
    )
  ) throw Error("INVALID_REPORT_REQUEST");
  const search = input.search ?? "";
  const limit = input.limit ?? 50;
  const offset = input.offset ?? 0;
  const from = date(input.fromDate), through = date(input.toDate);
  if (
    typeof search !== "string" || search.length > 80 ||
    typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 ||
    limit > 100 || typeof offset !== "number" || !Number.isInteger(offset) ||
    offset < 0 || offset > 100000 ||
    (from !== null && through !== null && from > through)
  ) throw Error("INVALID_REPORT_REQUEST");
  return {
    rpcName: "owner_list_audit_events",
    args: {
      p_search: search.trim() || null,
      p_from_date: from,
      p_to_date: through,
      p_limit: limit,
      p_offset: offset,
    },
    outputKey: "events",
  };
}
