param(
    [string] $PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [switch] $TestLegacyAuditRefusal
)
$ErrorActionPreference = 'Stop'

# This runner creates a NEW synthetic cluster under the ignored workspace cache.
# It never connects to the preserved native harness or a hosted database.
# No existing directory is accepted, no database is dropped, no cleanup resets
# sequences. The stopped cluster/logs are retained for diagnosis.
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$cacheRoot = Join-Path $repoRoot '.cache'
$runId = [guid]::NewGuid().ToString('N')
$runRoot = Join-Path $cacheRoot "security-test-$runId"
$dataRoot = Join-Path $runRoot 'data'
$passwordPath = Join-Path $runRoot 'bootstrap-password'
$passfilePath = Join-Path $runRoot 'pgpass.conf'
$database = 'gymforce_batch1_synthetic'
$started = $false
$testExit = 1
$refusalVerified = $false
foreach ($name in @('initdb.exe', 'pg_ctl.exe', 'psql.exe', 'createdb.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PostgresBin $name))) { throw "Required installed PostgreSQL utility missing: $name" }
}
if (Get-ChildItem Env: | Where-Object Name -like 'PG*') { throw 'Refusing inherited PG environment overrides.' }
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.gitignore'))) { throw 'Repository root not found.' }
$ignored = & git -C $repoRoot check-ignore -- .cache/security-test-probe
if ($LASTEXITCODE -ne 0) { throw 'Test cache is not ignored by Git.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Fresh run directory unexpectedly exists.' }
if ((Test-Path -LiteralPath $cacheRoot) -and ((Get-Item -LiteralPath $cacheRoot).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Refusing a redirected workspace cache.'
}
New-Item -ItemType Directory -Path $runRoot | Out-Null

# Protect synthetic credentials and server files from other ordinary users.
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetOwner($currentIdentity.User)
$acl.SetAccessRuleProtection($true, $false)
foreach ($principal in @($currentIdentity.User.Value, 'S-1-5-18', 'S-1-5-32-544')) {
    $rule = New-Object Security.AccessControl.FileSystemAccessRule(
        (New-Object Security.Principal.SecurityIdentifier($principal)),
        'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
    )
    $acl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $runRoot -AclObject $acl
$password = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
[IO.File]::WriteAllText($passwordPath, $password, [Text.UTF8Encoding]::new($false))

# A dynamic loopback port avoids the preserved test cluster's ports. The
# subsequent pg_ctl start fails closed if another process wins the port race.
$portReservation = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$portReservation.Start()
$port = $portReservation.LocalEndpoint.Port
$portReservation.Stop()
$psql = Join-Path $PostgresBin 'psql.exe'
$connection = "host=127.0.0.1 port=$port dbname=$database user=postgres passfile='$($passfilePath.Replace('\', '/'))' require_auth=scram-sha-256 connect_timeout=5"

function Invoke-NativeTool([string] $Tool, [string[]] $Arguments) {
    # Windows PowerShell wraps native stderr notices in ErrorRecords. Native
    # exit status, not NOTICE/WARNING text, determines whether the tool failed.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $nativeOutput = @(& $Tool @Arguments 2>&1)
        $nativeExit = $LASTEXITCODE
        return [pscustomobject]@{ Output = $nativeOutput; ExitCode = $nativeExit }
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Invoke-TestSqlFile([string] $File, [string] $ExpectedSqlRefusal = '') {
    # Guard and file run on the SAME connection. Never bypass this guard to
    # reuse another database; a new cluster is the only supported target.
    $expectedDirectory = $dataRoot.Replace('\', '/').Replace("'", "''")
    $guard = @"
DO `$guard`$ BEGIN
 IF current_database() <> '$database' OR session_user <> 'postgres'
 OR current_user <> 'postgres' OR inet_server_addr() <> '127.0.0.1'::inet
 OR current_setting('port') <> '$port'
 OR current_setting('gymforce.synthetic_run_id', true) IS DISTINCT FROM '$runId'
 OR lower(replace(current_setting('data_directory'), chr(92), '/')) <> lower('$expectedDirectory')
 THEN RAISE EXCEPTION 'Synthetic database identity mismatch'; END IF;
END `$guard`$;
"@
    $native = Invoke-NativeTool $psql @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-d', $connection, '-c', $guard, '-f', $File)
    $output = $native.Output
    $nativeExit = $native.ExitCode
    $logName = [IO.Path]::GetFileName($File) + '.log'
    $output | Set-Content -LiteralPath (Join-Path $runRoot $logName)
    if ($ExpectedSqlRefusal) {
        if ($nativeExit -ne 3 -or -not (($output | Out-String).Contains($ExpectedSqlRefusal))) {
            throw 'Expected migration refusal was not observed; no success may be inferred.'
        }
        Write-Output "PASS: expected transactional refusal of $([IO.Path]::GetFileName($File))."
        return
    }
    if ($nativeExit -ne 0) {
        # Fixtures are synthetic. Still limit console output to diagnostics.
        $output | Select-Object -Last 12 | ForEach-Object { Write-Output $_ }
        throw "SQL file failed (exit $nativeExit): $([IO.Path]::GetFileName($File))"
    }
    Write-Output "PASS: $([IO.Path]::GetFileName($File))"
}

try {
    $init = Invoke-NativeTool (Join-Path $PostgresBin 'initdb.exe') @('-D', $dataRoot, '-U', 'postgres', '--encoding=UTF8', '--locale=C', '--auth-host=scram-sha-256', '--auth-local=scram-sha-256', "--pwfile=$passwordPath")
    $init.Output | Set-Content -LiteralPath (Join-Path $runRoot 'initdb.log')
    if ($init.ExitCode -ne 0) { throw 'Synthetic initdb failed; see retained directory.' }
    [IO.File]::WriteAllText($passfilePath, "127.0.0.1:$port`:*:postgres:$password", [Text.UTF8Encoding]::new($false))
    Remove-Item -LiteralPath $passwordPath
    $password = $null
    Add-Content -LiteralPath (Join-Path $dataRoot 'postgresql.conf') -Value "`ngymforce.synthetic_run_id = '$runId'`ntimezone = 'UTC'"
    # Do not capture pg_ctl startup with a PowerShell pipeline: on Windows its
    # background server can retain pipe handles and prevent EOF after readiness.
    # File redirection plus a bounded process wait avoids that inherited pipe.
    $startArguments = '-D "' + $dataRoot + '" -l "' + (Join-Path $runRoot 'server.log') + '" -o "-h 127.0.0.1 -p ' + $port + '" -w -t 30 start'
    $startProcess = Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') -ArgumentList $startArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot 'start.log') -RedirectStandardError (Join-Path $runRoot 'start-error.log')
    $null = $startProcess.Handle # Retain handle so Windows PowerShell can read ExitCode after exit.
    if (-not $startProcess.WaitForExit(45000)) { throw 'Synthetic startup process exceeded its timeout.' }
    $startProcess.Refresh()
    if ($startProcess.ExitCode -ne 0) { throw 'Synthetic PostgreSQL startup failed.' }
    $started = $true
    $maintenanceConnection = $connection.Replace("dbname=$database", 'dbname=postgres')
    $created = Invoke-NativeTool (Join-Path $PostgresBin 'createdb.exe') @('-w', "--maintenance-db=$maintenanceConnection", $database)
    if ($created.ExitCode -ne 0) { throw 'Synthetic database creation failed.' }
    Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/synthetic_bootstrap.sql')
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'supabase/migrations') -Filter '*.sql' | Sort-Object Name) {
        if ($file.Name -eq '20261110103000_audit_timezone.sql') {
            if ($TestLegacyAuditRefusal) {
                Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/audit_timezone_incompatible_seed.sql')
                Invoke-TestSqlFile $file.FullName 'Legacy audit history requires Owner review before UTC normalization'
                Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/audit_timezone_refusal_assertions.sql')
                $refusalVerified = $true
                break
            }
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/audit_timezone_seed.sql')
        }
        Invoke-TestSqlFile $file.FullName
        if ($file.Name -eq '20261110100000_executor_hardening.sql') {
            # Snapshot assertions deliberately describe this phase, not all
            # future schemas. Run before subsequent lifecycle additions.
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/executor_hardening_assertions.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/membership_payment_security_assertions.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/executor_behavior.sql')
            try {
                $env:GYMFORCE_TEST_RUN_ID = $runId
                $env:GYMFORCE_TEST_PSQL = $psql
                $env:GYMFORCE_TEST_CONNECTION = $connection
                $env:GYMFORCE_TEST_DATA_DIRECTORY = $dataRoot
                $races = Invoke-NativeTool (Get-Command node.exe).Source @((Join-Path $repoRoot 'scripts/test-db-concurrency.mjs'))
                $races.Output | Set-Content -LiteralPath (Join-Path $runRoot 'concurrency.log')
                $races.Output | ForEach-Object { Write-Output $_ }
                if ($races.ExitCode -ne 0) { throw 'Synthetic concurrency suite failed.' }
            } finally {
                foreach ($entryName in @('GYMFORCE_TEST_RUN_ID','GYMFORCE_TEST_PSQL','GYMFORCE_TEST_CONNECTION','GYMFORCE_TEST_DATA_DIRECTORY')) {
                    Remove-Item -LiteralPath "Env:$entryName" -ErrorAction SilentlyContinue
                }
            }
        }
        if ($file.Name -eq '20261110103000_audit_timezone.sql') {
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/audit_timezone_behavior.sql')
        }
        $phaseSuites = @{
            '20261110110000_membership_lifecycle.sql' = 'membership_lifecycle_behavior.sql'
            '20261110120000_owner_reporting.sql' = 'owner_reporting_behavior.sql'
            '20261110130000_pin_recovery.sql' = 'pin_recovery_behavior.sql'
            '20261110140000_walkin_operations.sql' = 'walkin_behavior.sql'
            '20261110150000_member_checkin.sql' = 'member_checkin_behavior.sql'
            '20261110153000_owner_attendance.sql' = 'owner_attendance_behavior.sql'
            '20261110160000_receipt_review_corrections.sql' = 'receipt_review_behavior.sql'
            '20261110170000_cash_operations.sql' = 'cash_operations_behavior.sql'
            '20261110180000_provisional_claims.sql' = 'provisional_claims_behavior.sql'
            '20261110190000_receipt_allocation_review.sql' = 'receipt_allocation_behavior.sql'
            '20261110200000_operational_reports.sql' = 'operational_reports_behavior.sql'
        }
        if ($phaseSuites.ContainsKey($file.Name)) {
            Invoke-TestSqlFile (Join-Path $repoRoot ('supabase/tests/' + $phaseSuites[$file.Name]))
        }
    }
    if (-not $refusalVerified) {
        try {
            $env:GYMFORCE_TEST_RUN_ID = $runId
            $env:GYMFORCE_TEST_PSQL = $psql
            $env:GYMFORCE_TEST_CONNECTION = $connection
            $env:GYMFORCE_TEST_DATA_DIRECTORY = $dataRoot
            $operationRaces = Invoke-NativeTool (Get-Command node.exe).Source @((Join-Path $repoRoot 'scripts/test-db-concurrency.mjs'), '--operations')
            $operationRaces.Output | Set-Content -LiteralPath (Join-Path $runRoot 'operation-concurrency.log')
            $operationRaces.Output | ForEach-Object { Write-Output $_ }
            if ($operationRaces.ExitCode -ne 0) { throw 'Synthetic operation concurrency suite failed.' }
        } finally {
            foreach ($entryName in @('GYMFORCE_TEST_RUN_ID','GYMFORCE_TEST_PSQL','GYMFORCE_TEST_CONNECTION','GYMFORCE_TEST_DATA_DIRECTORY')) {
                Remove-Item -LiteralPath "Env:$entryName" -ErrorAction SilentlyContinue
            }
        }
        Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/final_security_assertions.sql')
    }
    $testExit = 0
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
} finally {
    if ($started -or (Test-Path -LiteralPath (Join-Path $dataRoot 'postmaster.pid'))) {
        $stopped = Invoke-NativeTool (Join-Path $PostgresBin 'pg_ctl.exe') @('-D', $dataRoot, '-m', 'fast', '-w', 'stop')
        if ($stopped.ExitCode -ne 0) { $testExit = 1; Write-Output 'FAIL: synthetic PostgreSQL shutdown failed.' }
        else { Write-Output 'PASS: synthetic PostgreSQL stopped.' }
    }
    # Delete only the two known synthetic credential files, never recursively.
    foreach ($credentialFile in @($passwordPath, $passfilePath)) {
        if (Test-Path -LiteralPath $credentialFile) { Remove-Item -LiteralPath $credentialFile }
    }
    Write-Output "Synthetic logs retained under .cache/security-test-$runId (no production access)."
}
exit $testExit
