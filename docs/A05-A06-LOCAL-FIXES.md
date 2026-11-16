# GYMFORCE A05/A06 local fixes — 2026-11-16

Branch: `review/production-recovery`. Scope: A05/A06 application fixes and local
regressions only. No SQL migration, hosted setting, production data, deployment,
merge, commit or push. The pre-existing changes to `production-recovery-plan.md`
were preserved without editing that file in this implementation batch. Its
baseline findings remain historical; this document records the local fixes.

## Before and after

| Case | Before | After |
| --- | --- | --- |
| Three Owner list RPCs return object/null/scalar with successful HTTP | Handler returned 200 and an empty list; frontend could show no records | Handler returns 503 with only `{"error":"SERVICE_UNAVAILABLE"}`; no result data/log details are forwarded. |
| Three Owner list RPCs return populated or empty arrays | Legitimate list | Same 200 envelope and array preserved; no new success field or row mapping. |
| Trusted-origin preflight while backend settings/flags unavailable | Some handlers returned configuration errors before OPTIONS | All 21 entrypoints answer 204 with the exact configured origin, POST/OPTIONS and required SDK request headers before entering the original handler. |
| Foreign, lookalike, null or missing Origin | Some denied responses still included CORS allow headers; one public POST path tolerated absent Origin | Shared guard rejects with 403 and no Access-Control-Allow-* headers, never invoking the handler. |
| Missing/malformed APP_ORIGIN (including wildcard/path/credentials) | Inconsistent failure envelopes/headers | Generic 503, no CORS allow headers, no handler execution. Configure an exact canonical http(s) origin; local HTTP remains supported, production HTTPS requirements unchanged. |
| Trusted POST without backend configuration, verified Auth or enabled feature | Protected operation unavailable | Existing configuration/Auth/release checks still apply. Valid OPTIONS never grants POST access or invokes Auth/RPC. |

`_shared/browser-cors.ts` is the outer boundary for all entrypoints. The original
handler-local checks are retained as defense in depth, preserving operation
validation, actor derivation, SQL/RLS boundaries, unavailable statuses and release
flags. Preflight never reaches those inner checks. It does not reflect arbitrary
origins, emit wildcard origin headers, allow credentials, alter RPC arguments or
set any release flag. Original unavailable POST statuses remain handler-specific
(500/503); they are not treated as successful operations.

No frontend source change was necessary. Existing Members/Plans/Purchases load
paths throw on function errors; their unavailable state is distinct from a valid
empty list. Node tests exercise actual handler/SDK responses; the existing browser
suite separately exercises the matching 503 unavailable UI and recovery to empty
success for all three lists. Browser APIs/Auth are synthetic fixtures, not an
actual hosted full-stack test.

## Changed files in this batch

Shared implementation and regression files:

- `supabase/functions/_shared/browser-cors.ts` — new common guard.
- `supabase/functions/_shared/browser-cors_test.ts` — new configuration/delegation tests.
- `supabase/functions/_shared/preflight_test.ts` — expanded from eight to all 21
  actual entrypoints, with a filesystem inventory assertion to prevent omissions.
- `tests/edge-handlers.test.mjs` — array-contract/authorization regressions for
  the three Owner list handlers using intercepted synthetic HTTP.
- `docs/A05-A06-LOCAL-FIXES.md` — this implementation/verification record.

All 21 entrypoints below import and apply the outer guard; the three marked A05
also reject non-array RPC success values:

```text
supabase/functions/member-checkin/index.ts
supabase/functions/member-enroll-pin/index.ts
supabase/functions/member-reset-pin/index.ts
supabase/functions/owner-attendance/index.ts
supabase/functions/owner-attendance-claims/index.ts
supabase/functions/owner-cash/index.ts
supabase/functions/owner-create-membership-purchase/index.ts
supabase/functions/owner-create-pin-enrollment-token/index.ts
supabase/functions/owner-create-pin-recovery-token/index.ts
supabase/functions/owner-list-members/index.ts                    [A05]
supabase/functions/owner-list-membership-plans/index.ts           [A05]
supabase/functions/owner-list-membership-purchases/index.ts       [A05]
supabase/functions/owner-membership-lifecycle/index.ts
supabase/functions/owner-membership-payments/index.ts
supabase/functions/owner-receipt-review/index.ts
supabase/functions/owner-register-member/index.ts
supabase/functions/owner-reporting/index.ts
supabase/functions/owner-save-membership-plan/index.ts
supabase/functions/owner-status/index.ts
supabase/functions/owner-walkins/index.ts
supabase/functions/public-walkin-request/index.ts
```

No package/dependency/configuration/SQL/frontend file was changed. Original UTF-8
BOMs in five entrypoints remain at byte zero after adding the import.

## Regression coverage and results

A05 tests cover each handler with a populated array, empty array, unexpected
object, wrapped-array object, null, string, number, true and false. Every malformed
case must return the identical generic error/no-store response. Missing and invalid
Auth cannot reach RPC; a SQL 42501 response still becomes a safe 403. Results and
actors are synthetic; global fetch is intercepted and unexpected origins fail.

A06 tests import every actual handler under three configuration profiles: exact
origin without backend settings (even with flags true), backend settings present
but release flags absent, and missing APP_ORIGIN. They check required CORS
headers/methods, cache isolation, no credential allow header, four untrusted or
missing Origin cases on OPTIONS and POST, blocked unauthenticated Owner POST,
and disabled public/PIN/claim operations. No rejected/disabled/preflight case
may make a network call. Separate unit tests reject malformed origin configuration
and prove accepted POST delegates to the exact original authorization response.

| Command / check | Result |
| --- | --- |
| `npm.cmd run lint` | PASS after correcting BOM placement following new imports. |
| `npm.cmd run typecheck` | PASS. |
| `npm.cmd test` | PASS 38/38, including final array/SQL Owner-denial regressions. |
| `npm.cmd run test:security` | PASS static source boundary checks. |
| Cached Deno shared tests | PASS 105/105 after correcting a test-only TypeScript narrowing error. |
| Cached Deno check on all 21 entrypoints | PASS. |
| `npm.cmd run build` | PASS, including PWA generation. |
| `node scripts/test-browser.mjs --production` | PASS: mobile Owner/public navigation, failed-list errors versus empty success/recovery, payment/walk-in handling, QR/PIN and static-only caches. Synthetic fixtures only; no external application requests. |
| `git diff --check` | PASS; final documentation check repeated at handoff. |
| Production SQL / Auth / RLS / Edge / Pages end-to-end | NOT RUN. |

Deno commands used the existing installed executable outside sandbox restrictions,
cached dependencies and `--node-modules-dir=manual`. Tests used
`--allow-read=supabase/functions` and only the two existing mobile-key environment
permissions required by encryption unit tests. No dependencies installed.
Browser evidence: `.cache/browser-test-3823b8cf-476b-43a3-b70a-eb556327873a`.

## Remaining gates

A05/A06 are local fixes, not production remediation. No missing endpoints or
database objects are installed. All other findings, the 17 unrecorded migrations,
ownership/default-ACL/legacy-data/recovery uncertainties, hosted full-stack
acceptance and explicit Owner deployment approvals remain open. The production
NO-GO in the recovery plan remains in effect.

Array validation here enforces the specified array container contract; it does
not introduce new row schemas or business rules. Origin is a browser boundary,
not authorization or abuse protection. Unknown origins/configuration fail closed;
Owner Auth and server SQL checks remain mandatory. Production setting correctness
and real-device acceptance remain unverified. No database suite was rerun because
SQL/schema behavior was not changed in this scoped batch.

Stop after local verification for Owner review; no publication/deployment follows.
