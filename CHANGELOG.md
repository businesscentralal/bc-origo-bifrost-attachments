# Changelog

All notable changes to Bifrost Attachments are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this app uses
Business Central release versioning (`major.minor.build.revision`).

## [Unreleased]

### Fixed (2026-10-07) - bounded build-input evidence (#78)

- Separate the complete compiler catalog from the resolved app cache in `tools/appsource_gate.py`, stream bounded NAVX hashes/CRC checks, and compare genuine helper additions with dependency resolution. Keep complete sanitized measurements and explicit failure truncation. No AL objects or IDs change. Add an internally reviewed exact-hash BC29 Base Application resource profile and exact immutable Apps530 Foundation candidate/staging profile; retain523as a separate controlled fixture and reject the same-version TestApps collision. Exercise every manifest identity field with genuine Base and Foundation bytes, and align the documented catalog/cache and profile limits. Pipeline/signing settings and actual Windows runner/runtime/trust gates remain unchanged.

### Fixed (2026-10-07) - canonical compilation and regression fixtures (#74)

- Isolate `Attachments Build Tests ori` (96274) fixture keys across dispatcher calls, create valid Data Exchange header/line/field relationships for the direct license-refusal check, and use standard XMLport 1225 exported XML for the import-refusal fixture. Preserve all response and persisted-state assertions; runtime verification remains required.
- Persist the two license-refusal fixtures in `Attachments Build Tests ori` (96274) before `asserterror`, so error rollback cannot remove their setup. Preserve license and row-content assertions, verify the exported definition remains, and delete only each test's fixture afterward. Amended runtime verification remains pending.

### Fixed (2026-10-06) - main AL compile failures after #68 and #73

- Restore Microsoft symbol resolution in `Storage Data Restriction ori` (10035663), `DataExch Type Set Impl ori` (70013531), `DataExch Export Run Impl ori` (70013534) and `DataExch Def Export Impl ori` (70013536) by importing the namespaces that own their tables.
- Remove codeunit ID collisions: `DataExch Entry Del Impl ori` uses 70013544 and `DataExch Def Import Impl ori` uses 70013545. Existing Help Get (70013521) and Type List (70013524) keep their IDs. Correct colliding message-type ordinals in `DataExch Import MsgType ori` (70013511, Import.Run 70013522) and `DataExch DefDel MsgType ori` (70013514, Definition.Delete 70013523); message names and implementation bindings stay the same.
- Use standard XMLport 1225 (`Imp / Exp Data Exch Def & Map`) for the existing unregistered `DataExch Def Import Impl ori` (70013545), retaining UTF-8 input. Protect both `Data Exch.` incoming-document relationship fields in the existing unregistered `DataExch Entry Del Impl ori` (70013544), including stale pointers.
- Shorten enumextension 70013519 to `DataExch Export MsgType ori`; retain `DataExchange.Export.Run` ordinal 70013519, its locked caption and all interface bindings. Align touched AL filenames with their declared names.
- Adopt `Attachments Build Tests ori` (96274) from PR87 with its five existing contract/dispatch tests, and add registered-message persisted-state and unlicensed direct-interface regressions. Correct the three `Force=false` calls in `Storage Link Guard Tests` (96214) and `Storage Upload Tests` (96205), and align dispatcher response buffers with Foundation's `Text[100]` signature. No test-only registration or licensing bypass is added; complete licensed direct-interface/runtime verification remains pending.
- Add `tools/Test-UniqueObjectIds.ps1` to detect duplicate object IDs and duplicate value ordinals across extensions of the same enum, with synthetic positive and negative cases. The free-ID ledger in `.claude/CLAUDE.md` records the repaired allocations.

### Fixed (2026-10-06) - compilation inputs (#74)

- Resolve Microsoft Data Exchange tables through `System.IO` in `DataExch Type Set Impl ori` (70013531), `DataExch Export Run Impl ori` (70013534), and `DataExch Def Export Impl ori` (70013536).
- Add `Attachments Build Tests ori` (96274) for existing Data Exchange dispatch, stored results, and refusal paths. Add a build-input guard for duplicate object IDs, overlapping enum ordinals, unallocated IDs, self dependencies, and the Foundation 28.0.1.0 floor, with synthetic regression fixtures.


## [28.0.0.4] — 2026-10-07

### Fixed

- `Storage Contract Parts ori` (70013500) removes unused storage requirements from Data Exchange queries and record uploads, documents conditional attachment sources and accepted address aliases, and adds shared shipped Data Exchange mutation chapters for integration by #82.
- `Data Exchange Query ori` (70013520) collects malformed filters, flags, dates and paging values before querying, refuses overlong codes and page sizes above 1000, preserves the zero/default page size of 100, and returns localized actionable error details.
- Read/query discovery wording is localized in `DataExch Def List Impl ori` (70013522), `DataExch Def Get Impl ori` (70013523), `DataExch Type List Impl ori` (70013524), `DataExch Entry List Impl ori` (70013525), and `DataExch Entry Get Impl ori` (70013526). `Storage Contract Batch2 Tests` (96216) adds #69 contract and full-dispatch regression coverage; exact-tip execution and final XLF integration remain verification gates.


### Fixed (2026-10-06) - retry skipped legacy take-over on upgrade (#76)

- `Storage Link Upgrade ori` (10035683) retries the permission-probed `Storage Takeover ori` (10035676) on every company upgrade, before checking the orphan-purge tag. A denied probe remains telemetry-only; a later permitted upgrade can copy legacy data and re-grant roles. Existing destination data and assignments retain the take-over routine's preservation rules. Generated mapping and grant code are unchanged.
- `Storage Takeover Probe Tests` (96210) covers tagged and untagged upgrades, both legacy read-denial paths, denied-then-permitted role re-grant, idempotent retry and populated destination preservation with the existing probe seam. Untagged denial still purges only invalid links and records the purge tag; later retries preserve that one-time boundary. Absent-legacy no-op fixtures explicitly require no residual legacy roles. Genuine restricted-identity install/upgrade and legacy-data lifecycle certification remain required; seam tests do not certify permissions.

