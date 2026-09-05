namespace Origo.Bifrost.Hnitbjorg;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Shared help document builder for the storage account discovery message type of the Bifrost Hnitbjorg storage connector.
/// One codeunit per message-type domain: every <c>*Impl</c> codeunit of the domain routes its
/// <c>GetMessageHelpAsMarkdownDocument</c> call here, so the Markdown contract for the whole
/// domain lives in one place.
/// </summary>
codeunit 10035670 "Storage Account Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for one message type of this domain.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    internal procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"Storage.Account.List":
                AccountListHelp(Argument);
        end;
    end;

    local procedure AccountListHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('Storage.Account.List', 'Lists the configured storage connections (codes, descriptions, connectors and enabled state). No secrets are exposed.', '');
        HelpBuilder.SetRouting('No routing parameters. Lists every configured connection so you can pick a `storageCode` for the other types. This is the discovery entry point — call it first.');
        HelpBuilder.SetRequestExample('{ }');
        HelpBuilder.AddResponseField('accounts', 'array', 'One object per connection: `{ code, description, connector, basePath, enabled }`. No secrets are returned.');
        HelpBuilder.SetNotes('Use a returned `code` as the `storageCode` on every other storage message type. Disabled connections are listed but rejected at call time, so prefer ones with `enabled = true`.');
        HelpBuilder.AddNextStep('Once you have a storageCode', 'Storage.File.Create', 'pass the `code` as `storageCode` (or use any other Storage.* type)');
        HelpBuilder.AddNextStep('To upload a large file', 'Storage.Upload.Begin', 'pass the `code` as `storageCode`');
        HelpBuilder.SetRelated('- **Connector overview:** `Help.Storage.Get`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;
}
