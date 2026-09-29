namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Shared help document builder for the file message types of the Bifrost Attachments storage connector.
/// One codeunit per message-type domain: every <c>*Impl</c> codeunit of the domain routes its
/// <c>GetMessageHelpAsMarkdownDocument</c> call here, so the Markdown contract for the whole
/// domain lives in one place.
/// </summary>
codeunit 10035671 "Storage File Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for one message type of this domain.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"Storage.File.List":
                FileListHelp(Argument);
            MessageType::"Storage.File.Get":
                FileGetHelp(Argument);
            MessageType::"Storage.File.Create":
                FileCreateHelp(Argument);
            MessageType::"Storage.File.Delete":
                FileDeleteHelp(Argument);
            MessageType::"Storage.File.Copy":
                FileCopyHelp(Argument);
            MessageType::"Storage.File.Move":
                FileMoveHelp(Argument);
            MessageType::"Storage.File.Exists":
                FileExistsHelp(Argument);
        end;
    end;

    local procedure FileListHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.File.List', 'Lists the files in a directory of the configured storage connection.', 'ListFiles');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', false, 'string', 'The directory whose files are listed (relative to the connection base path). Omit or pass an empty string to list the root of the connection.');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "invoices/2026" }');
        HelpBuilder.SetResponseNote('`path` and an `entries` array of `{ name, type, parentDirectory }` (type is always `File`)');
        HelpBuilder.AddError("Bifrost Error Code ori"::BusinessCentralError, 'The directory does not exist (connector error)', 'Verify the directory exists with Storage.Directory.Exists.');
        HelpBuilder.AddRelated('Storage.Directory.List', 'List subdirectories');
        HelpBuilder.AddRelated('Storage.File.Get', 'Download a file');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure FileGetHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.File.Get', 'Downloads a file from the configured storage connection and returns its content as base64.', 'GetFile');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'The file path to download (relative to the connection base path).');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "invoices/2026/INV-001.pdf" }');
        HelpBuilder.SetResponseNote('`path`, `contentLength` (bytes) and `contentBase64` (the file content)');
        HelpBuilder.AddError("Bifrost Error Code ori"::BusinessCentralError, 'The file does not exist (connector error)', 'Verify the file exists with Storage.File.Exists or list the directory with Storage.File.List.');
        HelpBuilder.SetNotes('The content is base64-encoded. Decode `contentBase64` to recover the original bytes.');
        HelpBuilder.AddRelated('Storage.File.Create', 'Upload a file');
        HelpBuilder.AddRelated('Storage.File.Exists', 'Check existence');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure FileCreateHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.File.Create', 'Uploads a base64 file of up to 240 MiB to a path in one call. For larger files, use Storage.Upload.Begin, Append and Commit.', 'CreateFile');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'The destination file path (relative to the connection base path).');
        HelpBuilder.AddParam('contentBase64', true, 'base64 string', 'The complete file content, base64-encoded; at most 251,658,240 bytes (240 MiB) before encoding. Use Storage.Upload.Begin for a larger file.');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "notes/hello.txt", "contentBase64": "SGVsbG8gd29ybGQ=" }');
        HelpBuilder.SetResponseNote('`path` and `contentLength` (the number of bytes stored)');
        HelpBuilder.AddError("Bifrost Error Code ori"::InvalidParameterFormat, 'Invalid base64 content', 'Ensure contentBase64 is valid base64 with no surrounding whitespace or data-URI prefix.');
        HelpBuilder.AddError("Bifrost Error Code ori"::BusinessCentralError, 'The directory does not exist (connector error)', 'Create the parent directory first with Storage.Directory.Create where the connector requires it.');
        HelpBuilder.SetSideEffects('Writes (and may overwrite) a file in external storage even though Direction is Outbound. Treat as a write when asking for confirmation.');
        HelpBuilder.SetNotes('One call carries a file of up to 240 MiB (the base64 text then stays under the 350 MB request limit of Business Central online). For a larger file use `Storage.Upload.Begin`, append chunks of up to 240 MiB each, then call `Storage.Upload.Commit`; every call is one billable message, so send as few as the file allows. Content over the limit is refused with `LimitExceeded`. Creating a file at an existing path overwrites it on connectors that support overwrite (for example Azure Blob).');
        HelpBuilder.AddRelated('Storage.Upload.Begin', 'Upload a larger file in parts');
        HelpBuilder.AddRelated('Storage.File.Get', 'Download the file');
        HelpBuilder.AddRelated('Storage.File.Delete', 'Delete the file');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure FileDeleteHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.File.Delete', 'Deletes a file from the configured storage connection.', 'DeleteFile');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'The file path to delete (relative to the connection base path).');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "notes/hello.txt" }');
        HelpBuilder.SetResponseNote('the deleted `path`');
        HelpBuilder.AddError("Bifrost Error Code ori"::BusinessCentralError, 'File not found', 'Verify the file exists with Storage.File.Exists.');
        HelpBuilder.AddError("Bifrost Error Code ori"::PreconditionFailed, 'File is linked to a Business Central attachment and cannot be deleted directly from storage', 'Restore the attachment (`Storage.Attachment.Restore`) or delete the BC attachment first, then delete the file.');
        HelpBuilder.AddError("Bifrost Error Code ori"::BusinessCentralError, 'The file does not exist (connector error)', 'Verify the file exists with Storage.File.Exists.');
        HelpBuilder.SetSideEffects('Deletes a file from external storage even though Direction is Outbound. Treat as a write when asking for confirmation.');
        HelpBuilder.AddRelated('Storage.File.Exists', 'Check existence first');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure FileCopyHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.File.Copy', 'Copies a file within the configured storage connection.', 'CopyFile');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('sourcePath', true, 'string', 'The file to copy (relative to the connection base path).');
        HelpBuilder.AddParam('targetPath', true, 'string', 'The destination path for the copy.');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "sourcePath": "in/a.txt", "targetPath": "out/a.txt" }');
        HelpBuilder.SetResponseNote('the `sourcePath` and `targetPath`');
        HelpBuilder.AddError("Bifrost Error Code ori"::BusinessCentralError, 'The source file does not exist (connector error)', 'Verify the source file exists with Storage.File.Exists.');
        HelpBuilder.SetSideEffects('Creates a copy in external storage even though Direction is Outbound. Treat as a write when asking for confirmation.');
        HelpBuilder.AddRelated('Storage.File.Move', 'Move instead of copy');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure FileMoveHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.File.Move', 'Moves a file within the configured storage connection.', 'MoveFile');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('sourcePath', true, 'string', 'The file to move (relative to the connection base path).');
        HelpBuilder.AddParam('targetPath', true, 'string', 'The destination path for the moved file.');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "sourcePath": "in/a.txt", "targetPath": "done/a.txt" }');
        HelpBuilder.SetResponseNote('the `sourcePath` and `targetPath`');
        HelpBuilder.AddError("Bifrost Error Code ori"::BusinessCentralError, 'The source file does not exist (connector error)', 'Verify the source file exists with Storage.File.Exists.');
        HelpBuilder.SetSideEffects('Moves (renames) a file in external storage even though Direction is Outbound. Treat as a write when asking for confirmation.');
        HelpBuilder.AddRelated('Storage.File.Copy', 'Copy instead of move');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure FileExistsHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.File.Exists', 'Reports whether a file exists in the configured storage connection.', 'FileExists');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'The file path to check (relative to the connection base path).');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "notes/hello.txt" }');
        HelpBuilder.SetResponseNote('`path` and `exists` (boolean)');
        HelpBuilder.AddRelated('Storage.File.List', 'List the directory');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;
}
