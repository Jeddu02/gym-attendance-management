param([string] $ArchivePath, [switch] $DownloadOfficialArchive)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runtimeRoot = Join-Path $repoRoot '.cache/pg17-portable-17.12'
$officialUrl = 'https://sbp.enterprisedb.com/getfile.jsp?fileid=1260667'
$acquisitionMode = if ($ArchivePath) { 'existing-archive' } else { 'official-https-download' }
if (Test-Path -LiteralPath $runtimeRoot) { throw 'Runtime target already exists; preserve it and inspect its provenance.' }
if (-not $ArchivePath -and -not $DownloadOfficialArchive) { throw 'Supply an existing archive or explicitly request the official download.' }
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.cache'))) { New-Item -ItemType Directory -Path (Join-Path $repoRoot '.cache') | Out-Null }
if ((Get-Item -LiteralPath (Join-Path $repoRoot '.cache')).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Redirected cache refused.' }
& git -C $repoRoot check-ignore -- .cache/pg17-portable-17.12
if ($LASTEXITCODE -ne 0) { throw 'Runtime cache must be ignored.' }
New-Item -ItemType Directory -Path $runtimeRoot | Out-Null
if (-not $ArchivePath) {
    $ArchivePath = Join-Path $runtimeRoot 'official-17.12-windows.zip'
    # Native curl avoids PowerShell progress rendering; credentials are never used.
    & curl.exe --fail --location --proto '=https' --proto-redir '=https' --silent --show-error --output $ArchivePath $officialUrl
    if ($LASTEXITCODE -ne 0) { throw 'Official archive acquisition failed; partial file retained, not executed.' }
}
$verifiedJson = & (Join-Path $PSScriptRoot 'verify-native-pg17-archive.ps1') -ArchivePath $ArchivePath
$verified = ($verifiedJson -join "`n") | ConvertFrom-Json
$archiveHash = $verified.archiveSha256
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($ArchivePath))
try {
    $rootPrefix = [IO.Path]::GetFullPath($runtimeRoot) + [IO.Path]::DirectorySeparatorChar
    $total = 0L; $extracted = 0
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '(^[\\/]|:|(^|[\\/])\.\.([\\/]|$))') { throw 'Unsafe archive path.' }
        if (($entry.ExternalAttributes -shr 16 -band 0xF000) -eq 0xA000) { throw 'Archive symlink refused.' }
        $target = [IO.Path]::GetFullPath((Join-Path $runtimeRoot $entry.FullName))
        if (-not $target.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Archive path escapes cache.' }
        if ($entry.FullName -notmatch '^pgsql/(bin|lib|share)/' -or $entry.FullName.EndsWith('/')) { continue }
        $total += $entry.Length
        if ($total -gt 3GB) { throw 'Runtime extraction size budget exceeded.' }
        $parent = [IO.Path]::GetDirectoryName($target)
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)
        $extracted++
    }
} finally { $zip.Dispose() }
$postgres = Join-Path $runtimeRoot 'pgsql/bin/postgres.exe'
$version = & $postgres --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch 'PostgreSQL\) 17\.12\b') { throw 'Extracted PG17.12 runtime verification failed.' }
$provenance = @{ publisherSource=$verified.publisherArchiveUrl; observedDownloadUrl=$(if($acquisitionMode -eq 'official-https-download'){$officialUrl}else{$null});
    acquisitionMode=$acquisitionMode; publisherVerification=$verified;
    architecture='windows-x64'; archiveSha256=$archiveHash; version="$version"; extractedFiles=$extracted;
    postgresSha256=(Get-FileHash -LiteralPath $postgres -Algorithm SHA256).Hash.ToLowerInvariant();
    verification='MATCHED_PUBLISHER_HTTPS_SHA256; no detached signature assertion';
    systemInstallationChanged=$false }
$provenance | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtimeRoot 'provenance.json') -Encoding UTF8
Write-Output "PASS: $version; portable runtime only; $extracted files; archive SHA-256 $archiveHash"
