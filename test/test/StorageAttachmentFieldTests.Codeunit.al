namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Utilities;

/// <summary>
/// Tests for the <c>Offloaded ori</c> FlowField on <c>Incoming Document Attachment</c>
/// and <c>Document Attachment</c>, and for discovering offload candidates via
/// <c>Data.Records.Get</c> with a tableView filter on the field.
/// </summary>
codeunit 96203 "Storage Attachment Field Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'MOCK', Locked = true;
        TestCustNoTok: Label 'BIFTS-FLD-TST', Locked = true;

    // ————— FlowField: Incoming Document Attachment —————

    [Test]
    procedure Offloaded_FalseForNewIncDocAttachment()
    var
        Attachment: Record "Incoming Document Attachment";
    begin
        // [SCENARIO] A new incoming document attachment that has not been offloaded reports Offloaded ori = false.
        Initialize();

        // [GIVEN] An incoming document attachment that has not been offloaded
        CreateIncDocAttachment('not-offloaded.txt', 'content', Attachment);

        // [WHEN] The FlowField is calculated
        Attachment.CalcFields("Offloaded ori");

        // [THEN] The field is false
        LibraryAssert.IsFalse(Attachment."Offloaded ori", 'A new attachment should not be marked as offloaded.');
    end;

    [Test]
    procedure Offloaded_TrueAfterOffload_IncDoc()
    var
        Attachment: Record "Incoming Document Attachment";
        TempArgument: Record "Message Argument ori";
    begin
        // [SCENARIO] After offloading, the Bifrost Offloaded FlowField reports true.
        Initialize();

        // [GIVEN] An incoming document attachment
        CreateIncDocAttachment('to-offload.txt', 'offload me', Attachment);

        // [WHEN] The attachment is offloaded
        OffloadAttachment(TempArgument, 'IncomingDocument', Attachment.SystemId);
        Attachment.GetBySystemId(Attachment.SystemId);
        Attachment.CalcFields("Offloaded ori");

        // [THEN] The FlowField reflects the link
        LibraryAssert.IsTrue(Attachment."Offloaded ori", 'An offloaded attachment should report Bifrost Offloaded = true.');
    end;

    [Test]
    procedure Offloaded_FalseAfterRestore_IncDoc()
    var
        Attachment: Record "Incoming Document Attachment";
        TempArgument: Record "Message Argument ori";
    begin
        // [SCENARIO] After restoring, the Bifrost Offloaded FlowField goes back to false.
        Initialize();

        // [GIVEN] An offloaded incoming document attachment
        CreateIncDocAttachment('restore-me.txt', 'restore me', Attachment);
        OffloadAttachment(TempArgument, 'IncomingDocument', Attachment.SystemId);

        // [WHEN] The attachment is restored
        Clear(TempArgument);
        RestoreAttachment(TempArgument, 'IncomingDocument', Attachment.SystemId);
        Attachment.GetBySystemId(Attachment.SystemId);
        Attachment.CalcFields("Offloaded ori");

        // [THEN] The FlowField is false again
        LibraryAssert.IsFalse(Attachment."Offloaded ori", 'A restored attachment should report Bifrost Offloaded = false.');
    end;

    // ————— FlowField: Document Attachment —————

    [Test]
    procedure Offloaded_FalseForNewDocAttachment()
    var
        DocAttachment: Record "Document Attachment";
    begin
        // [SCENARIO] A new document attachment that has not been offloaded reports Offloaded ori = false.
        Initialize();

        // [GIVEN] A document attachment that has not been offloaded
        CreateDocAttachment('not-offloaded.txt', 'content', DocAttachment);

        // [WHEN] The FlowField is calculated
        DocAttachment.CalcFields("Offloaded ori");

        // [THEN] The field is false
        LibraryAssert.IsFalse(DocAttachment."Offloaded ori", 'A new document attachment should not be marked as offloaded.');
    end;

    [Test]
    procedure Offloaded_TrueAfterOffload_DocAttach()
    var
        DocAttachment: Record "Document Attachment";
        TempArgument: Record "Message Argument ori";
    begin
        // [SCENARIO] After offloading a document attachment, the Bifrost Offloaded FlowField reports true.
        Initialize();

        // [GIVEN] A document attachment
        CreateDocAttachment('offload-doc.txt', 'offload me', DocAttachment);

        // [WHEN] The attachment is offloaded
        OffloadAttachment(TempArgument, 'DocumentAttachment', DocAttachment.SystemId);
        DocAttachment.GetBySystemId(DocAttachment.SystemId);
        DocAttachment.CalcFields("Offloaded ori");

        // [THEN] The FlowField reflects the link
        LibraryAssert.IsTrue(DocAttachment."Offloaded ori", 'An offloaded document attachment should report Bifrost Offloaded = true.');
    end;

    // ————— Data.Records.Get with Offloaded ori filter —————

    [Test]
    procedure DataRecordsGet_IncDoc_FiltersByOffloaded()
    var
        Att1: Record "Incoming Document Attachment";
        Att2: Record "Incoming Document Attachment";
        Att3: Record "Incoming Document Attachment";
        TempArgument: Record "Message Argument ori";
        TempOffloadArg: Record "Message Argument ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ResultArray: JsonArray;
        EntryNo: Integer;
    begin
        // [SCENARIO] Data.Records.Get with Offloaded ori=CONST(0) returns only non-offloaded incoming document attachments.
        Initialize();

        // [GIVEN] An incoming document with 3 attachments, 1 offloaded
        EntryNo := CreateIncDocEntry('drg-inc-test');
        CreateIncDocAttachmentForEntry(EntryNo, 'keep1.txt', 'a', Att1);
        CreateIncDocAttachmentForEntry(EntryNo, 'offloaded.txt', 'b', Att2);
        CreateIncDocAttachmentForEntry(EntryNo, 'keep2.txt', 'c', Att3);
        OffloadAttachment(TempOffloadArg, 'IncomingDocument', Att2.SystemId);

        // [WHEN] Data.Records.Get filters by this entry and Offloaded ori = false
        RequestJson.Add('tableName', 'Incoming Document Attachment');
