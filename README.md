# Bifröst Hnitbjörg

**App name:** Bifrost Hnitbjorg (display form *Bifröst Hnitbjörg*)
**Publisher:** Origo
**Version:** 28.0.0.0
**App ID:** `672df32a-a0c5-4a22-b591-0efa38023e95`
**Test app ID:** `7cdb530b-b74b-446b-9ece-80e2b911bfb3`
**Object ID range:** 10035635–10035684 (tests 96200–96299)
**Namespace:** `Origo.Bifrost.Hnitbjorg`
**Target:** Cloud (BC 28 — application/platform 28.0.0.0, runtime 17.0)
**Environments:** COSMO Alpaca `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International Ltd.)

Hnitbjörg is the hall where the mead was kept — the Bifröst module that stores things. It is
the storage module of the Bifröst platform: it exposes the Business Central **External File
Storage** facade (Azure Blob Storage, Azure File Share, SharePoint) as **23 Bifröst message
types**, so any external caller can read and write cloud storage through the same
Queue → Task → Data pattern used by the rest of Bifröst.

This app is the successor of *Origo Cloud Events Storage*. Version 28.0.0.0 is a full rebrand
into a new AppSource app with a new object range and a data take-over from the published app;
see [CHANGELOG.md](CHANGELOG.md) for the migration notes.

---

## Overview

Business Central ships a File Account / External File Storage framework, but it is only
reachable from AL. Bifröst Hnitbjörg puts that framework on the wire:

- **File operations** — list, download, upload, copy, move, delete, existence check.
- **Directory operations** — list, create, delete, existence check.
- **Chunked uploads** — begin, append, commit, abort, status. A large file is delivered as a
  sequence of small base64 chunks, which sidesteps the per-request payload limit.
- **Attachment offloading** — move a Document Attachment or Incoming Document Attachment's
  file content out of the database into storage, and restore it on demand. Offloaded content
  stays transparently readable in the BC UI.
- **Attachment creation** — attach a file that is already in storage to an incoming document,
  or create a Document Attachment on any record from base64, from storage, or by copying an
  existing attachment.

No secrets live in this app. Credentials belong to the Business Central connector apps
(Azure Blob Storage Connector, SharePoint Connector, …); Hnitbjörg only references a
registered **File Account** by id.

---

## Functional Flow

```
External caller                Bifröst Foundation               Bifröst Hnitbjörg              Cloud storage
      |                                |                                |                             |
      |-- POST queue (type + JSON) --->|                                |                             |
      |                                |-- resolve Message Type ori --->|                             |
      |                                |   → "* Impl ori" codeunit      |                             |
      |                                |                                |-- resolve storageCode       |
      |                                |                                |   → Storage Setup ori row   |
      |                                |                                |-- Storage Connector ori --->|
      |                                |                                |<-- result / error ----------|
      |                                |<-- Argument.SetResponseJson ---|                             |
      |<-- GET data (response JSON) ---|                                |                             |
