namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Help.Storage.Get</c> message type. Returns a Markdown overview
/// of the storage connector, release baseline, and every message type it exposes.
/// No request body is required.
/// </summary>
codeunit 10035655 "Storage Help Get Impl ori" implements "Msg Interface ori"
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
        exit('Returns a Markdown overview of the storage connector and all its message types. No request body is required.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        OverviewHelp: Codeunit "Storage Overview Help ori";
    begin
        OverviewHelp.GetHelp(Enum::"Message Type ori"::"Help.Storage.Get", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        OverviewHelp: Codeunit "Storage Overview Help ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        DataObject: JsonObject;
    begin
        Argument.AssertVersion1();
        DataObject.Add('format', 'markdown');
        DataObject.Add('markdown', OverviewHelp.BuildOverview());
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;
}
