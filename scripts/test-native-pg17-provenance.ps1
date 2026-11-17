param([string] $ArchivePath = (Join-Path $PSScriptRoot '../.cache/pg17-portable-17.12/official-17.12-windows.zip'))
$ErrorActionPreference='Stop'
$verifier=Join-Path $PSScriptRoot 'verify-native-pg17-archive.ps1'
$result = & $verifier -ArchivePath $ArchivePath | ConvertFrom-Json
if ($result.verification -ne 'MATCHED_PUBLISHER_HTTPS_SHA256' -or $result.publisherSha256 -cne $result.archiveSha256 -or $result.architecture -ne 'windows-x64') { throw 'Positive publisher verification failed.' }
Write-Output 'PASS: existing archive matches independent publisher HTTPS checksum.'
$fake=Join-Path $PSScriptRoot ('../.cache/archive-negative-'+[guid]::NewGuid().ToString('N')+'.zip')
[IO.File]::WriteAllText($fake,'synthetic-invalid-archive')
# PowerShell 5 wraps native stderr in ErrorRecords even for an expected refusal.
$ErrorActionPreference='Continue'
$output=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifier -ArchivePath $fake 2>&1)
$code=$LASTEXITCODE
$ErrorActionPreference='Stop'
if($code -ne 1 -or ($output -join '') -notmatch 'Publisher archive checksum mismatch'){throw 'Mismatch was not rejected.'}
Write-Output 'PASS: mismatched archive refused before extraction or execution.'