```

Every request carries a `storageCode`. That code selects a row in **Bifrost Storage Setup**,
which names the connector and the registered file account, plus an optional base path that is
prepended to every path in the request.

---

## Benefits

| Benefit | How |
| --- | --- |
| Smaller database | Attachments are offloaded to cloud storage and cleared from the BC database, while still opening normally in the UI. |
| No custom integration code | Storage access is a message type, not a bespoke API page or web service. |
| Large files without a large request | Chunked upload sessions assemble the file server-side. |
| No secret sprawl | Credentials stay in Microsoft's connector apps; this app stores only a file account id. |
| Discoverable contract | `Help.Storage.Get` returns a Markdown catalogue of every message type, and every type answers its own per-type help. |
| Safe by default | The upload session and chunk tables are blocked from the generic `Data.Records.*` message types; abandoned sessions are cleaned up by a retention policy. |

---

## Logic Flow

**Message dispatch.** `Storage Msg Type ori` extends Foundation's `Message Type ori` enum with
23 values. Each value binds `Msg Interface ori` to a `* Impl ori` codeunit. Foundation resolves
the enum and calls `ExecuteBifrostTask(Argument)`.

**Request resolution.** Every implementation delegates to `Storage Request Mgt ori`, which
resolves `storageCode` to a `Storage Setup ori` row, checks that the row is enabled and bound
to a file account, and returns the `Storage Connector ori` implementation to use. Errors are
returned as `status = Error` with a helpful message — never as an unhandled exception.

**Storage access.** `Storage Type ori` is an extensible enum implementing `Storage Connector ori`.
The single production value, *External File Storage*, is implemented by
`Storage Ext File Impl ori`, which delegates to the BC External File Storage facade. The test
app adds a `Mock` value backed by an in-memory file system, so the whole pipeline is testable
without a live storage account.

**Per-domain help.** Six help codeunits — `Storage Account Help ori`, `Storage File Help ori`,
`Storage Dir Help ori`, `Storage Attachment Help ori`, `Storage Upload Help ori` and
`Storage Overview Help ori` — hold the Markdown contract for their domain. Each `* Impl ori`
codeunit routes its `GetMessageHelpAsMarkdownDocument` to the help codeunit of its domain,
which builds the document with `Storage Help Builder ori`.

**Chunked upload.** `Storage Upload Begin` creates a `Storage Upload Session ori` header and
returns an `uploadId`. `Storage Upload Append` writes one `Storage Upload Chunk ori` row per
chunk; re-sending a sequence number replaces that chunk, so retries are safe.
`Storage Upload Commit` reads the chunks back in `Sequence No.` order, concatenates them and
writes the file through the connector; `Storage Upload CommitToRecord` attaches the assembled
file directly to a BC record instead. `Storage Upload Abort` discards the session.
`Storage Reten. Policy ori` cleans up sessions that are never committed.

**Attachment offload.** `Storage Attachment Mgt ori` uploads the attachment content, records a
`Storage Attachment Link ori` row and clears the blob. `Storage Attachment Subscr ori`
subscribes to the attachment tables' content-read hooks and streams the content back from
storage when a linked record is opened, so the offload is invisible to the user. The
`Offloaded ori` FlowField added to both attachment tables makes offloaded records filterable.

**Default paths.** Offloads with no `folderPath` land under `bifrost-attachments`
(for an incoming document: `bifrost-attachments/incoming-documents/{year}/{entry no.}/{file name}`);
uploads with neither `path` nor `folderPath` land under `bifrost-uploads/{fileName}`.

---

## Setup & Configuration

1. **Install a Business Central file storage connector app** — Azure Blob Storage Connector,
   Azure File Share Connector or SharePoint Connector — and register a file account in it.
2. **Enable HTTP client requests** for this extension. The assisted setup
   *Set up Bifrost Storage* (page `Storage Setup Wizard ori`) walks through this; it is also
   reachable from the **Storage** group on the Bifröst **Setup** page.
3. **Create a storage connection** on **Bifrost Storage Setup** (page `Storage Setup ori`):

   | Field | Meaning |
   | --- | --- |
   | Code | The value a Bifröst request passes as `storageCode`. |
   | Description | Free text. |
   | Storage Type | Which connector implementation carries out the action. Default: *External File Storage*. |
   | Connector | The BC external file storage connector that owns the file account. |
   | File Account Id / Name | The registered file account, chosen with **Select File Account**. |
   | Base Path | Optional prefix prepended to every path used through this connection. |
   | Enabled | Whether Bifröst requests may use this connection. |

4. **Test the connection** with the **Test Connection** action on the storage connection card.
5. **Assign permissions** — `BIFROST Hnitbj. ori` for users who only need the storage
   connections; users who already hold Foundation's `BIFROST Full ori` get storage access
   through the `Storage Full ori` permission set extension.

---

## Example Scenario

A supplier portal drops a 40 MB scanned invoice bundle that must end up as an incoming
document attachment in Business Central.

1. `Storage.Upload.Begin` — `{ "storageCode": "BLOB", "fileName": "bundle.pdf" }` → `uploadId`.
2. `Storage.Upload.Append` — one call per 3 MB chunk, `{ "uploadId": …, "sequenceNo": 1, "content": "<base64>" }`.
3. `Storage.Upload.Status` — confirms all chunks arrived and the received size matches.
4. `Storage.Upload.Commit` — assembles the chunks and writes `bifrost-uploads/bundle.pdf`.
5. `Storage.Attachment.CreateLinked` — creates the incoming document and links the stored file
   to it. The file never enters the BC database; opening the attachment streams it back from
   Azure Blob Storage.

Later, to reclaim database space on older documents, a scheduled caller sends
`Storage.Attachment.Offload` for each attachment found with `Offloaded ori = false`, and
`Storage.Attachment.Restore` if a file has to come back into the database.

---

## Message Types

| Domain | Message types |
| --- | --- |
| Discovery | `Help.Storage.Get`, `Storage.Account.List` |
| Files | `Storage.File.List`, `Storage.File.Get`, `Storage.File.Create`, `Storage.File.Delete`, `Storage.File.Copy`, `Storage.File.Move`, `Storage.File.Exists` |
| Directories | `Storage.Directory.List`, `Storage.Directory.Create`, `Storage.Directory.Delete`, `Storage.Directory.Exists` |
| Attachments | `Storage.Attachment.Offload`, `Storage.Attachment.Restore`, `Storage.Attachment.CreateLinked`, `Storage.Attachment.CreateForRecord` |
| Upload | `Storage.Upload.Begin`, `Storage.Upload.Append`, `Storage.Upload.Commit`, `Storage.Upload.Abort`, `Storage.Upload.Status`, `Storage.Upload.CommitToRecord` |

---

## Objects

### App — `app/src` (60 objects, range 10035635–10035684)

#### Tables

| ID | Name | Purpose |
| --- | --- | --- |
| 10035635 | Storage Attachment Link ori | One row per offloaded attachment: host table id, record SystemId, storage code and path, size and offload audit. |
| 10035636 | Storage Setup ori | One row per storage connection — code, connector, file account, base path, enabled flag. |
| 10035637 | Storage Upload Chunk ori | One appended chunk of a chunked upload: decoded bytes plus its sequence position. |
| 10035638 | Storage Upload Session ori | Header of a chunked upload: destination, declared and received size, chunk count, status. |

#### Table extensions

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035635 | Storage Inc. Doc. Attach. ori | Incoming Document Attachment | Adds the `Offloaded ori` FlowField (true when the content sits in storage). |
| 10035636 | Storage Doc. Attach. ori | Document Attachment | Adds the `Offloaded ori` FlowField (true when the content sits in storage). |

#### Pages

| ID | Name | Purpose |
| --- | --- | --- |
| 10035635 | Storage Account Lookup ori | Modal lookup of the BC file accounts registered for the chosen connector. |
| 10035636 | Storage Card ori | Card for one storage connection — connector, file account, base path, Test Connection. |
| 10035637 | Storage Setup ori | List of configured storage connections (Administration search target). |
| 10035638 | Storage Setup Wizard ori | Assisted setup that enables HTTP client requests for the extension. |

#### Page extensions

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035635 | Setup Ext. ori | Setup ori (Foundation) | Adds a **Storage** group with the File Account Wizard, File Accounts and Bifrost Storage Setup. |

#### Enums

| ID | Name | Purpose |
| --- | --- | --- |
| 10035635 | Storage Attachment Target ori | Which BC attachment table an offload/restore targets. |
| 10035636 | Storage Type ori | Selects the `Storage Connector ori` implementation; extensible, one production value. |
| 10035637 | Storage Upload Status ori | Lifecycle state of an upload session (Open / Committed / Aborted). |

#### Enum extensions

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035635 | Storage Msg Type ori | Message Type ori (Foundation) | Registers the 23 storage message types and binds each to its `* Impl ori` codeunit. |

#### Interfaces

| Name | Purpose |
| --- | --- |
| Storage Connector ori | Abstraction over one configured storage backend (list, get, create, delete, copy, move, exists, directory operations, test). |

#### Codeunits

| ID | Name | Purpose |
| --- | --- | --- |
| 10035635 | Storage Attachment Mgt ori | Moves attachment content between the BC database and storage; maintains the link table. |
| 10035636 | Storage Attachment Subscr ori | Streams offloaded content back on the attachment tables' content-read hooks. |
| 10035637 | Storage Install ori | Install codeunit — ChangeLog guard exception, assisted setup registration, upgrade tags. |
| 10035638 | Storage Overview Subscr ori | Appends the `Help.Storage.Get` row to Foundation's message-type overview. |
| 10035639 | Storage Account List Impl ori | `Storage.Account.List` — lists the configured connections, no secrets. |
| 10035640 | Storage Attach Link Impl ori | `Storage.Attachment.CreateLinked` — links a stored file to an incoming document. |
| 10035641 | Storage Att. Offload Impl ori | `Storage.Attachment.Offload` — moves attachment content to storage. |
| 10035642 | Storage Att. Restore Impl ori | `Storage.Attachment.Restore` — brings offloaded content back into the database. |
| 10035643 | Storage Help Builder ori | Builder that renders the AI-optimised Markdown help documents. |
| 10035644 | Storage Dir Create Impl ori | `Storage.Directory.Create`. |
| 10035645 | Storage Dir Delete Impl ori | `Storage.Directory.Delete`. |
| 10035646 | Storage Dir Exists Impl ori | `Storage.Directory.Exists`. |
| 10035647 | Storage Dir List Impl ori | `Storage.Directory.List`. |
| 10035648 | Storage File Copy Impl ori | `Storage.File.Copy`. |
| 10035649 | Storage File Create Impl ori | `Storage.File.Create` — uploads one small base64 file. |
| 10035650 | Storage File Delete Impl ori | `Storage.File.Delete`. |
| 10035651 | Storage File Exists Impl ori | `Storage.File.Exists`. |
| 10035652 | Storage File Get Impl ori | `Storage.File.Get` — downloads a file as base64. |
| 10035653 | Storage File List Impl ori | `Storage.File.List`. |
| 10035654 | Storage File Move Impl ori | `Storage.File.Move`. |
| 10035655 | Storage Help Get Impl ori | `Help.Storage.Get` — Markdown overview of the module and every message type. |
| 10035656 | Storage Upload Abort Impl ori | `Storage.Upload.Abort`. |
| 10035657 | Storage Upload Append Impl ori | `Storage.Upload.Append` — idempotent per sequence number. |
| 10035658 | Storage Upload Begin Impl ori | `Storage.Upload.Begin` — opens a session, returns the `uploadId`. |
| 10035659 | Storage Upload Commit Impl ori | `Storage.Upload.Commit` — assembles the chunks and writes the file. |
| 10035660 | Storage Upload Status Impl ori | `Storage.Upload.Status`. |
| 10035661 | Storage Ext File Impl ori | Production connector — delegates to the BC External File Storage facade. |
| 10035662 | Storage Request Mgt ori | Resolves `storageCode`, reads common request parameters, shapes responses and errors. |
| 10035663 | Storage Data Restriction ori | Blocks the upload session and chunk tables from the generic `Data.Records.*` types. |
| 10035664 | Storage Reten. Policy ori | Registers and ships the retention policy that cleans up abandoned upload sessions. |
| 10035665 | Storage Upload Mgt ori | Drives the chunked upload lifecycle (begin, append, assemble, commit, abort). |
| 10035666 | Storage Http Notif. Action ori | Notification action that opens Extension Management to enable HTTP client requests. |
| 10035667 | Storage Attach Record Impl ori | `Storage.Attachment.CreateForRecord` — Document Attachment on any record. |
| 10035668 | Storage Attach Key Subscr ori | Widens the set of tables the base app accepts as Document Attachment hosts. |
| 10035669 | Storage Upload Commit Rec ori | `Storage.Upload.CommitToRecord` — attaches the assembled upload straight to a record. |
| 10035670 | Storage Account Help ori | Markdown help contract for the account discovery domain. |
| 10035671 | Storage File Help ori | Markdown help contract for the file domain. |
| 10035672 | Storage Dir Help ori | Markdown help contract for the directory domain. |
| 10035673 | Storage Attachment Help ori | Markdown help contract for the attachment domain. |
| 10035674 | Storage Upload Help ori | Markdown help contract for the chunked-upload domain. |
| 10035675 | Storage Overview Help ori | Markdown help contract for the module overview (`Help.Storage.Get`). |
| 10035676 | Storage Takeover ori | Install codeunit that takes the published Cloud Events Storage app's data and role assignments over. |

#### Permission sets

| ID | Name | Kind | Purpose |
| --- | --- | --- | --- |
| 10035666 | BIFROST Hnitbj. ori | permissionset (Assignable) | Grants the storage setup table to users who only administer connections. |
| 10035635 | Storage Full ori | permissionsetextension of `BIFROST Full ori` | Adds the module's tables, codeunits and pages to Foundation's full-access role. |

### Test app — `test/` (8 objects, range 96200–96299)

| Type | ID | Name | Purpose |
| --- | --- | --- | --- |
| codeunit | 96200 | Storage Mock Impl | In-memory `Storage Connector ori` implementation for the tests. |
| enumextension | 96200 | Storage Type Test | Adds the `Mock` value to `Storage Type ori`. |
| codeunit | 96201 | Storage Mock State | Single-instance in-memory file system backing the mock connector. |
| codeunit | 96202 | Storage Test Install | Test-app install codeunit. |
| codeunit | 96203 | Storage Attachment Field Tests | Tests for the `Offloaded ori` FlowField and offload-candidate discovery. |
| codeunit | 96204 | Storage Connector Tests | Message-type registration, per-type help, account listing, file and directory pipeline. |
| codeunit | 96205 | Storage Upload Tests | Chunked upload roundtrip, out-of-order chunks, abort and status. |
| codeunit | 96206 | Storage Attach Record Tests | `Storage.Attachment.CreateForRecord` from all three content sources, plus its guards. |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.0.0 |

The test app additionally depends on Bifrost Hnitbjorg itself and on Microsoft's
Tests-TestLibraries, Application Test Library, Library Assert, Test Runner, Any and
Library Variable Storage.

At runtime, at least one Business Central external file storage connector app
(Azure Blob Storage, Azure File Share or SharePoint) must be installed and configured.

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Hnitbjorg`) |
| `app/src/MessageTypes/` | Message type implementations and the six domain help codeunits |
| `app/src/Storage/` | Connector interface, production implementation, request helper |
| `app/src/Attachments/` | Attachment offload/restore, link table, table extensions |
| `app/src/Upload/` | Chunked upload session and chunk tables, upload manager, retention policy |
| `app/src/Install/` | `Storage Takeover ori` — data take-over from the published legacy app |
| `app/docs/` | AppSource submission material (user scenarios, Partner Center texts) |
| `app/Help/` | HTML help (en-US, is-IS) published to origopublic blob storage |
| `test/` | Test app (`Bifrost Hnitbjorg - Tests`) |
| `tools/` | `gen_install.py` — generator for the take-over install codeunit |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

