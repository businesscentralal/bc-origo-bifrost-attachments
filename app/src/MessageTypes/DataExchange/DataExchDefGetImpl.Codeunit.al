namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Definition.Get</c>. Returns one definition in full.
/// </summary>
codeunit 70013523 "DataExch Def Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks whether the caller can read the underlying Data Exchange table.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        exit(DataExchDef.ReadPermission());
    end;

    /// <summary>Provides the FilterTableNo discovery or contract chapter.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Provides the Description discovery or contract chapter.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Returns one Data Exchange definition, including line definitions, columns and field mappings.', Comment = 'is-IS=Skilar einni skilgreiningu gagnaskipta, þar með talið línuskilgreiningum, dálkum og reitavörpun.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides the Keywords discovery or contract chapter.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'get data exchange definition, read mappings, definition columns', Comment = 'is-IS=sækja skilgreiningu gagnaskipta, lesa vörpun, dálkar skilgreiningar';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides the SelectionDescription discovery or contract chapter.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns one Data Exchange definition with line definitions, columns and mappings; pass a code from the list type.', Comment = 'is-IS=Skilar einni skilgreiningu gagnaskipta með línuskilgreiningum, dálkum og vörpun; gefðu upp kóða úr listaboðgerðinni.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Provides the Envelope discovery or contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    /// <summary>Provides the Target discovery or contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the Parameters discovery or contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Definition.Get');
        exit(true);
    end;

    /// <summary>Provides the Response discovery or contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Definition.Get');
        exit(true);
    end;

    /// <summary>Provides the Errors discovery or contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Definition.Get');
        exit(true);
    end;

    /// <summary>Provides the Effect discovery or contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Definition.Get');
        exit(true);
    end;

    /// <summary>Provides the Metering discovery or contract chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the Related discovery or contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('DataExchange.Definition.Get');
        exit(true);
    end;

    /// <summary>Provides the Workflow discovery or contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the Examples discovery or contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the Overview discovery or contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        exit(false);
    end;

    /// <summary>Provides the Notes discovery or contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    /// <summary>Provides the MessageDirection discovery or contract chapter.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Executes the registered read operation through Foundation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Query: Codeunit "Data Exchange Query ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Query.GetDefinition(Argument);
    end;
}
