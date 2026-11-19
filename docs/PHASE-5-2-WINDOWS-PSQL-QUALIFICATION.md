# Phase 5.2 — Windows psql client qualification

Prepared 2026-11-17. Project `alxhytivwybjbkjjdsyn`, branch `master`.
**Local executable checks PASS. Overall execution qualification BLOCKED pending
Owner connection, CA, privacy and authorization prerequisites. Production NO-GO.**

No database connection attempt, target DNS/reachability probe, authentication,
SQL, installation, database/configuration change, commit, push or deployment occurred. Only this
report is added. No password was requested, read, generated or stored. The
existing [manual guide](PHASE-5-2-MANUAL-DIAGNOSTIC-GUIDE.md) and original SQL/hash
contracts remain unchanged. Prior synthetic database results are historical;
they do not establish hosted TLS or session cleanup.

## 1. Executables actually detected and run locally

Discovery inspected PATH lookup, common PostgreSQL installation locations,
Windows installation registry entries and workspace portable-runtime locations.
This is a bounded inventory, not a scan of every Windows drive/user profile;
inaccessible cache directories prevent an exhaustive claim.

| Exact executable | Observed `--version` | Selection |
| --- | --- | --- |
| `C:\Users\Banco-Sual\Desktop\Trainee Jade\gym\.cache\pg17-portable-17.12\pgsql\bin\psql.exe` | PostgreSQL 17.12 | Recommended explicit client path for the PG17 recovery workflow; Owner must confirm interactive use/control. |
| `C:\Program Files\PostgreSQL\18\bin\psql.exe` | PostgreSQL 18.6 | Installed alternative, not selected or altered. |
| `C:\Program Files\PostgreSQL\18\pgAdmin 4\runtime\psql.exe` | PostgreSQL 18.6 | pgAdmin-bundled alternative, not selected or altered. |

Registry reports PostgreSQL 18 installation `18.6-5`. PATH lookup did not establish
a usable bare `psql.exe`; use the selected full path, not PATH ordering. No PG18
service, data, configuration or executable changed.

Selected psql.exe and adjacent libpq.dll both have PE machine **0x8664 (x64)**.
Observed local identity hashes (not publisher authentication by themselves):

```text
psql.exe   defe034e42d095afead17d91619e202a851b2e66f2c2fca1eb29123059868197
libpq.dll  d87674d536cb8fcc4897f8d6a1c8445675e33447ca0e6ebac210559029f19d04
```

Bundled `libpq.dll`, `libssl-3-x64.dll` and `libcrypto-3-x64.dll` are present.
Static libpq inspection found sslmode, verify-full, sslrootcert, gssencmode and
OpenSSL dependency names. This supports feature availability; strings and DLL
presence alone do not prove a successful certificate validation/handshake.

### Nonconnecting checks actually performed

- All three clients returned their version successfully.
- Selected client `--help` confirmed `-f`, `-v`, `-X`, `-W`, `-o` and `-P`.
- `--help=variables` listed AUTOCOMMIT, ON_ERROR_STOP, ON_ERROR_ROLLBACK, ECHO,
  ECHO_HIDDEN, HISTFILE and VERBOSITY.
- An intentionally invalid command-line option exited **1** before connecting.
  Version/help processes exited **0**. No psql connection or SQL test was used.
- Presence-only inspection found no current process environment values set for
  PGHOST, PGPORT, PGUSER, PGDATABASE, PGSERVICE, PGSERVICEFILE, PGOPTIONS,
  PGPASSWORD, PGPASSFILE, PGSSLMODE, PGSSLROOTCERT, PGGSSENCMODE or PGCLIENTENCODING.
  No environment values or credential/service files were read. This agent process
  is not proof of a future Owner terminal's environment or Windows identity.

## 2. Capability and readiness matrix

