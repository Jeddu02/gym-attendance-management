# Batch 6A - GoTrue source and build-readiness manifest

Prepared 2026-11-20, Asia/Manila. Original repository, master at
5283e35dcb64a72bbe96c89637f9167508401ffa. Status: PROPOSED FOR OWNER REVIEW.
Acquisition/build/startup authorization: NONE. A02 pending. Production NO-GO.

## Decision and scope

Native Windows AMD64 source compilation is a plausible qualification path,
not a verified build or supported upstream Windows release. No Windows binary
is published in the inspected release inventory. A source-provenance decision
and separate acquisition/build approval are required before proceeding.

This task read repository files and public textual release/source metadata.
No source archive, toolchain, module dependency or executable was downloaded;
no build, Auth execution, database startup or SQL was performed. Existing
18 candidate files are preserved; this manifest is the only new project file.
The prior Batch 5 runtime evidence remains historical.

## Acquisition inventory

| Item | Exact proposed identity | Integrity and disposition |
| --- | --- | --- |
| Official Auth repository | https://github.com/supabase/auth | Official Supabase repository; former GoTrue naming persists in commands/configuration |
| Inspected stable release | v2.198.0 | Candidate only; not established as the hosted project's version |
| Immutable source commit | `387e91f37e00b64b9060352988066bbb685f6e45` | Full commit linked by the official release; GitHub displays a verified GitHub signature. No independent local signature verification performed |
| Proposed source archive | `https://github.com/supabase/auth/archive/387e91f37e00b64b9060352988066bbb685f6e45.zip` | Commit-addressed URL, NOT acquired. Publisher SHA-256 for this generated source ZIP was not found; digest UNKNOWN. Not an approved checksum-pinned acquisition |
| Go portable Windows toolchain | `https://go.dev/dl/go1.27.4.windows-amd64.zip` | Official inventory: windows/amd64, 79,077,744 bytes; SHA-256 `178ab98950ac69ab25069307dc6ade79f3816e414cce95b4da166a115cde1e7e` |
| Auth Linux AMD64 release asset, excluded | `https://github.com/supabase/auth/releases/download/v2.198.0/auth-v2.198.0-amd64.tar.xz` | Publisher SHA-256 `4abe9134d7615faa9149cab514acada8e7133cd69d2ccd96fdcef0d795c05171`; NOT a Windows candidate and not proposed for acquisition |
| Go dependencies | Exact upstream commit's `go.mod`, `go.sum`, and local `internal/forks/godotenv` replacement | No standalone aggregate archive SHA-256 established. Pinned module versions and Go sum-database verification must be retained. Dependency acquisition needs explicit inclusion in later approval |
| Locally built executable | Proposed ignored `auth.exe` | SHA-256 UNKNOWN until built. Locally computed hash records identity, not publisher authentication or proof of correct behavior |

