# Bifrost Attachments

**App name:** Bifrost Attachments (display form *Bifröst viðhengi*)  
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28, runtime 17.0)  
**App ID:** `672df32a-a0c5-4a22-b591-0efa38023e95` — **Test app ID:** `7cdb530b-b74b-446b-9ece-80e2b911bfb3`  
**Object ID range:** 10035635–10035684 (tests 96200–96299) — **Namespace:** `Origo.Bifrost.Attachments`  
**Environments:** Business Central online (SaaS) and the COSMO Alpaca development containers `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International Ltd.)

---

## Overview

Bifrost Attachments is the storage module of the Bifröst platform. It exposes the Business Central
External File Storage facade (Azure Blob Storage, Azure File Share, SharePoint) as 23 Bifröst
message types, so any external caller can read and write cloud storage, upload large files in
chunks and offload attachments through the same Queue → Task → Data pattern used by the rest of
Bifröst. It is the successor of *Origo Cloud Events Storage*.

The app never holds storage credentials. It stores a reference to a registered Business Central
**File Account**; the connector app that owns that account (Azure Blob Storage, Azure File Share or
SharePoint) owns the secrets.

---

## Functional Flow

1. **Configure a connection.** An administrator opens **Bifröst viðhengi Setup** (`Attachments Setup ori`),
   runs the setup wizard, enables *Allow HttpClient Requests* for the extension, picks a registered
   File Account and saves it as a `Storage Setup ori` row with a short `storageCode`.
2. **Discover.** A caller invokes `Storage.Account.List` to learn which `storageCode` values exist,
   and `Help.Storage.Get` (or `Help.Implementation.Get`) to read the Markdown contract of any
   message type.
3. **Work with files and directories.** `Storage.File.*` and `Storage.Directory.*` list, read,
   write, copy, move, delete and probe entries under the connection's base path.
4. **Upload large files in chunks.** `Storage.Upload.Begin` opens a session, `Storage.Upload.Append`
   adds base64 chunks, `Storage.Upload.Status` reports progress, and `Storage.Upload.Commit`
   assembles the chunks and writes the finished file to storage. `Storage.Upload.Abort` discards a
   session. `Storage.Upload.CommitToRecord` commits straight to a Document Attachment or Incoming
   Document instead of to a path.
5. **Offload and restore attachments.** `Storage.Attachment.Offload` moves the content of a
   Document Attachment or an Incoming Document Attachment out of the BC database into cloud storage
   and leaves a `Storage Attachment Link ori` row behind. `Storage.Attachment.Restore` brings it
   back. Event subscribers serve the offloaded content transparently, so the standard BC UI keeps
   working.
6. **Link and create.** `Storage.Attachment.CreateLinked` registers an existing storage file as an
   attachment; `Storage.Attachment.CreateForRecord` creates an attachment on a record directly from
   supplied content.

---

## Benefits

- **No database bloat.** Attachment content lives in cloud storage instead of the BC database, while
  the standard Document Attachment and Incoming Document pages behave exactly as before.
- **No credentials in this app.** Only a File Account id is stored; the connector app owns the
  secret, so there is one place to rotate and one place to audit.
- **Large files without timeouts.** Chunked uploads split a file into sessions and chunks, so a
  multi-hundred-megabyte upload never depends on a single request completing.
- **One contract for every caller.** The same 23 message types serve the BC client, the Bifröst MCP
  server and any external integration, and each type documents itself at runtime.
- **Bilingual and AppSource-ready.** Every caption ships in en-US and is-IS; every object carries the
  registered ` ori` affix.
- **Safe succession.** On first install the app takes its data over from the published *Origo Cloud
  Events Storage* app, so an existing tenant keeps its connections and attachment links.

---

## Logic Flow

```
caller ─► Bifröst Foundation (Queue → Task → Data)
             │
             ▼
        Message Type ori  (extended by "Storage Msg Type ori")
             │  binds to
             ▼
        "<Name> Impl ori" : Msg Interface ori
             │  ExecuteBifrostTask(Argument)
             ▼
        "Storage Request Mgt ori"
             │  ResolveSetup(storageCode) ──► "Storage Setup ori"
             │  RequireParam(...)          ──► RespondWithError on a bad request
             ▼
        Interface "Storage Connector ori"          ("Storage Type ori" selects the implementation)
             │
             ├─ production: "Storage Ext File Impl ori" ──► BC External File Storage facade ──► Azure Blob / File Share / SharePoint
             └─ test:       "Storage Mock Impl"          ──► in-memory mock (test app only)
