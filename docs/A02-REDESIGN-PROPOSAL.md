# A02 implementation boundary requiring Owner decision

The master recovery task authorizes local code and isolated testing, but explicitly
requires stopping a remediation if an original security invariant cannot be
preserved. That condition applies to a customer-only migration redesign here.

The existing zero-membership final contract is unchanged. Documented hosted
custom-role creation leaves a provider-granted ADMIN edge that the customer
cannot remove; ownership transfers additionally require privileges barred by
the input assertions. There is no demonstrated supported execution path that
preserves all of these conditions. Do not solve this by deleting guards,
retaining ADMIN exceptions, adding broad grants or disabling FORCE RLS.

Implemented locally: a PG17-only launcher, actual authenticated non-superuser
P05/P11 refusal probes and rollback checks, plus the existing full sequence as
a separately labelled superuser engine control. See `supabase/recovery/README.md`
and `docs/PRODUCTION-RECOVERY-IMPLEMENTATION-RESULTS.md` for executed outcomes.
These are executable verification improvements, not a revised compatible A02
migration architecture. The 37 original migration files are untouched.

Owner decision needed before A02 source remediation:

1. Confirm a supported provider-operated mechanism and isolated rehearsal that
   preserves the current invariant; or
2. Authorize a separately reviewed architecture/trust-contract redesign under
   actual hosted capabilities. Define acceptable creator/operator relationships,
   scope, cleanup, row visibility, future maintenance and plan constraints first.

Option 2 is not approval to retain an ADMIN edge, create a privileged RPC runner,
provision another service, change platform or incur costs. If no safe design can
meet the required contract, continue HOLD. A02 remains BLOCKED, not fixed by
local-superuser success or a status report. Other safe recovery tooling proceeds
independently without claiming production readiness.
