namespace Origo.Bifrost.Hnitbjorg;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Shared help document builder for the file message types of the Bifrost Hnitbjorg storage connector.
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
    internal procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
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
        HelpBuilder.AddError('Path not found', 'Verify the directory exists with Storage.Directory.Exists.');
        HelpBuilder.SetRelated('- **List subdirectories:** `Storage.Directory.List`' + '\' + '- **Download a file:** `Storage.File.Get`');
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
        HelpBuilder.AddError('File not found', 'Verify the file exists with Storage.File.Exists or list the directory with Storage.File.List.');
        HelpBuilder.SetNotes('The content is base64-encoded. Decode `contentBase64` to recover the original bytes.');
        HelpBuilder.SetRelated('- **Upload a file:** `Storage.File.Create`' + '\' + '- **Check existence:** `Storage.File.Exists`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure FileCreateHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.File.Create', 'Uploads one small base64 file to a path. For larger files, use Storage.Upload.Begin/Append/Commit.', 'CreateFile');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'The destination file path (relative to the connection base path).');
        HelpBuilder.AddParam('contentBase64', true, 'base64 string', 'The complete file content, base64-encoded. Keep single-call uploads small; use Storage.Upload.Begin for larger files.');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "notes/hello.txt", "contentBase64": "SGVsbG8gd29ybGQ=" }');
        HelpBuilder.SetResponseNote('`path` and `contentLength` (the number of bytes stored)');
        HelpBuilder.AddError('Invalid base64 content', 'Ensure contentBase64 is valid base64 with no surrounding whitespace or data-URI prefix.');
        HelpBuilder.AddError('Path not found', 'Create the parent directory first with Storage.Directory.Create where the connector requires it.');
        HelpBuilder.SetNotes('Use this message type for small files that fit comfortably in one Bifrost request. For predictable large-file uploads, use `Storage.Upload.Begin`, append chunks of at most 49152 RAW bytes each (about 64 KB base64), then call `Storage.Upload.Commit`. Creating a file at an existing path overwrites it on connectors that support overwrite (for example Azure Blob).');
        HelpBuilder.SetRelated('- **Upload a larger file in parts:** `Storage.Upload.Begin`' + '\' + '- **Download the file:** `Storage.File.Get`' + '\' + '- **Delete the file:** `Storage.File.Delete`');
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
        HelpBuilder.AddError('File not found', 'Verify the file exists with Storage.File.Exists.');
        HelpBuilder.SetRelated('- **Check existence first:** `Storage.File.Exists`');
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
        HelpBuilder.AddError('Source not found', 'Verify the source file exists with Storage.File.Exists.');
        HelpBuilder.SetRelated('- **Move instead of copy:** `Storage.File.Move`');
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
        HelpBuilder.AddError('Source not found', 'Verify the source file exists with Storage.File.Exists.');
        HelpBuilder.SetRelated('- **Copy instead of move:** `Storage.File.Copy`');
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
        HelpBuilder.SetRelated('- **List the directory:** `Storage.File.List`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;
}