| Requirement | Evidence | Qualification |
| --- | --- | --- |
| Native PostgreSQL client/protocol | Actual PG17.12 psql and x64 libpq; PostgreSQL documents its client/server protocol. | PASS for local client capability; actual hosted connection untested. |
| TLS chain and hostname verification | Bundled SSL support plus documented libpq verify-full/sslrootcert behavior. | Supported; target host, trusted CA and live verification BLOCKED/NOT TESTED. |
| Script input, stop on first SQL error | Help confirms options; ON_ERROR_STOP documented. | PASS capability; SQL-error execution not tested in this no-SQL task. |
| Exact transaction control | -f can send the original statements; ON_ERROR_ROLLBACK is explicitly kept off. | PASS design; actual hosted completion untested. |
| Normal/local-error process termination | Version/help exit 0; invalid-option exit 1 observed. | PASS for these cases only; not a cancellation/network-failure demonstration. |
| Same-session cancellation/cleanup | One process/connection per unit; final ROLLBACK on success, disconnect on batch failure. | Documented procedure ready; hosted closure evidence and escalation path require Owner confirmation. |
| Complete private result capture | -o and unaligned/pager-off output supported. | Capability PASS; private directory/ACL/retention and actual result completeness NOT VERIFIED. |
| Owner-controlled execution | Full executable path identified; no Owner credentials/client profile supplied. | REQUIRES OWNER CONFIRMATION. |

