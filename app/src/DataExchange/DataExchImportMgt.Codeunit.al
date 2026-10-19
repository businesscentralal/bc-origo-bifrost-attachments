namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using System.IO;
using System.Utilities;

/// <summary>
/// The import engine behind <c>DataExchange.Import.Run</c>, <c>Storage.Upload.CommitToDataExchange</c>
/// and <c>DataExchange.Entry.Process</c>. It checks import definitions, inserts a <c>Data Exch.</c>
/// entry with the file content, runs the definition's reader so the <c>Data Exch. Field</c> rows are
/// parsed, and applies the definition's mappings. The import and the processing are separate steps,
/// so a caller can inspect the parsed fields before anything is written to business tables.
/// </summary>
/// <remarks>
/// The reader and the mapping codeunits run in the caller's transaction: an error from them rolls
/// back everything this engine wrote in that call, so a malformed file never leaves a half-parsed
/// entry behind. Only <see cref="ProcessIsolated"/> commits first, because a failed processing must
/// keep the imported entry for inspection.
/// </remarks>
codeunit 70013501 "DataExch Import Mgt ori"
{
    Access = Internal;

    var
        DefinitionNotFoundErr: Label 'Data Exchange definition %1 was not found.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 fannst ekki.';
        ImportTypeErr: Label 'Data Exchange definition %1 is not an import definition. Only Generic Import and Payroll Import definitions can be imported.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 er ekki innflutningsskilgreining. Aðeins er hægt að flytja inn með skilgreiningum fyrir almennan innflutning (Generic Import) og launainnflutning (Payroll Import).';
        BankStatementErr: Label 'Data Exchange definition %1 is a Bank Statement Import definition. Bank statements are imported into a bank account reconciliation, not into a generic entry.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 er skilgreining fyrir innflutning bankayfirlita (Bank Statement Import). Bankayfirlit eru flutt inn í afstemmingu bankareiknings, ekki í almenna færslu.';
        BankStatementNextStepLbl: Label 'Import the bank statement with Finance.BankReconciliation.Create.', Comment = 'is-IS=Flyttu bankayfirlitið inn með Finance.BankReconciliation.Create.';
        ImportDefinitionExpectedLbl: Label 'an existing Generic Import or Payroll Import definition', Comment = 'is-IS=fyrirliggjandi skilgreining fyrir almennan innflutning (Generic Import) eða launainnflutning (Payroll Import)';
        SelectImportDefinitionLbl: Label 'Call DataExchange.Definition.List with direction Import and use the exact code of a Generic Import or Payroll Import definition.', Comment = 'is-IS=Kallaðu á DataExchange.Definition.List með direction Import og notaðu nákvæman kóða skilgreiningar fyrir almennan innflutning (Generic Import) eða launainnflutning (Payroll Import).';
        NoReaderErr: Label 'Data Exchange definition %1 has neither a reading XMLport nor a reading codeunit, so a file cannot be read with it.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 hefur hvorki XMLport né kóðaeiningu til lestrar og því er ekki hægt að lesa skrá með henni.';
        ReaderExpectedLbl: Label 'a definition with a Reading/Writing XMLport or Reading/Writing Codeunit', Comment = 'is-IS=skilgreining með XMLport eða kóðaeiningu til lestrar og skriftar';
        CompleteDefinitionLbl: Label 'Complete the definition, for example by installing it with DataExchange.Definition.Import, and retry.', Comment = 'is-IS=Ljúktu við skilgreininguna, til dæmis með því að setja hana upp með DataExchange.Definition.Import, og reyndu aftur.';
        InlineTooLargeErr: Label 'Parameter "%1" carries %2 bytes; inline content may be at most %3 bytes (1 MB).', Comment = '%1 = parameter, %2 = size in bytes, %3 = limit in bytes||is-IS=Færibreytan "%1" ber %2 bæti; innfellt innihald má mest vera %3 bæti (1 MB).';
        InlineLimitExpectedLbl: Label 'at most 1048576 bytes', Comment = 'is-IS=í mesta lagi 1048576 bæti';
        UseStorageSourceLbl: Label 'Put the file in storage with Storage.File.Create or a chunked upload, then send storageCode and path, or use Storage.Upload.CommitToDataExchange.', Comment = 'is-IS=Settu skrána í geymslu með Storage.File.Create eða upphleðslu í bútum og sendu svo storageCode og path, eða notaðu Storage.Upload.CommitToDataExchange.';
        NoMappingErr: Label 'Data Exchange definition %1 has no mapping for line definition %2.', Comment = '%1 = definition code, %2 = line definition code||is-IS=Skilgreining gagnaskipta %1 hefur enga vörpun fyrir línuskilgreiningu %2.';
        NoMappingsErr: Label 'Data Exchange definition %1 has no mappings, so the entry cannot be processed.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 hefur engar varpanir og því er ekki hægt að vinna færsluna.';
        MappingExpectedLbl: Label 'a definition with a Data Exch. Mapping to a target table', Comment = 'is-IS=skilgreining með gagnaskiptavörpun í marktöflu';
        AddMappingLbl: Label 'Add a mapping to the definition, or call DataExchange.Definition.Get to see the line definitions that have one.', Comment = 'is-IS=Bættu vörpun við skilgreininguna eða kallaðu á DataExchange.Definition.Get til að sjá hvaða línuskilgreiningar hafa vörpun.';
        IntermediateErr: Label 'Data Exchange definition %1 maps to the intermediate table. Intermediate data is turned into documents only through an incoming document.', Comment = '%1 = definition code||is-IS=Skilgreining gagnaskipta %1 varpar í millitöfluna. Gögnum í millitöflu er aðeins breytt í skjöl í gegnum innkomuskjal.';
        IntermediateNextStepLbl: Label 'Wire the definition to a Data Exchange Type with DataExchange.Type.Set, then send the file with Storage.Upload.CommitToRecord (target IncomingDocument, dataExchangeType, process true).', Comment = 'is-IS=Tengdu skilgreininguna við gerð gagnaskipta með DataExchange.Type.Set og sendu svo skrána með Storage.Upload.CommitToRecord (target IncomingDocument, dataExchangeType, process true).';
        DirectMappingExpectedLbl: Label 'a definition that maps directly to a business table', Comment = 'is-IS=skilgreining sem varpar beint í viðskiptatöflu';
        TargetPermissionErr: Label 'You do not have permission to write table %1 (%2), which the mapping of definition %3 writes to.', Comment = '%1 = table id, %2 = table name, %3 = definition code||is-IS=Þú hefur ekki heimild til að skrifa í töflu %1 (%2) sem vörpun skilgreiningar %3 skrifar í.';
        TargetPermissionExpectedLbl: Label 'read and write permission on the target table', Comment = 'is-IS=les- og skrifheimild á marktöflunni';
        TargetPermissionNextStepLbl: Label 'Ask an administrator for permission on the target table, then process the entry again.', Comment = 'is-IS=Biddu kerfisstjóra um heimild á marktöflunni og vinndu svo færsluna aftur.';
        NoMappingCodeunitWarningLbl: Label 'The mapping of line definition %1 to table %2 has no mapping codeunit, so nothing is written for it.', Comment = '%1 = line definition code, %2 = table id||is-IS=Vörpun línuskilgreiningar %1 í töflu %2 hefur enga vörpunarkóðaeiningu og því er ekkert skrifað fyrir hana.';
        RecordIdsCappedWarningLbl: Label 'Table %1 received %2 new records; recordIds lists the first %3.', Comment = '%1 = table id, %2 = record count, %3 = cap||is-IS=Tafla %1 fékk %2 nýjar færslur; recordIds sýnir fyrstu %3.';
        ProcessFailedNextStepLbl: Label 'Read the parsed fields with DataExchange.Entry.Get, correct the file or the definition, and process the entry again with DataExchange.Entry.Process.', Comment = 'is-IS=Lestu þáttuðu reitina með DataExchange.Entry.Get, leiðréttu skrána eða skilgreininguna og vinndu færsluna aftur með DataExchange.Entry.Process.';

    /// <summary>Checks that a definition exists and can import a file, and collects every problem on the argument.</summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="DefCode">The definition code.</param>
    /// <param name="ParameterName">The request parameter that carried the code.</param>
    /// <returns>True when the definition is a usable import definition.</returns>
    procedure CheckImportDefinition(var Argument: Record "Message Argument ori"; DefCode: Code[20]; ParameterName: Text): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchDef.SetLoadFields(Code, Type);
        if not DataExchDef.Get(DefCode) then begin
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(DefinitionNotFoundErr, DefCode), ParameterName, DefCode, ImportDefinitionExpectedLbl, SelectImportDefinitionLbl);
            exit(false);
        end;
        if DataExchDef.Type = DataExchDef.Type::"Bank Statement Import" then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(BankStatementErr, DefCode), ParameterName, DefCode, ImportDefinitionExpectedLbl, BankStatementNextStepLbl);
            exit(false);
        end;
        if not (DataExchDef.Type in [DataExchDef.Type::"Generic Import", DataExchDef.Type::"Payroll Import"]) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ImportTypeErr, DefCode), ParameterName, DefCode, ImportDefinitionExpectedLbl, SelectImportDefinitionLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Checks that an import definition has a reader; call it after the permission checks.</summary>
    /// <param name="Argument">The message argument that collects the problem.</param>
    /// <param name="DefCode">The definition code, already checked with <see cref="CheckImportDefinition"/>.</param>
    /// <param name="ParameterName">The request parameter that carried the code.</param>
    /// <returns>True when the definition can read a file.</returns>
    procedure CheckReader(var Argument: Record "Message Argument ori"; DefCode: Code[20]; ParameterName: Text): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchDef.SetLoadFields(Code, "Reading/Writing XMLport", "Reading/Writing Codeunit");
        DataExchDef.Get(DefCode);
        if (DataExchDef."Reading/Writing XMLport" <> 0) or (DataExchDef."Reading/Writing Codeunit" <> 0) then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoReaderErr, DefCode), ParameterName, DefCode, ReaderExpectedLbl, CompleteDefinitionLbl);
        exit(false);
    end;

    /// <summary>The most bytes a request may carry inline or receive inline: 1 MB (decision D4).</summary>
    /// <returns>1,048,576.</returns>
    procedure MaxInlineBytes(): Integer
    begin
        exit(1048576);
    end;

    /// <summary>Adds <c>LimitExceeded</c> when inline content is larger than 1 MB.</summary>
    /// <param name="Argument">The message argument that collects the problem.</param>
    /// <param name="ParameterName">The parameter that carried the content.</param>
    /// <param name="ContentLength">The decoded content size in bytes.</param>
    /// <returns>True when the content fits.</returns>
    procedure CheckInlineSize(var Argument: Record "Message Argument ori"; ParameterName: Text; ContentLength: BigInteger): Boolean
    begin
        if ContentLength <= MaxInlineBytes() then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::LimitExceeded, StrSubstNo(InlineTooLargeErr, ParameterName, Format(ContentLength, 0, 9), Format(MaxInlineBytes(), 0, 9)),
            ParameterName, Format(ContentLength, 0, 9), InlineLimitExpectedLbl, UseStorageSourceLbl);
        exit(false);
    end;

    /// <summary>
    /// Inserts a <c>Data Exch.</c> entry with the file content, marks it as created by Bifröst and runs
    /// the definition's reader. A reader error is raised and rolls back the entry and every parsed field.
    /// </summary>
    /// <param name="DefCode">The import definition, already checked with <see cref="CheckImportDefinition"/>.</param>
    /// <param name="FileName">The file name stored on the entry.</param>
    /// <param name="TempBlob">The file content.</param>
    /// <param name="UploadId">The upload session the file came from, or a null GUID.</param>
    /// <param name="MessageTypeName">The message type that creates the entry.</param>
    /// <param name="StorageCode">The storage connection the file came from, or empty.</param>
    /// <param name="Path">The storage path the file came from, or empty.</param>
    /// <param name="DataExch">Returns the new entry.</param>
    procedure ImportFile(DefCode: Code[20]; FileName: Text; var TempBlob: Codeunit "Temp Blob"; UploadId: Guid; MessageTypeName: Text; StorageCode: Code[20]; Path: Text; var DataExch: Record "Data Exch.")
    var
        DataExchDef: Record "Data Exch. Def";
        DataExchLineDef: Record "Data Exch. Line Def";
        EntryNo: Integer;
    begin
        DataExchDef.Get(DefCode);
        DataExchLineDef.SetLoadFields("Data Exch. Def Code", Code);
        DataExchLineDef.SetRange("Data Exch. Def Code", DefCode);
        if DataExchLineDef.FindFirst() then;

        DataExch.Init();
        DataExch."File Name" := CopyStr(FileName, 1, MaxStrLen(DataExch."File Name"));
        DataExch."Data Exch. Def Code" := DefCode;
        DataExch."Data Exch. Line Def Code" := DataExchLineDef.Code;
        DataExch.SetFileContentFromBlob(TempBlob);
        DataExch.Insert(true);
        EntryNo := DataExch."Entry No.";
        InsertLink(EntryNo, UploadId, MessageTypeName, StorageCode, Path);

        DataExch.ImportToDataExch(DataExchDef);
        DataExch.Reset();
        DataExch.Get(EntryNo);
    end;

    /// <summary>Marks an entry as created by a Bifröst message type, so the retention policy covers it.</summary>
    /// <param name="EntryNo">The Data Exch. entry number.</param>
    /// <param name="UploadId">The upload session the file came from, or a null GUID.</param>
    /// <param name="MessageTypeName">The message type that created the entry.</param>
    /// <param name="StorageCode">The storage connection of the file, or empty.</param>
    /// <param name="Path">The storage path of the file, or empty.</param>
    procedure InsertLink(EntryNo: Integer; UploadId: Guid; MessageTypeName: Text; StorageCode: Code[20]; Path: Text)
    var
        EntryLink: Record "DataExch Entry Link ori";
    begin
        EntryLink.Init();
        EntryLink."Entry No." := EntryNo;
        EntryLink."Upload Id" := UploadId;
        EntryLink."Message Type" := CopyStr(MessageTypeName, 1, MaxStrLen(EntryLink."Message Type"));
        EntryLink."Storage Code" := StorageCode;
        EntryLink.Path := CopyStr(Path, 1, MaxStrLen(EntryLink.Path));
        EntryLink.Insert(true);
    end;

    /// <summary>Adds the import result of an entry to a response object.</summary>
    /// <param name="DataExch">The imported entry.</param>
    /// <param name="Result">The response object that receives entryNo, dataExchDefCode, fileName, lineCount and fieldCount.</param>
    procedure AddImportResult(DataExch: Record "Data Exch."; var Result: JsonObject)
    begin
        Result.Add('entryNo', DataExch."Entry No.");
        Result.Add('dataExchDefCode', DataExch."Data Exch. Def Code");
        Result.Add('fileName', DataExch."File Name");
        Result.Add('lineCount', LineCount(DataExch."Entry No."));
        Result.Add('fieldCount', FieldCount(DataExch."Entry No."));
    end;

    /// <summary>Counts the distinct parsed lines of an entry.</summary>
    /// <param name="EntryNo">The entry number.</param>
    /// <returns>The number of distinct line numbers.</returns>
    procedure LineCount(EntryNo: Integer) Lines: Integer
    var
        DataExchField: Record "Data Exch. Field";
        LastLineDef: Code[20];
        LastLineNo: Integer;
    begin
        DataExchField.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchField.SetLoadFields("Data Exch. No.", "Line No.", "Data Exch. Line Def Code");
        DataExchField.SetRange("Data Exch. No.", EntryNo);
        LastLineNo := -1;
        LastLineDef := '';
        if DataExchField.FindSet() then
            repeat
                if (DataExchField."Line No." <> LastLineNo) or (DataExchField."Data Exch. Line Def Code" <> LastLineDef) then begin
                    Lines += 1;
                    LastLineNo := DataExchField."Line No.";
                    LastLineDef := DataExchField."Data Exch. Line Def Code";
                end;
            until DataExchField.Next() = 0;
    end;

    /// <summary>Counts the parsed fields of an entry.</summary>
    /// <param name="EntryNo">The entry number.</param>
    /// <returns>The number of Data Exch. Field rows.</returns>
    procedure FieldCount(EntryNo: Integer): Integer
    var
        DataExchField: Record "Data Exch. Field";
    begin
        DataExchField.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchField.SetRange("Data Exch. No.", EntryNo);
        exit(DataExchField.Count());
    end;

    /// <summary>
    /// Finds why an entry cannot be processed: no mapping, an intermediate-table mapping (the incoming
    /// document path) or a target table the caller cannot write. Nothing is changed.
    /// </summary>
    /// <param name="DataExch">The entry.</param>
    /// <param name="LineDefCode">An optional line definition to process alone.</param>
    /// <param name="ErrorCode">Returns the error code of the blocker.</param>
    /// <param name="ErrorText">Returns the error text.</param>
    /// <param name="Expected">Returns what was expected.</param>
    /// <param name="NextStep">Returns the next step.</param>
    /// <returns>True when a blocker was found.</returns>
    procedure FindProcessBlocker(DataExch: Record "Data Exch."; LineDefCode: Code[20]; var ErrorCode: Enum "Bifrost Error Code ori"; var ErrorText: Text; var Expected: Text; var NextStep: Text): Boolean
    var
        DataExchMapping: Record "Data Exch. Mapping";
        TargetRef: RecordRef;
    begin
        DataExchMapping.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchMapping.SetLoadFields("Data Exch. Def Code", "Data Exch. Line Def Code", "Table ID", "Use as Intermediate Table");
        DataExchMapping.SetRange("Data Exch. Def Code", DataExch."Data Exch. Def Code");
        if LineDefCode <> '' then
            DataExchMapping.SetRange("Data Exch. Line Def Code", LineDefCode);
        if DataExchMapping.IsEmpty() then begin
            ErrorCode := "Bifrost Error Code ori"::PreconditionFailed;
            if LineDefCode <> '' then
                ErrorText := StrSubstNo(NoMappingErr, DataExch."Data Exch. Def Code", LineDefCode)
            else
                ErrorText := StrSubstNo(NoMappingsErr, DataExch."Data Exch. Def Code");
            Expected := MappingExpectedLbl;
            NextStep := AddMappingLbl;
            exit(true);
        end;
        DataExchMapping.FindSet();
        repeat
            if DataExchMapping."Use as Intermediate Table" then begin
                ErrorCode := "Bifrost Error Code ori"::PreconditionFailed;
                ErrorText := StrSubstNo(IntermediateErr, DataExch."Data Exch. Def Code");
                Expected := DirectMappingExpectedLbl;
                NextStep := IntermediateNextStepLbl;
                exit(true);
            end;
            TargetRef.Open(DataExchMapping."Table ID");
            if not (TargetRef.ReadPermission() and TargetRef.WritePermission()) then begin
                ErrorCode := "Bifrost Error Code ori"::PermissionDenied;
                ErrorText := StrSubstNo(TargetPermissionErr, DataExchMapping."Table ID", TargetRef.Name(), DataExch."Data Exch. Def Code");
                Expected := TargetPermissionExpectedLbl;
                NextStep := TargetPermissionNextStepLbl;
                TargetRef.Close();
                exit(true);
            end;
            TargetRef.Close();
        until DataExchMapping.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// Applies the mappings of the entry's definition, as the base application's Process Data Exch.
    /// step does. Without a line definition the definition's own <c>ProcessDataExchange</c> runs; with
    /// one only that line definition's mappings run. Errors are raised.
    /// </summary>
    /// <param name="DataExch">The entry.</param>
    /// <param name="LineDefCode">An optional line definition to process alone.</param>
    procedure RunMappings(var DataExch: Record "Data Exch."; LineDefCode: Code[20])
    var
        DataExchDef: Record "Data Exch. Def";
        DataExchMapping: Record "Data Exch. Mapping";
    begin
        DataExchDef.Get(DataExch."Data Exch. Def Code");
        if LineDefCode = '' then begin
            DataExchDef.ProcessDataExchange(DataExch);
            exit;
        end;
        if DataExchDef."Data Handling Codeunit" <> 0 then
            Codeunit.Run(DataExchDef."Data Handling Codeunit", DataExch);
        DataExchMapping.SetRange("Data Exch. Def Code", DataExch."Data Exch. Def Code");
        DataExchMapping.SetRange("Data Exch. Line Def Code", LineDefCode);
        DataExchMapping.FindSet();
        repeat
            if DataExchMapping."Pre-Mapping Codeunit" <> 0 then
                Codeunit.Run(DataExchMapping."Pre-Mapping Codeunit", DataExch);
            if DataExchMapping."Mapping Codeunit" <> 0 then
                Codeunit.Run(DataExchMapping."Mapping Codeunit", DataExch);
            if DataExchMapping."Post-Mapping Codeunit" <> 0 then
                Codeunit.Run(DataExchMapping."Post-Mapping Codeunit", DataExch);
        until DataExchMapping.Next() = 0;
    end;

    /// <summary>Records the row count of every target table of the definition before processing.</summary>
    /// <param name="DataExch">The entry.</param>
    /// <param name="LineDefCode">An optional line definition to process alone.</param>
    /// <param name="Counts">Returns table id to row count.</param>
    /// <param name="StartTime">Returns the moment the snapshot was taken.</param>
    procedure SnapshotTargets(DataExch: Record "Data Exch."; LineDefCode: Code[20]; var Counts: Dictionary of [Integer, Integer]; var StartTime: DateTime)
    var
        DataExchMapping: Record "Data Exch. Mapping";
        TargetRef: RecordRef;
    begin
        Clear(Counts);
        DataExchMapping.SetLoadFields("Data Exch. Def Code", "Data Exch. Line Def Code", "Table ID");
        DataExchMapping.SetRange("Data Exch. Def Code", DataExch."Data Exch. Def Code");
        if LineDefCode <> '' then
            DataExchMapping.SetRange("Data Exch. Line Def Code", LineDefCode);
        if DataExchMapping.FindSet() then
            repeat
                if not Counts.ContainsKey(DataExchMapping."Table ID") then begin
                    TargetRef.Open(DataExchMapping."Table ID");
                    TargetRef.ReadIsolation := IsolationLevel::ReadCommitted;
                    Counts.Add(DataExchMapping."Table ID", TargetRef.Count());
                    TargetRef.Close();
                end;
            until DataExchMapping.Next() = 0;
        StartTime := CurrentDateTime();
    end;

    /// <summary>Builds the processing result from the snapshot taken before the mappings ran.</summary>
    /// <param name="DataExch">The processed entry.</param>
    /// <param name="LineDefCode">The line definition that was processed alone, or empty.</param>
    /// <param name="Counts">The row counts taken before processing.</param>
    /// <param name="StartTime">The moment the snapshot was taken.</param>
    /// <param name="Processed">Whether the mappings ran without an error.</param>
    /// <param name="Result">Returns processed, targets and warnings.</param>
    procedure BuildProcessResult(DataExch: Record "Data Exch."; LineDefCode: Code[20]; Counts: Dictionary of [Integer, Integer]; StartTime: DateTime; Processed: Boolean; var Result: JsonObject)
    var
        DataExchMapping: Record "Data Exch. Mapping";
        Targets: JsonArray;
        Warnings: JsonArray;
        TableId: Integer;
    begin
        DataExchMapping.SetLoadFields("Data Exch. Def Code", "Data Exch. Line Def Code", "Table ID", "Mapping Codeunit", "Pre-Mapping Codeunit", "Post-Mapping Codeunit");
        DataExchMapping.SetRange("Data Exch. Def Code", DataExch."Data Exch. Def Code");
        if LineDefCode <> '' then
            DataExchMapping.SetRange("Data Exch. Line Def Code", LineDefCode);
        if DataExchMapping.FindSet() then
            repeat
                if (DataExchMapping."Mapping Codeunit" = 0) and (DataExchMapping."Pre-Mapping Codeunit" = 0) and (DataExchMapping."Post-Mapping Codeunit" = 0) then
                    Warnings.Add(StrSubstNo(NoMappingCodeunitWarningLbl, DataExchMapping."Data Exch. Line Def Code", DataExchMapping."Table ID"));
            until DataExchMapping.Next() = 0;
        if Processed then
            foreach TableId in Counts.Keys() do
                Targets.Add(TargetToJson(TableId, Counts.Get(TableId), StartTime, Warnings));
        Result.Add('processed', Processed);
        Result.Add('targets', Targets);
        Result.Add('warnings', Warnings);
    end;

    /// <summary>
    /// Commits the imported entry, then applies the mappings in an isolated codeunit run. A failure
    /// rolls back only the processing and is reported in <c>errors[]</c>; the entry stays for inspection.
    /// </summary>
    /// <param name="EntryNo">The imported entry.</param>
    /// <param name="Result">Returns processed, targets, warnings and errors.</param>
    /// <returns>True when the mappings ran without an error.</returns>
    procedure ProcessIsolated(EntryNo: Integer; var Result: JsonObject): Boolean
    var
        DataExch: Record "Data Exch.";
        Worker: Codeunit "DataExch Process Worker ori";
        Counts: Dictionary of [Integer, Integer];
        Errors: JsonArray;
        ErrorEntry: JsonObject;
        ErrorCode: Enum "Bifrost Error Code ori";
        ErrorText: Text;
        Expected: Text;
        NextStep: Text;
        StartTime: DateTime;
        Processed: Boolean;
    begin
        DataExch.Get(EntryNo);
        if FindProcessBlocker(DataExch, '', ErrorCode, ErrorText, Expected, NextStep) then begin
            AddErrorEntry(Errors, ErrorCode, ErrorText, NextStep);
            BuildProcessResult(DataExch, '', Counts, 0DT, false, Result);
            Result.Add('errors', Errors);
            exit(false);
        end;
        // The import is kept when the processing fails (D3/D5), so it is committed before the isolated run.
        Commit();
        SnapshotTargets(DataExch, '', Counts, StartTime);
        Worker.SetLineDef('');
        ClearLastError();
        Processed := Worker.Run(DataExch);
        if Processed then
            MarkProcessed(EntryNo)
        else begin
            ErrorEntry.Add('code', 'BusinessCentralError');
            ErrorEntry.Add('error', GetLastErrorText());
            ErrorEntry.Add('nextStep', ProcessFailedNextStepLbl);
            Errors.Add(ErrorEntry);
        end;
        DataExch.Get(EntryNo);
        BuildProcessResult(DataExch, '', Counts, StartTime, Processed, Result);
        Result.Add('errors', Errors);
        exit(Processed);
    end;

    /// <summary>Marks a Bifröst entry as processed.</summary>
    /// <param name="EntryNo">The entry number.</param>
    procedure MarkProcessed(EntryNo: Integer)
    var
        EntryLink: Record "DataExch Entry Link ori";
    begin
        if not EntryLink.Get(EntryNo) then
            exit;
        EntryLink.Processed := true;
        EntryLink.Modify(true);
    end;

    /// <summary>Tells whether an incoming document uses the entry.</summary>
    /// <param name="DataExch">The entry.</param>
    /// <returns>True when the entry carries an incoming document that still exists.</returns>
    procedure IsUsedByIncomingDocument(DataExch: Record "Data Exch."): Boolean
    var
        IncomingDocument: Record "Incoming Document";
    begin
        if DataExch."Incoming Entry No." = 0 then
            exit(false);
        IncomingDocument.ReadIsolation := IsolationLevel::ReadCommitted;
        IncomingDocument.SetRange("Entry No.", DataExch."Incoming Entry No.");
        exit(not IncomingDocument.IsEmpty());
    end;

    local procedure AddErrorEntry(var Errors: JsonArray; ErrorCode: Enum "Bifrost Error Code ori"; ErrorText: Text; NextStep: Text)
    var
        ErrorEntry: JsonObject;
    begin
        ErrorEntry.Add('code', ErrorCodeName(ErrorCode));
        ErrorEntry.Add('error', ErrorText);
        ErrorEntry.Add('nextStep', NextStep);
        Errors.Add(ErrorEntry);
    end;

    local procedure ErrorCodeName(ErrorCode: Enum "Bifrost Error Code ori"): Text
    var
        Ordinals: List of [Integer];
        Names: List of [Text];
        Index: Integer;
    begin
        Ordinals := ErrorCode.Ordinals();
        Names := ErrorCode.Names();
        Index := Ordinals.IndexOf(ErrorCode.AsInteger());
        if Index = 0 then
            exit('');
        exit(Names.Get(Index));
    end;

    local procedure TargetToJson(TableId: Integer; CountBefore: Integer; StartTime: DateTime; var Warnings: JsonArray) Target: JsonObject
    var
        TargetRef: RecordRef;
        CreatedAtRef: FieldRef;
        ModifiedAtRef: FieldRef;
        SystemIdRef: FieldRef;
        RecordIds: JsonArray;
        Inserted: Integer;
        Modified: Integer;
        NewRecords: Integer;
        MaxRecordIds: Integer;
        RecordSystemId: Guid;
    begin
        MaxRecordIds := 100;
        TargetRef.Open(TableId);
        TargetRef.ReadIsolation := IsolationLevel::ReadCommitted;
        Inserted := TargetRef.Count() - CountBefore;
        if Inserted < 0 then
            Inserted := 0;
        CreatedAtRef := TargetRef.Field(TargetRef.SystemCreatedAtNo());
        ModifiedAtRef := TargetRef.Field(TargetRef.SystemModifiedAtNo());
        CreatedAtRef.SetFilter('>=%1', StartTime);
        NewRecords := TargetRef.Count();
        if TargetRef.FindSet() then
            repeat
                SystemIdRef := TargetRef.Field(TargetRef.SystemIdNo());
                RecordSystemId := SystemIdRef.Value();
                RecordIds.Add(Format(RecordSystemId, 0, 4));
            until (TargetRef.Next() = 0) or (RecordIds.Count() >= MaxRecordIds);
        if NewRecords > MaxRecordIds then
            Warnings.Add(StrSubstNo(RecordIdsCappedWarningLbl, TableId, NewRecords, MaxRecordIds));
        CreatedAtRef.SetFilter('<%1', StartTime);
        ModifiedAtRef.SetFilter('>=%1', StartTime);
        Modified := TargetRef.Count();
        Target.Add('tableId', TableId);
        Target.Add('tableName', TargetRef.Name());
        Target.Add('recordsInserted', Inserted);
        Target.Add('recordsModified', Modified);
        Target.Add('recordIds', RecordIds);
        TargetRef.Close();
    end;
}
