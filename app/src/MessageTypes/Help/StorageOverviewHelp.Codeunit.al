namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Shared help document builder for the connector overview message type of the Bifrost Attachments storage connector.
/// One codeunit per message-type domain: every <c>*Impl</c> codeunit of the domain routes its
/// <c>GetMessageHelpAsMarkdownDocument</c> call here, so the Markdown contract for the whole
/// domain lives in one place.
/// </summary>
codeunit 10035675 "Storage Overview Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for one message type of this domain.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    internal procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"Help.Storage.Get":
                OverviewHelp(Argument);
        end;
    end;

    local procedure OverviewHelp(var Argument: Record "Message Argument ori")
    begin
        Argument.SetResponseMarkdown(BuildOverview());
    end;

    /// <summary>Builds the Markdown overview of the storage connector and all its message types.</summary>
    /// <returns>The overview document as Markdown.</returns>
    internal procedure BuildOverview(): Text
    var
        Builder: TextBuilder;
    begin
        Builder.AppendLine('# Bifrost Storage Connector — Message Types');
        Builder.AppendLine('');
        Builder.AppendLine('This connector exposes the Business Central **External File Storage** facade as Bifrost message types, giving read/write access to cloud storage (Azure Blob, Azure File Share, SharePoint, and any other registered External File Storage connector) from Business Central and from external callers.');
        Builder.AppendLine('');
        Builder.AppendLine('Message types are **outbound** (read/query) or **inbound** (write); all exchange JSON (`Content-Type: text/json`). Invoke any of them with the `call_message_type` tool, passing `type` = the message type name and `data` = its parameters.');
        Builder.AppendLine('');
        Builder.AppendLine('## Release information');
        Builder.AppendLine('');
        Builder.AppendLine('- **Release:** Initial release');
        Builder.AppendLine('- **Version:** 28.0.11.0');
        Builder.AppendLine('- **Supported locale(s):** en-US, is-IS');
        Builder.AppendLine('- **Supported runtime:** Business Central 28 / runtime 17.0');
        Builder.AppendLine('');
        Builder.AppendLine('## Getting started');
        Builder.AppendLine('');
        Builder.AppendLine('Recommended order for an automated caller:');
        Builder.AppendLine('');
        Builder.AppendLine('1. Call `Storage.Account.List` to discover the `storageCode` values you may use. Do not guess a code.');
        Builder.AppendLine('2. Request the per-type help (`get_message_type_help`) for the operation you intend to call to confirm its exact parameters and its **Next steps**.');
        Builder.AppendLine('3. Call the operation with a chosen `storageCode` and the operation''s parameters.');
        Builder.AppendLine('4. Inspect `status` first: on `Error`, read `error` and correct the request before retrying; on `Success`, read `data`.');
        Builder.AppendLine('');
        Builder.AppendLine('## Agent workflows');
        Builder.AppendLine('');
        Builder.AppendLine('Every per-type help document ends with a **Next steps** section naming the exact follow-up message type and the field to carry forward, so you can chain calls without guessing. The common journeys:');
        Builder.AppendLine('');
        Builder.AppendLine('**Upload a large file to external storage** (too big for a single `Storage.File.Create`):');
        Builder.AppendLine('1. `Storage.Upload.Begin` with `storageCode` + `fileName` \u2192 returns `uploadId`, `path`, `chunkSizeHint`.');
        Builder.AppendLine('2. `Storage.Upload.Append` once per chunk \u2014 read at most `chunkSizeHint` RAW bytes, base64-encode that slice on its own, send with `uploadId` and `sequence` = 1, 2, 3, ...');
        Builder.AppendLine('3. `Storage.Upload.Commit` with `uploadId` \u2192 writes the file and returns the final `path` and `contentLength`.');
        Builder.AppendLine('');
        Builder.AppendLine('**Upload a large file directly to a record** (no external storage needed):');
        Builder.AppendLine('1. `Storage.Upload.Begin` with just `fileName` (omit `storageCode`) \u2192 creates a buffer-only session.');
        Builder.AppendLine('2. `Storage.Upload.Append` once per chunk (same as above).');
        Builder.AppendLine('3. `Storage.Upload.CommitToRecord` with `uploadId` + record address (`tableId`/`no` or `recordSystemId`) \u2192 assembles chunks and stores in the database.');
        Builder.AppendLine('   - Default target is `DocumentAttachment` (any master record, sales document, posted document).');
        Builder.AppendLine('   - Set `target` = `IncomingDocument` to create an incoming document instead.');
        Builder.AppendLine('');
        Builder.AppendLine('**Attach an uploaded file to an incoming document:**');
        Builder.AppendLine('4. `Storage.Attachment.CreateLinked` with the `storageCode` + `path` from commit → creates (or reuses) an incoming document, returns `incomingDocumentEntryNo`.');
        Builder.AppendLine('5. `Incoming.Document.Get` with that entry no as `subject` → confirms the attachment; its content is served transparently from storage.');
        Builder.AppendLine('');
        Builder.AppendLine('**Attach a file to any master record** (customer, vendor, fixed asset, G/L account, bank account, ...):');
        Builder.AppendLine('- Inline: `Storage.Attachment.CreateForRecord` with `tableId`/`tableName` + `no`/`recordSystemId` + `content` (base64) + `fileName`.');
        Builder.AppendLine('- From storage (born offloaded): same call but pass `storageCode` + `path` instead of `content`. The file stays in storage and is served on demand.');
        Builder.AppendLine('- Copy from existing attachment: same call but pass `sourceTarget` + `sourceSystemId` instead of `content`. Server-side copy, nothing crosses the wire.');
        Builder.AppendLine('- Each storage path can only be linked to one attachment; use a separate upload per attachment.');
        Builder.AppendLine('');
        Builder.AppendLine('**Offload an existing BC attachment** then bring it back: `Storage.Attachment.Offload` → `Storage.Attachment.Restore`. Works for both `DocumentAttachment` and `IncomingDocument` targets.');
        Builder.AppendLine('');
        Builder.AppendLine('### Chunking rules (precise)');
        Builder.AppendLine('');
        Builder.AppendLine('- A chunk is at most `chunkSizeHint` **raw** bytes (currently 49152, about 48 KB).');
        Builder.AppendLine('- Base64-encode each chunk **independently**; never base64 the whole file and slice the resulting text — the chunk boundaries would not decode.');
        Builder.AppendLine('- `sequence` is 1-based and must be contiguous with no gaps by commit; re-sending a sequence replaces that chunk (retries are safe).');
        Builder.AppendLine('- Pass `declaredSize` (total bytes) at Begin so commit verifies nothing was lost.');
        Builder.AppendLine('- A session is private to the caller and is pruned automatically if never committed.');
        Builder.AppendLine('');
        Builder.AppendLine('## Routing');
        Builder.AppendLine('');
        Builder.AppendLine('Every request carries a **`storageCode`** that selects a row in **`Bifrost Storage Setup`**. Each row binds the code to a registered Business Central file account (a connector plus an account) and an optional **`Base Path`** prefix that is prepended to every path. The connector apps own authentication and secrets — this connector never stores credentials.');
        Builder.AppendLine('');
        Builder.AppendLine('Discover the configured codes with `Storage.Account.List`. The `path`, `sourcePath`, and `targetPath` values are relative to the connection''s base path and use forward slashes (for example `dir/sub/file.txt`).');
        Builder.AppendLine('');
        Builder.AppendLine('## Response envelope');
        Builder.AppendLine('');
        Builder.AppendLine('Every message type returns the same envelope:');
        Builder.AppendLine('');
        Builder.AppendLine('- Success — `{ "status": "Success", "data": { ... } }`');
        Builder.AppendLine('- Failure — `{ "status": "Error", "error": "<message>" }`');
        Builder.AppendLine('');
        Builder.AppendLine('File content is carried as base64 in `contentBase64`. Existence checks return `{ "path": ..., "exists": true|false }`.');
        Builder.AppendLine('');
        Builder.AppendLine('## Message types');
        Builder.AppendLine('');
        Builder.AppendLine('### Discovery');
        Builder.AppendLine('');
        Builder.AppendLine('| Message type | Required parameters | Description |');
        Builder.AppendLine('|---|---|---|');
        Builder.AppendLine('| `Help.Storage.Get` | _none_ | Returns this Markdown overview. |');
        Builder.AppendLine('| `Storage.Account.List` | _none_ | Lists the configured storage connections (codes and connectors; no secrets). |');
        Builder.AppendLine('');
        Builder.AppendLine('### Files');
        Builder.AppendLine('');
        Builder.AppendLine('| Message type | Required parameters | Description |');
        Builder.AppendLine('|---|---|---|');
        Builder.AppendLine('| `Storage.File.Exists` | `storageCode`, `path` | Reports whether a file exists. |');
        Builder.AppendLine('| `Storage.File.Get` | `storageCode`, `path` | Downloads a file as base64. |');
        Builder.AppendLine('| `Storage.File.Create` | `storageCode`, `path`, `contentBase64` | Uploads a file (overwrites where supported). |');
        Builder.AppendLine('| `Storage.File.Delete` | `storageCode`, `path` | Deletes a file. |');
        Builder.AppendLine('| `Storage.File.Copy` | `storageCode`, `sourcePath`, `targetPath` | Copies a file. |');
        Builder.AppendLine('| `Storage.File.Move` | `storageCode`, `sourcePath`, `targetPath` | Moves (renames) a file. |');
        Builder.AppendLine('| `Storage.File.List` | `storageCode`, `path` | Lists the files in a directory. |');
        Builder.AppendLine('');
        Builder.AppendLine('### Directories');
        Builder.AppendLine('');
        Builder.AppendLine('| Message type | Required parameters | Description |');
        Builder.AppendLine('|---|---|---|');
        Builder.AppendLine('| `Storage.Directory.Exists` | `storageCode`, `path` | Reports whether a directory exists. |');
        Builder.AppendLine('| `Storage.Directory.Create` | `storageCode`, `path` | Creates a directory. |');
        Builder.AppendLine('| `Storage.Directory.Delete` | `storageCode`, `path` | Deletes a directory. |');
        Builder.AppendLine('| `Storage.Directory.List` | `storageCode`, `path` | Lists the subdirectories of a directory. |');
        Builder.AppendLine('');
        Builder.AppendLine('### Attachments');
        Builder.AppendLine('');
        Builder.AppendLine('Move a Business Central attachment''s file out to storage and back. While offloaded, the file is removed from the database but stays transparently available to existing processes.');
        Builder.AppendLine('');
        Builder.AppendLine('| Message type | Required parameters | Description |');
        Builder.AppendLine('|---|---|---|');
        Builder.AppendLine('| `Storage.Attachment.Offload` | `target`, `systemId`, `storageCode` | Moves an attachment''s file to storage and clears it from the database. |');
        Builder.AppendLine('| `Storage.Attachment.Restore` | `target`, `systemId` | Brings an offloaded attachment''s file back into the database and deletes the remote copy. |');
        Builder.AppendLine('| `Storage.Attachment.CreateLinked` | `storageCode`, `path`, `fileName` | Attaches a file already in storage to a new or existing incoming document, served transparently from storage. |');
        Builder.AppendLine('| `Storage.Attachment.CreateForRecord` | `tableId`/`tableName`, `no`/`recordSystemId`, content source | Creates a document attachment on any record (customer, vendor, fixed asset, G/L account, ...) from inline base64, from storage, or by copying an existing attachment. |');
        Builder.AppendLine('');
        Builder.AppendLine('`target` is `IncomingDocument` or `DocumentAttachment`; `systemId` is the SystemId of the attachment record. `Storage.Attachment.Offload` also accepts an optional `folderPath` (one or more subfolders) that chooses where the file is stored; the file name is appended automatically. Omitting it for an incoming document yields a navigable default — `bifrost-attachments/incoming-documents/{year}/{entry no.}/{file name}` — so the blob traces back to its document.');
        Builder.AppendLine('');
        Builder.AppendLine('`Storage.Attachment.CreateForRecord` addresses the host record with `tableId`/`tableName` plus `no` or `recordSystemId`. It accepts three content sources — inline base64, a file in storage, or a copy from an existing attachment — but exactly one per call. Tables with a single Code primary key (Customer, Vendor, Fixed Asset, G/L Account, Bank Account, ...) can be addressed by `no`; all others use `recordSystemId`.');
        Builder.AppendLine('');
        Builder.AppendLine('### Chunked uploads');
        Builder.AppendLine('');
        Builder.AppendLine('Deliver a large file as a sequence of small chunks when it is too big for a single `Storage.File.Create` call or a single inline `content` parameter. Begin a session, append the file in pieces (about 48 KB of raw bytes each, base64-encoded), then commit — either to external storage or directly to a record attachment.');
        Builder.AppendLine('');
        Builder.AppendLine('| Message type | Required parameters | Description |');
        Builder.AppendLine('|---|---|---|');
        Builder.AppendLine('| `Storage.Upload.Begin` | `fileName` (+ optional `storageCode`) | Opens a session and returns an `uploadId`. Omit `storageCode` for a buffer-only session. |');
        Builder.AppendLine('| `Storage.Upload.Append` | `uploadId`, `sequence`, `contentBase64` | Appends one chunk (re-sending a sequence replaces it). |');
        Builder.AppendLine('| `Storage.Upload.Commit` | `uploadId` | Assembles the chunks and writes the file to external storage (requires `storageCode` on the session). |');
        Builder.AppendLine('| `Storage.Upload.CommitToRecord` | `uploadId`, record address | Assembles the chunks and attaches directly to a record without external storage. |');
        Builder.AppendLine('| `Storage.Upload.Abort` | `uploadId` | Discards the session without writing. |');
        Builder.AppendLine('| `Storage.Upload.Status` | `uploadId` | Reports progress and state. |');
        Builder.AppendLine('');
        Builder.AppendLine('Each upload session is private to the user that created it, so concurrent callers never see one another''s in-flight chunks. Sessions left uncommitted are pruned automatically by a retention policy.');
        Builder.AppendLine('');
        Builder.AppendLine('Request the per-type help document for any message type to get its full parameter table, request and response examples, and common errors.');
        Builder.AppendLine('');
        Builder.AppendLine('## Connector notes');
        Builder.AppendLine('');
        Builder.AppendLine('- **Accounts are registered in Business Central.** Configure connectors and accounts through the standard File Account setup; this connector references them by id and never stores credentials.');
        Builder.AppendLine('- **Directory semantics depend on the connector.** Object stores such as Azure Blob have no native directories — some connectors emulate them with zero-byte placeholder markers, others treat a folder as existing only once it contains a file. Use `Storage.Directory.Exists` to confirm rather than assuming.');
        Builder.AppendLine('- **Create overwrites.** `Storage.File.Create` replaces an existing file on connectors that support overwrite.');
        Builder.AppendLine('- **Paths can be case-sensitive** on cloud back ends — match the stored casing exactly.');
        Builder.AppendLine('- **Offloaded attachments stay transparent.** After `Storage.Attachment.Offload`, processes that read the file through the standard accessors keep working; the content is fetched from storage on demand. If the storage connection is unavailable the read fails rather than returning an empty file.');
        Builder.AppendLine('');
        Builder.AppendLine('## Initial release boundaries');
        Builder.AppendLine('');
        Builder.AppendLine('- Help documents are authored for machine-readable call guidance and deterministic request chaining.');
        Builder.AppendLine('- The connector intentionally routes through configured External File Storage accounts and does not manage credentials.');
        Builder.AppendLine('- Message contracts follow the common Bifrost response envelope with `status` and either `data` or `error`.');
        exit(Builder.ToText());
    end;
}
