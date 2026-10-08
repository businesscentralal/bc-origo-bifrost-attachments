# Changelog

All notable changes to Bifrost Attachments are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this app uses
Business Central release versioning (`major.minor.build.revision`).

## [Unreleased]



### Fixed (2026-10-07) - restricted permission fixture isolation (#79)

- Use fresh company-local setup, Customer and Data Exchange keys in `Storage 79 Perm Tests ori` (96218). Persist each arranged database baseline before applying exact actor permissions, including native content and upload chunks before a second lowering, so an expected platform error cannot roll back the fixture. Preserve all 28 scenarios, 13 test roles and denial/content assertions; genuine principal/provider/native/legacy verification remains blocked.
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
