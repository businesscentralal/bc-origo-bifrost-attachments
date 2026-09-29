namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Help document for <c>DataExchange.Type.List</c>.
/// </summary>
codeunit 70013528 "DataExch Type Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for the type list.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"DataExchange.Type.List":
                ListHelp(Argument);
        end;
    end;

    local procedure ListHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('DataExchange.Type.List', 'Lists Data Exchange Type rows. A company with none returns count 0 and an empty array.', '');
        HelpBuilder.SetRouting('No request parameters.');
        HelpBuilder.SetClosing('Data Exchange overview: request help for `Help.DataExchange.Get`.');
        HelpBuilder.SetRequestExample('{ }');
        HelpBuilder.AddResponseField('count', 'integer', 'Number of Data Exchange Type rows. Zero when the company has none.');
        HelpBuilder.AddResponseField('types', 'array', '`code`, `description`, `dataExchDefCode`, `userFeedbackCodeunit`, `validationCodeunit`, `dataHandlingCodeunit`, and `type`. The three codeunit names and `type` are read from the linked Data Exch. Def.');
        HelpBuilder.AddNextStep('To read the definition a type points at', 'DataExchange.Definition.Get', 'pass `dataExchDefCode` as `code`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;
}
