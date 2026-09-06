namespace Origo.Bifrost.Attachments;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Shared help document builder for the attachment message types of the Bifrost Attachments storage connector.
/// One codeunit per message-type domain: every <c>*Impl</c> codeunit of the domain routes its
/// <c>GetMessageHelpAsMarkdownDocument</c> call here, so the Markdown contract for the whole
/// domain lives in one place.
/// </summary>
codeunit 10035673 "Storage Attachment Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for one message type of this domain.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    internal procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"Storage.Attachment.Offload":
                AttachOffloadHelp(Argument);
            MessageType::"Storage.Attachment.Restore":
                AttachRestoreHelp(Argument);
            MessageType::"Storage.Attachment.CreateLinked":
                AttachCreateLinkedHelp(Argument);
            MessageType::"Storage.Attachment.CreateForRecord":
                AttachCreateForRecordHelp(Argument);
        end;
    end;

    local procedure AttachOffloadHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
        NotesBuilder: TextBuilder;
    begin
        HelpBuilder.Init('Storage.Attachment.Offload', 'Offloads an attachment''s file to a storage connection and clears it from the database, keeping it transparently available.', 'CreateFile');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.AddParam('target', true, 'string', 'Which attachment table to act on: ''IncomingDocument'' or ''DocumentAttachment''.');
        HelpBuilder.AddParam('systemId', true, 'string (GUID)', 'The SystemId of the attachment record whose file should be offloaded.');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to upload to. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('folderPath', false, 'string', 'Optional destination folder (one or more subfolders, relative to the connection base path) where the file is stored; the file name is appended automatically. Omit to use a navigable default: for an incoming document, `bifrost-attachments/incoming-documents/{year}/{entry no.}/{file name}`, so the blob traces back to the document.');
        HelpBuilder.SetRequestExample('{ "target": "IncomingDocument", "systemId": "0f8e...-...", "storageCode": "ARCHIVE", "folderPath": "invoices/2026" }');
        HelpBuilder.AddResponseField('target', 'string', 'Echo of the target table (IncomingDocument or DocumentAttachment).');
        HelpBuilder.AddResponseField('systemId', 'string (GUID)', 'Echo of the offloaded attachment record. Pass to Storage.Attachment.Restore to bring it back.');
        HelpBuilder.AddResponseField('storageCode', 'string', 'The storage connection that now holds the file.');
        HelpBuilder.AddResponseField('path', 'string', 'The full storage path the file was stored at.');
        HelpBuilder.AddResponseField('contentLength', 'integer', 'The number of bytes uploaded to storage.');
        HelpBuilder.AddError('The attachment is already offloaded', 'Restore it first with Storage.Attachment.Restore, then offload again if needed.');
        HelpBuilder.AddError('The attachment has no content to offload', 'The record holds no file content; nothing to move.');
        HelpBuilder.AddError('No attachment record was found for the supplied SystemId', 'Verify the target table and the SystemId.');

        NotesBuilder.AppendLine('After a successful offload the file is removed from the Business Central database and served on demand from storage, so existing processes keep working. Reverse it with Storage.Attachment.Restore.');
        NotesBuilder.AppendLine('');
        NotesBuilder.AppendLine('An attachment that is already offloaded cannot be offloaded again. The call will return an error; restore it first if you need to re-offload.');
        NotesBuilder.AppendLine('');
        NotesBuilder.AppendLine('### Finding offload candidates (batch workflow)');
        NotesBuilder.AppendLine('');
        NotesBuilder.AppendLine('Both attachment tables expose a calculated field **`Offloaded ori`** (Boolean) that is `true` when the record has a storage link and `false` when its content is still in the database. Use `get_records` to discover candidates:');
        NotesBuilder.AppendLine('');
        NotesBuilder.AppendLine('- **Incoming document attachments:** `get_records` with table `Incoming Document Attachment` (133), filter `WHERE(Offloaded ori=CONST(0))`, fields `SystemId,Name,Content_Length,Incoming_Document_Entry_No`. Set target to `IncomingDocument`.');
        NotesBuilder.AppendLine('- **Document attachments:** `get_records` with table `Document Attachment` (1173), filter `WHERE(Offloaded ori=CONST(0))`, fields `SystemId,File_Name,File_Extension,Table_ID,No`. Set target to `DocumentAttachment`.');
        NotesBuilder.AppendLine('');
        NotesBuilder.Append('Loop through the results and call this message type once per record, passing the returned `SystemId` as `systemId`. Already-offloaded records (if any slip through) are rejected safely.');
        HelpBuilder.SetNotes(NotesBuilder.ToText());

        HelpBuilder.AddNextStep('To bring the file back into the database', 'Storage.Attachment.Restore', 'pass the same `target` and `systemId` — no storageCode needed, it is read from the link');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure AttachRestoreHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Attachment.Restore', 'Restores an offloaded attachment''s file from storage back into the database and deletes the remote copy.', 'GetFile');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.SetRouting('Addressed by `target` + `systemId`. The storage connection and path are read from the attachment''s offload/link record — no `storageCode` is needed.');
        HelpBuilder.AddParam('target', true, 'string', 'Which attachment table to act on: ''IncomingDocument'' or ''DocumentAttachment''.');
        HelpBuilder.AddParam('systemId', true, 'string (GUID)', 'The SystemId of the offloaded or storage-linked attachment record to bring back into the database.');
        HelpBuilder.SetRequestExample('{ "target": "IncomingDocument", "systemId": "0f8e...-..." }');
        HelpBuilder.AddResponseField('target', 'string', 'Echo of the target table.');
        HelpBuilder.AddResponseField('systemId', 'string (GUID)', 'Echo of the restored attachment record.');
        HelpBuilder.AddResponseField('contentLength', 'integer', 'The number of bytes written back into the database.');
        HelpBuilder.AddError('The attachment is not offloaded', 'Only attachments with a storage link (from Offload or CreateLinked) can be restored. Check the `Offloaded ori` field.');
        HelpBuilder.AddError('No attachment record was found for the supplied SystemId', 'Verify the target table and the SystemId.');
        HelpBuilder.SetNotes(
            'Works for attachments produced by Storage.Attachment.Offload, Storage.Attachment.CreateLinked, and Storage.Attachment.CreateForRecord (when born offloaded from a storage source). ' +
            'The storage connection and path are read from the link record, so no storageCode is needed. ' +
            'The remote file is **deleted** after the content is written back to the database — restoring is destructive to the storage copy.');

        HelpBuilder.AddNextStep('To move the file back out to storage', 'Storage.Attachment.Offload', 'pass the same `target` and `systemId` with a `storageCode`');
        HelpBuilder.AddNextStep('To create a new linked attachment from storage', 'Storage.Attachment.CreateLinked', 'for incoming documents');
        HelpBuilder.AddNextStep('To attach a storage file to any master record', 'Storage.Attachment.CreateForRecord', 'pass `storageCode` + `path` as source 2');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure AttachCreateLinkedHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Attachment.CreateLinked', 'Attaches a file already in storage to a new or existing incoming document, served transparently from storage.', 'GetFile');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The storage connection that holds the file (the same code used for the upload). Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'Path of the file within the connection — typically the `path` returned by Storage.Upload.Commit.');
        HelpBuilder.AddParam('fileName', true, 'string', 'Attachment file name including extension (e.g. ''invoice.pdf''). The extension is parsed from it.');
        HelpBuilder.AddParam('incomingDocumentEntryNo', false, 'integer', 'Attach to this existing incoming document. Omit to create a new incoming document.');
        HelpBuilder.AddParam('description', false, 'string', 'Description for the new incoming document. Defaults to fileName. Ignored when incomingDocumentEntryNo is supplied.');
        HelpBuilder.SetRequestExample('{ "storageCode": "BLOBTEST", "path": "bifrost-uploads/invoice.pdf", "fileName": "invoice.pdf" }');
        HelpBuilder.AddResponseField('target', 'string', 'Always `IncomingDocument`.');
        HelpBuilder.AddResponseField('incomingDocumentEntryNo', 'integer', 'Entry No. of the incoming document the attachment belongs to. Use it as the `subject` of Incoming.Document.Get.');
        HelpBuilder.AddResponseField('lineNo', 'integer', 'Line No. of the new attachment within the incoming document.');
        HelpBuilder.AddResponseField('systemId', 'string (GUID)', 'SystemId of the attachment record. Use it as `systemId` for Storage.Attachment.Restore.');
        HelpBuilder.AddResponseField('storageCode', 'string', 'The storage connection that serves the file.');
        HelpBuilder.AddResponseField('path', 'string', 'The storage path the attachment is served from.');
        HelpBuilder.AddResponseField('fileName', 'string', 'The attachment file name.');
        HelpBuilder.AddResponseField('contentLength', 'integer', 'The file size in bytes.');
        HelpBuilder.AddError('No file was found in storage', 'Upload the file first (Storage.Upload.Begin/Append/Commit) and pass the committed path.');
        HelpBuilder.AddError('No incoming document was found with entry no.', 'Omit incomingDocumentEntryNo to create a new document, or pass a valid entry number.');
        HelpBuilder.AddError('is already linked to another attachment', 'Each storage file can only back one attachment. Upload a separate copy or use a different path.');
        HelpBuilder.SetNotes('The attachment is created from the stored file and immediately linked, with its local content cleared, so it is served on demand from storage exactly like an offloaded attachment. The file is never copied into the database from the caller.');
        HelpBuilder.AddNextStep('To verify the attachment and read it back', 'Incoming.Document.Get', 'pass the returned `incomingDocumentEntryNo` as the `subject`');
        HelpBuilder.AddNextStep('To pull the file into the database (un-link)', 'Storage.Attachment.Restore', 'pass `target` = IncomingDocument and the returned `systemId`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure AttachCreateForRecordHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Attachment.CreateForRecord', 'Creates a document attachment on any record - customer, vendor, fixed asset, document - from base64, from storage, or by copying an existing attachment.', 'GetFile');
        HelpBuilder.SetDirection('Inbound (write)');
        HelpBuilder.SetRouting('The record is addressed with `tableId`/`tableName` plus `recordSystemId` or `no`. A `storageCode` is needed only when the content source is a file in storage.');

        HelpBuilder.AddParam('tableId', false, 'integer', 'Table the attachment belongs to. Supply this or tableName. Common values: 18 = Customer, 23 = Vendor, 27 = Item, 156 = Resource, 270 = Bank Account, 5050 = Contact, 5200 = Employee, 5600 = Fixed Asset, 167 = Job, 15 = G/L Account.');
        HelpBuilder.AddParam('tableName', false, 'string', 'Table name instead of tableId, e.g. ''Fixed Asset'', ''Customer'', ''Bank Account''. Case-insensitive match against the BC object name.');
        HelpBuilder.AddParam('recordSystemId', false, 'string (GUID)', 'SystemId of the record to attach to. Works for every table, including those with composite primary keys. Supply this or no.');
        HelpBuilder.AddParam('no', false, 'string', 'Primary key value of the record (e.g. ''10000'' for a customer, ''FA000010'' for a fixed asset). Only works for tables whose primary key is a single Code or Text field of 20 characters or less. Use recordSystemId for document tables and any table with a composite or integer key.');
        HelpBuilder.AddParam('fileName', false, 'string', 'File name including extension, e.g. ''contract.pdf''. Required unless copying from an existing attachment that already carries a name.');
        HelpBuilder.AddParam('content', false, 'base64 string', 'Content source 1: the file itself, base64-encoded inline. The content is stored in the BC database. Use for small files.');
        HelpBuilder.AddParam('storageCode', false, 'string', 'Content source 2 (with path): references a file already in storage. The attachment is born offloaded — content stays in storage and is served transparently. Use for files delivered via Storage.Upload.Commit.');
        HelpBuilder.AddParam('path', false, 'string', 'Required with storageCode. Path of the file within the storage connection — typically the `path` returned by Storage.Upload.Commit. Each path can only be linked to one attachment.');
        HelpBuilder.AddParam('sourceTarget', false, 'string', 'Content source 3 (with sourceSystemId): copies content from an existing BC attachment. Value is ''IncomingDocument'' or ''DocumentAttachment''.');
        HelpBuilder.AddParam('sourceSystemId', false, 'string (GUID)', 'SystemId of the existing attachment to copy content from. The content is duplicated server-side — nothing crosses the wire.');

        HelpBuilder.SetRequestExample(
            '// Source 1 — inline base64 on a customer:' + '\' +
            '{ "tableId": 18, "no": "10000", "fileName": "contract.txt", "content": "SGVsbG8=" }' + '\' +
            '' + '\' +
            '// Source 2 — from storage (born offloaded) on a fixed asset:' + '\' +
            '{ "tableName": "Fixed Asset", "no": "FA000010", "fileName": "deed.pdf", "storageCode": "ARCHIVE", "path": "uploads/deed.pdf" }' + '\' +
            '' + '\' +
            '// Source 3 — copy from an existing incoming document attachment to a vendor:' + '\' +
            '{ "tableId": 23, "no": "20000", "sourceTarget": "IncomingDocument", "sourceSystemId": "e4a2..." }' + '\' +
            '' + '\' +
            '// Addressing by SystemId (works for any table):' + '\' +
            '{ "tableId": 18, "recordSystemId": "b2ae4a05-...", "fileName": "note.txt", "content": "SGVsbG8=" }');

        HelpBuilder.AddResponseField('target', 'string', 'Always `DocumentAttachment`.');
        HelpBuilder.AddResponseField('tableId', 'integer', 'The table the attachment was created on.');
        HelpBuilder.AddResponseField('no', 'string', 'The record key the attachment hangs on.');
        HelpBuilder.AddResponseField('documentType', 'string', 'The document type the base application derived from the record.');
        HelpBuilder.AddResponseField('lineNo', 'integer', 'The line number the base application derived from the record.');
        HelpBuilder.AddResponseField('attachmentId', 'integer', 'The attachment''s ID within the record''s attachment list.');
        HelpBuilder.AddResponseField('systemId', 'string (GUID)', 'SystemId of the new attachment. Pass to Storage.Attachment.Offload or Restore.');
        HelpBuilder.AddResponseField('fileName', 'string', 'The final attachment file name (may be deduplicated, e.g. ''deed1.pdf'').');
        HelpBuilder.AddResponseField('contentLength', 'integer', 'The file size in bytes.');
        HelpBuilder.AddResponseField('offloaded', 'boolean', 'True when content stayed in storage (source 2). False for inline or copy sources.');
        HelpBuilder.AddResponseField('storageCode', 'string', 'Present only when offloaded. The storage connection serving the file.');
        HelpBuilder.AddResponseField('path', 'string', 'Present only when offloaded. The storage path of the file.');

        HelpBuilder.AddError('Supply exactly one content source', 'Send content, or storageCode with path, or sourceTarget with sourceSystemId — never combine two sources in the same request.');
        HelpBuilder.AddError('No record was found in table', 'The host record must exist before attaching. Check tableId and no/recordSystemId.');
        HelpBuilder.AddError('has a composite primary key', 'The table has more than one key field. Address the record with recordSystemId instead of no.');
        HelpBuilder.AddError('is not a code or text field', 'The primary key is an Integer or other non-text type. Use recordSystemId.');
        HelpBuilder.AddError('does not know which field identifies a record', 'The table is not in the set BC can key an attachment to. This connector widens that set to all tables with a single Code key; others need a subscriber on Document Attachment Mgmt.OnAfterTableHasNumberFieldPrimaryKey.');
        HelpBuilder.AddError('is longer than the 20 characters', 'The record identifier exceeds the 20-character limit of Document Attachment.No.');
        HelpBuilder.AddError('is already linked to another attachment', 'Each storage file can only back one attachment. Upload a separate copy or use a different path.');

        HelpBuilder.SetNotes(
            'Document type and line number are derived from the host record — never supply them. ' +
            'File names are deduplicated within a record: two files named ''deed.pdf'' become ''deed.pdf'' and ''deed1.pdf''. ' +
            'With the storage source (source 2) the local content is cleared and a link is recorded, so the file is served on demand — the same state as Offload produces.' + '\' +
            '' + '\' +
            '### Supported tables' + '\' +
            '' + '\' +
            'The base application natively supports: Customer (18), Vendor (23), Item (27), Employee (5200), Fixed Asset (5600), Job (167), Resource (156), and the standard Sales/Purchase document tables. ' +
            'This connector widens that set to **every table whose primary key is a single Code field of 20 characters or less** — including G/L Account (15), Bank Account (270), Contact (5050), Location (14), and any extension table with the same shape. ' +
            'For tables outside this set, use recordSystemId (always works for addressing) — but note that the base application must still be able to derive a key for the Document Attachment row.');

        HelpBuilder.AddNextStep('To deliver a large file first', 'Storage.Upload.Begin', 'then Append and Commit, and pass the committed `path` + `storageCode` here as source 2');
        HelpBuilder.AddNextStep('To move inline content out of the database later', 'Storage.Attachment.Offload', 'pass `target` = DocumentAttachment and the returned `systemId`');
        HelpBuilder.AddNextStep('To pull offloaded content back into the database', 'Storage.Attachment.Restore', 'pass `target` = DocumentAttachment and the returned `systemId`');

        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;
}
