param([string] $PostgresBin, [switch] $CustomerCompatibility, [switch] $TestLegacyAuditRefusal)
$ErrorActionPreference = 'Stop'
if (-not $PostgresBin) {
    $portable = Join-Path $PSScriptRoot '../.cache/pg17-portable-17.12/pgsql/bin'
    $PostgresBin = if (Test-Path -LiteralPath (Join-Path $portable 'postgres.exe')) { [IO.Path]::GetFullPath($portable) } else { 'C:\Program Files\PostgreSQL\17\bin' }
}
# No connection string accepted. The underlying harness initializes a fresh loopback cluster.
$postgres = Join-Path $PostgresBin 'postgres.exe'
if (-not (Test-Path -LiteralPath $postgres)) {
    Write-Output 'BLOCKED: installed local PostgreSQL 17 runtime unavailable. No environment provisioned.'
    exit 2
}
$version = & $postgres --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch 'PostgreSQL\) 17\.') {
    Write-Output 'BLOCKED: PostgreSQL 17 executable required; refusing another major.'
    exit 2
}
Write-Output "PASS: selected PostgreSQL 17 runtime: $version"
& (Join-Path $PSScriptRoot 'test-database.ps1') -PostgresBin $PostgresBin -RecoveryAudit -CustomerCompatibility:$CustomerCompatibility -TestLegacyAuditRefusal:$TestLegacyAuditRefusal
exit $LASTEXITCODE
