namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using System.IO;

/// <summary>Refuses invalid or referenced Data Exchange Types before deleting one Data Exchange Type.</summary>
codeunit 10035200 "DataExch Type Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        DeleteType(Rec);
    end;

    /// <summary>Reports whether the caller can write the affected table.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExchangeType: Record "Data Exchange Type";
    begin
        exit(DataExchangeType.WritePermission());
    end;

    /// <summary>Returns the table associated with this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exchange Type");
    end;

    /// <summary>Describes the current operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Deletes a Data Exchange Type that no incoming document uses.', Comment = 'is-IS=Eyðir gerð gagnaskipta sem engin innkomin skjöl nota.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete data exchange type', Comment = 'is-IS=eyða gerð gagnaskipta';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Deletes one Data Exchange Type after a counted confirmation. Refuses a type that an incoming document uses. Never deletes the linked definition.', Comment = 'is-IS=Eyðir einni gerð gagnaskipta eftir talda staðfestingu. Hafnar gerð sem innkomið skjal notar. Eyðir aldrei tengdu skilgreiningunni.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the supported wire envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetDataExchangeEnvelope(true);
        Envelope.Add('messageType', 'DataExchange.Type.Delete');
        exit(true);
    end;

    /// <summary>Reports that this operation has no envelope target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Type.Delete');
        exit(true);
    end;

    /// <summary>Describes the accepted request keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Type.Delete');
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Type.Delete');
        exit(true);
    end;

    /// <summary>Describes operation refusals.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Type.Delete');
        exit(true);
    end;

    /// <summary>Describes the database effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Type.Delete');
        exit(true);
    end;

    /// <summary>Reports that this operation adds no custom metering chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('DataExchange.Type.List', 'Read the type before deleting it.'));
        Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Delete', 'Delete the definition once no type uses it.'));
        exit(true);
    end;

    /// <summary>Reports that no custom workflow chapter is supplied.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetWorkflow('DataExchange.Type.Delete', Workflow));
    end;

    /// <summary>Reports that no example chapter is supplied.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        Examples := ContractParts.GetExamples('DataExchange.Type.Delete');
        Guide.PrependSuccessExample('DataExchange.Type.Delete', Examples);
        exit(Examples.Count() > 0);
    end;

    /// <summary>Summarizes the operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Deletes one Data Exchange Type after a counted confirmation and a reference check. The linked definition is kept.', Comment = 'is-IS=Eyðir einni gerð gagnaskipta eftir talda staðfestingu og athugun á tilvísunum. Tengda skilgreiningin er áfram.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains operation restrictions.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Irreversible: send expectedCount 1 (the preview names the type). Does not delete a type that an incoming document still uses; clear or change that reference first. Never deletes the linked Data Exchange definition; use DataExchange.Definition.Delete afterwards.', Comment = 'is-IS=Óafturkræft: sendu expectedCount 1 (forskoðunin nefnir gerðina). Eyðir ekki gerð sem innkomið skjal notar enn; hreinsaðu eða breyttu þeirri tilvísun fyrst. Eyðir aldrei tengdu skilgreiningunni; notaðu DataExchange.Definition.Delete á eftir.';
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
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        // A non-object request is refused here, before the worker reads it with GetRequestJson.
        if not Reader.ReadMutationRequest(Argument) then begin
            Reader.RespondIfErrors(Argument);
            exit;
        end;
        // No Boolean return: retain the caller transaction and the existing Foundation exception boundary.
        Codeunit.Run(Codeunit::"DataExch Type Delete Impl ori", Argument);
    end;

    local procedure DeleteType(var Argument: Record "Message Argument ori")
    var
        DataExchangeType: Record "Data Exchange Type";
        IncomingDocument: Record "Incoming Document";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        TypeCode: Code[20];
        NotFoundErr: Label 'Data Exchange Type %1 was not found.', Comment = '%1 = type code||is-IS=Gerð gagnaskipta %1 fannst ekki.';
        TypeExpectedLbl: Label 'an existing Data Exchange Type', Comment = 'is-IS=fyrirliggjandi gerð gagnaskipta';
        SelectTypeLbl: Label 'Call DataExchange.Type.List and use the exact type code.', Comment = 'is-IS=Kallaðu á DataExchange.Type.List og notaðu nákvæman kóða gerðarinnar.';
        UsedErr: Label 'Data Exchange Type %1 is used by %2 incoming document(s) and cannot be deleted.', Comment = '%1 = type code, %2 = number of incoming documents||is-IS=Gerð gagnaskipta %1 er notuð af %2 innkomnum skjölum og ekki er hægt að eyða henni.';
        UnusedExpectedLbl: Label 'a Data Exchange Type that no incoming document uses', Comment = 'is-IS=gerð gagnaskipta sem ekkert innkomið skjal notar';
        ClearReferenceLbl: Label 'Change the Data Exchange Type on the incoming documents that use it, or delete those documents, then retry. The linked definition is not touched.', Comment = 'is-IS=Breyttu gerð gagnaskipta á innkomnu skjölunum sem nota hana, eða eyddu þeim skjölum, og reyndu aftur. Tengda skilgreiningin er ekki snert.';
    begin
        RequestJson := Argument.GetRequestJson();
        Reader.ReadMutationCode(Argument, RequestJson, 'code', TypeCode);
        if Reader.RespondIfErrors(Argument) then
            exit;
        // Refuse missing caller grants before reference reads or the delete trigger can raise a platform error.
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exchange Type", false) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exchange Type", true) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Incoming Document", false) then
            exit;
        DataExchangeType.ReadIsolation := IsolationLevel::UpdLock;
        if not DataExchangeType.Get(TypeCode) then begin
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, TypeCode), 'code', TypeCode, TypeExpectedLbl, SelectTypeLbl);
            Reader.RespondIfErrors(Argument);
            exit;
        end;
        IncomingDocument.ReadIsolation := IsolationLevel::ReadCommitted;
        IncomingDocument.SetRange("Data Exchange Type", TypeCode);
        if not IncomingDocument.IsEmpty() then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(UsedErr, TypeCode, IncomingDocument.Count()), 'code', TypeCode, UnusedExpectedLbl, ClearReferenceLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;
        // Only the type row goes; its Data Exch. Def stays and keeps its own Definition.Delete rules.
        DataExchangeType.Delete(true);
        ResponseJson.Add('code', TypeCode);
        RequestMgt.RespondSuccess(Argument, ResponseJson);
    end;
}
