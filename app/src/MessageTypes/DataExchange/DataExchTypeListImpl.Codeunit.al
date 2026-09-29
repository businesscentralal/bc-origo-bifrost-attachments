namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Type.List</c>. Lists Data Exchange Type rows.
/// </summary>
codeunit 70013524 "DataExch Type List Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DataExchType: Record "Data Exchange Type";
    begin
        exit(DataExchType.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Lists Data Exchange Types and the definition type each one resolves to.');
    end;

    procedure GetKeywords(): Text
    var KeywordsLbl: Label 'list data exchange types, incoming document types, exchange type codes', Comment = 'is-IS=lista tegundir gagnaskipta, tegundir innkomandi skjala, tegundakóðar gagnaskipta';
    begin exit(KeywordsLbl); end;
    procedure GetSelectionDescription(): Text
    var SelectionDescriptionLbl: Label 'Lists Data Exchange Types and their definition codes; use definition get to inspect the referenced format.', Locked = true;
    begin exit(SelectionDescriptionLbl); end;
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Envelope := ContractParts.GetEnvelope(false); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean begin exit(false); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean begin exit(false); end;
    procedure GetResponse(var Response: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Response := ContractParts.GetResponse('DataExchange.Type.List'); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Errors := ContractParts.GetErrors('DataExchange.Type.List'); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Effect := ContractParts.GetEffect('DataExchange.Type.List'); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Related := ContractParts.GetRelated('DataExchange.Type.List'); exit(true); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean begin exit(false); end;
    procedure GetNotes(var Notes: Text): Boolean begin exit(false); end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        TypeHelp: Codeunit "DataExch Type Help ori";
    begin
        TypeHelp.GetHelp(Enum::"Message Type ori"::"DataExchange.Type.List", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Query: Codeunit "Data Exchange Query ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Query.ListTypes(Argument);
    end;
}