---

## Development

- Open `al.code-workspace` in VS Code.
- Development containers: COSMO Alpaca `bc28-is` and `bc28-w1` (see `app/.vscode/launch.json`,
  which is git-ignored and is the authority for the instance ids).
- Publish with `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>` and run the
  tests with `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1`.
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards).
  Project rules are in `.claude/CLAUDE.md`; agent context is in [AGENTS.md](AGENTS.md).
- Every object carries the mandatory `ori` suffix; the brand name is carried by the namespace,
  the app name and the captions, never by an object-name prefix.

---

## Documentation

- Message-type contracts are served by the app itself: `Help.Storage.Get` returns the module
  overview, and every message type answers its own per-type Markdown help through
  `get_message_type_help` / `Help.Implementation.Get`.
- AppSource submission material: `app/docs/AppSource-UserScenarios.md`,
  `app/docs/PartnerCenter-Description.md`, `app/docs/PartnerCenter-Listing.md`.
- Release notes: [CHANGELOG.md](CHANGELOG.md).

### Context-Sensitive Help

HTML help ships in English and Icelandic under `app/Help/en-US/` and `app/Help/is-IS/` and is
published to Azure Blob Storage:

- Help URL: <https://origopublic.blob.core.windows.net/help/BifrostHnitbjorg/bc28/en-US/index.html>
- Context-sensitive help URL: `https://origopublic.blob.core.windows.net/help/BifrostHnitbjorg/bc28/{0}/`

| Page | Help file |
| --- | --- |
| Storage Setup ori, Storage Setup Wizard ori | `StorageSetup.html` |
| Storage Card ori | `StorageCard.html` |
| Storage Account Lookup ori | `StorageAccountLookup.html` |

Each help file carries a language switcher to its counterpart in the other locale, and
`index.html` in each locale is the table of contents.

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
