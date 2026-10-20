namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Entry.Delete</c>. Deletes a Data Exch. entry and its parsed fields
/// unless an incoming document uses it.
/// </summary>
codeunit 10035160 "DataExch Entry Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        DeleteEntry(Rec);
    end;

    /// <summary>Reports whether the caller holds the table permission this message type needs.</summary>
    /// <returns>True when the permission is held.</returns>
    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch.");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Deletes a Data Exch. entry and its parsed fields unless an incoming document uses it.', Comment = 'is-IS=Eyðir gagnaskiptafærslu og þáttuðum reitum hennar nema skjal í innleið noti hana.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete data exchange entry, remove imported file, discard import, clean up data exchange', Comment = 'is-IS=eyða gagnaskiptafærslu, fjarlægja innflutta skrá, henda innflutningi, hreinsa gagnaskipti';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Removes one imported or exported Data Exch. entry and its fields; the definition and the business records written from the entry stay.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Supplies the envelope chapter for this message type.</summary>
    /// <param name="Envelope">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetDataExchangeEnvelope(true);
        Envelope.Add('messageType', 'DataExchange.Entry.Delete');
        exit(true);
    end;

    /// <summary>Supplies the target chapter for this message type.</summary>
    /// <param name="Target">Out: the record the request addresses.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Entry.Delete');
        exit(true);
    end;

    /// <summary>Supplies the parameters chapter for this message type.</summary>
    /// <param name="Parameters">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Entry.Delete');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Entry.Delete');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Entry.Delete');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Entry.Delete');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no metering chapter.</summary>
    /// <param name="Metering">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the related chapter for this message type.</summary>
    /// <param name="Related">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('DataExchange.Entry.Delete');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the recorded English examples for this message type.</summary>
    /// <param name="Examples">Out: recorded request and answer pairs.</param>
    /// <returns>True when recorded examples are available.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Examples := ContractParts.GetExamples('DataExchange.Entry.Delete');
        exit(Examples.Count() > 0);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Deletes the entry, its Data Exch. Field rows and the Bifröst marker. Records already written by processing are not touched.', Comment = 'is-IS=Eyðir færslunni, gagnaskiptareitum hennar og Bifröst-merkinu. Færslum sem vinnslan hefur þegar skrifað er ekki breytt.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'An entry that an incoming document uses is refused; delete or process the incoming document instead. Entries created by Bifröst are also removed by the retention policy for Bifrost Data Exchange Entry after 30 days by default.', Comment = 'is-IS=Færslu sem skjal í innleið notar er hafnað; eyddu eða vinndu skjalið í innleið í staðinn. Færslum sem Bifröst stofnaði er einnig eytt með varðveislureglu fyrir gagnaskiptafærslur Bifröst, sjálfgefið eftir 30 daga.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and the references before deleting the entry.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
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
        // No Boolean return: an error after a write rolls back every write of the call.
        Codeunit.Run(Codeunit::"DataExch Entry Delete Impl ori", Argument);
    end;

    local procedure DeleteEntry(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        EntryLink: Record "DataExch Entry Link ori";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        EntryNo: Integer;
        FieldCount: Integer;
        EntryNotFoundErr: Label 'Data Exch. entry %1 was not found.', Comment = '%1 = entry number||is-IS=Gagnaskiptafærsla %1 fannst ekki.';
        EntryExpectedLbl: Label 'an existing entry number', Comment = 'is-IS=númer fyrirliggjandi færslu';
        ChooseEntryLbl: Label 'Use an entryNo returned by DataExchange.Entry.List.', Comment = 'is-IS=Notaðu entryNo sem DataExchange.Entry.List skilar.';
        PositiveErr: Label 'Parameter "entryNo" must be greater than 0.', Comment = 'is-IS=Færibreytan "entryNo" verður að vera stærri en 0.';
        IncomingErr: Label 'Data Exch. entry %1 is used by incoming document %2 and cannot be deleted.', Comment = '%1 = entry number, %2 = incoming document entry number||is-IS=Skjal í innleið %2 notar gagnaskiptafærslu %1 og ekki er hægt að eyða henni.';
        IncomingExpectedLbl: Label 'an entry that no incoming document uses', Comment = 'is-IS=færsla sem ekkert skjal í innleið notar';
        IncomingNextStepLbl: Label 'Process or delete incoming document %1 first.', Comment = '%1 = incoming document entry number||is-IS=Vinndu eða eyddu skjali í innleið %1 fyrst.';
    begin
        RequestJson := Argument.GetRequestJson();
        if Reader.ReadInteger(Argument, RequestJson, 'entryNo', true, EntryNo) then
            if EntryNo < 1 then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, PositiveErr, 'entryNo', Format(EntryNo, 0, 9), EntryExpectedLbl, ChooseEntryLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch.", true) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch. Field", true) then
            exit;
        DataExch.ReadIsolation := IsolationLevel::UpdLock;
        DataExch.SetLoadFields("Entry No.", "Data Exch. Def Code", "Incoming Entry No.");
        if not DataExch.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryNotFoundErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), EntryExpectedLbl, ChooseEntryLbl);
            exit;
        end;
        if ImportMgt.IsUsedByIncomingDocument(DataExch) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(IncomingErr, EntryNo, DataExch."Incoming Entry No."), 'entryNo', Format(EntryNo, 0, 9),
                IncomingExpectedLbl, StrSubstNo(IncomingNextStepLbl, DataExch."Incoming Entry No."));
            exit;
        end;
        FieldCount := ImportMgt.FieldCount(EntryNo);
        if EntryLink.Get(EntryNo) then
            EntryLink.Delete(false);
        DataExch.Delete(true);
        DataObject.Add('entryNo', EntryNo);
        DataObject.Add('dataExchDefCode', DataExch."Data Exch. Def Code");
        DataObject.Add('deletedFieldCount', FieldCount);
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;
}
