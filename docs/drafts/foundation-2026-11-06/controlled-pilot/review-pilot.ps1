param([string]$Spec, [string]$Candidate, [string]$Approval, [string]$Outcomes, [switch]$Execute)
$ErrorActionPreference = 'Stop'
# OFFLINE ONLY. No psql/process runner or database connection is implemented.
if ($Execute) {
    Write-Error 'Execution refused: recovery/post-rollback verifier and isolation approval remain unresolved.' -ErrorAction Continue
    exit 2
}
$pilotArguments = @((Join-Path $PSScriptRoot 'check-pilot.mjs'))
if ($Spec) { $pilotArguments += @('--spec', $Spec) }
if ($Candidate) { $pilotArguments += @('--candidate', $Candidate) }
if ($Approval) { $pilotArguments += @('--approval', $Approval) }
if ($Outcomes) { $pilotArguments += @('--outcomes', $Outcomes) }
try {
    & node @pilotArguments
    $nativeExit = $LASTEXITCODE
    if ($null -eq $nativeExit) { throw 'Offline child did not report an exit code.' }
    exit $nativeExit
} catch {
    Write-Error 'Offline review process failed; no database operation was attempted.' -ErrorAction Continue
    exit 2
}
