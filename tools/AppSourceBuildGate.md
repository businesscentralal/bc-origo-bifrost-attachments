# AppSource build gate (#78)

The shipping build must provide actual final compiler settings, a complete clean
compile, compiled NAVX identities and current-run hook receipts. A setting file or
source-only friend removal is insufficient. `PipelineInitialize` preserves the
existing Default friend/AS0081 stripping and the Alpaca initialization.

`PipelineInitialize` explicitly installs the real Run-AlPipeline
`CompileAppWithBcCompilerFolder` callback using Alpaca's parent-context scope
mechanism; AL-Go v9.2 does not auto-register that filename. An existing compiler
override blocks replacement pending its owner's coordination.
The callback snapshots the real symbol directory **before**
the helper copies its newly built product there. It forwards the original helper
parameters and output callback and retains an isolated compiler log.
`PostCompileApp` receives the returned package, app type and final compilation
parameters, checks the intended CodeCop, UICop and AppSourceCop flags and
`failOn=warning`, and captures executable/cop/helper hashes before cleanup.
`PipelineFinalize` requires all expected product/test receipts and matches them
to the actual `.buildartifacts/Apps` and `TestApps` outputs. Translation precompiles
are classified separately and cannot substitute for a final compile receipt.

The reader accepts the genuine compiler's NAVX v2 40-byte header and its declared
ZIP payload, checks CRCs and unique manifest/entries, and compares AppId, publisher,
name, full version, source commit and compiler identity. Default carries no friend
grants. The Test product carries exactly the existing Attachments test friend;
the test app carries none. Final output content must match the compile receipt.
An arbitrary ZIP, `.app` filename, signature tail or stale output cannot pass.

The current approved Foundation input is main
`336b91d9fff11b71ae5cd75dee08186d4218bf07`, run `37544940349`, attempt 2,
`Origo_Bifrost Foundation_28.0.2.523.app`, SHA256
`5901bebe66b44e91ed6110620e62ee45d122ba9e0378dcfda4aeef4d00d3ae0f`.
The actual precompile inventory must contain these exact bytes, with zero product
self-app inputs. Test must use the exact just-built product. Changing the approved
input requires a reviewed tooling change; the app dependency floor remains
**28.0.1.0**. Symbol inventories are independent of the donated manifest guard.

Run/attempt/job, checkout SHA, compiled-source SHA, build mode, script hashes,
package/content digests and source hashes are retained in sanitized JSON under
`.buildartifacts/AppSourceGate/<mode>`. The checkout can be a synthetic PR merge;
the manifest's compiled-source commit is checked independently. Existing receipts
cannot be reused. Missing/displaced hooks, truncated later logs, disabled cops,
fallbacks, workspace compilation and unsupported compiler collection fail closed.
Container-only compilation needs a supported identity collector before acceptance.

## Infrastructure and acceptance holds

The concrete workflow patch is an external review artifact, **not applied here**.
It runs `Assert-AppSourceBuild.ps1 -Stage Pipeline` immediately after RunPipeline,
then `-Stage Signed` immediately after the existing Sign action when shipping
signing is intended. It preserves signing selection, action pins and credentials.
Windows `Get-AuthenticodeSignature` must return `Valid` for the actual NAVX output
with a signer certificate and supported SIP/trust; absence or an unsupported
provider is a blocker. Signing is allowed to change whole-package bytes, but
must preserve every package entry/manifest. No synthetic signature success is
used by the tests. Failed builds retain the original failure and upload sanitized
receipts only.

PR84 / worker-3 is the sole product/test compile repair. PR87 remains donor-only
on its explicit hold; its branch is not merged. PR91 has separate pipeline
ownership. This tooling implementation does not release infrastructure, runtime,
QA, input/access or publication holds. Actual product/test analyzer builds with
0 errors / 0 warnings, all guards, owned serial COSMO unit/MCP/UI verification and
verified deletion remain required after PR84 merges and integration is approved.

## Tooling regressions

Generate isolated genuine NAVX fixtures with the installed compiler and run:

