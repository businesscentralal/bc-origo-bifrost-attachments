namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>Binds an existing import definition to a Data Exchange Type.</summary>
codeunit 70013531 "DataExch Type Set Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        SetType(Rec);
    end;

    /// <summary>Reports whether the current user has the table permission required by this message.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExchangeType: Record "Data Exchange Type";
    begin
        exit(DataExchangeType.WritePermission());
    end;

    /// <summary>Returns the Microsoft table used to filter this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exchange Type");
    end;

    /// <summary>Describes the existing message operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates or updates a Data Exchange Type and requires an import definition.', Comment = 'is-IS=Stofnar eða uppfærir gerð gagnaskipta og krefst innflutningsskilgreiningar.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns the discovery terms for this message type.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'data exchange type, incoming document type, set definition', Comment = 'is-IS=gerð gagnaskipta, gerð innkomuskjals, stilla skilgreiningu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Wires a Data Exchange Type to an import definition.', Comment = 'is-IS=Tengir gerð gagnaskipta við innflutningsskilgreiningu.';
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
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Type.Set');
        exit(true);
    end;

    /// <summary>Declares the request parameters consumed by this message.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Type.Set');
        exit(true);
    end;

    /// <summary>Describes the existing response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Type.Set');
        exit(true);
    end;

    /// <summary>Describes the existing refusal conditions.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Type.Set');
        exit(true);
    end;

    /// <summary>Declares the effects of this operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Type.Set');
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
        Related.Add('Storage.Upload.CommitToRecord');
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
        Overview := 'Creates or updates a Data Exchange Type for incoming documents.';
        exit(true);
    end;

    /// <summary>Describes the limits of the currently implemented operation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The definition must be an import definition. Export definitions are rejected.';
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
        Codeunit.Run(Codeunit::"DataExch Type Set Impl ori", Argument);
    end;

    local procedure SetType(var Argument: Record "Message Argument ori")
    var
        DataExchangeType: Record "Data Exchange Type";
        DataExchDef: Record "Data Exch. Def";
        Reader: Codeunit "Storage Request Reader ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DefinitionCode: Code[20];
        TypeCode: Code[20];
        Description: Text;
        NotFoundErr: Label 'Data Exchange definition %1 was not found.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 fannst ekki.';
        InvalidKindErr: Label 'The definition kind is not accepted by this operation.', Comment = 'is-IS=Þessi aðgerð tekur ekki við tegund skilgreiningarinnar.';
        ExpectedLbl: Label 'an existing Generic Import definition', Comment = 'is-IS=fyrirliggjandi Generic Import-skilgreining';
        SelectDefinitionLbl: Label 'Call DataExchange.Definition.List and select a definition of an accepted kind using its exact code.', Comment = 'is-IS=Kallaðu á DataExchange.Definition.List og veldu skilgreiningu af leyfðri tegund með nákvæmum kóða hennar.';
    begin
        if Reader.ReadMutationRequest(Argument, RequestJson) then begin
            Reader.ReadMutationCode(Argument, RequestJson, 'code', TypeCode);
            Reader.ReadMutationCode(Argument, RequestJson, 'dataExchDefCode', DefinitionCode);
            Reader.ReadMutationText(Argument, RequestJson, 'description', false, MaxStrLen(DataExchangeType.Description), Description);
        end;
        if Reader.RespondIfErrors(Argument) then
            exit;
        DataExchDef.SetLoadFields(Type);
        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        if not DataExchDef.Get(DefinitionCode) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, DefinitionCode), 'dataExchDefCode', DefinitionCode, ExpectedLbl, SelectDefinitionLbl)
        else
            // Preserve the shipped predicate, including Payroll Import handling.
            if DataExchDef.Type <> DataExchDef.Type::"Generic Import" then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, InvalidKindErr, 'dataExchDefCode', DefinitionCode, ExpectedLbl, SelectDefinitionLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;
        DataExchangeType.ReadIsolation := IsolationLevel::UpdLock;
        if not DataExchangeType.Get(TypeCode) then begin
            DataExchangeType.Init();
            DataExchangeType.Code := TypeCode;
            DataExchangeType.Insert(true);
        end;
        DataExchangeType.Validate("Data Exch. Def. Code", DefinitionCode);
        if RequestJson.Contains('description') then
            DataExchangeType.Description := CopyStr(Description, 1, MaxStrLen(DataExchangeType.Description));
        DataExchangeType.Modify(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('code', DataExchangeType.Code);
        ResponseJson.Add('dataExchDefCode', DataExchangeType."Data Exch. Def. Code");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