#pragma warning disable AA0217
        RequestJson.Add('tableView', StrSubstNo('WHERE(Incoming Document Entry No.=CONST(%1),Offloaded ori=CONST(0))', EntryNo));
#pragma warning restore AA0217
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Data.Records.Get", RequestJson);

        // [THEN] Only the 2 non-offloaded attachments are returned
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Data.Records.Get should succeed.');
        ResultArray := GetResultArray(ResponseJson);
        LibraryAssert.AreEqual(2, ResultArray.Count(), 'Only non-offloaded attachments should be returned.');
    end;

    [Test]
    procedure DataRecordsGet_DocAttach_FiltersByOffloaded()
    var
        DocAtt1: Record "Document Attachment";
        DocAtt2: Record "Document Attachment";
        TempArgument: Record "Message Argument ori";
        TempOffloadArg: Record "Message Argument ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ResultArray: JsonArray;
    begin
        // [SCENARIO] Data.Records.Get with Offloaded ori=CONST(0) returns only non-offloaded document attachments.
        Initialize();

        // [GIVEN] A customer with 2 document attachments, 1 offloaded
        CreateDocAttachment('keep-doc.txt', 'keep', DocAtt1);
        CreateDocAttachment('offload-doc2.txt', 'offload', DocAtt2);
        OffloadAttachment(TempOffloadArg, 'DocumentAttachment', DocAtt2.SystemId);

        // [WHEN] Data.Records.Get filters by this customer and Offloaded ori = false
        RequestJson.Add('tableName', 'Document Attachment');
#pragma warning disable AA0217
        RequestJson.Add('tableView', StrSubstNo('WHERE(Table ID=CONST(%1),No.=CONST(%2),Offloaded ori=CONST(0))', Database::Customer, TestCustNoTok));
