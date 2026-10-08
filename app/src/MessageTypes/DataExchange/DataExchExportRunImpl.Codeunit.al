namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>Creates the existing Data Exchange export entry and returns its header.</summary>
codeunit 70013534 "DataExch Export Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExportHeader(Rec);
    end;

    /// <summary>Reports whether the current user has the table permission required by this message.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.WritePermission());
    end;

    /// <summary>Returns the Microsoft table used to filter this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch.");
    end;

    /// <summary>Describes the existing message operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Exports through a Data Exchange definition to a named file.', Comment = 'is-IS=Flytur út með skilgreiningu gagnaskipta í nafngreinda skrá.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns the discovery terms for this message type.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'data exchange export, payment export, export file', Comment = 'is-IS=útflutningur gagnaskipta, útflutningur greiðslna, flytja út skrá';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Runs an export definition and returns the file name.', Comment = 'is-IS=Keyrir útflutningsskilgreiningu og skilar skráarheitinu.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Declares the existing message name and supported version.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    /// <summary>Declares the Microsoft table targeted by this message.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Declares the request parameters consumed by this message.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Describes the existing response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Describes the existing refusal conditions.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Declares the effects of this operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Export.Run');
        exit(true);
    end;

    /// <summary>Declares the metering information for this message.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related Data Exchange message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('DataExchange.Definition.Get');
        Related.Add('Storage.File.Write');
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
        Overview := 'Creates a Data Exch. entry for an export definition and returns the target file name.';
        exit(true);
    end;

    /// <summary>Describes the limits of the currently implemented operation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Payment export uses the same type when the definition type is Payment Export. The compiler pass must bind the export stream to storage.';
        exit(true);
    end;

    /// <summary>Returns the direction of this message.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates raw inputs before any write, preserving the caller transaction on execution failure.</summary>
    /// <param name="Argument">The licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        // No Boolean return: preserve the caller transaction and propagate postwrite errors.
        Codeunit.Run(Codeunit::"DataExch Export Run Impl ori", Argument);
    end;

    local procedure ExportHeader(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        DataExchDef: Record "Data Exch. Def";
        Reader: Codeunit "Storage Request Reader ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DefinitionCode: Code[20];
        FileName: Text;
        NotFoundErr: Label 'Data Exchange definition %1 was not found.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 fannst ekki.';
        InvalidKindErr: Label 'The definition kind is not accepted by this operation.', Comment = 'is-IS=Þessi aðgerð tekur ekki við tegund skilgreiningarinnar.';
        ExpectedLbl: Label 'an existing definition other than Generic Import', Comment = 'is-IS=fyrirliggjandi skilgreining af annarri tegund en Generic Import';
        SelectDefinitionLbl: Label 'Call DataExchange.Definition.List and select a definition of an accepted kind using its exact code.', Comment = 'is-IS=Kallaðu á DataExchange.Definition.List og veldu skilgreiningu af leyfðri tegund með nákvæmum kóða hennar.';
    begin
        if Reader.ReadMutationRequest(Argument, RequestJson) then begin
            Reader.ReadMutationCode(Argument, RequestJson, 'dataExchDefCode', DefinitionCode);
            Reader.ReadMutationText(Argument, RequestJson, 'fileName', true, MaxStrLen(DataExch."File Name"), FileName);
        end;
        if Reader.RespondIfErrors(Argument) then
            exit;
        DataExchDef.SetLoadFields(Type);
        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        if not DataExchDef.Get(DefinitionCode) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, DefinitionCode), 'dataExchDefCode', DefinitionCode, ExpectedLbl, SelectDefinitionLbl)
        else
            // Preserve the shipped predicate, including Payroll Import handling.
            if DataExchDef.Type = DataExchDef.Type::"Generic Import" then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, InvalidKindErr, 'dataExchDefCode', DefinitionCode, ExpectedLbl, SelectDefinitionLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DefinitionCode;
        DataExch."File Name" := CopyStr(FileName, 1, MaxStrLen(DataExch."File Name"));
        DataExch.Insert(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', DataExch."Entry No.");
        ResponseJson.Add('fileName', FileName);
        ResponseJson.Add('dataExchDefCode', DefinitionCode);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
