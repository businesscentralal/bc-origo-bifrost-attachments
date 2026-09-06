# Extension: Bifrost Hnitbjorg

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.Hnitbjorg`
namespace; every object name starts with `Storage` because that is what the module does, not
because it is a brand prefix)

## Namespace
Origo.Bifrost.Hnitbjorg (tests: Origo.Bifrost.Hnitbjorg.Test)

## Object ID Range
App:   10035635-10035684 (allocated in origo_cloudevents_object_ranges.xlsx; migrated from the
       Cloud Events Storage range 10075985-10076034 with offset -40350. The original target block
       10035485-10035534, offset -40500, was already occupied by the legacy Cloud Events Chat app
       on bc28-is, so the coordinator reallocated this app to 10035635-10035684 in the workbook.)
Tests: 96200-96299 (migrated from 92700-92799 with offset +3500)

Highest object id currently used: 10035679. Free ids left in the block: 10035680-10035684.
Register any further block in the workbook before using it - never squeeze objects into a
neighbouring app's range.

Ids taken by the setup migration (2026-09-06): page 10035677 `Hnitbjorg Setup ori`,
page 10035678 `Storage Conn. Part ori`, codeunit 10035679 `Storage Upload Purge ori`.
No id was freed - `Setup Ext. ori` keeps 10035635, it was only reduced in scope.
Test app: codeunit 96207 `Storage Setup Page Tests` (next free test id 96208).

## App Identity
App:      Bifrost Hnitbjorg, id `672df32a-a0c5-4a22-b591-0efa38023e95`, version 28.0.0.0
Test app: Bifrost Hnitbjorg - Tests, id `7cdb530b-b74b-446b-9ece-80e2b911bfb3`
Publisher: Origo - target Cloud - runtime 17.0 - application/platform 28.0.0.0
Display form in prose and captions: **Bifröst Hnitbjörg** (Norse module name; Hnitbjörg is the
hall that stores the mead).

## Target BC Version
28.x (application/platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-hnitbjorg
Default branch: main
Migration branch: feature/bifrost-hnitbjorg-migration

## Dependencies
- Bifrost Foundation, id `7505e808-6e52-4b96-a328-82573391297a`, publisher Origo, version 28.0.0.0

At runtime the tenant must also have at least one Business Central external file storage
connector app installed and configured (Azure Blob Storage, Azure File Share or SharePoint).
Those apps own the credentials - this app only stores a registered File Account id.

## Naming Rules
- Every object carries the ` ori` suffix (AppSource mandatory affix) and is at most 30
  characters. Two names had to be abbreviated to fit: `Storage Att. Offload Impl ori` and
  `Storage Att. Restore Impl ori`.
- The brand name "Bifrost" lives in the namespace, the app name, the permission set
  (`BIFROST Hnitbj. ori`) and user-facing captions - never as an object-name prefix.
- Icelandic captions use "Bifröst". Any remaining "atburða í skýinu" wording is a Cloud Events
  leftover and must be replaced with Bifröst wording.
- File names follow `<ObjectNameShort>.<ObjectTypeShortPascalCase>.al` with the suffix removed
  (CRS settings in `al.code-workspace`).

## Documentation

Documentation lives in businesscentralal/bifrost (site bifrost.origo.is); no Help/ or docs/
folders in this repo - deviation from the Origo PR gateway check 8 approved by the user
2026-09-06.

- Product docs: https://businesscentralal.github.io/bifrost/en-us/hnitbjorg/
- In-product help: https://businesscentralal.github.io/bifrost/en-us/help/hnitbjorg/
- Extensibility guide: https://businesscentralal.github.io/bifrost/en-us/extensibility/

Context-sensitive help pages are addressed by Docusaurus slug (`hnitbjorg-setup`,
`storage-setup`, `storage-card`, `storage-account-lookup`), not by HTML file name. The
`hnitbjorg-setup` slug is new with the 2026-09-06 setup migration and still has to be created
in the businesscentralal/bifrost site repository - this repository holds no help markdown.

## Development Standards

This project follows the **Origo BC Development Standards**
(https://github.com/OrigoSoftwareSolutions/bc-dev-standards).

Before writing any AL code, load the relevant skills:
- **`origo-bc-al-coding-standards`** - namespaces, XML docs, naming, formatting, performance,
  enums, Format/Evaluate, events, error handling, JSON, security
- **`origo-bc-test-writer`** - test structure, AAA pattern, coverage checklists, mock patterns
- **`origo-bc-documentation-writer`** - XML doc comments, markdown reference docs, help
  codeunits, sync rules

Agent context for this repository is in [AGENTS.md](../AGENTS.md).

Key rules always in effect:
- Namespace `Origo.Bifrost.Hnitbjorg` at the top of every file
- XML documentation on every object and non-local procedure
- Bilingual captions (en-US + is-IS `Comment = 'is-IS=...'`) on all user-facing text
- `SetLoadFields` on all record reads
- `Format(guid, 0, 4)` for GUIDs, `Format(value, 0, 9)` / `Evaluate(var, text, 9)` for
  culture-invariant serialization
- Never use `Format()` / `Evaluate()` on enum values - use `.Names()`, `.Ordinals()`,
  `.AsInteger()`, `.FromInteger()`
- Implementation = code + tests + documentation (domain help codeunit, plus the page in
  businesscentralal/bifrost when user-facing)
- New tables, pages, reports and codeunits must be added to `Storage Full ori`
  (`app/src/Permissions/StorageFull.PermissionSetExt.al`)

## Development Environment
- Two COSMO Alpaca containers, both defined in `app/.vscode/launch.json` (git-ignored, the
  authority for instance ids): `launch: bc28-is` (Icelandic CRONUS IS, with the legacy
  Origo Cloud Events Storage app installed side by side, used for the MCP message-type tests and
  for verifying the data take-over) and `launch: bc28-w1` (W1 CRONUS International Ltd., unit
  tests). Publish and run the unit tests on **both**; select the target with
  `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with alc.exe + CodeCop/UICop/AppSourceCop (symbols in `app/.alpackages`,
  test symbols in `test/.alpackages` including the Bifrost Foundation .app).