### Fixed (2026-10-06) - localized storage refusals (#72)

- Translate response prose and expected-value conjunctions in `Storage Upload Mgt ori` (10035665), `Storage Attachment Mgt ori` (10035635), and `Storage Request Mgt ori` (10035662), preserving embedded wire tokens.
- Harvest the existing Icelandic connection-test messages into source comments in `Storage Setup ori` (table 10035636). Add bilingual dispatch regression cases to `Storage Error Response Tests` (96212) and setup-action TestPage cases to `Storage Setup Page Tests` (96207).
- Correct the agent instructions to locate the archived Foundation takeover generator; generated takeover source remains subject to its separate owner and generator approval.

### Fixed (2026-10-06) - attachment path integrity (#75)
- #75 source continuation: `Storage Ext File Impl ori` (10035661) validates verified Azure account metadata and Blob/File Share address budgets; `Storage Request Mgt ori` (10035662), `Storage Request Reader ori` (10035682) and `Storage Attachment Mgt ori` (10035635) preserve case, protect disabled/root/account aliases, derive each moved link's relative path and check installed native field capacity. External linked moves and unresolved provider capabilities remain explicitly fenced in this incomplete draft; runtime and provider recovery are not certified. `Storage Integrity 75 Tests ori` (96225), `Storage Mock Impl` (96200) and `Storage Mock State` (96201) add real-operation alias and copy-fault readbacks plus provider boundary validation tests.

- `Storage Request Mgt ori` (10035662), `Storage Request Reader ori` (10035682) and `Storage Ext File Impl ori` (10035661) use a shared outer-slash identity, reject unsafe paths, and validate complete base-prefixed addresses. Raw create/copy/move and upload commit refuse attachment-backed destinations with an actionable error; copy/move onto the same canonical source is also refused.
- `Storage Attachment Mgt ori` (10035635) matches legacy slash-spelled links, validates generated offload paths and complete filenames before writes, and prepares link/native path updates before a remote move. `Storage Upload Mgt ori` (10035665) validates names and generated paths before inserting a session and rechecks linked targets before commit.
- `Storage Mock Impl` (96200), `Storage Mock State` (96201) and `Storage Integrity 75 Tests ori` (96225) exercise slash/base resolution, protected destinations, retained upload sessions, path/name boundaries and pre-write connector failure rollback. Runtime verification and provider-specific limit/case policy remain release blockers; this entry does not certify AppSource readiness.

