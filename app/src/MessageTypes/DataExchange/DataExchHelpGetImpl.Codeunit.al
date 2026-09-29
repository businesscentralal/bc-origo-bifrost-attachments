namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Help.DataExchange.Get</c>. Returns the Data Exchange discovery overview.
/// No request body is required.
/// </summary>
codeunit 70013521 "DataExch Help Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'data exchange help, import discovery, data exchange overview', Comment = 'is-IS=gagnaskiptahjálp, uppgötvun innflutnings, yfirlit gagnaskipta';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns the Data Exchange discovery guide; use a specific Data Exchange type to inspect definitions or entries.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(false);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Help.DataExchange.Get');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Help.DataExchange.Get');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Help.DataExchange.Get');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the Data Exchange discovery overview.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
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
