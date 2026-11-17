# Source-integrity line-ending portability

Prepared 2026-11-17. Input master HEAD
`1566c92e92a3f5f562225ddd40672bd4884f0879`; remote master was
`38fdf66791a52c12cd45068d979d126d704b5f7b`. Production remains NO-GO.

## Root cause and proven representations

The original source manifest captured working-tree bytes, not a uniform canonical
representation. System Git configuration enables core.autocrlf=true. Switching
branches converted 21 Edge entrypoints and one shared module to CRLF, invalidating
their working-byte hashes even though the committed LF blobs were unchanged.
The earlier raw-byte implementation therefore depended on checkout history.

Comparison against the exact committed input identified:

| Manifest inventory | Existing expected SHA-256 represents |
| --- | --- |
| 37 migrations | 19 exact LF Git blobs; 12 full CRLF checkouts; six mixed LF/CRLF checkouts. |
| 21 Edge entrypoints | All 21 exact LF Git blobs. |
| 17 shared runtime modules | All 17 exact LF Git blobs. |

All 18 migration checkout representations were proven using the still-existing
reviewed working files: each matched its original expected SHA-256, and replacing
only CRLF pairs with LF reproduced its committed blob exactly. Mixed layouts
were not guessed to be uniformly CRLF. Their exact one-based CRLF line positions,
and the 12 all-CRLF layouts, are recorded in
`scripts/recovery/source-byte-policy.json`. This is an explicit representation
bridge, not a replacement hash catalog. Existing manifests and expected hashes
are unchanged. BOM bytes are retained, including existing UTF-8 BOMs.

## Canonical method and guarantees

`scripts/recovery/source-bytes.mjs` uses exact **LF Git blob bytes** as the
repository canonical representation. It reads HEAD:path without text conversion
and requires that blob to contain no CRLF pairs. The actual working file, with
only CR removed from CRLF pairs, must equal that blob byte-for-byte. Dirty content
does not disappear merely because the committed file is trusted.

To compare to an existing expected digest, the verifier reconstructs only the
explicitly recorded legacy line layout from the canonical bytes, then computes
SHA-256 and requires the unchanged expected digest. Unlisted files use LF. The
line map is validated, sorted, unique and bounded by actual source line endings.
There is no try-every-normalization heuristic, hash refresh, BOM stripping,
whitespace trimming or SQL-body alteration. Non-newline content, spaces, tabs,
final newlines, lone CR and arbitrary byte changes still fail.

An isolated source archive with no .git at its root verifies the same unchanged
pinned digest from LF-canonical working bytes and the explicit layout. The
clean-room harness intentionally uses that mode. If .git exists, invalid Git
root/access/object errors fail closed; they never fall back to archive mode.
Missing historical objects are not required: HEAD supplies current source blobs,
while the unchanged digest and layout pin their reviewed content. The recorded
reviewedCommit identifies the evidence origin, not a request to rewrite history.

The builder reads canonical source input, preventing new artifact fingerprints
from depending on checkout layout. Existing generated SQL and manifests must
remain byte-identical. The compatibility test verifies original migration
fingerprints through the same reviewed-byte bridge rather than hashing an
arbitrary working-tree encoding.

Scoped .gitattributes fixes LF checkout for scripts, tests, recovery artifacts,
the parser tools and preflight diagnostics. It does not renormalize or edit
historical migrations or application source. Current tooling/artifact checkout
copies were restored to their exact existing Git blob bytes only after proving
CRLF-to-LF equality. That caused no tracked SQL or manifest changes. Global and
repository core.autocrlf configuration was not changed.

## Verification and release boundary

Focused regressions cover both LF and CRLF representations of all 75 source
files, all 18 legacy mappings, altered content/digests, BOM removal, whitespace,
lone CR and final newline changes. A real ignored isolated Git repository tests
HEAD-versus-dirty-file rejection and committed unauthorized content. Synthetic
fixture commits affect only that disposable repository, not project history.

Commands used for acceptance:

```powershell
node scripts/recovery/validate-source.mjs
node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-tooling.test.mjs tests/recovery-integrity.test.mjs
node docs/production-preflight/sql-editor/validate.cjs
node scripts/test-recovery-reproducibility.mjs
npm.cmd run lint
npm.cmd run typecheck
npm.cmd test
npm.cmd run test:security
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility
git diff --check
```

The final Git handoff reports actual results, commit SHA and remote verification
after checks complete. No production SQL, migrations, permissions, provider
configuration, feature activation or deployment is part of this correction.
Owner reconfirmed that saved automatic production deployments remain disabled
and no other integration deploys master on push. GitHub trigger metadata is
rechecked before push. This is Owner-supplied Cloudflare evidence, not a claim
that an authenticated Cloudflare API inspection occurred.

Fresh acceptance evidence: 37/37 migration fingerprints, 21/21 Edge entrypoints
and 17/17 shared modules pass with the existing expected hashes; the source
validator distinguishes HEAD-blob checks from pinned source-archive checks in
its output. All 23 recovery tests (including seven portability regressions),
38 application Node tests, lint, typecheck, source security and the 16 SQL Editor
variant checks passed. Clean-room evidence `.cache/parser-repro-Coue1z` passed
all 23 tests and preserved every byte of the 42 existing SQL/manifest artifacts.
The final HEAD/archive count reporting change is logging/summary-only; the
hash/representation and generator checks are the same as in that clean room.

PG17 evidence `.cache/security-test-0ee217b471904a46895edb5a9bbf44d6` reports
17.12/170012, complete customer compatibility replay, nine concurrency scenarios,
eleven legacy refusals, rollback/RLS/ACL/default/inherited-denial checks and ten
final privilege screens. Server stop, removed credential/PID markers and zero
temporary authority leaks were verified separately. These are synthetic local
results, not evidence of hosted Supabase compatibility. No historical migration,
application source, existing source/compatibility manifest or reviewed diagnostic
SQL was changed. A separate correction commit and ordinary master push require
the final clean-tree and remote-state gates described in the handoff.
