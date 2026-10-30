
$ErrorActionPreference = "Stop"

$Psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$Database = "gym_full_migration_test"
$HostName = "localhost"
$Port = "5432"

if (-not (Test-Path $Psql)) {
    throw "PostgreSQL psql.exe was not found."
}

# Request the local PostgreSQL password once.
$SecurePassword = Read-Host "Enter the local postgres password" -AsSecureString
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)

try {
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)

    $TestDirectory = Join-Path $env:TEMP "gym-pin-rate-limit-test"
    New-Item -ItemType Directory -Force -Path $TestDirectory | Out-Null

    # Helper: run a local SQL command and fail on errors.
    function Invoke-LocalSql {
        param([string]$Sql)

        $Output = & $Psql -X -q -A -t `
            -v ON_ERROR_STOP=1 `
            -U postgres -h $HostName -p $Port -d $Database `
            -c $Sql 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "PostgreSQL command failed: $($Output -join "`n")"
        }

        return ($Output -join "`n").Trim()
    }

    Write-Host "`n=== TEST 1: Prepare isolated rate-limit table ===" -ForegroundColor Cyan

    # This deletes only local rate-limiter test events.
    Invoke-LocalSql "TRUNCATE TABLE private.pin_enrollment_global_rate_limit_events RESTART IDENTITY;"

    $InitialCount = Invoke-LocalSql "SELECT COUNT(*) FROM private.pin_enrollment_global_rate_limit_events;"

    if ([int]$InitialCount -ne 0) {
        throw "The rate-limit table is not empty. Stopping test."
    }

    Write-Host "Table cleared. Starting 40 concurrent requests..." -ForegroundColor Green

    Write-Host "`n=== TEST 2: Forty concurrent requests ===" -ForegroundColor Cyan

    $Jobs = @()

    for ($i = 1; $i -le 40; $i++) {
        $Jobs += Start-Job -ArgumentList $Psql, $Database, $HostName, $Port -ScriptBlock {
param($PsqlPath, $Db, $DbHost, $DbPort)

$Output = & $PsqlPath -X -q -A -t `
    -v ON_ERROR_STOP=1 `
    -U postgres -h $DbHost -p $DbPort -d $Db `
                -c "SET ROLE service_role; SELECT api.reserve_pin_enrollment_request();" 2>&1

            [PSCustomObject]@{
                ExitCode = $LASTEXITCODE
                Output   = ($Output -join "`n").Trim()
            }
        }
    }

    $JobResults = @()
    foreach ($Job in $Jobs) {
        $JobResults += Receive-Job -Job $Job -Wait
    }

    $Jobs | Remove-Job -Force

    $Allowed = 0
    $Rejected = 0
    $Failed = 0
    $Invalid = 0

    foreach ($Result in $JobResults) {
        if ($Result.ExitCode -ne 0) {
            $Failed++
            Write-Host "Database error: $($Result.Output)" -ForegroundColor Red
            continue
        }

        try {
            $Json = $Result.Output | ConvertFrom-Json -ErrorAction Stop

            if ($Json.allowed -eq $true -and $null -ne $Json.remaining) {
                $Allowed++
            }
            elseif ($Json.allowed -eq $false -and $null -ne $Json.retryAfterSeconds) {
                $Rejected++
            }
            else {
                $Invalid++
                Write-Host "Unexpected response: $($Result.Output)" -ForegroundColor Yellow
            }
        }
        catch {
            $Invalid++
            Write-Host "Invalid JSON response: $($Result.Output)" -ForegroundColor Yellow
        }
    }

    $EventCount = Invoke-LocalSql "SELECT COUNT(*) FROM private.pin_enrollment_global_rate_limit_events WHERE requested_at > clock_timestamp() - INTERVAL '60 seconds';"

    Write-Host "`nConcurrency results:" -ForegroundColor Cyan
    Write-Host "Allowed:  $Allowed"
    Write-Host "Rejected: $Rejected"
    Write-Host "Failed:   $Failed"
    Write-Host "Invalid:  $Invalid"
    Write-Host "Recorded accepted events: $EventCount"

    $ConcurrencyPassed = (
        $Allowed -eq 30 -and
        $Rejected -eq 10 -and
        $Failed -eq 0 -and
        $Invalid -eq 0 -and
        [int]$EventCount -eq 30
    )

    if ($ConcurrencyPassed) {
        Write-Host "PASS: Exactly 30 allowed, 10 rejected, 0 failed." -ForegroundColor Green
    }
    else {
        Write-Host "FAIL: Concurrency results did not match expectations." -ForegroundColor Red
    }

    Write-Host "`n=== TEST 3: Rolling 60-second window ===" -ForegroundColor Cyan
    Write-Host "Waiting 61 seconds for the accepted requests to expire..." -ForegroundColor Yellow

    Start-Sleep -Seconds 61

    $ResetResponse = Invoke-LocalSql "SET ROLE service_role; SELECT api.reserve_pin_enrollment_request();"
    $ResetJson = $ResetResponse | ConvertFrom-Json

    Write-Host "Response after 61 seconds: $ResetResponse"

    $RollingWindowPassed = (
        $ResetJson.allowed -eq $true -and
        $ResetJson.remaining -eq 29
    )

    if ($RollingWindowPassed) {
        Write-Host "PASS: A new request was accepted after the rolling window." -ForegroundColor Green
    }
    else {
        Write-Host "FAIL: Rolling-window reset did not match expectations." -ForegroundColor Red
    }

    Write-Host "`n=== TEST 4: 24-hour event cleanup ===" -ForegroundColor Cyan

    Invoke-LocalSql "INSERT INTO private.pin_enrollment_global_rate_limit_events (requested_at) VALUES (clock_timestamp() - INTERVAL '25 hours');"

    $OldBefore = Invoke-LocalSql "SELECT COUNT(*) FROM private.pin_enrollment_global_rate_limit_events WHERE requested_at <= clock_timestamp() - INTERVAL '24 hours';"

    # Invoking the function triggers its cleanup logic.
    $CleanupResponse = Invoke-LocalSql "SET ROLE service_role; SELECT api.reserve_pin_enrollment_request();"

    $OldAfter = Invoke-LocalSql "SELECT COUNT(*) FROM private.pin_enrollment_global_rate_limit_events WHERE requested_at <= clock_timestamp() - INTERVAL '24 hours';"

    Write-Host "Old events before cleanup: $OldBefore"
    Write-Host "Old events after cleanup:  $OldAfter"
    Write-Host "Cleanup-trigger response: $CleanupResponse"

    $CleanupPassed = ([int]$OldBefore -ge 1 -and [int]$OldAfter -eq 0)

    if ($CleanupPassed) {
        Write-Host "PASS: Events older than 24 hours were removed." -ForegroundColor Green
    }
    else {
        Write-Host "FAIL: The 24-hour cleanup check did not pass." -ForegroundColor Red
    }

    Write-Host "`n=== FINAL RESULTS ===" -ForegroundColor Cyan

    [PSCustomObject]@{
        Test                   = "40-request concurrency"
        Result                 = if ($ConcurrencyPassed) { "PASS" } else { "FAIL" }
    }

    [PSCustomObject]@{
        Test                   = "Rolling 60-second window"
        Result                 = if ($RollingWindowPassed) { "PASS" } else { "FAIL" }
    }

    [PSCustomObject]@{
        Test                   = "24-hour cleanup"
        Result                 = if ($CleanupPassed) { "PASS" } else { "FAIL" }
    }

    if (-not ($ConcurrencyPassed -and $RollingWindowPassed -and $CleanupPassed)) {
        throw "One or more rate-limiter tests failed. Review the output above."
    }

    Write-Host "`nALL RATE-LIMITER TESTS PASSED." -ForegroundColor Green
}
finally {
    $env:PGPASSWORD = $null

    if ($BSTR -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
}
