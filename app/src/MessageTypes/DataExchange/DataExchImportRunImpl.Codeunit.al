namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>Validates a shipped import request and creates its Data Exchange header.</summary>
codeunit 70013540 "DataExch Import Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ImportHeader(Rec);
    end;

    /// <summary>Reports whether the caller can write the affected table.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.WritePermission());
    end;

    /// <summary>Returns the table associated with this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch.");
    end;

    /// <summary>Describes the current operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates a Data Exch. entry from a stored file for a generic or payroll import.', Comment = 'is-IS=Býr til gagnaskiptafærslu úr geymdri skrá fyrir almennan innflutning eða launainnflutning.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'data exchange import, process import file', Comment = 'is-IS=innflutningur gagnaskipta, vinna innflutningsskrá';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Runs a Generic Import or Payroll Import definition. Refuses Bank Statement Import and export definitions.', Comment = 'is-IS=Keyrir skilgreiningu fyrir Generic Import eða Payroll Import. Hafnar Bank Statement Import og útflutningsskilgreiningum.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the supported wire envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    /// <summary>Reports that this operation has no envelope target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Describes the accepted request keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Describes operation refusals.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Describes the database effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Reports that this operation adds no custom metering chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('DataExchange.Definition.Get');
        Related.Add('DataExchange.Entry.Get');
        exit(true);
    end;

    /// <summary>Reports that no custom workflow chapter is supplied.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Reports that no example chapter is supplied.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Summarizes the operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Creates a Data Exch. header for an import definition without executing a storage provider.', Comment = 'is-IS=Býr til gagnaskiptahaus fyrir innflutningsskilgreiningu án þess að keyra geymsluveitu.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains operation restrictions.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Bank Statement Import stays on the bank statement types. Export definitions are refused.', Comment = 'is-IS=Innflutningur bankayfirlita notar áfram bankayfirlitsaðferðirnar. Útflutningsskilgreiningum er hafnað.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates all input before creating a header; execution errors propagate in the caller transaction.</summary>
    /// <param name="Argument">The licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        // No Boolean return: do not introduce an implicit commit or catch postwrite errors.
        Codeunit.Run(Codeunit::"DataExch Import Run Impl ori", Argument);
    end;

    local procedure ImportHeader(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        DataExch: Record "Data Exch.";
        Reader: Codeunit "Storage Request Reader ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DefCode: Code[20];
        StorageCode: Code[20];
        Path: Text;
        NotFoundErr: Label 'Data Exchange definition %1 was not found.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 fannst ekki.';
        TypeErr: Label 'DataExchange.Import.Run accepts Generic Import and Payroll Import only.', Comment = 'is-IS=DataExchange.Import.Run tekur aðeins við Generic Import og Payroll Import.';
        DefinitionExpectedLbl: Label 'an existing Generic Import or Payroll Import definition', Comment = 'is-IS=fyrirliggjandi skilgreining fyrir Generic Import eða Payroll Import';
        SelectDefinitionLbl: Label 'Call DataExchange.Definition.List and use the exact code of a Generic Import or Payroll Import definition.', Comment = 'is-IS=Kallaðu á DataExchange.Definition.List og notaðu nákvæman kóða skilgreiningar fyrir Generic Import eða Payroll Import.';
    begin
        if Reader.ReadMutationRequest(Argument, RequestJson) then begin
            Reader.ReadMutationCode(Argument, RequestJson, 'dataExchDefCode', DefCode);
            Reader.ReadMutationCode(Argument, RequestJson, 'storageCode', StorageCode);
            if Reader.ReadMutationText(Argument, RequestJson, 'path', true, 2048, Path) then
                Reader.CheckPath(Argument, 'path', Path);
        end;
        if Reader.RespondIfErrors(Argument) then
            exit;
        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        if not DataExchDef.Get(DefCode) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, DefCode), 'dataExchDefCode', DefCode, DefinitionExpectedLbl, SelectDefinitionLbl)
        else
            if not (DataExchDef.Type in [DataExchDef.Type::"Generic Import", DataExchDef.Type::"Payroll Import"]) then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, TypeErr, 'dataExchDefCode', DefCode, DefinitionExpectedLbl, SelectDefinitionLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;
        // This shipped operation creates a header only. It does not resolve storage or execute a provider/import pipeline.
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DefCode;
        DataExch.Insert(true);
        ResponseJson.Add('status', 'Accepted');
        ResponseJson.Add('entryNo', DataExch."Entry No.");
        ResponseJson.Add('dataExchDefCode', DefCode);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
