param(
    [string] $PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [switch] $TestLegacyAuditRefusal,
    [switch] $RecoveryAudit,
    [switch] $CustomerCompatibility,
    [ValidateSet('AfterCredential','BeforeInitdb','InitdbFailure','AfterInitdb','AfterStart')]
    [string] $FaultPoint
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
$actorBootstrapPath = Join-Path $runRoot 'recovery-actor-bootstrap.sql'
$database = 'gymforce_batch1_synthetic'
$started = $false
$testExit = 1
$refusalVerified = $false
$adminUser = if ($CustomerCompatibility) { 'gf_provider_admin' } else { 'postgres' }
if ($CustomerCompatibility) {
    $RecoveryAudit = $true
    $version = & (Join-Path $PostgresBin 'postgres.exe') --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch 'PostgreSQL\) 17\.') { throw 'Customer compatibility requires PG17.' }
    $compatibilityRoot = Join-Path $repoRoot 'supabase/recovery/compatibility/synthetic'
    $compatibilityManifestPath = Join-Path $compatibilityRoot 'manifest.json'
    $compatibilityManifest = Get-Content -Raw -LiteralPath $compatibilityManifestPath | ConvertFrom-Json
    if ($compatibilityManifest.provider -ne 'gf_provider_admin' -or $compatibilityManifest.productionAuthorization -ne $false -or $compatibilityManifest.records.Count -ne 21) { throw 'Complete synthetic compatibility manifest required.' }
    foreach ($artifact in $compatibilityManifest.records) {
        if ($artifact.file -notmatch '^[a-z0-9_-]+\.sql$' -or (Get-FileHash -LiteralPath (Join-Path $compatibilityRoot $artifact.file) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $artifact.compatibilitySha256) { throw 'Compatibility artifact changed; rebuild and review.' }
    }
}
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
$psql = Join-Path $PostgresBin 'psql.exe'

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
 IF current_database() <> '$database' OR session_user <> '$adminUser'
 OR current_user <> '$adminUser' OR inet_server_addr() <> '127.0.0.1'::inet
 OR current_setting('port') <> '$port'
 OR current_setting('gymforce.synthetic_run_id', true) IS DISTINCT FROM '$runId'
 OR lower(replace(current_setting('data_directory'), chr(92), '/')) <> lower('$expectedDirectory')
 THEN RAISE EXCEPTION 'Synthetic database identity mismatch'; END IF;
END `$guard`$;
"@
    $native = Invoke-NativeTool $psql @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose', '-d', $connection, '-c', $guard, '-f', $File)
    $output = $native.Output
    $nativeExit = $native.ExitCode
    $logName = [IO.Path]::GetFileName($File) + '.log'
    $output | Set-Content -LiteralPath (Join-Path $runRoot $logName)
    if ($ExpectedSqlRefusal) {
        $refusalText = ($output | ForEach-Object { "$_" }) -join "`n"
        if ($nativeExit -ne 3 -or -not $refusalText.Contains($ExpectedSqlRefusal)) {
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

function Invoke-CustomerSqlFile([string] $File, [string] $ExpectedSqlRefusal = '', [switch] $SingleJson) {
    if ([IO.Path]::GetFullPath($File).StartsWith([IO.Path]::GetFullPath($compatibilityRoot)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
        $artifact = $compatibilityManifest.records | Where-Object file -eq ([IO.Path]::GetFileName($File))
        if (-not $artifact -or (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant() -cne $artifact.compatibilitySha256) { throw 'Reviewed compatibility bytes changed during the run.' }
    }
    $customerConnection = $connection.Replace('user=gf_provider_admin ', 'user=postgres ')
    $guard = @"
DO `$guard`$ BEGIN
 IF current_database()<>'$database' OR current_user<>'postgres' OR session_user<>'postgres'
 OR inet_server_addr()<>'127.0.0.1'::inet OR current_setting('port')<>'$port'
 OR current_setting('gymforce.synthetic_run_id',true) IS DISTINCT FROM '$runId'
 OR current_setting('server_version_num')::integer/10000<>17
 OR NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND rolcreaterole AND NOT rolsuper AND NOT rolbypassrls)
 THEN RAISE EXCEPTION 'Actual non-superuser customer connection required'; END IF;
END `$guard`$;
"@
    $clientArgs = @('-X','-w','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-d',$customerConnection,'-c',$guard,'-f',$File)
    if ($SingleJson) { $clientArgs += '-qAt' }
    $native = Invoke-NativeTool $psql $clientArgs
    $native.Output | Set-Content -LiteralPath (Join-Path $runRoot ([IO.Path]::GetFileName($File) + '.log'))
    if ($ExpectedSqlRefusal) {
        if ($native.ExitCode -ne 3 -or -not (($native.Output | ForEach-Object { "$_" }) -join "`n").Contains($ExpectedSqlRefusal)) { throw 'Expected customer refusal not observed.' }
        Write-Output "PASS: customer expected refusal of $([IO.Path]::GetFileName($File))."
    } elseif ($native.ExitCode -ne 0) {
        $native.Output | Select-Object -Last 10 | ForEach-Object { Write-Output $_ }
        throw "Customer SQL failed: $([IO.Path]::GetFileName($File))"
    } else { Write-Output "PASS: actual non-superuser customer $([IO.Path]::GetFileName($File))." }
}

function Get-CompatibilityFile([string] $Name) {
    return Join-Path $repoRoot ('supabase/recovery/compatibility/synthetic/' + $Name)
}

function Assert-CatalogRollback([string] $Before, [string] $After) {
    $prior = (Get-Content -LiteralPath (Join-Path $runRoot "catalog-$Before.json") -Raw | ConvertFrom-Json).objects | ConvertTo-Json -Depth 10 -Compress
    $next = (Get-Content -LiteralPath (Join-Path $runRoot "catalog-$After.json") -Raw | ConvertFrom-Json).objects | ConvertTo-Json -Depth 10 -Compress
    if ($prior -cne $next) { throw 'Compatibility failure/fixture cleanup changed inventoried metadata.' }
}

function Save-LegacyData([string] $Label) {
    # Hash complete synthetic rows inside the isolated database; never export rows.
    $relations = Invoke-NativeTool $psql @('-X','-w','-qAt','-v','ON_ERROR_STOP=1','-d',$connection,'-c',
      "SELECT n.nspname||'.'||c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind IN ('r','p') AND (n.nspname IN ('private','supabase_migrations') OR (n.nspname='public' AND c.relname='gym_settings')) ORDER BY 1")
    if ($relations.ExitCode -ne 0) { throw 'Synthetic relation snapshot failed.' }
    $parts = foreach ($relation in $relations.Output) {
        if ("$relation" -notmatch '^(private|public|supabase_migrations)\.[a-z0-9_]+$') { throw 'Unexpected synthetic relation.' }
        "SELECT '$relation' AS relation, count(*) AS rows, encode(sha256(convert_to(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb)::text,'UTF8')),'hex') AS hash FROM $relation t"
    }
    $sql = 'SELECT jsonb_agg(to_jsonb(s) ORDER BY relation) FROM (' + ($parts -join ' UNION ALL ') + ') s'
    $snapshot = Invoke-NativeTool $psql @('-X','-w','-qAt','-v','ON_ERROR_STOP=1','-d',$connection,'-c',$sql)
    if ($snapshot.ExitCode -ne 0) { throw 'Synthetic data fingerprint failed.' }
    [IO.File]::WriteAllText((Join-Path $runRoot "data-$Label.json"),($snapshot.Output -join ''),[Text.UTF8Encoding]::new($false))
}

function Invoke-LegacyRefusal([string] $File, [string] $Label, [string] $SetupSql, [string] $CleanupSql, [string] $Message) {
    $fixture = Join-Path $runRoot "legacy-$Label.sql"
    [IO.File]::WriteAllText($fixture,"BEGIN;`n$SetupSql`nCOMMIT;",[Text.UTF8Encoding]::new($false))
    Invoke-TestSqlFile $fixture
    try {
        Save-RecoveryCatalog "legacy-before-$Label"
        Save-LegacyData "before-$Label"
        if ($CustomerCompatibility) { Invoke-CustomerSqlFile $File $Message }
        else { Invoke-TestSqlFile $File $Message }
        $refusalLog = Join-Path $runRoot ([IO.Path]::GetFileName($File)+'.log')
        if ([IO.File]::ReadAllText($refusalLog) -notmatch 'ERROR:\s+P0001:') { throw 'Legacy refusal SQLSTATE differs.' }
        Copy-Item -LiteralPath $refusalLog -Destination (Join-Path $runRoot "refusal-$Label.log")
        Save-RecoveryCatalog "legacy-after-$Label"
        Save-LegacyData "after-$Label"
        Assert-CatalogRollback "legacy-before-$Label" "legacy-after-$Label"
        if ([IO.File]::ReadAllText((Join-Path $runRoot "data-before-$Label.json")) -cne [IO.File]::ReadAllText((Join-Path $runRoot "data-after-$Label.json"))) { throw 'Legacy refusal changed synthetic payment/member/audit history.' }
        Write-Output "PASS: real legacy migration refusal $Label; complete protected-row hashes and metadata unchanged."
    } finally {
        [IO.File]::WriteAllText($fixture,"BEGIN;`n$CleanupSql`nCOMMIT;",[Text.UTF8Encoding]::new($false))
        Invoke-TestSqlFile $fixture
    }
}

function Invoke-LegacyStage([string] $File, [string] $Version) {
    $member = '90000000-0000-4000-8000-000000000001'
    $plan = '90000000-0000-4000-8000-000000000002'
    $purchase = '90000000-0000-4000-8000-000000000003'
    if ($Version -eq '20261103080000') {
        Invoke-LegacyRefusal $File 'plan-duplicate' "INSERT INTO private.membership_plans(id,name,price_php) VALUES('$plan','Legacy   conflict',100),('$purchase','legacy conflict',100);" "DELETE FROM private.membership_plans WHERE id IN ('$plan','$purchase');" 'DUPLICATE_MEMBERSHIP_PLAN_NAMES'
    }
    if ($Version -eq '20261110110000') {
        $base = "INSERT INTO private.members(member_code,full_name,mobile_lookup_hash,mobile_encrypted,id,status,approved_at) VALUES('GF-LEGACY-FIXTURE','Synthetic legacy',decode(repeat('ea',32),'hex'),decode('01','hex'),'$member',"
        foreach ($case in @(@('active-unapproved',"'active',NULL"),@('pending-approved',"'pending',clock_timestamp()"),@('future-approval',"'active',clock_timestamp()+interval '1 day'"))) {
            Invoke-LegacyRefusal $File $case[0] ($base+$case[1]+');') "DELETE FROM private.members WHERE id='$member';" 'Legacy registration state requires documented Owner review'
        }
        $setup = $base + "'active','2010-01-01'::timestamptz); INSERT INTO private.membership_plans(id,name,price_php) VALUES('$plan','Legacy fixture',100);"
        foreach ($case in @(@('active-undated',"'active',NULL,NULL"),@('pending-dated',"'pending_payment','2020-01-01','2020-01-31'"),@('unpaid-active',"'active','2020-01-01','2020-01-31'"))) {
            Invoke-LegacyRefusal $File $case[0] ($setup+" INSERT INTO private.membership_purchases(id,member_id,plan_id,price_php,purchase_status,activation_date,expiry_date) VALUES('$purchase','$member','$plan',100,"+$case[1]+');') "DELETE FROM private.membership_purchases WHERE id='$purchase'; DELETE FROM private.members WHERE id='$member'; DELETE FROM private.membership_plans WHERE id='$plan';" 'Legacy membership/payment state requires documented Owner review'
        }
        # Isolate the expiry predicate with a real confirmed receipt/allocation:
        # missing-payment rejection must not mask removal of the date guard.
        # Keep the synthetic money/audit history; cleanup corrects only this
        # deliberately malformed pre-lifecycle fixture term to its server basis.
        $paid = $setup + " INSERT INTO private.membership_purchases(id,member_id,plan_id,price_php) VALUES('$purchase','$member','$plan',100); SET LOCAL ROLE service_role; DO `$paid`$ DECLARE p jsonb; BEGIN p:=api.owner_record_membership_payment('00000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000004','$purchase',100,'cash',NULL); PERFORM api.owner_confirm_membership_payment('00000000-0000-4000-8000-000000000001',(p->>'id')::uuid,true); END `$paid`$; RESET ROLE; UPDATE private.membership_purchases SET purchase_status='active',activation_date=(clock_timestamp() AT TIME ZONE 'Asia/Manila')::date,expiry_date=((clock_timestamp() AT TIME ZONE 'Asia/Manila')::date+interval '1 month')::date WHERE id='$purchase';"
        Invoke-LegacyRefusal $File 'wrong-expiry' $paid "UPDATE private.membership_purchases SET expiry_date=(activation_date+interval '1 month')::date-1 WHERE id='$purchase';" 'Legacy membership/payment state requires documented Owner review'
    }
    if ($Version -eq '20261110160000') {
        # The current parent trigger forbids creating this old state. A disposable
        # inherited fixture supplies it to the actual parent SELECT, without
        # disabling/changing any existing trigger, constraint, policy or RLS flag.
        $setup = "CREATE TABLE private.gf_legacy_review_fixture () INHERITS(private.membership_purchases); ALTER TABLE private.gf_legacy_review_fixture OWNER TO gym_data_owner; ALTER TABLE private.gf_legacy_review_fixture ENABLE ROW LEVEL SECURITY; ALTER TABLE private.gf_legacy_review_fixture FORCE ROW LEVEL SECURITY; INSERT INTO private.gf_legacy_review_fixture(id,member_id,plan_id,price_php,purchase_status,activation_date,expiry_date) VALUES('$purchase','$member','$plan',100,'payment_review','2020-01-01','2020-01-31');"
        Invoke-LegacyRefusal $File 'dated-review' $setup 'DROP TABLE private.gf_legacy_review_fixture;' 'Historical review terms require explicit basis review before correction migration'
    }
    if ($Version -eq '20261110170000') {
        foreach ($state in @('open','closed')) {
            $closed = if($state -eq 'closed'){",closed_at,closed_by"}else{''}
            $values = if($state -eq 'closed'){",clock_timestamp(),'00000000-0000-4000-8000-000000000001'"}else{''}
            Invoke-LegacyRefusal $File "drawer-$state" "INSERT INTO private.cash_drawer_sessions(id,opened_by,opening_float_php,session_status$closed) VALUES('$purchase','00000000-0000-4000-8000-000000000001',0,'$state'$values);" "DELETE FROM private.cash_drawer_sessions WHERE id='$purchase';" 'Legacy cash sessions require Owner evidence review before daily procedure migration'
        }
    }
}

function Invoke-CompatibilityRollbackProbe([string] $File, [string] $Version) {
    $sql = [IO.File]::ReadAllText($File)
    $anchor = if ($Version -eq '20261110100000') { 'ALTER TABLE private.attendance_checkins OWNER TO gym_data_owner;' } else { 'ALTER TABLE private.member_checkin_rate_events OWNER TO gym_data_owner;' }
    if ($sql.Split(@($anchor),[StringSplitOptions]::None).Count -ne 2) { throw 'Rollback probe source anchor changed.' }
    $probe = Join-Path $runRoot "rollback-$Version.sql"
    [IO.File]::WriteAllText($probe,$sql.Replace($anchor,$anchor + "`nDO `$injected`$ BEGIN RAISE EXCEPTION 'Injected compatibility rollback'; END `$injected`$;"),[Text.UTF8Encoding]::new($false))
    Save-RecoveryCatalog "rollback-before-$Version"
    Invoke-CustomerSqlFile $probe 'Injected compatibility rollback'
    Save-RecoveryCatalog "rollback-after-$Version"
    Assert-CatalogRollback "rollback-before-$Version" "rollback-after-$Version"
    Write-Output "PASS: partial ownership/role/capability rollback at $Version; identical before/after metadata."
}

function Save-RecoveryCatalog([string] $Version) {
    $result = Invoke-NativeTool $psql @('-X', '-w', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', $connection,
        '-f', (Join-Path $repoRoot 'supabase/recovery/catalog.sql'))
    if ($result.ExitCode -ne 0) {
        $result.Output | Set-Content -LiteralPath (Join-Path $runRoot 'catalog-error.log')
        throw 'Recovery catalog capture failed; see private synthetic catalog-error.log.'
    }
    $json = ($result.Output | ForEach-Object { "$_" }) -join "`n"
    $parsed = $json | ConvertFrom-Json
    if ($parsed.format -ne 1 -or -not $parsed.objects) { throw 'Recovery catalog envelope missing.' }
    $sourceManifest = (Get-Content -LiteralPath (Join-Path $repoRoot 'supabase/recovery/source-manifest.json') -Raw | ConvertFrom-Json).migrations
    $parsed | Add-Member -MemberType NoteProperty -Name sourceManifest -Value $sourceManifest
    $parsed | Add-Member -MemberType NoteProperty -Name syntheticStage -Value $Version
    $parsed | Add-Member -MemberType NoteProperty -Name executionProfile -Value $(if ($CustomerCompatibility) { 'customer-compatibility' } else { 'unchanged-engine-control' })
    if ($CustomerCompatibility) {
        $parsed | Add-Member -MemberType NoteProperty -Name compatibilityManifestSha256 -Value (Get-FileHash -LiteralPath $compatibilityManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $json = $parsed | ConvertTo-Json -Depth 12 -Compress
    [IO.File]::WriteAllText((Join-Path $runRoot "catalog-$Version.json"), $json, [Text.UTF8Encoding]::new($false))
}

function Invoke-RecoveryAuthorityRefusal([string] $File, [string] $RoleName, [string] $Message) {
    # A real SCRAM-authenticated non-superuser connection, not superuser SET ROLE.
    Save-RecoveryCatalog ("before-" + $RoleName)
    $actorConnection = $connection.Replace('user=postgres ', 'user=gf_recovery_migrator ')
    $guard = @"
DO `$guard`$ BEGIN
 IF current_database()<>'$database' OR session_user<>'gf_recovery_migrator'
 OR current_user<>session_user OR inet_server_addr()<>'127.0.0.1'::inet
 OR current_setting('gymforce.synthetic_run_id',true)<>'$runId'
 OR current_setting('port')<>'$port'
 OR EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls OR NOT rolcreaterole))
 THEN RAISE EXCEPTION 'Recovery non-superuser identity mismatch'; END IF;
END `$guard`$;
"@
    if ($RoleName -eq 'gym_checkin_executor') {
        $grant = Invoke-NativeTool $psql @('-X','-w','-v','ON_ERROR_STOP=1','-d',$connection,
            '-c','GRANT USAGE ON SCHEMA private TO gf_recovery_migrator; GRANT UPDATE ON private.attendance_checkins TO gf_recovery_migrator')
        if ($grant.ExitCode -ne 0) { throw 'Synthetic attendance lock prerequisite failed.' }
    }
    try {
        $result = Invoke-NativeTool $psql @('-X','-w','-v','ON_ERROR_STOP=1','-d',$actorConnection,'-c',$guard,'-f',$File)
        $result.Output | Set-Content -LiteralPath (Join-Path $runRoot ("authority-" + $RoleName + '.log'))
        $refusalText = ($result.Output | ForEach-Object { "$_" }) -join "`n"
        if ($result.ExitCode -ne 3 -or -not $refusalText.Contains($Message)) {
            throw 'Expected unchanged migration authority refusal not observed.'
        }
    } finally {
        if ($RoleName -eq 'gym_checkin_executor') {
            $revoke = Invoke-NativeTool $psql @('-X','-w','-v','ON_ERROR_STOP=1','-d',$connection,
                '-c','REVOKE UPDATE ON private.attendance_checkins FROM gf_recovery_migrator; REVOKE USAGE ON SCHEMA private FROM gf_recovery_migrator')
            if ($revoke.ExitCode -ne 0) { throw 'Synthetic prerequisite cleanup failed.' }
        }
    }
    $predicate = "rolname='$RoleName'"
    if ($RoleName -eq 'gym_data_owner') { $predicate = "rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor')" }
    $clean = Invoke-NativeTool $psql @('-X','-w','-At','-v','ON_ERROR_STOP=1','-d',$connection,
        '-c',"SELECT NOT EXISTS(SELECT 1 FROM pg_roles WHERE $predicate)")
    if ($clean.ExitCode -ne 0 -or ($clean.Output -join '').Trim() -ne 't') { throw 'Failed migration leaked a reserved role.' }
    Save-RecoveryCatalog ("after-" + $RoleName)
    $before = (Get-Content -LiteralPath (Join-Path $runRoot ("catalog-before-" + $RoleName + '.json')) -Raw | ConvertFrom-Json).objects | ConvertTo-Json -Depth 8 -Compress
    $after = (Get-Content -LiteralPath (Join-Path $runRoot ("catalog-after-" + $RoleName + '.json')) -Raw | ConvertFrom-Json).objects | ConvertTo-Json -Depth 8 -Compress
    if ($before -cne $after) { throw 'Authority refusal or probe cleanup changed the catalog.' }
    Write-Output "PASS: real non-superuser unchanged $([IO.Path]::GetFileName($File)) refused and connection rollback removed its role."
}

try {
    # All credential creation and initialization now share the same finally.
    $password = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($passwordPath, $password, [Text.UTF8Encoding]::new($false))
    if ($FaultPoint -eq 'AfterCredential') { throw 'Injected initialization failure: AfterCredential' }
    $portReservation = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    try { $portReservation.Start(); $port = $portReservation.LocalEndpoint.Port }
    finally { $portReservation.Stop() }
    $connection = "host=127.0.0.1 port=$port dbname=$database user=$adminUser passfile='$($passfilePath.Replace('\', '/'))' require_auth=scram-sha-256 connect_timeout=5"
    if ($FaultPoint -eq 'BeforeInitdb') { throw 'Injected initialization failure: BeforeInitdb' }
    $locale = if ($FaultPoint -eq 'InitdbFailure') { 'gymforce_invalid_locale' } else { 'C' }
    $init = Invoke-NativeTool (Join-Path $PostgresBin 'initdb.exe') @('-D', $dataRoot, '-U', $adminUser, '--encoding=UTF8', "--locale=$locale", '--auth-host=scram-sha-256', '--auth-local=scram-sha-256', "--pwfile=$passwordPath")
    $init.Output | Set-Content -LiteralPath (Join-Path $runRoot 'initdb.log')
    if ($init.ExitCode -ne 0) { throw 'Synthetic initdb failed; see retained directory.' }
    if ($FaultPoint -eq 'AfterInitdb') { throw 'Injected initialization failure: AfterInitdb' }
    [IO.File]::WriteAllText($passfilePath, "127.0.0.1:$port`:*:$adminUser`:$password", [Text.UTF8Encoding]::new($false))
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
    if ($FaultPoint -eq 'AfterStart') { throw 'Injected initialization failure: AfterStart' }
    $maintenanceConnection = $connection.Replace("dbname=$database", 'dbname=postgres')
    if ($CustomerCompatibility) {
        $customerPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        [IO.File]::AppendAllText($passfilePath, "`n127.0.0.1:$port`:*:postgres:$customerPassword", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($actorBootstrapPath,"CREATE ROLE postgres LOGIN NOSUPERUSER NOCREATEDB CREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS PASSWORD '$customerPassword';",[Text.UTF8Encoding]::new($false))
        $customerPassword = $null
        $customerCreated = Invoke-NativeTool $psql @('-X','-w','-v','ON_ERROR_STOP=1','-d',$maintenanceConnection,'-f',$actorBootstrapPath)
        if ($customerCreated.ExitCode -ne 0) { throw 'Synthetic customer bootstrap failed.' }
        Remove-Item -LiteralPath $actorBootstrapPath
        $created = Invoke-NativeTool (Join-Path $PostgresBin 'createdb.exe') @('-w', "--maintenance-db=$maintenanceConnection", '-O','postgres', $database)
    } else { $created = Invoke-NativeTool (Join-Path $PostgresBin 'createdb.exe') @('-w', "--maintenance-db=$maintenanceConnection", $database) }
    if ($created.ExitCode -ne 0) {
        $created.Output | Set-Content -LiteralPath (Join-Path $runRoot 'createdb-error.log')
        throw 'Synthetic database creation failed; see private createdb-error.log.'
    }
    $runtime = Invoke-NativeTool $psql @('-X','-w','-qAt','-d',$connection,'-c',"SELECT jsonb_build_object('serverVersion',current_setting('server_version'),'serverVersionNum',current_setting('server_version_num'),'customerCompatibility',$(if ($CustomerCompatibility) { 'true' } else { 'false' }))")
    if ($runtime.ExitCode -ne 0) { throw 'Server runtime verification failed.' }
    $runtime.Output | Set-Content -LiteralPath (Join-Path $runRoot 'runtime.json')
    Write-Output ('PASS: isolated server runtime ' + ($runtime.Output -join ''))
    Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/synthetic_bootstrap.sql')
    if ($CustomerCompatibility) {
        $bootstrap = Invoke-NativeTool $psql @('-X','-w','-v','ON_ERROR_STOP=1','-d',$connection,'-c',
          'CREATE EXTENSION pgcrypto WITH SCHEMA extensions; GRANT USAGE ON SCHEMA extensions TO postgres WITH GRANT OPTION; GRANT USAGE ON SCHEMA auth TO postgres; GRANT REFERENCES ON auth.users TO postgres;')
        if ($bootstrap.ExitCode -ne 0) { throw 'Synthetic provider dependency fixture failed.' }
    }
    if ($RecoveryAudit -and -not $CustomerCompatibility) {
        $actorPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        [IO.File]::AppendAllText($passfilePath, "`n127.0.0.1:$port`:*:gf_recovery_migrator:$actorPassword", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($actorBootstrapPath,
            "CREATE ROLE gf_recovery_migrator LOGIN NOSUPERUSER NOCREATEDB CREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS PASSWORD '$actorPassword';",
            [Text.UTF8Encoding]::new($false))
        $actorPassword = $null
        Invoke-TestSqlFile $actorBootstrapPath
        Remove-Item -LiteralPath $actorBootstrapPath
    }
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'supabase/migrations') -Filter '*.sql' | Sort-Object Name) {
        if ($RecoveryAudit) {
            $legacyFile = if ($CustomerCompatibility -and $file.Name.Substring(0,14) -ge '20261110100000') { Get-CompatibilityFile $file.Name } else { $file.FullName }
            Invoke-LegacyStage $legacyFile $file.Name.Substring(0,14)
        }
        if ($RecoveryAudit -and $file.Name -eq '20261103080000_owner_membership_plans.sql') {
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/recovery_legacy_behavior.sql')
        }
        if ($RecoveryAudit -and -not $CustomerCompatibility -and $file.Name -eq '20261110100000_executor_hardening.sql') {
            Invoke-RecoveryAuthorityRefusal $file.FullName 'gym_data_owner' 'Reserved role membership exists; refusing membership changes'
        }
        if ($RecoveryAudit -and -not $CustomerCompatibility -and $file.Name -eq '20261110150000_member_checkin.sql') {
            Invoke-RecoveryAuthorityRefusal $file.FullName 'gym_checkin_executor' 'Unsafe verifier role or membership; refusing to alter it'
        }
        if ($file.Name -eq '20261110103000_audit_timezone.sql') {
            if ($TestLegacyAuditRefusal) {
                Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/audit_timezone_incompatible_seed.sql')
                if ($CustomerCompatibility) {
                    Save-RecoveryCatalog 'audit-refusal-before'
                    Invoke-CustomerSqlFile (Get-CompatibilityFile $file.Name) 'Legacy audit history requires Owner review before UTC normalization'
                    Save-RecoveryCatalog 'audit-refusal-after'
                    Assert-CatalogRollback 'audit-refusal-before' 'audit-refusal-after'
                } else { Invoke-TestSqlFile $file.FullName 'Legacy audit history requires Owner review before UTC normalization' }
                Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/audit_timezone_refusal_assertions.sql')
                $refusalVerified = $true
                break
            }
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/audit_timezone_seed.sql')
        }
        if ($CustomerCompatibility) {
            $sourceFile = if ($file.Name.Substring(0,14) -ge '20261110100000') { Get-CompatibilityFile $file.Name } else { $file.FullName }
            if ($file.Name.Substring(0,14) -in @('20261110100000','20261110150000')) {
                Invoke-CompatibilityRollbackProbe $sourceFile $file.Name.Substring(0,14)
            }
            if ($file.Name.Substring(0,14) -eq '20261110103000') {
                Save-RecoveryCatalog 'unsafe-graph-before'
                $leak = Invoke-NativeTool $psql @('-X','-w','-v','ON_ERROR_STOP=1','-d',$connection,'-c','GRANT gym_owner_executor TO authenticated WITH INHERIT TRUE, SET TRUE')
                if ($leak.ExitCode -ne 0) { throw 'Unsafe graph fixture setup failed.' }
                try { Invoke-CustomerSqlFile $sourceFile 'Unapproved compatibility role graph or attributes' }
                finally {
                    $clean = Invoke-NativeTool $psql @('-X','-w','-v','ON_ERROR_STOP=1','-d',$connection,'-c','REVOKE gym_owner_executor FROM authenticated')
                    if ($clean.ExitCode -ne 0) { throw 'Unsafe graph fixture cleanup failed.' }
                }
                Save-RecoveryCatalog 'unsafe-graph-after'
                Assert-CatalogRollback 'unsafe-graph-before' 'unsafe-graph-after'
                Write-Output 'PASS: unexpected application membership refused; fixture cleanup preserved metadata.'
            }
            Invoke-CustomerSqlFile $sourceFile
        } else { Invoke-TestSqlFile $file.FullName }
        if ($RecoveryAudit -and $file.Name.Substring(0,14) -ge '20261030180000') {
            Save-RecoveryCatalog $file.Name.Substring(0,14)
        }
        if ($file.Name -eq '20261110100000_executor_hardening.sql') {
            # Snapshot assertions deliberately describe this phase, not all
            # future schemas. Run before subsequent lifecycle additions.
            $foundationAssertions = if ($CustomerCompatibility) { Get-CompatibilityFile 'executor_hardening_assertions.sql' } else { Join-Path $repoRoot 'supabase/tests/executor_hardening_assertions.sql' }
            Invoke-TestSqlFile $foundationAssertions
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/membership_payment_security_assertions.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/executor_behavior.sql')
            try {
                $env:GYMFORCE_TEST_RUN_ID = $runId
                $env:GYMFORCE_TEST_PSQL = $psql
                $env:GYMFORCE_TEST_CONNECTION = $connection
                $env:GYMFORCE_TEST_DATA_DIRECTORY = $dataRoot
                $raceArgs = @((Join-Path $repoRoot 'scripts/test-db-concurrency.mjs'))
                if ($CustomerCompatibility) { $raceArgs += '--compatibility-fixture' }
                $races = Invoke-NativeTool (Get-Command node.exe).Source $raceArgs
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
            $phaseFile = if ($CustomerCompatibility -and $phaseSuites[$file.Name] -eq 'member_checkin_behavior.sql') { Get-CompatibilityFile 'member_checkin_behavior.sql' } else { Join-Path $repoRoot ('supabase/tests/' + $phaseSuites[$file.Name]) }
            Invoke-TestSqlFile $phaseFile
        }
    }
    if (-not $refusalVerified) {
        try {
            $env:GYMFORCE_TEST_RUN_ID = $runId
            $env:GYMFORCE_TEST_PSQL = $psql
            $env:GYMFORCE_TEST_CONNECTION = $connection
            $env:GYMFORCE_TEST_DATA_DIRECTORY = $dataRoot
            $raceArgs = @((Join-Path $repoRoot 'scripts/test-db-concurrency.mjs'), '--operations')
            if ($CustomerCompatibility) { $raceArgs += '--compatibility-fixture' }
            $operationRaces = Invoke-NativeTool (Get-Command node.exe).Source $raceArgs
            $operationRaces.Output | Set-Content -LiteralPath (Join-Path $runRoot 'operation-concurrency.log')
            $operationRaces.Output | ForEach-Object { Write-Output $_ }
            if ($operationRaces.ExitCode -ne 0) { throw 'Synthetic operation concurrency suite failed.' }
        } finally {
            foreach ($entryName in @('GYMFORCE_TEST_RUN_ID','GYMFORCE_TEST_PSQL','GYMFORCE_TEST_CONNECTION','GYMFORCE_TEST_DATA_DIRECTORY')) {
                Remove-Item -LiteralPath "Env:$entryName" -ErrorAction SilentlyContinue
            }
        }
        $finalAssertions = if ($CustomerCompatibility) { Get-CompatibilityFile 'final_security_assertions.sql' } else { Join-Path $repoRoot 'supabase/tests/final_security_assertions.sql' }
        Invoke-TestSqlFile $finalAssertions
        if ($CustomerCompatibility) {
            $leak = Invoke-NativeTool $psql @('-X','-w','-v','ON_ERROR_STOP=1','-d',$connection,'-c','GRANT EXECUTE ON FUNCTION api.owner_list_payable_purchases(uuid,text,integer,integer) TO PUBLIC')
            if ($leak.ExitCode -ne 0) { throw 'PUBLIC ACL fixture failed.' }
            Invoke-CustomerSqlFile (Get-CompatibilityFile '01-explicit-routine-acls.sql')
            Invoke-CustomerSqlFile (Get-CompatibilityFile '01-explicit-routine-acls.sql')
            Invoke-CustomerSqlFile (Join-Path $repoRoot 'supabase/recovery/proposals/02-postgres-future-routine-defaults.sql')
            Invoke-CustomerSqlFile (Join-Path $repoRoot 'supabase/recovery/proposals/02-postgres-future-routine-defaults.sql')
            Invoke-CustomerSqlFile (Join-Path $repoRoot 'supabase/tests/compatibility_security_behavior.sql')
            Invoke-CustomerSqlFile (Get-CompatibilityFile 'maintenance-rls-proof.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/recovery_inherited_leak.sql')
            Save-RecoveryCatalog 'acl-refusal-before'
            Invoke-CustomerSqlFile (Get-CompatibilityFile '01-explicit-routine-acls.sql') 'Inherited routine access remains; refusing partial correction'
            Save-RecoveryCatalog 'acl-refusal-after'
            Assert-CatalogRollback 'acl-refusal-before' 'acl-refusal-after'
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/recovery_inherited_cleanup.sql')
            Invoke-TestSqlFile $finalAssertions
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/compatibility_legacy_diagnostics.sql')
            $legacyRow = Get-Content -LiteralPath (Join-Path $runRoot 'compatibility_legacy_diagnostics.sql.log') | Where-Object { $_ -match '^\s*\[' } | Select-Object -First 1
            $legacy = $null
            foreach ($finding in ($legacyRow | ConvertFrom-Json)) {
                if ($finding.check_name -eq 'superseded_aggregate_limiter_table') { $legacy = $finding }
            }
            if (-not $legacy -or $legacy.result -ne 'PRESENT_REQUIRES_PRIVATE_REVIEW_NO_REMOVAL_AUTHORIZED' -or $legacy.dependency_count -lt 1 -or $legacy.policy_count -ne 1) { throw 'Legacy diagnostic missed synthetic dependencies/policy.' }
            Invoke-TestSqlFile (Get-CompatibilityFile 'history-fixture.sql')
            $historyRow = Get-Content -LiteralPath (Join-Path $runRoot 'history-fixture.sql.log') | Where-Object { $_ -match '^\s*\{' } | Select-Object -First 1
            [IO.File]::WriteAllText((Join-Path $runRoot 'history-fixture.json'),$historyRow.Trim(),[Text.UTF8Encoding]::new($false))
            $historyCheck = Invoke-NativeTool (Get-Command node.exe).Source @((Join-Path $repoRoot 'scripts/recovery/compare-history.mjs'),(Join-Path $runRoot 'history-fixture.json'))
            if ($historyCheck.ExitCode -ne 0) { throw 'Read-only history diagnostic/offline comparison failed.' }
            $historyResult = ($historyCheck.Output -join '') | ConvertFrom-Json
            if ($historyResult.recordedKnown -ne 20 -or $historyResult.unrecordedLocal -ne 17 -or $historyResult.productionDecision -ne 'HOLD') { throw 'Synthetic history classification differs.' }
            Invoke-CustomerSqlFile (Get-CompatibilityFile 'compatibility-authority.sql') -SingleJson
            $authority = Get-Content -Raw -LiteralPath (Join-Path $runRoot 'compatibility-authority.sql.log') | ConvertFrom-Json
            if (-not $authority.actorMatches -or $authority.reservedPresent -ne 4 -or $authority.approvedProviderEdges -ne 4 -or
              $authority.unexpectedEdges -ne 0 -or $authority.reservedSchemaCreatePaths -ne 0 -or $authority.operatorSetOrInheritPaths -ne 0 -or
              $authority.unsafeReservedAttributes -ne 0 -or $authority.maintenancePolicies -ne 0 -or $authority.missingProviderEdges -ne 0 -or
              -not $authority.digestDependency.ownerExecutorCanExecute) { throw 'Compatibility authority diagnostic failed final cleanup.' }
            Invoke-CustomerSqlFile (Get-CompatibilityFile 'effective-privileges.sql')
            $rows = @(Get-Content -LiteralPath (Join-Path $runRoot 'effective-privileges.sql.log') | Where-Object { $_ -match '^\s*[a-z_]+\s+\|\s+(PASS|FAIL)\s*$' })
            if ($rows.Count -ne 10 -or @($rows | Where-Object { $_ -match '\|\s+FAIL\s*$' }).Count -ne 0) { throw 'Customer final privilege outcomes must be ten PASS rows.' }
            foreach ($diagnostic in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'supabase/recovery/diagnostics') -Filter '*.sql') {
                # Already executed and asserted above as the customer using the
                # synthetic provider profile. Do not overwrite its evidence with
                # the hosted-profile query executed as the bootstrap superuser.
                if ($diagnostic.Name -eq 'compatibility-authority.sql') { continue }
                if ($diagnostic.Name -eq 'migration-authority.sql') { Invoke-CustomerSqlFile $diagnostic.FullName }
                else { Invoke-TestSqlFile $diagnostic.FullName }
            }
            Save-RecoveryCatalog 'final'
            Write-Output 'PASS: actual PG17 customer ACL correction/replay/inherited-refusal/defaults and ten final privilege screens.'
        }
        if ($RecoveryAudit -and -not $CustomerCompatibility) {
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/recovery_security_behavior.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/recovery_creator_defaults.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/recovery_inherited_leak.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/recovery/proposals/01-explicit-routine-acls.sql') 'Inherited routine access remains; refusing partial correction'
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/recovery_inherited_cleanup.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/tests/final_security_assertions.sql')
            Invoke-TestSqlFile (Join-Path $repoRoot 'supabase/recovery/effective-privileges.sql')
            $privilegeRows = @(Get-Content -LiteralPath (Join-Path $runRoot 'effective-privileges.sql.log') | Where-Object {
                $_ -match '^\s*[a-z_]+\s+\|\s+(PASS|FAIL)\s*$'
            })
            if ($privilegeRows.Count -ne 10 -or @($privilegeRows | Where-Object { $_ -match '\|\s+FAIL\s*$' }).Count -ne 0) {
                throw 'Final synthetic effective privilege screens must contain ten PASS outcomes.'
            }
            Write-Output 'PASS: all ten final synthetic effective privilege screens.'
            foreach ($diagnostic in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'supabase/recovery/diagnostics') -Filter '*.sql') {
                Invoke-TestSqlFile $diagnostic.FullName
            }
            Save-RecoveryCatalog 'final'
        }
    }
    $testExit = 0
} catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
} finally {
    try {
        if ($started -or (Test-Path -LiteralPath (Join-Path $dataRoot 'postmaster.pid'))) {
            $stopped = Invoke-NativeTool (Join-Path $PostgresBin 'pg_ctl.exe') @('-D', $dataRoot, '-m', 'fast', '-w', 'stop')
            if ($stopped.ExitCode -ne 0) { $testExit = 1; Write-Output 'FAIL: synthetic PostgreSQL shutdown failed.' }
            else { Write-Output 'PASS: synthetic PostgreSQL stopped.' }
        }
    } finally {
        foreach ($credentialFile in @($passwordPath, $passfilePath, $actorBootstrapPath)) {
            try { if (Test-Path -LiteralPath $credentialFile) { Remove-Item -LiteralPath $credentialFile } }
            catch { $testExit=1; Write-Output 'FAIL: synthetic credential removal failed; restricted file retained for Owner-local cleanup.' }
        }
        $password=$null; $customerPassword=$null; $actorPassword=$null
    }
    Write-Output "Synthetic logs retained under .cache/security-test-$runId (no production access)."
}
exit $testExit
