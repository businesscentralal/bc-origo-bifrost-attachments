namespace Origo.Bifrost.Attachments;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Shared help document builder for the chunked-upload message types of the Bifrost Attachments storage connector.
/// One codeunit per message-type domain: every <c>*Impl</c> codeunit of the domain routes its
/// <c>GetMessageHelpAsMarkdownDocument</c> call here, so the Markdown contract for the whole
/// domain lives in one place.
/// </summary>
codeunit 10035674 "Storage Upload Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for one message type of this domain.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"Storage.Upload.Begin":
                UploadBeginHelp(Argument);
            MessageType::"Storage.Upload.Append":
                UploadAppendHelp(Argument);
            MessageType::"Storage.Upload.Commit":
                UploadCommitHelp(Argument);
            MessageType::"Storage.Upload.Abort":
                UploadAbortHelp(Argument);
            MessageType::"Storage.Upload.Status":
                UploadStatusHelp(Argument);
            MessageType::"Storage.Upload.CommitToRecord":
                UploadCommitToRecordHelp(Argument);
        end;
    end;

    local procedure UploadBeginHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Upload.Begin', 'Opens a chunked upload session for delivering a large file as a sequence of small chunks.', 'CreateFile');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.AddParam('storageCode', false, 'string', 'The storage connection the file is written to on Storage.Upload.Commit. Omit to create a buffer-only session that can only be committed with Storage.Upload.CommitToRecord (attaches directly to a record without external storage).');
        HelpBuilder.AddParam('fileName', true, 'string', 'File name of the upload, including extension. Used as the leaf of the default path.');
        HelpBuilder.AddParam('path', false, 'string', 'Full destination path including the file name, relative to the connection base path. Overrides folderPath. Omit both to use the default `bifrost-uploads/{fileName}`.');
        HelpBuilder.AddParam('folderPath', false, 'string', 'Destination folder (forward-slash separated); the file name is appended automatically. Ignored when path is supplied.');
        HelpBuilder.AddParam('declaredSize', false, 'integer', 'Expected total size in bytes. When supplied it is verified against the assembled size on commit; a mismatch fails the commit. Recommended for integrity.');
        HelpBuilder.SetRequestExample('{ "storageCode": "BLOBTEST", "fileName": "invoice.pdf", "folderPath": "invoices/2026", "declaredSize": 212413 }');
        HelpBuilder.AddResponseField('uploadId', 'string (GUID)', 'The session id. Pass it as `uploadId` on every Append, Commit, Abort and Status call for this upload.');
        HelpBuilder.AddResponseField('storageCode', 'string', 'Echo of the resolved storage connection.');
        HelpBuilder.AddResponseField('path', 'string', 'The destination path the committed file will be written to.');
        HelpBuilder.AddResponseField('chunkSizeHint', 'integer', 'Recommended maximum RAW bytes per chunk (currently 49152). Read at most this many bytes per chunk, base64-encode that slice on its own, and send it with Append.');
        HelpBuilder.AddError('No storage connection is configured for storageCode', 'Resolve a valid, enabled code via Storage.Account.List.');
        HelpBuilder.SetNotes('Use this when a file is too large to pass to Storage.File.Create in one call. Split the file into chunks of at most `chunkSizeHint` RAW bytes; base64-encode each chunk INDEPENDENTLY (do not base64 the whole file and then slice the text — the boundaries would not decode). Send chunks with sequence numbers 1, 2, 3, ..., then commit. A session is private to the user that created it and is pruned automatically if never committed.');
        HelpBuilder.AddNextStep('To send the file contents', 'Storage.Upload.Append', 'pass the returned `uploadId`, `sequence` starting at 1, and one base64 chunk');
        HelpBuilder.AddNextStep('To write the file to storage', 'Storage.Upload.Commit', 'pass the `uploadId` — requires a storageCode on the session');
        HelpBuilder.AddNextStep('To attach the file to a record without storage', 'Storage.Upload.CommitToRecord', 'pass the `uploadId` + record address (tableId/no)');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure UploadAppendHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Upload.Append', 'Appends one base64 chunk to an open upload session.', 'CreateFile');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.SetRouting('Addressed by `uploadId` — the session created by `Storage.Upload.Begin`. No `storageCode` is needed here; the destination was fixed at Begin.');
        HelpBuilder.AddParam('uploadId', true, 'string (GUID)', 'The session returned by Storage.Upload.Begin.');
        HelpBuilder.AddParam('sequence', true, 'integer', '1-based position of this chunk. Sequences must be contiguous (1, 2, 3, ...) with no gaps by the time you commit. Re-sending the same sequence replaces that chunk, so retries are safe.');
        HelpBuilder.AddParam('contentBase64', true, 'base64 string', 'This chunk''s raw bytes, base64-encoded on their own — no data-URI prefix, no whitespace. Keep each chunk at or below the chunkSizeHint raw bytes from Begin (~48 KB).');
        HelpBuilder.SetRequestExample('{ "uploadId": "0f8e...-...", "sequence": 1, "contentBase64": "JVBERi0xLjQK..." }');
        HelpBuilder.AddResponseField('uploadId', 'string (GUID)', 'Echo of the session id.');
        HelpBuilder.AddResponseField('sequence', 'integer', 'Echo of the accepted chunk sequence.');
        HelpBuilder.AddResponseField('received', 'integer', 'Total bytes accumulated across all chunks so far. When this equals declaredSize (or the file size you intend), you are done appending.');
        HelpBuilder.AddResponseField('chunkCount', 'integer', 'Number of distinct chunks stored so far.');
        HelpBuilder.AddError('No upload session was found for the supplied uploadId', 'Begin a session first; a session is private to its creator and may have been committed, aborted, or pruned.');
        HelpBuilder.AddError('The upload session is not open', 'It was already committed or aborted; begin a new session.');
        HelpBuilder.AddError('Invalid base64 content', 'Ensure contentBase64 is valid base64 with no surrounding whitespace or data-URI prefix.');
        HelpBuilder.SetNotes('Send chunks in order (sequence 1, 2, 3, ...). This call is idempotent per sequence — re-sending a sequence replaces that chunk.');
        HelpBuilder.AddNextStep('While more chunks remain', 'Storage.Upload.Append', 'increment `sequence` and send the next chunk');
        HelpBuilder.AddNextStep('When all chunks are sent (to external storage)', 'Storage.Upload.Commit', 'pass the same `uploadId` — requires a storageCode on the session');
        HelpBuilder.AddNextStep('When all chunks are sent (to a record, no storage)', 'Storage.Upload.CommitToRecord', 'pass the same `uploadId` + record address or `target` = IncomingDocument');
        HelpBuilder.AddNextStep('To check accumulated progress', 'Storage.Upload.Status', 'pass the same `uploadId`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure UploadCommitHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Upload.Commit', 'Assembles an upload session''s chunks and writes the file to the storage connection.', 'CreateFile');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.SetRouting('Addressed by `uploadId` — the session created by `Storage.Upload.Begin`. The destination path and storage connection were fixed at Begin.');
        HelpBuilder.AddParam('uploadId', true, 'string (GUID)', 'The session returned by Storage.Upload.Begin, after all chunks have been appended.');
        HelpBuilder.SetRequestExample('{ "uploadId": "0f8e...-..." }');
        HelpBuilder.AddResponseField('uploadId', 'string (GUID)', 'Echo of the committed session id.');
        HelpBuilder.AddResponseField('storageCode', 'string', 'The storage connection the file was written to. Carry it into Storage.Attachment.CreateLinked or Storage.File.* calls.');
        HelpBuilder.AddResponseField('path', 'string', 'The full path the file was written to. Carry it into Storage.Attachment.CreateLinked, Storage.File.Get, etc.');
        HelpBuilder.AddResponseField('contentLength', 'integer', 'The assembled file size in bytes.');
        HelpBuilder.AddError('The upload session has no chunks to commit', 'Append at least one chunk with Storage.Upload.Append before committing.');
        HelpBuilder.AddError('The upload session is missing one or more chunks', 'Sequence numbers are not contiguous; re-append the missing sequence(s) before committing.');
        HelpBuilder.AddError('The received size does not match the declared size', 'A chunk is missing or truncated; re-append it, or begin again without declaredSize.');
        HelpBuilder.AddError('The upload session is not open', 'It was already committed or aborted; begin a new session.');
        HelpBuilder.AddError('This upload session has no storage connection', 'The session was begun without a storageCode. Use Storage.Upload.CommitToRecord to attach it to a record without external storage, or begin a new session with a storageCode.');
        HelpBuilder.SetNotes('Commit assembles the chunks in ascending sequence order, writes the file last (after the database work, so a failure rolls back cleanly), and removes the chunks. Writing to an existing path overwrites it on connectors such as Azure Blob. This message type requires a storageCode on the session — use Storage.Upload.CommitToRecord instead if you want to attach the file directly to a record without external storage.');
        HelpBuilder.AddNextStep('To attach the file to a new or existing incoming document', 'Storage.Attachment.CreateLinked', 'pass the returned `storageCode` and `path`');
        HelpBuilder.AddNextStep('To attach the file to any master record (born offloaded)', 'Storage.Attachment.CreateForRecord', 'pass the returned `storageCode` and `path` as content source 2');
        HelpBuilder.AddNextStep('To download or confirm the stored file', 'Storage.File.Get', 'pass the returned `storageCode` and `path`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure UploadAbortHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Upload.Abort', 'Discards an open upload session and all its chunks without writing to storage.', '');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.SetRouting('Addressed by `uploadId` — the session created by `Storage.Upload.Begin`. Touches no storage.');
        HelpBuilder.AddParam('uploadId', true, 'string (GUID)', 'The session returned by Storage.Upload.Begin.');
        HelpBuilder.SetRequestExample('{ "uploadId": "0f8e...-..." }');
        HelpBuilder.AddResponseField('uploadId', 'string (GUID)', 'Echo of the discarded session id.');
        HelpBuilder.AddResponseField('status', 'string', 'Always `Aborted` on success.');
        HelpBuilder.AddError('No upload session was found for the supplied uploadId', 'It may have already been committed, aborted, or pruned; a session is private to its creator.');
        HelpBuilder.AddError('The upload session is not open', 'Only an open session can be aborted; a committed upload is already stored.');
        HelpBuilder.SetNotes('Aborting deletes the session and its chunks from the database. It does not touch storage, because nothing has been written there yet. Uncommitted sessions are also pruned automatically by a retention policy, so aborting is optional.');
        HelpBuilder.AddNextStep('To start a fresh upload', 'Storage.Upload.Begin', '');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure UploadStatusHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Upload.Status', 'Reports the progress and state of an upload session.', '');
        HelpBuilder.SetRouting('Addressed by `uploadId` — the session created by `Storage.Upload.Begin`.');
        HelpBuilder.AddParam('uploadId', true, 'string (GUID)', 'The session returned by Storage.Upload.Begin.');
        HelpBuilder.SetRequestExample('{ "uploadId": "0f8e...-..." }');
        HelpBuilder.AddResponseField('uploadId', 'string (GUID)', 'Echo of the session id.');
        HelpBuilder.AddResponseField('storageCode', 'string', 'The storage connection the file will be written to.');
        HelpBuilder.AddResponseField('fileName', 'string', 'The file name set at Begin.');
        HelpBuilder.AddResponseField('path', 'string', 'The destination path the committed file will be written to.');
        HelpBuilder.AddResponseField('status', 'string', '`Open`, `Committed`, or `Aborted`.');
        HelpBuilder.AddResponseField('declaredSize', 'integer', 'The expected size declared at Begin, or 0 if none was given.');
        HelpBuilder.AddResponseField('received', 'integer', 'Bytes accumulated across all chunks so far.');
        HelpBuilder.AddResponseField('chunkCount', 'integer', 'Number of chunks stored so far.');
        HelpBuilder.AddError('No upload session was found for the supplied uploadId', 'It may have been committed, aborted, or pruned; a session is private to its creator.');
        HelpBuilder.SetNotes('Use this to confirm received bytes and chunk count before committing, or to check whether a session is still open. This is a read-only query and does not change the session.');
        HelpBuilder.AddNextStep('If status is Open and bytes remain', 'Storage.Upload.Append', 'send the next chunk');
        HelpBuilder.AddNextStep('If all bytes are received', 'Storage.Upload.Commit', 'pass the same `uploadId`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure UploadCommitToRecordHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Upload.CommitToRecord', 'Assembles uploaded chunks and attaches the file directly to a record without external storage.', '');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.SetRouting('Addressed by `uploadId` from a prior `Storage.Upload.Begin`. Set `target` to choose the attachment type. For DocumentAttachment (default), address the record with `tableId`/`tableName` plus `recordSystemId` or `no`. For IncomingDocument, optionally supply `incomingDocumentEntryNo`. No `storageCode` is needed.');

        HelpBuilder.AddParam('uploadId', true, 'string (GUID)', 'The session returned by Storage.Upload.Begin.');
        HelpBuilder.AddParam('target', false, 'string', '''DocumentAttachment'' (default) or ''IncomingDocument''. Controls which attachment table the file is written to.');
        HelpBuilder.AddParam('tableId', false, 'integer', 'DocumentAttachment: table the attachment belongs to. 18 = Customer, 23 = Vendor, 36 = Sales Header (use recordSystemId), 112 = Sales Invoice Header, 5600 = Fixed Asset, etc.');
        HelpBuilder.AddParam('tableName', false, 'string', 'DocumentAttachment: table name instead of tableId.');
        HelpBuilder.AddParam('recordSystemId', false, 'string (GUID)', 'DocumentAttachment: SystemId of the record. Required for tables with composite keys (sales/purchase documents).');
        HelpBuilder.AddParam('no', false, 'string', 'DocumentAttachment: primary key of the record. Only for single Code key tables.');
        HelpBuilder.AddParam('incomingDocumentEntryNo', false, 'integer', 'IncomingDocument: attach to this existing incoming document. Omit to create a new one.');
        HelpBuilder.AddParam('description', false, 'string', 'IncomingDocument: description for a new incoming document. Defaults to fileName.');
        HelpBuilder.AddParam('fileName', false, 'string', 'Overrides the file name from Begin. If omitted, the session''s original fileName is used.');

        HelpBuilder.SetRequestExample(
            '// Attach to a customer (DocumentAttachment, default):' + '\' +
            '{ "uploadId": "0f8e...", "tableId": 18, "no": "10000" }' + '\' +
            '' + '\' +
            '// Attach to a sales quote by SystemId:' + '\' +
            '{ "uploadId": "0f8e...", "tableId": 36, "recordSystemId": "04df3c11-..." }' + '\' +
            '' + '\' +
            '// Create as incoming document:' + '\' +
            '{ "uploadId": "0f8e...", "target": "IncomingDocument", "description": "Scanned invoice" }');

        HelpBuilder.AddResponseField('target', 'string', '`DocumentAttachment` or `IncomingDocument`.');
        HelpBuilder.AddResponseField('tableId', 'integer', 'DocumentAttachment: the table the attachment was created on.');
        HelpBuilder.AddResponseField('no', 'string', 'DocumentAttachment: the record key.');
        HelpBuilder.AddResponseField('incomingDocumentEntryNo', 'integer', 'IncomingDocument: entry no. of the incoming document.');
        HelpBuilder.AddResponseField('systemId', 'string (GUID)', 'SystemId of the new attachment.');
        HelpBuilder.AddResponseField('fileName', 'string', 'The final attachment file name.');
        HelpBuilder.AddResponseField('contentLength', 'integer', 'The file size in bytes.');
        HelpBuilder.AddResponseField('offloaded', 'boolean', 'Always false — content is stored in the database.');

        HelpBuilder.AddError('No upload session was found', 'Begin a session first with Storage.Upload.Begin.');
        HelpBuilder.AddError('The upload session is not open', 'It was already committed or aborted; begin a new session.');
        HelpBuilder.AddError('No record was found in table', 'DocumentAttachment: the host record must exist.');
        HelpBuilder.AddError('Unknown target', 'Use ''DocumentAttachment'' or ''IncomingDocument''.');

        HelpBuilder.SetNotes(
            'The storage-free alternative to Storage.Upload.Commit. Chunks are assembled and written directly into the database — no external storage connection is needed. ' +
            'Begin the session with or without a `storageCode`; omitting it creates a buffer-only session.' + '\' +
            '' + '\' +
            '### Workflow' + '\' +
            '1. `Storage.Upload.Begin` with `fileName` (storageCode is optional).' + '\' +
            '2. `Storage.Upload.Append` once per chunk.' + '\' +
            '3. `Storage.Upload.CommitToRecord` with `uploadId` + target + record address.' + '\' +
            '' + '\' +
            '### Target differences' + '\' +
            '- **DocumentAttachment** (default): requires `tableId`/`tableName` + `no`/`recordSystemId`. Works for master records (Customer, Vendor, FA) and documents (Sales Header via recordSystemId, Posted Sales Invoice via no).' + '\' +
            '- **IncomingDocument**: creates or reuses an incoming document. Optionally pass `incomingDocumentEntryNo` to attach to an existing one.');

        HelpBuilder.AddNextStep('To offload the attachment to storage later', 'Storage.Attachment.Offload', 'pass the returned `target` and `systemId`');

        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;
}
