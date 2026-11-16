param(
    [switch]$CheckPgpassOnly
)

$ErrorActionPreference = 'Stop'

# Read-only preflight shared by bootstrap, migration, RLS, and cleanup steps.
# It never prints password-file contents or changes ACLs/files.
$PgBin = 'C:\Program Files\PostgreSQL\18\bin'
$PgControlData = Join-Path $PgBin 'pg_controldata.exe'
$Psql = Join-Path $PgBin 'psql.exe'
$IdentityRoot = Join-Path $env:LOCALAPPDATA 'GYMFORCE-PG18-TEST'
$DataDirectory = Join-Path $IdentityRoot 'data'
$MarkerPath = Join-Path $IdentityRoot 'cluster-marker.txt'
$SystemIdentifierPath = Join-Path $IdentityRoot 'system-identifier.txt'
$PgpassPath = Join-Path (Join-Path $env:APPDATA 'postgresql') 'pgpass.conf'
# Reject libpq overrides, including PGPASSWORD, PGPASSFILE, PGSERVICE and
# PGOPTIONS. Never print their values. Callers must use a clean environment.
if (@(Get-ChildItem Env: | Where-Object { $_.Name -like 'PG*' }).Count -ne 0) {
    throw 'Remove PostgreSQL PG* environment overrides before using this harness. Values were not displayed.'
}

function Assert-NoReparsePoint([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Harness paths must not contain symbolic links, junctions, or other reparse points.'
        }
        if ($item -is [System.IO.FileInfo]) { $item = $item.Directory }
        else { $item = $item.Parent }
    }
}

function Assert-ProtectedFile([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description is missing: $Path"
    }

    Assert-NoReparsePoint $Path
    $acl = Get-Acl -LiteralPath $Path
    if (-not $acl.AreAccessRulesProtected) {
        throw "$Description ACL inherits permissions; protect it before continuing."
    }

    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $allowedSids = @($currentSid, 'S-1-5-18', 'S-1-5-32-544')
    $ownerSid = $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
    if ($ownerSid -ne $currentSid -and $ownerSid -ne 'S-1-5-32-544') {
        throw "$Description owner is not the current user or local Administrators."
    }

    $hasCurrentFullControl = $false
    foreach ($rule in $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
        if ($rule.IsInherited -or $rule.IdentityReference.Value -notin $allowedSids -or
            $rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            throw "$Description ACL grants or denies access to an unexpected principal."
        }
        if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and
            $rule.IdentityReference.Value -eq $currentSid -and
            (($rule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq
                [System.Security.AccessControl.FileSystemRights]::FullControl)) {
            $hasCurrentFullControl = $true
        }
    }
    if (-not $hasCurrentFullControl) {
        throw "$Description ACL does not grant the current user FullControl."
    }
}

if (-not (Test-Path -LiteralPath $PgpassPath -PathType Leaf)) {
    throw "pgpass.conf is missing: $PgpassPath. Create it manually; preflight will not create or overwrite it."
}
Assert-ProtectedFile $PgpassPath 'pgpass.conf'

# Parse conservatively: only documented colon/backslash escapes are accepted.
# Reject any competing wildcard or database-specific entry for this endpoint;
# libpq otherwise uses the first match, which could bypass the validated entry.
$field = '((?:\\[:\\]|[^:\\\r\n])*)'
$entryPattern = '^' + (($field, $field, $field, $field, $field) -join ':') + '$'
$requiredEntries = 0
try {
    foreach ($line in [System.IO.File]::ReadAllLines($PgpassPath)) {
        if ($line.Length -eq 0 -or $line.StartsWith('#')) { continue }
        $entry = [regex]::Match($line, $entryPattern)
        if (-not $entry.Success) { throw 'Invalid entry' }
        $hostField = $entry.Groups[1].Value -replace '\\([:\\])', '$1'
        $portField = $entry.Groups[2].Value -replace '\\([:\\])', '$1'
        $databaseField = $entry.Groups[3].Value -replace '\\([:\\])', '$1'
        $userField = $entry.Groups[4].Value -replace '\\([:\\])', '$1'
        if ($hostField -in @('127.0.0.1', '*') -and
            $portField -in @('55432', '*') -and $userField -in @('postgres', '*')) {
            if ($hostField -cne '127.0.0.1' -or $portField -cne '55432' -or
                $databaseField -cne '*' -or $userField -cne 'postgres' -or
                $entry.Groups[5].Value.Length -eq 0) { throw 'Ambiguous entry' }
            $requiredEntries++
        }
    }
    if ($requiredEntries -ne 1) { throw 'Missing or duplicate entry' }
} catch {
    throw 'Cannot validate pgpass.conf: require exactly one nonempty 127.0.0.1:55432:*:postgres entry and no competing matches. Contents were not displayed.'
} finally {
    $line = $null
    $entry = $null
}
if (-not (Test-Path -LiteralPath $Psql -PathType Leaf)) {
    throw "psql was not found: $Psql"
}

