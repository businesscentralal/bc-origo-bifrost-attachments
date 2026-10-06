namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Text;

/// <summary>
/// Tests that the storage message types answer bad requests the way every Bifröst message type
/// does: <c>status</c> = <c>Error</c> with a stable <c>code</c>, the request <c>parameter</c>
/// concerned, the value <c>received</c>, what was <c>expected</c> and a <c>nextStep</c>, with every
/// problem of a request reported at once. Also covers the 240 MiB single-call content limit and
/// the chunk size an upload session advertises.
/// </summary>
codeunit 96212 "Storage Error Response Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'MOCK', Locked = true;
        DisabledCodeTok: Label 'BIFTS-OFF', Locked = true;
        TestCustNoTok: Label 'BIFTS-ERR-TST', Locked = true;

    [Test]
    procedure FileGet_NoStorageCodeNoPath_ReportsBothMissing()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
        Parameters: List of [Text];
    begin
        // [SCENARIO] Every missing value is reported in one answer, not only the first.
        Initialize();

        // [WHEN] Storage.File.Get runs with neither storageCode nor path
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", RequestJson);

        // [THEN] MultipleErrors lists both, each as MissingParameter
        AssertErrorCode(TempArgument, 'MultipleErrors');
        Parameters := ErrorParameters(TempArgument, 'MissingParameter');
        LibraryAssert.AreEqual(2, Parameters.Count(), 'Both missing parameters should be reported.');
        LibraryAssert.IsTrue(Parameters.Contains('storageCode'), 'storageCode should be reported missing.');
        LibraryAssert.IsTrue(Parameters.Contains('path'), 'path should be reported missing.');
    end;

    [Test]
    procedure FileGet_UnknownStorageCode_ReturnsRecordNotFoundWithNextStep()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] An unknown storage code is RecordNotFound and points to Storage.Account.List.
        Initialize();
        RequestJson.Add('storageCode', 'BIFTS-NONE');
        RequestJson.Add('path', 'a.txt');

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", RequestJson);

        AssertErrorAnswer(TempArgument, 'RecordNotFound', 'storageCode');
        LibraryAssert.AreEqual('BIFTS-NONE', ReadText(TempArgument.GetResponseJson(), 'received'), 'The received code should be echoed.');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'nextStep').Contains('Storage.Account.List'), 'The next step should name Storage.Account.List.');
    end;

    [Test]
    procedure FileGet_DisabledConnection_ReturnsPreconditionFailed()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A disabled connection is a precondition, not a missing record.
        Initialize();
        RequestJson.Add('storageCode', DisabledCodeTok);
        RequestJson.Add('path', 'a.txt');

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", RequestJson);

        AssertErrorAnswer(TempArgument, 'PreconditionFailed', 'storageCode');
    end;

    [Test]
    procedure FileGet_DotDotPath_ReturnsInvalidParameter()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A path that walks out of the connection's base path is refused before any storage call.
        Initialize();
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', 'invoices/../../secret.txt');

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Get", RequestJson);

        AssertErrorAnswer(TempArgument, 'InvalidParameter', 'path');
        LibraryAssert.AreEqual('invoices/../../secret.txt', ReadText(TempArgument.GetResponseJson(), 'received'), 'The rejected path should be echoed.');
    end;

    [Test]
    procedure FileCreate_NotBase64_ReturnsInvalidParameterFormat()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] Content that is not base64 is a format error on contentBase64, and nothing is stored.
        Initialize();
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', 'bad.txt');
        RequestJson.Add('contentBase64', '@@ not base64 @@');

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.File.Create", RequestJson);

        AssertErrorAnswer(TempArgument, 'InvalidParameterFormat', 'contentBase64');
        LibraryAssert.AreEqual('', ReadText(TempArgument.GetResponseJson(), 'received'), 'The content must never be echoed back.');
    end;

    [Test]
    procedure UploadAppend_ThreeBadValues_ReportsAllTogether()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A malformed uploadId, a text sequence and a missing chunk are all reported at once.
        Initialize();
        RequestJson.Add('uploadId', 'not-a-guid');
        RequestJson.Add('sequence', 'abc');

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Append", RequestJson);

        AssertErrorCode(TempArgument, 'MultipleErrors');
        LibraryAssert.IsTrue(ErrorParameters(TempArgument, 'InvalidParameterFormat').Contains('uploadId'), 'uploadId should be a format error.');
        LibraryAssert.IsTrue(ErrorParameters(TempArgument, 'InvalidParameterFormat').Contains('sequence'), 'sequence should be a format error.');
        LibraryAssert.IsTrue(ErrorParameters(TempArgument, 'MissingParameter').Contains('contentBase64'), 'contentBase64 should be reported missing.');
    end;

    [Test]
    procedure UploadAppend_FractionalSequence_ReturnsInvalidParameterFormat()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] Boundary: 1.5 is a number but not an integer, so it never falls back to 1 or 0.
        Initialize();
        UploadId := BeginUpload();
        RequestJson.Add('uploadId', UploadId);
        RequestJson.Add('sequence', 1.5);
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('x'));

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Append", RequestJson);

        AssertErrorAnswer(TempArgument, 'InvalidParameterFormat', 'sequence');
    end;

    [Test]
    procedure UploadAppend_DigitStringSequence_IsAccepted()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
        UploadId: Text;
    begin
        // [SCENARIO] Like Foundation's readers, an integer may arrive as a JSON number or a string of digits.
        Initialize();
        UploadId := BeginUpload();
        RequestJson.Add('uploadId', UploadId);
        RequestJson.Add('sequence', '1');
        RequestJson.Add('contentBase64', Base64Convert.ToBase64('x'));

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Append", RequestJson);

        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'A digit string should be read as an integer.');
    end;

    [Test]
    procedure UploadBegin_NegativeDeclaredSize_ReturnsInvalidParameter()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] Boundary: a negative size is well-formed but not allowed.
        Initialize();
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('fileName', 'neg.txt');
        RequestJson.Add('declaredSize', -1);

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", RequestJson);

        AssertErrorAnswer(TempArgument, 'InvalidParameter', 'declaredSize');
    end;

    [Test]
    procedure UploadBegin_Session_AdvertisesLargestChunk()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO] Every chunk is one billable message, so the session asks for the largest chunk one call can carry.
        Initialize();
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('fileName', 'big.bin');

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", RequestJson);

        TempArgument.GetResponseJson().Get('data', Token);
        DataObject := Token.AsObject();
        DataObject.Get('chunkSizeHint', Token);
        LibraryAssert.AreEqual(251658240, Token.AsValue().AsInteger(), 'chunkSizeHint should be 240 MiB.');
        DataObject.Get('maxChunkBytes', Token);
        LibraryAssert.AreEqual(251658240, Token.AsValue().AsInteger(), 'maxChunkBytes should be 240 MiB.');
    end;

    [Test]
    procedure ContentLimit_ExactlyMaximum_IsAcceptedOneByteMoreIsNot()
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        // [SCENARIO] Boundary of the single-call limit: 240 MiB fits, one byte more does not.
        // Direct call: building a 240 MiB request in a test is not practical.
        Initialize();
        LibraryAssert.IsTrue(Reader.IsWithinContentLimit(Reader.MaxContentBytes()), 'Exactly 240 MiB should fit in one call.');
        LibraryAssert.IsFalse(Reader.IsWithinContentLimit(Reader.MaxContentBytes() + 1), 'One byte over 240 MiB should not fit.');
        LibraryAssert.AreEqual(251658240, Reader.MaxContentBytes(), 'The limit should be 240 MiB.');
    end;

    [Test]
    procedure UploadStatus_UnknownUploadId_ReturnsRecordNotFound()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A well-formed uploadId that names no session is RecordNotFound with a next step.
        Initialize();
        RequestJson.Add('uploadId', Format(CreateGuid(), 0, 4));

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Status", RequestJson);

        AssertErrorAnswer(TempArgument, 'RecordNotFound', 'uploadId');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'nextStep').Contains('Storage.Upload.Begin'), 'The next step should name Storage.Upload.Begin.');
    end;

    [Test]
    procedure Offload_UnknownTargetAndNoSystemId_ReportsBoth()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A wrong target and a missing systemId are reported together.
        Initialize();
        RequestJson.Add('target', 'Picture');
        RequestJson.Add('storageCode', MockCodeTok);

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Offload", RequestJson);

        AssertErrorCode(TempArgument, 'MultipleErrors');
        LibraryAssert.IsTrue(ErrorParameters(TempArgument, 'InvalidParameter').Contains('target'), 'target should be reported invalid.');
        LibraryAssert.IsTrue(ErrorParameters(TempArgument, 'MissingParameter').Contains('systemId'), 'systemId should be reported missing.');
    end;

    [Test]
    procedure Offload_UnknownSystemId_ReturnsRecordNotFound()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] An attachment that does not exist is RecordNotFound on systemId.
        Initialize();
        RequestJson.Add('target', 'DocumentAttachment');
        RequestJson.Add('systemId', Format(CreateGuid(), 0, 4));
        RequestJson.Add('storageCode', MockCodeTok);

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Offload", RequestJson);

        AssertErrorAnswer(TempArgument, 'RecordNotFound', 'systemId');
    end;

    [Test]
    procedure Restore_AttachmentNotOffloaded_ReturnsPreconditionFailed()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        CreateJson: JsonObject;
        RestoreJson: JsonObject;
        SystemId: Text;
    begin
        // [SCENARIO] Restoring an attachment that still holds its content is a precondition failure.
        Initialize();

        // [GIVEN] An attachment on the test customer with inline content
        CreateJson.Add('tableId', Database::Customer);
        CreateJson.Add('no', TestCustNoTok);
        CreateJson.Add('fileName', 'inline.txt');
        CreateJson.Add('content', Base64Convert.ToBase64('inline'));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", CreateJson);
        SystemId := ReadDataText(TempArgument, 'systemId');

        // [WHEN] It is restored
        RestoreJson.Add('target', 'DocumentAttachment');
        RestoreJson.Add('systemId', SystemId);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Restore", RestoreJson);

        // [THEN] PreconditionFailed on systemId
        AssertErrorAnswer(TempArgument, 'PreconditionFailed', 'systemId');
    end;

    [Test]
    procedure CreateForRecord_TextTableId_ReturnsInvalidParameterFormat()
    var
        TempArgument: Record "Message Argument ori";
        Base64Convert: Codeunit "Base64 Convert";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A table id that is not an integer never falls back to "no table given".
        Initialize();
        RequestJson.Add('tableId', 'Customer');
        RequestJson.Add('no', TestCustNoTok);
        RequestJson.Add('fileName', 'x.txt');
        RequestJson.Add('content', Base64Convert.ToBase64('x'));

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", RequestJson);

        AssertErrorAnswer(TempArgument, 'InvalidParameterFormat', 'tableId');
    end;

    // ————— Helpers —————

    /// <summary>Checks localized filename refusals through dispatch while preserving protocol fields.</summary>
    [Test]
    procedure Scenario_AC01_UploadFolder_BilingualRefusalPreservesKeys()
    begin
        // [SCENARIO] Invalid folder names produce localized prose with stable error keys.
        Initialize();
        AssertLocalizedUploadRefusal(1033,
            'fileName must be a file name without folders; use path or folderPath for the destination folder.',
            'a file name with no slash or backslash');
        AssertLocalizedUploadRefusal(1039,
            'fileName verður að vera skráarheiti án mappa; notaðu path eða folderPath fyrir áfangamöppuna.',
            'skráarheiti án skástriks eða öfugs skástriks');
    end;

    /// <summary>Checks that localized expected text retains the attachment target identifiers.</summary>
    [Test]
    procedure Scenario_AC01_UnknownTarget_BilingualExpectedPreservesTokens()
    begin
        // [SCENARIO] Only the conjunction between wire target names changes with language.
        Initialize();
        AssertLocalizedTarget(1033, 'DocumentAttachment or IncomingDocument');
        AssertLocalizedTarget(1039, 'DocumentAttachment eða IncomingDocument');
    end;

    /// <summary>Checks that upload success keys and stored filenames stay stable in both languages.</summary>
    [Test]
    procedure Scenario_AC02_UploadBegin_BilingualSuccessKeepsStoredFilename()
    begin
        // [SCENARIO] Localization does not change upload IDs, state tokens, or the persisted filename.
        Initialize();
        AssertLocalizedUploadSuccess(1033);
        AssertLocalizedUploadSuccess(1039);
    end;

    local procedure AssertLocalizedUploadRefusal(LanguageId: Integer; ExpectedMessage: Text; ExpectedValue: Text)
    var
        TempArgument: Record "Message Argument ori";
        UploadSession: Record "Storage Upload Session ori";
        RequestJson: JsonObject;
        SavedLanguageId: Integer;
        BeforeCount: Integer;
    begin
        // [GIVEN] A configured mock backend and an invalid file name containing a folder.
        BeforeCount := UploadSession.Count();
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('fileName', 'folder/file.txt');
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] Dispatching a real upload begin request.
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", RequestJson);
        GlobalLanguage(SavedLanguageId);
        // [THEN] The refusal is translated, keys are stable, and no session was created.
        AssertErrorAnswer(TempArgument, 'InvalidParameter', 'fileName');
        LibraryAssert.AreEqual(ExpectedMessage, ReadText(TempArgument.GetResponseJson(), 'message'), 'Localized refusal mismatch.');
        LibraryAssert.AreEqual(ExpectedValue, ReadText(TempArgument.GetResponseJson(), 'expected'), 'Localized expected value mismatch.');
        LibraryAssert.AreEqual('folder/file.txt', ReadText(TempArgument.GetResponseJson(), 'received'), 'The received filename must remain unchanged.');
        LibraryAssert.AreEqual(BeforeCount, UploadSession.Count(), 'An invalid name must not create an upload session.');
    end;

    local procedure AssertLocalizedTarget(LanguageId: Integer; ExpectedValue: Text)
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
        SavedLanguageId: Integer;
    begin
        // [GIVEN] An unknown target and a valid identifier to isolate the target refusal.
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('target', 'Picture');
        RequestJson.Add('systemId', Format(CreateGuid(), 0, 4));
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] Dispatching a real attachment offload request.
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Offload", RequestJson);
        GlobalLanguage(SavedLanguageId);
        // [THEN] Protocol target names and error keys stay stable in the localized response.
        AssertErrorAnswer(TempArgument, 'InvalidParameter', 'target');
        LibraryAssert.AreEqual(ExpectedValue, ReadText(TempArgument.GetResponseJson(), 'expected'), 'Expected target names must retain their wire spelling.');
        LibraryAssert.AreEqual('Picture', ReadText(TempArgument.GetResponseJson(), 'received'), 'The received target must not be translated.');
    end;

    local procedure AssertLocalizedUploadSuccess(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori";
        UploadSession: Record "Storage Upload Session ori";
        RequestJson: JsonObject;
        UploadId: Guid;
        SavedLanguageId: Integer;
    begin
        // [GIVEN] A valid filename for the mock backend.
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('fileName', 'localized.txt');
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] Dispatching an upload begin request in either language.
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", RequestJson);
        GlobalLanguage(SavedLanguageId);
        // [THEN] A real session exists and the stable success payload identifies it.
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Success is a protocol token.');
        Evaluate(UploadId, ReadDataText(TempArgument, 'uploadId'));
        UploadSession.SetLoadFields("File Name", Status);
        UploadSession.Get(UploadId);
        LibraryAssert.AreEqual('localized.txt', UploadSession."File Name", 'The persisted filename must remain unchanged.');
        LibraryAssert.AreEqual(UploadSession.Status::Open, UploadSession.Status, 'The session must be open.');
        LibraryAssert.AreEqual(MockCodeTok, ReadDataText(TempArgument, 'storageCode'), 'storageCode is a protocol key.');
    end;

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        Customer: Record Customer;
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.Reset();
        StorageSetup.DeleteAll();
        InsertSetup(MockCodeTok, true);
        InsertSetup(DisabledCodeTok, false);
        if not Customer.Get(TestCustNoTok) then begin
            Customer.Init();
            Customer."No." := TestCustNoTok;
            Customer.Insert();
        end;
    end;

    local procedure InsertSetup(StorageCode: Code[20]; IsEnabled: Boolean)
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        StorageSetup.Init();
        StorageSetup."Code" := StorageCode;
        StorageSetup.Description := 'Mock storage connection';
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := IsEnabled;
        StorageSetup.Insert();
    end;

    local procedure BeginUpload(): Text
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('fileName', 'seq.txt');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Upload.Begin", RequestJson);
        exit(ReadDataText(TempArgument, 'uploadId'));
    end;

    local procedure AssertErrorAnswer(var TempArgument: Record "Message Argument ori"; ExpectedCode: Text; ExpectedParameter: Text)
    begin
        AssertErrorCode(TempArgument, ExpectedCode);
        LibraryAssert.AreEqual(ExpectedParameter, ReadText(TempArgument.GetResponseJson(), 'parameter'), 'The error should name the parameter.');
    end;

    local procedure AssertErrorCode(var TempArgument: Record "Message Argument ori"; ExpectedCode: Text)
    var
        ResponseJson: JsonObject;
    begin
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Error', ReadText(ResponseJson, 'status'), 'The call should answer with an error response.');
        LibraryAssert.AreEqual(ExpectedCode, ReadText(ResponseJson, 'code'), 'Unexpected error code.');
        LibraryAssert.IsFalse(ResponseJson.Contains('callstack'), 'No call stack may reach the caller.');
    end;

    local procedure ErrorParameters(var TempArgument: Record "Message Argument ori"; ErrorCode: Text) Parameters: List of [Text]
    var
        Token: JsonToken;
        EntryToken: JsonToken;
    begin
        if not TempArgument.GetResponseJson().Get('errors', Token) then
            exit;
        foreach EntryToken in Token.AsArray() do
            if ReadText(EntryToken.AsObject(), 'code') = ErrorCode then
                Parameters.Add(ReadText(EntryToken.AsObject(), 'parameter'));
    end;

    local procedure ExecuteTypeWithRequest(var TempArgument: Record "Message Argument ori"; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[50];
        MessageVersion: Enum "Message Version ori";
        RequestText: Text;
        ResponseText: Text;
        ResponseJson: JsonObject;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(true);
        TempArgument.SetResponseJson(ResponseJson);
    end;

    local procedure ReadDataText(var TempArgument: Record "Message Argument ori"; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        TempArgument.GetResponseJson().Get('data', Token);
        exit(ReadText(Token.AsObject(), PropertyName));
    end;

    local procedure ReadText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
