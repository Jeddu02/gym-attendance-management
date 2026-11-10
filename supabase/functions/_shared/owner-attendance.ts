type AttendanceFilters = {
  p_search: string | null;
  p_from_date: string | null;
  p_to_date: string | null;
  p_status: string;
  p_limit: number;
  p_offset: number;
};

function calendarDate(value: unknown): string | null {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string" || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/u.test(value) || value.startsWith("0000")) {
    throw Error("INVALID_ATTENDANCE_FILTERS");
  }
  const date = new Date(`${value}T00:00:00Z`);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    throw Error("INVALID_ATTENDANCE_FILTERS");
  }
  return value;
}

/** Only list filters are accepted; the authenticated actor is supplied by Edge. */
export function parseAttendanceFilters(value: unknown): AttendanceFilters {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("INVALID_ATTENDANCE_FILTERS");
  const input = value as Record<string, unknown>;
  if (Object.keys(input).some((key) => !["search", "fromDate", "toDate", "status", "limit", "offset"].includes(key))) {
    throw Error("INVALID_ATTENDANCE_FILTERS");
  }
  const search = input.search === undefined ? "" : input.search;
  const status = input.status === undefined ? "all" : input.status;
  const limit = input.limit === undefined ? 50 : input.limit;
  const offset = input.offset === undefined ? 0 : input.offset;
  const fromDate = calendarDate(input.fromDate);
  const toDate = calendarDate(input.toDate);
  if (typeof search !== "string" || search.length > 80
    || typeof status !== "string" || !["all", "valid", "invalidated_payment", "invalidated_correction", "review"].includes(status)
    || typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100
    || typeof offset !== "number" || !Number.isInteger(offset) || offset < 0 || offset > 100000
    || (fromDate !== null && toDate !== null && fromDate > toDate)) {
    throw Error("INVALID_ATTENDANCE_FILTERS");
  }
  return {
    p_search: search.trim() || null,
    p_from_date: fromDate,
    p_to_date: toDate,
    p_status: status,
    p_limit: limit,
    p_offset: offset,
  };
}