PostgreSQL protocol reference: [frontend/backend protocol](https://www.postgresql.org/docs/17/protocol.html).
No protocol compatibility result is inferred from a service-role API key or a
successful frontend login. psql uses database authentication, not browser Auth.

## 3. Connection mode — documented choices, not guessed endpoints

Use the intended project's **Connect** panel privately. Prefer a direct connection
if the Owner confirms its network reachability; otherwise use the documented
shared **session-mode** pooler. Direct connectivity may require IPv6 depending
on the project's configuration; IPv6 availability was not inspected or assumed.
Session mode is the free-tier-compatible IPv4 alternative. Do not buy an add-on,
guess a regional host, use a transaction pooler, or switch modes silently.
Host, port and login differ by mode and must come from the actual Connect panel.
[Supabase connection options](https://supabase.com/docs/guides/database/connecting-to-postgres)

Supabase publishes a psql example using verify-full and a trusted CA path.
The Owner must identify the correct CA chain for the **chosen endpoint**; do not
assume the direct endpoint and session pooler use the same issuer/bundle.
[Supabase psql guidance](https://supabase.com/docs/guides/database/psql)

**Selected mode remains unconfirmed.** No production hostname, port or username
was supplied in this task, so an active connection configuration cannot be
completed truthfully. The project reference alone is insufficient.

## 4. Password-free configuration template for Owner completion

This is an inert template in a report, not a written or active service file.
The Owner may later prepare it outside the repository, cloud-synced folders and
shared locations, under restricted Windows access. No credential may be added.

```ini
[gymforce_phase52]
host=<exact-host-from-approved-project-Connect-panel>
port=<exact-port-for-confirmed-direct-or-session-mode>
dbname=postgres
user=<exact-existing-database-login-for-that-mode>
sslmode=verify-full
sslrootcert=<absolute-forward-slash-path-to-approved-CA-PEM-bundle>
gssencmode=disable
connect_timeout=10
application_name=gymforce_phase52_diagnostic
```

The database name and proposed 10-second connection timeout require Owner
confirmation. They do not change the SQL's 30-second statement/2-second lock
timeouts. Do not add host lists, load balancing, role overrides, startup SQL,
options, password, client private keys or unreviewed extra parameters. Do not
use an IP substitution to work around a certificate-name failure.

`sslmode=verify-full` validates both certificate trust and hostname; an invalid
chain/name must fail. An explicit trusted CA PEM bundle avoids assumptions about
this OpenSSL build's Windows/system trust integration. Acquire the appropriate
CA through an authenticated authoritative route, privately record provenance,
fingerprint, validity and Owner trust acceptance, and confirm the file is readable.
No CA was supplied/read/downloaded and no handshake was attempted. Never fall
back to require, prefer, allow, disable or verify-ca to complete diagnostics.
[PostgreSQL TLS verification](https://www.postgresql.org/docs/17/libpq-ssl.html)

gssencmode=disable ensures the required TLS route is used rather than GSS encryption;
this is a client connection parameter, not a Windows or database security-policy
change. It does not disable TLS. [libpq connection parameters](https://www.postgresql.org/docs/17/libpq-connect.html)

libpq supports private named service files and PGSERVICEFILE. The Owner must
review parameter overrides and ambient settings in their actual terminal; -X
suppresses psql startup files but does not suppress libpq environment/default
files. [Connection service file](https://www.postgresql.org/docs/17/libpq-pgservice.html)

### Credentials — Owner's private interactive prompt only

Use psql **-W** in the Owner's own non-recorded console after separate approval;
type the existing database password only into psql's hidden prompt. Do not put
it in a URI, PowerShell variable, argument, environment variable, service file,
SQL, password file, transcript, shell history, screenshot, clipboard export or Git.
No password should ever be sent to this assistant or entered through its tools.
If the console is recorded or its prompt behavior is uncertain, stop.

Do not use PGPASSWORD. libpq cautions against password environment variables.
Confirm no conflicting automatic credential source/unsafe startup setting is
being relied on without disclosing its contents; do not delete unrelated Owner
credential files. [libpq environment variables](https://www.postgresql.org/docs/17/libpq-envars.html)

## 5. One-unit-per-process procedure — NOT authorized or executed

Keep order **1 → 2 → 3 → 19 → 20 → 22 → 23 → 25**. Use the existing source/hash
table and per-unit prerequisites/output contracts in the manual guide. Six units
are existing files; H01/H02 are embedded SQL blocks. Any Owner-private verbatim
execution copy must preserve its existing hash contract and be explicitly
covered by approval. No SQL extraction/copy was created in this task.

1. Complete section 7 and the diagnostic authorization. Verify the source and
   execution-copy hash offline. Check the target/client/private profile/CA/output
   location; stop if any differs from approval. No new runtime SQL is added.
2. Use the selected absolute psql path, not bare psql. Supply an approved private
   PGSERVICEFILE path only in the Owner process scope; it contains no password.
   Verify/restore any pre-existing process setting privately afterward. Do not
   print the service file, environment values or results through Codex tools.
3. Select one unit file and unique private output file. The output directory must
   already have Owner-approved restricted ACLs/storage/retention and be outside
   the repository; a Git ignore rule alone does not supply privacy. Refuse an
   existing output path rather than overwriting prior evidence. Confirm no console
   transcript/session capture or screen sharing is active.
4. Only under separate authorization, invoke one foreground process as below,
   enter the password privately, and wait. Do not loop over all units, use -c,
   --single-transaction, -q, echo/log options, savepoints or another BEGIN/COMMIT.
5. Immediately record the native exit code privately. Read the complete private
   output and verify final ROLLBACK, expected schema/row counts and no truncation.
   Zero exit alone does not prove data completeness or security acceptance.
6. Stop/clean up as in section 6 on any uncertainty. Review stage-sensitive findings
   before continuing. Missing roles or metadata are UNKNOWN, never permission to
   create prerequisites or assume release PASS. A new process is a new session;
   do not use one process's identity result as proof of another arbitrary profile.

Illustrative syntax only; placeholders make it non-runnable until Owner completion:

```powershell
# Run only in the Owner's private console after approval, never through Codex.
# PGSERVICEFILE must already identify the reviewed password-free private profile.
& 'C:\Users\Banco-Sual\Desktop\Trainee Jade\gym\.cache\pg17-portable-17.12\pgsql\bin\psql.exe' -X -n -W --dbname='service=gymforce_phase52' -v ON_ERROR_STOP=1 -v ON_ERROR_ROLLBACK=off -v ECHO=none -v ECHO_HIDDEN=off -v VERBOSITY=sqlstate -P pager=off -P format=unaligned -o '<unique-Owner-private-result-path>' -f '<one-unchanged-reviewed-unit-file>'
# Inspect $LASTEXITCODE immediately in that private console; nonzero stops all later units.
```

These printing/psql controls do not alter the approved SQL. The original
REPEATABLE READ READ ONLY, SET LOCAL statement_timeout=30s, lock_timeout=2s,
search_path=pg_catalog and final ROLLBACK remain byte-identical. Error rollback
savepoint behavior is off. Expected successful final command is ROLLBACK, not
COMMIT. Local help supports these options; actual hosted execution is untested.

## 6. Failure, cancellation and session-closure rules

| Event | Required procedure |
| --- | --- |
| Normal exit 0 | Require full result and final ROLLBACK acknowledgement, then process exit. A result containing security FAIL is not a release PASS. |
| SQL error / statement or lock timeout | Error-stop must end the batch; do not assume the script's final ROLLBACK ran. Record sanitized SQLSTATE and privately verify disconnect/closure. No automatic retry or timeout increase. |
| Local/file/output error | Stop; protect partial files. Do not run the next unit or overwrite evidence. |
| Ctrl+C / cancellation | Request cancellation once; wait for the known process to exit. Cancellation alone does not prove rollback/disconnect. In the proposed batch mode do not type extra SQL into a password prompt or a new session. |
| Process remains alive | Keep later units held. Use only the Owner-approved narrowly scoped termination/escalation procedure for this diagnostic process; no broad process kill, service stop or new backend-control SQL. |
| Network/TLS/authentication failure | Stop. Never downgrade TLS, substitute host, create/reset a role or retry with a different identity to pass. |
| Connection loss or forced local termination | Local process death/socket closure does not prove the remote backend immediately observed it. Mark closure UNKNOWN until Owner-controlled existing monitoring/support confirms the original diagnostic transaction/session is no longer open. |
| Closure cannot be confirmed | Hold every later unit. A new connection and ROLLBACK cannot clean up an unidentified previous connection. Obtain separate narrowly scoped help; do not assume the 30s statement limit bounds an idle transaction or network outage. |

PostgreSQL documents native exit codes: 0 normal, 1 client failure, 2 lost
noninteractive connection, 3 script error with ON_ERROR_STOP. All nonzero or
abnormal termination is a stop. -o captures query output without a UI grid limit;
private disk capacity and actual full content still need checking. -W supplies
the password prompt. The controls are documented, not a newly executed SQL/
network/cancellation test. [PostgreSQL 17 psql](https://www.postgresql.org/docs/17/app-psql.html)

Server termination/rollback and a client's local exit are distinct evidence:
[PostgreSQL connection termination](https://www.postgresql.org/docs/17/protocol-flow.html#PROTOCOL-FLOW-TERMINATION).
No pg_cancel_backend/pg_terminate_backend query is added to the exact scope.

## 7. No-SQL qualification checklist and Owner prerequisites

| Check | Current result / required Owner action |
| --- | --- |
| Exact PG17.12 executable/version/architecture and basic exit behavior | PASS locally; Owner confirms they can use this exact binary in their own console and verifies identity hashes before use. |
| Documented TLS/protocol/transaction/error-stop features | PASS capability review; live negotiation/SQL behavior NOT TESTED here. |
| Intended project | Owner-confirmed intent `alxhytivwybjbkjjdsyn`; actual connection target still requires private confirmation. |
| Direct versus shared session mode | Owner chooses using actual Connect settings; actual IPv6/routing not established. |
| Host, port, database, existing login and no role override | REQUIRES OWNER CONFIRMATION; no actual endpoint/identity configuration supplied. |
| verify-full and correct endpoint CA | REQUIRES OWNER CA path/provenance/trust approval; actual handshake remains untested until authorized. |
| Password-free service profile / clean Owner terminal environment | Template prepared, not written/activated; Owner reviews privately. No password sharing or new database login. |
| Result directory, ACLs/encryption, custodian and authorized viewers | REQUIRES OWNER CONFIRMATION; no private storage was inspected or created. |
| Retention/disposal, provider/log/history handling | REQUIRES OWNER DECISION; no raw metadata export approved implicitly. |
| Same-session closure/escalation operator and evidence | Procedure prepared; REQUIRES OWNER CONFIRMATION of actual observable cleanup route. |
| Exact eight-unit hashes/copies/order and date/window in Asia/Manila | Existing contracts retained; REQUIRES explicit scope/window approval and pre-execution hash recheck. |
| Sanitized reporting | Status/category/counts and approved identifiers only; no full output through Codex or Git. Owner accepts restrictions. |
| Separate execution authorization and no-SQL pre-flight | NOT COMPLETE. No connection authorized by this report. |

Private capture is technically supported; confidentiality is conditional on the
Owner's storage and console controls. Verify six complete JSON cells (units 1,
2, 3, 20, 23, 25), all 91 marker rows (19), and all ten screen rows (22) against
the guide. Do not print those results here. Return only the approved sanitized
template from the manual guide; even OIDs, fingerprints, role graphs and routine
signatures remain sensitive. No credentials/personal/financial records are needed.

## 8. Decision and exact next action

**Client binary capability: PASS as inspected. Overall qualification: BLOCKED.**
Missing endpoint/CA/identity/storage/closure approvals prevent a fully populated
secure profile and hosted readiness claim. Supported features do not equal a
verified target connection or proven remote cleanup.

**Next action:** Owner privately completes the password-free direct/session
profile and CA/storage/cleanup fields above, and supplies only confirmation or
private references with the exact eight-unit window/scope approval. Never send
the database password. Then review authorization in a no-SQL pre-flight before
any separately instructed connection/execution. Stop here; production remains NO-GO.