```

Supporting paths:

- **Uploads** — `Storage Upload Mgt ori` owns `Storage Upload Session ori` and
  `Storage Upload Chunk ori`; `Storage Upload Purge ori` and `Storage Reten. Policy ori` clean them
  up. `Storage Data Restriction ori` blocks both tables from the generic `Data.Records.*` message
  types so callers must use the dedicated `Storage.Upload.*` types.
- **Attachments** — `Storage Attachment Mgt ori` owns offload/restore and the
  `Storage Attachment Link ori` table; `Storage Attachment Subscr ori` serves offloaded content back
  to the standard BC pages through event subscribers.
- **Help** — six domain codeunits (`Storage Account Help ori`, `Storage File Help ori`,
  `Storage Dir Help ori`, `Storage Attachment Help ori`, `Storage Upload Help ori`,
  `Storage Overview Help ori`) build their Markdown with `Storage Help Builder ori`. Every
  implementation delegates its help to the codeunit of its domain — help is never built inline.
- **Lifecycle** — `Storage Install ori` registers the ChangeLog guard exception, the assisted setup
  entry and the upgrade tag; `Storage Takeover ori` copies data over from the published Cloud Events
  Storage app on first install per company.

---

## Setup & Configuration

| Step | Where | What |
| --- | --- | --- |
| 1 | Extension Management (page 2500) | Enable **Allow HttpClient Requests** for Bifrost Attachments. The shared **Bifröst Setup** page notifies the administrator when it is off — this app registers itself with Foundation's `App Registry ori` so that notification can name it and offer *Start setup wizard*. |
| 2 | Business Central **File Accounts** | Register and configure the storage account in the Azure Blob Storage, Azure File Share or SharePoint connector app. That app owns the credentials. |
| 3 | **Bifröst Setup** → *Apps* → **Bifröst viðhengi** | Open `Attachments Setup ori` (page 10035677), the single place this module is configured. |
| 4 | `Storage Conn. Part ori` on that page | Add one row per connection. |
| 5 | `Storage Card ori` | Fill in the connection and test it. |

`Storage Setup ori` (table 10035636) fields:

| Field | Purpose |
| --- | --- |
| `Code` | The `storageCode` callers pass in every message. |
| `Description` | Free text shown in lists and returned by `Storage.Account.List`. |
| `Storage Type` | Selects the `Storage Connector ori` implementation (production: *External File Storage*). |
| `Connector` | The BC `Ext. File Storage Connector` to use. |
| `File Account Id` / `File Account Name` | The registered File Account this connection resolves to. |
| `Base Path` | Root all paths are resolved against. |
| `Enabled` | Whether the connection accepts requests. |

Actions available from `Attachments Setup ori`: **Storage Setup Wizard**, **File Accounts**,
**Bifrost Storage Setup** and **Purge Upload Sessions**.

Permissions: assign **`BIFROST Attach ori`** (caption *Bifrost Storage*) to users who need the
module. Administrators who already hold Foundation's `BIFROST Full ori` role get the same grants
through `Storage Full ori` and need no second assignment.

---

## Example Scenario

A supplier portal has to attach a 40 MB signed contract PDF to purchase invoice `PI-100234` and
keep it out of the Business Central database.

1. `Storage.Account.List` → the portal learns the connection code `BLOB01` is enabled.
2. `Storage.Upload.Begin` with `{"storageCode":"BLOB01","fileName":"PI-100234-contract.pdf"}`
   → returns an `uploadId`.
3. `Storage.Upload.Append` × 20, each with the `uploadId` and one base64 2 MB chunk.
   `Storage.Upload.Status` can be polled at any point to confirm the chunk count received.
4. `Storage.Upload.CommitToRecord` with the `uploadId` and the purchase invoice's `recordSystemId`
   → the chunks are assembled, written to storage under the connection's base path, a
   `Document Attachment` row is created for the invoice and a `Storage Attachment Link ori` row
   records where the content actually lives.
5. A buyer opens the purchase invoice in Business Central and clicks the attachment. The event
   subscribers in `Storage Attachment Subscr ori` fetch the content from cloud storage and serve it
   as if it had been stored in the database all along.

If step 3 or 4 fails — bad `uploadId`, missing chunk, unreachable storage — the response comes back
as `status = Error` with a message naming the cause; no exception escapes to the API, and
`Storage.Upload.Abort` (or the retention policy) discards the half-finished session.

---

## Objects

63 objects, all inside range 10035635–10035684. Free ids left: 10035681–10035684 (codeunit id
10035666 was freed when `Storage Http Notif. Action ori` was removed and is not reused). Every
object carries the mandatory ` ori` affix.

### Tables

| ID | Name | Purpose |
| --- | --- | --- |
| 10035635 | `Storage Attachment Link ori` | Maps a BC attachment to the storage path that holds its content. |
| 10035636 | `Storage Setup ori` | One row per configured storage connection (`storageCode`). |
| 10035637 | `Storage Upload Chunk ori` | Transient chunk buffer for an in-flight chunked upload. |
| 10035638 | `Storage Upload Session ori` | Transient header of an in-flight chunked upload. |

### Table extensions

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035635 | `Storage Inc. Doc. Attach. ori` | Incoming Document Attachment | Marks an incoming-document attachment as offloaded. |
| 10035636 | `Storage Doc. Attach. ori` | Document Attachment | Marks a document attachment as offloaded. |

### Pages

| ID | Name | Purpose |
| --- | --- | --- |
| 10035635 | `Storage Account Lookup ori` | Picks a registered BC File Account for a connection. |
| 10035636 | `Storage Card ori` | Edits one storage connection and tests it. |
| 10035637 | `Storage Setup ori` | List of storage connections; reached from the setup page, not searchable. |
| 10035638 | `Storage Setup Wizard ori` | Assisted setup: HTTP client permission, file account, finish. |
| 10035677 | `Attachments Setup ori` | The module's own setup page — the only place it is configured. |
| 10035678 | `Storage Conn. Part ori` | List part embedded in the setup page showing the connections. |

### Page extension

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035635 | `Setup Ext. ori` | `Setup ori` (Foundation) | Adds exactly one *Apps* action pointing at `Attachments Setup ori`. |

### Enums

| ID | Name | Purpose |
| --- | --- | --- |
| 10035635 | `Storage Attachment Target ori` | `DocumentAttachment` / `IncomingDocument`. |
| 10035636 | `Storage Type ori` | Selects the `Storage Connector ori` implementation. |
| 10035637 | `Storage Upload Status ori` | State of a chunked upload session. |

### Enum extension

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035635 | `Storage Msg Type ori` | `Message Type ori` (Foundation) | The 23 message types this app publishes. Captions are `Locked = true` — they are the public wire contract. |

### Interface

| Name | Purpose |
| --- | --- |
| `Storage Connector ori` | Abstraction over one storage backend: test, list, get, create, delete, copy, move, exists, and the directory equivalents. |

### Codeunits

| ID | Name | Purpose |
| --- | --- | --- |
| 10035635 | `Storage Attachment Mgt ori` | Offload, restore, link and create attachments; owns the link table. |
| 10035636 | `Storage Attachment Subscr ori` | Event subscribers that serve offloaded attachment content to the standard BC pages. |
| 10035637 | `Storage Install ori` | ChangeLog guard exception, assisted setup entry, upgrade tag. |
| 10035638 | `Storage Overview Subscr ori` | Registers the module in Foundation's message-type overview. |
| 10035639 | `Storage Account List Impl ori` | `Storage.Account.List` |
| 10035640 | `Storage Attach Link Impl ori` | `Storage.Attachment.CreateLinked` |
| 10035641 | `Storage Att. Offload Impl ori` | `Storage.Attachment.Offload` |
| 10035642 | `Storage Att. Restore Impl ori` | `Storage.Attachment.Restore` |
| 10035643 | `Storage Help Builder ori` | Builds the Markdown help document for the six domain help codeunits. |
| 10035644 | `Storage Dir Create Impl ori` | `Storage.Directory.Create` |
| 10035645 | `Storage Dir Delete Impl ori` | `Storage.Directory.Delete` |
| 10035646 | `Storage Dir Exists Impl ori` | `Storage.Directory.Exists` |
| 10035647 | `Storage Dir List Impl ori` | `Storage.Directory.List` |
| 10035648 | `Storage File Copy Impl ori` | `Storage.File.Copy` |
| 10035649 | `Storage File Create Impl ori` | `Storage.File.Create` |
| 10035650 | `Storage File Delete Impl ori` | `Storage.File.Delete` |
| 10035651 | `Storage File Exists Impl ori` | `Storage.File.Exists` |
| 10035652 | `Storage File Get Impl ori` | `Storage.File.Get` |
| 10035653 | `Storage File List Impl ori` | `Storage.File.List` |
| 10035654 | `Storage File Move Impl ori` | `Storage.File.Move` |
| 10035655 | `Storage Help Get Impl ori` | `Help.Storage.Get` — the module directory. |
| 10035656 | `Storage Upload Abort Impl ori` | `Storage.Upload.Abort` |
| 10035657 | `Storage Upload Append Impl ori` | `Storage.Upload.Append` |
| 10035658 | `Storage Upload Begin Impl ori` | `Storage.Upload.Begin` |
| 10035659 | `Storage Upload Commit Impl ori` | `Storage.Upload.Commit` |
| 10035660 | `Storage Upload Status Impl ori` | `Storage.Upload.Status` |
| 10035661 | `Storage Ext File Impl ori` | Production `Storage Connector ori` — delegates to the BC External File Storage facade. |
| 10035662 | `Storage Request Mgt ori` | Resolves `storageCode` to a connection and connector, validates parameters, wraps every backend call and shapes the response envelope. |
| 10035663 | `Storage Data Restriction ori` | Blocks the upload session and chunk tables from the generic `Data.Records.*` message types. |
| 10035664 | `Storage Reten. Policy ori` | Registers the retention policy for spent upload sessions. |
| 10035665 | `Storage Upload Mgt ori` | Owns the chunked-upload lifecycle and chunk assembly. |
| 10035667 | `Storage Attach Record Impl ori` | `Storage.Attachment.CreateForRecord` |
| 10035668 | `Storage Attach Key Subscr ori` | Supplies the primary-key field for the attachment link table to the platform. |
| 10035669 | `Storage Upload Commit Rec ori` | `Storage.Upload.CommitToRecord` |
| 10035670 | `Storage Account Help ori` | Help contract for the `Storage.Account.*` domain. |
| 10035671 | `Storage File Help ori` | Help contract for the `Storage.File.*` domain. |
| 10035672 | `Storage Dir Help ori` | Help contract for the `Storage.Directory.*` domain. |
| 10035673 | `Storage Attachment Help ori` | Help contract for the `Storage.Attachment.*` domain. |
| 10035674 | `Storage Upload Help ori` | Help contract for the `Storage.Upload.*` domain. |
| 10035675 | `Storage Overview Help ori` | Module directory served by `Help.Storage.Get`. |
| 10035676 | `Storage Takeover ori` | One-time data take-over from the published *Origo Cloud Events Storage* app. |
| 10035679 | `Storage Upload Purge ori` | Purges spent upload sessions and their chunks. |
| 10035680 | `Attachments Registration ori` | Registers this app with Foundation's `App Registry ori` so the shared Bifröst Setup page can list it and raise its setup notification. |

### Permission sets

| Type | ID | Name | Purpose |
| --- | --- | --- | --- |
| permissionset | 10035666 | `BIFROST Attach ori` | Assignable set with everything the module needs (caption *Bifrost Storage*). |
| permissionsetextension | 10035635 | `Storage Full ori` | Adds the same grants to Foundation's `BIFROST Full ori` role. |

---

## Dependencies

| App | ID | Purpose |
| --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo 28.0.0.0 — the message-type kernel (`Message Type ori`, `Msg Interface ori`, `Message Argument ori`, the Queue → Task → Data API route). |

The test app additionally depends on Bifrost Attachments itself and on Microsoft's
Tests-TestLibraries, Application Test Library, Library Assert, Test Runner, Any and
Library Variable Storage.

At runtime, at least one Business Central external file storage connector app (Azure Blob
Storage, Azure File Share or SharePoint) must be installed and configured. Those apps own the
credentials — this app only stores a registered File Account id.

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Attachments`) |
| `app/src/MessageTypes/` | Message type implementations and the six domain help codeunits |
| `app/src/Storage/` | Connector interface, production implementation, request helper |
| `app/src/Attachments/` | Attachment offload/restore, link table, table extensions |
| `app/src/Upload/` | Chunked upload session and chunk tables, upload manager, retention policy |
| `app/src/Setup/` | Setup page, connection part, wizard, card and lookup pages |
| `app/src/Install/` | `Storage Takeover ori` — data take-over from the published legacy app |
| `app/src/Permissions/` | `BIFROST Attach ori` and the `Storage Full ori` extension |
| `test/` | Test app (`Bifrost Attachments - Tests`) |
| `test/reports/` | End-to-end message-type test reports and PR gateway reports (internal, not published) |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