- Publish and test without VS Code (pwsh 7, credential from the user-level env vars
  `BC28IS_USER` / `BC28IS_PASSWORD`, never from files):
  `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>` and
  `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1`. Both read the instance from
  `app/.vscode/launch.json` - check it matches the MCP server's baseUrl before publishing.
- Command-line alc does not raise AS0011 (mandatory affix); AL-Go CI is the gate, so check the
  ` ori` suffix yourself before pushing.

## Message Type Conventions
- `Storage Msg Type ori` (10035635) extends Foundation's `Message Type ori` enum with 23 values.
  Each value binds `Msg Interface ori` to a `<Name> Impl ori` codeunit that implements
  `ExecuteBifrostTask`. Captions are `Locked = true` - the keys are the public wire contract.
- Keys are `Area.Entity.Verb`: `Help.Storage.Get` is the module directory; the rest are
  `Storage.Account.List`, `Storage.File.{List,Get,Create,Delete,Copy,Move,Exists}`,
  `Storage.Directory.{List,Create,Delete,Exists}`,
  `Storage.Attachment.{Offload,Restore,CreateLinked,CreateForRecord}` and
  `Storage.Upload.{Begin,Append,Commit,Abort,Status,CommitToRecord}`.
- **Help lives per domain, not per type.** Six help codeunits - `Storage Account Help ori`,
  `Storage File Help ori`, `Storage Dir Help ori`, `Storage Attachment Help ori`,
  `Storage Upload Help ori`, `Storage Overview Help ori` - hold the Markdown contract for their
  domain, built with `Storage Help Builder ori`. Every `* Impl ori` codeunit delegates its
  `GetMessageHelpAsMarkdownDocument` to the help codeunit of its domain with a `case` on the
  message type. Never build the help document inline in an implementation codeunit.
- Every implementation resolves its request through `Storage Request Mgt ori`, which maps
  `storageCode` to a `Storage Setup ori` row and returns the `Storage Connector ori`
  implementation to use.
- Errors must be returned as `status = Error` with a helpful message via
  `Argument.RespondWithError`; never let an unhandled exception reach the API.
- `Storage Upload Session ori` and `Storage Upload Chunk ori` are blocked from the generic
  `Data.Records.*` message types by `Storage Data Restriction ori` - use the dedicated
  `Storage.Upload.*` types.

## Setup Surface
- `Hnitbjorg Setup ori` (10035677) is the app's own setup page and the only place the module is
  configured. It embeds `Storage Conn. Part ori` (10035678) for the storage connections, carries
  the Storage Setup Wizard / File Accounts / Bifrost Storage Setup / Purge Upload Sessions
  actions, and shows the "Allow HttpClient Requests" notification in its `OnOpenPage`.
- `Setup Ext. ori` (10035635) must stay at exactly one `addlast(Apps)` action plus its
  `addlast(Category_Apps)` actionref - no layout changes, no other group, no notification, no
  `ContextSensitiveHelpPage` override. The shared `Setup ori` page belongs to Bifröst Foundation.
- Purge logic lives in `Storage Upload Purge ori` (10035679), never inline on a page.

## Install and Take-over
- `Storage Install ori` (10035637) registers the ChangeLog guard exception for the attachment
  link table, the assisted setup entry for `Storage Setup Wizard ori`, and the initial-release
  upgrade tag.
- `Storage Takeover ori` (10035676) takes data over from the published
  *Origo Cloud Events Storage* app (`7acf9361-f558-442b-a516-f5e5dd92aecb`) on first install per
  company: `CE Storage Attachment Link` (10075985) -> `Storage Attachment Link ori` (10035635)
  and `Cloud Events Storage Setup` (10075986) -> `Storage Setup ori` (10035636) with
  `DataTransfer`, plus the `Access Control` re-grant from `CE Storage` to `BIFROST Hnitbj. ori`.
  The generator `gen_install.py` is archived in
  `bc-origo-bifrost-core/tools/migration/archive/hnitbjorg/` - regenerate from there, never
  hand-edit.
- Transient tables (upload sessions and chunks) are not copied by design.

## Testing Through the MCP Server
- `invoke_message_type` / `get_message_type_help` / `get_records` / `set_records` on the
  `origo-bc-bc28-is` server reach this app through Foundation's route `origo/bifrost/v1.0`.
  Keep calls **serial** - parallel bursts crash the server.
- Test data uses the `BIFT-<letter>` prefix in CRONUS IS; never delete existing master data.
- The ChangeLog Write Guard must be set to *Open* in the BC UI before data-heavy generic
  `Data.Records.Set` runs, and restored afterwards.
- The test app exercises the whole pipeline without a live storage account through the `Mock`
  value that `Storage Type Test` (96200) adds to `Storage Type ori`.
- Full message-type test reports live in
  `test/reports/Bifrost_Hnitbjorg_MessageType_TestReport_<date>.md` (internal, not published).
  The generator `make_report.py` and the type list `hnitbjorg_types.txt` are archived in
  `bc-origo-bifrost-core/tools/migration/archive/hnitbjorg/`. The open defect list from the last
  run is in that report's "Defects and observations" section - fix from there.
