namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Entry.Process</c>. Applies the mappings of the definition to a
/// parsed Data Exch. entry and reports the records written to each target table.
/// </summary>
codeunit 70013507 "DataExch Entry Proc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ProcessEntry(Rec);
    end;

    /// <summary>Reports whether the caller holds the table permission this message type needs.</summary>
    /// <returns>True when the permission is held.</returns>
    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.ReadPermission());
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
        DescriptionLbl: Label 'Applies the mappings of the definition to a parsed Data Exch. entry and reports the records written.', Comment = 'is-IS=Beitir vörpunum skilgreiningarinnar á þáttaða gagnaskiptafærslu og greinir frá færslunum sem voru skrifaðar.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'process data exchange entry, apply mapping, write imported lines, run import mapping, process imported file', Comment = 'is-IS=vinna gagnaskiptafærslu, beita vörpun, skrifa innfluttar línur, keyra innflutningsvörpun, vinna innflutta skrá';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Writes the parsed fields of an imported entry to the business tables of the definition mappings, as the second step after DataExchange.Import.Run or Storage.Upload.CommitToDataExchange.', Locked = true;
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
        Envelope.Add('messageType', 'DataExchange.Entry.Process');
        exit(true);
    end;

    /// <summary>Supplies the target chapter for this message type.</summary>
    /// <param name="Target">Out: the record the request addresses.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Entry.Process');
        exit(true);
    end;

    /// <summary>Supplies the parameters chapter for this message type.</summary>
    /// <param name="Parameters">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Entry.Process');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Entry.Process');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Entry.Process');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Entry.Process');
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
        Related := ContractParts.GetRelated('DataExchange.Entry.Process');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares that this implementation supplies no examples chapter.</summary>
    /// <param name="Examples">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Runs the mapping codeunits of the entry definition (Process Data Exch.) and returns targets with the inserted and modified record counts and up to 100 record SystemIds per table.', Comment = 'is-IS=Keyrir vörpunarkóðaeiningar skilgreiningar færslunnar (Process Data Exch.) og skilar marktöflum með fjölda nýrra og breyttra færslna og allt að 100 SystemId-gildum færslna í hverri töflu.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes in the current language.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A mapping error rolls back the whole processing and is answered as an error; the entry stays for another attempt. An entry is processed once. Mappings to the intermediate table belong to the incoming document path (Storage.Upload.CommitToRecord with dataExchangeType). The counts compare the target tables before and after the run, so writes by other sessions at the same time can be counted too.', Comment = 'is-IS=Villa í vörpun afturkallar alla vinnsluna og er svarað sem villu; færslan bíður annarrar tilraunar. Færsla er unnin einu sinni. Varpanir í millitöfluna tilheyra leið skjala í innleið (Storage.Upload.CommitToRecord með dataExchangeType). Fjöldinn ber saman marktöflurnar fyrir og eftir keyrslu, svo skrif annarra lota á sama tíma geta talist með.';
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

    /// <summary>Validates the request and the entry, then applies the mappings; a mapping error propagates and rolls back the processing.</summary>
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
        Codeunit.Run(Codeunit::"DataExch Entry Proc Impl ori", Argument);
    end;

    local procedure ProcessEntry(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        EntryLink: Record "DataExch Entry Link ori";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        Counts: Dictionary of [Integer, Integer];
        ErrorCode: Enum "Bifrost Error Code ori";
        LineDefText: Text;
        ErrorText: Text;
        Expected: Text;
        NextStep: Text;
        ParameterName: Text;
        StartTime: DateTime;
        EntryNo: Integer;
        EntryNotFoundErr: Label 'Data Exch. entry %1 was not found.', Comment = '%1 = entry number||is-IS=Gagnaskiptafærsla %1 fannst ekki.';
        EntryExpectedLbl: Label 'an existing entry number', Comment = 'is-IS=númer fyrirliggjandi færslu';
        ChooseEntryLbl: Label 'Use an entryNo returned by DataExchange.Import.Run or DataExchange.Entry.List.', Comment = 'is-IS=Notaðu entryNo sem DataExchange.Import.Run eða DataExchange.Entry.List skilar.';
        PositiveErr: Label 'Parameter "entryNo" must be greater than 0.', Comment = 'is-IS=Færibreytan "entryNo" verður að vera stærri en 0.';
        AlreadyProcessedErr: Label 'Data Exch. entry %1 has already been processed.', Comment = '%1 = entry number||is-IS=Gagnaskiptafærsla %1 hefur þegar verið unnin.';
        UnprocessedExpectedLbl: Label 'an entry that has not been processed', Comment = 'is-IS=færsla sem hefur ekki verið unnin';
        ImportAgainLbl: Label 'Import the file again with DataExchange.Import.Run to process it again.', Comment = 'is-IS=Flyttu skrána inn aftur með DataExchange.Import.Run til að vinna hana aftur.';
        IncomingErr: Label 'Data Exch. entry %1 belongs to incoming document %2.', Comment = '%1 = entry number, %2 = incoming document entry number||is-IS=Gagnaskiptafærsla %1 tilheyrir skjali í innleið %2.';
        IncomingExpectedLbl: Label 'an entry that is not part of an incoming document', Comment = 'is-IS=færsla sem er ekki hluti af skjali í innleið';
        IncomingNextStepLbl: Label 'Process the incoming document with Incoming.Document.Process.', Comment = 'is-IS=Vinndu skjalið í innleið með Incoming.Document.Process.';
    begin
        RequestJson := Argument.GetRequestJson();
        if Reader.ReadInteger(Argument, RequestJson, 'entryNo', true, EntryNo) then
            if EntryNo < 1 then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, PositiveErr, 'entryNo', Format(EntryNo, 0, 9), EntryExpectedLbl, ChooseEntryLbl);
        Reader.ReadMutationText(Argument, RequestJson, 'mappingLineDef', false, 20, LineDefText);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch.", false) then
            exit;
        DataExch.ReadIsolation := IsolationLevel::UpdLock;
        if not DataExch.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryNotFoundErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), EntryExpectedLbl, ChooseEntryLbl);
            exit;
        end;
        ImportMgt.CheckImportDefinition(Argument, DataExch."Data Exch. Def Code", 'entryNo');
        if Reader.RespondIfErrors(Argument) then
            exit;
        if DataExch."Incoming Entry No." <> 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(IncomingErr, EntryNo, DataExch."Incoming Entry No."), 'entryNo', Format(EntryNo, 0, 9), IncomingExpectedLbl, IncomingNextStepLbl);
            exit;
        end;
        EntryLink.SetLoadFields(Processed);
        if EntryLink.Get(EntryNo) then
            if EntryLink.Processed then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(AlreadyProcessedErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), UnprocessedExpectedLbl, ImportAgainLbl);
                exit;
            end;
        if ImportMgt.FindProcessBlocker(DataExch, CopyStr(LineDefText, 1, 20), ErrorCode, ErrorText, Expected, NextStep) then begin
            ParameterName := 'entryNo';
            if LineDefText <> '' then
                ParameterName := 'mappingLineDef';
            Argument.RespondWithError(ErrorCode, ErrorText, ParameterName, DataExch."Data Exch. Def Code", Expected, NextStep);
            exit;
        end;
        ImportMgt.SnapshotTargets(DataExch, CopyStr(LineDefText, 1, 20), Counts, StartTime);
        // A mapping error is raised and rolls back the processing; the entry stays.
        ImportMgt.RunMappings(DataExch, CopyStr(LineDefText, 1, 20));
        if LineDefText = '' then
            ImportMgt.MarkProcessed(EntryNo);
        DataObject.Add('entryNo', EntryNo);
        DataObject.Add('dataExchDefCode', DataExch."Data Exch. Def Code");
        if LineDefText <> '' then
            DataObject.Add('mappingLineDef', LineDefText);
        ImportMgt.BuildProcessResult(DataExch, CopyStr(LineDefText, 1, 20), Counts, StartTime, true, DataObject);
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;
}
