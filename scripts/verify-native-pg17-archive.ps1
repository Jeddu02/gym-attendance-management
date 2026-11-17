param([Parameter(Mandatory=$true)][string] $ArchivePath)
$ErrorActionPreference = 'Stop'
$name = 'postgresql-17.12-1-windows-x64-binaries.zip'
$url = "https://get.enterprisedb.com/postgresql/$name"
# Separate publisher-hosted checksum, not a digest derived from the input ZIP.
$checksum = & curl.exe --fail --silent --show-error --location --connect-timeout 10 --max-time 30 --proto '=https' --proto-redir '=https' "$url.sha256"
if ($LASTEXITCODE -ne 0) { throw 'Publisher checksum unavailable; archive execution blocked.' }
$text = ($checksum -join "`n").Trim()
if ($text -notmatch ('^([a-fA-F0-9]{64})\s+\*?' + [regex]::Escape($name) + '$')) { throw 'Unexpected publisher checksum format; refusing archive.' }
$published = $Matches[1].ToLowerInvariant()
$actual = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -cne $published) { throw 'Publisher archive checksum mismatch; refusing extraction or execution.' }
@{ version='17.12'; build='1'; architecture='windows-x64'; archiveName=$name;
   publisherArchiveUrl=$url; publisherChecksumUrl="$url.sha256";
   archiveSha256=$actual; publisherSha256=$published;
   verification='MATCHED_PUBLISHER_HTTPS_SHA256'; detachedSignatureVerified=$false;
   verifiedAtUtc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json
