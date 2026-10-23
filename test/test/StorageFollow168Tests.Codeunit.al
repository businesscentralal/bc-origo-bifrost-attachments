namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>Issue 168 UAT follow-ups through the public dispatcher with explicit caller LCIDs.</summary>
codeunit 96264 "Storage Follow168 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";

    /// <summary>AC1/AC2: MappingPreflight with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_MappingPreflight_1033()
    begin
        CheckMappingPreflight(1033);
    end;

    /// <summary>AC1/AC2: MappingPreflight with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_MappingPreflight_1039()
    begin
        CheckMappingPreflight(1039);
    end;

    /// <summary>AC1/AC2: ImportMapping with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_ImportMapping_1033()
    begin
        CheckImportMapping(1033);
    end;

    /// <summary>AC1/AC2: ImportMapping with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_ImportMapping_1039()
    begin
        CheckImportMapping(1039);
    end;

    /// <summary>AC1/AC2: DefinitionEntries with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_DefinitionEntries_1033()
    begin
        CheckDefinitionEntries(1033);
    end;

    /// <summary>AC1/AC2: DefinitionEntries with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_DefinitionEntries_1039()
    begin
        CheckDefinitionEntries(1039);
    end;

    /// <summary>AC1/AC2: EntityType with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_EntityType_1033()
    begin
        CheckEntityType(1033);
    end;

    /// <summary>AC1/AC2: EntityType with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_EntityType_1039()
    begin
        CheckEntityType(1039);
    end;

    /// <summary>AC1/AC2: InvalidEntity with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_InvalidEntity_1033()
    begin
        CheckInvalidEntity(1033);
    end;

    /// <summary>AC1/AC2: InvalidEntity with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_InvalidEntity_1039()
    begin
        CheckInvalidEntity(1039);
    end;

    /// <summary>AC1/AC2: FileContract with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_FileContract_1033()
    begin
        CheckFileContract(1033);
    end;

    /// <summary>AC1/AC2: FileContract with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_FileContract_1039()
    begin
        CheckFileContract(1039);
    end;

    /// <summary>AC1/AC2: UploadContract with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_UploadContract_1033()
    begin
        CheckUploadContract(1033);
    end;

    /// <summary>AC1/AC2: UploadContract with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_UploadContract_1039()
    begin
        CheckUploadContract(1039);
    end;

    /// <summary>AC1/AC2: FolderFileName with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_FolderFileName_1033()
    begin
        CheckFolderFileName(1033);
    end;

    /// <summary>AC1/AC2: FolderFileName with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_FolderFileName_1039()
    begin
        CheckFolderFileName(1039);
    end;

    /// <summary>AC1/AC2: LinkedMove with explicit caller language 1033.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_LinkedMove_1033()
    begin
        CheckLinkedMove(1033);
    end;

    /// <summary>AC1/AC2: LinkedMove with explicit caller language 1039.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_LinkedMove_1039()
    begin
        CheckLinkedMove(1039);
    end;

    local procedure CheckMappingPreflight(LanguageId: Integer)
    var
        DataExch: Record "Data Exch.";
        Definition: Record "Data Exch. Def";
        Mapping: Record "Data Exch. Mapping";
        Target: Record "DataExch Test Target ori";
        Request: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
        Position: Integer;
        BeforeCount: Integer;
    begin
        // [GIVEN] An owned definition/entry for each processing hook; 1247 requires a journal record.
        for Position := 1 to 4 do begin
            DefCode := Fixture.CreateImportDefinition(0);
            Definition.Get(DefCode);
            Mapping.SetRange("Data Exch. Def Code", DefCode);
            Mapping.FindFirst();
            case Position of
                1: Mapping."Pre-Mapping Codeunit" := 1247;
                2: Mapping."Mapping Codeunit" := 1247;
                3: Mapping."Post-Mapping Codeunit" := 1247;
                4: Definition."Data Handling Codeunit" := 1247;
            end;
            Mapping.Modify();
            Definition.Modify();
            DataExch.Init();
            DataExch."Entry No." := 0;
            DataExch."Data Exch. Def Code" := DefCode;
            DataExch.Insert(true);
            Clear(Request);
            Request.Add('entryNo', DataExch."Entry No.");
            BeforeCount := Target.Count();
            // [WHEN] The public caller asks to process the entry.
            Response := Dispatch("Message Type ori"::"DataExchange.Entry.Process", Request, LanguageId);
            // [THEN] Refusal is actionable before any mapping can write.
            AssertRefusal(Response, 'PreconditionFailed');
            LibraryAssert.IsTrue(Fixture.ReadText(Response, 'error').Contains('1247'), 'Identify the incompatible codeunit.');
            AssertLanguage(Fixture.ReadText(Response, 'nextStep'), LanguageId, 'payroll journal', 'launabókina');
            LibraryAssert.AreEqual(BeforeCount, Target.Count(), 'No target rows changed.');
            LibraryAssert.IsTrue(DataExch.Get(DataExch."Entry No."), 'Entry survives refusal.');
            DataExch.Delete(true);
            Definition.Delete(true);
        end;
    end;

    local procedure CheckImportMapping(LanguageId: Integer)
    var
        Mapping: Record "Data Exch. Mapping";
        DataExch: Record "Data Exch.";
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        Response: JsonObject;
        ProcessResult: JsonObject;
        Problems: JsonArray;
        Token: JsonToken;
        DefCode: Code[20];
    begin
        // [GIVEN] Parsing is supported but the mapping requires table 81.
        DefCode := Fixture.CreateImportDefinition(0);
        Mapping.SetRange("Data Exch. Def Code", DefCode);
        Mapping.FindFirst();
        Mapping."Mapping Codeunit" := 1247;
        Mapping.Modify();
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('contentBase64', Fixture.Encode('X168,Owned,1'));
        Request.Add('fileName', 'X168.csv');
        Request.Add('process', true);
        // [WHEN] Import requests processing in the same call.
        Response := Dispatch("Message Type ori"::"DataExchange.Import.Run", Request, LanguageId);
        // [THEN] Parsing succeeds, processing is refused, and the entry remains available.
        AssertSuccess(Response);
        Fixture.Data(Response).Get('processResult', Token);
        ProcessResult := Token.AsObject();
        LibraryAssert.IsFalse(Fixture.ReadBool(ProcessResult, 'processed'), 'Incompatible mapping never runs.');
        Problems := Fixture.ReadArray(ProcessResult, 'errors');
        LibraryAssert.AreEqual(1, Problems.Count(), 'Exactly one preflight refusal.');
        Problems.Get(0, Token);
        LibraryAssert.AreEqual('PreconditionFailed', Fixture.ReadText(Token.AsObject(), 'code'), 'Stable nested refusal.');
        AssertLanguage(Fixture.ReadText(Token.AsObject(), 'nextStep'), LanguageId, 'payroll journal', 'launabókina');
        DataExch.Get(Fixture.ReadInt(Fixture.Data(Response), 'entryNo'));
        DataExch.Delete(true);
        Definition.Get(DefCode);
        Definition.Delete(true);
    end;

    local procedure CheckDefinitionEntries(LanguageId: Integer)
    var
        Definition: Record "Data Exch. Def";
        Entry: Record "Data Exch.";
        Request: JsonObject;
        DeleteEntry: JsonObject;
        Response: JsonObject;
        DefCode: Code[20];
    begin
        // [GIVEN] A definition is referenced by a persisted entry.
        DefCode := Fixture.CreateImportDefinition(0);
        Entry."Data Exch. Def Code" := DefCode;
        Entry.Insert(true);
        Request.Add('code', DefCode);
        // [WHEN] Deletion is requested before cleanup.
        Response := Dispatch("Message Type ori"::"DataExchange.Definition.Delete", Request, LanguageId);
        // [THEN] Both records survive; following the documented recovery permits deletion.
        AssertRefusal(Response, 'PreconditionFailed');
        LibraryAssert.IsTrue(Fixture.ReadText(Response, 'nextStep').Contains('DataExchange.Entry.Delete'), 'Name the cleanup operation.');
        AssertLanguage(Fixture.ReadText(Response, 'error'), LanguageId, 'still use definition', 'nota enn skilgreiningu');
        LibraryAssert.IsTrue(Definition.Get(DefCode), 'Definition survives.');
        LibraryAssert.IsTrue(Entry.Get(Entry."Entry No."), 'Entry survives.');
        DeleteEntry.Add('entryNo', Entry."Entry No.");
        AssertSuccess(Dispatch("Message Type ori"::"DataExchange.Entry.Delete", DeleteEntry, LanguageId));
        AssertSuccess(Dispatch("Message Type ori"::"DataExchange.Definition.Delete", Request, LanguageId));
        LibraryAssert.IsFalse(Definition.Get(DefCode), 'Unreferenced definition deleted.');
    end;

    local procedure CheckEntityType(LanguageId: Integer)
    var
        ExchangeType: Record "Data Exchange Type";
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        Response: JsonObject;
        TypeCode: Code[20];
        DefCode: Code[20];
    begin
        // [GIVEN] A new type and a Generic Import definition.
        DefCode := Fixture.CreateImportDefinition(0);
        TypeCode := Fixture.NewCode('X168');
        Request.Add('code', TypeCode);
        Request.Add('dataExchDefCode', DefCode);
        // [WHEN/THEN] Default, explicit Credit Memo, omission and explicit Invoice round trip.
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", Request, LanguageId);
        AssertSuccess(Response);
        LibraryAssert.AreEqual('Invoice', Fixture.ReadText(Fixture.Data(Response), 'entityType'), 'New default.');
        Request.Add('entityType', 'Credit Memo');
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", Request, LanguageId);
        AssertSuccess(Response);
        LibraryAssert.AreEqual('Credit Memo', Fixture.ReadText(Fixture.Data(Response), 'entityType'), 'Stable wire name.');
        ExchangeType.Get(TypeCode);
        LibraryAssert.AreEqual(ExchangeType."Entity Type"::"Credit Memo", ExchangeType."Entity Type", 'Persisted value.');
        Request.Remove('entityType');
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", Request, LanguageId);
        AssertSuccess(Response);
        LibraryAssert.AreEqual('Credit Memo', Fixture.ReadText(Fixture.Data(Response), 'entityType'), 'Omission preserves value.');
        Request.Add('entityType', 'Invoice');
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", Request, LanguageId);
        AssertSuccess(Response);
        ExchangeType.Get(TypeCode);
        LibraryAssert.AreEqual(ExchangeType."Entity Type"::Invoice, ExchangeType."Entity Type", 'Explicit Invoice persisted.');
        ExchangeType.Delete(true);
        Definition.Get(DefCode);
        Definition.Delete(true);
    end;

    local procedure CheckInvalidEntity(LanguageId: Integer)
    var
        ExchangeType: Record "Data Exchange Type";
        Definition: Record "Data Exch. Def";
        Request: JsonObject;
        Response: JsonObject;
        TypeCode: Code[20];
        DefCode: Code[20];
    begin
        // [GIVEN] An invalid entity name for a new type.
        DefCode := Fixture.CreateImportDefinition(0);
        TypeCode := Fixture.NewCode('X168');
        Request.Add('code', TypeCode);
        Request.Add('dataExchDefCode', DefCode);
        Request.Add('entityType', 'Unknown');
        // [WHEN/THEN] Invalid names and JSON types fail before creation.
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", Request, LanguageId);
        AssertRefusal(Response, 'InvalidParameter');
        LibraryAssert.AreEqual('entityType', Fixture.ReadText(Response, 'parameter'), 'Name rejected field.');
        AssertLanguage(Fixture.ReadText(Response, 'nextStep'), LanguageId, 'stable name', 'fasta heitið');
        LibraryAssert.IsFalse(ExchangeType.Get(TypeCode), 'Invalid entity never creates a type.');
        Request.Replace('entityType', 1);
        Response := Dispatch("Message Type ori"::"DataExchange.Type.Set", Request, LanguageId);
        AssertRefusal(Response, 'InvalidParameterFormat');
        LibraryAssert.IsFalse(ExchangeType.Get(TypeCode), 'Wrong JSON type never creates a type.');
        Definition.Get(DefCode);
        Definition.Delete(true);
    end;

    local procedure CheckFileContract(LanguageId: Integer)
    var
        Setup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        Contract: Codeunit "Storage Contract Parts ori";
        Request: JsonObject;
        Response: JsonObject;
        SetupCode: Code[20];
        PreviousLanguage: Integer;
    begin
        // [GIVEN] An isolated in-memory connector, not a live provider account.
        SetupCode := CreateSetup();
        Request.Add('storageCode', SetupCode);
        Request.Add('path', 'X168.txt');
        Request.Add('contentBase64', Fixture.Encode('owned'));
        // [WHEN/THEN] Real response keys match the documented fields in each language.
        Response := Dispatch("Message Type ori"::"Storage.File.Create", Request, LanguageId);
        AssertSuccess(Response);
        LibraryAssert.AreEqual(5, Fixture.ReadInt(Fixture.Data(Response), 'contentLength'), 'Actual byte count.');
        PreviousLanguage := GlobalLanguage(LanguageId);
        AssertField(Contract.GetResponse('Storage.File.Create'), 'contentLength', true);
        AssertField(Contract.GetResponse('Storage.File.Copy'), 'sourcePath', true);
        AssertField(Contract.GetResponse('Storage.File.Copy'), 'targetPath', true);
        AssertField(Contract.GetResponse('Storage.File.Copy'), 'path', false);
        AssertField(Contract.GetResponse('Storage.File.Move'), 'sourcePath', true);
        GlobalLanguage(PreviousLanguage);
        Clear(Request);
        Request.Add('storageCode', SetupCode);
        Request.Add('sourcePath', 'X168.txt');
        Request.Add('targetPath', 'X168-copy.txt');
        Response := Dispatch("Message Type ori"::"Storage.File.Copy", Request, LanguageId);
        AssertSuccess(Response);
        LibraryAssert.AreEqual('X168.txt', Fixture.ReadText(Fixture.Data(Response), 'sourcePath'), 'Actual source.');
        LibraryAssert.AreEqual('X168-copy.txt', Fixture.ReadText(Fixture.Data(Response), 'targetPath'), 'Actual destination.');
        MockState.Reset();
        Setup.Get(SetupCode);
        Setup.Delete();
    end;

    local procedure CheckUploadContract(LanguageId: Integer)
    var
        Contract: Codeunit "Storage Contract Parts ori";
        Request: JsonObject;
        Response: JsonObject;
        Effect: JsonObject;
        MessageType: Text;
        MessageTypes: List of [Text];
        PreviousLanguage: Integer;
    begin
        // [GIVEN/WHEN] Record-only upload help in the selected language.
        PreviousLanguage := GlobalLanguage(LanguageId);
        MessageTypes.Add('Storage.Upload.Begin');
        MessageTypes.Add('Storage.Upload.Append');
        MessageTypes.Add('Storage.Upload.Status');
        MessageTypes.Add('Storage.Upload.Abort');
        MessageTypes.Add('Storage.Upload.CommitToRecord');
        foreach MessageType in MessageTypes do begin
            Effect := Contract.GetEffect(MessageType);
            AssertLanguage(Fixture.ReadText(Effect, 'preconditions'), LanguageId, 'not for record-only uploads', 'ekki þegar hlaðið er upp eingöngu í færslu');
        end;
        GlobalLanguage(PreviousLanguage);
        // [THEN] Opening a session without storageCode actually succeeds.
        Request.Add('fileName', 'X168.txt');
        Response := Dispatch("Message Type ori"::"Storage.Upload.Begin", Request, LanguageId);
        AssertSuccess(Response);
        Clear(Request);
        Request.Add('uploadId', Fixture.ReadText(Fixture.Data(Response), 'uploadId'));
        AssertSuccess(Dispatch("Message Type ori"::"Storage.Upload.Abort", Request, LanguageId));
    end;

    local procedure CheckFolderFileName(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN/WHEN] A caller puts a folder in fileName.
        Request.Add('fileName', 'X168/example.txt');
        Response := Dispatch("Message Type ori"::"Storage.Upload.Begin", Request, LanguageId);
        // [THEN] Localized recovery tells the caller to separate file and folder.
        AssertRefusal(Response, 'InvalidParameter');
        LibraryAssert.AreEqual('fileName', Fixture.ReadText(Response, 'parameter'), 'Correct parameter.');
        AssertLanguage(Fixture.ReadText(Response, 'nextStep'), LanguageId, 'Send only the file name', 'Sendu aðeins skráarheitið');
        AssertLanguage(Fixture.ReadText(Response, 'nextStep'), LanguageId, 'without a folder path', 'án möppuslóðar');
    end;

    local procedure CheckLinkedMove(LanguageId: Integer)
    var
        Setup: Record "Storage Setup ori";
        Attachment: Record "Incoming Document Attachment";
        Link: Record "Storage Attachment Link ori";
        IncomingDocument: Record "Incoming Document";
        MockState: Codeunit "Storage Mock State";
        Request: JsonObject;
        Response: JsonObject;
        SetupCode: Code[20];
        AttachmentId: Guid;
        IncomingNo: Integer;
    begin
        // [GIVEN] A file linked to an owned attachment through a connector without linked-move support.
        SetupCode := CreateSetup();
        MockState.RefuseLinkedMoves();
        Request.Add('storageCode', SetupCode);
        Request.Add('path', 'X168-linked.txt');
        Request.Add('contentBase64', Fixture.Encode('owned'));
        AssertSuccess(Dispatch("Message Type ori"::"Storage.File.Create", Request, LanguageId));
        Request.Remove('contentBase64');
        Request.Add('fileName', 'X168-linked.txt');
        Response := Dispatch("Message Type ori"::"Storage.Attachment.CreateLinked", Request, LanguageId);
        AssertSuccess(Response);
        Evaluate(AttachmentId, Fixture.ReadText(Fixture.Data(Response), 'systemId'));
        Attachment.GetBySystemId(AttachmentId);
        IncomingNo := Attachment."Incoming Document Entry No.";
        Clear(Request);
        Request.Add('storageCode', SetupCode);
        Request.Add('sourcePath', 'X168-linked.txt');
        Request.Add('targetPath', 'X168-moved.txt');
        // [WHEN] A direct file move is requested.
        Response := Dispatch("Message Type ori"::"Storage.File.Move", Request, LanguageId);
        // [THEN] Clear recovery text, unchanged link and file, no target.
        AssertRefusal(Response, 'PreconditionFailed');
        AssertLanguage(Fixture.ReadText(Response, 'nextStep'), LanguageId, 'Restore the attachment first, then move the file.', 'Endurheimtu viðhengið fyrst og færðu svo skrána.');
        LibraryAssert.IsFalse(Fixture.ReadText(Response, 'expected').Contains('acknowledgement'), 'No connector jargon.');
        Link.Get(Database::"Incoming Document Attachment", AttachmentId);
        LibraryAssert.AreEqual('X168-linked.txt', Link."Storage Path", 'Refusal preserves link.');
        LibraryAssert.IsTrue(MockState.HasFile('X168-linked.txt'), 'Source preserved.');
        LibraryAssert.AreEqual(Fixture.Encode('owned'), MockState.GetFileContent('X168-linked.txt'), 'Source bytes preserved.');
        LibraryAssert.IsFalse(MockState.HasFile('X168-moved.txt'), 'No target.');
        Attachment.Delete(true);
        IncomingDocument.Get(IncomingNo);
        IncomingDocument.Delete(true);
        MockState.Reset();
        Setup.Get(SetupCode);
        Setup.Delete();
    end;

    local procedure CreateSetup(): Code[20]
    var
        Setup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.Reset();
        Setup.Code := Fixture.NewCode('X168');
        Setup."Storage Type" := Setup."Storage Type"::Mock;
        Setup.Enabled := true;
        Setup.Insert();
        exit(Setup.Code);
    end;

    local procedure AssertField(Response: JsonObject; FieldName: Text; Expected: Boolean)
    var
        Fields: JsonArray;
        Token: JsonToken;
        Found: Boolean;
    begin
        Fields := Fixture.ReadArray(Response, 'fields');
        foreach Token in Fields do
            if Fixture.ReadText(Token.AsObject(), 'name') = FieldName then
                Found := true;
        LibraryAssert.AreEqual(Expected, Found, 'Documented response field ' + FieldName);
    end;

    local procedure AssertSuccess(Response: JsonObject)
    begin
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Expected success. ' + Fixture.ReadText(Response, 'error'));
    end;

    local procedure AssertRefusal(Response: JsonObject; ErrorCode: Text)
    begin
        LibraryAssert.AreEqual('Error', Fixture.ReadText(Response, 'status'), 'Expected refusal.');
        LibraryAssert.AreEqual(ErrorCode, Fixture.ReadText(Response, 'code'), 'Stable refusal code. ' + Fixture.ReadText(Response, 'error'));
    end;

    local procedure AssertLanguage(Value: Text; LanguageId: Integer; English: Text; Icelandic: Text)
    begin
        if LanguageId = 1039 then
            LibraryAssert.IsTrue(Value.Contains(Icelandic), 'Expected Icelandic: ' + Value)
        else
            LibraryAssert.IsTrue(Value.Contains(English), 'Expected English: ' + Value);
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ContentType: Text[100];
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        // The queued public route applies the requested LCID; Execute uses the setup default.
        Commit();
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'The public dispatcher returns JSON.');
    end;
}
