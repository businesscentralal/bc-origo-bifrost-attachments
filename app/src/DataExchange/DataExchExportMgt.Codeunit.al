namespace Origo.Bifrost.Attachments;

using Microsoft.Bank.BankAccount;
using Microsoft.Bank.Payment;
using Microsoft.Finance.GeneralLedger.Journal;
using Origo.Bifrost;
using System.IO;
using System.Reflection;
using System.Text;
using System.Utilities;

/// <summary>
/// The export engine behind <c>DataExchange.Export.Run</c> (Generic Export definitions) and
/// <c>DataExchange.PaymentExport.Run</c> (the base application's payment export of a journal batch),
/// plus the delivery of a produced file to storage or inline, which <c>DataExchange.Definition.Export</c>
/// shares.
/// </summary>
/// <remarks>
/// A generic export runs the standard steps of the definition (data handling, validation, pre-mapping,
/// mapping, post-mapping and the writer) in the caller's transaction. The definition's external data
/// handling step, which would download the file to a browser, is replaced by the storage or inline
/// delivery. Every check runs before the first write; a problem that shows only after a write (inline
/// size, storage write failure) is raised with the collected errors so all writes roll back.
/// </remarks>
codeunit 70013503 "DataExch Export Mgt ori"
{
    Access = Internal;

    var
        MissingValueLbl: Label '(missing)', Comment = 'is-IS=(vantar)';
        DefinitionNotFoundErr: Label 'Data Exchange definition %1 was not found.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 fannst ekki.';
        ExportDefinitionExpectedLbl: Label 'an existing Generic Export definition', Comment = 'is-IS=fyrirliggjandi skilgreining fyrir almennan útflutning (Generic Export)';
        SelectExportDefinitionLbl: Label 'Call DataExchange.Definition.List with direction Export and use the exact code of a Generic Export definition.', Comment = 'is-IS=Kallaðu á DataExchange.Definition.List með direction Export og notaðu nákvæman kóða skilgreiningar fyrir almennan útflutning (Generic Export).';
        ImportDefinitionErr: Label 'Data Exchange definition %1 is an import definition and cannot export records.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 er innflutningsskilgreining og getur ekki flutt út færslur.';
        PaymentDefinitionErr: Label 'Data Exchange definition %1 is a payment export definition. Payment files are exported from a payment journal batch.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 er skilgreining fyrir útflutning greiðslna. Greiðsluskrár eru fluttar út úr greiðslubók.';
        PaymentDefinitionNextStepLbl: Label 'Export the payment journal batch with DataExchange.PaymentExport.Run.', Comment = 'is-IS=Fluttu greiðslubókina út með DataExchange.PaymentExport.Run.';
        NoExportMappingErr: Label 'Data Exchange definition %1 has no mapping that names a source table.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 hefur enga vörpun sem tilgreinir upprunatöflu.';
        NoExportMappingLineErr: Label 'Data Exchange definition %1 has no mapping for line definition %2.', Comment = '%1 = definition code, %2 = line definition code||is-IS=Skilgreining gagnaskipta %1 hefur enga vörpun fyrir línuskilgreiningu %2.';
        ExportMappingExpectedLbl: Label 'a definition with a Data Exch. Mapping to the source table', Comment = 'is-IS=skilgreining með gagnaskiptavörpun á upprunatöfluna';
        AddExportMappingLbl: Label 'Add a mapping to the definition, or call DataExchange.Definition.Get to see its line definitions and mappings.', Comment = 'is-IS=Bættu vörpun við skilgreininguna eða kallaðu á DataExchange.Definition.Get til að sjá línuskilgreiningar hennar og varpanir.';
        NoWriterErr: Label 'Data Exchange definition %1 has neither a writing codeunit nor a writing XMLport, so no file can be written with it.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 hefur hvorki kóðaeiningu né XMLport til skriftar og því er ekki hægt að skrifa skrá með henni.';
        WriterExpectedLbl: Label 'a definition with a Reading/Writing Codeunit or Reading/Writing XMLport', Comment = 'is-IS=skilgreining með kóðaeiningu eða XMLport til lestrar og skriftar';
        CompleteDefinitionLbl: Label 'Complete the definition, for example by installing it with DataExchange.Definition.Import, and retry.', Comment = 'is-IS=Ljúktu við skilgreininguna, til dæmis með því að setja hana upp með DataExchange.Definition.Import, og reyndu aftur.';
        TableMismatchErr: Label 'Table %1 is not the source table of definition %2, which exports table %3.', Comment = '%1 = requested table id, %2 = definition code, %3 = mapping table id||is-IS=Tafla %1 er ekki upprunatafla skilgreiningar %2, sem flytur út töflu %3.';
        TableMismatchExpectedLbl: Label 'table %1', Comment = '%1 = table id||is-IS=tafla %1';
        TableMismatchNextStepLbl: Label 'Send the table of the definition mapping, or omit tableId and tableName to use it.', Comment = 'is-IS=Sendu töflu skilgreiningarvörpunarinnar, eða slepptu tableId og tableName til að nota hana.';
        UnknownTableErr: Label 'Table %1 does not exist.', Comment = '%1 = table id or name||is-IS=Tafla %1 er ekki til.';
        SourceRequiredErr: Label 'Name the records to export with tableId or tableName (and an optional tableView), or with recordIds.', Comment = 'is-IS=Tilgreindu færslurnar sem á að flytja út með tableId eða tableName (og valfrjálsu tableView), eða með recordIds.';
        SourceExpectedLbl: Label 'tableId or tableName, or recordIds', Comment = 'is-IS=tableId eða tableName, eða recordIds';
        SourceNextStepLbl: Label 'Send tableId 18 with tableView WHERE(No.=FILTER(10000..30000)), for example, or a recordIds array of SystemIds.', Comment = 'is-IS=Sendu til dæmis tableId 18 með tableView WHERE(No.=FILTER(10000..30000)) eða fylkið recordIds með SystemId-gildum.';
        ViewAndIdsErr: Label 'Send either tableView or recordIds, not both.', Comment = 'is-IS=Sendu annaðhvort tableView eða recordIds, ekki hvort tveggja.';
        ViewAndIdsExpectedLbl: Label 'one record selection', Comment = 'is-IS=eitt val á færslum';
        ViewAndIdsNextStepLbl: Label 'Remove tableView to export the listed records, or remove recordIds to export the filtered records.', Comment = 'is-IS=Fjarlægðu tableView til að flytja út skráðar færslur, eða fjarlægðu recordIds til að flytja út síaðar færslur.';
        RecordIdsFormatErr: Label 'Parameter "recordIds" must be an array of 1 to 1000 SystemId strings.', Comment = 'is-IS=Færibreytan "recordIds" verður að vera fylki með 1 til 1000 SystemId-strengjum.';
        RecordIdsExpectedLbl: Label 'an array of SystemId GUID strings', Comment = 'is-IS=fylki með SystemId GUID-strengjum';
        RecordIdsNextStepLbl: Label 'Send the SystemIds returned by Data.Records.Get, at most 1000 per call.', Comment = 'is-IS=Sendu SystemId-gildin sem Data.Records.Get skilar, mest 1000 í hverju kalli.';
        NoRecordsErr: Label 'No records of table %1 match the selection, so there is nothing to export.', Comment = '%1 = table id||is-IS=Engar færslur í töflu %1 passa við valið og því er ekkert að flytja út.';
        NoRecordsExpectedLbl: Label 'at least one matching record', Comment = 'is-IS=að minnsta kosti ein færsla sem passar';
        NoRecordsNextStepLbl: Label 'Widen the tableView or check the recordIds, then retry.', Comment = 'is-IS=Víkkaðu tableView eða athugaðu recordIds og reyndu svo aftur.';
        DeliveryRequiredErr: Label 'Choose where the file goes: storageCode with path or folderPath, or inline true.', Comment = 'is-IS=Veldu hvert skráin fer: storageCode með path eða folderPath, eða inline true.';
        DeliveryExpectedLbl: Label 'storageCode, or inline true', Comment = 'is-IS=storageCode, eða inline true';
        DeliveryNextStepLbl: Label 'Send storageCode (find it with Storage.Account.List), or inline true for a file of at most 1 MB.', Comment = 'is-IS=Sendu storageCode (finndu hann með Storage.Account.List), eða inline true fyrir skrá sem er mest 1 MB.';
        PathAndFolderErr: Label 'Send either path or folderPath, not both.', Comment = 'is-IS=Sendu annaðhvort path eða folderPath, ekki hvort tveggja.';
        PathAndFolderExpectedLbl: Label 'path or folderPath', Comment = 'is-IS=path eða folderPath';
        PathAndFolderNextStepLbl: Label 'Send path for an exact file path, or folderPath to let the file name be chosen.', Comment = 'is-IS=Sendu path fyrir nákvæma skráarslóð, eða folderPath til að láta velja skráarheitið.';
        PathWithoutStorageErr: Label 'Parameter "%1" needs storageCode.', Comment = '%1 = parameter||is-IS=Færibreytan "%1" þarf storageCode.';
        InlineTooLargeErr: Label 'The file is %1 bytes; inline delivery is limited to %2 bytes (1 MB). Nothing was changed.', Comment = '%1 = size, %2 = limit||is-IS=Skráin er %1 bæti; innfelld afhending er takmörkuð við %2 bæti (1 MB). Engu var breytt.';
        InlineLimitExpectedLbl: Label 'at most 1048576 bytes', Comment = 'is-IS=í mesta lagi 1048576 bæti';
        UseStorageDeliveryLbl: Label 'Send storageCode with path or folderPath and read the file with Storage.File.Get, or omit inline.', Comment = 'is-IS=Sendu storageCode með path eða folderPath og lestu skrána með Storage.File.Get, eða slepptu inline.';
        StorageWriteFailedErr: Label 'The file could not be written to storage, so the export was rolled back: %1', Comment = '%1 = connector error||is-IS=Ekki tókst að skrifa skrána í geymslu og því var útflutningurinn afturkallaður: %1';
        StorageWriteNextStepLbl: Label 'Check the storage connection and the path, then retry.', Comment = 'is-IS=Athugaðu geymslutenginguna og slóðina og reyndu svo aftur.';
        EmptyFileErr: Label 'The writer of definition %1 produced no file content.', Comment = '%1 = definition code||is-IS=Ritari skilgreiningar %1 bjó ekki til neitt skráarinnihald.';
        EmptyFileNextStepLbl: Label 'Check the column definitions and field mappings with DataExchange.Definition.Get.', Comment = 'is-IS=Athugaðu dálkaskilgreiningar og reitavarpanir með DataExchange.Definition.Get.';
        BatchNotFoundErr: Label 'Journal batch %1 %2 was not found.', Comment = '%1 = template name, %2 = batch name||is-IS=Bókarkeyrsla %1 %2 fannst ekki.';
        BatchExpectedLbl: Label 'an existing payment journal template and batch', Comment = 'is-IS=fyrirliggjandi sniðmát og keyrsla greiðslubókar';
        BatchNextStepLbl: Label 'Read the journal batches with Data.Records.Get on Gen. Journal Batch and send the exact template and batch names.', Comment = 'is-IS=Lestu bókarkeyrslurnar með Data.Records.Get á Gen. Journal Batch og sendu nákvæm heiti sniðmáts og keyrslu.';
        NothingToExportErr: Label 'Journal batch %1 %2 has no lines to export.', Comment = '%1 = template name, %2 = batch name||is-IS=Bókarkeyrsla %1 %2 hefur engar línur til að flytja út.';
        LinesExpectedLbl: Label 'a batch with payment lines', Comment = 'is-IS=keyrsla með greiðslulínum';
        LinesNextStepLbl: Label 'Create the payment lines, for example with Suggest Vendor Payments, then retry.', Comment = 'is-IS=Búðu til greiðslulínurnar, til dæmis með Leggja til greiðslur lánardrottna, og reyndu svo aftur.';
        BankRequiredErr: Label 'The lines of journal batch %1 %2 must have a bank account as balancing account with a payment export format.', Comment = '%1 = template name, %2 = batch name||is-IS=Línur bókarkeyrslu %1 %2 verða að hafa bankareikning sem mótreikning með sniði fyrir útflutning greiðslna.';
        BankExpectedLbl: Label 'a balancing bank account with Payment Export Format', Comment = 'is-IS=mótbankareikningur með sniði fyrir útflutning greiðslna (Payment Export Format)';
        BankNextStepLbl: Label 'Set Bal. Account Type Bank Account on the lines and a Payment Export Format on the bank account, then retry.', Comment = 'is-IS=Settu mótreikningsgerðina Bankareikningur á línurnar og snið fyrir útflutning greiðslna á bankareikninginn og reyndu svo aftur.';
        NoPaymentFileErr: Label 'The payment export of bank account %1 did not hand a file over. Its export codeunit writes the file in a way Bifröst cannot capture.', Comment = '%1 = bank account no.||is-IS=Útflutningur greiðslna bankareiknings %1 skilaði engri skrá. Útflutningskóðaeining hans skrifar skrána á hátt sem Bifröst getur ekki gripið.';
        NoPaymentFileExpectedLbl: Label 'the SEPA credit transfer export or a Data Exchange payment export', Comment = 'is-IS=SEPA-útflutningur millifærslna eða útflutningur greiðslna með gagnaskiptum';
        NoPaymentFileNextStepLbl: Label 'Use a payment export format whose processing codeunit is SEPA CT-Export File or empty, or export the batch in the Payment Journal page.', Comment = 'is-IS=Notaðu útflutningssnið þar sem vinnslukóðaeiningin er SEPA CT-Export File eða tóm, eða fluttu keyrsluna út á síðunni Greiðslubók.';
        JournalNameErr: Label 'Parameter "%1" must be a journal name of at most 10 characters in its canonical uppercase spelling.', Comment = '%1 = parameter||is-IS=Færibreytan "%1" verður að vera heiti bókar, mest 10 stafir, í stöðluðum hástöfum.';
        JournalNameExpectedLbl: Label 'an uppercase name of at most 10 characters', Comment = 'is-IS=heiti með hástöfum, mest 10 stafir';
        JournalNameNextStepLbl: Label 'Send the name exactly as Data.Records.Get returns it.', Comment = 'is-IS=Sendu heitið nákvæmlega eins og Data.Records.Get skilar því.';

    /// <summary>Runs <c>DataExchange.Export.Run</c>: exports the selected records with a Generic Export definition and delivers the file.</summary>
    /// <param name="Argument">The request; receives the response.</param>
    procedure RunGenericExport(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        DataExchMapping: Record "Data Exch. Mapping";
        DataExch: Record "Data Exch.";
        StorageSetup: Record "Storage Setup ori";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
        TempBlob: Codeunit "Temp Blob";
        SourceRef: RecordRef;
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        RecordIds: List of [Guid];
        DefCode: Code[20];
        LineDefText: Text;
        FileName: Text;
        Path: Text;
        TableView: Text;
        TableId: Integer;
        TableParameter: Text;
        FolderPath: Text;
        RecordCount: Integer;
        HasStorage: Boolean;
        Inline: Boolean;
        EmptyGuid: Guid;
    begin
        RequestJson := Argument.GetRequestJson();
        // Phase 1: the definition and the file name.
        Reader.ReadMutationCode(Argument, RequestJson, 'dataExchDefCode', DefCode);
        if Reader.ReadMutationText(Argument, RequestJson, 'fileName', false, MaxStrLen(DataExch."File Name"), FileName) then
            if FileName <> '' then
                Reader.CheckFileName(Argument, FileName);
        // Read all independent request fields before returning collected problems.
        Reader.ReadMutationText(Argument, RequestJson, 'lineDef', false, 20, LineDefText);
        ReadSourceTable(Argument, RequestJson, TableId, TableParameter);
        ReadRecordIds(Argument, RequestJson, RecordIds);
        Reader.ReadText(Argument, RequestJson, 'tableView', false, TableView);
        if RequestJson.Contains('tableView') and RequestJson.Contains('recordIds') then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, ViewAndIdsErr, 'tableView', TableView, ViewAndIdsExpectedLbl, ViewAndIdsNextStepLbl);
        if (TableId = 0) and (TableParameter = '') and (RecordIds.Count() = 0) and not RequestJson.Contains('recordIds') then
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, SourceRequiredErr, 'tableId', MissingValueLbl, SourceExpectedLbl, SourceNextStepLbl);
        if DefCode <> '' then
            CheckExportDefinition(Argument, DefCode, DataExchDef);
        if (FileName = '') and (DataExchDef.Code <> '') then
            FileName := DefaultExportFileName(DataExchDef);
        ReadDelivery(Argument, RequestJson, FileName, StorageSetup, Connector, Path, HasStorage, Inline, FolderPath);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch.", true) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch. Field", true) then
            exit;
        if FileName = '' then
            FileName := DefaultExportFileName(DataExchDef);
        if HasStorage and (Path = '') then begin
            Path := RequestMgt.CombinedPath(FolderPath, FileName);
            Reader.CheckStoragePath(Argument, StorageSetup, 'path', Path, false);
        end;
        FindExportMapping(Argument, DataExchDef, CopyStr(LineDefText, 1, 20), DataExchMapping);
        if (TableId <> 0) and (DataExchMapping."Table ID" <> 0) and (TableId <> DataExchMapping."Table ID") then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TableMismatchErr, TableId, DefCode, DataExchMapping."Table ID"), TableParameter, Format(TableId, 0, 9),
                StrSubstNo(TableMismatchExpectedLbl, DataExchMapping."Table ID"), TableMismatchNextStepLbl);
        if (DataExchDef."Reading/Writing Codeunit" = 0) and (DataExchDef."Reading/Writing XMLport" = 0) then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoWriterErr, DefCode), 'dataExchDefCode', DefCode, WriterExpectedLbl, CompleteDefinitionLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, DataExchMapping."Table ID", false) then
            exit;
        SourceRef.Open(DataExchMapping."Table ID");
        if RecordIds.Count() > 0 then
            ApplyRecordIds(SourceRef, RecordIds)
        else
            if not ApplyValidatedView(Argument, TableView, SourceRef) then
                exit;
        RecordCount := SourceRef.Count();
        if RecordCount = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoRecordsErr, SourceRef.Number()), 'tableView', TableView, NoRecordsExpectedLbl, NoRecordsNextStepLbl);
            exit;
        end;
        if HasStorage then
            if not CheckDestination(Argument, StorageSetup, Path) then
                exit;

        // Writes start here; a later problem is raised so that every write rolls back.
        CreateExportEntry(DataExch, DataExchMapping, FileName, SourceRef.GetView());
        ImportMgt.InsertLink(DataExch."Entry No.", EmptyGuid, 'DataExchange.Export.Run', StorageSetup.Code, Path);
        RunExportSteps(DataExch, DataExchDef, DataExchMapping);
        ReadFileContent(Argument, DataExch, TempBlob);

        ResponseJson.Add('entryNo', DataExch."Entry No.");
        ResponseJson.Add('fileName', FileName);
        ResponseJson.Add('dataExchDefCode', DefCode);
        ResponseJson.Add('recordCount', RecordCount);
        Deliver(Argument, TempBlob, StorageSetup, Connector, Path, HasStorage, Inline, true, ResponseJson);
        RequestMgt.RespondSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Runs <c>DataExchange.PaymentExport.Run</c>: exports a payment journal batch with the payment export
    /// format of its balancing bank account, as the Payment Journal's Export action does, and delivers the file.
    /// </summary>
    /// <param name="Argument">The request; receives the response.</param>
    procedure RunPaymentExport(var Argument: Record "Message Argument ori")
    var
        GenJournalBatch: Record "Gen. Journal Batch";
        GenJournalLine: Record "Gen. Journal Line";
        BankAccount: Record "Bank Account";
        CreditTransferRegister: Record "Credit Transfer Register";
        StorageSetup: Record "Storage Setup ori";
        Capture: Codeunit "DataExch Pay Capture ori";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        TemplateName: Code[10];
        BatchName: Code[10];
        FileName: Text;
        CapturedFileName: Text;
        Path: Text;
        FolderPath: Text;
        HasStorage: Boolean;
        Inline: Boolean;
        LineCount: Integer;
        ExportedCount: Integer;
        DataExchEntryNo: Integer;
        EmptyGuid: Guid;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadJournalName(Argument, RequestJson, 'journalTemplate', TemplateName);
        ReadJournalName(Argument, RequestJson, 'journalBatch', BatchName);
        if Reader.ReadMutationText(Argument, RequestJson, 'fileName', false, 250, FileName) then
            if FileName <> '' then
                Reader.CheckFileName(Argument, FileName);
        ReadDelivery(Argument, RequestJson, FileName, StorageSetup, Connector, Path, HasStorage, Inline, FolderPath);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Gen. Journal Line", true) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch.", true) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Credit Transfer Register", true) then
            exit;
        GenJournalBatch.SetLoadFields("Journal Template Name", Name);
        if not GenJournalBatch.Get(TemplateName, BatchName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(BatchNotFoundErr, TemplateName, BatchName), 'journalBatch', BatchName, BatchExpectedLbl, BatchNextStepLbl);
            exit;
        end;
        GenJournalLine.SetLoadFields("Journal Template Name", "Journal Batch Name", "Line No.", "Bal. Account Type", "Bal. Account No.");
        GenJournalLine.SetRange("Journal Template Name", TemplateName);
        GenJournalLine.SetRange("Journal Batch Name", BatchName);
        LineCount := GenJournalLine.Count();
        if not GenJournalLine.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NothingToExportErr, TemplateName, BatchName), 'journalBatch', BatchName, LinesExpectedLbl, LinesNextStepLbl);
            exit;
        end;
        BankAccount.SetLoadFields("No.", "Payment Export Format");
        if (GenJournalLine."Bal. Account Type" <> GenJournalLine."Bal. Account Type"::"Bank Account") or (not BankAccount.Get(GenJournalLine."Bal. Account No.")) or (BankAccount."Payment Export Format" = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(BankRequiredErr, TemplateName, BatchName), 'journalBatch', BatchName, BankExpectedLbl, BankNextStepLbl);
            exit;
        end;
        if HasStorage and (Path <> '') then
            if not CheckDestination(Argument, StorageSetup, Path) then
                exit;

        // The base-app export marks the lines and fills the credit transfer register. Its client
        // download is captured instead, so the file can be delivered to storage.
        GenJournalLine.SetLoadFields();
        GenJournalLine.Reset();
        GenJournalLine.SetRange("Journal Template Name", TemplateName);
        GenJournalLine.SetRange("Journal Batch Name", BatchName);
        GenJournalLine.FindFirst();
        BindSubscription(Capture);
        GenJournalLine.ExportPaymentFile();
        UnbindSubscription(Capture);
        if not Capture.GetFile(TempBlob, CapturedFileName) then begin
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoPaymentFileErr, BankAccount."No."), 'journalBatch', BatchName, NoPaymentFileExpectedLbl, NoPaymentFileNextStepLbl);
            Argument.RaiseCollectedErrors("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoPaymentFileErr, BankAccount."No."));
        end;
        if FileName = '' then
            FileName := CapturedFileName;
        if HasStorage then
            CompletePath(Argument, StorageSetup, FolderPath, FileName, Path);

        GenJournalLine.Reset();
        GenJournalLine.SetRange("Journal Template Name", TemplateName);
        GenJournalLine.SetRange("Journal Batch Name", BatchName);
        GenJournalLine.SetRange("Exported to Payment File", true);
        ExportedCount := GenJournalLine.Count();
        GenJournalLine.SetRange("Exported to Payment File");
        GenJournalLine.SetFilter("Data Exch. Entry No.", '<>0');
        GenJournalLine.SetLoadFields("Data Exch. Entry No.");
        if GenJournalLine.FindFirst() then
            DataExchEntryNo := GenJournalLine."Data Exch. Entry No.";
        if DataExchEntryNo <> 0 then
            if not EntryIsLinked(DataExchEntryNo) then
                ImportMgt.InsertLink(DataExchEntryNo, EmptyGuid, 'DataExchange.PaymentExport.Run', StorageSetup.Code, Path);
        CreditTransferRegister.SetLoadFields("No.", "From Bank Account No.");
        CreditTransferRegister.SetRange("From Bank Account No.", BankAccount."No.");

        ResponseJson.Add('journalTemplate', TemplateName);
        ResponseJson.Add('journalBatch', BatchName);
        ResponseJson.Add('bankAccountNo', BankAccount."No.");
        ResponseJson.Add('paymentExportFormat', BankAccount."Payment Export Format");
        ResponseJson.Add('lineCount', LineCount);
        ResponseJson.Add('exportedLineCount', ExportedCount);
        if CreditTransferRegister.FindLast() then
            ResponseJson.Add('creditTransferRegisterNo', CreditTransferRegister."No.");
        if DataExchEntryNo <> 0 then
            ResponseJson.Add('entryNo', DataExchEntryNo);
        ResponseJson.Add('fileName', FileName);
        Deliver(Argument, TempBlob, StorageSetup, Connector, Path, HasStorage, Inline, true, ResponseJson);
        RequestMgt.RespondSuccess(Argument, ResponseJson);
    end;

    /// <summary>
    /// Reads the delivery of a produced file: <c>storageCode</c> with <c>path</c> or <c>folderPath</c>
    /// (the file name is appended to a folder), and/or <c>inline</c>. At least one is required. Problems are collected.
    /// </summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request.</param>
    /// <param name="FileName">The file name used with folderPath or as the default path.</param>
    /// <param name="StorageSetup">Returns the resolved storage connection.</param>
    /// <param name="Connector">Returns the connector.</param>
    /// <param name="Path">Returns the destination path.</param>
    /// <param name="HasStorage">Returns whether the file goes to storage.</param>
    /// <param name="Inline">Returns whether the file is returned inline.</param>
    /// <param name="FolderPath">Returns the folder; when FileName is empty the path is completed later with <see cref="CompletePath"/>.</param>
    procedure ReadDelivery(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; FileName: Text; var StorageSetup: Record "Storage Setup ori"; var Connector: Interface "Storage Connector ori"; var Path: Text; var HasStorage: Boolean; var Inline: Boolean; var FolderPath: Text)
    var
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        StorageCode: Code[20];
        InlineValid: Boolean;
    begin
        Clear(Path);
        Clear(FolderPath);
        // An interface must be initialized before it is passed on, even when no storage is used.
        Connector := StorageSetup."Storage Type";
        HasStorage := RequestJson.Contains('storageCode');
        Inline := false;
        InlineValid := Reader.ReadBoolean(Argument, RequestJson, 'inline', false, Inline);
        if Reader.ReadMutationText(Argument, RequestJson, 'path', false, 2048, Path) then
            if Path <> '' then
                Reader.CheckPath(Argument, 'path', Path);
        if Reader.ReadMutationText(Argument, RequestJson, 'folderPath', false, 2048, FolderPath) then
            if FolderPath <> '' then
                Reader.CheckPath(Argument, 'folderPath', FolderPath);
        if (Path <> '') and (FolderPath <> '') then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, PathAndFolderErr, 'folderPath', FolderPath, PathAndFolderExpectedLbl, PathAndFolderNextStepLbl);
        if not HasStorage then begin
            if Path <> '' then
                Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(PathWithoutStorageErr, 'path'), 'storageCode', MissingValueLbl, DeliveryExpectedLbl, DeliveryNextStepLbl)
            else
                if FolderPath <> '' then
                    Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(PathWithoutStorageErr, 'folderPath'), 'storageCode', MissingValueLbl, DeliveryExpectedLbl, DeliveryNextStepLbl);
            if (Path = '') and (FolderPath = '') and InlineValid and not Inline then
                Argument.AddError("Bifrost Error Code ori"::MissingParameter, DeliveryRequiredErr, 'storageCode', MissingValueLbl, DeliveryExpectedLbl, DeliveryNextStepLbl);
            exit;
        end;
        if not Reader.ReadMutationCode(Argument, RequestJson, 'storageCode', StorageCode) then
            exit;
        if (Path = '') and (FileName <> '') then
            Path := RequestMgt.CombinedPath(FolderPath, FileName);
        if RequestMgt.ResolveSetup(Argument, StorageCode, 'storageCode', StorageSetup, Connector) then
            if Path <> '' then
                Reader.CheckStoragePath(Argument, StorageSetup, 'path', Path, false);
    end;

    /// <summary>
    /// Completes a storage path whose file name was only known after the export, and checks it. A
    /// problem is raised, because the export has already written.
    /// </summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="StorageSetup">The storage connection.</param>
    /// <param name="FolderPath">The requested folder.</param>
    /// <param name="FileName">The produced file name.</param>
    /// <param name="Path">The path; completed when empty.</param>
    procedure CompletePath(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; FolderPath: Text; FileName: Text; var Path: Text)
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        LinkedErr: Label 'File "%1" backs a Business Central attachment and cannot be overwritten by an export.', Comment = '%1 = storage path||is-IS=Skráin "%1" geymir viðhengi í Business Central og útflutningur má ekki yfirskrifa hana.';
        LinkedNextStepLbl: Label 'Choose another path or folderPath and export again.', Comment = 'is-IS=Veldu aðra slóð eða möppu (path eða folderPath) og fluttu út aftur.';
    begin
        if Path = '' then begin
            Path := RequestMgt.CombinedPath(FolderPath, FileName);
            Reader.CheckStoragePath(Argument, StorageSetup, 'path', Path, false);
            if not Argument.HasCollectedErrors() then
                if AttachmentMgt.IsStorageFileLinked(StorageSetup.Code, Path) then
                    Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(LinkedErr, Path), 'path', Path, '', LinkedNextStepLbl);
        end;
        if Argument.HasCollectedErrors() then
            Argument.RaiseCollectedErrors("Bifrost Error Code ori"::MultipleErrors, StrSubstNo(LinkedErr, Path));
    end;

    /// <summary>Refuses a destination that backs an attachment, before any write.</summary>
    /// <param name="Argument">The message argument; receives the refusal.</param>
    /// <param name="StorageSetup">The storage connection.</param>
    /// <param name="Path">The destination path.</param>
    /// <returns>True when the destination may be written.</returns>
    procedure CheckDestination(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
    begin
        exit(RequestMgt.CheckUnlinkedDestination(Argument, StorageSetup.Code, Path, 'path'));
    end;

    /// <summary>
    /// Delivers a produced file: refuses inline content over 1 MB, writes the file to storage as the last
    /// step and adds storageCode, path, contentLength and contentBase64 to the response.
    /// </summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="TempBlob">The file content.</param>
    /// <param name="StorageSetup">The storage connection, when HasStorage.</param>
    /// <param name="Connector">The connector, when HasStorage.</param>
    /// <param name="Path">The destination path, when HasStorage.</param>
    /// <param name="HasStorage">Whether the file goes to storage.</param>
    /// <param name="Inline">Whether the file is returned inline.</param>
    /// <param name="RaiseOnFailure">True after database writes: a failure is raised so the writes roll back. False: the failure is answered.</param>
    /// <param name="ResponseJson">The data payload that receives the delivery fields.</param>
    /// <returns>True when the file was delivered; false when an error response was written.</returns>
    procedure Deliver(var Argument: Record "Message Argument ori"; var TempBlob: Codeunit "Temp Blob"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; HasStorage: Boolean; Inline: Boolean; RaiseOnFailure: Boolean; var ResponseJson: JsonObject): Boolean
    var
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Base64Convert: Codeunit "Base64 Convert";
        ContentInStream: InStream;
        ErrorText: Text;
    begin
        if Inline and (TempBlob.Length() > ImportMgt.MaxInlineBytes()) then begin
            ErrorText := StrSubstNo(InlineTooLargeErr, Format(TempBlob.Length(), 0, 9), Format(ImportMgt.MaxInlineBytes(), 0, 9));
            Argument.AddError("Bifrost Error Code ori"::LimitExceeded, ErrorText, 'inline', Format(TempBlob.Length(), 0, 9), InlineLimitExpectedLbl, UseStorageDeliveryLbl);
            exit(FailDelivery(Argument, RaiseOnFailure, "Bifrost Error Code ori"::LimitExceeded, ErrorText));
        end;
        if HasStorage then
            if not RequestMgt.TryWriteStorageFile(StorageSetup, Connector, Path, TempBlob) then begin
                ErrorText := StrSubstNo(StorageWriteFailedErr, GetLastErrorText());
                Argument.AddError("Bifrost Error Code ori"::BusinessCentralError, ErrorText, 'storageCode', StorageSetup.Code, '', StorageWriteNextStepLbl);
                exit(FailDelivery(Argument, RaiseOnFailure, "Bifrost Error Code ori"::BusinessCentralError, ErrorText));
            end;
        if HasStorage then begin
            ResponseJson.Add('storageCode', StorageSetup.Code);
            ResponseJson.Add('path', Path);
        end;
        ResponseJson.Add('contentLength', TempBlob.Length());
        if Inline then begin
            TempBlob.CreateInStream(ContentInStream);
            ResponseJson.Add('contentBase64', Base64Convert.ToBase64(ContentInStream));
        end;
        exit(true);
    end;

    local procedure FailDelivery(var Argument: Record "Message Argument ori"; RaiseOnFailure: Boolean; ErrorCode: Enum "Bifrost Error Code ori"; ErrorText: Text): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        if RaiseOnFailure then
            Argument.RaiseCollectedErrors(ErrorCode, ErrorText);
        Reader.RespondIfErrors(Argument);
        exit(false);
    end;

    local procedure CheckExportDefinition(var Argument: Record "Message Argument ori"; DefCode: Code[20]; var DataExchDef: Record "Data Exch. Def")
    begin
        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        if not DataExchDef.Get(DefCode) then begin
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(DefinitionNotFoundErr, DefCode), 'dataExchDefCode', DefCode, ExportDefinitionExpectedLbl, SelectExportDefinitionLbl);
            exit;
        end;
        case DataExchDef.Type of
            DataExchDef.Type::"Generic Export":
                exit;
            DataExchDef.Type::"Payment Export", DataExchDef.Type::"Positive Pay Export":
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(PaymentDefinitionErr, DefCode), 'dataExchDefCode', DefCode, ExportDefinitionExpectedLbl, PaymentDefinitionNextStepLbl);
            else
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ImportDefinitionErr, DefCode), 'dataExchDefCode', DefCode, ExportDefinitionExpectedLbl, SelectExportDefinitionLbl);
        end;
    end;

    local procedure FindExportMapping(var Argument: Record "Message Argument ori"; DataExchDef: Record "Data Exch. Def"; LineDefCode: Code[20]; var DataExchMapping: Record "Data Exch. Mapping")
    begin
        DataExchMapping.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchMapping.SetRange("Data Exch. Def Code", DataExchDef.Code);
        if LineDefCode <> '' then
            DataExchMapping.SetRange("Data Exch. Line Def Code", LineDefCode);
        DataExchMapping.SetFilter("Table ID", '<>0');
        if DataExchMapping.FindFirst() then
            exit;
        Clear(DataExchMapping);
        if LineDefCode <> '' then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoExportMappingLineErr, DataExchDef.Code, LineDefCode), 'lineDef', LineDefCode, ExportMappingExpectedLbl, AddExportMappingLbl)
        else
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoExportMappingErr, DataExchDef.Code), 'dataExchDefCode', DataExchDef.Code, ExportMappingExpectedLbl, AddExportMappingLbl);
    end;

    local procedure ReadSourceTable(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var TableId: Integer; var TableParameter: Text)
    var
        AllObjWithCaption: Record AllObjWithCaption;
        Reader: Codeunit "Storage Request Reader ori";
        TableName: Text;
    begin
        TableId := 0;
        TableParameter := '';
        if RequestJson.Contains('tableId') then begin
            TableParameter := 'tableId';
            if not Reader.ReadInteger(Argument, RequestJson, 'tableId', false, TableId) then
                exit;
            if TableId = 0 then
                exit;
            AllObjWithCaption.SetLoadFields("Object Type", "Object ID");
            if not AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Table, TableId) then
                Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownTableErr, TableId), 'tableId', Format(TableId, 0, 9), '', SourceNextStepLbl);
            exit;
        end;
        if not RequestJson.Contains('tableName') then
            exit;
        TableParameter := 'tableName';
        Reader.ReadText(Argument, RequestJson, 'tableName', false, TableName);
        if TableName = '' then
            exit;
        AllObjWithCaption.SetLoadFields("Object Type", "Object ID", "Object Name");
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Table);
        AllObjWithCaption.SetRange("Object Name", CopyStr(TableName, 1, MaxStrLen(AllObjWithCaption."Object Name")));
        if AllObjWithCaption.FindFirst() then
            TableId := AllObjWithCaption."Object ID"
        else
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownTableErr, TableName), 'tableName', TableName, '', SourceNextStepLbl);
    end;

    local procedure ReadRecordIds(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var RecordIds: List of [Guid])
    var
        Reader: Codeunit "Storage Request Reader ori";
        Token: JsonToken;
        ItemToken: JsonToken;
        RecordSystemId: Guid;
    begin
        Clear(RecordIds);
        if not RequestJson.Get('recordIds', Token) then
            exit;
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                exit;
        if (not Token.IsArray()) or (Token.AsArray().Count() = 0) or (Token.AsArray().Count() > 1000) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, RecordIdsFormatErr, 'recordIds', CopyStr(Reader.TokenText(Token), 1, 250), RecordIdsExpectedLbl, RecordIdsNextStepLbl);
            exit;
        end;
        foreach ItemToken in Token.AsArray() do begin
            if not ItemToken.IsValue() then begin
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, RecordIdsFormatErr, 'recordIds', CopyStr(Reader.TokenText(ItemToken), 1, 250), RecordIdsExpectedLbl, RecordIdsNextStepLbl);
                exit;
            end;
            if not Evaluate(RecordSystemId, ItemToken.AsValue().AsText()) then begin
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, RecordIdsFormatErr, 'recordIds', ItemToken.AsValue().AsText(), RecordIdsExpectedLbl, RecordIdsNextStepLbl);
                exit;
            end;
            if not RecordIds.Contains(RecordSystemId) then
                RecordIds.Add(RecordSystemId);
        end;
    end;

    local procedure ApplyRecordIds(var SourceRef: RecordRef; RecordIds: List of [Guid])
    var
        SystemIdRef: FieldRef;
        FilterText: TextBuilder;
        RecordSystemId: Guid;
    begin
        foreach RecordSystemId in RecordIds do begin
            if FilterText.Length() > 0 then
                FilterText.Append('|');
            FilterText.Append(Format(RecordSystemId));
        end;
        SystemIdRef := SourceRef.Field(SourceRef.SystemIdNo());
        SystemIdRef.SetFilter(FilterText.ToText());
    end;

    local procedure ApplyValidatedView(var Argument: Record "Message Argument ori"; TableView: Text; var SourceRef: RecordRef): Boolean
    var
        ViewFilter: Codeunit "DataExch View Filter ori";
    begin
        if TableView = '' then
            exit(true);
        ViewFilter.SetSource(Argument."Type", SourceRef.Number(), TableView);
        ViewFilter.Run();
        if not ViewFilter.IsValid() then begin
            // Foundation answered the refusal on its own argument; hand it to the caller.
            Argument.SetResponseJson(ViewFilter.GetRefusal());
            Argument."Content Type" := Argument.GetContentTypeJson();
            exit(false);
        end;
        // tableView validated by the caller
        SourceRef.SetView(ViewFilter.GetAppliedView());
        exit(true);
    end;

    local procedure CreateExportEntry(var DataExch: Record "Data Exch."; DataExchMapping: Record "Data Exch. Mapping"; FileName: Text; TableFilters: Text)
    var
        TableFiltersOutStream: OutStream;
    begin
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DataExchMapping."Data Exch. Def Code";
        DataExch."Data Exch. Line Def Code" := DataExchMapping."Data Exch. Line Def Code";
        DataExch."File Name" := CopyStr(FileName, 1, MaxStrLen(DataExch."File Name"));
        DataExch."Table Filters".CreateOutStream(TableFiltersOutStream);
        TableFiltersOutStream.WriteText(TableFilters);
        DataExch.Insert(true);
    end;

    local procedure RunExportSteps(var DataExch: Record "Data Exch."; DataExchDef: Record "Data Exch. Def"; DataExchMapping: Record "Data Exch. Mapping")
    var
        DataExchField: Record "Data Exch. Field";
        EntryNo: Integer;
        FileOutStream: OutStream;
    begin
        // The steps of Export Launcher and Data Exch.ExportFromDataExch, without the external data
        // handling (a client download) and the payment user feedback: the delivery replaces them.
        EntryNo := DataExch."Entry No.";
        if DataExchDef."Data Handling Codeunit" > 0 then
            Codeunit.Run(DataExchDef."Data Handling Codeunit", DataExchMapping);
        if DataExchDef."Validation Codeunit" > 0 then
            Codeunit.Run(DataExchDef."Validation Codeunit", DataExchMapping);
        if DataExchMapping."Pre-Mapping Codeunit" > 0 then
            Codeunit.Run(DataExchMapping."Pre-Mapping Codeunit", DataExch);
        if DataExchMapping."Mapping Codeunit" > 0 then
            Codeunit.Run(DataExchMapping."Mapping Codeunit", DataExch)
        else
            Codeunit.Run(Codeunit::"Export Mapping", DataExch);
        if DataExchMapping."Post-Mapping Codeunit" > 0 then
            Codeunit.Run(DataExchMapping."Post-Mapping Codeunit", DataExch);
        DataExch.Get(EntryNo);
        if DataExchDef."Reading/Writing Codeunit" > 0 then
            Codeunit.Run(DataExchDef."Reading/Writing Codeunit", DataExch)
        else begin
            // The same as Exp. Writing Gen. Jnl.: the XMLport writes the fields into the entry file.
            DataExch."File Content".CreateOutStream(FileOutStream);
            DataExchField.SetRange("Data Exch. No.", EntryNo);
            Xmlport.Export(DataExchDef."Reading/Writing XMLport", FileOutStream, DataExchField);
            DataExch.Modify(true);
            DataExchField.DeleteAll(true);
        end;
        DataExch.Get(EntryNo);
    end;

    local procedure ReadFileContent(var Argument: Record "Message Argument ori"; var DataExch: Record "Data Exch."; var TempBlob: Codeunit "Temp Blob")
    begin
        DataExch.CalcFields("File Content");
        if DataExch."File Content".HasValue() then begin
            TempBlob.FromRecord(DataExch, DataExch.FieldNo("File Content"));
            exit;
        end;
        Argument.AddError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(EmptyFileErr, DataExch."Data Exch. Def Code"), 'dataExchDefCode', DataExch."Data Exch. Def Code", '', EmptyFileNextStepLbl);
        Argument.RaiseCollectedErrors("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(EmptyFileErr, DataExch."Data Exch. Def Code"));
    end;

    local procedure DefaultExportFileName(DataExchDef: Record "Data Exch. Def"): Text
    var
        DataExch: Record "Data Exch.";
    begin
        DataExch."Data Exch. Def Code" := DataExchDef.Code;
        exit(DataExchDef.Code + '-' + TimeStamp() + DataExch.GetFileExtension());
    end;

    /// <summary>Returns a compact local timestamp for generated file names, such as 20261019T143005.</summary>
    /// <returns>The timestamp text.</returns>
    procedure TimeStamp(): Text
    var
        Now: DateTime;
    begin
        Now := CurrentDateTime();
        exit(Format(DT2Date(Now), 0, '<Year4><Month,2><Filler Character,0><Day,2><Filler Character,0>') + 'T' +
            Format(DT2Time(Now), 0, '<Hours24,2><Filler Character,0><Minutes,2><Filler Character,0><Seconds,2><Filler Character,0>'));
    end;

    local procedure ReadJournalName(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; var JournalName: Code[10])
    var
        Reader: Codeunit "Storage Request Reader ori";
        RawText: Text;
    begin
        Clear(JournalName);
        if not Reader.ReadMutationText(Argument, RequestJson, ParameterName, true, 10, RawText) then
            exit;
        if (RawText <> UpperCase(RawText)) or (RawText <> DelChr(RawText, '<>', ' ')) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(JournalNameErr, ParameterName), ParameterName, RawText, JournalNameExpectedLbl, JournalNameNextStepLbl);
            exit;
        end;
        JournalName := CopyStr(RawText, 1, MaxStrLen(JournalName));
    end;

    local procedure EntryIsLinked(EntryNo: Integer): Boolean
    var
        EntryLink: Record "DataExch Entry Link ori";
    begin
        EntryLink.SetRange("Entry No.", EntryNo);
        exit(not EntryLink.IsEmpty());
    end;
}
