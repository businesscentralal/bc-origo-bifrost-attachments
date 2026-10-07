namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Entry.List</c>. Lists processed Data Exch. entries.
/// </summary>
codeunit 70013525 "DataExch Entry List Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks whether the caller can read the underlying Data Exchange table.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.ReadPermission());
    end;

    /// <summary>Provides the FilterTableNo discovery or contract chapter.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Provides the Description discovery or contract chapter.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Lists processed Data Exch. entries. Optional filters: dataExchDefCode, dateFrom, dateTo, skip, take.', Comment = 'is-IS=Listar afgreiddar gagnaskiptafærslur. Valkvæðar síur: dataExchDefCode, dateFrom, dateTo, skip, take.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides the Keywords discovery or contract chapter.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'list data exchange entries, processed imports, imported files', Comment = 'is-IS=lista færslur gagnaskipta, unnar innflutningar, innfluttar skrár';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides the SelectionDescription discovery or contract chapter.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Lists processed Data Exchange entries with filters and paging; use entry get to read fields.', Comment = 'is-IS=Listar afgreiddar gagnaskiptafærslur með síum og síðuskiptingu; notaðu færslusækiboðgerðina til að lesa reiti.';
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
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Entry.List');
        exit(true);
    end;

    /// <summary>Provides the Response discovery or contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Entry.List');
        exit(true);
    end;

    /// <summary>Provides the Errors discovery or contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Entry.List');
        exit(true);
    end;

    /// <summary>Provides the Effect discovery or contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Entry.List');
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
        Related := ContractParts.GetRelated('DataExchange.Entry.List');
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
        Query.ListEntries(Argument);
    end;
}
