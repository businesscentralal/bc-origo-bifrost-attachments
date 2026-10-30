namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Builds the contract chapters that name the record a message type acts on (target), the usual
/// sequence of calls (workflow), the consultant notes (notes) and one successful example for every
/// Bifröst Attachments message type. All text is English markdown or JSON by design: it is public
/// help, read with Help.Implementation.Get, and is not translated.
/// </summary>
codeunit 10035199 "Storage Contract Guide ori"
{
    Access = Internal;

    /// <summary>Builds the target chapter for one message type.</summary>
    /// <param name="MessageType">The public message type name.</param>
    /// <param name="Target">Receives the entries, in resolution order.</param>
    /// <returns>True when the type identifies an existing record or path; false for lists, help and creating types.</returns>
    procedure GetTarget(MessageType: Text; var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        case MessageType of
            'Storage.Upload.CommitToStaging':
                Target.Add(ContractMgt.TargetEntry('data.uploadId', 'upload session id (GUID)', 'The complete open session owned by the calling user.'));
            'Storage.File.Get', 'Storage.File.Exists', 'Storage.File.Delete', 'Storage.File.Create':
                begin
                    Target.Add(ContractMgt.TargetEntry('data.storageCode', 'storage connection code', 'The connection the file is in. Resolve it with Storage.Account.List.'));
                    Target.Add(ContractMgt.TargetEntry('data.path', 'relative storage path', 'The file, relative to the base path of the connection.'));
                end;
            'Storage.File.List', 'Storage.Directory.List':
                begin
                    Target.Add(ContractMgt.TargetEntry('data.storageCode', 'storage connection code', 'The connection that is listed. Resolve it with Storage.Account.List.'));
                    Target.Add(ContractMgt.TargetEntry('data.path', 'relative storage path', 'The directory that is listed. Omitted, it is the root of the connection (its base path).'));
                end;
            'Storage.Directory.Exists', 'Storage.Directory.Create', 'Storage.Directory.Delete':
                begin
                    Target.Add(ContractMgt.TargetEntry('data.storageCode', 'storage connection code', 'The connection the directory is in. Resolve it with Storage.Account.List.'));
                    Target.Add(ContractMgt.TargetEntry('data.path', 'relative storage path', 'The directory, relative to the base path of the connection.'));
                end;
            'Storage.File.Copy', 'Storage.File.Move':
                begin
                    Target.Add(ContractMgt.TargetEntry('data.storageCode', 'storage connection code', 'The connection both paths belong to. Resolve it with Storage.Account.List.'));
                    Target.Add(ContractMgt.TargetEntry('data.sourcePath', 'relative storage path', 'The file that is copied or moved.'));
                    Target.Add(ContractMgt.TargetEntry('data.targetPath', 'relative storage path', 'The path the file gets. Nothing may exist there yet.'));
                end;
            'Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status':
                Target.Add(ContractMgt.TargetEntry('data.uploadId', 'upload session id (GUID)', 'The session that Storage.Upload.Begin returned. Only the user who began the session can use it.'));
            'Storage.Upload.CommitToRecord':
                begin
                    Target.Add(ContractMgt.TargetEntry('data.uploadId', 'upload session id (GUID)', 'The session that Storage.Upload.Begin returned. Only the user who began the session can use it.'));
                    Target.Add(ContractMgt.TargetEntry('data.tableId', 'table number', 'Target DocumentAttachment: the table of the host record. tableId wins when it is not 0.'));
                    Target.Add(ContractMgt.TargetEntry('data.tableName', 'table name', 'Target DocumentAttachment: the table of the host record when tableId is absent or 0.'));
                    Target.Add(ContractMgt.TargetEntry('data.recordSystemId', 'guid', 'Target DocumentAttachment: the host record. recordSystemId wins when it is present.'));
                    Target.Add(ContractMgt.TargetEntry('data.no', 'primary key value', 'Target DocumentAttachment: the host record by a single code or text primary key of at most 20 characters, when recordSystemId is absent.'));
                    Target.Add(ContractMgt.TargetEntry('data.incomingDocumentEntryNo', 'incoming document entry no.', 'Target IncomingDocument: an existing Incoming Document to add the attachment to. Omitted, a new Incoming Document is created.'));
                end;
            'Storage.Upload.CommitToDataExchange':
                begin
                    Target.Add(ContractMgt.TargetEntry('data.uploadId', 'upload session id (GUID)', 'The session that Storage.Upload.Begin returned. Only the user who began the session can use it.'));
                    Target.Add(ContractMgt.TargetEntry('data.dataExchDefCode', 'Data Exch. Def code', 'The import definition that reads the file.'));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Target.Add(ContractMgt.TargetEntry('data.tableId', 'table number', 'The table of the host record. tableId wins when it is not 0.'));
                    Target.Add(ContractMgt.TargetEntry('data.tableName', 'table name', 'The table of the host record when tableId is absent or 0.'));
                    Target.Add(ContractMgt.TargetEntry('data.recordSystemId', 'guid', 'The host record. recordSystemId wins when it is present.'));
                    Target.Add(ContractMgt.TargetEntry('data.no', 'primary key value', 'The host record by a single code or text primary key of at most 20 characters, when recordSystemId is absent.'));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Target.Add(ContractMgt.TargetEntry('data.storageCode + data.path', 'storage connection code and relative path', 'The file in storage that the new attachment links to.'));
                    Target.Add(ContractMgt.TargetEntry('data.incomingDocumentEntryNo', 'incoming document entry no.', 'An existing Incoming Document to add the attachment to. Omitted, a new Incoming Document is created.'));
                end;
            'DataExchange.Definition.Get':
                Target.Add(ContractMgt.TargetEntry('data.code', 'Data Exch. Def code', 'The definition that is read.'));
            'DataExchange.Entry.Get':
                Target.Add(ContractMgt.TargetEntry('data.entryNo', 'Data Exch. entry no.', 'The entry that is read.'));
        end;
        exit(Target.Count() > 0);
    end;

    /// <summary>Builds the workflow chapter for one message type.</summary>
    /// <param name="MessageType">The public message type name.</param>
    /// <param name="Workflow">Receives the steps and the explanation.</param>
    /// <returns>True when the type takes part in a sequence of calls; false for the two help types.</returns>
    procedure GetWorkflow(MessageType: Text; var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
        Explanation: Text;
    begin
        Clear(Workflow);
        case MessageType of
            'Storage.Upload.CommitToStaging':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Begin', 'Open a session without storageCode.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Append', 'Send numbered base64 chunks.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.CommitToStaging', 'Store the assembled bytes and receive stagingId.'));
                    Explanation := 'Pass stagingId to the consuming message type as the same user in the same company. Its Take consumes the row; otherwise Foundation retention removes it. No storage connection is needed. Data.Records cannot access staging rows.';
                end;
            'Storage.Account.List', 'Storage.File.List', 'Storage.File.Get', 'Storage.File.Exists':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Account.List', 'Find the storageCode of an enabled connection.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.List', 'List the files of a directory to find the path.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Get', 'Download the file as base64.'));
                    Explanation := 'Every storage call starts with a storageCode from Storage.Account.List. List a directory, then read the file you chose; a file that is missing answers RecordNotFound, while Storage.File.Exists answers true or false.';
                end;
            'Storage.File.Create':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Account.List', 'Find the storageCode of an enabled connection.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Exists', 'Check whether the destination is free.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Create', 'Write the file, with overwrite true only to replace an existing one.'));
                    Explanation := 'For a file above the one-call limit use Storage.Upload.Begin, Storage.Upload.Append and Storage.Upload.Commit instead.';
                end;
            'Storage.File.Copy', 'Storage.File.Move':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Exists', 'Check that the source exists and the target path is free.'));
                    Steps.Add(ContractMgt.WorkflowStep(MessageType, 'Copy or move the file.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.List', 'Check the result in the directory.'));
                    Explanation := 'The target path must not exist. There is no overwrite option: delete the target first with Storage.File.Delete when you mean to replace it.';
                end;
            'Storage.File.Delete':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Exists', 'Check the file.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Delete', 'Delete it.'));
                    Explanation := 'A file that backs a Business Central attachment is refused. Restore the attachment with Storage.Attachment.Restore first.';
                end;
            'Storage.Directory.List', 'Storage.Directory.Exists':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Account.List', 'Find the storageCode of an enabled connection.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Directory.List', 'List the subdirectories of a directory.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.List', 'List the files of the directory you chose.'));
                    Explanation := 'Directories and files are listed separately, one directory at a time.';
                end;
            'Storage.Directory.Create':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Directory.Exists', 'Check whether the directory exists.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Directory.Create', 'Create it.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Create', 'Write files into it.'));
                    Explanation := 'Create the directory first when a later write depends on it.';
                end;
            'Storage.Directory.Delete':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.List', 'List the files that are still in the directory.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Directory.List', 'List its subdirectories.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Delete', 'Delete what is left, file by file.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Directory.Delete', 'Delete the empty directory.'));
                    Explanation := 'Only an empty directory can be deleted, and never the root of the connection.';
                end;
            'Storage.Upload.Begin', 'Storage.Upload.Append', 'Storage.Upload.Status', 'Storage.Upload.Abort', 'Storage.Upload.Commit':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Begin', 'Open the session and keep its uploadId.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Append', 'Send each chunk with its sequence number.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Status', 'Check the received size and chunk count.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Commit', 'Write the assembled file to storage.'));
                    Explanation := 'Storage.Upload.Abort discards an open session instead of committing it. To keep the file in Business Central, end with Storage.Upload.CommitToRecord; to read it with a Data Exchange definition, end with Storage.Upload.CommitToDataExchange; to hand the bytes to another app by id, end with Storage.Upload.CommitToStaging.';
                end;
            'Storage.Upload.CommitToRecord':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Begin', 'Open a session, with or without a storageCode.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Append', 'Send each chunk.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.CommitToRecord', 'Create the attachment from the assembled file.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Attachment.Offload', 'Move the content to storage later, when the database should not hold it.'));
                    Explanation := 'The file never reaches external storage unless you offload the attachment afterwards.';
                end;
            'Storage.Upload.CommitToDataExchange':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Begin', 'Open a session.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.Append', 'Send each chunk.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Upload.CommitToDataExchange', 'Read the file with the import definition into an entry.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Entry.Get', 'Inspect the parsed fields.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Entry.Process', 'Write them to the business tables when process was false.'));
                    Explanation := 'Send process true to run the mappings in the same call; the import is then committed first, so a failed mapping leaves the entry for another attempt.';
                end;
            'Storage.Attachment.Offload', 'Storage.Attachment.Restore':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Account.List', 'Find the storageCode of an enabled connection.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Attachment.Offload', 'Move the content of the attachment to storage and keep a link.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Attachment.Restore', 'Bring the content back into Business Central.'));
                    Explanation := 'Offload and Restore are a pair. Restore uses the connection recorded in the link, so it takes no storageCode.';
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.List', 'Find a file that is already in storage.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Attachment.CreateLinked', 'Link it to a new or existing Incoming Document.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Attachment.Restore', 'Bring the content into Business Central when needed.'));
                    Explanation := 'A file that arrives through Storage.Upload.Commit can be linked the same way. Send dataExchangeType and process true to turn the Incoming Document into a Business Central document in the same call.';
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Attachment.CreateForRecord', 'Attach inline content, a stored file or a copy of another attachment to a record.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.Attachment.Offload', 'Move inline content to storage later.'));
                    Explanation := 'For content above the one-call limit use Storage.Upload.Begin, Storage.Upload.Append and Storage.Upload.CommitToRecord.';
                end;
            'DataExchange.Definition.List', 'DataExchange.Definition.Get', 'DataExchange.Type.List':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Definition.List', 'Find a definition code.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Definition.Get', 'Read its lines, columns and mappings.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Type.List', 'See which Data Exchange Types use it.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Import.Run', 'Import a file with it.'));
                    Explanation := 'Every code a list returns is the exact value the next call expects.';
                end;
            'DataExchange.Type.Set':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Definition.List', 'Find the import definition.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Type.Set', 'Create or change the Data Exchange Type that points at it.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Type.List', 'Check the result.'));
                    Explanation := 'A type is what Incoming Documents use to find their import definition.';
                end;
            'DataExchange.Definition.Import', 'DataExchange.Definition.Export', 'DataExchange.Definition.Delete':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Definition.Export', 'Write an existing definition as XML.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Definition.Import', 'Install or replace definitions from XML.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Definition.Get', 'Check the installed definition.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Definition.Delete', 'Remove a definition that is no longer used.'));
                    Explanation := 'Export and Import use the same XML format as the Business Central actions of the same name, so a definition can move between environments.';
                end;
            'DataExchange.Import.Run', 'DataExchange.Entry.Get', 'DataExchange.Entry.List', 'DataExchange.Entry.Process', 'DataExchange.Entry.Delete':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Import.Run', 'Read a file into an entry with an import definition.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Entry.Get', 'Inspect the parsed fields.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Entry.Process', 'Write them to the business tables.'));
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Entry.Delete', 'Remove the entry when it is no longer needed.'));
                    Explanation := 'An entry is processed once. DataExchange.Entry.List finds older entries.';
                end;
            'DataExchange.Export.Run', 'DataExchange.PaymentExport.Run':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('DataExchange.Definition.Get', 'Read the export definition and its mapping table.'));
                    Steps.Add(ContractMgt.WorkflowStep(MessageType, 'Run the export and deliver the file.'));
                    Steps.Add(ContractMgt.WorkflowStep('Storage.File.Get', 'Read the file back from storage.'));
                    Explanation := 'Send storageCode with path or folderPath to write the file to storage, or inline true to receive it in the answer.';
                end;
            else
                exit(false);
        end;
        Workflow.Add('steps', Steps);
        Workflow.Add('text', Explanation);
        exit(true);
    end;

    /// <summary>Builds the consultant notes for one message type, as markdown.</summary>
    /// <param name="MessageType">The public message type name.</param>
    /// <param name="Notes">Receives the notes.</param>
    /// <returns>True when the type has notes.</returns>
    procedure GetNotes(MessageType: Text; var Notes: Text): Boolean
    begin
        Notes := NotesFor(MessageType);
        exit(Notes <> '');
    end;

    local procedure NotesFor(MessageType: Text): Text
    begin
        case MessageType of
            'Storage.Account.List':
                exit('- Every connection is listed, enabled or not. Check `enabled` first: a call that names a disabled connection is refused with PreconditionFailed.' + Lf() +
                    '- `description` is returned as stored, in every language. No credentials, URLs or account details are returned.' + Lf() +
                    '- `basePath` is the folder that every relative path of the connection starts in.');
            'Help.Storage.Get':
                exit('- The guide is English markdown whatever the language of the caller, and needs no storageCode.' + Lf() +
                    '- Read the contract of one message type with Help.Implementation.Get, with the type as subject.');
            'Help.DataExchange.Get':
                exit('- The guide is English markdown whatever the language of the caller, and needs no storageCode.' + Lf() +
                    '- Read the contract of one message type with Help.Implementation.Get, with the type as subject.');
            'Storage.File.List':
                exit('- Lists one directory: the files directly in `path`, across every page the connector returns. Subdirectories are not entered; Storage.Directory.List lists them.' + Lf() +
                    '- Omit `path` to list the root of the connection, which is its base path.' + Lf() +
                    '- ' + PathRules());
            'Storage.File.Get':
                exit('- The whole file comes back in one answer as base64, so a very large file makes a very large answer. `contentLength` is the size of the decoded file in bytes.' + Lf() +
                    '- A path that does not exist is answered RecordNotFound, with the path exactly as sent; any other provider failure is BusinessCentralError without the provider URL.' + Lf() +
                    '- ' + PathRules());
            'Storage.File.Exists':
                exit('- Checks files only; Storage.Directory.Exists checks directories.' + Lf() +
                    '- `exists` false is a successful answer. A connector failure while checking is answered as an error, never as false.' + Lf() +
                    '- ' + PathRules());
            'Storage.File.Create':
                exit('- An existing destination is refused with PreconditionFailed unless `overwrite` is true. A file that backs a Business Central attachment is never overwritten, even with `overwrite` true.' + Lf() +
                    '- `contentBase64` carries at most 251,658,240 bytes (240 MiB) decoded in one call; more is refused with LimitExceeded. Send larger files with Storage.Upload.Begin, Storage.Upload.Append and Storage.Upload.Commit.' + Lf() +
                    '- The path must name a file; the connection root is refused. ' + PathRules() + '' + Lf() +
                    '- ' + ExternalWriteRule());
            'Storage.File.Copy':
                exit('- The source stays where it is. The target must not exist: there is no overwrite option, and an existing target is refused with PreconditionFailed before anything is written.' + Lf() +
                    '- The source and the target must differ, and a target that backs a Business Central attachment is refused. The copy is a plain file; it is not linked to any attachment.' + Lf() +
                    '- A source that does not exist is answered RecordNotFound on `sourcePath`. ' + PathRules() + '' + Lf() +
                    '- ' + ExternalWriteRule());
            'Storage.File.Move':
                exit('- The target must not exist: there is no overwrite option, and an existing target is refused with PreconditionFailed.' + Lf() +
                    '- When the file backs Business Central attachments, their links are updated to the new path in the same transaction, before the connector moves the file; a connector error rolls the links back. The caller needs read and write permission on those attachments (PermissionDenied otherwise), and the target must lie inside the base path of every linked connection.' + Lf() +
                    '- A file that backs attachments is moved only with a connector that guarantees the source stays intact when a move fails; any other connector is refused with PreconditionFailed.' + Lf() +
                    '- ' + PathRules() + '' + Lf() +
                    '- ' + ExternalWriteRule());
            'Storage.File.Delete':
                exit('- A file that backs a Business Central attachment is refused with PreconditionFailed. Restore the attachment with Storage.Attachment.Restore, or delete the attachment in Business Central, first.' + Lf() +
                    '- The app keeps no copy: the deletion cannot be undone from Bifröst. ' + ExternalWriteRule() + '' + Lf() +
                    '- A file that does not exist is answered RecordNotFound. ' + PathRules());
            'Storage.Directory.List':
                exit('- Lists one directory: the subdirectories directly in `path`, across every page the connector returns. Files are listed with Storage.File.List.' + Lf() +
                    '- Omit `path` to list the root of the connection, which is its base path.' + Lf() +
                    '- ' + PathRules());
            'Storage.Directory.Exists':
                exit('- Checks directories only; Storage.File.Exists checks files.' + Lf() +
                    '- `exists` false is a successful answer. A connector failure while checking is answered as an error, never as false.' + Lf() +
                    '- ' + PathRules());
            'Storage.Directory.Create':
                exit('- Whether creating a directory that already exists is an error is decided by the connector.' + Lf() +
                    '- ' + PathRules() + '' + Lf() +
                    '- ' + ExternalWriteRule());
            'Storage.Directory.Delete':
                exit('- Only an empty directory is deleted: a directory that still holds a file or a subdirectory is refused with PreconditionFailed. The connection root is refused with InvalidParameter.' + Lf() +
                    '- A directory that holds files backing Business Central attachments is refused with PreconditionFailed.' + Lf() +
                    '- The app keeps no copy: the deletion cannot be undone from Bifröst. ' + ExternalWriteRule() + '' + Lf() +
                    '- ' + PathRules());
            'Storage.Attachment.Offload':
                exit('- Find candidates with Data.Records.Get on the attachment tables using the Offloaded ori field and tableView WHERE(Offloaded ori=CONST(0)). Run one offload call per record in a batch workflow.' + Lf() +
                    '- `target` IncomingDocument means an attachment line of an Incoming Document (table Incoming Document Attachment); DocumentAttachment means Document Attachment. `systemId` is the SystemId of that attachment line, not of the Incoming Document or the host record.' + Lf() +
                    '- The destination is `folderPath` and the file name when `folderPath` is sent. Otherwise an Incoming Document attachment goes to `bifrost-attachments/incoming-documents/<year>/<entry no.>/<file name>` (the year of the posting date, else of the document date, left out when neither is set), and a Document Attachment to `bifrost-attachments/<table no.>/<systemId>/<file name>`.' + Lf() +
                    '- An existing destination is refused unless `overwrite` is true, and a file that backs another attachment is never overwritten. A file that `overwrite` replaced is not deleted by Storage.Attachment.Restore.' + Lf() +
                    '- The database changes (the link, the cleared content) come first and the upload last, so a failed upload rolls them back and the attachment keeps its content. For a DocumentAttachment the Business Central external storage fields are filled too, when they exist.' + Lf() +
                    '- ' + ExternalWriteRule());
            'Storage.Attachment.Restore':
                exit('- The content is read from the linked file and written back into Business Central; the link is removed. The connection is the one recorded in the link, so the request carries no storageCode.' + Lf() +
                    '- The stored file is deleted only when Bifröst created it (an Offload to a path that was free). A file that was already in storage, or that was replaced with `overwrite` true, or that was linked with Storage.Attachment.CreateLinked, is left in place.' + Lf() +
                    '- The database changes come first and the deletion in storage last, so a failed deletion rolls the whole call back and the attachment stays offloaded. The deletion in storage cannot be rolled back once it has happened.' + Lf() +
                    '- For a DocumentAttachment the Business Central external storage fields are cleared too, when they exist.');
            'Storage.Attachment.CreateLinked':
                exit('- The file stays in storage and is never deleted by Storage.Attachment.Restore. One storage file can back only one attachment; a file that already backs another attachment is refused with PreconditionFailed.' + Lf() +
                    '- `incomingDocumentEntryNo` adds the attachment to an existing Incoming Document. Omitted, a new Incoming Document is created with `description`, or with the file name when there is none (at most 100 characters).' + Lf() +
                    '- `dataExchangeType` and `vendorNo` are set on the Incoming Document. With `process` true the transaction is committed first and the document is then processed, so a failed processing leaves the link in place and reports `processErrors` and `incomingDocumentStatus`.' + Lf() +
                    '- ' + PathRules());
            'Storage.Attachment.CreateForRecord':
                exit('- Send exactly one content source: `contentBase64` (or its alias `content`, never both), `storageCode` with `path`, or `sourceTarget` with `sourceSystemId`. Any other combination is refused with InvalidParameter.' + Lf() +
                    '- The host record is identified by `tableId` (it wins) or `tableName`, and by `recordSystemId` (it wins) or `no`. `no` works only for a table whose primary key is a single code or text field of at most 20 characters.' + Lf() +
                    '- Content from a stored file makes the attachment born offloaded: it links to the file, which stays in storage. A file that already backs another attachment is refused.' + Lf() +
                    '- `fileName` is optional only when the content is copied from another attachment, which supplies its name.' + Lf() +
                    '- The caller needs read permission on the host table and write permission on Document Attachment; a table without an attachment key is refused with PreconditionFailed.');
            'Storage.Upload.Begin':
                exit('- The default root is bifrost-uploads/. fileName must be a file name without folders; use path or folderPath for directories.' + Lf() +
                    '- `storageCode` is optional. A session without it can end in Storage.Upload.CommitToRecord, Storage.Upload.CommitToDataExchange or Storage.Upload.CommitToStaging; Storage.Upload.Commit refuses it with PreconditionFailed.' + Lf() +
                    '- With a `storageCode` the destination is `path`, else `folderPath` and `fileName`, else the folder `bifrost-uploads` and `fileName`. It is fixed when the session begins and returned as `path`; without a `storageCode`, `path` is empty.' + Lf() +
                    '- `fileName` is a name only: a folder or relative segment is refused with InvalidParameter.' + Lf() +
                    '- When `declaredSize` is above 0, a commit is refused unless the received size equals it.' + Lf() +
                    '- A session belongs to the user who began it; any other user gets RecordNotFound for its `uploadId`.');
            'Storage.Upload.Append':
                exit('- Chunks are joined in ascending `sequence` order, whatever order they arrive in. The numbers must be contiguous or the commit is refused.' + Lf() +
                    '- Sending a `sequence` again replaces that chunk.' + Lf() +
                    '- One chunk carries at most 251,658,240 bytes (240 MiB) decoded; `maxChunkBytes` in the Begin answer repeats the limit.' + Lf() +
                    '- Only an open session accepts chunks. The chunks are kept in the Business Central database until the session is committed or aborted.');
            'Storage.Upload.Commit':
                exit('- The connection and path are those fixed at Begin; the request cannot change them. An existing destination is refused unless `overwrite` is true, and a file that backs an attachment is never overwritten.' + Lf() +
                    '- The database changes (session status, deleting the chunks) come first and the write to storage last, so a failed write rolls them back and the session stays open and can be committed again.' + Lf() +
                    '- A session with no chunks, with a gap in the sequence numbers, or whose received size differs from `declaredSize` is refused with PreconditionFailed.' + Lf() +
                    '- ' + ExternalWriteRule());
            'Storage.Upload.Abort':
                exit('- Deletes the session and its chunks. Nothing is written to storage.' + Lf() +
                    '- The `uploadId` is gone afterwards: Storage.Upload.Status and any other call with it answer RecordNotFound, although this answer reports status Aborted.' + Lf() +
                    '- Only an open session can be aborted; a committed one answers PreconditionFailed.');
            'Storage.Upload.Status':
                exit('- Read-only, and available for open and committed sessions of the calling user. Another user''s session, or one that was aborted, answers RecordNotFound.' + Lf() +
                    '- `received` is the sum of the chunk sizes; `declaredSize` is 0 when none was declared; `path` is empty for a session without a storage connection.' + Lf() +
                    '- Abandoned sessions stay until an administrator purges them on the Bifröst Attachments setup page; the retention policy framework offers a one-week policy for the table.');
            'Storage.Upload.CommitToRecord':
                exit('- The content is stored in Business Central and nothing is written to external storage. The session is marked committed and its chunks are deleted.' + Lf() +
                    '- `target` DocumentAttachment (the default) attaches to a host record, identified as in Storage.Attachment.CreateForRecord. `target` IncomingDocument adds to `incomingDocumentEntryNo`, or creates a new Incoming Document with `description`, or with the file name (at most 100 characters).' + Lf() +
                    '- `fileName` replaces the file name of the session.' + Lf() +
                    '- `dataExchangeType` and `vendorNo` are set on the Incoming Document. With `process` true the transaction is committed first and the document is then processed, so a failed processing leaves the attachment in place and reports `processErrors` and `incomingDocumentStatus`.');
            'DataExchange.Definition.List':
                exit('- Read-only. `type` filters by the definition type name and `direction` by Import or Export; an unknown value is refused with InvalidParameter.' + Lf() +
                    '- Each row carries counts only; DataExchange.Definition.Get returns the lines, columns and mappings.');
            'DataExchange.Definition.Get':
                exit('- Read-only: the definition is neither run nor changed. The answer holds the full line definitions, column definitions and mappings, so a large definition makes a large answer.' + Lf() +
                    '- `usedByDataExchangeTypes` lists the codes of the Data Exchange Types that point at the definition.' + Lf() +
                    '- A code that does not exist is answered RecordNotFound.');
            'DataExchange.Type.List':
                exit('- Read-only. Every Data Exchange Type is listed, with the codeunit names of its definition.' + Lf() +
                    '- `type` is empty when the definition the type points at no longer exists.');
            'DataExchange.Entry.List':
                exit('- Read-only. `dateFrom` and `dateTo` filter on when the entry was created, inclusive, as YYYY-MM-DD or an invariant date-time; a start after the end is refused with InvalidParameter.' + Lf() +
                    '- `count` is the number of matching entries before paging; `skip` and `take` page them (`take` defaults to 100 and may not exceed 1000).' + Lf() +
                    '- The file is never returned here (`hasFileContent` says whether one exists); DataExchange.Entry.Get can return it.');
            'DataExchange.Entry.Get':
                exit('- Read-only. `fields` are paged with `skip` and `take` (`take` defaults to 100 and may not exceed 1000); `includeFields` false leaves them out.' + Lf() +
                    '- `includeFileContent` true adds `contentLength` and `contentBase64`; a file above 1 MB is refused with LimitExceeded.' + Lf() +
                    '- No mapping is run; DataExchange.Entry.Process writes the fields to the business tables.');
        end;
        exit('');
    end;

    local procedure Lf(): Text
    var
        LineFeed: Text[1];
    begin
        LineFeed[1] := 10;
        exit(LineFeed);
    end;

    local procedure PathRules(): Text
    begin
        exit('Paths are relative to the base path of the connection and use forward slashes. Outer slashes are ignored. A path with a "." or ".." segment, a backslash, an empty inner segment or a control character is refused, and the full path (base path and path) may not exceed 2048 characters.');
    end;

    local procedure ExternalWriteRule(): Text
    begin
        exit('The change happens in the external storage, outside the Business Central transaction, so it is not rolled back with it.');
    end;

    /// <summary>Puts one successful request and answer first in the examples of a type that has none.</summary>
    /// <param name="MessageType">The public message type name.</param>
    /// <param name="Examples">The examples of the type; a successful pair is put in front of them.</param>
    procedure PrependSuccessExample(MessageType: Text; var Examples: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Rebuilt: JsonArray;
        ExampleToken: JsonToken;
        RequestText: Text;
        ResponseText: Text;
    begin
        if not SuccessExample(MessageType, RequestText, ResponseText) then
            exit;
        Rebuilt.Add(ContractMgt.Example('A successful request', RequestText, ResponseText));
        foreach ExampleToken in Examples do
            Rebuilt.Add(ExampleToken);
        Examples := Rebuilt;
    end;

    local procedure SuccessExample(MessageType: Text; var RequestText: Text; var ResponseText: Text): Boolean
    var
        Guid: Text;
    begin
        Guid := '3f2504e0-4f89-11d3-9a0c-0305e82c3301';
        case MessageType of
            'Storage.File.List':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"invoices/2026"', '{"path":"invoices/2026","entries":[{"name":"INV-001.pdf","type":"File","parentDirectory":"invoices/2026"}]}', RequestText, ResponseText);
            'Storage.File.Get':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"invoices/2026/note.txt"', '{"path":"invoices/2026/note.txt","contentLength":5,"contentBase64":"aGVsbG8="}', RequestText, ResponseText);
            'Storage.File.Exists':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"invoices/2026/note.txt"', '{"path":"invoices/2026/note.txt","exists":true}', RequestText, ResponseText);
            'Storage.File.Create':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"invoices/2026/note.txt","contentBase64":"aGVsbG8="', '{"path":"invoices/2026/note.txt","contentLength":5}', RequestText, ResponseText);
            'Storage.File.Delete':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"invoices/2026/note.txt"', '{"path":"invoices/2026/note.txt"}', RequestText, ResponseText);
            'Storage.File.Copy', 'Storage.File.Move':
                Pair(MessageType, '"storageCode":"ARCHIVE","sourcePath":"invoices/2026/note.txt","targetPath":"archive/2026/note.txt"', '{"sourcePath":"invoices/2026/note.txt","targetPath":"archive/2026/note.txt"}', RequestText, ResponseText);
            'Storage.Directory.List':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"invoices"', '{"path":"invoices","entries":[{"name":"2026","type":"Directory","parentDirectory":"invoices"}]}', RequestText, ResponseText);
            'Storage.Directory.Exists':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"invoices/2026"', '{"path":"invoices/2026","exists":true}', RequestText, ResponseText);
            'Storage.Directory.Create', 'Storage.Directory.Delete':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"invoices/2027"', '{"path":"invoices/2027"}', RequestText, ResponseText);
            'Storage.Attachment.Offload':
                Pair(MessageType, '"target":"DocumentAttachment","systemId":"' + Guid + '","storageCode":"ARCHIVE"', '{"target":"DocumentAttachment","systemId":"' + Guid + '","storageCode":"ARCHIVE","path":"bifrost-attachments/1173/' + Guid + '/offer.pdf","contentLength":20480}', RequestText, ResponseText);
            'Storage.Attachment.Restore':
                Pair(MessageType, '"target":"DocumentAttachment","systemId":"' + Guid + '"', '{"target":"DocumentAttachment","systemId":"' + Guid + '","contentLength":20480}', RequestText, ResponseText);
            'Storage.Attachment.CreateLinked':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"incoming/invoice.pdf","fileName":"invoice.pdf"', '{"target":"IncomingDocument","incomingDocumentEntryNo":7,"lineNo":10000,"systemId":"' + Guid + '","storageCode":"ARCHIVE","path":"incoming/invoice.pdf","fileName":"invoice.pdf","contentLength":20480,"processed":false}', RequestText, ResponseText);
            'Storage.Attachment.CreateForRecord':
                Pair(MessageType, '"tableId":18,"no":"10000","fileName":"hello.txt","contentBase64":"aGVsbG8="', '{"target":"DocumentAttachment","tableId":18,"no":"10000","documentType":"Quote","lineNo":0,"attachmentId":3,"systemId":"' + Guid + '","fileName":"hello.txt","contentLength":5,"offloaded":false}', RequestText, ResponseText);
            'Storage.Upload.Begin':
                Pair(MessageType, '"storageCode":"ARCHIVE","fileName":"big.pdf","folderPath":"incoming","declaredSize":10', '{"uploadId":"' + Guid + '","storageCode":"ARCHIVE","path":"incoming/big.pdf","chunkSizeHint":251658240,"maxChunkBytes":251658240}', RequestText, ResponseText);
            'Storage.Upload.Append':
                Pair(MessageType, '"uploadId":"' + Guid + '","sequence":1,"contentBase64":"aGVsbG8="', '{"uploadId":"' + Guid + '","sequence":1,"received":5,"chunkCount":1}', RequestText, ResponseText);
            'Storage.Upload.Commit':
                Pair(MessageType, '"uploadId":"' + Guid + '"', '{"uploadId":"' + Guid + '","storageCode":"ARCHIVE","path":"incoming/big.pdf","contentLength":10}', RequestText, ResponseText);
            'Storage.Upload.Abort':
                Pair(MessageType, '"uploadId":"' + Guid + '"', '{"uploadId":"' + Guid + '","status":"Aborted"}', RequestText, ResponseText);
            'Storage.Upload.Status':
                Pair(MessageType, '"uploadId":"' + Guid + '"', '{"uploadId":"' + Guid + '","storageCode":"ARCHIVE","fileName":"big.pdf","path":"incoming/big.pdf","status":"Open","declaredSize":10,"received":5,"chunkCount":1}', RequestText, ResponseText);
            'Storage.Upload.CommitToRecord':
                Pair(MessageType, '"uploadId":"' + Guid + '","tableId":18,"no":"10000"', '{"target":"DocumentAttachment","tableId":18,"no":"10000","documentType":"Quote","lineNo":0,"attachmentId":4,"systemId":"' + Guid + '","fileName":"big.pdf","contentLength":10,"offloaded":false}', RequestText, ResponseText);
            'Storage.Upload.CommitToStaging':
                Pair(MessageType, '"uploadId":"' + Guid + '"', '{"stagingId":"' + Guid + '","size":3145728,"fileName":"layout.docx","nextStep":"Pass stagingId to the consuming message type as the same user in the same company. Its take consumes the staged file."}', RequestText, ResponseText);
            'Storage.Upload.CommitToDataExchange':
                Pair(MessageType, '"uploadId":"' + Guid + '","dataExchDefCode":"INVOICES"', '{"uploadId":"' + Guid + '","entryNo":12,"dataExchDefCode":"INVOICES","fileName":"invoices.csv","lineCount":2,"fieldCount":8,"processed":false}', RequestText, ResponseText);
            'DataExchange.Definition.Get':
                Pair(MessageType, '"code":"INVOICES"', '{"code":"INVOICES","name":"Invoice import","type":"Generic Import","fileType":"Variable Text","readingWritingCodeunit":"","readingWritingXmlPort":"","extDataHandlingCodeunit":"","lineDefCount":1,"mappingCount":1,"usedByDataExchangeTypes":["INVOICES"],"lineDefs":[{"code":"INVOICE","name":"Invoice","columnCount":1,"dataLineTag":"","namespace":""}],"columnDefs":[{"lineDef":"INVOICE","columnNo":1,"name":"Number","dataType":"Text","dataFormat":"","dataFormattingCulture":"","path":"","negativeSign":"","constant":""}],"mappings":[{"lineDef":"INVOICE","tableId":50100,"tableName":"Invoice Staging","mappingCodeunit":"","preMappingCodeunit":"","postMappingCodeunit":"","dataExchNoFieldId":1,"useAsIntermediateTable":true,"fieldMappings":[{"columnNo":1,"fieldId":2,"fieldName":"Number","optional":false,"multiplier":1,"overwriteValue":false,"transformationRule":""}]}]}', RequestText, ResponseText);
            'DataExchange.Entry.Get':
                Pair(MessageType, '"entryNo":12,"take":1', '{"entryNo":12,"dataExchDefCode":"INVOICES","dataExchLineDefCode":"","fileName":"invoices.csv","createdAt":"2026-10-21T09:15:00.000Z","hasFileContent":true,"fieldCount":8,"incomingEntryNo":0,"relatedRecord":"","skip":0,"take":1,"fields":[{"lineNo":1,"columnNo":1,"columnName":"Number","value":"INV-001","dataExchLineDefCode":"INVOICE"}]}', RequestText, ResponseText);
            'DataExchange.Type.Set':
                Pair(MessageType, '"code":"INVOICES","dataExchDefCode":"INVOICES","description":"Invoice import"', '{"code":"INVOICES","dataExchDefCode":"INVOICES"}', RequestText, ResponseText);
            'DataExchange.Definition.Delete':
                Pair(MessageType, '"code":"INVOICES"', '{"code":"INVOICES"}', RequestText, ResponseText);
            'DataExchange.Definition.Export':
                Pair(MessageType, '"code":"INVOICES"', '{"code":"INVOICES","name":"Invoice import","type":"Generic Import"}', RequestText, ResponseText);
            'DataExchange.Definition.Import':
                Pair(MessageType, '"storageCode":"ARCHIVE","path":"definitions/invoices.xml"', '{"codes":["INVOICES"],"lineDefs":1,"mappings":1,"overwritten":[]}', RequestText, ResponseText);
            'DataExchange.Import.Run':
                Pair(MessageType, '"dataExchDefCode":"INVOICES","storageCode":"ARCHIVE","path":"import/invoices.csv"', '{"entryNo":12,"dataExchDefCode":"INVOICES","fileName":"invoices.csv","lineCount":2,"fieldCount":8,"storageCode":"ARCHIVE","path":"import/invoices.csv","processed":false}', RequestText, ResponseText);
            'DataExchange.Entry.Process':
                Pair(MessageType, '"entryNo":12', '{"entryNo":12,"dataExchDefCode":"INVOICES","processed":true,"targets":[{"tableId":50100,"tableName":"Invoice Staging","recordsInserted":2,"recordsModified":0,"recordIds":["' + Guid + '"]}],"warnings":[]}', RequestText, ResponseText);
            'DataExchange.Entry.Delete':
                Pair(MessageType, '"entryNo":12', '{"entryNo":12,"dataExchDefCode":"INVOICES","deletedFieldCount":8}', RequestText, ResponseText);
            'DataExchange.Export.Run':
                Pair(MessageType, '"dataExchDefCode":"CUSTEXPORT","tableId":18,"storageCode":"ARCHIVE","path":"export/customers.csv"', '{"entryNo":13,"fileName":"customers.csv","dataExchDefCode":"CUSTEXPORT","recordCount":3,"storageCode":"ARCHIVE","path":"export/customers.csv","contentLength":120}', RequestText, ResponseText);
            'DataExchange.PaymentExport.Run':
                Pair(MessageType, '"journalTemplate":"PAYMENT","journalBatch":"BANK","storageCode":"ARCHIVE","path":"export/payments.xml"', '{"journalTemplate":"PAYMENT","journalBatch":"BANK","bankAccountNo":"OPERATING","paymentExportFormat":"SEPACT","lineCount":3,"exportedLineCount":3,"creditTransferRegisterNo":5,"fileName":"payments.xml","storageCode":"ARCHIVE","path":"export/payments.xml","contentLength":2048}', RequestText, ResponseText);
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure Pair(MessageType: Text; RequestData: Text; ResponseData: Text; var RequestText: Text; var ResponseText: Text)
    begin
        RequestText := '{"type":"' + MessageType + '","data":{' + RequestData + '},"lcid":1033}';
        ResponseText := '{"status":"Success","data":' + ResponseData + '}';
    end;
}
