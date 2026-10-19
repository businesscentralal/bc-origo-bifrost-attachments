namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>
/// Phase 1 (#24): generic import. DataExchange.Import.Run and Storage.Upload.CommitToDataExchange
/// create a parsed Data Exch. entry; DataExchange.Entry.Process applies the mappings;
/// DataExchange.Entry.Delete removes an entry unless an incoming document uses it.
/// </summary>
codeunit 96242 "DataExch Import Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";

    [Test]
    procedure AC01_CommitToDataExchange_ParsesWithoutProcessing()
    var
        Session: Record "Storage Upload Session ori";
        Response: JsonObject;
        DataObject: JsonObject;
        DefCode: Code[20];
        UploadId: Text;
        UploadGuid: Guid;
        EntryNo: Integer;
    begin
        // [SCENARIO] AC01: a chunked upload commits into a parsed entry; nothing is processed.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        UploadId := BeginAndAppend('ac01.csv', Fixture.TwoLineCsv(false));

        Response := CommitToDataExchange(UploadId, DefCode, false, false);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'AC01 status. ' + Fixture.ReadText(Response, 'error'));
        DataObject := Fixture.Data(Response);
        EntryNo := Fixture.ReadInt(DataObject, 'entryNo');
        LibraryAssert.AreNotEqual(0, EntryNo, 'AC01 returns the entry.');
        LibraryAssert.AreEqual(DefCode, Fixture.ReadText(DataObject, 'dataExchDefCode'), 'AC01 definition.');
        LibraryAssert.AreEqual(2, Fixture.ReadInt(DataObject, 'lineCount'), 'AC01 two lines.');
        LibraryAssert.AreEqual(6, Fixture.ReadInt(DataObject, 'fieldCount'), 'AC01 fieldCount = rows x columns.');
        LibraryAssert.IsFalse(Fixture.ReadBool(DataObject, 'processed'), 'AC01 processed is false.');
        LibraryAssert.AreEqual(0, Fixture.TargetCount(EntryNo), 'AC01 writes no target rows.');
        Evaluate(UploadGuid, UploadId);
        Session.Get(UploadGuid);
        LibraryAssert.AreEqual(Session.Status::Committed, Session.Status, 'AC01 commits the session.');
        AssertEntryFields(EntryNo, 6);
    end;

    [Test]
    procedure AC01_CommitToDataExchange_KeepFileWritesSessionPath()
    var
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
        DataObject: JsonObject;
        DefCode: Code[20];
        UploadId: Text;
    begin
        // [SCENARIO] AC01 / A2: keepFileInStorage also writes the assembled file to the session path.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        UploadId := BeginAndAppend('keep.csv', Fixture.TwoLineCsv(false));

        Response := CommitToDataExchange(UploadId, DefCode, false, true);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Keep status. ' + Fixture.ReadText(Response, 'error'));
        DataObject := Fixture.Data(Response);
        LibraryAssert.AreEqual('bifrost-uploads/keep.csv', Fixture.ReadText(DataObject, 'path'), 'Keep returns the session path.');
        LibraryAssert.IsTrue(MockState.HasFile('bifrost-uploads/keep.csv'), 'Keep writes the file.');
        LibraryAssert.AreEqual(Fixture.TwoLineCsv(false), Fixture.Decode(MockState.GetFileContent('bifrost-uploads/keep.csv')), 'Keep writes the exact bytes.');
    end;

    [Test]
    procedure AC02_ImportRun_ProcessTrue_InsertsTargets()
    var
        Target: Record "DataExch Test Target ori";
        Response: JsonObject;
        ProcessResult: JsonObject;
        Targets: JsonArray;
        TargetToken: JsonToken;
        DefCode: Code[20];
        EntryNo: Integer;
    begin
        // [SCENARIO] AC02: process true applies the mappings and lists the written records.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(1);

        Response := ImportInline(DefCode, Fixture.TwoLineCsv(true), true);

        LibraryAssert.AreEqual('Accepted', Fixture.ReadText(Response, 'status'), 'AC02 status. ' + Fixture.ReadText(Response, 'error'));
        EntryNo := Fixture.ReadInt(Response, 'entryNo');
        LibraryAssert.AreEqual(6, Fixture.ReadInt(Response, 'fieldCount'), 'AC02 header line is skipped.');
        LibraryAssert.IsTrue(Fixture.ReadBool(Response, 'processed'), 'AC02 processed. ' + Format(Fixture.ReadObject(Response, 'processResult')));
        ProcessResult := Fixture.ReadObject(Response, 'processResult');
        Targets := Fixture.ReadArray(ProcessResult, 'targets');
        LibraryAssert.AreEqual(1, Targets.Count(), 'AC02 one target table.');
        Targets.Get(0, TargetToken);
        LibraryAssert.AreEqual(Database::"DataExch Test Target ori", Fixture.ReadInt(TargetToken.AsObject(), 'tableId'), 'AC02 target table.');
        LibraryAssert.AreEqual(2, Fixture.ReadInt(TargetToken.AsObject(), 'recordsInserted'), 'AC02 two records inserted.');
        LibraryAssert.AreEqual(2, Fixture.ReadArray(TargetToken.AsObject(), 'recordIds').Count(), 'AC02 two record ids.');
        Target.SetRange("Data Exch. No.", EntryNo);
        LibraryAssert.AreEqual(2, Target.Count(), 'AC02 rows exist.');
        Target.SetRange(Code, 'A1');
        Target.FindFirst();
        LibraryAssert.AreEqual('Alpha', Target.Name, 'AC02 name mapped.');
        LibraryAssert.AreEqual(10.5, Target.Amount, 'AC02 amount mapped.');
    end;

    [Test]
    procedure AC03_ImportRunFromStorage_LeavesFileUntouched()
    var
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
        Request: JsonObject;
        DefCode: Code[20];
        Content: Text;
    begin
        // [SCENARIO] AC03: Import.Run reads a stored file; the file stays unchanged.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Content := Fixture.Encode(Fixture.TwoLineCsv(false));
        MockState.PutFile('in/ac03.csv', Content);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'in/ac03.csv');

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Import.Run", Request);

        LibraryAssert.AreEqual('Accepted', Fixture.ReadText(Response, 'status'), 'AC03 status. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.AreEqual(6, Fixture.ReadInt(Response, 'fieldCount'), 'AC03 fieldCount.');
        LibraryAssert.AreEqual('ac03.csv', Fixture.ReadText(Response, 'fileName'), 'AC03 file name from the path.');
        LibraryAssert.AreEqual('in/ac03.csv', Fixture.ReadText(Response, 'path'), 'AC03 echoes the path.');
        LibraryAssert.IsFalse(Fixture.ReadBool(Response, 'processed'), 'AC03 not processed.');
        LibraryAssert.AreEqual(Content, MockState.GetFileContent('in/ac03.csv'), 'AC03 file untouched.');
        AssertEntryFields(Fixture.ReadInt(Response, 'entryNo'), 6);
    end;

    [Test]
    procedure AC03_ImportRunMissingStoredFile_AnswersError()
    var
        Response: JsonObject;
        Request: JsonObject;
        DefCode: Code[20];
        BeforeCount: Integer;
    begin
        // [SCENARIO] AC03 edge: a path that does not exist answers an error and writes nothing.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        BeforeCount := EntryCount(DefCode);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'in/missing.csv');

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Import.Run", Request);

        LibraryAssert.AreEqual('Error', Fixture.ReadText(Response, 'status'), 'Missing file status.');
        LibraryAssert.AreEqual(BeforeCount, EntryCount(DefCode), 'Missing file writes no entry.');
    end;

    [Test]
    procedure AC04_BankStatementDefinition_PointsToBankReconciliation()
    var
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] AC04: a Bank Statement Import definition is refused with a pointer to Finance.BankReconciliation.Create.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateBareDefinition("Data Exchange Definition Type"::"Bank Statement Import");

        Response := ImportInline(DefCode, Fixture.TwoLineCsv(false), false);

        Fixture.AssertRefusal(Response, 'InvalidParameter', 'dataExchDefCode');
        LibraryAssert.IsTrue(Fixture.ReadText(Response, 'nextStep').Contains('Finance.BankReconciliation.Create'), 'AC04 names Finance.BankReconciliation.Create.');
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'AC04 writes nothing.');
    end;

    [Test]
    procedure AC04_ExportDefinition_IsRefusedForImport()
    var
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] AC04: an export definition cannot import a file.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateExportDefinition();

        Response := ImportInline(DefCode, Fixture.TwoLineCsv(false), false);

        Fixture.AssertRefusal(Response, 'InvalidParameter', 'dataExchDefCode');
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'Export definition writes nothing.');
    end;

    [Test]
    procedure AC05_MalformedFile_LeavesNoHalfParsedEntry()
    var
        DataExchField: Record "Data Exch. Field";
        DefCode: Code[20];
        FieldsBefore: Integer;
    begin
        // [SCENARIO] AC05: a file the reader refuses (only a header line) rolls back the entry and every parsed field.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(1);
        FieldsBefore := DataExchField.Count();

        asserterror ImportInline(DefCode, 'code,name,amount', false);

        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'AC05 leaves no entry.');
        LibraryAssert.AreEqual(FieldsBefore, DataExchField.Count(), 'AC05 leaves no parsed field.');
    end;

    [Test]
    procedure AC05_MalformedUpload_KeepsSessionOpen()
    var
        Session: Record "Storage Upload Session ori";
        DefCode: Code[20];
        UploadId: Text;
        UploadGuid: Guid;
    begin
        // [SCENARIO] AC05: a malformed upload rolls back; the session stays open with its chunks for a retry.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(1);
        UploadId := BeginAndAppend('bad.csv', 'code,name,amount');

        asserterror CommitToDataExchange(UploadId, DefCode, false, false);

        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'AC05 upload leaves no entry.');
        Evaluate(UploadGuid, UploadId);
        Session.Get(UploadGuid);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'AC05 session stays open.');
        LibraryAssert.AreEqual(1, Session."Chunk Count", 'AC05 chunks stay.');
    end;

    [Test]
    procedure AC06_EntryDelete_RefusedForIncomingDocument()
    var
        DataExch: Record "Data Exch.";
        IncomingDocument: Record "Incoming Document";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        EntryNo: Integer;
    begin
        // [SCENARIO] AC06: an entry that an incoming document uses cannot be deleted.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        EntryNo := Fixture.ReadInt(ImportInline(DefCode, Fixture.TwoLineCsv(false), false), 'entryNo');
        DataExch.Get(EntryNo);
        DataExch."Incoming Entry No." := IncomingDocument.CreateIncomingDocument('DXI AC06', '');
        DataExch.Modify();
        Request.Add('entryNo', EntryNo);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Delete", Request);

        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'entryNo');
        LibraryAssert.IsTrue(DataExch.Get(EntryNo), 'AC06 entry stays.');
        AssertEntryFields(EntryNo, 6);
    end;

    [Test]
    procedure EntryDelete_RemovesEntryFieldsAndMarker()
    var
        DataExch: Record "Data Exch.";
        EntryLink: Record "DataExch Entry Link ori";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        EntryNo: Integer;
    begin
        // [SCENARIO] Entry.Delete removes the entry, its parsed fields and the Bifröst marker.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        EntryNo := Fixture.ReadInt(ImportInline(DefCode, Fixture.TwoLineCsv(false), false), 'entryNo');
        LibraryAssert.IsTrue(EntryLink.Get(EntryNo), 'The import marks the entry as created by Bifröst.');
        Request.Add('entryNo', EntryNo);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Delete", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Delete status. ' + Fixture.ReadText(Response, 'error'));
        LibraryAssert.AreEqual(6, Fixture.ReadInt(Fixture.Data(Response), 'deletedFieldCount'), 'Delete reports the fields.');
        LibraryAssert.IsFalse(DataExch.Get(EntryNo), 'Entry deleted.');
        LibraryAssert.IsFalse(EntryLink.Get(EntryNo), 'Marker deleted.');
        AssertEntryFields(EntryNo, 0);
    end;

    [Test]
    procedure EntryDelete_UnknownEntry_RecordNotFound()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] Entry.Delete refuses an entry number that does not exist.
        Request.Add('entryNo', 2147483000);
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Delete", Request), 'RecordNotFound', 'entryNo');
    end;

    [Test]
    procedure EntryProcess_WritesTargets_ThenRefusesSecondRun()
    var
        Request: JsonObject;
        Response: JsonObject;
        DataObject: JsonObject;
        TargetToken: JsonToken;
        DefCode: Code[20];
        EntryNo: Integer;
    begin
        // [SCENARIO] Entry.Process applies the mappings once; a second run is refused so nothing is written twice.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        EntryNo := Fixture.ReadInt(ImportInline(DefCode, Fixture.TwoLineCsv(false), false), 'entryNo');
        Request.Add('entryNo', EntryNo);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request);

        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Process status. ' + Fixture.ReadText(Response, 'error'));
        DataObject := Fixture.Data(Response);
        LibraryAssert.IsTrue(Fixture.ReadBool(DataObject, 'processed'), 'Processed.');
        Fixture.ReadArray(DataObject, 'targets').Get(0, TargetToken);
        LibraryAssert.AreEqual(2, Fixture.ReadInt(TargetToken.AsObject(), 'recordsInserted'), 'Two records inserted.');
        LibraryAssert.AreEqual(2, Fixture.TargetCount(EntryNo), 'Rows exist.');

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request);
        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'entryNo');
        LibraryAssert.AreEqual(2, Fixture.TargetCount(EntryNo), 'The second run writes nothing.');
    end;

    [Test]
    procedure EntryProcess_IntermediateMapping_PointsToIncomingDocument()
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        EntryNo: Integer;
    begin
        // [SCENARIO] An intermediate-table mapping is refused and points to the incoming document path.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Fixture.UseIntermediateTable(DefCode);
        EntryNo := Fixture.ReadInt(ImportInline(DefCode, Fixture.TwoLineCsv(false), false), 'entryNo');
        Request.Add('entryNo', EntryNo);

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request);

        Fixture.AssertRefusal(Response, 'PreconditionFailed', 'entryNo');
        LibraryAssert.IsTrue(Fixture.ReadText(Response, 'nextStep').Contains('Storage.Upload.CommitToRecord'), 'Points to CommitToRecord.');
        LibraryAssert.AreEqual(0, Fixture.TargetCount(EntryNo), 'Nothing is written.');
    end;

    [Test]
    procedure ImportRun_ProcessTrueWithIntermediateMapping_KeepsEntry()
    var
        Response: JsonObject;
        ProcessResult: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] process true with a blocked mapping keeps the imported entry and reports the error in processResult.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Fixture.UseIntermediateTable(DefCode);

        Response := ImportInline(DefCode, Fixture.TwoLineCsv(false), true);

        LibraryAssert.AreEqual('Accepted', Fixture.ReadText(Response, 'status'), 'The import succeeds.');
        LibraryAssert.IsFalse(Fixture.ReadBool(Response, 'processed'), 'Not processed.');
        ProcessResult := Fixture.ReadObject(Response, 'processResult');
        LibraryAssert.AreEqual(1, Fixture.ReadArray(ProcessResult, 'errors').Count(), 'One processing error.');
        LibraryAssert.AreEqual(1, EntryCount(DefCode), 'The entry stays.');
    end;

    [Test]
    procedure EntryProcess_InvalidInput_RefusedBeforeWrite()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] Entry.Process refuses a missing, zero and unknown entry number.
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request), 'MissingParameter', 'entryNo');
        Request.Add('entryNo', 0);
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request), 'InvalidParameter', 'entryNo');
        Clear(Request);
        Request.Add('entryNo', 2147483000);
        Fixture.AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request), 'RecordNotFound', 'entryNo');
    end;

    [Test]
    procedure ImportRun_InlineOverOneMegabyte_LimitExceeded()
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] Inline content over 1 MB is refused with a pointer to storage.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('contentBase64', Fixture.Encode(PadStr('', 1100000, 'A')));

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Import.Run", Request);

        Fixture.AssertRefusal(Response, 'LimitExceeded', 'contentBase64');
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'Nothing is written.');
    end;

    [Test]
    procedure ImportRun_TwoSources_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [SCENARIO] contentBase64 together with storageCode and path is refused.
        Fixture.InitializeStorage();
        DefCode := Fixture.CreateImportDefinition(0);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('contentBase64', Fixture.Encode(Fixture.TwoLineCsv(false)));
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'in/x.csv');

        Response := Fixture.Dispatch("Message Type ori"::"DataExchange.Import.Run", Request);

        Fixture.AssertRefusal(Response, 'InvalidParameter', 'contentBase64');
        LibraryAssert.AreEqual(0, EntryCount(DefCode), 'Nothing is written.');
    end;

    [Test]
    procedure CommitToDataExchange_UnknownDefinition_SessionStaysOpen()
    var
        Session: Record "Storage Upload Session ori";
        Response: JsonObject;
        UploadId: Text;
        UploadGuid: Guid;
    begin
        // [SCENARIO] An unknown definition is refused before any write; the session stays open.
        Fixture.InitializeStorage();
        UploadId := BeginAndAppend('x.csv', Fixture.TwoLineCsv(false));

        Response := CommitToDataExchange(UploadId, 'DXNOSUCHDEF', false, false);

        Fixture.AssertRefusal(Response, 'RecordNotFound', 'dataExchDefCode');
        Evaluate(UploadGuid, UploadId);
        Session.Get(UploadGuid);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'Session stays open.');
    end;

    local procedure ImportInline(DefCode: Code[20]; Content: Text; Process: Boolean): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('contentBase64', Fixture.Encode(Content));
        Request.Add('fileName', 'inline.csv');
        if Process then
            Request.Add('process', true);
        exit(Fixture.Dispatch("Message Type ori"::"DataExchange.Import.Run", Request));
    end;

    local procedure BeginAndAppend(FileName: Text; Content: Text) UploadId: Text
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('fileName', FileName);
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Begin", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Begin succeeds.');
        UploadId := Fixture.ReadText(Fixture.Data(Response), 'uploadId');
        Clear(Request);
        Request.Add('uploadId', UploadId);
        Request.Add('sequence', 1);
        Request.Add('contentBase64', Fixture.Encode(Content));
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Append", Request);
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Append succeeds.');
    end;

    local procedure CommitToDataExchange(UploadId: Text; DefCode: Code[20]; Process: Boolean; KeepFile: Boolean): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('uploadId', UploadId);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('process', Process);
        Request.Add('keepFileInStorage', KeepFile);
        exit(Fixture.Dispatch("Message Type ori"::"Storage.Upload.CommitToDataExchange", Request));
    end;

    local procedure EntryCount(DefCode: Code[20]): Integer
    var
        DataExch: Record "Data Exch.";
    begin
        DataExch.SetRange("Data Exch. Def Code", DefCode);
        exit(DataExch.Count());
    end;

    local procedure AssertEntryFields(EntryNo: Integer; Expected: Integer)
    var
        DataExchField: Record "Data Exch. Field";
    begin
        DataExchField.SetRange("Data Exch. No.", EntryNo);
        LibraryAssert.AreEqual(Expected, DataExchField.Count(), 'Parsed field count of the entry.');
    end;
}
