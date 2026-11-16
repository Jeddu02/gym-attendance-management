$ErrorActionPreference = 'Stop'
# Filesystem/unit tests ONLY. No psql, PostgreSQL tools, database URLs, or network calls.
# Preserve real native exit status; never report success after a child refusal.
try {
    & node (Join-Path $PSScriptRoot 'parse-drafts-offline.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'SQL/procedural parser or body coverage failed.' }
    & node --test (Join-Path $PSScriptRoot 'parser-fixtures.test.mjs') (Join-Path $PSScriptRoot 'semantic-alignment.test.mjs') (Join-Path $PSScriptRoot 'approved-text-casts.test.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Offline parser/definition regression tests failed.' }
    & node (Join-Path $PSScriptRoot 'review-boolean-alignment.mjs') --require-aligned
    if ($LASTEXITCODE -ne 0) { throw 'Definition alignment gate refused.' }
    & node (Join-Path $PSScriptRoot 'check-executor-fixtures.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Declarative executor fixture review failed.' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'static-review.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Draft static checker failed.' }
    & node (Join-Path $PSScriptRoot 'test-offline-negative.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Offline negative suite failed.' }
    & node (Join-Path $PSScriptRoot 'test-aligned-negative.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Aligned assertion negative suite failed.' }
    & node --test (Join-Path $PSScriptRoot 'default-privilege-classification.test.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Default privilege classification tests failed.' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '../../../supabase/tests/check-security-config.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Existing security configuration check failed.' }
    Write-Output 'PASS: filesystem-only validation. Restricted-executor runtime and hosted behavior remain unverified.'
    exit 0
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
