namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost.Attachments;
using System.Reflection;

/// <summary>
/// BC 28 native external-storage field mirror (#11). The Microsoft extension is optional, so the
/// tests assert the no-op path when its fields are absent and the write path when they exist.
/// </summary>
codeunit 96217 "Storage Native Fields Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

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
        RecRef: RecordRef;
        StoredExternallyFld: FieldRef;
    begin
        // [SCENARIO] AC01/AC02: when fields 8750-8753 exist, offload sets them and restore clears them.
        RecRef.Open(Database::"Document Attachment");
        if not RecRef.FieldExist(8750) then begin
            RecRef.Close();
            exit;
        end;
        RecRef.Close();

        DocumentAttachment.Init();
        DocumentAttachment."File Name" := 'native-mirror.txt';
        DocumentAttachment.Insert(true);

        AttachmentMgt.SetNativeExternalStorageFields(DocumentAttachment.SystemId, 'ORIGOBCTEST', 'bifrost-test/native-mirror.txt');
        RecRef.Open(Database::"Document Attachment");
        RecRef.GetBySystemId(DocumentAttachment.SystemId);
        StoredExternallyFld := RecRef.Field(8750);
        LibraryAssert.IsTrue(StoredExternallyFld.Value, 'Stored Externally should be set.');
        LibraryAssert.AreEqual('ORIGOBCTEST:bifrost-test/native-mirror.txt', Format(RecRef.Field(8752).Value), 'External File Path');
        RecRef.Close();

        AttachmentMgt.ClearNativeExternalStorageFields(DocumentAttachment.SystemId);
        RecRef.Open(Database::"Document Attachment");
        RecRef.GetBySystemId(DocumentAttachment.SystemId);
        LibraryAssert.IsFalse(RecRef.Field(8750).Value, 'Stored Externally should be cleared.');
        LibraryAssert.AreEqual('', Format(RecRef.Field(8752).Value), 'External File Path should be blank.');
        RecRef.Close();
        DocumentAttachment.Delete(true);
    end;
}
