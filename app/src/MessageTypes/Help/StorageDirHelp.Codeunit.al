namespace Origo.Bifrost.Hnitbjorg;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Shared help document builder for the directory message types of the Bifrost Hnitbjorg storage connector.
/// One codeunit per message-type domain: every <c>*Impl</c> codeunit of the domain routes its
/// <c>GetMessageHelpAsMarkdownDocument</c> call here, so the Markdown contract for the whole
/// domain lives in one place.
/// </summary>
codeunit 10035672 "Storage Dir Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for one message type of this domain.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    internal procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"Storage.Directory.List":
                DirListHelp(Argument);
            MessageType::"Storage.Directory.Create":
                DirCreateHelp(Argument);
            MessageType::"Storage.Directory.Delete":
                DirDeleteHelp(Argument);
            MessageType::"Storage.Directory.Exists":
                DirExistsHelp(Argument);
        end;
    end;

    local procedure DirListHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Directory.List', 'Lists the subdirectories of a directory in the configured storage connection.', 'ListDirectories');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', false, 'string', 'The directory whose subdirectories are listed (relative to the connection base path). Omit or pass an empty string to list the root of the connection.');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "invoices" }');
        HelpBuilder.SetResponseNote('`path` and an `entries` array of `{ name, type, parentDirectory }` (type is always `Directory`)');
        HelpBuilder.SetRelated('- **List files:** `Storage.File.List`' + '\' + '- **Create a directory:** `Storage.Directory.Create`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure DirCreateHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Directory.Create', 'Creates a directory in the configured storage connection.', 'CreateDirectory');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'The directory path to create (relative to the connection base path).');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "invoices/2026" }');
        HelpBuilder.SetResponseNote('the created `path`');
        HelpBuilder.SetNotes('Some connectors (for example Azure Blob) have no real directories; a directory may only become visible once it contains a file.');
        HelpBuilder.SetRelated('- **Delete a directory:** `Storage.Directory.Delete`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure DirDeleteHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Directory.Delete', 'Deletes a directory from the configured storage connection.', 'DeleteDirectory');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'The directory path to delete (relative to the connection base path).');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "invoices/2026" }');
        HelpBuilder.SetResponseNote('the deleted `path`');
        HelpBuilder.AddError('Directory not found', 'Verify the directory exists with Storage.Directory.Exists.');
        HelpBuilder.SetRelated('- **Check existence first:** `Storage.Directory.Exists`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure DirExistsHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Directory.Exists', 'Reports whether a directory exists in the configured storage connection.', 'DirectoryExists');
        HelpBuilder.AddParam('storageCode', true, 'string', 'The configured storage connection to use. Resolve via Storage.Account.List.');
        HelpBuilder.AddParam('path', true, 'string', 'The directory path to check (relative to the connection base path).');
        HelpBuilder.SetRequestExample('{ "storageCode": "ARCHIVE", "path": "invoices/2026" }');
        HelpBuilder.SetResponseNote('`path` and `exists` (boolean)');
        HelpBuilder.SetRelated('- **List subdirectories:** `Storage.Directory.List`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;
}