---

## Development

- Open `al.code-workspace` in VS Code.
- Development containers: COSMO Alpaca `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International
  Ltd.), both defined in `app/.vscode/launch.json` — git-ignored and the authority for the
  instance ids. Publish and run the unit tests on **both**; select the target with
  `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with `alc.exe` plus CodeCop, UICop and AppSourceCop. Symbols live in
  `app/.alpackages`; test symbols in `test/.alpackages`, including the Bifrost Foundation `.app`.

  ```
  alc.exe /project:app /packagecachepath:app/.alpackages /out:app/output/attachments.app ^
          /analyzer:<CodeCop.dll> /analyzer:<UICop.dll> /analyzer:<AppSourceCop.dll>
  ```

- Publish and run tests without VS Code (pwsh 7, credential from the user-level env vars
  `BC28IS_USER` / `BC28IS_PASSWORD`, never from files):
  `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>` and
  `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1`.
- Command-line `alc` does not raise AS0011 (mandatory affix); AL-Go CI is the gate, so check the
  ` ori` suffix yourself before pushing.
- `app.json` suppresses **AS0081** only — the advisory that `internalsVisibleTo` exposes internal
  objects, which is required so the test app can reach them. No other warning is suppressed.
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards).
  Project rules are in `.claude/CLAUDE.md`; agent context is in [AGENTS.md](AGENTS.md).
