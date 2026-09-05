# Bifröst Hnitbjörg — Agent Context

This file gives AI agents the big-picture context needed to work in this repository correctly
and safely.

---

## What This Extension Does

**Bifröst Hnitbjörg** is the storage module of the Bifröst platform. It is a Business Central AL
extension that exposes the standard BC **External File Storage** facade — Azure Blob Storage,
Azure File Share and SharePoint — as **23 Bifröst message types**, so any external caller can
read and write cloud storage through the same Queue → Task → Data pattern that Bifröst
Foundation uses for everything else.

On top of raw file access it adds three things the base platform does not have on the wire:
**chunked uploads** (a large file delivered as a sequence of small base64 chunks), **attachment
offloading** (moving attachment content out of the BC database into storage while keeping it
transparently readable in the UI), and **attachment creation** on arbitrary records.

The module name is Norse: Hnitbjörg is the hall where the mead was stored.

---

## Who Uses It

- External systems (document capture, portals, archiving, e-commerce, AI agents) that need to
  push files into or pull files out of Business Central without a bespoke integration.
- Business Central itself, through the attachment offload/restore flow, to keep the database
  small while attachments stay openable.
- Other Origo Bifröst apps that want a file to land somewhere durable before referencing it.

---

## Repository Structure

```
app/                Business Central AL extension (publisher: Origo, ID range 10035635–10035684)
  src/
    MessageTypes/   The 23 message-type implementations, grouped by domain
      Accounts/     Storage.Account.List
      Files/        Storage.File.*
      Directories/  Storage.Directory.*
      Attachments/  Storage.Attachment.*
      Upload/       Storage.Upload.*
      Help/         Help.Storage.Get + the six domain help codeunits
      StorageMsgType.EnumExt.al   Registers every type on Foundation's Message Type ori enum
      StorageHelpBuilder.Codeunit.al  Markdown help builder used by the help codeunits
    Storage/        Storage Connector ori interface, production impl, request helper, type enum
    Attachments/    Offload/restore management, link table, the two table extensions
    Upload/         Upload session + chunk tables, upload manager, retention policy, data guard
    Setup/          Storage Setup table/list/card/wizard, account lookup, Setup page extension
    Permissions/    BIFROST Hnitbj. ori + Storage Full ori
    Install/        Storage Takeover ori (generated data take-over from the legacy app)
    Lifecycle/      Storage Install ori, Storage Overview Subscr ori
  Help/             HTML help pages (en-US and is-IS) deployed to Azure Blob
  Translations/     Generated .xlf translation files
  docs/             AppSource submission material (user scenarios, Partner Center texts)

test/               Separate test app (ID range 96200–96299)
  src/              Mock connector, mock state, test install, Storage Type enum extension
  test/             Test codeunits (Subtype = Test)

tools/
  gen_install.py    Generator for the take-over install codeunit

.AL-Go/, .github/   AL-Go for GitHub / COSMO Alpaca pipeline configuration
```

---

## Core Architectural Concepts

### The Message Loop (owned by Foundation)

Bifröst Foundation owns the Queue → Task → Data API. This app plugs into it: an external POST
creates a message whose `Type` is one of this app's enum values; Foundation resolves the enum to
the bound `* Impl ori` codeunit and calls `ExecuteBifrostTask(Argument)`; the implementation
writes its answer back onto the `Argument` and Foundation serves it from the data API.

### Interface / Enum / Impl Pattern

Every message type is:
- A **value** in `Storage Msg Type ori` (10035635), the enum extension on Foundation's
  `Message Type ori`, with a `Locked = true` caption — the key is the public wire contract.
- An **impl codeunit** named `<Name> Impl ori` that satisfies `Msg Interface ori`.
- Backed by a **domain help codeunit** that supplies `GetMessageHelpAsMarkdownDocument`.

### Domain Help Codeunits

This is the pattern that differs from the older Cloud Events apps. Instead of one help codeunit
per message type, there is **one per domain**:

| Help codeunit | Covers |
| --- | --- |
| `Storage Account Help ori` | `Storage.Account.List` |
| `Storage File Help ori` | the seven `Storage.File.*` types |
| `Storage Dir Help ori` | the four `Storage.Directory.*` types |
| `Storage Attachment Help ori` | the four `Storage.Attachment.*` types |
| `Storage Upload Help ori` | the six `Storage.Upload.*` types |
| `Storage Overview Help ori` | `Help.Storage.Get`, the module overview |

Each help codeunit does a `case` on the message type and builds the document through
`Storage Help Builder ori` (`Init` → `AddParam`/`AddError`/setters → `Render`).

### Storage Connector Abstraction

