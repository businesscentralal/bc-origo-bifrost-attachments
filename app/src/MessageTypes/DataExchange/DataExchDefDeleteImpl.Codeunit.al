namespace Origo.Bifrost.Attachments;

using Microsoft.Bank.Setup;
using Origo.Bifrost;
using System.IO;

/// <summary>Refuses invalid or referenced definitions before deleting a Data Exchange definition.</summary>
codeunit 70013543 "DataExch Def Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        DeleteDefinition(Rec);
    end;

    /// <summary>Reports whether the caller can write the affected table.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        exit(DataExchDef.WritePermission());
    end;

    /// <summary>Returns the table associated with this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch. Def");
    end;

    /// <summary>Describes the current operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Deletes a Data Exchange definition that is not referenced.', Comment = 'is-IS=Eyðir skilgreiningu gagnaskipta sem ekki er vísað í.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete data exchange definition', Comment = 'is-IS=eyða skilgreiningu gagnaskipta';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Deletes a definition. Refuses a definition used by a Data Exchange Type or Bank Export/Import Setup.', Comment = 'is-IS=Eyðir skilgreiningu. Hafnar skilgreiningu sem er notuð af gerð gagnaskipta eða uppsetningu bankaútflutnings eða innflutnings.';
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
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Describes the accepted request keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Describes operation refusals.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Definition.Delete');
        exit(true);
    end;

    /// <summary>Describes the database effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Definition.Delete');
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
        Related.Add('DataExchange.Type.List');
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
        OverviewLbl: Label 'Deletes one Data Exchange definition after checking references.', Comment = 'is-IS=Eyðir einni skilgreiningu gagnaskipta eftir að tilvísanir hafa verið athugaðar.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains operation restrictions.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Does not delete a definition that a Data Exchange Type or Bank Export/Import Setup still uses.', Comment = 'is-IS=Eyðir ekki skilgreiningu sem tegund gagnaskipta eða uppsetning bankaútflutnings eða bankainnflutnings notar enn.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the key and references before deleting; execution errors propagate in the caller transaction.</summary>
    /// <param name="Argument">The licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        // No Boolean return: retain the caller transaction and the existing Foundation exception boundary.
        Codeunit.Run(Codeunit::"DataExch Def Delete Impl ori", Argument);
    end;

    local procedure DeleteDefinition(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        DataExchType: Record "Data Exchange Type";
        BankExportImportSetup: Record "Bank Export/Import Setup";
        Reader: Codeunit "Storage Request Reader ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DefCode: Code[20];
        NotFoundErr: Label 'Data Exchange definition %1 was not found.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 fannst ekki.';
        UsedErr: Label 'Data Exchange definition %1 is referenced and cannot be deleted.', Comment = '%1 = definition code||is-IS=Vísað er í skilgreiningu gagnaskipta %1 og ekki er hægt að eyða henni.';
        DefinitionExpectedLbl: Label 'an existing Data Exchange definition', Comment = 'is-IS=fyrirliggjandi skilgreining gagnaskipta';
        UnreferencedExpectedLbl: Label 'a definition not used by a Data Exchange Type or Bank Export/Import Setup', Comment = 'is-IS=skilgreining sem er ekki notuð í tegund gagnaskipta eða uppsetningu bankaútflutnings eða bankainnflutnings';
        SelectDefinitionLbl: Label 'Call DataExchange.Definition.List and use the exact definition code.', Comment = 'is-IS=Kallaðu á DataExchange.Definition.List og notaðu nákvæman kóða skilgreiningarinnar.';
        RemoveReferenceLbl: Label 'Review the Data Exchange Types and Bank Export/Import Setup that use this definition. Change those references before retrying deletion.', Comment = 'is-IS=Farðu yfir tegundir gagnaskipta og uppsetningu bankaútflutnings eða bankainnflutnings sem nota skilgreininguna. Breyttu þeim tilvísunum áður en þú reynir að eyða aftur.';
    begin
        if Reader.ReadMutationRequest(Argument, RequestJson) then
            Reader.ReadMutationCode(Argument, RequestJson, 'code', DefCode);
        if Reader.RespondIfErrors(Argument) then
            exit;
        DataExchDef.ReadIsolation := IsolationLevel::UpdLock;
        if not DataExchDef.Get(DefCode) then begin
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, DefCode), 'code', DefCode, DefinitionExpectedLbl, SelectDefinitionLbl);
            Reader.RespondIfErrors(Argument);
            exit;
        end;
        DataExchType.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchType.SetRange("Data Exch. Def. Code", DefCode);
        BankExportImportSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        BankExportImportSetup.SetRange("Data Exch. Def. Code", DefCode);
        if not DataExchType.IsEmpty() or not BankExportImportSetup.IsEmpty() then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(UsedErr, DefCode), 'code', DefCode, UnreferencedExpectedLbl, RemoveReferenceLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;
        DataExchDef.Delete(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('code', DefCode);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
