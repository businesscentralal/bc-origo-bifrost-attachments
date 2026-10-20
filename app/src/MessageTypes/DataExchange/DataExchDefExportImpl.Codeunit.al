namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>Returns the existing Data Exchange definition header.</summary>
codeunit 10035156 "DataExch Def Export Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the current user has the table permission required by this message.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        exit(DataExchDef.ReadPermission());
    end;

    /// <summary>Returns the Microsoft table used to filter this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch. Def");
    end;

    /// <summary>Describes the existing message operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Returns the header of a Data Exchange definition: code, name and type.', Comment = 'is-IS=Skilar haus skilgreiningar gagnaskipta: kóða, heiti og gerð.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns the discovery terms for this message type.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'export data exchange definition, dump definition', Comment = 'is-IS=flytja út skilgreiningu gagnaskipta, afrita skilgreiningu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns only the code, name and type of one definition; DataExchange.Definition.Get also returns its lines and mappings.', Comment = 'is-IS=Skilar aðeins kóða, heiti og gerð einnar skilgreiningar; DataExchange.Definition.Get skilar einnig línum hennar og vörpunum.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Declares the existing message name and supported version.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetDataExchangeEnvelope(true);
        Envelope.Add('messageType', 'DataExchange.Definition.Export');
        exit(true);
    end;

    /// <summary>Declares the Microsoft table targeted by this message.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Definition.Export');
        exit(true);
    end;

    /// <summary>Declares the request parameters consumed by this message.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Definition.Export');
        exit(true);
    end;

    /// <summary>Describes the existing response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Definition.Export');
        exit(true);
    end;

    /// <summary>Describes the existing refusal conditions.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Definition.Export');
        exit(true);
    end;

    /// <summary>Declares the effects of this operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Definition.Export');
        exit(true);
    end;

    /// <summary>Declares the metering information for this message.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related Data Exchange message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read the definition before exporting it.'));
        Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'Find a definition to export.'));
        exit(true);
    end;

    /// <summary>Describes the existing Data Exchange workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides example inputs for the existing operation.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Summarizes the existing operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the header of one Data Exchange definition: its code, name and type.';
        exit(true);
    end;

    /// <summary>Describes the limits of the currently implemented operation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Only the header is returned. Line, column and mapping definitions are not part of the answer; read them with DataExchange.Definition.Get.';
        exit(true);
    end;

    /// <summary>Returns the direction of this message.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Executes the existing Data Exchange operation and writes its response to the argument.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DataExchangeQuery: Codeunit "Data Exchange Query ori";
        Reader: Codeunit "Storage Request Reader ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        // The query codeunit holds an indirect read. Refuse from this codeunit so a missing user grant stays visible.
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch. Def", false) then
            exit;
        DataExchangeQuery.ExportDefinition(Argument);
    end;
}
