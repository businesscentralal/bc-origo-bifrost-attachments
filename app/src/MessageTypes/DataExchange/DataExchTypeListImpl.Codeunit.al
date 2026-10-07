namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Type.List</c>. Lists Data Exchange Type rows.
/// </summary>
codeunit 70013524 "DataExch Type List Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks whether the caller can read the underlying Data Exchange table.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExchType: Record "Data Exchange Type";
    begin
        exit(DataExchType.ReadPermission());
    end;

    /// <summary>Provides the FilterTableNo discovery or contract chapter.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Provides the Description discovery or contract chapter.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Lists Data Exchange Types and the definition type each one resolves to.', Comment = 'is-IS=Listar gerðir gagnaskipta og gerð skilgreiningar sem hver þeirra vísar í.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides the Keywords discovery or contract chapter.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'list data exchange types, incoming document types, exchange type codes', Comment = 'is-IS=lista tegundir gagnaskipta, tegundir innkomandi skjala, tegundakóðar gagnaskipta';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides the SelectionDescription discovery or contract chapter.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Lists Data Exchange Types and their definition codes; use definition get to inspect the referenced format.', Comment = 'is-IS=Listar gerðir gagnaskipta og skilgreiningarkóða þeirra; notaðu skilgreiningarsækiboðgerðina til að skoða sniðið sem vísað er í.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Provides the Envelope discovery or contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(false);
        exit(true);
    end;

    /// <summary>Provides the Target discovery or contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the Parameters discovery or contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the Response discovery or contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Type.List');
        exit(true);
    end;

    /// <summary>Provides the Errors discovery or contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Type.List');
        exit(true);
    end;

    /// <summary>Provides the Effect discovery or contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Type.List');
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
        Related := ContractParts.GetRelated('DataExchange.Type.List');
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
        Query.ListTypes(Argument);
    end;
}
