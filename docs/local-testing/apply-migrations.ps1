$ErrorActionPreference = 'Stop'

# Applies only the pinned migration chain to the disposable loopback database.
# Never resume after a failure: discard and recreate the database first.
$PgBin = 'C:\Program Files\PostgreSQL\18\bin'
$Psql = Join-Path $PgBin 'psql.exe'
$HostAddress = '127.0.0.1'
$Port = 55432
$Database = 'gymforce_pg18_test'
$ConnectionDatabase = "dbname=$Database require_auth=scram-sha-256 connect_timeout=5"
$DbUser = 'postgres'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$MigrationDir = Join-Path $ProjectRoot 'supabase\migrations'
$LogDir = Join-Path $env:LOCALAPPDATA 'GYMFORCE-PG18-TEST'
$LogPath = Join-Path $LogDir 'migration-run.log'
$IdentityPreflight = Join-Path $PSScriptRoot 'preflight.ps1'

$ExpectedMigrations = @(
    '20261028061728_initial_schema.sql'
    '20261028062516_membership_core.sql'
    '20261028062602_payment_ledger.sql'
    '20261028062706_walkin_attendance.sql'
    '20261028062757_owner_security.sql'
    '20261028062853_member_pin_security.sql'
    '20261028062935_cash_reconciliation.sql'
    '20261028063027_audit_integrity.sql'
    '20261028063404_integrity_fixes.sql'
    '20261028063446_membership_overlap_guard.sql'
    '20261028063638_payment_integrity_guard.sql'
    '20261028064100_database_security_foundation.sql'
    '20261029100000_owner_authorization_rpc.sql'
    '20261030120000_audit_chain_enforcement.sql'
    '20261030130000_owner_register_member.sql'
    '20261030140000_owner_create_pin_enrollment_token.sql'
    '20261030150000_member_pin_enrollment.sql'
    '20261030160000_global_pin_enrollment_rate_limit.sql'
    '20261030170000_rolling_pin_enrollment_rate_limit.sql'
    '20261030180000_owner_list_members.sql'
    '20261103080000_owner_membership_plans.sql'
    '20261103100000_owner_create_membership_purchase.sql'
    '20261103110000_owner_list_membership_purchases.sql'
    '20261103120000_owner_membership_payments.sql'
)

if (-not (Test-Path -LiteralPath $Psql -PathType Leaf)) {
    throw "psql was not found at the pinned PostgreSQL 18 path: $Psql"
}
if (-not (Test-Path -LiteralPath $IdentityPreflight -PathType Leaf)) {
    throw "Identity preflight was not found: $IdentityPreflight"
}
$Identity = & $IdentityPreflight
if ($null -eq $Identity -or
    [string]::IsNullOrWhiteSpace($Identity.Marker) -or
    [string]::IsNullOrWhiteSpace($Identity.SystemIdentifier) -or
    [string]::IsNullOrWhiteSpace($Identity.DataDirectory)) {
    throw 'Identity preflight failed; no migrations were applied.'
}
$ClusterMarker = [string]$Identity.Marker
$SystemIdentifier = [string]$Identity.SystemIdentifier
$DataDirectory = [string]$Identity.DataDirectory

$ActualMigrations = @(
    Get-ChildItem -LiteralPath $MigrationDir -File -Filter '*.sql' |
        Sort-Object -Property Name |
        ForEach-Object Name
)
if (($ActualMigrations -join "`n") -cne ($ExpectedMigrations -join "`n")) {
    throw 'Migration inventory differs from the pinned 24-file chain; review before applying anything.'
}

$Ready = & (Join-Path $PgBin 'pg_isready.exe') -h $HostAddress -p $Port -d $Database -U $DbUser 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Disposable database is not ready at the required loopback endpoint: $Ready"
}

$ConnectionCheck = & $Psql -X -A -t -v ON_ERROR_STOP=1 `
    -w -h $HostAddress -p $Port -U $DbUser -d $ConnectionDatabase `
    -c "SELECT current_database() || '|' || pg_catalog.host(inet_server_addr()) || '|' || current_setting('port') || '|' || coalesce(current_setting('gymforce.test_cluster_marker', true), '') || '|' || (pg_catalog.pg_control_system()).system_identifier::text || '|' || lower(rtrim(replace(current_setting('data_directory'), E'\\', '/'), '/'));" 2>&1
