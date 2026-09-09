namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.FixedAssets.FixedAsset;
using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Text;
using System.Utilities;

/// <summary>
/// Tests for <c>Storage.Attachment.CreateForRecord</c> — creating a <c>Document Attachment</c>
/// on an arbitrary record from each of the three content sources, and the guards around
/// addressing the host record.
/// </summary>
codeunit 96206 "Storage Attach Record Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'MOCK', Locked = true;
        TestCustNoTok: Label 'BIFTS-REC-TST', Locked = true;
        TestFANoTok: Label 'BIFTS-REC-FA', Locked = true;

    [Test]
    procedure CreateForRecord_FromBase64_OnCustomer()
    var
        DocAttachment: Record "Document Attachment";
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] Inline base64 content becomes a document attachment on a customer.
        Initialize();

        // [GIVEN] A request addressing the customer by its number
        RequestJson.Add('tableId', Database::Customer);
        RequestJson.Add('no', TestCustNoTok);
        RequestJson.Add('fileName', 'contract.txt');
        RequestJson.Add('content', ToBase64('hello world'));

        // [WHEN] The attachment is created
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", RequestJson);

        // [THEN] The call succeeds and the attachment hangs on the customer
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Creating from base64 should succeed.');
        LibraryAssert.AreEqual('contract.txt', ReadDataText(TempArgument.GetResponseJson(), 'fileName'), 'The response should echo the file name.');

        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", TestCustNoTok);
        LibraryAssert.AreEqual(1, DocAttachment.Count(), 'One attachment should exist on the customer.');
        DocAttachment.FindFirst();
        LibraryAssert.AreEqual('contract', DocAttachment."File Name", 'The file name is stored without its extension.');
        LibraryAssert.AreEqual('txt', DocAttachment."File Extension", 'The extension is split off the file name.');
        DocAttachment.CalcFields("Offloaded ori");
        LibraryAssert.IsFalse(DocAttachment."Offloaded ori", 'Inline content stays in the database.');
    end;

    [Test]
    procedure CreateForRecord_OnFixedAsset()
    var
        DocAttachment: Record "Document Attachment";
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A fixed asset carries an attachment just like a customer does.
        Initialize();

        // [GIVEN] A request addressing the fixed asset by table name
        RequestJson.Add('tableName', 'Fixed Asset');
        RequestJson.Add('no', TestFANoTok);
        RequestJson.Add('fileName', 'deed.pdf');
        RequestJson.Add('content', ToBase64('purchase deed'));

        // [WHEN] The attachment is created
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", RequestJson);

        // [THEN] It is attached to the fixed asset
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Creating on a fixed asset should succeed.');

        DocAttachment.SetRange("Table ID", Database::"Fixed Asset");
        DocAttachment.SetRange("No.", TestFANoTok);
        LibraryAssert.AreEqual(1, DocAttachment.Count(), 'The fixed asset should carry one attachment.');
    end;

    [Test]
    procedure CreateForRecord_ByRecordSystemId()
    var
        Customer: Record Customer;
        DocAttachment: Record "Document Attachment";
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A record can be addressed by SystemId instead of by its number.
        Initialize();
        Customer.Get(TestCustNoTok);

        // [GIVEN] A request carrying the customer's SystemId
        RequestJson.Add('tableId', Database::Customer);
        RequestJson.Add('recordSystemId', Format(Customer.SystemId, 0, 4));
        RequestJson.Add('fileName', 'by-system-id.txt');
        RequestJson.Add('content', ToBase64('located by system id'));

        // [WHEN] The attachment is created
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", RequestJson);

        // [THEN] The attachment lands on that customer's number
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Addressing by SystemId should succeed.');
        LibraryAssert.AreEqual(TestCustNoTok, ReadDataText(TempArgument.GetResponseJson(), 'no'), 'The response should carry the resolved record number.');

        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", TestCustNoTok);
        LibraryAssert.AreEqual(1, DocAttachment.Count(), 'One attachment should exist on the customer.');
    end;

    [Test]
    procedure CreateForRecord_CopiesFromIncomingDocument()
    var
        IncDocAttachment: Record "Incoming Document Attachment";
        DocAttachment: Record "Document Attachment";
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A file that is already in Business Central is copied onto a record without
        // ever crossing the wire, and without a storage connection.
        Initialize();

        // [GIVEN] An incoming document attachment
        CreateIncDocAttachment('kaupsamningur.pdf', 'contract bytes', IncDocAttachment);

        // [WHEN] It is copied onto the customer, with no fileName supplied
        RequestJson.Add('tableId', Database::Customer);
        RequestJson.Add('no', TestCustNoTok);
        RequestJson.Add('sourceTarget', 'IncomingDocument');
        RequestJson.Add('sourceSystemId', Format(IncDocAttachment.SystemId, 0, 4));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", RequestJson);

        // [THEN] The attachment is created and inherits the source file name
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Copying an existing attachment should succeed.');
        LibraryAssert.AreEqual('kaupsamningur.pdf', ReadDataText(TempArgument.GetResponseJson(), 'fileName'), 'The source file name should carry over.');

        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", TestCustNoTok);
        DocAttachment.FindFirst();
        LibraryAssert.AreEqual('kaupsamningur', DocAttachment."File Name", 'The copied attachment keeps its name.');
        LibraryAssert.IsTrue(DocAttachment.HasContent(), 'The copied attachment should carry content.');
    end;

    [Test]
    procedure CreateForRecord_FromStorage_IsBornOffloaded()
    var
        DocAttachment: Record "Document Attachment";
        TempArgument: Record "Message Argument ori";
        MockState: Codeunit "Storage Mock State";
        RequestJson: JsonObject;
        StoragePath: Text;
    begin
        // [SCENARIO] A file already in storage becomes an attachment that is served from storage,
        // with no copy of the bytes in the database.
        Initialize();

        // [GIVEN] A file sitting in storage
        StoragePath := 'bifrost-uploads/large.pdf';
        MockState.PutFile(StoragePath, ToBase64('a large file'));

        // [WHEN] It is attached to the customer
        RequestJson.Add('tableId', Database::Customer);
        RequestJson.Add('no', TestCustNoTok);
        RequestJson.Add('fileName', 'large.pdf');
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', StoragePath);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", RequestJson);

        // [THEN] The attachment reports itself as offloaded
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Creating from storage should succeed.');

        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", TestCustNoTok);
        DocAttachment.FindFirst();
        DocAttachment.CalcFields("Offloaded ori");
        LibraryAssert.IsTrue(DocAttachment."Offloaded ori", 'A storage-sourced attachment should be born offloaded.');
        LibraryAssert.IsTrue(DocAttachment.HasContent(), 'The offloaded attachment should still report content, served from storage.');
    end;

    [Test]
    procedure CreateForRecord_RejectsTwoContentSources()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] Ambiguity about where the bytes come from is refused rather than guessed at.
        Initialize();

        RequestJson.Add('tableId', Database::Customer);
        RequestJson.Add('no', TestCustNoTok);
        RequestJson.Add('fileName', 'ambiguous.txt');
        RequestJson.Add('content', ToBase64('inline'));
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', 'somewhere/else.txt');

        asserterror ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", RequestJson);
    end;

    [Test]
    procedure CreateForRecord_RejectsUnknownRecord()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] An attachment cannot be hung on a record that does not exist.
        Initialize();

        RequestJson.Add('tableId', Database::Customer);
        RequestJson.Add('no', 'NO-SUCH-CUSTOMER');
        RequestJson.Add('fileName', 'orphan.txt');
        RequestJson.Add('content', ToBase64('orphan'));

        asserterror ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.CreateForRecord", RequestJson);
    end;

    // ————— Helpers —————

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        Customer: Record Customer;
        FixedAsset: Record "Fixed Asset";
        DocAttachment: Record "Document Attachment";
        AttachmentLink: Record "Storage Attachment Link ori";
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.Reset();
        StorageSetup.DeleteAll();
        StorageSetup.Init();
        StorageSetup."Code" := MockCodeTok;
        StorageSetup.Description := 'Mock storage connection';
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();

        if not Customer.Get(TestCustNoTok) then begin
            Customer.Init();
            Customer."No." := TestCustNoTok;
            Customer.Insert();
        end;

        if not FixedAsset.Get(TestFANoTok) then begin
            FixedAsset.Init();
            FixedAsset."No." := TestFANoTok;
            FixedAsset.Insert();
        end;

        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", TestCustNoTok);
        DocAttachment.DeleteAll();
        DocAttachment.Reset();
        DocAttachment.SetRange("Table ID", Database::"Fixed Asset");
        DocAttachment.SetRange("No.", TestFANoTok);
        DocAttachment.DeleteAll();
        AttachmentLink.DeleteAll();
    end;

    local procedure CreateIncDocAttachment(FileName: Text; Content: Text; var Attachment: Record "Incoming Document Attachment")
    var
        IncomingDocument: Record "Incoming Document";
        TempBlob: Codeunit "Temp Blob";
        EntryNo: Integer;
        OutStr: OutStream;
        InStr: InStream;
        Extension: Text;
        DotPos: Integer;
    begin
        EntryNo := IncomingDocument.CreateIncomingDocument(CopyStr(FileName, 1, 100), '');
        IncomingDocument.Get(EntryNo);
        TempBlob.CreateOutStream(OutStr);
        OutStr.WriteText(Content);
        TempBlob.CreateInStream(InStr);
        DotPos := FileName.LastIndexOf('.');
        if DotPos > 0 then
            Extension := FileName.Substring(DotPos + 1)
        else
            Extension := 'txt';
        IncomingDocument.AddAttachmentFromStream(Attachment, FileName, Extension, InStr);
    end;

    local procedure ToBase64(Content: Text): Text
    var
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        OutStr: OutStream;
        InStr: InStream;
    begin
        TempBlob.CreateOutStream(OutStr);
        OutStr.WriteText(Content);
        TempBlob.CreateInStream(InStr);
        exit(Base64Convert.ToBase64(InStr));
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
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(true);
        TempArgument.SetResponseJson(ResponseJson);
    end;

    local procedure ReadText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadDataText(ResponseJson: JsonObject; PropertyName: Text): Text
    var
        DataToken: JsonToken;
    begin
        if not ResponseJson.Get('data', DataToken) then
            exit('');
        if not DataToken.IsObject() then
            exit('');
        exit(ReadText(DataToken.AsObject(), PropertyName));
    end;
}