`Storage Type ori` is an extensible enum implementing `Storage Connector ori`. The single
production value, *External File Storage*, is implemented by `Storage Ext File Impl ori`, which
delegates to the BC External File Storage facade using the connector and file account registered
on the `Storage Setup ori` row. The test app adds a `Mock` value backed by an in-memory file
system, which is why almost every test runs without a live storage account.

### Request Resolution

Implementations do not read the request payload themselves. They call `Storage Request Mgt ori`,
which resolves `storageCode` → `Storage Setup ori` row → connector implementation, validates
that the row is enabled and bound to a file account, applies the row's `Base Path`, reads the
common parameters, and shapes both success and error responses.

### Chunked Upload

`Storage Upload Session ori` is the header, `Storage Upload Chunk ori` holds one row per chunk.
Appending the same `Sequence No.` twice replaces that chunk, so retries are safe. Commit reads
the chunks back in sequence order, concatenates them, writes the file through the connector and
clears the chunks. `Storage Reten. Policy ori` ships an enabled retention policy that removes
abandoned sessions.

### Attachment Offload

`Storage Attachment Mgt ori` uploads the content, writes a `Storage Attachment Link ori` row and
clears the blob. `Storage Attachment Subscr ori` subscribes to the attachment tables'
content-read hooks and streams the content back from storage when a linked record is read, so
the offload is invisible to users. The `Offloaded ori` FlowField on both attachment tables makes
offloaded records filterable.

---

## Key Design Rules

- **Never** build a help document inline in an implementation codeunit — route
  `GetMessageHelpAsMarkdownDocument` to the domain help codeunit.
- **Never** use string concatenation to build markdown — use the builder / `TextBuilder`.
- **Never** rename or renumber a message type value. The keys are the public wire contract and
  are `Locked = true`.
- **Never** put credentials, connection strings or SAS tokens in this app. The BC connector apps
  own the secrets; `Storage Setup ori` stores only a registered File Account id.
- **Always** resolve `storageCode` through `Storage Request Mgt ori`, never by reading
  `Storage Setup ori` directly in an implementation.
- **Always** return failures as `status = Error` with a helpful message. An unhandled exception
  reaching the API is a defect.
- **Always** keep `Extensible = true` on `Storage Type ori` — the test app's `Mock` backend
  depends on it.
- **Always** add new tables, pages and codeunits to `Storage Full ori`
  (`app/src/Permissions/StorageFull.PermissionSetExt.al`).
- **Always** write bilingual captions (`Comment = 'is-IS=...'`) and use "Bifröst" in the
  Icelandic text.
- Object names carry the ` ori` suffix and are at most 30 characters.

---

## What AI Agents Should Not Do Here

- Do not hand-edit `app/src/Install/StorageTakeover.Codeunit.al` — it is generated by
  `tools/gen_install.py`. Change the generator and regenerate.
- Do not add upload sessions or chunks to the generic `Data.Records.*` surface;
  `Storage Data Restriction ori` blocks them on purpose.
- Do not add API pages or OData endpoints to this app — the API surface belongs to Foundation.
- Do not use `Format()` or `Evaluate()` on enum values — use `.Names()`, `.Ordinals()`,
  `.AsInteger()`, `.FromInteger()`.
- Do not copy AL code from the legacy *Origo Cloud Events Storage* repository. Read the business
  logic and rewrite it with current patterns; the legacy repo is a reference, not a source.
- Do not carry the legacy default folder names (`cloud-events-attachments`,
  `cloud-events-uploads`) back in — the defaults are `bifrost-attachments` and
  `bifrost-uploads`.
- Do not change the object ID range or claim ids outside 10035635–10035684 (tests
  96200–96299). Request a new block in `origo_cloudevents_object_ranges.xlsx` instead.

---

## Migration Context

This app replaces the published AppSource app *Origo Cloud Events Storage*
(`7acf9361-f558-442b-a516-f5e5dd92aecb`, range 10075985–10076034). The two can be installed side
by side; `Storage Takeover ori` copies the old app's setup and attachment-link data on first
install per company and re-grants the permission set. See [CHANGELOG.md](CHANGELOG.md) for the
full rename and offset tables, and the Bifröst migration guide in
`bc-origo-bifrost-core/tools/migration/MIGRATION_GUIDE.md` for the process that produced this
repository.

---

## Testing

- Unit tests live in `test/test/` and run against the in-memory `Mock` storage backend.
- End-to-end message-type verification goes through the `origo-bc-bc28-is` MCP server
  (route `origo/bifrost/v1.0`). Keep MCP calls **serial** — parallel bursts crash the server.
- Publish and test with `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1` and
  `Run-BifrostTests.ps1` on both `bc28-is` and `bc28-w1`.
- Every message type needs at least one happy path (verified by reading the effect back) and one
  negative case that must return `status = Error` with a helpful message.