Assert-ProtectedFile $MarkerPath 'Cluster marker file'
Assert-ProtectedFile $SystemIdentifierPath 'Cluster system identifier file'
if (-not (Test-Path -LiteralPath $DataDirectory -PathType Container)) {
    throw "Expected PostgreSQL data directory is missing: $DataDirectory"
}
if (-not (Test-Path -LiteralPath $PgControlData -PathType Leaf)) {
    throw "pg_controldata was not found: $PgControlData"
}

$marker = (Get-Content -LiteralPath $MarkerPath -Raw).Trim()
$storedSystemIdentifier = (Get-Content -LiteralPath $SystemIdentifierPath -Raw).Trim()
if ($marker -notmatch '^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
    throw 'Stored cluster marker is missing or malformed; refusing to regenerate it.'
}
if ($storedSystemIdentifier -notmatch '^[0-9]{1,20}$') {
    throw 'Stored PostgreSQL system identifier is missing or malformed.'
}

$canonicalDataDirectory = (Resolve-Path -LiteralPath $DataDirectory).Path.TrimEnd('\', '/')
Assert-NoReparsePoint $canonicalDataDirectory
$controldataOutput = & $PgControlData $canonicalDataDirectory 2>&1
if ($LASTEXITCODE -ne 0) {
    throw 'pg_controldata could not read the expected data directory; identity verification failed.'
}
$systemIdentifierMatches = @(
    $controldataOutput | Select-String -Pattern '^Database system identifier:\s*([0-9]+)\s*$'
)
if ($systemIdentifierMatches.Count -ne 1) {
    throw 'Could not unambiguously read the PostgreSQL system identifier from pg_controldata.'
}
$actualSystemIdentifier = $systemIdentifierMatches[0].Matches[0].Groups[1].Value
if ($actualSystemIdentifier -cne $storedSystemIdentifier) {
    throw 'Stored system identifier does not match pg_controldata for the expected data directory.'
}

if (-not (Test-Path -LiteralPath (Join-Path $canonicalDataDirectory 'postgresql.conf') -PathType Leaf)) {
    throw 'Expected data directory does not contain postgresql.conf.'
}
$configText = Get-Content -LiteralPath (Join-Path $canonicalDataDirectory 'postgresql.conf') -Raw
if ($configText -notmatch ('(?m)^\s*' + [regex]::Escape("gymforce.test_cluster_marker = '$marker'") + '\s*(?:#.*)?$')) {
    throw 'The expected data directory configuration does not contain the stored marker setting.'
}

$targetDatabase = 'gymforce_pg18_test'
if ($CheckPgpassOnly) { $targetDatabase = 'postgres' }
$directorySql = "'" + $canonicalDataDirectory.Replace('\', '/').TrimEnd('/').ToLowerInvariant().Replace("'", "''") + "'"
$identityQuery = @"
BEGIN READ ONLY;
SELECT CASE WHEN current_database() = '$targetDatabase'
 AND inet_server_addr() = '127.0.0.1'::inet
 AND current_setting('port') = '55432'
 AND current_user = 'postgres' AND session_user = 'postgres'
 AND (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user)
 AND current_setting('gymforce.test_cluster_marker', true) = '$marker'
 AND (pg_catalog.pg_control_system()).system_identifier::text = '$actualSystemIdentifier'
 AND lower(rtrim(replace(current_setting('data_directory'), E'\\', '/'), '/')) = $directorySql
 THEN 'verified' ELSE 'rejected' END;
ROLLBACK;
"@
$connectionResult = & $Psql -X -w -q -A -t -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 55432 `
    -U postgres -d "dbname=$targetDatabase require_auth=scram-sha-256 connect_timeout=5" -c $identityQuery 2>$null
if ($LASTEXITCODE -ne 0 -or (($connectionResult | Out-String).Trim() -cne 'verified')) {
    throw 'Local connection or server-reported cluster identity validation failed. No password was displayed.'
}

if ($CheckPgpassOnly) {
    Write-Output 'pgpass and cluster identity preflight passed (password not displayed).'
} else {
    [pscustomobject]@{
        Marker = $marker
        SystemIdentifier = $actualSystemIdentifier
        DataDirectory = $canonicalDataDirectory
    }
}
