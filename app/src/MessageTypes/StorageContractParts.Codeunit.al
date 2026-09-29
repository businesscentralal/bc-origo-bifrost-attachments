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
        if MessageType in ['Storage.Account.List', 'Help.Storage.Get'] then
            exit;

        Parameters.Add(ContractMgt.Parameter('storageCode', 'string', true, 'The configured storage connection code. Resolve it with Storage.Account.List.'));
        case MessageType of
            'Storage.File.List', 'Storage.Directory.List':
                Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The directory path relative to the connection base path.'));
            'Storage.File.Get', 'Storage.File.Delete', 'Storage.File.Exists', 'Storage.Directory.Create', 'Storage.Directory.Delete', 'Storage.Directory.Exists':
                Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The file or directory path relative to the connection base path.'));
            'Storage.File.Create': begin
                Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The destination file path relative to the connection base path.'));
                Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, 'The complete file content encoded as base64.'));
            end;
            'Storage.File.Copy', 'Storage.File.Move': begin
                Parameters.Add(ContractMgt.Parameter('sourcePath', 'string', true, 'The source file path relative to the connection base path.'));
                Parameters.Add(ContractMgt.Parameter('targetPath', 'string', true, 'The destination file path relative to the connection base path.'));
            end;
        end;
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
            'Storage.Account.List':
                Fields.Add(ContractMgt.ResponseField('accounts', 'array', 'Configured storage connections without secrets.'));
            'Storage.File.List', 'Storage.Directory.List': begin
                Fields.Add(ContractMgt.ResponseField('path', 'string', 'The requested directory path.'));
                Fields.Add(ContractMgt.ResponseField('entries', 'array', 'The files or directories found at the path.'));
            end;
            'Storage.File.Get': begin
                Fields.Add(ContractMgt.ResponseField('path', 'string', 'The downloaded file path.'));
                Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', 'The file content encoded as base64.'));
            end;
            'Storage.File.Exists', 'Storage.Directory.Exists': begin
                Fields.Add(ContractMgt.ResponseField('path', 'string', 'The checked path.'));
                Fields.Add(ContractMgt.ResponseField('exists', 'boolean', 'Whether the path exists.'));
            end;
            'Storage.File.Create', 'Storage.File.Delete', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create', 'Storage.Directory.Delete':
                Fields.Add(ContractMgt.ResponseField('path', 'string', 'The affected path.'));
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Builds the known errors returned by one message type.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Storage.File.Create'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'The contentBase64 value is not valid base64.', 'Send valid base64 content.'));
        if MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'A linked Business Central attachment prevents the delete.', 'Restore or remove the attachment first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The storage connector rejects or cannot complete the operation.', 'Check the path, connection and connector error details.'));
    end;

    /// <summary>Builds the operation effect for one message type.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    begin
        if MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete'] then
            Effect.Add('effect', 'irreversible')
        else if MessageType in ['Storage.File.Create', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create'] then
            Effect.Add('effect', 'write')
        else
            Effect.Add('effect', 'read');
        Effect.Add('changes', 'The operation changes only the external storage state described by the message.');
        Effect.Add('idempotent', MessageType in ['Storage.Account.List', 'Storage.File.List', 'Storage.File.Get', 'Storage.File.Exists', 'Storage.Directory.List', 'Storage.Directory.Exists']);
        Effect.Add('permissionSet', 'BIFROST Attach ori');
        Effect.Add('preconditions', 'The storage connection exists, is enabled and permits the requested operation.');
    end;

    /// <summary>Builds related message types for one message type.</summary>
    procedure GetRelated(MessageType: Text) Related: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Storage.Account.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files after choosing a storageCode.'));
            'Storage.File.List': begin
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', 'List subdirectories instead of files.'));
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Download one listed file.'));
            end;
            'Storage.File.Get': begin
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
        end;
    end;
}