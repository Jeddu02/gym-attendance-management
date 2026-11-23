# GYMFORCE source and checkpoint inventory

Prepared 2026-11-23, Asia/Manila. All tracked and nonignored untracked source files are listed below. Candidate means proposed only: nothing is staged. Sizes are working-copy bytes at inventory generation; this inventory excludes its own size.

Ignored local state is accounted for by category in the handover, never copied or enumerated as private evidence. No secret values or data rows are included. Regenerate the candidate list with `git diff --name-only` plus `git ls-files --others --exclude-standard` before approval.

| Path | Git disposition | Bytes | Purpose |
| --- | --- | ---: | --- |
| `.devcontainer/devcontainer.json` | Candidate | 591 | Repository configuration |
| `.env.example` | Candidate | 525 | Repository configuration |
| `.gitattributes` | Tracked unchanged | 233 | Repository configuration |
| `.gitignore` | Candidate | 1556 | Repository configuration |
| `AGENTS.md` | Tracked unchanged | 11380 | Repository configuration |
| `README.md` | Candidate | 2846 | Repository configuration |
| `deno.json` | Tracked unchanged | 25 | Repository configuration |
| `deno.lock` | Tracked unchanged | 134369 | Repository configuration |
| `docs/A02-EXECUTOR-HARDENING-REVIEW.md` | Tracked unchanged | 38085 | Documentation/evidence design |
| `docs/A02-PROVIDER-COMPATIBILITY.md` | Tracked unchanged | 24589 | Documentation/evidence design |
| `docs/A02-REDESIGN-PROPOSAL.md` | Tracked unchanged | 2036 | Documentation/evidence design |
| `docs/A02-REMEDIATION-DESIGN.md` | Tracked unchanged | 28514 | Documentation/evidence design |
| `docs/A05-A06-LOCAL-FIXES.md` | Tracked unchanged | 8425 | Documentation/evidence design |
| `docs/GYMFORCE-BATCH-5-AUTH-READINESS.md` | Candidate | 23696 | Documentation/evidence design |
| `docs/GYMFORCE-BATCH-6A-GOTRUE-ACQUISITION-MANIFEST.md` | Candidate | 12745 | Documentation/evidence design |
| `docs/GYMFORCE-CODESPACES-HANDOVER.md` | Candidate | 27342 | Documentation/evidence design |
| `docs/GYMFORCE-CONSOLIDATED-RECOVERY-READINESS.md` | Tracked unchanged | 2679 | Documentation/evidence design |
| `docs/GYMFORCE-CURRENT-PHASE-ASSESSMENT.md` | Tracked unchanged | 30648 | Documentation/evidence design |
| `docs/GYMFORCE-DEVELOPMENT-PROGRESS.md` | Candidate | 41119 | Documentation/evidence design |
| `docs/GYMFORCE-MIGRATION-FILE-INVENTORY.md` | Candidate | self | Documentation/evidence design |
| `docs/GYMFORCE-OWNER-DECISION-MATRIX.md` | Tracked unchanged | 1731 | Documentation/evidence design |
| `docs/GYMFORCE-PHASE-5-9-COMPLETE-SYSTEM-AUDIT.md` | Tracked unchanged | 30187 | Documentation/evidence design |
| `docs/GYMFORCE-PHASE-6-0-PUBLIC-REQUEST-RECOVERY-CONTRACT.md` | Tracked unchanged | 35410 | Documentation/evidence design |
| `docs/GYMFORCE-PHASE-6-0A-OWNER-DECISION-PACKAGE.md` | Tracked unchanged | 30498 | Documentation/evidence design |
| `docs/GYMFORCE-PHASE-6-1-RECOVERY-IMPLEMENTATION.md` | Tracked unchanged | 24258 | Documentation/evidence design |
| `docs/GYMFORCE-PHASE-6-1A-INGRESS-OWNER-DECISION.md` | Tracked unchanged | 43430 | Documentation/evidence design |
| `docs/GYMFORCE-PHASE-6-1B-INGRESS-IMPLEMENTATION.md` | Candidate | 64644 | Documentation/evidence design |
| `docs/GYMFORCE-PRODUCTION-RECOVERY-GATES.md` | Tracked unchanged | 1570 | Documentation/evidence design |
| `docs/GYMFORCE-PROJECT-STATUS-AUDIT.md` | Tracked unchanged | 49877 | Documentation/evidence design |
| `docs/HOSTED-DIAGNOSTIC-AUTHORIZATION-FORM.md` | Tracked unchanged | 23999 | Documentation/evidence design |
| `docs/HOSTED-READINESS-DECISION-MATRIX.md` | Tracked unchanged | 9238 | Documentation/evidence design |
| `docs/HOSTED-READINESS-DIAGNOSTIC-PLAN.md` | Tracked unchanged | 28684 | Documentation/evidence design |
| `docs/HOSTED-READINESS-OWNER-APPROVAL.md` | Tracked unchanged | 13463 | Documentation/evidence design |
| `docs/M2-OWNER-SECURITY-REVIEW.md` | Tracked unchanged | 4111 | Documentation/evidence design |
| `docs/PG17-COMPATIBILITY-FINAL-REVIEW.md` | Tracked unchanged | 41478 | Documentation/evidence design |
| `docs/PG17-STARTUP-RECOVERY-VERIFICATION.md` | Tracked unchanged | 9708 | Documentation/evidence design |
| `docs/PHASE-5-2-HOSTED-READINESS-RESULTS.md` | Tracked unchanged | 6851 | Documentation/evidence design |
| `docs/PHASE-5-2-MANUAL-DIAGNOSTIC-GUIDE.md` | Tracked unchanged | 23415 | Documentation/evidence design |
| `docs/PHASE-5-2-WINDOWS-PSQL-QUALIFICATION.md` | Tracked unchanged | 18679 | Documentation/evidence design |
| `docs/PHASE-5-3-COMPATIBILITY-RESOLUTION.md` | Tracked unchanged | 6683 | Documentation/evidence design |
| `docs/PHASE-5-4-INTEGRATION-TEST-REPORT.md` | Tracked unchanged | 14846 | Documentation/evidence design |
| `docs/PHASE-5-CONSOLIDATED-COMPATIBILITY-RECOVERY-REVIEW.md` | Tracked unchanged | 32348 | Documentation/evidence design |
| `docs/PHASE-5-FINAL-READINESS-ASSESSMENT.md` | Tracked unchanged | 6579 | Documentation/evidence design |
| `docs/PHASE-5-M1-M2-DIAGNOSTIC-PREPARATION.md` | Tracked unchanged | 46600 | Documentation/evidence design |
| `docs/PHASE-5-TARGETED-REMEDIATION-PLAN.md` | Tracked unchanged | 32481 | Documentation/evidence design |
| `docs/PRODUCTION-RECOVERY-FINAL-READINESS.md` | Tracked unchanged | 27099 | Documentation/evidence design |
| `docs/PRODUCTION-RECOVERY-IMPLEMENTATION-RESULTS.md` | Tracked unchanged | 18130 | Documentation/evidence design |
| `docs/RELEASE-READINESS.md` | Tracked unchanged | 7695 | Documentation/evidence design |
| `docs/SOURCE-INTEGRITY-PORTABILITY.md` | Tracked unchanged | 6828 | Documentation/evidence design |
| `docs/SPRINT-2026-11-19-LOCAL-RC.md` | Tracked unchanged | 9708 | Documentation/evidence design |
| `docs/SPRINT-PHASE-5-6-STABILIZATION.md` | Tracked unchanged | 13421 | Documentation/evidence design |
| `docs/SPRINT-PHASE-5-7-OWNER-ANDROID-REVIEW.md` | Tracked unchanged | 20481 | Documentation/evidence design |
| `docs/SPRINT-PHASE-5-8-FINAL-ACCEPTANCE.md` | Tracked unchanged | 18329 | Documentation/evidence design |
| `docs/STABILIZATION-2026-11-11.md` | Tracked unchanged | 23234 | Documentation/evidence design |
| `docs/STABILIZATION-2026-11-16.md` | Tracked unchanged | 12885 | Documentation/evidence design |
| `docs/attendance-implementation-readiness.md` | Tracked unchanged | 26807 | Documentation/evidence design |
| `docs/database-security-design.md` | Tracked unchanged | 57651 | Documentation/evidence design |
| `docs/database-security-foundation.md` | Tracked unchanged | 11658 | Documentation/evidence design |
| `docs/development-checkpoint-2026-11-06.md` | Tracked unchanged | 18670 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/20261106120000_owner_executor_foundation.sql.draft` | Tracked unchanged | 578536 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/README.md` | Tracked unchanged | 26301 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/accelerated-review/README.md` | Tracked unchanged | 12215 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/accelerated-review/change-inventory.json` | Tracked unchanged | 2142 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/accelerated-review/draft-statement-revisions.json` | Tracked unchanged | 2615 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/accelerated-review/parser-results.json` | Tracked unchanged | 7215 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/accelerated-review/reviewed-pin-revisions.json` | Tracked unchanged | 333 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/aligned-contract.mjs` | Tracked unchanged | 3985 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/aligned-schema-contract.json` | Tracked unchanged | 145981 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/approved-text-casts.mjs` | Tracked unchanged | 782 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/approved-text-casts.test.mjs` | Tracked unchanged | 1200 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/12-observed.csv` | Tracked unchanged | 1454 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/12-routine-identities.sql` | Tracked unchanged | 8523 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-c-observed.csv` | Tracked unchanged | 3355 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-constraints-c.sql` | Tracked unchanged | 8174 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-constraints-f.sql` | Tracked unchanged | 6438 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-constraints-p.sql` | Tracked unchanged | 3370 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-constraints-u.sql` | Tracked unchanged | 2143 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-constraints-x.sql` | Tracked unchanged | 1832 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-f-observed.csv` | Tracked unchanged | 2340 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-p-observed.csv` | Tracked unchanged | 1427 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-u-observed.csv` | Tracked unchanged | 490 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/13-x-observed.csv` | Tracked unchanged | 182 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/14-index-definitions.sql` | Tracked unchanged | 7913 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/14-observed.csv` | Tracked unchanged | 1480 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/15-column-expressions.sql` | Tracked unchanged | 10756 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/15-observed.csv` | Tracked unchanged | 6984 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/16-observed.csv` | Tracked unchanged | 931 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/16-trigger-definitions.sql` | Tracked unchanged | 4619 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/17-observed.csv` | Tracked unchanged | 1035 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/17-routine-defaults.sql` | Tracked unchanged | 3875 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/18-approved-text-casts.sql` | Tracked unchanged | 3450 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/18-observed.csv` | Tracked unchanged | 751 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/19-approved-body-equality.sql` | Tracked unchanged | 4272 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/19-observed.csv` | Tracked unchanged | 1036 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/boolean-alignment/findings.json` | Tracked unchanged | 17445 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/check-executor-fixtures.mjs` | Tracked unchanged | 1736 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/check-offline.mjs` | Tracked unchanged | 4163 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/check-parser-fixture.mjs` | Tracked unchanged | 666 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/compare-minimal-catalog.mjs` | Tracked unchanged | 10954 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/LOCAL-TEST-ONLY.catalogue-pilot.sql` | Tracked unchanged | 581611 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/README.md` | Tracked unchanged | 14641 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/approval.example.json` | Tracked unchanged | 519 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/candidate-manifest.json` | Tracked unchanged | 19943 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/check-pilot.mjs` | Tracked unchanged | 9043 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/pilot-spec.json` | Tracked unchanged | 1232 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/prepare-pilot.mjs` | Tracked unchanged | 5211 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/prepare-scenario-checklist.mjs` | Tracked unchanged | 1853 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/review-pilot.ps1` | Tracked unchanged | 988 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/scenario-checklist.json` | Tracked unchanged | 23588 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/controlled-pilot/test-pilot-negative.mjs` | Tracked unchanged | 4355 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/default-function-privileges.sql.draft` | Tracked unchanged | 3780 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/default-privilege-classification.mjs` | Tracked unchanged | 930 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/default-privilege-classification.test.mjs` | Tracked unchanged | 1806 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/default-privilege-proposal.md` | Tracked unchanged | 13752 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/deparser-candidates.mjs` | Tracked unchanged | 4036 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/dependent-objects.json` | Tracked unchanged | 11175 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/executor-acceptance-fixtures.json` | Tracked unchanged | 9977 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/executor-acceptance-plan.md` | Tracked unchanged | 13663 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/foundation_assertions.sql.draft` | Tracked unchanged | 181120 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/inspect-catalog.sql` | Tracked unchanged | 1664 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/01-identity-counts.sql` | Tracked unchanged | 1664 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/01-observed.csv` | Tracked unchanged | 139 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/02-observed.csv` | Tracked unchanged | 1184 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/02-tables.sql` | Tracked unchanged | 1094 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/03-constraints-indexes.sql` | Tracked unchanged | 1599 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/03-observed.csv` | Tracked unchanged | 13808 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/04-columns.sql` | Tracked unchanged | 1282 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/04-observed.csv` | Tracked unchanged | 8931 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/05-observed.csv` | Tracked unchanged | 2318 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/05-routines.sql` | Tracked unchanged | 1583 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/06-observed.csv` | Tracked unchanged | 8858 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/06-table-privileges.sql` | Tracked unchanged | 1586 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/07-observed.csv` | Tracked unchanged | 947 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/07-triggers-rules.sql` | Tracked unchanged | 1326 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/08-default-privileges.sql` | Tracked unchanged | 1554 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/08-observed.csv` | Tracked unchanged | 551 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/09-observed.csv` | Tracked unchanged | 1373 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/09-role-schema-privileges.sql` | Tracked unchanged | 1480 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/10-default-origins.sql` | Tracked unchanged | 2578 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/10-observed.csv` | Tracked unchanged | 472 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/11-browser-boundary.sql` | Tracked unchanged | 1709 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/11-observed.csv` | Tracked unchanged | 120 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/README.md` | Tracked unchanged | 8105 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/minimal-catalog/findings.json` | Tracked unchanged | 5478 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/object-manifest.json` | Tracked unchanged | 84850 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/offline-negative-fixtures.json` | Tracked unchanged | 4084 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/offline-parser.mjs` | Tracked unchanged | 2790 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/parse-drafts-offline.mjs` | Tracked unchanged | 1502 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/parser-fixtures.json` | Tracked unchanged | 2088 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/parser-fixtures.test.mjs` | Tracked unchanged | 1122 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/pre-execution-security-review.md` | Tracked unchanged | 12258 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/prepare-boolean-alignment.mjs` | Tracked unchanged | 8101 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/prepare-index-metadata.mjs` | Tracked unchanged | 3226 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/prepare-minimal-inspection.mjs` | Tracked unchanged | 7298 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/prepare-semantic-alignment.mjs` | Tracked unchanged | 5021 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/render-hardening.mjs` | Tracked unchanged | 18241 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/review-boolean-alignment.mjs` | Tracked unchanged | 6171 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/review-semantic-alignment.mjs` | Tracked unchanged | 3570 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/schema-contract.json` | Tracked unchanged | 109365 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment.test.mjs` | Tracked unchanged | 3822 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/20-checks.sql` | Tracked unchanged | 9404 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/20-observed.csv` | Tracked unchanged | 3346 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/21-indexes.sql` | Tracked unchanged | 7988 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/21-observed.csv` | Tracked unchanged | 2262 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/22-exclusion.sql` | Tracked unchanged | 1911 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/22-observed.csv` | Tracked unchanged | 173 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/23-exclusion-metadata.sql` | Tracked unchanged | 2602 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/23-observed.csv` | Tracked unchanged | 245 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/24-index-metadata.sql` | Tracked unchanged | 7503 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/24-observed.csv` | Tracked unchanged | 2467 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/README.md` | Tracked unchanged | 11645 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/classification.json` | Tracked unchanged | 48040 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/evidence-pins.json` | Tracked unchanged | 2555 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/findings.json` | Tracked unchanged | 271 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/index-key-expectations.json` | Tracked unchanged | 3875 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/parser-provenance.json` | Tracked unchanged | 1797 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/parser-results.json` | Tracked unchanged | 2364 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/semantic-alignment/source-candidates.json` | Tracked unchanged | 30464 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/source-contract.mjs` | Tracked unchanged | 11109 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/statement-manifest.json` | Tracked unchanged | 42922 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/static-review.ps1` | Tracked unchanged | 7761 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/technical-review-2026-11-06.md` | Tracked unchanged | 39202 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/test-aligned-negative.mjs` | Tracked unchanged | 2957 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/test-offline-negative.mjs` | Tracked unchanged | 3161 | Documentation/evidence design |
| `docs/drafts/foundation-2026-11-06/validate-offline.ps1` | Tracked unchanged | 2037 | Documentation/evidence design |
| `docs/foundation-lifecycle-review-2026-11-06.md` | Tracked unchanged | 16636 | Documentation/evidence design |
| `docs/local-testing/README.md` | Tracked unchanged | 23141 | Documentation/evidence design |
| `docs/local-testing/apply-migrations.ps1` | Tracked unchanged | 7768 | Documentation/evidence design |
| `docs/local-testing/bootstrap.sql` | Tracked unchanged | 12662 | Documentation/evidence design |
| `docs/local-testing/cleanup.sql` | Tracked unchanged | 3480 | Documentation/evidence design |
| `docs/local-testing/owner_boundary_assertions.sql` | Tracked unchanged | 8109 | Documentation/evidence design |
| `docs/local-testing/preflight.ps1` | Tracked unchanged | 8890 | Documentation/evidence design |
| `docs/local-testing/rls_behavior_assertions.sql` | Tracked unchanged | 12821 | Documentation/evidence design |
| `docs/local-testing/test-safety-guards.ps1` | Tracked unchanged | 10304 | Documentation/evidence design |
| `docs/member-checkin-security-contract.md` | Tracked unchanged | 22839 | Documentation/evidence design |
| `docs/migration-review.txt` | Tracked unchanged | 32904 | Documentation/evidence design |
| `docs/migration_review.txt` | Tracked unchanged | 34703 | Documentation/evidence design |
| `docs/phase-3d-decisions.md` | Tracked unchanged | 12310 | Documentation/evidence design |
| `docs/phase-3d-final-review.md` | Tracked unchanged | 37704 | Documentation/evidence design |
| `docs/production-preflight/01-catalog.sql` | Tracked unchanged | 8516 | Documentation/evidence design |
| `docs/production-preflight/02-unrecorded-object-markers.sql` | Tracked unchanged | 8549 | Documentation/evidence design |
| `docs/production-preflight/03-hardening-screen.sql` | Tracked unchanged | 16265 | Documentation/evidence design |
| `docs/production-preflight/04-migration-authority.sql` | Tracked unchanged | 2686 | Documentation/evidence design |
| `docs/production-preflight/05-audit-blockers.sql` | Tracked unchanged | 2735 | Documentation/evidence design |
| `docs/production-preflight/06-registration-and-plan-blockers.sql` | Tracked unchanged | 1982 | Documentation/evidence design |
| `docs/production-preflight/07-lifecycle-payment-blockers.sql` | Tracked unchanged | 3340 | Documentation/evidence design |
| `docs/production-preflight/AUTHORIZED-01-02-STATUS.md` | Tracked unchanged | 3818 | Documentation/evidence design |
| `docs/production-preflight/MANUAL-SQL-EDITOR-GUIDE.md` | Tracked unchanged | 14361 | Documentation/evidence design |
| `docs/production-preflight/README.md` | Tracked unchanged | 19140 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-01-identity.sql` | Tracked unchanged | 704 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-02-migration-history.sql` | Tracked unchanged | 490 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-03-schemas.sql` | Tracked unchanged | 585 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-04-routines.sql` | Tracked unchanged | 1252 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-05-routine-acls.sql` | Tracked unchanged | 1246 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-06-routine-permissions.sql` | Tracked unchanged | 1022 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-07-schema-permissions.sql` | Tracked unchanged | 892 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-08-default-acls.sql` | Tracked unchanged | 1615 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-09-table-rls.sql` | Tracked unchanged | 900 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-10-table-permissions.sql` | Tracked unchanged | 1035 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-11-policies.sql` | Tracked unchanged | 1351 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-12-columns.sql` | Tracked unchanged | 908 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-13-triggers.sql` | Tracked unchanged | 810 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-14-constraints.sql` | Tracked unchanged | 728 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/01-15-indexes.sql` | Tracked unchanged | 795 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql` | Tracked unchanged | 8492 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/OUTPUT-CONTRACTS.md` | Tracked unchanged | 10022 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/README.md` | Tracked unchanged | 9633 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/REPORT-TEMPLATE.md` | Tracked unchanged | 2587 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/VALIDATION.md` | Tracked unchanged | 2363 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/manifest.json` | Tracked unchanged | 7338 | Documentation/evidence design |
| `docs/production-preflight/sql-editor/validate.cjs` | Tracked unchanged | 5350 | Documentation/evidence design |
| `docs/production-recovery-plan.md` | Tracked unchanged | 119126 | Documentation/evidence design |
| `docs/schema-proposal.md` | Tracked unchanged | 77708 | Documentation/evidence design |
| `docs/security-audit/npm-audit-latest.json` | Tracked unchanged | 2735 | Documentation/evidence design |
| `docs/security-test-plan.md` | Tracked unchanged | 31504 | Documentation/evidence design |
| `eslint.config.js` | Tracked unchanged | 868 | Repository configuration |
| `index.html` | Tracked unchanged | 460 | Repository configuration |
| `package-lock.json` | Tracked unchanged | 315675 | Repository configuration |
| `package.json` | Candidate | 1988 | Repository configuration |
| `public/_headers` | Tracked unchanged | 319 | Static asset/security headers |
| `public/pwa.svg` | Tracked unchanged | 256 | Static asset/security headers |
| `scripts/check-codespaces.mjs` | Candidate | 2150 | Development/diagnostic tooling |
| `scripts/check-source-security.mjs` | Tracked unchanged | 7774 | Development/diagnostic tooling |
| `scripts/diagnose-hosting.mjs` | Tracked unchanged | 3415 | Development/diagnostic tooling |
| `scripts/recovery/build-compatibility.mjs` | Tracked unchanged | 16036 | Development/diagnostic tooling |
| `scripts/recovery/compare-catalog.mjs` | Tracked unchanged | 3781 | Development/diagnostic tooling |
| `scripts/recovery/compare-history.mjs` | Tracked unchanged | 2398 | Development/diagnostic tooling |
| `scripts/recovery/durable-ingress-ops.mjs` | Candidate | 6800 | Development/diagnostic tooling |
| `scripts/recovery/ingress-monitor.mjs` | Candidate | 2602 | Development/diagnostic tooling |
| `scripts/recovery/parser.cjs` | Tracked unchanged | 1052 | Development/diagnostic tooling |
| `scripts/recovery/plan-checks.mjs` | Tracked unchanged | 2173 | Development/diagnostic tooling |
| `scripts/recovery/qualify-http-faults.mjs` | Candidate | 13675 | Development/diagnostic tooling |
| `scripts/recovery/serve-local-edge.ts` | Candidate | 676 | Development/diagnostic tooling |
| `scripts/recovery/source-byte-policy.json` | Tracked unchanged | 1707 | Development/diagnostic tooling |
| `scripts/recovery/source-bytes.mjs` | Tracked unchanged | 3682 | Development/diagnostic tooling |
| `scripts/recovery/validate-hosted-package.mjs` | Tracked unchanged | 7221 | Development/diagnostic tooling |
| `scripts/recovery/validate-source.mjs` | Candidate | 5813 | Development/diagnostic tooling |
| `scripts/setup-native-pg17.ps1` | Tracked unchanged | 4033 | Development/diagnostic tooling |
| `scripts/test-browser.mjs` | Candidate | 41862 | Development/diagnostic tooling |
| `scripts/test-database.ps1` | Candidate | 49905 | Development/diagnostic tooling |
| `scripts/test-db-concurrency.mjs` | Tracked unchanged | 29473 | Development/diagnostic tooling |
| `scripts/test-native-pg17-provenance.ps1` | Tracked unchanged | 1208 | Development/diagnostic tooling |
| `scripts/test-persisted-http.mjs` | Candidate | 39531 | Development/diagnostic tooling |
| `scripts/test-pin-enrollment-rate-limit.ps1` | Tracked unchanged | 7192 | Development/diagnostic tooling |
| `scripts/test-recovery-cleanup.ps1` | Tracked unchanged | 1778 | Development/diagnostic tooling |
| `scripts/test-recovery-pg17.ps1` | Candidate | 1382 | Development/diagnostic tooling |
| `scripts/test-recovery-reproducibility.mjs` | Tracked unchanged | 2904 | Development/diagnostic tooling |
| `scripts/verify-native-pg17-archive.ps1` | Tracked unchanged | 1311 | Development/diagnostic tooling |
| `src/App.tsx` | Tracked unchanged | 15990 | Application source |
| `src/components/AttendancePage.tsx` | Tracked unchanged | 7420 | Application source |
| `src/components/AuditLogPage.tsx` | Tracked unchanged | 6241 | Application source |
| `src/components/CashDrawerPage.tsx` | Tracked unchanged | 7263 | Application source |
| `src/components/ClaimReviewPage.tsx` | Tracked unchanged | 7175 | Application source |
| `src/components/EntrancePage.tsx` | Tracked unchanged | 13213 | Application source |
| `src/components/MembersPage.tsx` | Tracked unchanged | 23204 | Application source |
| `src/components/MembershipPlansPage.tsx` | Tracked unchanged | 12213 | Application source |
| `src/components/MembershipPurchasesPage.tsx` | Tracked unchanged | 19660 | Application source |
| `src/components/OverviewPage.tsx` | Tracked unchanged | 5031 | Application source |
| `src/components/OwnerUpdateNotice.tsx` | Tracked unchanged | 2083 | Application source |
| `src/components/PaymentsPage.tsx` | Tracked unchanged | 24851 | Application source |
| `src/components/PinSetupPage.tsx` | Tracked unchanged | 4800 | Application source |
| `src/components/ReceiptReviewPage.tsx` | Tracked unchanged | 11227 | Application source |
| `src/components/ReportsPage.tsx` | Tracked unchanged | 7450 | Application source |
| `src/components/SettingsPage.tsx` | Tracked unchanged | 5539 | Application source |
| `src/components/WalkinsPage.tsx` | Tracked unchanged | 14436 | Application source |
| `src/lib/csv.ts` | Tracked unchanged | 1244 | Application source |
| `src/lib/entrance-link.ts` | Tracked unchanged | 440 | Application source |
| `src/lib/function-error.ts` | Tracked unchanged | 956 | Application source |
| `src/lib/money.ts` | Tracked unchanged | 647 | Application source |
| `src/lib/operation-error.ts` | Tracked unchanged | 338 | Application source |
| `src/lib/public-entry-contract.ts` | Tracked unchanged | 2059 | Application source |
| `src/lib/supabase.ts` | Tracked unchanged | 2490 | Application source |
| `src/lib/walkin-recovery-store.ts` | Tracked unchanged | 3164 | Application source |
| `src/main.tsx` | Tracked unchanged | 999 | Application source |
| `src/style.css` | Tracked unchanged | 35911 | Application source |
| `supabase/.gitignore` | Tracked unchanged | 72 | Repository configuration |
| `supabase/config.toml` | Tracked unchanged | 18387 | Repository configuration |
| `supabase/functions/_shared/browser-cors.ts` | Tracked unchanged | 1513 | Edge runtime or test |
| `supabase/functions/_shared/browser-cors_test.ts` | Tracked unchanged | 1654 | Edge runtime or test |
| `supabase/functions/_shared/cash-operations.ts` | Tracked unchanged | 2248 | Edge runtime or test |
| `supabase/functions/_shared/cash-operations_test.ts` | Tracked unchanged | 1232 | Edge runtime or test |
| `supabase/functions/_shared/member-checkin.ts` | Tracked unchanged | 6159 | Edge runtime or test |
| `supabase/functions/_shared/member-checkin_test.ts` | Tracked unchanged | 6672 | Edge runtime or test |
| `supabase/functions/_shared/member-mobile.ts` | Tracked unchanged | 3970 | Edge runtime or test |
| `supabase/functions/_shared/member-mobile_test.ts` | Tracked unchanged | 2319 | Edge runtime or test |
| `supabase/functions/_shared/member-registration.ts` | Tracked unchanged | 1588 | Edge runtime or test |
| `supabase/functions/_shared/member-registration_test.ts` | Tracked unchanged | 1691 | Edge runtime or test |
| `supabase/functions/_shared/membership-calendar.ts` | Tracked unchanged | 3716 | Edge runtime or test |
| `supabase/functions/_shared/membership-calendar_test.ts` | Tracked unchanged | 4998 | Edge runtime or test |
| `supabase/functions/_shared/membership-lifecycle.ts` | Tracked unchanged | 2342 | Edge runtime or test |
| `supabase/functions/_shared/membership-lifecycle_test.ts` | Tracked unchanged | 2692 | Edge runtime or test |
| `supabase/functions/_shared/owner-attendance.ts` | Tracked unchanged | 2175 | Edge runtime or test |
| `supabase/functions/_shared/owner-attendance_test.ts` | Tracked unchanged | 2346 | Edge runtime or test |
| `supabase/functions/_shared/owner-register-request.ts` | Tracked unchanged | 2509 | Edge runtime or test |
| `supabase/functions/_shared/owner-register-request_test.ts` | Tracked unchanged | 4909 | Edge runtime or test |
| `supabase/functions/_shared/owner-register-service.ts` | Tracked unchanged | 2943 | Edge runtime or test |
| `supabase/functions/_shared/owner-register-service_test.ts` | Tracked unchanged | 4251 | Edge runtime or test |
| `supabase/functions/_shared/owner-reporting.ts` | Tracked unchanged | 3248 | Edge runtime or test |
| `supabase/functions/_shared/owner-reporting_test.ts` | Tracked unchanged | 2468 | Edge runtime or test |
| `supabase/functions/_shared/pin-enrollment.ts` | Tracked unchanged | 890 | Edge runtime or test |
| `supabase/functions/_shared/pin-enrollment_test.ts` | Tracked unchanged | 1174 | Edge runtime or test |
| `supabase/functions/_shared/pin-password.ts` | Tracked unchanged | 1092 | Edge runtime or test |
| `supabase/functions/_shared/pin-password_test.ts` | Tracked unchanged | 1483 | Edge runtime or test |
| `supabase/functions/_shared/pin-recovery.ts` | Tracked unchanged | 2895 | Edge runtime or test |
| `supabase/functions/_shared/pin-recovery_test.ts` | Tracked unchanged | 3524 | Edge runtime or test |
| `supabase/functions/_shared/postgres-bytea.ts` | Tracked unchanged | 300 | Edge runtime or test |
| `supabase/functions/_shared/postgres-bytea_test.ts` | Tracked unchanged | 808 | Edge runtime or test |
| `supabase/functions/_shared/preflight_test.ts` | Tracked unchanged | 6225 | Edge runtime or test |
| `supabase/functions/_shared/provisional-claims.ts` | Tracked unchanged | 2269 | Edge runtime or test |
| `supabase/functions/_shared/provisional-claims_test.ts` | Tracked unchanged | 1254 | Edge runtime or test |
| `supabase/functions/_shared/receipt-review.ts` | Tracked unchanged | 3880 | Edge runtime or test |
| `supabase/functions/_shared/receipt-review_test.ts` | Tracked unchanged | 2176 | Edge runtime or test |
| `supabase/functions/_shared/walkin-ingress.ts` | Tracked unchanged | 2188 | Edge runtime or test |
| `supabase/functions/_shared/walkin-recovery.ts` | Tracked unchanged | 3855 | Edge runtime or test |
| `supabase/functions/_shared/walkin-recovery_test.ts` | Tracked unchanged | 2265 | Edge runtime or test |
| `supabase/functions/_shared/walkin-request.ts` | Tracked unchanged | 3545 | Edge runtime or test |
| `supabase/functions/_shared/walkin-request_test.ts` | Tracked unchanged | 2895 | Edge runtime or test |
| `supabase/functions/deno.json` | Tracked unchanged | 79 | Edge runtime or test |
| `supabase/functions/member-checkin/index.ts` | Tracked unchanged | 4948 | Edge runtime or test |
| `supabase/functions/member-enroll-pin/index.ts` | Tracked unchanged | 6468 | Edge runtime or test |
| `supabase/functions/member-reset-pin/index.ts` | Tracked unchanged | 3946 | Edge runtime or test |
| `supabase/functions/owner-attendance-claims/index.ts` | Tracked unchanged | 2684 | Edge runtime or test |
| `supabase/functions/owner-attendance/index.ts` | Tracked unchanged | 2881 | Edge runtime or test |
| `supabase/functions/owner-cash/index.ts` | Tracked unchanged | 2554 | Edge runtime or test |
| `supabase/functions/owner-create-membership-purchase/index.ts` | Tracked unchanged | 5870 | Edge runtime or test |
| `supabase/functions/owner-create-pin-enrollment-token/index.ts` | Tracked unchanged | 6610 | Edge runtime or test |
| `supabase/functions/owner-create-pin-recovery-token/index.ts` | Tracked unchanged | 3930 | Edge runtime or test |
| `supabase/functions/owner-list-members/index.ts` | Tracked unchanged | 5501 | Edge runtime or test |
| `supabase/functions/owner-list-membership-plans/index.ts` | Tracked unchanged | 4676 | Edge runtime or test |
| `supabase/functions/owner-list-membership-purchases/index.ts` | Tracked unchanged | 5377 | Edge runtime or test |
| `supabase/functions/owner-membership-lifecycle/index.ts` | Tracked unchanged | 3057 | Edge runtime or test |
| `supabase/functions/owner-membership-payments/index.ts` | Tracked unchanged | 9714 | Edge runtime or test |
| `supabase/functions/owner-receipt-review/index.ts` | Tracked unchanged | 2571 | Edge runtime or test |
| `supabase/functions/owner-register-member/index.ts` | Tracked unchanged | 3906 | Edge runtime or test |
| `supabase/functions/owner-reporting/index.ts` | Tracked unchanged | 3196 | Edge runtime or test |
| `supabase/functions/owner-save-membership-plan/index.ts` | Tracked unchanged | 6165 | Edge runtime or test |
| `supabase/functions/owner-status/.npmrc` | Tracked unchanged | 221 | Edge runtime or test |
| `supabase/functions/owner-status/deno.json` | Tracked unchanged | 136 | Edge runtime or test |
| `supabase/functions/owner-status/deno.lock` | Tracked unchanged | 2140 | Edge runtime or test |
| `supabase/functions/owner-status/index.ts` | Tracked unchanged | 3842 | Edge runtime or test |
| `supabase/functions/owner-walkins/index.ts` | Tracked unchanged | 4322 | Edge runtime or test |
| `supabase/functions/public-walkin-recovery/index.ts` | Tracked unchanged | 4984 | Edge runtime or test |
| `supabase/functions/public-walkin-request/index.ts` | Tracked unchanged | 4033 | Edge runtime or test |
| `supabase/migrations/20261028061728_initial_schema.sql` | Tracked unchanged | 5232 | Historical migration; unchanged |
| `supabase/migrations/20261028062516_membership_core.sql` | Tracked unchanged | 2464 | Historical migration; unchanged |
| `supabase/migrations/20261028062602_payment_ledger.sql` | Tracked unchanged | 5402 | Historical migration; unchanged |
| `supabase/migrations/20261028062706_walkin_attendance.sql` | Tracked unchanged | 5653 | Historical migration; unchanged |
| `supabase/migrations/20261028062757_owner_security.sql` | Tracked unchanged | 1967 | Historical migration; unchanged |
| `supabase/migrations/20261028062853_member_pin_security.sql` | Tracked unchanged | 3502 | Historical migration; unchanged |
| `supabase/migrations/20261028062935_cash_reconciliation.sql` | Tracked unchanged | 3699 | Historical migration; unchanged |
| `supabase/migrations/20261028063027_audit_integrity.sql` | Tracked unchanged | 1588 | Historical migration; unchanged |
| `supabase/migrations/20261028063404_integrity_fixes.sql` | Tracked unchanged | 341 | Historical migration; unchanged |
| `supabase/migrations/20261028063446_membership_overlap_guard.sql` | Tracked unchanged | 568 | Historical migration; unchanged |
| `supabase/migrations/20261028063638_payment_integrity_guard.sql` | Tracked unchanged | 621 | Historical migration; unchanged |
| `supabase/migrations/20261028064100_database_security_foundation.sql` | Tracked unchanged | 312 | Historical migration; unchanged |
| `supabase/migrations/20261029100000_owner_authorization_rpc.sql` | Tracked unchanged | 975 | Historical migration; unchanged |
| `supabase/migrations/20261030120000_audit_chain_enforcement.sql` | Tracked unchanged | 11814 | Historical migration; unchanged |
| `supabase/migrations/20261030130000_owner_register_member.sql` | Tracked unchanged | 3341 | Historical migration; unchanged |
| `supabase/migrations/20261030140000_owner_create_pin_enrollment_token.sql` | Tracked unchanged | 3195 | Historical migration; unchanged |
| `supabase/migrations/20261030150000_member_pin_enrollment.sql` | Tracked unchanged | 3434 | Historical migration; unchanged |
| `supabase/migrations/20261030160000_global_pin_enrollment_rate_limit.sql` | Tracked unchanged | 2176 | Historical migration; unchanged |
| `supabase/migrations/20261030170000_rolling_pin_enrollment_rate_limit.sql` | Tracked unchanged | 2592 | Historical migration; unchanged |
| `supabase/migrations/20261030180000_owner_list_members.sql` | Tracked unchanged | 2644 | Historical migration; unchanged |
| `supabase/migrations/20261103080000_owner_membership_plans.sql` | Tracked unchanged | 6168 | Historical migration; unchanged |
| `supabase/migrations/20261103100000_owner_create_membership_purchase.sql` | Tracked unchanged | 3198 | Historical migration; unchanged |
| `supabase/migrations/20261103110000_owner_list_membership_purchases.sql` | Tracked unchanged | 3596 | Historical migration; unchanged |
| `supabase/migrations/20261103120000_owner_membership_payments.sql` | Tracked unchanged | 30565 | Historical migration; unchanged |
| `supabase/migrations/20261110100000_executor_hardening.sql` | Tracked unchanged | 177867 | Historical migration; unchanged |
| `supabase/migrations/20261110103000_audit_timezone.sql` | Tracked unchanged | 1532 | Historical migration; unchanged |
| `supabase/migrations/20261110110000_membership_lifecycle.sql` | Tracked unchanged | 18420 | Historical migration; unchanged |
| `supabase/migrations/20261110120000_owner_reporting.sql` | Tracked unchanged | 7337 | Historical migration; unchanged |
| `supabase/migrations/20261110130000_pin_recovery.sql` | Tracked unchanged | 13448 | Historical migration; unchanged |
| `supabase/migrations/20261110140000_walkin_operations.sql` | Tracked unchanged | 29357 | Historical migration; unchanged |
| `supabase/migrations/20261110150000_member_checkin.sql` | Tracked unchanged | 18314 | Historical migration; unchanged |
| `supabase/migrations/20261110153000_owner_attendance.sql` | Tracked unchanged | 3726 | Historical migration; unchanged |
| `supabase/migrations/20261110160000_receipt_review_corrections.sql` | Tracked unchanged | 32682 | Historical migration; unchanged |
| `supabase/migrations/20261110170000_cash_operations.sql` | Tracked unchanged | 12951 | Historical migration; unchanged |
| `supabase/migrations/20261110180000_provisional_claims.sql` | Tracked unchanged | 9969 | Historical migration; unchanged |
| `supabase/migrations/20261110190000_receipt_allocation_review.sql` | Tracked unchanged | 27473 | Historical migration; unchanged |
| `supabase/migrations/20261110200000_operational_reports.sql` | Tracked unchanged | 6468 | Historical migration; unchanged |
| `supabase/recovery/README.md` | Tracked unchanged | 16716 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/catalog.sql` | Tracked unchanged | 5807 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/checks.json` | Tracked unchanged | 2935 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/README.md` | Tracked unchanged | 10999 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/01-explicit-routine-acls.sql` | Tracked unchanged | 12140 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110100000_executor_hardening.sql` | Tracked unchanged | 189105 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110103000_audit_timezone.sql` | Tracked unchanged | 11703 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110110000_membership_lifecycle.sql` | Tracked unchanged | 29180 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110120000_owner_reporting.sql` | Tracked unchanged | 17082 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110130000_pin_recovery.sql` | Tracked unchanged | 22659 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110140000_walkin_operations.sql` | Tracked unchanged | 39102 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110150000_member_checkin.sql` | Tracked unchanged | 28212 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110153000_owner_attendance.sql` | Tracked unchanged | 12937 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110160000_receipt_review_corrections.sql` | Tracked unchanged | 42841 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110170000_cash_operations.sql` | Tracked unchanged | 23110 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110180000_provisional_claims.sql` | Tracked unchanged | 19180 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110190000_receipt_allocation_review.sql` | Tracked unchanged | 36666 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/20261110200000_operational_reports.sql` | Tracked unchanged | 15679 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/compatibility-authority.sql` | Tracked unchanged | 3097 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/effective-privileges.sql` | Tracked unchanged | 4909 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/executor_hardening_assertions.sql` | Tracked unchanged | 73611 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/final_security_assertions.sql` | Tracked unchanged | 4288 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/manifest.json` | Tracked unchanged | 15643 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/review/member_checkin_behavior.sql` | Tracked unchanged | 16201 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/01-explicit-routine-acls.sql` | Tracked unchanged | 12224 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110100000_executor_hardening.sql` | Tracked unchanged | 189195 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110103000_audit_timezone.sql` | Tracked unchanged | 11784 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110110000_membership_lifecycle.sql` | Tracked unchanged | 29264 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110120000_owner_reporting.sql` | Tracked unchanged | 17166 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110130000_pin_recovery.sql` | Tracked unchanged | 22740 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110140000_walkin_operations.sql` | Tracked unchanged | 39186 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110150000_member_checkin.sql` | Tracked unchanged | 28296 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110153000_owner_attendance.sql` | Tracked unchanged | 13018 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110160000_receipt_review_corrections.sql` | Tracked unchanged | 42922 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110170000_cash_operations.sql` | Tracked unchanged | 23191 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110180000_provisional_claims.sql` | Tracked unchanged | 19261 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110190000_receipt_allocation_review.sql` | Tracked unchanged | 36747 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/20261110200000_operational_reports.sql` | Tracked unchanged | 15760 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/compatibility-authority.sql` | Tracked unchanged | 3100 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/effective-privileges.sql` | Tracked unchanged | 4912 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/executor_hardening_assertions.sql` | Tracked unchanged | 73614 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/final_security_assertions.sql` | Tracked unchanged | 4291 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/history-fixture.sql` | Tracked unchanged | 1111 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/maintenance-rls-proof.sql` | Tracked unchanged | 10775 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/manifest.json` | Tracked unchanged | 16044 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/compatibility/synthetic/member_checkin_behavior.sql` | Tracked unchanged | 16204 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/additional-legacy-blockers.sql` | Tracked unchanged | 1934 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/audit.sql` | Tracked unchanged | 2735 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/compatibility-authority.sql` | Tracked unchanged | 3097 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/legacy-dependencies.sql` | Tracked unchanged | 1566 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/lifecycle-payments.sql` | Tracked unchanged | 3340 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/m1-plan-routine-components.sql` | Tracked unchanged | 5964 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/m2-data-privilege-attribution.sql` | Tracked unchanged | 15855 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/migration-authority.sql` | Tracked unchanged | 1717 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/diagnostics/registration-plan-cash.sql` | Tracked unchanged | 1982 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/effective-privileges.sql` | Tracked unchanged | 4516 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/history.sql` | Tracked unchanged | 496 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/phase61/001-public-walkin-recovery.sql` | Tracked unchanged | 6985 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/phase61/source-manifest.json` | Tracked unchanged | 766 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/phase61b/002-public-ingress.sql` | Tracked unchanged | 18074 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/phase61b/003-local-operational-controls.sql` | Candidate | 2246 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/phase61b/operational-manifest.json` | Candidate | 1130 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/phase61b/source-manifest.json` | Tracked unchanged | 646 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/proposals/01-explicit-routine-acls.sql` | Tracked unchanged | 2644 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/proposals/02-postgres-future-routine-defaults.sql` | Tracked unchanged | 943 | Recovery design/candidate; not hosted migration |
| `supabase/recovery/source-manifest.json` | Tracked unchanged | 14745 | Recovery design/candidate; not hosted migration |
| `supabase/tests/audit_timezone_behavior.sql` | Tracked unchanged | 1356 | Synthetic SQL test |
| `supabase/tests/audit_timezone_incompatible_seed.sql` | Tracked unchanged | 871 | Synthetic SQL test |
| `supabase/tests/audit_timezone_refusal_assertions.sql` | Tracked unchanged | 1350 | Synthetic SQL test |
| `supabase/tests/audit_timezone_seed.sql` | Tracked unchanged | 863 | Synthetic SQL test |
| `supabase/tests/cash_operations_behavior.sql` | Tracked unchanged | 4268 | Synthetic SQL test |
| `supabase/tests/check-security-config.ps1` | Tracked unchanged | 4233 | Synthetic SQL test |
| `supabase/tests/compatibility_legacy_diagnostics.sql` | Tracked unchanged | 1156 | Synthetic SQL test |
| `supabase/tests/compatibility_security_behavior.sql` | Tracked unchanged | 2392 | Synthetic SQL test |
| `supabase/tests/database_owner_migration_procedure.sql` | Tracked unchanged | 11240 | Synthetic SQL test |
| `supabase/tests/database_security_foundation_assertions.sql` | Tracked unchanged | 36651 | Synthetic SQL test |
| `supabase/tests/executor_behavior.sql` | Tracked unchanged | 11311 | Synthetic SQL test |
| `supabase/tests/executor_hardening_assertions.sql` | Tracked unchanged | 73218 | Synthetic SQL test |
| `supabase/tests/final_eligibility_boundaries.sql` | Tracked unchanged | 3415 | Synthetic SQL test |
| `supabase/tests/final_security_assertions.sql` | Tracked unchanged | 3895 | Synthetic SQL test |
| `supabase/tests/member_checkin_behavior.sql` | Tracked unchanged | 15808 | Synthetic SQL test |
| `supabase/tests/membership_lifecycle_behavior.sql` | Tracked unchanged | 20143 | Synthetic SQL test |
| `supabase/tests/membership_payment_security_assertions.sql` | Tracked unchanged | 4252 | Synthetic SQL test |
| `supabase/tests/operational_reports_behavior.sql` | Tracked unchanged | 4616 | Synthetic SQL test |
| `supabase/tests/owner_attendance_behavior.sql` | Tracked unchanged | 5090 | Synthetic SQL test |
| `supabase/tests/owner_reporting_behavior.sql` | Tracked unchanged | 13376 | Synthetic SQL test |
| `supabase/tests/pin_recovery_behavior.sql` | Tracked unchanged | 8949 | Synthetic SQL test |
| `supabase/tests/provisional_claims_behavior.sql` | Tracked unchanged | 5106 | Synthetic SQL test |
| `supabase/tests/public_walkin_clock_boundaries.sql` | Candidate | 9461 | Synthetic SQL test |
| `supabase/tests/public_walkin_ingress.sql` | Tracked unchanged | 18813 | Synthetic SQL test |
| `supabase/tests/public_walkin_recovery.sql` | Tracked unchanged | 10282 | Synthetic SQL test |
| `supabase/tests/receipt_allocation_behavior.sql` | Tracked unchanged | 8463 | Synthetic SQL test |
| `supabase/tests/receipt_review_behavior.sql` | Tracked unchanged | 11181 | Synthetic SQL test |
| `supabase/tests/recovery_creator_defaults.sql` | Tracked unchanged | 2247 | Synthetic SQL test |
| `supabase/tests/recovery_inherited_cleanup.sql` | Tracked unchanged | 661 | Synthetic SQL test |
| `supabase/tests/recovery_inherited_leak.sql` | Tracked unchanged | 564 | Synthetic SQL test |
| `supabase/tests/recovery_legacy_behavior.sql` | Tracked unchanged | 1127 | Synthetic SQL test |
| `supabase/tests/recovery_security_behavior.sql` | Tracked unchanged | 1915 | Synthetic SQL test |
| `supabase/tests/synthetic_bootstrap.sql` | Tracked unchanged | 1243 | Synthetic SQL test |
| `supabase/tests/walkin_behavior.sql` | Tracked unchanged | 17394 | Synthetic SQL test |
| `tests/csv.test.mjs` | Tracked unchanged | 827 | Node regression test |
| `tests/durable-ingress-ops.test.mjs` | Candidate | 4360 | Node regression test |
| `tests/edge-handlers.test.mjs` | Tracked unchanged | 9103 | Node regression test |
| `tests/entrance-link.test.mjs` | Tracked unchanged | 1097 | Node regression test |
| `tests/function-error.test.mjs` | Tracked unchanged | 901 | Node regression test |
| `tests/hosted-package.test.mjs` | Tracked unchanged | 2901 | Node regression test |
| `tests/hosting-diagnostics.test.mjs` | Tracked unchanged | 2136 | Node regression test |
| `tests/ingress-monitor.test.mjs` | Candidate | 2523 | Node regression test |
| `tests/money.test.mjs` | Tracked unchanged | 494 | Node regression test |
| `tests/operation-error.test.mjs` | Tracked unchanged | 588 | Node regression test |
| `tests/persisted-http-guard.test.mjs` | Candidate | 1227 | Node regression test |
| `tests/public-entry-contract.test.mjs` | Tracked unchanged | 3612 | Node regression test |
| `tests/recovery-compatibility.test.mjs` | Tracked unchanged | 3674 | Node regression test |
| `tests/recovery-integrity.test.mjs` | Tracked unchanged | 6006 | Node regression test |
| `tests/recovery-sql.test.mjs` | Tracked unchanged | 2149 | Node regression test |
| `tests/recovery-tooling.test.mjs` | Tracked unchanged | 1607 | Node regression test |
| `tests/recovery.test.mjs` | Tracked unchanged | 5593 | Node regression test |
| `tests/source-security.test.mjs` | Tracked unchanged | 5448 | Node regression test |
| `tests/vite-development.test.mjs` | Tracked unchanged | 3139 | Node regression test |
| `tests/walkin-ingress.test.mjs` | Tracked unchanged | 2884 | Node regression test |
| `tests/walkin-recovery.test.mjs` | Tracked unchanged | 8452 | Node regression test |
| `tools/recovery-parser/README.md` | Tracked unchanged | 1390 | Separately locked parser tooling |
| `tools/recovery-parser/package-lock.json` | Tracked unchanged | 1601 | Separately locked parser tooling |
| `tools/recovery-parser/package.json` | Tracked unchanged | 160 | Separately locked parser tooling |
| `tsconfig.app.json` | Tracked unchanged | 615 | Repository configuration |
| `tsconfig.json` | Tracked unchanged | 119 | Repository configuration |
| `tsconfig.node.json` | Tracked unchanged | 556 | Repository configuration |
| `vite.config.ts` | Tracked unchanged | 1187 | Repository configuration |
