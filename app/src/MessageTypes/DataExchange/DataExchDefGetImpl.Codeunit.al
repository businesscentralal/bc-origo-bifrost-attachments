namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Definition.Get</c>. Returns one definition in full.
/// </summary>
codeunit 70013523 "DataExch Def Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        exit(DataExchDef.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns one Data Exchange definition, including line definitions, columns and field mappings.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'get data exchange definition, read mappings, definition columns', Comment = 'is-IS=sækja skilgreiningu gagnaskipta, lesa vörpun, dálkar skilgreiningar';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns one Data Exchange definition with line definitions, columns and mappings; pass a code from the list type.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Definition.Get');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Definition.Get');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Definition.Get');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Definition.Get');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('DataExchange.Definition.Get');
        exit(true);
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
        Clear(Overview);
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Query: Codeunit "Data Exchange Query ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Query.GetDefinition(Argument);
    end;
}
