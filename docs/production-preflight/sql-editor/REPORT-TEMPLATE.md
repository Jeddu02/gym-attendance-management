# Sanitized Owner verification report

Project ref: alxhytivwybjbkjjdsyn

Execution approval reference: ___

Date/time window (Asia/Manila): ___

Project/primary-database selection verified: PASS / FAIL / UNKNOWN

Diagnostic role matched intended context (no raw identity): PASS / FAIL / UNKNOWN

Identity result read_only = on: PASS / FAIL / UNKNOWN

Whole files executed separately; final rollback/session cleanup confirmed:
PASS / FAIL / UNKNOWN

Unexpected concurrent deployment/schema change: YES / NO / UNKNOWN

| Result | Complete row count | Execution PASS/FAIL/UNKNOWN | Sanitized finding |
| --- | --- | --- | --- |
| 01-01 identity | | | |
| 01-02 migration history | | | |
| 01-03 schemas | | | |
| 01-04 routines | | | |
| 01-05 routine ACLs | | | |
| 01-06 effective routine permissions | | | |
| 01-07 schema permissions | | | |
| 01-08 default ACLs | | | |
| 01-09 table RLS | | | |
| 01-10 table permissions | | | |
| 01-11 policies | | | |
| 01-12 columns | | | |
| 01-13 triggers | | | |
| 01-14 constraints | | | |
| 01-15 indexes | | | |
| 02-01 markers | | | |

Successful execution does not imply a security or readiness PASS. Empty or
truncated inventories are UNKNOWN until reconciled with expected source objects.

Migration summary: recorded versions ___; supplied baseline matched YES/NO/UNKNOWN;
unrecorded local versions ___; unexpected versions ___ (counts only).

Marker summary (expected 91 rows, not 91 distinct objects):

- RECORDED: ___
- PRESENT_WITHOUT_HISTORY: ___
- ABSENT_WITHOUT_HISTORY: ___
- Total: ___
- Recorded but object_present=false: ___ (separate drift count)
- Unrecorded versions with all/some/no listed markers present: ___ / ___ / ___

Prerequisites missing: approved source object names or aggregate counts only ___

RLS/privilege exceptions: counts and affected source component only ___

Invalid/not-ready indexes and unvalidated constraints: counts only ___

Definition correctness, hosted exposed-schema configuration, executor-hardening,
ownership-change authority, audit-chain/lifecycle blockers: UNKNOWN unless
separately established. Scripts 03–07 remain on hold.

Error/stop point: filename ___; SQLSTATE or sanitized category ___;
cleanup confirmed ___; remaining files NOT RUN ___.

Recommendation: HOLD / request next narrowly scoped review ___.

Do not attach result grids, raw role/owner names, function bodies, policy
expressions, member/payment/audit rows, PINs, tokens, keys, connection strings or
full server logs. Presence without history never authorizes history repair or
proves that a migration is applied.
