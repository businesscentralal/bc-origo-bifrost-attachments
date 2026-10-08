# Changelog

All notable changes to Bifrost Attachments are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this app uses
Business Central release versioning (`major.minor.build.revision`).

## [Unreleased]



### Fixed (2026-10-07) - selective Data Exchange localization (#72, #74)

- Localize discovery text in `DataExch Type Set Impl ori` (70013531), `DataExch Export Run Impl ori` (70013534), `DataExch Def Export Impl ori` (70013536), `DataExch Entry Del Impl ori` (70013544) and `DataExch Def Import Impl ori` (70013545), plus six existing refusal labels in Definition Export, Definition Import and Entry Delete. `Attachments Build Tests ori` (96274) asserts exact discovery text in English and Icelandic; `Storage Setup Page Tests` (96207) orders Record declarations before TestPage without changing assertions. Eight TypeSet/ExportRun execution contexts remain deferred. Compiled shipping translations and runtime verification remain pending.

### Fixed (2026-10-07) - registered parameter metadata (#69)

- Delegate parameter chapters in `DataExch Type Set Impl ori` (70013531), `DataExch Export Run Impl ori` (70013534) and `DataExch Def Export Impl ori` (70013536) to `Storage Contract Parts ori` (70013500), documenting the shipped optional `description` and JSON string types without changing wire keys or execution. `Storage Contract Batch2 Tests` (96216) asserts exact registered parameter counts, types, requiredness and uniqueness. The tests also verify replacement of stale metadata and the canonical `error` property for single/collected bilingual refusals; runtime verification remains pending.

### Fixed (2026-10-07) - duplicate Data Exchange type-list contract case

- Remove the redundant `DataExchange.Type.List` response branch from `Storage Contract Parts ori` (70013500), preserving the localized `count` and `types` fields returned by `Data Exchange Query ori` (70013520). `Storage Contract Batch2 Tests` (96216) covers unique typed response metadata, a deterministically empty parameterless request and exactly two seeded public-dispatcher rows with integer count, array shape and row contents. Full company rows are preserved/restored in the owned disposable test company; runtime verification remains required.
