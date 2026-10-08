namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Foundation.Attachment;
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
}
