param([string] $PostgresBin = (Join-Path $PSScriptRoot '../.cache/pg17-portable-17.12/pgsql/bin'))
$ErrorActionPreference='Stop'
$results=[Collections.Generic.List[object]]::new()
foreach ($point in @('AfterCredential','BeforeInitdb','InitdbFailure','AfterInitdb','AfterStart')) {
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test-database.ps1') -PostgresBin $PostgresBin -FaultPoint $point)
    if ($LASTEXITCODE -ne 1 -or -not (($output -join "`n") -match 'FAIL:')) { throw 'Expected initialization refusal missing.' }
    $match = [regex]::Match(($output -join "`n"),'Synthetic logs retained under \.cache/security-test-([a-f0-9]{32})')
    if (-not $match.Success) { throw 'Fault run identity missing.' }
    $root = Join-Path $PSScriptRoot ("../.cache/security-test-" + $match.Groups[1].Value)
    foreach ($file in @('bootstrap-password','pgpass.conf','recovery-actor-bootstrap.sql','data/postmaster.pid')) {
        if (Test-Path -LiteralPath (Join-Path $root $file)) { throw 'Fault left a credential or active server.' }
    }
    # Inspect formats only, never return possible values from a failed fixture.
    foreach ($log in Get-ChildItem -LiteralPath $root -Filter '*.log') {
        if ([IO.File]::ReadAllText($log.FullName) -match "PASSWORD\s+'[^']+'") { throw 'Sensitive SQL text in test log.' }
    }
    Write-Output "PASS: $point; expected failure, stopped server and no temporary credentials."
    $results.Add(@{point=$point;runId=$match.Groups[1].Value;result='PASS'})
}
$evidence=Join-Path $PSScriptRoot ('../.cache/cleanup-test-'+[guid]::NewGuid().ToString('N')+'.json')
$results | ConvertTo-Json | Set-Content -LiteralPath $evidence -Encoding UTF8
Write-Output "Synthetic fault evidence: $evidence"
