namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>Builds the shared contract chapters for Bifröst Attachments message types.</summary>
codeunit 70013500 "Storage Contract Parts ori"
{
    Access = Internal;

    /// <summary>Builds the envelope shared by storage requests.</summary>
    procedure GetEnvelope(DataRequired: Boolean) Envelope: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The storage message is identified by its message type; it has no subject record.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', DataRequired);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Builds the request parameters read by one message type.</summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Storage.Account.List', 'Help.Storage.Get', 'Help.DataExchange.Get', 'DataExchange.Type.List'] then
            exit;

        if not (MessageType in ['Storage.Attachment.Restore', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status', 'DataExchange.Definition.Get', 'DataExchange.Entry.Get']) then
            Parameters.Add(ContractMgt.Parameter('storageCode', 'string', true, 'The configured storage connection code. Resolve it with Storage.Account.List.'));
        case MessageType of
            'Storage.File.List', 'Storage.Directory.List':
                Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The directory path relative to the connection base path.'));
            'Storage.File.Get', 'Storage.File.Delete', 'Storage.File.Exists', 'Storage.Directory.Create', 'Storage.Directory.Delete', 'Storage.Directory.Exists':
                Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The file or directory path relative to the connection base path.'));
            'Storage.File.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The destination file path relative to the connection base path.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, 'The complete file content encoded as base64.'));
                end;
            'Storage.File.Copy', 'Storage.File.Move':
                begin
                    Parameters.Add(ContractMgt.Parameter('sourcePath', 'string', true, 'The source file path relative to the connection base path.'));
                    Parameters.Add(ContractMgt.Parameter('targetPath', 'string', true, 'The destination file path relative to the connection base path.'));
                end;
            'Storage.Attachment.Offload':
                begin
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, 'The attachment table: IncomingDocument or DocumentAttachment.'));
                    Parameters.Add(ContractMgt.Parameter('systemId', 'string', true, 'The attachment SystemId.'));
                    Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, 'Optional destination folder.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, 'The attachment table: IncomingDocument or DocumentAttachment.'));
                    Parameters.Add(ContractMgt.Parameter('systemId', 'string', true, 'The attachment SystemId.'));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The file path in storage.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, 'The attachment file name.'));
                    Parameters.Add(ContractMgt.Parameter('incomingDocumentEntryNo', 'integer', false, 'An existing incoming document entry number.'));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'Description for a new incoming document.'));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, 'The host record table id.'));
                    Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, 'The host record table name.'));
                    Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'The host record SystemId.'));
                    Parameters.Add(ContractMgt.Parameter('no', 'string', false, 'The host record primary key.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, 'The attachment file name.'));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The source file path in storage.'));
                end;
            'Storage.Upload.Begin':
                begin
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, 'The leaf file name.'));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The full destination path.'));
                    Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, 'The destination folder.'));
                    Parameters.Add(ContractMgt.Parameter('declaredSize', 'integer', false, 'The expected total size in bytes.'));
                end;
            'Storage.Upload.Append':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
                    Parameters.Add(ContractMgt.Parameter('sequence', 'integer', true, 'The one-based chunk sequence.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, 'The chunk content encoded as base64.'));
                end;
            'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status':
                Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
            'Storage.Upload.CommitToRecord':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
                    Parameters.Add(ContractMgt.Parameter('target', 'string', false, 'DocumentAttachment or IncomingDocument.'));
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, 'The host record table id.'));
                    Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'The host record SystemId.'));
                    Parameters.Add(ContractMgt.Parameter('no', 'string', false, 'The host record primary key.'));
                    Parameters.Add(ContractMgt.Parameter('incomingDocumentEntryNo', 'integer', false, 'An existing incoming document entry number.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, 'An optional replacement file name.'));
                end;
            'DataExchange.Definition.List':
                begin
                    Parameters.Add(ContractMgt.Parameter('type', 'string', false, 'Optional definition type filter.'));
                    Parameters.Add(ContractMgt.Parameter('direction', 'string', false, 'Import or Export.'));
                end;
            'DataExchange.Definition.Get':
                Parameters.Add(ContractMgt.Parameter('code', 'string', true, 'The Data Exchange definition code.'));
            'DataExchange.Entry.List':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', false, 'Optional definition code filter.'));
                    Parameters.Add(ContractMgt.Parameter('dateFrom', 'string', false, 'Inclusive start date or datetime.'));
                    Parameters.Add(ContractMgt.Parameter('dateTo', 'string', false, 'Inclusive end date or datetime.'));
                    Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, 'Rows to skip.'));
                    Parameters.Add(ContractMgt.Parameter('take', 'integer', false, 'Page size.'));
                end;
            'DataExchange.Entry.Get':
                begin
                    Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, 'The Data Exchange entry number.'));
                    Parameters.Add(ContractMgt.Parameter('includeFields', 'boolean', false, 'Whether to include fields.'));
                    Parameters.Add(ContractMgt.Parameter('includeFileContent', 'boolean', false, 'Whether to include file content.'));
                    Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, 'Fields to skip.'));
                    Parameters.Add(ContractMgt.Parameter('take', 'integer', false, 'Field page size.'));
                end;
        end;
    end;

    /// <summary>Builds the target chapter for attachment records.</summary>
    procedure GetAttachmentTarget() Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.target + data.systemId', 'attachment record', 'The attachment table and SystemId identify the attachment.'));
    end;

    /// <summary>Builds the success response fields for one message type.</summary>
    procedure GetResponse(MessageType: Text) Response: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        case MessageType of
            'Help.Storage.Get':
                Fields.Add(ContractMgt.ResponseField('markdown', 'string', 'The storage connector overview and message type guidance.'));
            'Help.DataExchange.Get':
                Fields.Add(ContractMgt.ResponseField('markdown', 'string', 'The Data Exchange discovery overview and workflow guidance.'));
            'Storage.Account.List':
                Fields.Add(ContractMgt.ResponseField('accounts', 'array', 'Configured storage connections without secrets.'));
            'Storage.File.List', 'Storage.Directory.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The requested directory path.'));
                    Fields.Add(ContractMgt.ResponseField('entries', 'array', 'The files or directories found at the path.'));
                end;
            'Storage.File.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The downloaded file path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                    Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', 'The file content encoded as base64.'));
                end;
            'Storage.File.Exists', 'Storage.Directory.Exists':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The checked path.'));
                    Fields.Add(ContractMgt.ResponseField('exists', 'boolean', 'Whether the path exists.'));
                end;
            'Storage.File.Create', 'Storage.File.Delete', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create', 'Storage.Directory.Delete':
                Fields.Add(ContractMgt.ResponseField('path', 'string', 'The affected path.'));
            'Storage.Attachment.Offload':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment table.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The storage path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment table.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.CommitToRecord':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment target.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The new attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', 'The final attachment file name.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Upload.Begin':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The destination path.'));
                    Fields.Add(ContractMgt.ResponseField('maxChunkBytes', 'integer', 'The maximum raw chunk size.'));
                end;
            'Storage.Upload.Append':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('sequence', 'integer', 'The accepted chunk sequence.'));
                    Fields.Add(ContractMgt.ResponseField('received', 'integer', 'Bytes accumulated so far.'));
                end;
            'Storage.Upload.Commit':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The committed upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', 'The storage connection.'));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The committed file path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Upload.Abort':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The aborted upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'The resulting status.'));
                end;
            'Storage.Upload.Status':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'The upload state.'));
                    Fields.Add(ContractMgt.ResponseField('received', 'integer', 'Bytes accumulated so far.'));
                    Fields.Add(ContractMgt.ResponseField('chunkCount', 'integer', 'Chunks stored so far.'));
                end;
            'DataExchange.Definition.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Number of matching definitions.'));
                    Fields.Add(ContractMgt.ResponseField('definitions', 'array', 'Matching definitions.'));
                end;
            'DataExchange.Definition.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('code', 'string', 'The definition code.'));
                    Fields.Add(ContractMgt.ResponseField('lineDefs', 'array', 'Line definitions.'));
                    Fields.Add(ContractMgt.ResponseField('columnDefs', 'array', 'Column definitions.'));
                    Fields.Add(ContractMgt.ResponseField('mappings', 'array', 'Field mappings.'));
                end;
            'DataExchange.Type.List':
                Fields.Add(ContractMgt.ResponseField('types', 'array', 'Data Exchange Type rows.'));
            'DataExchange.Entry.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Number of matching entries.'));
                    Fields.Add(ContractMgt.ResponseField('entries', 'array', 'Matching entries.'));
                end;
            'DataExchange.Entry.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number.'));
                    Fields.Add(ContractMgt.ResponseField('fields', 'array', 'Paged entry fields.'));
                    Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', 'Optional file content.'));
                end;
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Builds the known errors returned by one message type.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Storage.File.Create', 'Storage.Upload.Append'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'The contentBase64 value is not valid base64.', 'Send valid base64 content.'));
        if MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'A linked Business Central attachment prevents the delete.', 'Restore or remove the attachment first.'));
        if MessageType in ['Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.CommitToRecord'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The upload session is missing, closed or incomplete.', 'Begin a new session or complete the missing chunks.'));
        if MessageType in ['DataExchange.Definition.Get'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The definition code does not exist.', 'Use DataExchange.Definition.List first.'));
        if MessageType in ['DataExchange.Entry.Get'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The entry number does not exist.', 'Use DataExchange.Entry.List first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The storage connector rejects or cannot complete the operation.', 'Check the path, connection and connector error details.'));
    end;

    /// <summary>Builds the operation effect for one message type.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    begin
        if MessageType in ['Storage.Attachment.Restore', 'Storage.File.Delete', 'Storage.Directory.Delete'] then
            Effect.Add('effect', 'irreversible')
        else if MessageType in ['Storage.Attachment.Offload', 'Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Begin', 'Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.CommitToRecord', 'Storage.File.Create', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create'] then
            Effect.Add('effect', 'write')
        else
            Effect.Add('effect', 'read');
        Effect.Add('changes', 'The operation changes only the external storage state described by the message.');
        Effect.Add('idempotent', MessageType in ['Storage.Account.List', 'Storage.File.List', 'Storage.File.Get', 'Storage.File.Exists', 'Storage.Directory.List', 'Storage.Directory.Exists', 'Storage.Upload.Status', 'DataExchange.Definition.List', 'DataExchange.Definition.Get', 'DataExchange.Type.List', 'DataExchange.Entry.List', 'DataExchange.Entry.Get']);
        Effect.Add('permissionSet', 'BIFROST Attach ori');
        Effect.Add('preconditions', 'The storage connection exists, is enabled and permits the requested operation.');
    end;

    /// <summary>Builds related message types for one message type.</summary>
    procedure GetRelated(MessageType: Text) Related: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Help.Storage.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Account.List', 'Choose a configured storage connection.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files in a storage connection.'));
                end;
            'Help.DataExchange.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'Discover available Data Exchange definitions.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', 'List processed Data Exchange entries.'));
                end;
            'Storage.Account.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files after choosing a storageCode.'));
            'Storage.File.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', 'List subdirectories instead of files.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Download one listed file.'));
                end;
            'Storage.File.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Exists', 'Check whether a file exists without downloading it.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Create', 'Upload a file instead of downloading it.'));
                end;
            'Storage.File.Create':
                Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Begin', 'Upload a file larger than the single-call limit.'));
            'Storage.File.Delete':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Exists', 'Check whether the file exists first.'));
            'Storage.File.Copy':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Move', 'Move the file and remove the original path.'));
            'Storage.File.Move':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Copy', 'Copy the file while keeping the original.'));
            'Storage.Directory.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files instead of subdirectories.'));
            'Storage.Directory.Create':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.Delete', 'Remove a directory.'));
            'Storage.Directory.Delete':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.Exists', 'Check whether the directory exists first.'));
            'Storage.Directory.Exists':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', 'List the directory contents.'));
            'Storage.Attachment.Offload':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Restore', 'Bring the file back into the database.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Account.List', 'Find a storageCode.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move the file back to storage.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.CreateLinked', 'Create a new linked attachment.'));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Use the path of a committed upload.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Restore', 'Bring the linked file into the database.'));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToRecord', 'Attach a chunked upload directly to a record.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move inline content to storage later.'));
                end;
            'Storage.Upload.Begin':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', 'Send each chunk.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Write the completed file to storage.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToRecord', 'Attach the completed file without storage.'));
                end;
            'Storage.Upload.Append':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Status', 'Check received bytes.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Commit the completed upload.'));
                end;
            'Storage.Upload.Commit':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Download the committed file.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.CreateLinked', 'Attach the committed file.'));
                end;
            'Storage.Upload.Abort':
                Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Begin', 'Start a fresh upload.'));
            'Storage.Upload.Status':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', 'Send another chunk.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Commit when complete.'));
                end;
            'Storage.Upload.CommitToRecord':
                Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move the created attachment to storage later.'));
            'DataExchange.Definition.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read one definition in full.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Type.List', 'See which type uses a definition.'));
                end;
            'DataExchange.Definition.Get':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'Find another definition code.'));
            'DataExchange.Type.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'List available definitions.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read the referenced definition.'));
                end;
            'DataExchange.Entry.List':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Get', 'Read one entry and its fields.'));
            'DataExchange.Entry.Get':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', 'Find another entry.'));
        end;
    end;
}