$ErrorActionPreference = 'Stop'
# FILESYSTEM ONLY. Never invokes psql or any draft SQL.
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'object-manifest.json') -Raw | ConvertFrom-Json
$dependent = Get-Content -LiteralPath (Join-Path $PSScriptRoot $manifest.dependent_inventory) -Raw | ConvertFrom-Json
function Require([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
Require ($manifest.tables.Count -eq 22) 'Expected 22 tables.'
Require ($manifest.routines.Count -eq 25) 'Expected 25 application functions.'
Require ($manifest.sequences.Count -eq 3) 'Expected three identity sequences.'
Require ($manifest.permissions.Count -eq 34) 'Expected 34 command/role policies.'
Require ($manifest.triggers.Count -eq 13) 'Expected 13 trigger dependencies.'
Require ($dependent.indexes.Count -eq 57) 'Expected 57 dependent indexes.'
Require ($dependent.types.Count -eq 44) 'Expected 44 dependent row/array types.'
$baselineNames = @($manifest.baseline_migrations | ForEach-Object name)
$actualNames = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'supabase/migrations') -Filter '*.sql' | Sort-Object Name | ForEach-Object Name)
Require (($actualNames -join "`n") -ceq ($baselineNames -join "`n")) 'Active migration inventory changed.'
foreach ($baseline in $manifest.baseline_migrations) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot ('supabase/migrations/' + $baseline.name)) -Algorithm SHA256).Hash.ToLowerInvariant()
    Require ($hash -ceq $baseline.sha256) ('Existing migration modified: ' + $baseline.name)
}
foreach ($baseline in $manifest.protected_files) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot $baseline.path) -Algorithm SHA256).Hash.ToLowerInvariant()
    Require ($hash -ceq $baseline.sha256) ('Existing protected source modified: ' + $baseline.path)
}
$migrationPath = Join-Path $PSScriptRoot '20261106120000_owner_executor_foundation.sql.draft'
$assertionPath = Join-Path $PSScriptRoot 'foundation_assertions.sql.draft'
$sql = [IO.File]::ReadAllText($migrationPath)
$assertions = [IO.File]::ReadAllText($assertionPath)
foreach ($path in @($migrationPath,$assertionPath)) {
    Require (-not $path.StartsWith((Join-Path $ProjectRoot 'supabase/migrations'),[StringComparison]::OrdinalIgnoreCase)) 'Draft must stay outside active migration directory.'
    $text = [IO.File]::ReadAllText($path)
    Require ($text.Contains("RAISE EXCEPTION 'DRAFT ONLY:")) 'Missing unconditional draft blocker.'
    Require ($text.IndexOf('DO $draft_only$') -lt $text.IndexOf('DO $phase_assertions$')) 'Draft blocker must precede assertion/DDL.'
    foreach ($group in @([regex]::Matches($text,'\$[a-z_]+\$') | Group-Object Value)) {
        Require ($group.Count % 2 -eq 0) ('Unbalanced dollar tag: ' + $group.Name)
    }
    Require (-not ($text -match '(?im)^\s*(REASSIGN OWNED|ALTER ROLE|CREATE ROLE|DROP |TRUNCATE |INSERT INTO |UPDATE |DELETE FROM )')) 'Unapproved role/data/destructive statement.'
    Require (-not ($text -match '(?im)^\s*GRANT\s+gym_\w+\s+TO\s+')) 'Membership grant is prohibited.'
    Require (-not ($text -match 'FOR column_name IN|g\.column_name=column_name')) 'Ambiguous PL/pgSQL column variable.'
    Require (-not ($text -match 'pg_roles r\b')) 'SQL alias conflicts with PL/pgSQL record variable.'
    Require ($text.Contains('replace(current_setting(''data_directory''),E''\\'',''/'')')) 'Windows path separator must decode to one backslash.'
    Require (-not $text.Contains('E''\\\\''')) 'Over-escaped Windows path separator.'
}
Require ([regex]::Matches($sql,'(?m)^ALTER TABLE .* OWNER TO gym_data_owner;').Count -eq 22) 'Table transfer allowlist mismatch.'
Require ([regex]::Matches($sql,'(?m)^ALTER TABLE .* FORCE ROW LEVEL SECURITY;').Count -eq 22) 'FORCE RLS allowlist mismatch.'
Require ([regex]::Matches($sql,'(?m)^ALTER FUNCTION .* OWNER TO ').Count -eq 25) 'Routine owner allowlist mismatch.'
Require ([regex]::Matches($sql,'(?m)^ALTER FUNCTION .* SECURITY DEFINER;').Count -eq 16) 'Only sixteen API entrypoints may remain definers.'
Require ([regex]::Matches($sql,'(?m)^ALTER FUNCTION .* SECURITY INVOKER;').Count -eq 9) 'Nine private helpers must be invokers.'
Require ([regex]::Matches($sql,'(?m)^CREATE POLICY ').Count -eq 34) 'Policy statement count mismatch.'
Require (-not ($sql -match '(?m)^ALTER SEQUENCE .* OWNER TO')) 'Identity ownership must follow its parent table.'
foreach ($table in $manifest.tables) {
    Require ($sql.Contains('ALTER TABLE ' + $table.name + ' OWNER TO gym_data_owner;')) ('Missing table: ' + $table.name)
}
foreach ($routine in $manifest.routines) {
    Require ($sql.Contains('ALTER FUNCTION ' + $routine.signature + ' OWNER TO ' + $routine.owner + ';')) ('Missing function: ' + $routine.signature)
    Require ($sql.Contains($routine.body_md5) -and $assertions.Contains($routine.body_md5)) ('Missing function-body pin: ' + $routine.signature)
    if ($routine.signature.StartsWith('api.')) {
        Require (@($routine.callers) -contains 'service_role') 'Server-only API boundary missing.'
    }
}
foreach ($permission in $manifest.permissions) {
    Require ($permission.role -in @('gym_owner_executor','gym_public_executor')) 'Only restricted executors may receive runtime table grants.'
    $table = @($manifest.tables | Where-Object { $_.name -ceq $permission.table })
    Require ($table.Count -eq 1) 'Permission references unknown table.'
    foreach ($column in $permission.columns) {
        Require (@($table[0].columns | ForEach-Object name) -ccontains $column) ('Permission references unknown column: ' + $column)
    }
    if ($permission.command -eq 'DELETE') {
        Require ($permission.table -ceq 'private.pin_enrollment_global_rate_limit_events' -and $permission.role -ceq 'gym_public_executor') 'DELETE is only for existing limiter retention.'
    }
    $columnList = if ($permission.columns.Count -gt 0) { ' (' + ($permission.columns -join ', ') + ')' } else { '' }
    $grant = 'GRANT ' + $permission.command + $columnList + ' ON TABLE ' + $permission.table + ' TO ' + $permission.role + ';'
    Require ($sql.Contains($grant)) ('Missing reviewed grant: ' + $permission.table + '/' + $permission.command)
    Require ($sql.Contains('CREATE POLICY ' + $permission.policy + ' ON ' + $permission.table + ' FOR ' + $permission.command + ' TO ' + $permission.role)) 'Missing role/command policy.'
}
$policyKeys = @($manifest.permissions | ForEach-Object { $_.table + '/' + $_.policy })
Require (@($policyKeys | Sort-Object -Unique).Count -eq 34) 'Duplicate table/policy key.'
Require (-not ($sql -match '(?m)^GRANT .* ON TABLE .* TO (anon|authenticated|service_role|gym_registration_login);')) 'Direct caller table grant prohibited.'
Require (-not ($sql -match '(?m)^CREATE POLICY .* TO (PUBLIC|anon|authenticated|service_role)')) 'Public/caller RLS allow policy prohibited.'
Require (-not ($sql -match '(?m)^ALTER (FUNCTION|TABLE|SCHEMA|TYPE|SEQUENCE) (auth|extensions|graphql_public)\.')) 'Provider-object owner/body change prohibited.'
foreach ($profile in @('historical_phase1','current_server_only','proposed_owner_executor','future_attendance')) {
    Require ($assertions.Contains($profile)) ('Missing explicit phase profile: ' + $profile)
}
& node (Join-Path $PSScriptRoot 'check-offline.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Independent offline contract/statement checker refused the draft.' }
Write-Output 'PASS: draft containment/blockers, 24 unchanged migration hashes, protected-source hashes, exact object/grant/policy manifest and lexical checks.'
Write-Output 'NOT EXECUTED: SQL runtime, ownership changes or runtime security tests. Separate offline parser checks do not certify runtime.'

