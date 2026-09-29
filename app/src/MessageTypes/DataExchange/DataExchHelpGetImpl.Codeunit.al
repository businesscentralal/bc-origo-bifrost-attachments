namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Help.DataExchange.Get</c>. Returns the Data Exchange discovery overview.
/// No request body is required.
/// </summary>
codeunit 70013521 "DataExch Help Get Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns a Markdown overview of Data Exchange discovery: pipeline, phases, decision tree and chaining.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        OverviewHelp: Codeunit "DataExch Overview Help ori";
    begin
        OverviewHelp.GetHelp(Enum::"Message Type ori"::"Help.DataExchange.Get", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        OverviewHelp: Codeunit "DataExch Overview Help ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        DataObject: JsonObject;
    begin
        Argument.AssertVersion1();
        DataObject.Add('format', 'markdown');
        DataObject.Add('markdown', OverviewHelp.BuildOverview());
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;
}
