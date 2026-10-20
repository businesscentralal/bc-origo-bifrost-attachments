namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.TestLibraries.Utilities;

/// <summary>Issue166: explicit storage replacement and conservative attachment file ownership in both languages.</summary>
codeunit 96261 "Storage Write166 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "DataExch Fixture ori";
        LibraryAssert: Codeunit "Library Assert";
        MockState: Codeunit "Storage Mock State";

    [Test]
    procedure FileCreateConsent_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        FileCreateConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure FileCreateConsent_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        FileCreateConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure UploadCommitConsent_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        UploadCommitConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure UploadCommitConsent_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        UploadCommitConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure DefinitionExportConsent_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        DefinitionExportConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure DefinitionExportConsent_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        DefinitionExportConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure ExportRunConsent_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        ExportRunConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure ExportRunConsent_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        ExportRunConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure UploadDataExchangeConsent_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        UploadDataExchangeConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure UploadDataExchangeConsent_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        UploadDataExchangeConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure OffloadConsent_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        OffloadConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure OffloadConsent_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        OffloadConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure LinkedSourceSurvivesRestore_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        LinkedSourceSurvivesRestore();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure LinkedSourceSurvivesRestore_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        LinkedSourceSurvivesRestore();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure LinkedSourceSurvivesDelete_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        LinkedSourceSurvivesDelete();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure LinkedSourceSurvivesDelete_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        LinkedSourceSurvivesDelete();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure FreshOffloadDeletesOwnedFile_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        FreshOffloadDeletesOwnedFile();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure FreshOffloadDeletesOwnedFile_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        FreshOffloadDeletesOwnedFile();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure InvalidOverwriteRefused_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        InvalidOverwriteRefused();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure InvalidOverwriteRefused_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        InvalidOverwriteRefused();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure LinkedFileProtectedWithConsent_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        LinkedFileProtectedWithConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure LinkedFileProtectedWithConsent_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        LinkedFileProtectedWithConsent();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure CommitToRecordDoesNotWriteStorage_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        CommitToRecordDoesNotWriteStorage();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure CommitToRecordDoesNotWriteStorage_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        CommitToRecordDoesNotWriteStorage();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure CreateLinkedSourceSurvivesRestore_1033()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1033);
        CreateLinkedSourceSurvivesRestore();
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure CreateLinkedSourceSurvivesRestore_1039()
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage(1039);
        CreateLinkedSourceSurvivesRestore();
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CreateLinkedSourceSurvivesRestore()
    var
        Request: JsonObject;
        Response: JsonObject;
        AttachmentId: Text;
    begin
        Initialize();
        SeedDestination();
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'existing.txt');
        Request.Add('fileName', 'existing.txt');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Attachment.CreateLinked", Request);
        AssertSuccess(Response);
        AttachmentId := Fixture.ReadText(Fixture.Data(Response), 'systemId');
        Clear(Request);
        Request.Add('target', 'IncomingDocument');
        Request.Add('systemId', AttachmentId);
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Attachment.Restore", Request));
        LibraryAssert.AreEqual(Fixture.Encode('original bytes'), MockState.GetFileContent('existing.txt'), 'Restoring a linked incoming attachment preserves its source file.');
    end;

    local procedure FileCreateConsent()
    var
        Request: JsonObject;
    begin
        Initialize();
        SeedDestination();
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'existing.txt');
        Request.Add('contentBase64', Fixture.Encode('replacement'));
        AssertConsent("Message Type ori"::"Storage.File.Create", Request);
        LibraryAssert.AreEqual(Fixture.Encode('replacement'), MockState.GetFileContent('existing.txt'), 'Explicit replacement writes the requested bytes.');
    end;

    local procedure UploadCommitConsent()
    var
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        Request: JsonObject;
        UploadId: Guid;
    begin
        Initialize();
        SeedDestination();
        Evaluate(UploadId, BeginUpload('replacement'));
        Request.Add('uploadId', Format(UploadId));
        AssertRefusal(Fixture.Dispatch("Message Type ori"::"Storage.Upload.Commit", Request));
        Session.Get(UploadId);
        LibraryAssert.AreEqual(Session.Status::Open, Session.Status, 'Refusal leaves the upload open.');
        Chunk.SetRange("Upload Id", UploadId);
        LibraryAssert.AreEqual(1, Chunk.Count(), 'Refusal preserves the reusable chunk.');
        Request.Add('overwrite', true);
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Upload.Commit", Request));
        LibraryAssert.AreEqual(Fixture.Encode('replacement'), MockState.GetFileContent('existing.txt'), 'Committed content replaces the file only with consent.');
    end;

    local procedure DefinitionExportConsent()
    var
        Request: JsonObject;
    begin
        Initialize();
        SeedDestination();
        Request.Add('code', Fixture.CreateImportDefinition(0));
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'existing.txt');
        AssertConsent("Message Type ori"::"DataExchange.Definition.Export", Request);
        LibraryAssert.IsTrue(Fixture.Decode(MockState.GetFileContent('existing.txt')).Contains('DataExchDef'), 'Replacement is exported XML.');
    end;

    local procedure ExportRunConsent()
    var
        DataExch: Record "Data Exch.";
        Request: JsonObject;
        CustomerNos: List of [Code[20]];
        BeforeCount: Integer;
    begin
        Initialize();
        SeedDestination();
        CustomerNos := Fixture.CreateCustomers(1, 'Issue166 export');
        Request.Add('dataExchDefCode', Fixture.CreateExportDefinition());
        Request.Add('tableId', Database::Customer);
        Request.Add('tableView', 'WHERE(No.=FILTER(' + CustomerNos.Get(1) + '))');
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'existing.txt');
        BeforeCount := DataExch.Count();
        AssertRefusal(Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request));
        LibraryAssert.AreEqual(BeforeCount, DataExch.Count(), 'Refusal creates no export entry.');
        Request.Add('overwrite', true);
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"DataExchange.Export.Run", Request));
        LibraryAssert.IsTrue(Fixture.Decode(MockState.GetFileContent('existing.txt')).Contains(CustomerNos.Get(1)), 'Consented export contains only the selected fixture.');
    end;

    local procedure UploadDataExchangeConsent()
    var
        DataExch: Record "Data Exch.";
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        Initialize();
        SeedDestination();
        Request.Add('uploadId', BeginUpload(Fixture.TwoLineCsv(false)));
        Request.Add('dataExchDefCode', Fixture.CreateImportDefinition(0));
        Request.Add('keepFileInStorage', true);
        BeforeCount := DataExch.Count();
        AssertRefusal(Fixture.Dispatch("Message Type ori"::"Storage.Upload.CommitToDataExchange", Request));
        LibraryAssert.AreEqual(BeforeCount, DataExch.Count(), 'Refusal creates no import entry.');
        Request.Add('overwrite', true);
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Upload.CommitToDataExchange", Request));
        LibraryAssert.AreEqual(Fixture.Encode(Fixture.TwoLineCsv(false)), MockState.GetFileContent('existing.txt'), 'Consented retained file contains uploaded CSV.');
    end;

    local procedure OffloadConsent()
    var
        Link: Record "Storage Attachment Link ori";
        DocumentAttachment: Record "Document Attachment";
        Request: JsonObject;
        Response: JsonObject;
        AttachmentId: Guid;
    begin
        Initialize();
        MockState.PutFile('collision/existing.txt', Fixture.Encode('original bytes'));
        AttachmentId := CreateAttachment(false);
        Request := AttachmentRequest(AttachmentId);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('folderPath', 'collision');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Attachment.Offload", Request);
        AssertRefusalAt(Response, 'collision/existing.txt');
        LibraryAssert.IsFalse(Link.Get(Database::"Document Attachment", AttachmentId), 'Refusal creates no link.');
        DocumentAttachment.GetBySystemId(AttachmentId);
        LibraryAssert.IsTrue(DocumentAttachment.HasContent(), 'Refusal preserves the local content.');
        Request.Add('overwrite', true);
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Attachment.Offload", Request));
        Link.Get(Database::"Document Attachment", AttachmentId);
        LibraryAssert.IsFalse(Link."Created Storage File", 'Explicit replacement does not acquire deletion ownership.');
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Attachment.Restore", AttachmentRequest(AttachmentId)));
        LibraryAssert.AreEqual(Fixture.Encode('attachment bytes'), MockState.GetFileContent('collision/existing.txt'), 'Restore preserves an explicitly overwritten pre-existing file.');
    end;

    local procedure LinkedSourceSurvivesRestore()
    var
        DocumentAttachment: Record "Document Attachment";
        Link: Record "Storage Attachment Link ori";
        AttachmentId: Guid;
    begin
        Initialize();
        SeedDestination();
        AttachmentId := CreateAttachment(true);
        Link.Get(Database::"Document Attachment", AttachmentId);
        LibraryAssert.IsFalse(Link."Created Storage File", 'Linking an existing file does not acquire deletion ownership.');
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Attachment.Restore", AttachmentRequest(AttachmentId)));
        LibraryAssert.AreEqual(Fixture.Encode('original bytes'), MockState.GetFileContent('existing.txt'), 'Restore preserves the original external file.');
        LibraryAssert.IsFalse(Link.Get(Database::"Document Attachment", AttachmentId), 'Restore removes the link.');
        DocumentAttachment.GetBySystemId(AttachmentId);
        LibraryAssert.IsTrue(DocumentAttachment.HasContent(), 'Restored attachment has local content.');
    end;

    local procedure LinkedSourceSurvivesDelete()
    var
        DocumentAttachment: Record "Document Attachment";
    begin
        Initialize();
        SeedDestination();
        DocumentAttachment.GetBySystemId(CreateAttachment(true));
        DocumentAttachment.Delete(true);
        LibraryAssert.AreEqual(Fixture.Encode('original bytes'), MockState.GetFileContent('existing.txt'), 'Deleting a linked attachment preserves the source.');
    end;

    local procedure FreshOffloadDeletesOwnedFile()
    var
        Link: Record "Storage Attachment Link ori";
        Request: JsonObject;
        Response: JsonObject;
        AttachmentId: Guid;
        Path: Text;
    begin
        Initialize();
        AttachmentId := CreateAttachment(false);
        Request := AttachmentRequest(AttachmentId);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('folderPath', 'owned');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Attachment.Offload", Request);
        AssertSuccess(Response);
        Path := Fixture.ReadText(Fixture.Data(Response), 'path');
        Link.Get(Database::"Document Attachment", AttachmentId);
        LibraryAssert.IsTrue(Link."Created Storage File", 'New offload records deletion ownership.');
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Attachment.Restore", AttachmentRequest(AttachmentId)));
        LibraryAssert.IsFalse(MockState.HasFile(Path), 'Restore deletes the newly-created owned file.');
    end;

    local procedure InvalidOverwriteRefused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Initialize();
        SeedDestination();
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'existing.txt');
        Request.Add('contentBase64', Fixture.Encode('replacement'));
        Request.Add('overwrite', 'yes');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.File.Create", Request);
        LibraryAssert.AreEqual('Error', Fixture.ReadText(Response, 'status'), 'Overwrite must be a boolean.');
        LibraryAssert.AreEqual(Fixture.Encode('original bytes'), MockState.GetFileContent('existing.txt'), 'Invalid consent never changes bytes.');
        LibraryAssert.AreEqual(0, MockState.GetWriteCalls(), 'Invalid consent never calls the writer.');
    end;

    local procedure LinkedFileProtectedWithConsent()
    var
        Request: JsonObject;
    begin
        Initialize();
        SeedDestination();
        CreateAttachment(true);
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'existing.txt');
        Request.Add('contentBase64', Fixture.Encode('replacement'));
        Request.Add('overwrite', true);
        AssertRefusal(Fixture.Dispatch("Message Type ori"::"Storage.File.Create", Request));
    end;

    local procedure CommitToRecordDoesNotWriteStorage()
    var
        Request: JsonObject;
        CustomerNos: List of [Code[20]];
    begin
        Initialize();
        SeedDestination();
        CustomerNos := Fixture.CreateCustomers(1, 'Issue166 upload');
        Request.Add('uploadId', BeginUpload('attachment bytes'));
        Request.Add('tableId', Database::Customer);
        Request.Add('no', CustomerNos.Get(1));
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Upload.CommitToRecord", Request));
        LibraryAssert.AreEqual(Fixture.Encode('original bytes'), MockState.GetFileContent('existing.txt'), 'CommitToRecord writes only BC content even when its session names storage.');
        LibraryAssert.AreEqual(0, MockState.GetWriteCalls(), 'No storage write occurs.');
    end;

    local procedure Initialize()
    var
        Link: Record "Storage Attachment Link ori";
    begin
        Link.DeleteAll();
        Fixture.InitializeStorage();
    end;

    local procedure SeedDestination()
    begin
        MockState.PutFile('existing.txt', Fixture.Encode('original bytes'));
    end;

    local procedure AssertSuccess(Response: JsonObject)
    begin
        LibraryAssert.AreEqual('Success', Fixture.ReadText(Response, 'status'), 'Expected success: ' + Fixture.ReadText(Response, 'error'));
    end;

    local procedure AssertRefusal(Response: JsonObject)
    begin
        AssertRefusalAt(Response, 'existing.txt');
    end;

    local procedure AssertRefusalAt(Response: JsonObject; Path: Text)
    begin
        LibraryAssert.AreEqual('Error', Fixture.ReadText(Response, 'status'), 'Existing destination must be refused.');
        LibraryAssert.AreEqual('PreconditionFailed', Fixture.ReadText(Response, 'code'), 'Stable precondition refusal.');
        LibraryAssert.AreEqual('path', Fixture.ReadText(Response, 'parameter'), 'The destination path is identified.');
        LibraryAssert.AreNotEqual('', Fixture.ReadText(Response, 'nextStep'), 'The caller gets an actionable next step.');
        LibraryAssert.AreEqual(Fixture.Encode('original bytes'), MockState.GetFileContent(Path), 'Refusal preserves original bytes.');
        LibraryAssert.AreEqual(0, MockState.GetWriteCalls(), 'Refusal happens before any external write.');
    end;

    local procedure AssertConsent(MessageType: Enum "Message Type ori"; Request: JsonObject)
    begin
        AssertRefusal(Fixture.Dispatch(MessageType, Request));
        Request.Add('overwrite', false);
        AssertRefusal(Fixture.Dispatch(MessageType, Request));
        Request.Replace('overwrite', true);
        AssertSuccess(Fixture.Dispatch(MessageType, Request));
        LibraryAssert.AreEqual(1, MockState.GetWriteCalls(), 'Exactly one consented write occurs.');
    end;

    local procedure BeginUpload(Content: Text): Text
    var
        Request: JsonObject;
        Response: JsonObject;
        UploadId: Text;
    begin
        Request.Add('storageCode', Fixture.StorageCode());
        Request.Add('path', 'existing.txt');
        Request.Add('fileName', 'existing.txt');
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Upload.Begin", Request);
        AssertSuccess(Response);
        UploadId := Fixture.ReadText(Fixture.Data(Response), 'uploadId');
        Clear(Request);
        Request.Add('uploadId', UploadId);
        Request.Add('sequence', 1);
        Request.Add('contentBase64', Fixture.Encode(Content));
        AssertSuccess(Fixture.Dispatch("Message Type ori"::"Storage.Upload.Append", Request));
        exit(UploadId);
    end;

    local procedure CreateAttachment(FromStorage: Boolean) AttachmentId: Guid
    var
        Request: JsonObject;
        Response: JsonObject;
        CustomerNos: List of [Code[20]];
    begin
        CustomerNos := Fixture.CreateCustomers(1, 'Issue166 attachment');
        Request.Add('tableId', Database::Customer);
        Request.Add('no', CustomerNos.Get(1));
        Request.Add('fileName', 'existing.txt');
        if FromStorage then begin
            Request.Add('storageCode', Fixture.StorageCode());
            Request.Add('path', 'existing.txt');
        end else
            Request.Add('contentBase64', Fixture.Encode('attachment bytes'));
        Response := Fixture.Dispatch("Message Type ori"::"Storage.Attachment.CreateForRecord", Request);
        AssertSuccess(Response);
        Evaluate(AttachmentId, Fixture.ReadText(Fixture.Data(Response), 'systemId'));
    end;

    local procedure AttachmentRequest(AttachmentId: Guid) Request: JsonObject
    begin
        Request.Add('target', 'DocumentAttachment');
        Request.Add('systemId', Format(AttachmentId));
    end;
}