$ExpectedDataDirectory = $DataDirectory.Replace('\', '/').TrimEnd('/').ToLowerInvariant()
$ExpectedConnection = "$Database|$HostAddress|$Port|$ClusterMarker|$SystemIdentifier|$ExpectedDataDirectory"
if ($LASTEXITCODE -ne 0 -or (($ConnectionCheck | Out-String).Trim() -cne $ExpectedConnection)) {
    throw "Connection or cluster-marker guard failed; expected $ExpectedConnection. No migrations were applied."
}

$DataDirectorySql = "'" + $ExpectedDataDirectory.Replace("'", "''") + "'"
$ClusterGuardSqlTemplate = @'
DO $cluster_guard$
BEGIN
    IF current_database() <> 'gymforce_pg18_test'
       OR current_setting('port') <> '55432'
       OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
       OR current_user <> 'postgres' OR session_user <> 'postgres'
       OR NOT (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user)
       OR current_setting('gymforce.test_cluster_marker', true) IS DISTINCT FROM '__EXPECTED_MARKER__'
       OR (pg_catalog.pg_control_system()).system_identifier::text IS DISTINCT FROM '__EXPECTED_SYSID__'
       OR lower(rtrim(replace(current_setting('data_directory'), E'\\', '/'), '/')) IS DISTINCT FROM __EXPECTED_DATA_DIRECTORY__ THEN
        RAISE EXCEPTION 'Migration cluster identity check failed';
    END IF;
END;
$cluster_guard$;
'@
$ClusterGuardSql = $ClusterGuardSqlTemplate.Replace('__EXPECTED_MARKER__', $ClusterMarker).
    Replace('__EXPECTED_SYSID__', $SystemIdentifier).
    Replace('__EXPECTED_DATA_DIRECTORY__', $DataDirectorySql)

$BootstrapCheck = & $Psql -X -A -t -v ON_ERROR_STOP=1 `
    -w -h $HostAddress -p $Port -U $DbUser -d $ConnectionDatabase `
    -c "SELECT (to_regclass('auth.users') IS NOT NULL AND to_regprocedure('auth.uid()') IS NOT NULL AND EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') AND EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'service_role'))::text;" 2>&1
if ($LASTEXITCODE -ne 0 -or (($BootstrapCheck | Out-String).Trim() -cne 'true')) {
    throw 'Compatibility bootstrap check failed; no migrations were applied.'
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Set-Content -LiteralPath $LogPath -Value "GYMFORCE migration run started $(Get-Date -Format o); target=$Database@$HostAddress`:$Port" -Encoding utf8

foreach ($MigrationName in $ExpectedMigrations) {
    $MigrationPath = Join-Path $MigrationDir $MigrationName
    Add-Content -LiteralPath $LogPath -Value "START $MigrationName" -Encoding utf8
    Write-Output "Applying $MigrationName"

    # Windows PowerShell 5.1 wraps native stderr (including harmless NOTICEs)
    # as error records. Preserve it in the log without terminating the pipe
    # before psql returns. ON_ERROR_STOP and its exit status remain mandatory.
    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Psql -X -w -v ON_ERROR_STOP=1 -h $HostAddress -p $Port `
            -U $DbUser -d $ConnectionDatabase -c $ClusterGuardSql -f $MigrationPath 2>&1 |
            ForEach-Object {
                # Tee-Object in Windows PowerShell 5.1 appends UTF-16 to our
                # UTF-8 log. Use one explicit encoding for every log write.
                $LogLine = $_.ToString()
                Add-Content -LiteralPath $LogPath -Value $LogLine -Encoding utf8 -ErrorAction Stop
                Write-Output $LogLine
            }
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($ExitCode -ne 0) {
        $Failure = "FAILED $MigrationName exit_code=$ExitCode. Stop here; do not skip or resume. Discard and recreate the disposable database before another run."
        Add-Content -LiteralPath $LogPath -Value $Failure -Encoding utf8
        throw $Failure
    }

    Add-Content -LiteralPath $LogPath -Value "PASS $MigrationName" -Encoding utf8
}

Add-Content -LiteralPath $LogPath -Value 'COMPLETE all 24 migrations applied in pinned filename order.' -Encoding utf8
Write-Output "All 24 migrations completed. Log: $LogPath"