- Every object carries the mandatory ` ori` suffix; the brand name is carried by the namespace,
  the app name and the captions, never by an object-name prefix.

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://businesscentralal.github.io/bifrost>. There are no `docs/` or `Help/`
folders in this repository — an approved deviation from Origo PR gateway check 8.

| What | Where |
| --- | --- |
| Product documentation (overview, message types, AppSource listing) | <https://businesscentralal.github.io/bifrost/en-us/hnitbjorg/> |
| In-product help (context-sensitive help pages, en-US and is-IS) | <https://businesscentralal.github.io/bifrost/en-us/help/hnitbjorg/> |
| Building on Bifröst (extensibility guide) | <https://businesscentralal.github.io/bifrost/en-us/extensibility/> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

Message-type contracts are also served by the app itself at runtime: `Help.Storage.Get` returns
the module directory, and every message type answers its own Markdown help through
`get_message_type_help` / `Help.Implementation.Get`.

### Context-Sensitive Help

`app.json` declares `contextSensitiveHelpUrl` =
`https://businesscentralal.github.io/bifrost/{0}/help/hnitbjorg/` and `supportedLocales`
`["en-US", "is-IS"]`, so every help page must exist in both locales on the site.

| Slug | Pages that use it |
| --- | --- |
| `hnitbjorg-setup` | `Attachments Setup ori`, `Storage Conn. Part ori` |
| `storage-setup` | `Storage Setup ori`, `Storage Setup Wizard ori` |
| `storage-card` | `Storage Card ori` |
| `storage-account-lookup` | `Storage Account Lookup ori` |

---

© 2026 Origo ehf.

<!-- AUTO-UPDATE-START -->
# COSMO Alpaca AL-Go AppSource App Template

[![Use this template](https://github.com/microsoft/AL-Go/assets/10775043/ca1ecc85-2fd3-4ab5-a866-bd2e7e80259d)](https://github.com/new?template_name=Alpaca-AppSource-Template&template_owner=cosmoconsult)

This template repository can be used for managing AppSource Apps for Business Central.

It is a customized version of the [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) template and is designed to be used with [COSMO Alpaca](https://cosmoconsult.com/cosmo-alpaca).

> [!NOTE]
> If you created this repository using the GitHub web UI (for example by clicking **Use this template** on GitHub.com) instead of creating it from the COSMO Alpaca VS Code extension, you must initialize it using the [COSMO Alpaca VS Code extension](https://marketplace.visualstudio.com/items?itemName=cosmoconsult.cosmo-alpaca). To do this, simply right-click on the repository in VS Code and select _Initialize_.

Please go to https://aka.ms/AL-Go and [COSMO Docs](https://docs.cosmoconsult.com/en-us/cloud-service/alpaca) to learn more.
<!-- AUTO-UPDATE-END -->