```powershell
./tools/New-AppSourceGateFixtures.ps1 -CompilerDll <actual-alc.dll> -Dotnet <dotnet> -OutputFolder <temporary-fixture-folder>
./tools/Test-AppSourceBuildGate.ps1 -FixtureFolder <temporary-fixture-folder> -FoundationPackage <approved-523.app>
python -m unittest discover -s tools/tests -p test_build_inputs.py -v
```

Missing real packages fails the fixture suite, never skips it. The isolated
`tools/fixtures` codeunit is never included in the product/test apps and consumes
no product allocation. Those compiles exercise NAVX/tooling behavior; they do not
claim product, effective-analyzer, BC runtime or signature-trust certification.
The eight donor tests remain unchanged and hash-pinned to PR87's approved source.

## Isolated Foundation staging (#78 input continuation)

`stage_foundation_inputs.py stage --input request.json --destination <fresh-dir>`
validates the already downloaded immutable Apps/TestApps archives and exact
allowlisted provenance, then extracts into distinct `Apps/` and `TestApps/`
directories. It writes `selection.json`, `helper-inputs.json`, `installApps.json`
and `installTestApps.json`. No downloads, helper installation or hook changes
occur. Maximum 128 files and 128 MiB per inventory/archive; flat `.app` artifact
entries only. URLs, GUIDs, wildcard inputs and symlinks fail closed and need an
explicitly reviewed adapter; they are never silently dropped.

The signed Foundation Apps pin remains
`5901bebe66b44e91ed6110620e62ee45d122ba9e0378dcfda4aeef4d00d3ae0f`,
source `336b91d9fff11b71ae5cd75dee08186d4218bf07`, run `37544940349`,
attempt 2, Apps artifact `11459147009`, with zero friends. Only the exact
same-AppId Foundation product collision from TestApps artifact `11459677378`
is excluded. All distinct genuine dependencies remain; parenthesized test
inputs retain the helper's skip-test-execution marker. Default/Test Attachments
friend stripping and dependency floor are untouched.

The request contains `context` (run, attempt, sourceCommit, checkoutSha, mode),
`artifacts` keyed Apps/TestApps (archive path and provenance fields repository,
sourceSha, run, attempt, artifactId, archiveSha256, expired, conclusion), and
optional explicit local-file arrays `otherApps`/`otherTestApps`. This is a
caller-provided provenance contract checked against the immutable pins, not an
independent live API or signature-trust attestation. Pipeline owner must supply
actual authorized API metadata and current run identity.

`validate --input consumed.json --destination <staged-dir>` rehashes actual
`installApps` and `installTestApps` arrays against the current-context receipt
and both archives. Optional `symbols` verifies the exact Foundation consumed
by compilation. Call validation before helper installation and again with real
compiler inputs. Changing a package, omitting/reordering/substituting an input,
wrong provenance or stale/missing receipt fails. `rejected-input.json` captures
allowlisted on-disk hashes/identity before the existing precompile failure;
it does not convert a failed gate into success.

AL-Go v9.2's `Resolve-DependencyFiles` extracts/copies both archives into one
folder before RunPipeline. RunPipeline reads both JSON arrays before calling
Run-AlPipeline. Helper initialization precedes dependency installation, but
cannot recover overwritten signed bytes without separately retained Apps.
Alpaca publication also scans `.dependencies` independently of compiler symbols.
A compiler-folder copy alone cannot certify install/probing inputs. Integration
must preserve isolated archives and replace the actual arrays before these
consumers; the review-only owner patch documents that boundary. No supported
whole-hook runtime integration has been established or applied. PR91 remains
with its separate physical owner; precise owner pickup and infrastructure
approval are required. Workspace compilation remains blocked separately.

Run `Test-FoundationStaging.ps1` with both genuine archive paths available under
its artifact folder and the compiler-produced fixture folder. Fixture tests
prove utility selection and refusal behavior, not product compile/runtime,
signature trust, live runner arrays or independent review acceptance.