Publisher references: [Auth release](https://github.com/supabase/auth/releases/tag/v2.198.0),
[full commit](https://github.com/supabase/auth/commit/387e91f37e00b64b9060352988066bbb685f6e45),
[asset inventory](https://github.com/supabase/auth/releases/expanded_assets/v2.198.0),
[official Go download metadata](https://go.dev/dl/?mode=json&include=all).
The release's binary checksums do not authenticate the source ZIP. Do not
substitute a self-computed archive hash for a missing publisher attestation.

### Source integrity gate requiring an Owner decision

Preferred alternative to an unattested generated ZIP: separately approve a
portable Git source acquisition pinned to the full commit, verify the fetched
tag-to-commit relationship and Git objects, and record the complete tree identity.
Git object verification is a different integrity contract from publisher
SHA-256 archive verification. It requires explicit Owner acceptance; it is not
silently substituted here. Independently validate any signing trust claimed;
GitHub's displayed signature badge alone is not local signer verification.
Alternatively obtain an authenticated publisher source checksum/attestation.
If neither route is accepted, source acquisition remains BLOCKED.

Commit-addressed raw source requests were unavailable through the browsing
service during this review. Build findings below use the release-tagged files,
with the full commit obtained separately from the release. Reconcile every
inspected file against the acquired commit before permitting a build; refuse
tag movement or any source mismatch.

## Toolchain and Windows feasibility

The inspected [go.mod](https://github.com/supabase/auth/blob/v2.198.0/go.mod)
requires Go 1.27.4; the [Dockerfile](https://github.com/supabase/auth/blob/v2.198.0/Dockerfile)
also pins 1.27.4. The [Makefile](https://github.com/supabase/auth/blob/v2.198.0/Makefile)
disables CGO and defines Linux AMD64/ARM64 and Darwin ARM64 release targets.
Use a direct reviewed Go build on Windows, not the Unix Makefile, shell scripts,
symlinks or Docker targets. No C compiler or additional DLL acquisition is
proposed. Transitive platform constraints still require an actual compile.

Local read-only discovery confirms a 64-bit OS and no `go` command on PATH.
The bounded Batch 5 inventory found no native Auth server or Go installation
in its inspected locations. It did not prove absence on every disk location.
Docker is excluded; no WSL distribution was available in that earlier inventory.

Proposed ignored locations are `.cache/tools/go1.27.4-win-amd64`,
`.cache/tools/gotrue-source`, and a dedicated ignored build/cache directory.
`git check-ignore` confirms the first two paths are ignored. No directory was
created. Before extraction, resolve absolute destinations inside this workspace,
reject archive traversal/links escaping them, and refuse existing conflicting
contents. No machine/user PATH, registry, service or firewall modification.

Future child-process build environment, subject to approval:

- Explicit portable `go.exe`; `GOOS=windows`, `GOARCH=amd64`, `CGO_ENABLED=0`.
- `GOTOOLCHAIN=local`, `GOENV=off`, `GOWORK=off`; explicit empty `GOFLAGS`.
- Dedicated ignored `GOPATH`, `GOCACHE`, `GOMODCACHE`, `GOTMPDIR` and portable
  `GOROOT`; do not reuse ambient private-module credentials or configuration.
- `GOPROXY=https://proxy.golang.org` without direct fallback;
  `GOSUMDB=sum.golang.org`, with no private/no-sum exceptions.
- Review exact upstream `go.mod`/`go.sum` and local replacements; do not run
  `go get`, `go generate`, upstream installers, tests or migration commands.

After separately authorized dependency acquisition, run module verification,
then build with `-mod=readonly -trimpath -buildvcs=false`, explicit output path,
and `-ldflags "-X github.com/supabase/auth/internal/utilities.Version=v2.198.0"`.
Preserve the full source commit separately in the build record; the version
label alone cannot prove it. Fail on any module-file change, checksum mismatch,
unexpected toolchain download, CGO requirement or unsupported Windows code.
Do not install a compiler or patch upstream source to make a failure disappear.

## Expected executable qualification, not execution authorization

Expected output is a PE Windows AMD64 `auth.exe`, not ELF or a renamed Linux
binary. After approved build: record file SHA-256 and size, inspect PE machine
type `0x8664`, available signature metadata and `go version -m` build/module
information, including Go version and GOOS/GOARCH/CGO settings. A local unsigned
build is not an official signed Supabase binary.

The inspected [version subcommand](https://github.com/supabase/auth/blob/v2.198.0/cmd/version_cmd.go)
prints the version; [root command](https://github.com/supabase/auth/blob/v2.198.0/cmd/root_cmd.go)
registers `version` separately, while a bare invocation migrates then serves.
If explicitly authorized later, use ONLY `auth.exe version` for a bounded
identity check, after rechecking exact acquired source. Expect `v2.198.0`, exit 0,
no listener or remaining process. Do not assume `--version` is equivalent.
Clear inherited runtime secrets and use a sterile working directory.
Windows signal/shutdown behavior in [main.go](https://github.com/supabase/auth/blob/v2.198.0/main.go)
still requires later runtime qualification; a successful version check does not
establish service operation or cleanup.

## Runtime configuration and integration dependencies - later gate only

These are required configuration categories, not runnable settings or approved
values. [Configuration source](https://github.com/supabase/auth/blob/v2.198.0/internal/conf/configuration.go)
declares required DB driver/URL, site URL, external API URL and JWT secret.
Future mapping must review `GOTRUE_DB_DRIVER`, `DATABASE_URL`,
`GOTRUE_DB_NAMESPACE`, `GOTRUE_API_HOST`, `PORT`, `API_EXTERNAL_URL`,
`GOTRUE_SITE_URL`, `GOTRUE_JWT_SECRET`, `GOTRUE_JWT_AUD`,
`GOTRUE_JWT_ISSUER`, `GOTRUE_JWT_ADMIN_ROLES`,
`GOTRUE_DISABLE_SIGNUP`, `GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED`,
and bounded DB pool/session/refresh settings. Exact environment precedence and
defaults must be reconciled before startup. Bind loopback only, disable public
signup/anonymous access and outbound providers, and use synthetic secrets only.

The [loader](https://github.com/supabase/auth/blob/v2.198.0/internal/conf/confload/loader.go)
can load `.env` from its working directory when no explicit config is supplied.
Future service launch therefore needs an isolated working directory, explicit
reviewed local config and an allowlisted child environment. Never launch it
from the repository with inherited hosted settings or print configuration.

Existing PG17.12/PostgREST/Deno/Node/browser components do not supply Auth.
`supabase/tests/synthetic_bootstrap.sql:1` is an id-only Auth shim. Do not start
Auth against it. A separately reviewed real Auth schema/bootstrap profile,
narrow Auth database identity, extension requirements and migration ownership
are prerequisites; no application/private grants or A02 exception is implied.
Runtime DB/OS TLS trust and any network egress need explicit qualification.
No mail/SMS, OAuth, external notification destination or real customer data.

`scripts/recovery/serve-local-edge.ts:9` remains loopback-bound and serves the
public recovery module. Actual Owner endpoints need an explicitly reviewed
adapter and real Auth route before integrated acceptance. Their existing
`auth.getUser` calls remain intact (`owner-status/index.ts:84`,
`owner-walkins/index.ts:34`). Do not replace them with fabricated identity
responses. The initial release has Owner-only management, no staff accounts.

## Risks, fallback and approval register

| Gate | Result / required decision |
| --- | --- |
| Source identity and toolchain selection | Identified; Owner must accept candidate version and source-integrity acquisition method |
| Go archive publisher SHA-256 | Available; downloaded-byte verification NOT PERFORMED |
| Auth generated source ZIP publisher SHA-256 | UNKNOWN; checksum-pinned ZIP route BLOCKED |
| Native Windows compile and dependencies | NOT VERIFIED; authorize bounded portable acquisition/dependency verification/build separately |
| Auth service startup and PG17 compatibility | BLOCKED; requires separate schema/privilege/configuration review and execution authorization |
| Owner Auth integrated acceptance | BLOCKED; do not substitute mocks or prior public HTTP evidence |
| Hosted execution / A02 / release | Not authorized; A02 pending; production NO-GO |

If native compilation fails, retain the error and stop. A Linux release requires
a separately approved Linux environment; Docker and new WSL installation remain
outside scope. Keep Owner integration PARTIAL/BLOCKED rather than presenting a
mock server as a fallback. Upstream transitive dependencies and release security
notes need review before runtime use; a checksum is not a vulnerability audit.

Minimum next authorization: Owner selects the source-provenance route and
approves only pinned portable Go/source acquisition plus explicitly bounded
module downloads and a Windows build/identity qualification. That approval
must name destinations, accepted integrity mechanism, no upstream modification,
no system-wide install and no Auth server/SQL execution. Startup, Auth schema
migrations, local identities, integration service operation and all hosted work
remain separate decisions. No approval boxes or signatures are implied here.

## Local completion evidence

Git branch/HEAD/status inspected; original 18 files fingerprinted for bytewise
preservation. `git diff --check` succeeded before this addition (existing Git
CRLF conversion warnings were informational). Final validation checks this
manifest and preservation again. No broad regression suites were run: runtime
source is unchanged and this task authorizes qualification/preparation only.
