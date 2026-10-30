namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Text;
using System.Utilities;

/// <summary>Exercises staging through real upload messages and only Foundation's public façade.</summary>
codeunit 96275 "Storage Staging Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure MultiChunkBinaryRoundTrip()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        Staging: Codeunit "Blob Staging ori";
        Payload: Codeunit "Temp Blob";
        Expected: Codeunit "Temp Blob";
        Actual: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        Request: JsonObject;
        Data: JsonObject;
        PayloadInStream: InStream;
        ExpectedInStream: InStream;
        ActualInStream: InStream;
        ExpectedOutStream: OutStream;
        UploadId: Guid;
        StagingId: Guid;
        SequenceNo: Integer;
        EncodedChunk: Text;
    begin
        // [SCENARIO] Three 1 MiB chunks containing every byte 0..255 survive staging unchanged.
        MakeBinaryChunk(Payload);
        Payload.CreateInStream(PayloadInStream);
        EncodedChunk := Base64Convert.ToBase64(PayloadInStream);
        Expected.CreateOutStream(ExpectedOutStream);
        UploadId := BeginSession(3145728);
        for SequenceNo := 1 to 3 do begin
            Payload.CreateInStream(PayloadInStream);
            CopyStream(ExpectedOutStream, PayloadInStream);
            Append(UploadId, SequenceNo, EncodedChunk);
        end;
        Request.Add('uploadId', Format(UploadId, 0, 4));
        ExecuteTypeWithRequest(TempArgument, Enum::"Message Type ori"::"Storage.Upload.CommitToStaging", Request);
        AssertStatus(TempArgument, 'Success');
        Data := ReadData(TempArgument.GetResponseJson());
        Evaluate(StagingId, ReadText(Data, 'stagingId'));
        LibraryAssert.IsTrue(Staging.Exists(StagingId), 'The returned row must exist for its creator.');
        LibraryAssert.AreEqual(3145728, ReadInteger(Data, 'size'), 'The response size must describe all three chunks.');
        LibraryAssert.AreEqual('layout.docx', ReadText(Data, 'fileName'), 'Default to the session filename.');
        LibraryAssert.IsTrue(Staging.Take(StagingId, Actual), 'Public Take must read the complete binary payload.');
        Expected.CreateInStream(ExpectedInStream);
        Actual.CreateInStream(ActualInStream);
        LibraryAssert.AreEqual(Base64Convert.ToBase64(ExpectedInStream), Base64Convert.ToBase64(ActualInStream), 'Every byte, including NUL and 0xFF, must match.');
        LibraryAssert.IsFalse(Staging.Exists(StagingId), 'Take must clean up the owned staging row.');
        Session.Get(UploadId);
        LibraryAssert.AreEqual(Session.Status::Committed, Session.Status, 'Successful commit must close the session.');
        Chunk.SetRange("Upload Id", UploadId);
        LibraryAssert.IsTrue(Chunk.IsEmpty(), 'Successful commit must release all chunks.');
        ExecuteTypeWithRequest(TempArgument, Enum::"Message Type ori"::"Storage.Upload.CommitToStaging", Request);
        AssertRefusal(TempArgument, 'PreconditionFailed');
        LibraryAssert.AreEqual('', ReadText(ReadData(TempArgument.GetResponseJson()), 'stagingId'), 'Retrying a committed session cannot create another row.');
        Session.Delete(true);
    end;

    [Test]
    procedure ReplacementMetadataAndBilingualDiscovery()
    var
        Session: Record "Storage Upload Session ori";
        TempArgument: Record "Message Argument ori" temporary;
        Staging: Codeunit "Blob Staging ori";
        Payload: Codeunit "Temp Blob";
        Request: JsonObject;
        Data: JsonObject;
        Parameters: JsonArray;
        Workflow: JsonObject;
        Response: JsonObject;
        Discovery: Interface "Msg Discovery ori";
        Contract: Interface "Msg Contract ori";
        Implementation: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        UploadId: Guid;
        StagingId: Guid;
        SavedLanguage: Integer;
    begin
        // [SCENARIO] Optional metadata is accepted without a storage connection; all discovery chapters exist.
        UploadId := BeginSession(3);
        Append(UploadId, 1, 'AP8A');
        Request.Add('uploadId', Format(UploadId, 0, 4));
        Request.Add('fileName', 'replacement.bin');
        Request.Add('contentType', 'application/octet-stream');
        ExecuteTypeWithRequest(TempArgument, Enum::"Message Type ori"::"Storage.Upload.CommitToStaging", Request);
        AssertStatus(TempArgument, 'Success');
        Data := ReadData(TempArgument.GetResponseJson());
        LibraryAssert.AreEqual('replacement.bin', ReadText(Data, 'fileName'), 'Replacement filename must be returned.');
        Evaluate(StagingId, ReadText(Data, 'stagingId'));
        LibraryAssert.IsTrue(Staging.Take(StagingId, Payload), 'Clean up only the row this test created.');
        Session.Get(UploadId);
        Session.Delete(true);
        MessageType := MessageType::"Storage.Upload.CommitToStaging";
        Discovery := MessageType;
        Contract := MessageType;
        Implementation := MessageType;
        LibraryAssert.IsTrue(Implementation.IsEnabled(), 'Upload session access enables the message without a connector.');
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        LibraryAssert.IsTrue(Discovery.GetKeywords() <> '', 'English keywords must exist.');
        GlobalLanguage(1039);
        LibraryAssert.IsTrue(Discovery.GetSelectionDescription() <> '', 'Icelandic selection help must exist.');
        GlobalLanguage(SavedLanguage);
        LibraryAssert.IsTrue(Contract.GetParameters(Parameters), 'Parameters are required.');
        LibraryAssert.AreEqual(3, Parameters.Count(), 'Only uploadId, fileName and contentType are accepted.');
        LibraryAssert.IsTrue(Contract.GetWorkflow(Workflow), 'The workflow must explain staging consumption.');
        LibraryAssert.IsTrue(Contract.GetResponse(Response), 'Response fields are required.');
    end;

    [Test]
    procedure UnknownSessionMatchesSiblingRefusal()
    begin
        // [SCENARIO] An unknown upload uses the sibling refusal without creating a staging row.
        // Foreign-session coverage must use two authenticated users in live verification:
        // Business Central overwrites SystemCreatedBy when inserting a synthetic fixture.
        CompareRefusal(CreateGuid(), 'RecordNotFound');
    end;

    [Test]
    procedure MissingChunkRefusesThenRetries()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        Staging: Codeunit "Blob Staging ori";
        Payload: Codeunit "Temp Blob";
        UploadId: Guid;
        StagingId: Guid;
        Request: JsonObject;
    begin
        // [SCENARIO] Missing chunks cause no write; adding the missing chunk makes the same session retryable.
        UploadId := BeginSession(9);
        Append(UploadId, 1, 'AP8A');
        Append(UploadId, 3, 'AP8A');
        CompareRefusal(UploadId, 'PreconditionFailed');
        Session.Get(UploadId);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'Failed commit must leave the session open.');
        Chunk.SetRange("Upload Id", UploadId);
        LibraryAssert.AreEqual(2, Chunk.Count(), 'Failed commit must retain both chunks.');
        Append(UploadId, 2, 'AP8A');
        Request.Add('uploadId', Format(UploadId, 0, 4));
        ExecuteTypeWithRequest(TempArgument, Enum::"Message Type ori"::"Storage.Upload.CommitToStaging", Request);
        AssertStatus(TempArgument, 'Success');
        Evaluate(StagingId, ReadText(ReadData(TempArgument.GetResponseJson()), 'stagingId'));
        LibraryAssert.IsTrue(Staging.Take(StagingId, Payload), 'Retry must create a consumable staging row.');
        LibraryAssert.AreEqual(9, Payload.Length(), 'Retry must preserve every chunk.');
        Session.Get(UploadId);
        Session.Delete(true);
    end;

    [Test]
    procedure NoChunksAndSizeMismatchMatchSiblingRefusals()
    var
        Session: Record "Storage Upload Session ori";
        UploadId: Guid;
    begin
        // [SCENARIO] Empty and size-mismatched uploads keep the standard refusal behavior.
        UploadId := BeginSession(6);
        CompareRefusal(UploadId, 'PreconditionFailed');
        Append(UploadId, 1, 'AP8A');
        CompareRefusal(UploadId, 'PreconditionFailed');
        Session.Get(UploadId);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'Size mismatch must leave the session open.');
        Session.Delete(true);
    end;

    [Test]
    procedure InvalidMetadataKeepsSessionRetryable()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        Request: JsonObject;
        UploadId: Guid;
    begin
        // [SCENARIO] Invalid filename is rejected before writes and preserves chunks for correction.
        UploadId := BeginSession(3);
        Append(UploadId, 1, 'AP8A');
        Request.Add('uploadId', Format(UploadId, 0, 4));
        Request.Add('fileName', '../bad.bin');
        ExecuteTypeWithRequest(TempArgument, Enum::"Message Type ori"::"Storage.Upload.CommitToStaging", Request);
        AssertStatus(TempArgument, 'Error');
        Session.Get(UploadId);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'Invalid metadata must leave the session open.');
        Chunk.SetRange("Upload Id", UploadId);
        LibraryAssert.AreEqual(1, Chunk.Count(), 'Invalid metadata must preserve the chunk.');
        Session.Delete(true);
    end;

    local procedure BeginSession(Size: Integer) UploadId: Guid
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('fileName', 'layout.docx');
        Request.Add('declaredSize', Size);
        ExecuteTypeWithRequest(TempArgument, Enum::"Message Type ori"::"Storage.Upload.Begin", Request);
        AssertStatus(TempArgument, 'Success');
        Evaluate(UploadId, ReadText(ReadData(TempArgument.GetResponseJson()), 'uploadId'));
    end;

    local procedure Append(UploadId: Guid; SequenceNo: Integer; Encoded: Text)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('uploadId', Format(UploadId, 0, 4));
        Request.Add('sequence', SequenceNo);
        Request.Add('contentBase64', Encoded);
        ExecuteTypeWithRequest(TempArgument, Enum::"Message Type ori"::"Storage.Upload.Append", Request);
        AssertStatus(TempArgument, 'Success');
    end;

    local procedure CompareRefusal(UploadId: Guid; ExpectedCode: Text)
    var
        TempStagingArgument: Record "Message Argument ori" temporary;
        TempSiblingArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        StagingResponse: JsonObject;
        SiblingResponse: JsonObject;
    begin
        Request.Add('uploadId', Format(UploadId, 0, 4));
        ExecuteTypeWithRequest(TempStagingArgument, Enum::"Message Type ori"::"Storage.Upload.CommitToStaging", Request);
        ExecuteTypeWithRequest(TempSiblingArgument, Enum::"Message Type ori"::"Storage.Upload.CommitToRecord", Request);
        AssertRefusal(TempStagingArgument, ExpectedCode);
        StagingResponse := TempStagingArgument.GetResponseJson();
        SiblingResponse := TempSiblingArgument.GetResponseJson();
        LibraryAssert.AreEqual(ReadText(SiblingResponse, 'error'), ReadText(StagingResponse, 'error'), 'Refusal text must match the sibling.');
        LibraryAssert.AreEqual(ReadText(SiblingResponse, 'code'), ReadText(StagingResponse, 'code'), 'Refusal code must match the sibling.');
        LibraryAssert.AreEqual('', ReadText(ReadData(StagingResponse), 'stagingId'), 'A refused request cannot return a new staging row.');
    end;

    local procedure MakeBinaryChunk(var Payload: Codeunit "Temp Blob")
    var
        Pattern: Codeunit "Temp Blob";
        PatternOutStream: OutStream;
        PayloadOutStream: OutStream;
        PatternInStream: InStream;
        ByteValue: Byte;
        Index: Integer;
    begin
        Pattern.CreateOutStream(PatternOutStream);
        for Index := 0 to 255 do begin
            ByteValue := Index;
            PatternOutStream.Write(ByteValue);
        end;
        Payload.CreateOutStream(PayloadOutStream);
        for Index := 1 to 4096 do begin
            Pattern.CreateInStream(PatternInStream);
            CopyStream(PayloadOutStream, PatternInStream);
        end;
    end;

    local procedure AssertStatus(var TempArgument: Record "Message Argument ori" temporary; Expected: Text)
    begin
        LibraryAssert.AreEqual(Expected, ReadText(TempArgument.GetResponseJson(), 'status'), 'Unexpected message response.');
    end;

    local procedure AssertRefusal(var TempArgument: Record "Message Argument ori" temporary; ExpectedCode: Text)
    begin
        AssertStatus(TempArgument, 'Error');
        LibraryAssert.AreEqual(ExpectedCode, ReadText(TempArgument.GetResponseJson(), 'code'), 'Unexpected refusal code.');
    end;

    local procedure ReadData(Response: JsonObject) Data: JsonObject
    var
        Token: JsonToken;
    begin
        if Response.Get('data', Token) then
            if Token.IsObject() then
                Data := Token.AsObject();
    end;

    local procedure ReadText(Data: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Data.Get(Name, Token) then
            exit(Token.AsValue().AsText());
    end;

    local procedure ReadInteger(Data: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Data.Get(Name, Token);
        exit(Token.AsValue().AsInteger());
    end;
    local procedure ExecuteTypeWithRequest(var TempArgument: Record "Message Argument ori" temporary; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
    begin
        ExecuteTypeWithRequest(TempArgument, MessageType, RequestJson, 0);
    end;

    local procedure ExecuteTypeWithRequest(var TempArgument: Record "Message Argument ori" temporary; MessageType: Enum "Message Type ori"; RequestJson: JsonObject; LanguageId: Integer)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
        RequestText: Text;
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseText: Text;
        ResponseJson: JsonObject;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        if LanguageId = 0 then
            Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType)
        else
            Dispatcher.EnqueueAndProcess(MessageType, MessageVersion, '', '', 'application/json', RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
        // Clear PK before Insert: Init keeps ID; reuse after a prior Insert raises
        // "Message TempArgument ori already exists" (attachments#31 smoking gun).
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(true);
        TempArgument.SetResponseJson(ResponseJson);
    end;

}
