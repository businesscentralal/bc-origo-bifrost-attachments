namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Reflection;
using System.Utilities;

/// <summary>
/// BC 28 native external-storage field mirror (#11). The Microsoft extension is optional, so the
/// tests assert the no-op path when its fields are absent and the write path when they exist.
/// </summary>
codeunit 96217 "Storage Native Fields Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    EventSubscriberInstance = Manual;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        NativeModifyFailureId: Guid;

    [Test]
    procedure NativeFields_WhenExtensionMissing_SetAndClearDoNotError()
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        RecRef: RecordRef;
        RecSystemId: Guid;
    begin
        // [SCENARIO] AC06: without External Storage - Document Attachments, the mirror is a no-op.
        RecRef.Open(Database::"Document Attachment");
        if RecRef.FieldExist(8750) then begin
            RecRef.Close();
            exit;
        end;
        RecRef.Close();
        RecSystemId := CreateGuid();
        AttachmentMgt.SetNativeExternalStorageFields(RecSystemId, 'ORIGOBCTEST', 'bifrost-test/file.txt');
        AttachmentMgt.ClearNativeExternalStorageFields(RecSystemId);
        LibraryAssert.IsTrue(true, 'Missing native fields must not raise.');
    end;

    [Test]
    procedure NativeFields_WhenPresent_SetAndClearRoundTrip()
    var
        DocumentAttachment: Record "Document Attachment";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        StoredExternallyFld: FieldRef;
        ContentOutStream: OutStream;
        ContentInStream: InStream;
    begin
        // [SCENARIO] AC01/AC02: when fields 8750-8753 exist, offload sets them and restore clears them.
        RecRef.Open(Database::"Document Attachment");
        if not RecRef.FieldExist(8750) then begin
            RecRef.Close();
            exit;
        end;
        RecRef.Close();

        // Seed a real attachment: the base table rejects inserts with no content.
        TempBlob.CreateOutStream(ContentOutStream);
        ContentOutStream.WriteText('X native mirror content');
        TempBlob.CreateInStream(ContentInStream);
        DocumentAttachment.Init();
        DocumentAttachment.ImportFromStream(ContentInStream, 'native-mirror.txt');
        DocumentAttachment.Insert(true);

        AttachmentMgt.SetNativeExternalStorageFields(DocumentAttachment.SystemId, 'ORIGOBCTEST', 'bifrost-test/native-mirror.txt');
        RecRef.Open(Database::"Document Attachment");
        RecRef.GetBySystemId(DocumentAttachment.SystemId);
        StoredExternallyFld := RecRef.Field(8750);
        LibraryAssert.IsTrue(StoredExternallyFld.Value, 'Stored Externally should be set.');
        LibraryAssert.IsFalse(RecRef.Field(8753).Value, 'Stored Internally should be cleared.');
        LibraryAssert.AreNotEqual(0DT, RecRef.Field(8751).Value, 'External upload date should be recorded.');
        LibraryAssert.AreEqual('ORIGOBCTEST:bifrost-test/native-mirror.txt', Format(RecRef.Field(8752).Value), 'External File Path');
        RecRef.Close();

        AttachmentMgt.ClearNativeExternalStorageFields(DocumentAttachment.SystemId);
        RecRef.Open(Database::"Document Attachment");
        RecRef.GetBySystemId(DocumentAttachment.SystemId);
        LibraryAssert.IsFalse(RecRef.Field(8750).Value, 'Stored Externally should be cleared.');
        LibraryAssert.IsTrue(RecRef.Field(8753).Value, 'Stored Internally should be restored.');
        LibraryAssert.AreEqual(0DT, RecRef.Field(8751).Value, 'External upload date should be cleared.');
        LibraryAssert.AreEqual('', Format(RecRef.Field(8752).Value), 'External File Path should be blank.');
        RecRef.Close();
        DocumentAttachment.Delete(true);
    end;

    /// <summary>An unknown attachment remains absent after both mirror operations.</summary>
    [Test]
    procedure Scenario_AC06_MissingRecord_SetAndClearDoNotInsert()
    var
        DocumentAttachment: Record "Document Attachment";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        MissingId: Guid;
        BeforeCount: Integer;
    begin
        // Story #75, AC06 | Time: none | Risk: native extension present or absent.
        MissingId := CreateGuid();
        BeforeCount := DocumentAttachment.Count();
        AttachmentMgt.SetNativeExternalStorageFields(MissingId, 'ORIGOBCTEST', 'missing.txt');
        AttachmentMgt.ClearNativeExternalStorageFields(MissingId);
        LibraryAssert.IsFalse(DocumentAttachment.GetBySystemId(MissingId), 'A missing attachment must not be created.');
        LibraryAssert.AreEqual(BeforeCount, DocumentAttachment.Count(), 'Mirror no-op must preserve attachment count.');
    end;

    /// <summary>A failed native field assignment must not persist earlier assignments.</summary>
    [Test]
    procedure Scenario_AC06_AssignmentFailure_PreservesPersistedFields()
    var
        DocumentAttachment: Record "Document Attachment";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        ContentOutStream: OutStream;
        ContentInStream: InStream;
        OriginalDate: DateTime;
        TooLongPath: Text;
    begin
        // Story #75, AC06 | Time: compare persisted upload timestamp | Risk: requires native fields.
        RecRef.Open(Database::"Document Attachment");
        if not RecRef.FieldExist(8752) then begin
            RecRef.Close();
            exit;
        end;
        TooLongPath := PadStr('', RecRef.Field(8752).Length + 1, 'X');
        RecRef.Close();
        TempBlob.CreateOutStream(ContentOutStream);
        ContentOutStream.WriteText('X assignment failure fixture');
        TempBlob.CreateInStream(ContentInStream);
        DocumentAttachment.Init();
        DocumentAttachment.ImportFromStream(ContentInStream, 'assignment.txt');
        DocumentAttachment.Insert(true);
        AttachmentMgt.SetNativeExternalStorageFields(DocumentAttachment.SystemId, 'ORIGOBCTEST', 'original.txt');
        RecRef.GetTable(DocumentAttachment);
        RecRef.GetBySystemId(DocumentAttachment.SystemId);
        OriginalDate := RecRef.Field(8751).Value;
        RecRef.Close();
        AttachmentMgt.SetNativeExternalStorageFields(DocumentAttachment.SystemId, 'ORIGOBCTEST', TooLongPath);
        RecRef.Open(Database::"Document Attachment");
        RecRef.GetBySystemId(DocumentAttachment.SystemId);
        LibraryAssert.IsTrue(RecRef.Field(8750).Value, 'Failed assignment must retain external state.');
        LibraryAssert.IsFalse(RecRef.Field(8753).Value, 'Failed assignment must retain internal state.');
        LibraryAssert.AreEqual(OriginalDate, RecRef.Field(8751).Value, 'Failed assignment must retain timestamp.');
        LibraryAssert.AreEqual('ORIGOBCTEST:original.txt', Format(RecRef.Field(8752).Value), 'Failed assignment must retain original path.');
        RecRef.Close();
        DocumentAttachment.Delete(true);
    end;
    /// <summary>A native mirror persistence failure must not upload an orphan or clear the only local copy.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure NativeMirrorModifyFailure_PreventsExternalUpload()
    var
        DocumentAttachment: Record "Document Attachment";
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        Faults: Codeunit "Storage Native Fields Tests";
        MockState: Codeunit "Storage Mock State";
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        Request: JsonObject;
        AttachmentId: Guid;
        ContentOut: OutStream;
        ContentIn: InStream;
        ContentText: Text;
        MockCodeTok: Label 'X75NATIVE', Locked = true;
    begin
        // Requires the supported native extension. The missing-extension path is tested separately.
        RecRef.Open(Database::"Document Attachment");
        if not RecRef.FieldExist(8750) then begin
            RecRef.Close();
            exit;
        end;
        RecRef.Close();
        MockState.Reset();
        if StorageSetup.Get(MockCodeTok) then
            StorageSetup.Delete();
        StorageSetup.Init();
        StorageSetup.Code := MockCodeTok;
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
        TempBlob.CreateOutStream(ContentOut);
        ContentOut.WriteText('X native persistence baseline');
        TempBlob.CreateInStream(ContentIn);
        DocumentAttachment.Init();
        DocumentAttachment.ImportFromStream(ContentIn, 'native-failure.txt');
        DocumentAttachment.Insert(true);
        // Offload refuses a blank or folded name before the native mirror runs. Keep a leaf name.
        DocumentAttachment."File Name" := 'native-failure';
        DocumentAttachment."File Extension" := 'txt';
        DocumentAttachment.Modify(true);
        AttachmentId := DocumentAttachment.SystemId;
        Commit();
        Request.Add('target', 'DocumentAttachment');
        Request.Add('systemId', Format(AttachmentId, 0, 4));
        Request.Add('storageCode', MockCodeTok);
        Faults.ConfigureNativeModifyFailure(AttachmentId);
        BindSubscription(Faults);
        asserterror DispatchNativeOffload(Request);
        LibraryAssert.ExpectedError('X75 native mirror persistence failure');
        UnbindSubscription(Faults);
        LibraryAssert.AreEqual(0, MockState.GetWriteCalls(), 'Native persistence must succeed before any irreversible provider write.');
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'Failure must not leave a remote orphan.');
        LibraryAssert.IsFalse(Link.Get(Database::"Document Attachment", AttachmentId), 'Failed offload must roll back the link.');
        DocumentAttachment.GetBySystemId(AttachmentId);
        Clear(TempBlob);
        DocumentAttachment.GetAsTempBlob(TempBlob);
        TempBlob.CreateInStream(ContentIn);
        ContentIn.ReadText(ContentText);
        LibraryAssert.AreEqual('X native persistence baseline', ContentText, 'Failed offload must preserve the original local bytes.');
        RecRef.GetTable(DocumentAttachment);
        LibraryAssert.IsFalse(RecRef.Field(8750).Value, 'Failed offload must preserve native local-storage state.');
        RecRef.Close();
        DocumentAttachment.Delete(true);
        StorageSetup.Delete();
        Commit();
    end;

    [Test]
    procedure ExternalStorageModule_IsPresentInTheTestContainer()
    var
        ModuleInfo: ModuleInfo;
        RecRef: RecordRef;
        ExternalStorageAppId: Guid;
    begin
        // [SCENARIO] The read path under test is the installed External Storage module, not a missing-field no-op.
        ExternalStorageAppId := '5f2e93a0-6083-4718-b05a-7ac89be5644d';
        LibraryAssert.IsTrue(NavApp.GetModuleInfo(ExternalStorageAppId, ModuleInfo), 'External Storage - Document Attachments must be installed in the test container.');
        RecRef.Open(Database::"Document Attachment");
        LibraryAssert.IsTrue(RecRef.FieldExist(8753), 'Field 8753 Stored Internally must exist.');
        RecRef.Close();
    end;

    [Test]
    procedure LinkedRead_LeavesStoredRowUnchangedAfterModify()
    var
        DocumentAttachment: Record "Document Attachment";
        Link: Record "Storage Attachment Link ori";
        TempBlob: Codeunit "Temp Blob";
        ContentIn: InStream;
        AttachmentId: Guid;
        ExpectedPath: Text;
        ReadBack: Text;
    begin
        // [SCENARIO] A Bifrost read must not persist Stored Internally next to the native mirror.
        AssertExternalStorageFieldPresent();
        AttachmentId := OffloadLeafAttachment('linked-read', 'X linked read bytes');
        LibraryAssert.IsTrue(Link.Get(Database::"Document Attachment", AttachmentId), 'Offload must record a Bifrost link.');
        ExpectedPath := NativePath(AttachmentId);
        LibraryAssert.IsFalse(StoredInternally(AttachmentId), 'The stored mirror keeps Stored Internally false.');
        LibraryAssert.IsTrue(StoredExternally(AttachmentId), 'The stored mirror keeps Stored Externally true.');

        DocumentAttachment.GetBySystemId(AttachmentId);
        LibraryAssert.IsTrue(DocumentAttachment.HasContent(), 'A linked offload still reports content.');
        DocumentAttachment.GetAsTempBlob(TempBlob);
        TempBlob.CreateInStream(ContentIn);
        ContentIn.ReadText(ReadBack);
        LibraryAssert.AreEqual('X linked read bytes', ReadBack, 'The Bifrost link serves the bytes.');
        LibraryAssert.IsFalse(StoredInternally(AttachmentId), 'The read must not change the stored row.');
        LibraryAssert.AreEqual(ExpectedPath, NativePath(AttachmentId), 'The read must not change the external path.');

        DocumentAttachment."File Name" := 'read-then-modify';
        DocumentAttachment.Modify(true);
        DocumentAttachment.GetBySystemId(AttachmentId);
        LibraryAssert.AreEqual('read-then-modify', DocumentAttachment."File Name", 'The later modify is saved.');
        LibraryAssert.IsFalse(DocumentAttachment."Document Reference ID".HasValue(), 'The media stays empty.');
        LibraryAssert.IsFalse(StoredInternally(AttachmentId), 'Modify after a read must not persist Stored Internally.');
        LibraryAssert.IsTrue(StoredExternally(AttachmentId), 'Stored Externally stays set.');
        LibraryAssert.AreEqual(ExpectedPath, NativePath(AttachmentId), 'The external path stays unchanged.');
    end;

    [Test]
    procedure MicrosoftOffloadWithoutLink_StaysWithMicrosoftModule()
    var
        DocumentAttachment: Record "Document Attachment";
        Link: Record "Storage Attachment Link ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        ContentOut: OutStream;
        ContentIn: InStream;
        AttachmentId: Guid;
        ExpectedPath: Text;
    begin
        // [SCENARIO] A Microsoft-offloaded row with no Bifrost link is not claimed or rewritten by Bifrost.
        AssertExternalStorageFieldPresent();
        TempBlob.CreateOutStream(ContentOut);
        ContentOut.WriteText('X microsoft bytes');
        TempBlob.CreateInStream(ContentIn);
        DocumentAttachment.Init();
        DocumentAttachment.ImportFromStream(ContentIn, 'ms-only.txt');
        DocumentAttachment.Insert(true);
        DocumentAttachment."File Name" := 'ms-only';
        DocumentAttachment."File Extension" := 'txt';
        DocumentAttachment.Modify(true);
        AttachmentId := DocumentAttachment.SystemId;
        AttachmentMgt.SetNativeExternalStorageFields(AttachmentId, 'ORIGOBCTEST', 'bifrost-test/ms-only.txt');
        DocumentAttachment.GetBySystemId(AttachmentId);
        Clear(DocumentAttachment."Document Reference ID");
        DocumentAttachment.Modify(true);
        LibraryAssert.IsFalse(Link.Get(Database::"Document Attachment", AttachmentId), 'This row has no Bifrost link.');
        ExpectedPath := NativePath(AttachmentId);
        LibraryAssert.AreEqual('ORIGOBCTEST:bifrost-test/ms-only.txt', ExpectedPath, 'The Microsoft path is stored.');

        DocumentAttachment.GetBySystemId(AttachmentId);
        LibraryAssert.IsTrue(DocumentAttachment.HasContent(), 'The Microsoft module still claims an unlinked external row.');
        LibraryAssert.IsFalse(StoredInternally(AttachmentId), 'HasContent must not change the stored row.');
        DocumentAttachment."File Name" := 'ms-read-then-modify';
        DocumentAttachment.Modify(true);
        LibraryAssert.IsFalse(StoredInternally(AttachmentId), 'Modify must keep Stored Internally false.');
        LibraryAssert.IsTrue(StoredExternally(AttachmentId), 'Stored Externally stays set.');
        LibraryAssert.AreEqual(ExpectedPath, NativePath(AttachmentId), 'The Microsoft path stays unchanged.');
        DocumentAttachment.GetBySystemId(AttachmentId);
        LibraryAssert.IsFalse(DocumentAttachment."Document Reference ID".HasValue(), 'The media stays empty.');
    end;

    /// <summary>Arms this manually bound subscriber only for the named attachment fixture.</summary>
    /// <param name="AttachmentId">The fixture whose native mirror persistence must fail.</param>
    internal procedure ConfigureNativeModifyFailure(AttachmentId: Guid)
    begin
        NativeModifyFailureId := AttachmentId;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Document Attachment", 'OnAfterModifyEvent', '', false, false)]
    local procedure FailNativeMirrorModify(var Rec: Record "Document Attachment"; var xRec: Record "Document Attachment"; RunTrigger: Boolean)
    var
        RecRef: RecordRef;
        FailureErr: Label 'X75 native mirror persistence failure', Locked = true;
    begin
        if Rec.IsTemporary() or not RunTrigger or (Rec.SystemId <> NativeModifyFailureId) then
            exit;
        RecRef.GetTable(Rec);
        if RecRef.FieldExist(8750) then
            if RecRef.Field(8750).Value then
                Error(FailureErr);
        RecRef.Close();
    end;

    local procedure AssertExternalStorageFieldPresent()
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(Database::"Document Attachment");
        LibraryAssert.IsTrue(RecRef.FieldExist(8753), 'Field 8753 Stored Internally must exist.');
        RecRef.Close();
    end;

    local procedure OffloadLeafAttachment(FileName: Text; Content: Text): Guid
    var
        DocumentAttachment: Record "Document Attachment";
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        TempBlob: Codeunit "Temp Blob";
        Response: JsonObject;
        Request: JsonObject;
        ContentOut: OutStream;
        ContentIn: InStream;
        ResponseText: Text;
        Token: JsonToken;
        MockCodeTok: Label 'X75READ', Locked = true;
    begin
        MockState.Reset();
        if StorageSetup.Get(MockCodeTok) then
            StorageSetup.Delete();
        StorageSetup.Init();
        StorageSetup.Code := MockCodeTok;
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
        TempBlob.CreateOutStream(ContentOut);
        ContentOut.WriteText(Content);
        TempBlob.CreateInStream(ContentIn);
        DocumentAttachment.Init();
        DocumentAttachment.ImportFromStream(ContentIn, FileName + '.txt');
        DocumentAttachment.Insert(true);
        DocumentAttachment."File Name" := CopyStr(FileName, 1, MaxStrLen(DocumentAttachment."File Name"));
        DocumentAttachment."File Extension" := 'txt';
        DocumentAttachment.Modify(true);
        Request.Add('target', 'DocumentAttachment');
        Request.Add('systemId', Format(DocumentAttachment.SystemId, 0, 4));
        Request.Add('storageCode', MockCodeTok);
        ResponseText := DispatchOffloadResponse(Request);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'Offload must return JSON.');
        LibraryAssert.IsTrue(Response.Get('status', Token), 'Offload status');
        LibraryAssert.AreEqual('Success', Token.AsValue().AsText(), 'Offload must succeed.');
        exit(DocumentAttachment.SystemId);
    end;

    local procedure DispatchOffloadResponse(Request: JsonObject) ResponseText: Text
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseContentType: Text[100];
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Storage.Attachment.Offload", "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType, false);
        ResponseContent.GetSubText(ResponseText, 1);
    end;

    local procedure StoredInternally(AttachmentId: Guid): Boolean
    begin
        exit(NativeBoolean(AttachmentId, 8753));
    end;

    local procedure StoredExternally(AttachmentId: Guid): Boolean
    begin
        exit(NativeBoolean(AttachmentId, 8750));
    end;

    local procedure NativeBoolean(AttachmentId: Guid; FieldNo: Integer): Boolean
    var
        RecRef: RecordRef;
        Value: Boolean;
    begin
        RecRef.Open(Database::"Document Attachment");
        RecRef.GetBySystemId(AttachmentId);
        Value := RecRef.Field(FieldNo).Value;
        RecRef.Close();
        exit(Value);
    end;

    local procedure NativePath(AttachmentId: Guid): Text
    var
        RecRef: RecordRef;
        Value: Text;
    begin
        RecRef.Open(Database::"Document Attachment");
        RecRef.GetBySystemId(AttachmentId);
        Value := Format(RecRef.Field(8752).Value);
        RecRef.Close();
        exit(Value);
    end;

    local procedure DispatchNativeOffload(Request: JsonObject)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseContentType: Text[100];
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Storage.Attachment.Offload", "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType, false);
    end;
}
