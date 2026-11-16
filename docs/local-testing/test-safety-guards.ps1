$ErrorActionPreference = 'Stop'

# Read-only tests of the existing migrated cluster. Never run migrations or
# cleanup, create fixtures, change ownership, or grant/revoke memberships.
$Psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$Identity = & (Join-Path $PSScriptRoot 'preflight.ps1')
if ($Identity.Marker -cne 'f497fabb-a12f-4068-b745-8b0729279276' -or
    $Identity.SystemIdentifier -cne '7704603813616068820' -or
    $Identity.DataDirectory -ine 'C:\Users\Banco-Sual\AppData\Local\GYMFORCE-PG18-TEST\data') {
    throw 'Identity differs from the approved GYMFORCE cluster. Stop.'
}
$Connection = 'dbname=gymforce_pg18_test require_auth=scram-sha-256 connect_timeout=5'
$Common = @('-X', '-w', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1',
    '-h', '127.0.0.1', '-p', '55432', '-U', 'postgres', '-d', $Connection)
$IdentityArgs = @('-v', "expected_cluster_marker=$($Identity.Marker)",
    '-v', "expected_system_identifier=$($Identity.SystemIdentifier)",
    '-v', "expected_data_directory=$($Identity.DataDirectory)")

function Invoke-Psql([string[]]$Arguments, [string]$InputSql) {
    $previous = $ErrorActionPreference
    try {
        # Capture native stderr without PowerShell 5.1 terminating on it.
        $ErrorActionPreference = 'Continue'
        if ($InputSql) {
            $output = $InputSql | & $Psql @Arguments 2>&1
        }
        else { $output = & $Psql @Arguments 2>&1 }
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    [pscustomobject]@{ Code = $code; Text = ($output | Out-String).Trim() }
}

function Assert-Rejected([string]$Name, [string[]]$Arguments,
                         [int]$ExpectedCode, [string]$ExpectedMessage) {
    $sqlIndex = [Array]::IndexOf($Arguments, '-c')
    if ($sqlIndex -ge 0 -and $Arguments[$sqlIndex + 1].Contains("`n")) {
        $sqlInput = $Arguments[$sqlIndex + 1]
        $Arguments[$sqlIndex] = '-f'
        $Arguments[$sqlIndex + 1] = '-'
        $result = Invoke-Psql $Arguments $sqlInput
    }
    else { $result = Invoke-Psql $Arguments }
    if ($result.Code -ne $ExpectedCode -or
        -not $result.Text.Contains($ExpectedMessage)) {
        throw "Unexpected safety-test result: $Name; exit=$($result.Code). Stop."
    }
    Write-Output "PASS: $Name; exit=$($result.Code)"
}

function Get-StateFingerprint {
    # No password hashes, credentials, or member rows are printed. Only
    # database-computed digests are returned for before/after comparison.
    $tables = Invoke-Psql ($Common + @('-c', @'
BEGIN READ ONLY;
SELECT n.nspname||'.'||c.relname||'|'||c.relkind::text FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('private','public','auth') AND c.relkind IN ('r','p','S')
ORDER BY 1;
ROLLBACK;
'@))
    if ($tables.Code -ne 0) { throw 'Cannot enumerate fingerprint scope.' }
    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in ($tables.Text -split '\r?\n')) {
        if ($entry -notmatch '^((private|public|auth)\.[a-z_][a-z_0-9]*)\|([rpS])$') {
            throw 'Unexpected fingerprint object name.'
        }
        $name = $Matches[1]
        if ($Matches[3] -eq 'S') {
            # Sequences expose fields but have no composite row type.
            $parts.Add("SELECT '$name' AS scope, md5(jsonb_build_array(last_value,log_cnt,is_called)::text) AS digest FROM $name")
        }
        else {
            $parts.Add("SELECT '$name' AS scope, md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'')) AS digest FROM $name t")
        }
    }
    $catalog = @'
SELECT 'catalog', md5(coalesce(string_agg(item,'|' ORDER BY item),''))
FROM (
 SELECT concat_ws('|','relation',n.nspname,c.relname,c.relkind,c.relowner,c.relacl::text,c.relrowsecurity,c.relforcerowsecurity) AS item
 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('private','public','api','auth','extensions')
 UNION ALL
 SELECT concat_ws('|','constraint',c.oid,c.conrelid,pg_get_constraintdef(c.oid),c.convalidated) FROM pg_catalog.pg_constraint c JOIN pg_catalog.pg_namespace n ON n.oid=c.connamespace WHERE n.nspname IN ('private','public','api','auth','extensions')
 UNION ALL
 SELECT concat_ws('|','function',p.oid,p.proowner,p.proacl::text,pg_get_functiondef(p.oid)) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('private','api','auth','extensions') AND p.prokind='f'
 UNION ALL
 SELECT concat_ws('|','schema',n.oid,n.nspowner,n.nspacl::text) FROM pg_catalog.pg_namespace n WHERE n.nspname IN ('private','public','api','auth','extensions')
 UNION ALL
 SELECT concat_ws('|','role',oid,rolname,rolsuper,rolinherit,rolcreaterole,rolcreatedb,rolcanlogin,rolreplication,rolbypassrls,rolconfig::text) FROM pg_catalog.pg_roles
 UNION ALL
 SELECT 'membership|'||to_jsonb(m)::text FROM pg_catalog.pg_auth_members m
 UNION ALL
 SELECT concat_ws('|','column',a.attrelid,a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attacl::text,a.attidentity,a.attgenerated,a.attisdropped) FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_class c ON c.oid=a.attrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('private','public','api','auth','extensions') AND a.attnum>0
 UNION ALL
 SELECT concat_ws('|','index',i.indexrelid,pg_get_indexdef(i.indexrelid),i.indisvalid,i.indisready) FROM pg_catalog.pg_index i JOIN pg_catalog.pg_class c ON c.oid=i.indrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('private','public','api','auth','extensions')
 UNION ALL
 SELECT concat_ws('|','trigger',t.oid,pg_get_triggerdef(t.oid),t.tgenabled) FROM pg_catalog.pg_trigger t JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('private','public','api','auth','extensions')
 UNION ALL
 SELECT 'default_acl|'||to_jsonb(d)::text FROM pg_catalog.pg_default_acl d
 UNION ALL
 SELECT 'policy|'||to_jsonb(p)::text FROM pg_catalog.pg_policy p JOIN pg_catalog.pg_class c ON c.oid=p.polrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('private','public','api','auth','extensions')
) s
'@
    $parts.Add($catalog)
    # Feed the larger snapshot query on stdin to avoid Windows native-command
    # argument length/quoting limits. All SQL input here is ASCII source text.
    $snapshotSql = 'BEGIN READ ONLY; SELECT * FROM (' +
        ($parts -join ' UNION ALL ') + ') fingerprints ORDER BY 1; ROLLBACK;'
    $result = Invoke-Psql ($Common + @('-f','-')) $snapshotSql
    if ($result.Code -ne 0) {
        # Only an SQL error's first line, never query results or row contents.
        $diagnostic = [regex]::Match($result.Text, '(?im)ERROR:[^\r\n]*').Value
        throw ("Cannot compute read-only state fingerprint; exit=$($result.Code). " + $diagnostic)
    }
    return $result.Text
}

$before = Get-StateFingerprint
$bootstrap = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'bootstrap.sql'))
$guard = [regex]::Match($bootstrap, '(?s)DO \$bootstrap_guard\$.*?\$bootstrap_guard\$;')
if (-not $guard.Success) { throw 'Cannot locate the existing bootstrap target guard.' }
$runner = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'apply-migrations.ps1'))
$migrationGuard = [regex]::Match($runner, '(?s)DO \$cluster_guard\$.*?\$cluster_guard\$;')
if (-not $migrationGuard.Success) { throw 'Cannot locate existing migration guard.' }
$directorySql = "'" + $Identity.DataDirectory.Replace('\','/').TrimEnd('/').ToLowerInvariant().Replace("'","''") + "'"
$sqlGuard = $migrationGuard.Value.Replace('__EXPECTED_MARKER__',$Identity.Marker).
    Replace('__EXPECTED_SYSID__',$Identity.SystemIdentifier).
    Replace('__EXPECTED_DATA_DIRECTORY__',$directorySql)

# Alter only the expected values in in-memory guard copies. The live server's
# identity, configuration, SQL files, and current database are never changed.
Assert-Rejected 'wrong expected database (guard simulation)' ($Common + @('-c',
    ('BEGIN READ ONLY; ' + $sqlGuard.Replace("<> 'gymforce_pg18_test'", "<> 'gymforce_wrong_target'")))) 3 'Migration cluster identity check failed'
Assert-Rejected 'wrong expected port (guard simulation)' ($Common + @('-c',
    ('BEGIN READ ONLY; ' + $sqlGuard.Replace("<> '55432'", "<> '55433'")))) 3 'Migration cluster identity check failed'
Assert-Rejected 'wrong execution role (SET LOCAL only)' ($Common + @('-c',
    ('BEGIN READ ONLY; SET LOCAL ROLE service_role; ' + $guard.Value))) 3 'Run bootstrap as the local PostgreSQL superuser postgres'
Assert-Rejected 'bootstrap refuses migrated database' ($Common + $IdentityArgs +
    @('-c','BEGIN READ ONLY;','-f',(Join-Path $PSScriptRoot 'bootstrap.sql'))) 3 'Database is not fresh'

$absent = Invoke-Psql ($Common + @('-c', "BEGIN READ ONLY; SELECT count(*) FROM pg_catalog.pg_database WHERE datname='gymforce_guard_absent_test'; ROLLBACK;"))
if ($absent.Code -ne 0 -or $absent.Text -cne '0') {
    throw 'Negative connection database is not confirmed absent. Stop.'
}
$wrongDatabase = 'dbname=gymforce_guard_absent_test require_auth=scram-sha-256 connect_timeout=5'
Assert-Rejected 'nonexistent database connection' @('-X','-w','-h','127.0.0.1',
    '-p','55432','-U','postgres','-d',$wrongDatabase,'-c','SELECT 1;') 2 'does not exist'

# Hold a bound, non-listening loopback socket so another server cannot claim
# the deliberately wrong port. Never try the unrelated default server.
$socket = [Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork,
    [Net.Sockets.SocketType]::Stream,[Net.Sockets.ProtocolType]::Tcp)
try {
    $socket.ExclusiveAddressUse = $true
    $socket.Bind([Net.IPEndPoint]::new([Net.IPAddress]::Loopback,0))
    $closedPort = $socket.LocalEndPoint.Port.ToString()
    Assert-Rejected 'closed reserved loopback endpoint' @('-X','-w','-h','127.0.0.1',
        '-p',$closedPort,'-U','postgres','-d',$Connection,'-c','SELECT 1;') 2 'Connection refused'
}
finally { $socket.Dispose() }

$after = Get-StateFingerprint
if ($after -cne $before) { throw 'Persistent state fingerprint changed. Stop.' }
$null = & (Join-Path $PSScriptRoot 'preflight.ps1')
Write-Output 'PASS: six negative cases, unchanged scoped catalog/data/sequence/role fingerprints, final identity preflight.'
