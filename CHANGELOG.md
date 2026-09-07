# Changelog

All notable changes to Bifrost Attachments are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this app uses
Business Central release versioning (`major.minor.build.revision`).

## [28.0.0.0] - 2026-09-07

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
