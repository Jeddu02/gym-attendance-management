$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot '..\config.toml'
$configText = Get-Content -LiteralPath $configPath -Raw

function Get-ValidatedApiSchemas {
    param([Parameter(Mandatory)][string] $Text)

    $section = ''
    $apiSectionCount = 0
    $schemaSettings = [System.Collections.Generic.List[string]]::new()

    foreach ($rawLine in ($Text -split "`r?`n")) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith('#')) {
            continue
        }

        if ($line.StartsWith('[')) {
            if ($line -notmatch '^\[([A-Za-z0-9_.-]+)\]\s*(?:#.*)?$') {
                throw "Unsupported or malformed TOML section header: $line"
            }
            $section = $Matches[1]
            if ($section -ceq 'api') {
                $apiSectionCount++
            }
            continue
        }

        if ($section -ceq 'api' -and $line -match '^(?:schemas|"schemas")(?:\s|=|$)') {
            if ($line -notmatch '^schemas\s*=\s*\[\s*"public"\s*,\s*"graphql_public"\s*,\s*"api"\s*\]\s*(?:#.*)?$') {
                throw "Unsupported or incorrect [api].schemas syntax: $line"
            }
            $schemaSettings.Add($line)
        }
    }

    if ($apiSectionCount -ne 1) {
        throw "Expected exactly one [api] section; found $apiSectionCount."
    }
    if ($schemaSettings.Count -ne 1) {
        throw "Expected exactly one supported schemas setting inside [api]; found $($schemaSettings.Count)."
    }

    return @('public', 'graphql_public', 'api')
}

$expectedSchemas = @('public', 'graphql_public', 'api')
$validExample = "[api]`nschemas = [`"public`", `"graphql_public`", `"api`"]"
if ((Get-ValidatedApiSchemas -Text $validExample) -join "`n" -cne ($expectedSchemas -join "`n")) {
    throw 'The supported exact [api].schemas example was rejected.'
}

$invalidExamples = @(
    @{ Name = 'setting outside [api]'; Text = "schemas = [`"public`", `"graphql_public`", `"api`"]`n[api]`nenabled = true" },
    @{ Name = 'additional schema'; Text = "[api]`nschemas = [`"public`", `"graphql_public`", `"api`", `"private`"]" },
    @{ Name = 'missing schema'; Text = "[api]`nschemas = [`"public`", `"api`"]" },
    @{ Name = 'wrong order'; Text = "[api]`nschemas = [`"graphql_public`", `"public`", `"api`"]" },
    @{ Name = 'unquoted schema'; Text = '[api]' + "`n" + 'schemas = [public, "graphql_public", "api"]' },
    @{ Name = 'malformed value'; Text = "[api]`nschemas = [" },
    @{ Name = 'duplicate setting'; Text = "[api]`nschemas = [`"public`", `"graphql_public`", `"api`"]`nschemas = [`"public`", `"graphql_public`", `"api`"]" }
)
foreach ($example in $invalidExamples) {
    $rejected = $false
    try {
        [void](Get-ValidatedApiSchemas -Text $example.Text)
    }
    catch {
        $rejected = $true
    }
    if (-not $rejected) {
        throw "Static parser self-test accepted invalid example: $($example.Name)"
    }
}

$schemas = Get-ValidatedApiSchemas -Text $configText
if (($schemas -join "`n") -cne ($expectedSchemas -join "`n")) {
    throw "Expected API schemas exactly: $($expectedSchemas -join ', '). Found: $($schemas -join ', ')"
}

if ($configText -notmatch '(?m)^auto_expose_new_tables\s*=\s*false\s*$') {
    throw 'Automatic exposure of new public tables must be disabled locally.'
}

$authMatch = [regex]::Match($configText, '(?ms)^\[auth\]\s*(?<body>.*?)(?=^\[|\z)')
if (-not $authMatch.Success -or $authMatch.Groups['body'].Value -notmatch '(?m)^enable_signup\s*=\s*false\s*$') {
    throw 'Local global Auth signup must be disabled.'
}

$emailMatch = [regex]::Match($configText, '(?ms)^\[auth\.email\]\s*(?<body>.*?)(?=^\[|\z)')
if (-not $emailMatch.Success -or $emailMatch.Groups['body'].Value -notmatch '(?m)^enable_signup\s*=\s*false\s*$') {
    throw 'Local email Auth signup must be disabled.'
}

$authMatch = [regex]::Match($configText, '(?ms)^\[auth\]\s*(?<body>.*?)(?=^\[|\z)')
if (-not $authMatch.Success -or $authMatch.Groups['body'].Value -notmatch '(?m)^enable_anonymous_sign_ins\s*=\s*false\s*$') {
    throw 'Local anonymous Auth sign-ins must be disabled.'
}

$smsMatch = [regex]::Match($configText, '(?ms)^\[auth\.sms\]\s*(?<body>.*?)(?=^\[|\z)')
if (-not $smsMatch.Success -or $smsMatch.Groups['body'].Value -notmatch '(?m)^enable_signup\s*=\s*false\s*$') {
    throw 'Local SMS Auth signup must be disabled.'
}

Write-Output 'PASS: local API, auto-exposure, global/email/SMS signup, and anonymous sign-in configuration assertions.'