#pragma warning restore AA0217
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Data.Records.Get", RequestJson);

        // [THEN] Only the non-offloaded attachment is returned
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Data.Records.Get should succeed.');
        ResultArray := GetResultArray(ResponseJson);
        LibraryAssert.AreEqual(1, ResultArray.Count(), 'Only the non-offloaded document attachment should be returned.');
    end;

    // ————— Help documentation —————

    [Test]
    procedure OffloadHelp_DocumentsCandidateDiscovery()
    var
        TempArgument: Record "Message Argument ori";
        MsgInterface: Interface "Msg Interface ori";
        HelpText: Text;
    begin
        // [SCENARIO] The Storage.Attachment.Offload help documents how to find offload candidates using Data.Records.Get.
        TempArgument.Init();
        TempArgument."Type" := TempArgument."Type"::"Storage.Attachment.Offload";
        TempArgument.Insert(true);
        MsgInterface := TempArgument.GetMessageTypeInterface();
        MsgInterface.GetMessageHelpAsMarkdownDocument(TempArgument);
        HelpText := TempArgument.GetResponseText();

        // [THEN] The help explains the Offloaded ori field and the get_records filter
        LibraryAssert.IsTrue(HelpText.Contains('Offloaded ori'), 'The help should reference the Offloaded ori field.');
        LibraryAssert.IsTrue(HelpText.Contains('get_records'), 'The help should reference the get_records tool for candidate discovery.');
        LibraryAssert.IsTrue(HelpText.Contains('CONST(0)'), 'The help should show the language-independent filter syntax.');
        LibraryAssert.IsTrue(HelpText.Contains('batch'), 'The help should describe the batch workflow.');
    end;

    // ————— Helpers —————

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        Customer: Record Customer;
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

        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", TestCustNoTok);
        DocAttachment.DeleteAll();
        AttachmentLink.DeleteAll();
    end;

    local procedure CreateIncDocEntry(Description: Text): Integer
    var
        IncomingDocument: Record "Incoming Document";
    begin
        exit(IncomingDocument.CreateIncomingDocument(CopyStr(Description, 1, 100), ''));
    end;

    local procedure CreateIncDocAttachment(FileName: Text; Content: Text; var Attachment: Record "Incoming Document Attachment")
    var
        EntryNo: Integer;
    begin
        EntryNo := CreateIncDocEntry(FileName);
        CreateIncDocAttachmentForEntry(EntryNo, FileName, Content, Attachment);
    end;

    local procedure CreateIncDocAttachmentForEntry(EntryNo: Integer; FileName: Text; Content: Text; var Attachment: Record "Incoming Document Attachment")
    var
        IncomingDocument: Record "Incoming Document";
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        Extension: Text;
        DotPos: Integer;
    begin
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

    local procedure CreateDocAttachment(FileName: Text; Content: Text; var DocAttachment: Record "Document Attachment")
    var
        Customer: Record Customer;
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        OutStr: OutStream;
    begin
        Customer.Get(TestCustNoTok);
        TempBlob.CreateOutStream(OutStr);
        OutStr.WriteText(Content);
        RecRef.GetTable(Customer);
        DocAttachment.SaveAttachment(RecRef, FileName, TempBlob);
        DocAttachment.SetRange("Table ID", Database::Customer);
        DocAttachment.SetRange("No.", Customer."No.");
        DocAttachment.FindLast();
    end;

    local procedure OffloadAttachment(var TempArgument: Record "Message Argument ori"; Target: Text; SystemId: Guid)
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('target', Target);
        RequestJson.Add('systemId', Format(SystemId, 0, 4));
        RequestJson.Add('storageCode', MockCodeTok);
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Offload", RequestJson);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Offload should succeed.');
    end;

    local procedure RestoreAttachment(var TempArgument: Record "Message Argument ori"; Target: Text; SystemId: Guid)
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('target', Target);
        RequestJson.Add('systemId', Format(SystemId, 0, 4));
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Storage.Attachment.Restore", RequestJson);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Restore should succeed.');
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

    local procedure GetResultArray(ResponseJson: JsonObject) ResultArray: JsonArray
    var
        DataToken: JsonToken;
        ResultToken: JsonToken;
        DataObj: JsonObject;
    begin
        Clear(ResultArray);
        // Data.Records.Get returns result at top level or inside data
        if ResponseJson.Get('result', ResultToken) then
            if ResultToken.IsArray() then
                exit(ResultToken.AsArray());
        if ResponseJson.Get('data', DataToken) then
            if DataToken.IsObject() then begin
                DataObj := DataToken.AsObject();
                if DataObj.Get('result', ResultToken) then
                    if ResultToken.IsArray() then
                        exit(ResultToken.AsArray());
            end;
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
}