- `DataExch Import Run Impl ori` (70013540) and `DataExch Def Delete Impl ori` (70013543) collect complete input refusals before changing data. `Storage Request Reader ori` (10035682) adds strict mutation readers that reject wrong JSON types, raw values beyond their bounds, and code spellings that Business Central would uppercase or trim. Import remains header-only and deletion preserves reference checks and standard triggers (#82).
- `DataExch Refusal82 Tests ori` (96226) adds dispatched happy/error/boundary, reference readback and postwrite rollback tests for these two operations. ExportRun/TypeSet integration and runtime acceptance remain separately gated; this source change is not release certification.


### Added (2026-10-07) - restricted-role regression preparation (#79)

- Test codeunit `Storage 79 Perm Tests ori` (96218) adds 28 `TestPermissions = Restrictive` regressions for the setup card, setup I/M/D refusal, account discovery, files/directories, upload state and bytes, native creation/offload/open/restore, and shipped Data Exchange discovery/read/write denial. Dedicated test permission sets `Storage79 Test/Setup/Source/Target/Link ori` (96218–96222) and `Storage79 Entry/Column/Def/Field/FldMap/Line/Map/Type ori` (96227–96234) isolate the effective grants without changing product roles. The test app declares its Microsoft Permissions Mock dependency.
- `test/permissions-79.md` records the least-role matrix, actual Foundation API role union, observer versus actor phases, and outstanding canonical PR84, genuine SaaS/provider/legacy and release gates. All existing broad disabled suites are preserved. These are authored regressions; runtime verification is pending, and they do not certify real identities or provider permissions.

### Changed (2026-10-07) - AppSource build evidence (#78)

- Add bounded immutable Foundation Apps/TestApps staging, deterministic helper-file selection, substitution/stale-receipt checks and sanitized rejected-input receipts. Preserve signed Apps bytes and remove only the exact Foundation product collision from test inputs. Genuine collision fixtures cover both download orders and modes; PR91 pipeline application and real verification remain blocked. No AL objects or IDs change.

- Enable CodeCop, UICop and test-app analyzers with `failOn=warning`; add compiler/package hooks and tooling that reject incomplete compiles, wrong inputs, stale receipts and surviving compiled Default friend grants. Preserve the exact Test friend and existing signing policy. Integrate PR87's hash-pinned allocation/dependency guard and all eight regressions. No product AL objects or IDs change. Workflow application, actual product/runtime verification and release readiness remain blocked pending PR84 and infrastructure approval; see `tools/AppSourceBuildGate.md`.

## [28.0.0.4] — 2026-10-06

### Fixed (2026-10-07) - API audit attribution (#77)

- Distinguish provider table `Storage Setup ori` (10035636) from UI page `Storage Setup ori` (10035637); label consumer counts as bounded lexical matches and guard matrix identity/attribution. Preserve all AL access and the publication/registration hold.

### Added (2026-10-06) - AppSource API audit (#77)

- `API-SURFACE.md` and the object/procedure inventories record the shipped AL contract and consumers. `Storage Connector ori` (interface), `Storage Type ori` (enum 10035636) and `Storage Setup ori` (table 10035636) remain public; the provider enum remains extensible. Proposed access reductions for `Storage Attachment Target ori` (enum 10035635) and `Storage Upload Status ori` (enum 10035637) are held pending authoritative publication/baseline and consumer evidence. No AL surface or IDs change.
- Release checklist #83 must obtain authoritative registration for both 10035635–10035684 and 70013500–70013549 plus the `ori` affix. Source declarations and catalog absence do not establish registration. Product/test compilation and runtime verification remain dependent on current-main repair #74 and a usable Foundation package.


### Changed (2026-10-07) - AppSource working-material evidence (#81)

- Refresh the approved internal submission workspace with Foundation 28.0.2.523 provenance, source/asset hashes and issue/PR input owners. Preserve immutable internal-QA and explicit release gates for formal scenarios and the smoke dry-run. No AL objects or IDs changed.

### Added (2026-10-06) - AppSource submission planning (#81)

- Add the Attachments release checklist, independent scenario coverage plan, source market inventory and gated validator sandbox smoke script in `app/docs/appsource/`. Formal scenarios await internal QA. No AL objects or IDs changed.
- Record Gunnar's confirmed new-offer plan: Attachments has no Partner Center offer or existing product ID. Keep `deliverToAppSource` unconfigured until separately authorized offer creation supplies the genuine Attachments ID; creation, submission and publication remain outside #81. No AL objects or IDs changed.

### Changed (2026-10-05) - align with Bifrost Foundation 28.0.1

- The Foundation dependency floor is **28.0.1.0** in `app/app.json` and `test/app.json`, the same floor Bifrost Language Models uses for Foundation 28.0.1. Every 28.0.1.x build is accepted.
- Every table and page now declares `Extensible`. The ones nothing extends are `Extensible = false`; opening one later is non-breaking. `Storage Type ori` stays `Extensible = true` because connector apps extend it.
- `tools/` carries Foundation's source guards (copied from the Language Models alignment, pointed at this app). `Test-HelpLinks` defaults to `attachments`. The Source Guards workflow runs the checks that already pass on this app: no call stack in answers, validated table views, no obsolete, permission coverage, and Icelandic keyword counts. Contract-parameter and mixed-language guards are in `tools/` but not in the workflow yet: shared contract chapters declare keys list types do not read, and several Locked telemetry labels predate that rule. Help Links is not wired in: `businesscentralal/bifrost` main has no `help/attachments` folder yet.
- `.claude/CLAUDE.md`, `AGENTS.md` and the README now name Foundation 28.0.1.0 and the published `attachments` help route, not `hnitbjorg`.
- Document Attachment offload, born-offloaded create and restore now mirror BC 28 `Stored Externally`, `External File Path`, `External Upload Date` and `Stored Internally` when Microsoft's External Storage - Document Attachments app is installed (#11). The link table is unchanged. Incoming documents are not mirrored. Generic `Data.Records` writes to fields 8750-8753 are blocked. A failed mirror is logged as `BFA-EXTSTOR-01` and does not fail the offload or restore.
- Icelandic discovery keywords for `Storage.Upload.Begin`, `Storage.Upload.Commit` and `Storage.Directory.Exists` now have one entry per English keyword (attachments#10).

### Changed (2026-10-04) - CI/CD builds only main; every pull request gets a Pull Request Build

- Build policy only, no app change. `CI/CD` runs on pushes to `main` only, and `Pull Request Build` runs for pull requests into any branch. `.github/AL-Go-Settings.json` sets `CICDPushBranches` to `main` and `CICDPullRequestBranches` to `**`, so Update AL-Go System Files keeps the triggers.



### Issue #72 source localization continuation
- Correct placeholder metadata ordering in "Storage Upload Purge ori" (10035679) so Icelandic purge notifications retain the existing sentence without English placeholder notes; final generated XLF remains with worker7.
- Localized descriptions and selection prose in "Storage Account List Impl ori" (10035639), "Storage Att. Offload Impl ori" (10035641), "Storage Att. Restore Impl ori" (10035642), "Storage Attach Link Impl ori" (10035640), "Storage Attach Record Impl ori" (10035667), "Storage Dir Create Impl ori" (10035644), "Storage Dir Delete Impl ori" (10035645), "Storage Dir Exists Impl ori" (10035646), "Storage Dir List Impl ori" (10035647), "Storage File Copy Impl ori" (10035648), "Storage File Create Impl ori" (10035649), "Storage File Delete Impl ori" (10035650), "Storage File Exists Impl ori" (10035651), "Storage File Get Impl ori" (10035652), "Storage File List Impl ori" (10035653), "Storage File Move Impl ori" (10035654), "Storage Help Get Impl ori" (10035655), "Storage Upload Abort Impl ori" (10035656), "Storage Upload Append Impl ori" (10035657), "Storage Upload Begin Impl ori" (10035658), "Storage Upload Commit Impl ori" (10035659), "Storage Upload Commit Rec ori" (10035669), "Storage Upload Status Impl ori" (10035660). Public wire names, enum values and implementation bindings are unchanged.
- Added English/Icelandic exact production-interface discovery assertions to "Storage Error Response Tests" (96212), and aligned its response content type with the real Foundation Text[100] signature. Final XLF remains worker7-owned; runtime/compiler/guard acceptance is blocked pending canonical PR84 and other owner deliveries.


### Removed (2026-10-01) - markdown help procedure (#61)

- Every message type codeunit drops `GetMessageHelpAsMarkdownDocument`. Foundation removed it from `Msg Interface ori` (core#198); help is the contract chapters that `Help.Implementation.Get` returns. No chapter changed.
- Bifrost Foundation dependency raised to 28.0.0.186, the first Foundation build without the procedure, in `app/app.json` and `test/app.json`.
- The metadata tests in `Storage Connector Tests` and `Storage Upload Tests` iterated the legacy Cloud Events ordinals (72620-72641), so they ran no assertion. They now cover the real message types: direction, description, contract present, response chapter and `storageCode` parameter.
- AGENTS.md, README.md and .claude/CLAUDE.md describe contracts instead of the deleted domain help codeunits; freed ids 10035643 and 10035670-10035675 are recorded.

### Changed (2026-10-01) - external storage writes declare effect irreversible (#65)

- `Storage.File.Create`, `Storage.File.Copy`, `Storage.File.Move`, `Storage.Directory.Create`, `Storage.Upload.Commit` and `Storage.Attachment.Offload` now declare effect `irreversible`: they write to the external storage outside the Business Central transaction, so the Orchestrator's Omit Commit guard refuses them in a rollback chain.
- The effect `changes` text now says what each type changes: the external store, Business Central records only, or nothing.

- **Message type contracts, Batch 1** (`Help.Storage.Get`, `Storage.Account.List`, all
  `Storage.File.*` and `Storage.Directory.*` types): added structured contract chapters
  and contract validation tests.
- **Message type contracts, Batch 2** (Attachments, Upload and DataExchange types): added
  structured contract chapters, bilingual discovery keywords and contract validation tests.
- **Foundation CI probe** (`.AL-Go/settings.json`): the `bc-origo-bifrost-core` `appDependencyProbingPaths` entry uses `"version": "latest"` (`release_status` stays `latestBuild`), so the app builds against the latest Foundation CI build with a Foundation floor of `28.0.0.0`.
- **Install permission-probe diagnostics** in `Storage Takeover ori`: the `WriteDeniedErr` and `ReadDeniedErr` texts are now `Locked` labels. The text is identical, and they only feed telemetry, so there's no translation (xlf) change.
- **Page help links** (`ContextSensitiveHelpPage` on `Attachments Setup ori` and `Storage Conn. Part ori`) now use the renamed docs route `attachments-setup` (`hnitbjorg-setup` renamed to `attachments-setup`).
- **`app.json`**: `help`, `privacyStatement`, `EULA` and `contextSensitiveHelpUrl` now point at the published Bifröst docs (`attachments` routes and Foundation privacy/EULA); `applicationInsightsConnectionString` now uses the shared Application Insights connection string.

### Fixed (2026-09-30) - pin Foundation to 28.0.0.166 (#63)

- The app and the test app are both pinned to Bifrost Foundation 28.0.0.166. Contract batch tests resolve message types with `Enum::"Message Type ori".FromInteger`, so the test app compiles against that pin.

### Fixed (2026-09-29) - Restore main build after #45/#47 AddError conflict (#55)

- `Storage.Directory.Delete` and `Storage.File.Delete` help pass an error code and a resolution to `AddError`, so those calls compile against the three-parameter form.
### Fixed (2026-09-29) - help names current tools and characters (#12)

- `Help.DataExchange.Get` tells the caller to use `invoke_message_type`. The tool-name test now covers every Data Exchange help type, and rendered Storage and Data Exchange help must not contain a literal `\u` escape.
- `Storage.Attachment.Offload` discovers candidates with `Data.Records.Get` (`tableName` and `tableView`) instead of `get_records`.
### Fixed (2026-09-28) - Upload.Begin rejects a fileName that contains folders (#16)

- `Storage.Upload.Begin` rejects a `fileName` that contains `/` or `\` (`fileName must be a file name without folders; use path or folderPath for the destination folder.`) and does not create a session. Help states the default root `bifrost-uploads/`.
### Changed (2026-09-28) - CreateForRecord accepts contentBase64 (#15)

- `Storage.Attachment.CreateForRecord` accepts `contentBase64` as the canonical inline content name and keeps `content` as an alias. Sending both names returns "Supply contentBase64 or content, not both."

### Security (2026-09-29) - generic writes blocked on Storage Attachment Link ori; orphan links purged (#9)

- Generic `Data.Records.Set` writes to `Storage Attachment Link ori` are refused. The error names `Storage.Attachment.Offload / Storage.Attachment.CreateLinked / Storage.Attachment.CreateForRecord`. Reads stay allowed.
- Install and the next per-company upgrade (`Storage Link Upgrade ori`, 10035683, tag `Origo.Bifrost.Attachments-PurgeOrphanLinks-20260928`) delete link rows whose Table ID is 0 or whose Record System Id is empty.
### Changed (2026-09-28) - message types behave like Bifröst Foundation's (Foundation #138, #135, #136, #144, #146)

- **Structured errors.** Every storage message type now answers a bad request the way Foundation does:
  `status` = `Error` with a stable `code` (`MissingParameter`, `InvalidParameterFormat`, `InvalidParameter`,
  `RecordNotFound`, `PreconditionFailed`, `PermissionDenied`, `LimitExceeded`, `BusinessCentralError`),
  `parameter`, `received`, `expected` and `nextStep`. All problems of a request are reported at once
  (`MultipleErrors` with `errors[]`). Examples: an unknown `storageCode` is `RecordNotFound` pointing to
  `Storage.Account.List`; a disabled connection or a closed upload session is `PreconditionFailed`; a
  path with a `..` segment is `InvalidParameter`. Storage connector failures stay `BusinessCentralError`
  with the connector's own text. **Breaking for callers that matched error texts**: several messages were
  reworded, and upload/attachment errors that used to be raised are now answered. Everything the request
  and the data can show is checked before the first database write; a failure after a write is still
  raised, so the write rolls back.
- **Strict request values** (new `Storage Request Reader ori`, codeunit 10035682). Integers are a JSON
  number or a string of digits, GUIDs must parse, base64 must decode. A present but invalid value never
  falls back to a default any more (before, an invalid `incomingDocumentEntryNo` or `tableId` was treated
  as "not given").
- **Search keywords.** The 22 business types implement Foundation's `Msg Discovery ori`: English keywords
  with Icelandic translations, and a selection description that separates each type from its siblings.
  `Help.Storage.Get` stays technical and has none. The Icelandic keywords are a first draft for review.
- **Chunks as large as one call allows.** A chunk (and a single `Storage.File.Create` or inline
  `content`) may carry up to 240 MiB (251,658,240 bytes); the base64 text then stays under Business
  Central online's 350 MB OData request limit. `Storage.Upload.Begin` returns `chunkSizeHint` (was
  49,152) and the new `maxChunkBytes`, both 240 MiB, so a file takes as few billable messages as possible.
  Larger content is refused with `LimitExceeded`.
- **Filter tables.** `Storage.Attachment.Offload` and `Restore` report `Document Attachment`,
  `Storage.Attachment.CreateLinked` reports `Incoming Document` (was 0).
- **Help.** Every help document has Foundation's sections (Overview, Request Parameters, Response Shape,
  Errors with a `code` column, Related Message Types); the old `{status, error}` failure block is gone
  because Foundation appends the shared error section. Fixed: `invoke_message_type` tool name (was
  `call_message_type`), line breaks that rendered as a literal `\`, and `→`/`—` shown as text in
  the overview. `Help.Storage.Get`'s own help is now a standard help document followed by the overview.
- **Tests.** New `Storage Msg Conformance Tests` (96211, Foundation's rules 1-6 plus keyword coverage for
  every type, no allow-list) and `Storage Error Response Tests` (96212) and setup-action TestPage cases to `Storage Setup Page Tests` (96207). Existing tests assert the
  structured answers instead of raised texts.
- **Foundation.** Requires a Foundation build with `Msg Discovery ori` and `Bifrost Error Code ori`
  (#149, #153) and the structured-error hand-over of core#153, #164 and #165; built and tested against the stack up to #169.

### Added (2026-09-28) - Data Exchange Phase 0 (#22)

- Read-only discovery message types `Help.DataExchange.Get`, `DataExchange.Definition.List`, `DataExchange.Definition.Get`, `DataExchange.Type.List`, `DataExchange.Entry.List` and `DataExchange.Entry.Get`. Generic `Data.Records.Set` on `Data Exch.` is blocked and the error names `DataExchange.Import.Run / Storage.Upload.CommitToDataExchange`.
- New permission set `BIFROST DataExch ori` (70013548), also granted through `Storage Full ori`.
- `app.json` `idRanges` gains 70013500–70013549.

### Changed (2026-09-28) - document linked-attachment delete guards (#14)

- `Storage.File.Delete` and `Storage.Directory.Delete` help list the linked-attachment guard errors and the resolution: restore with `Storage.Attachment.Restore` or delete the BC attachment first, then delete the file. The overview Connector notes mention the same guard.

### Fixed (2026-09-28) - Help.Storage.Get reports the installed app version (#13)

- `Help.Storage.Get` prints the installed module version (`NavApp.GetCurrentModuleInfo`, culture-invariant major.minor.build.revision) and drops the hard-coded `28.0.11.0` / "Initial release" line.

### Fixed (2026-09-28) - Storage help uses the MCP tool names from Foundation (#12)

- Storage help no longer names `call_message_type` or `get_message_type_help`. It uses `invoke_message_type` and `describe_message_type`, matching Bifrost Foundation after core#64.

### Changed (2026-09-24) - Storage.Upload help after Abort (#17)

- Storage.Upload help: Abort notes now point to the Status not-found result, and the not-found error names `Storage.Upload.Begin`.

### Changed (2026-09-22) - Outbound storage Side effects in help (#18)

- **`Help.Storage.Get` overview** states that Direction describes Business Central data;
  File and Directory Create, Delete, Copy and Move still change external storage even though
  they are Outbound, and agents should treat them as writes when asking for confirmation.
- **Per-type help** for `Storage.File.Create`/`Delete`/`Copy`/`Move` and
  `Storage.Directory.Create`/`Delete` adds a `## Side effects` section via
  `Storage Help Builder ori`.`SetSideEffects`.
- **Tests** extend `Storage Connector Tests` (96204): overview AC01 assertion +
  `MutatingOutboundStorageHelpDocumentsSideEffects` for AC02.

### Changed

- App logo: new Bifröst wordmark with "Powered by origo." tagline; app-name line unchanged.
- Generic `Data.Records.Set` writes to `Storage Setup ori` are now blocked by `Storage Data Restriction ori` (table-write restriction). Reads stay allowed, and callers must use the Bifrost Storage Setup page/flow for setup changes; `Storage.Account.List` behavior is unchanged.

### Changed - docs: CLAUDE.md Foundation pin + next free test id

- **`.claude/CLAUDE.md`**: Bifrost Foundation dependency pin **28.0.0.87** → **28.0.0.102**; next free test id **96211** (drop stale `Test No Source Read` / 96212 bookkeeping after #29).

### Changed (2026-09-15) - permission-tolerant legacy take-over probe (#8)

- **`Storage Takeover ori` probes legacy tabledata before copy** (`TryProbeTakeOverPermissions` /
  `TryRunTakeOverAtInstall`), mirroring Foundation core#43. Sources remain only Cloud Events
  tables 10075985 / 10075986; Access Control write is probed when `CE Storage` role pairs would
  move. First denial skips the whole take-over with one telemetry event (`ORI-BIF-0002`), never
  `Error`. Ambiguity A1: telemetry only + idempotent re-run (no pending flag on multi-row setup).
- **`Storage Takeover State ori` (10035681)** — SingleInstance probe-denial / last-skip seam for
  unit tests (same role as Foundation `Take-Over State ori`).
- **`Storage Install ori`** calls `TryRunTakeOverAtInstall` instead of bare `TakeOverAll`.
- **Tests** `Storage Takeover Probe Tests` (96210) cover AC01 probe-denied, AC02 probe-OK, AC03
  legacy absent; probe-denial seam + `TestPermissions = Disabled` (standing HARD — no
  `Test No Source Read`). Existing Access Control mapping tests (96209) unchanged.
- **Dependencies**: Bifrost Foundation pin → **28.0.0.102** (app + test); `.AL-Go` core probing
  `release_status` → **latestBuild** (prerelease only had 28.0.0.87). App version stays
  **28.0.0.0**.

### Fixed (2026-09-11) - install Setup ori read + Access Control take-over grant

- **`Storage Install ori` grants `tabledata "Setup ori" = R`.** Deploy of 28.0.0.18 failed on
  Bifrost with `TableData 10077901 Setup ori Read` denied at
  `RegisterChangeLogGuardExceptions` during `OnInstallAppPerCompany`. The grant lives on the
  install codeunit's `Permissions` property (not a user-assignable permission set).
- **`Storage Takeover ori` grants `tabledata "Access Control" = RI`.** Legacy-tenant take-over
  inserts matching `BIFROST Attach ori` rows for holders of `CE Storage`; without the grant the
  whole publish rolls back. No delete of legacy rows, so R+I is sufficient.
- **Take-over unit tests TC001–TC003** (`Storage Takeover Tests`, 96209) seed Access Control via
  `RecordRef.Open(2000000053)` and cover grant, idempotent re-run, and empty-legacy exit.

### Security

- Default (release) builds no longer ship the test app's internalsVisibleTo grant; the strip moved to PipelineInitialize.ps1 because Alpaca never ran PreCompileApp.ps1 (core#129).

## [28.0.0.0] - 2026-09-07

### Added (2026-09-07) - Setup Wizard action

- **`Attachments Setup ori` gained a promoted `Setup Wizard` action** that opens Bifröst
  Foundation's `Setup Wizard ori`, matching the pattern already shipped on the other Bifröst
  apps' own setup pages. It enables outbound HTTP client requests for every registered Bifröst
  app and walks through each app's credentials in one optional, skippable flow - the
  administrator no longer has to find the shared **Bifröst Setup** page separately to run it.

### Changed (2026-09-07) - setup notifications and wizard

Across the Bifröst family, a setup notification is now raised in exactly one place: Bifröst
Foundation's shared **Bifröst Setup** page, with a single action, *Start setup wizard*. A module
no longer nags on its own setup page, so an administrator sees one list of what still needs
configuring instead of one notification per app, each in a different place.

- **New codeunit `Attachments Registration ori` (10035680).** It subscribes to Foundation's
  `App Registry ori.OnRegisterApps` and registers this app with its id, its display name and
  `Attachments Setup ori` as the page to open. Without it, the shared setup page cannot name this
  module or point the administrator anywhere. Added to `BIFROST Attach ori` and `Storage Full ori`.
- **`Attachments Setup ori` no longer raises the "Allow HttpClient Requests" notification.** Its
  `OnOpenPage` trigger, the `ShowHttpClientNotification` procedure and the three labels behind it
  are gone; Foundation reports the same condition through `App Registry ori.IsHttpEnabled`.
- **Codeunit `Storage Http Notif. Action ori` (10035666) deleted.** It existed only to carry the
  two notification actions. Its id is free but is not reused. (Permission set 10035666
  `BIFROST Attach ori` is unaffected - object types have separate id spaces.)
- **Tests.** New codeunit `Storage App Registry Tests` (96208) asserts that
  `App Registry ori.GetApps` lists this app under the id from `NavApp.GetCurrentModuleInfo` and
  points at page `Attachments Setup ori`. `Storage Setup Page Tests` (96207) dropped its
  `SendNotificationHandler` - opening the setup page no longer sends anything to handle.

### Changed (2026-09-07) - tests run on Foundation's public API

- The test app no longer depends on Bifröst Foundation's internals: Bifrost Attachments - Tests has been removed
  from Foundation's `internalsVisibleTo`, and the test suite compiles and runs against a Foundation
  package that does not grant it. No test code had to change - the suite never touched a Foundation internal.


### Changed (2026-09-07)

- **Restoring an attachment now removes the database link before it deletes the remote copy** (`Storage.Attachment.Restore`). The remote delete is the only irreversible step, so it runs last: if anything after it had failed, the transaction would have rolled the record back to the offloaded state with the only copy of the file already gone. In this order a failing delete rolls the whole restore back instead — the attachment stays offloaded and its remote copy stays where the link says it is. The same discipline `Storage.Attachment.Offload` already followed.
- **Reads narrowed.** `SetLoadFields` on every attachment-link lookup in `Storage Attachment Mgt ori` and `Storage Attachment Subscr ori` (the subscribers run on every attachment the user opens), on the `NAV App Setting` read behind the setup wizard's HTTP-client check, and `ReadIsolation = ReadCommitted` on the `Storage.Account.List` scan and the permission take-over scan.

### Fixed (2026-09-07)

- **Assisted-setup wizard strings corrected to the app's current name.** The assisted setup entry registered by `Storage Install ori` (title and short title) and the wizard page `Storage Setup Wizard ori` itself (page caption, welcome step, HTTP step instructional text) still said "Bifrost Storage" / "Bifröst geymsla" - a leftover from before the app was renamed to Bifrost Attachments. They now say "Bifrost Attachments" / "Bifröst viðhengi", matching the rest of the app. References to the separate, still-named `Storage Setup ori` page and the shared Bifröst Setup page were left untouched, since those objects were not renamed.

### Security (2026-09-07)

- **Relative path segments are rejected.** A connection's `Base Path` is its only confinement boundary, so a caller-supplied path whose segments include `.` or `..` — in either slash direction — is now refused. `Storage.File.*` and `Storage.Directory.*` answer `status = Error` naming the rejected path; the attachment and upload folder helpers raise the same error. The production connector re-checks the path in `ResolvePath`, so every route into external file storage is covered, not just the message types. Dots inside a file name (`my..archive.v1.txt`) stay legal — only whole segments are rejected. Four unit tests cover it.

### Renamed before release (2026-09-06)

The app was called **Bifrost Hnitbjorg** while it was being built. Bifröst apps are named after what they do, not after a Norse hall, so everything below was renamed before the first release. Nothing has shipped, so there is no upgrade path to keep: no object id changed, and no `Storage.*` message type key changed. Object names still start with `Storage` - that is the domain, not a brand.

- App `Bifrost Hnitbjorg` -> **`Bifrost Attachments`** (Icelandic "Bifröst viðhengi"); test app `Bifrost Attachments - Tests`.
- Namespace `Origo.Bifrost.Hnitbjorg` -> **`Origo.Bifrost.Attachments`** (tests `Origo.Bifrost.Attachments.Test`).
- Repository `businesscentralal/bc-origo-bifrost-hnitbjorg` -> `businesscentralal/bc-origo-bifrost-attachments`.
- Page `Hnitbjorg Setup ori` -> **`Attachments Setup ori`** (id 10035677 unchanged).
- Permission set `BIFROST Hnitbj. ori` -> **`BIFROST Attach ori`** (id 10035666 unchanged). `Storage Takeover ori` re-grants the new role id to every user who held the legacy `CE Storage` set.
- Upgrade tag `Origo.Bifrost.Hnitbjorg-Initial-20260905` -> `Origo.Bifrost.Attachments-Initial-20260905`.
- The documentation site slug stays `hnitbjorg` for now (`help`, `contextSensitiveHelpUrl` and `ContextSensitiveHelpPage = 'hnitbjorg-setup'`); the folders in `businesscentralal/bifrost` are renamed in a separate change, and the app.json URLs follow then.

### Changed (2026-09-06)

- **Take-over hardened and install simplified** (PR #1 review). Every `DataTransfer` field in `Storage Takeover ori` is now guarded by `RecordRef.FieldExist`, the pattern Nornir already uses: the published Cloud Events Storage schema is not byte-identical across environments, and a missing field would otherwise fail the whole install. `Storage Takeover ori` is no longer an install codeunit - it exposes `TakeOverAll()`, which `Storage Install ori.OnInstallAppPerCompany` calls before it registers anything of its own, so the app has one install entry point with a visible step order.
- **`BIFROST Attach ori` is now a complete role.** It granted only `tabledata "Storage Setup ori"`, so nobody could use the app with it alone. It now carries the four tables, all 43 codeunits and all six pages. `Storage Full ori`, the extension of Foundation's `BIFROST Full ori`, was missing four codeunits and the setup wizard page; both lists are now complete and identical.
- **`keyVaultUrls` removed from `app.json`.** No AL code in this app reads an Azure key vault - secrets go through Foundation's `Secret Store ori`.

- **Own setup page, one entry on the Bifröst Setup page.** Bifrost Attachments now follows the
  shared platform setup pattern. A new page `Attachments Setup ori` (10035677, help slug
  `hnitbjorg-setup`) is the single place where the module is configured: it embeds the storage
  connections in the new list part `Storage Conn. Part ori` (10035678) and carries the four
  actions that used to sit on the shared Bifröst Setup page - Storage Setup Wizard, Storage
  Setup (file accounts), Bifrost Storage Setup and Purge Upload Sessions - plus the
  "HttpClient requests are not enabled" notification, which now appears when this page is
  opened instead of on the shared page.
- `Setup Ext. ori` (10035635) is reduced to exactly one action: a `Bifrost Attachments Setup`
  entry in the Apps group that opens `Attachments Setup ori`, with the matching promoted
  actionref in `Category_Apps`. The `Storage` navigation group, its four actions, the
  `OnOpenPage` trigger and the notification were removed from the extension, so the shared
  Bifröst Setup page stays owned by Bifröst Foundation.
- The inline purge logic moved out of the page extension into the new codeunit
  `Storage Upload Purge ori` (10035679), which deletes abandoned upload sessions and their
  chunks and reports the counts. It is unit-tested; the page action only calls it.
- `Storage Setup ori` is no longer searchable (`UsageCategory = None`). Dependent-app setup pages are reached only from the Bifröst Setup page so that Tell Me is not crowded (portfolio rule).
- Help and documentation moved to <https://businesscentralal.github.io/bifrost>. The `app/Help/` and `app/docs/` folders were removed from this repository; all public content now lives in the businesscentralal/bifrost site repository. `help` in `app.json` points at <https://businesscentralal.github.io/bifrost/en-us/hnitbjorg/> and `contextSensitiveHelpUrl` at `https://businesscentralal.github.io/bifrost/{0}/help/hnitbjorg/`.
- Context-sensitive help pages are now addressed by Docusaurus page slug instead of an HTML file name: `hnitbjorg-setup` (Attachments Setup ori, Storage Conn. Part ori), `storage-setup` (Storage Setup ori, Storage Setup Wizard ori), `storage-card` (Storage Card ori) and `storage-account-lookup` (Storage Account Lookup ori).

### Rebrand: Origo Cloud Events Storage -> Bifrost Attachments

This release replaces the published AppSource app *Origo Cloud Events Storage* with a new app,
**Bifrost Attachments**, the storage module of the Bifröst platform. The two apps can be installed
side by side; the new app takes the old app's data over on its first install, so no manual data
migration is needed before the old app is uninstalled.

### Added

- **Data take-over on first install.** A new install codeunit `Storage Takeover ori`
  (10035676) runs once per company when the app is installed. It copies
  `CE Storage Attachment Link` (10075985) into `Storage Attachment Link ori` (10035635) and
  `Cloud Events Storage Setup` (10075986) into `Storage Setup ori` (10035636) with
  `DataTransfer`, but only when the old table still exists in the database and the new table is
  empty, so re-installing never overwrites live data. Every user that held the old
  `CE Storage` permission set is granted `BIFROST Attach ori` through the `Access Control`
  table. Transient tables — upload sessions and upload chunks — are deliberately not copied;
  an upload in flight during the switch must be restarted. The codeunit is generated by
  `tools/gen_install.py` and is not hand-edited.
- **Six domain help codeunits.** `Storage Account Help ori` (10035670),
  `Storage File Help ori` (10035671), `Storage Dir Help ori` (10035672),
  `Storage Attachment Help ori` (10035673), `Storage Upload Help ori` (10035674) and
  `Storage Overview Help ori` (10035675) now hold the Markdown help contract for their domain.
  Every `* Impl ori` codeunit routes its `GetMessageHelpAsMarkdownDocument` to the help codeunit
  of its domain instead of building the document inline, so the request contract for a whole
  domain is described in one place and stays consistent across its message types.

### Changed

- **New app identity.** App id `672df32a-a0c5-4a22-b591-0efa38023e95` (was
  `7acf9361-f558-442b-a516-f5e5dd92aecb`); test app `Bifrost Attachments - Tests`, id
  `7cdb530b-b74b-446b-9ece-80e2b911bfb3`. Version reset to 28.0.0.0. App name
  `Origo Cloud Events Storage` -> **Bifrost Attachments**, shown to users as *Bifröst viðhengi*.
- **New object ID range** 10035635–10035684, migrated from the Cloud Events Storage range
  10075985–10076034 with an offset of −40350; object numbers keep their relative order. The
  test app moves from 92700–92799 to 96200–96299 (offset +3500), so the Bifröst test app can be
  installed next to the legacy Cloud Events test app.
- **Dependency swapped** from `Origo Cloud Events Core` to **Bifrost Foundation**
  (`7505e808-6e52-4b96-a328-82573391297a`, version 28.0.0.0). The message-type interface is
  Foundation's `Msg Interface ori` and the enum extended is Foundation's `Message Type ori`.
- **Namespace** `Origo.APP.CloudEvents.Storage` -> `Origo.Bifrost.Attachments`; the test app uses
  `Origo.Bifrost.Attachments.Test`.
- **Object names.** The `CE` prefix and the words "Cloud Events" were dropped from every object
  name, and every object now carries the mandatory AppSource affix ` ori` — for example
  `CE Storage Attachment Link` -> `Storage Attachment Link ori`,
  `Cloud Events Storage Setup` -> `Storage Setup ori`,
  `Cloud Events Storage Card` -> `Storage Card ori`,
  `Cloud Events Storage Type` -> `Storage Type ori`,
  `Cloud Events Setup Ext.` -> `Setup Ext. ori`,
  and the interface `CE Storage Connector` -> `Storage Connector ori`.
  Two names would have exceeded the 30-character limit with the suffix and were abbreviated:
  `CE Storage Attach Offload Impl` -> **`Storage Att. Offload Impl ori`** and
  `CE Storage Attach Restore Impl` -> **`Storage Att. Restore Impl ori`**.
- **Permission sets renamed.** The assignable set `CE Storage` -> `BIFROST Attach ori`, and the
  permission set extension `CE Storage Full` -> `Storage Full ori`, which now extends
  Foundation's `BIFROST Full ori` instead of `CE Full Access ori`.
- **Default storage folders rebranded.** Attachments offloaded without an explicit
  `folderPath` now land under `bifrost-attachments` (was `cloud-events-attachments`), and
  chunked uploads committed without an explicit `path` or `folderPath` land under
  `bifrost-uploads` (was `cloud-events-uploads`). Files written by the old app keep their
  existing paths — the link table records the full path, so offloaded attachments stay
  readable after the take-over. Only newly written files use the new defaults.
- **Icelandic captions** now say "Bifröst".
- **Message type keys are unchanged.** All 23 keys — `Help.Storage.Get`,
  `Storage.Account.List`, the seven `Storage.File.*`, the four `Storage.Directory.*`, the four
  `Storage.Attachment.*` and the six `Storage.Upload.*` types — keep their names, so existing
  callers keep working once they are pointed at the Bifröst API route
  (`origo/bifrost/v1.0`, which Foundation serves alongside the legacy route).
  The JSON request and response shapes are unchanged.

### Upgrade notes

- Install Bifrost Attachments alongside Origo Cloud Events Storage. On the first install per
  company the data and role assignments are taken over automatically.
- Verify the storage connections on **Bifrost Storage Setup** and re-run **Test Connection**
  before uninstalling the old app.
- Complete or abandon any open chunked upload sessions before the switch — sessions and chunks
  are not carried over.
- The old app remains installed and functional until it is removed; both apps read the same
  external storage accounts, so no files need to be moved.

- Clears absent Notes output in "DataExch Entry Del Impl ori" (70013544), retaining false and the real interface signature; adds seeded/repeated/empty-output regression to "Attachments Build Tests ori" (96274) under the bounded internal analyzer disposition.
