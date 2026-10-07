namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;

/// <summary>
/// Write restriction and orphan purge for <c>Storage Attachment Link ori</c>.
/// </summary>
codeunit 96214 "Storage Link Guard Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        LinkWriteHintTok: Label 'Storage.Attachment.Offload / Storage.Attachment.CreateLinked / Storage.Attachment.CreateForRecord', Locked = true;

    [Test]
    procedure DataRecordsSet_OnAttachmentLink_ReturnsHint()
    var
        Link: Record "Storage Attachment Link ori";
        TempArgument: Record "Message Argument ori";
        SetRequest: JsonObject;
        RecordObject: JsonObject;
        PrimaryKey: JsonObject;
        Fields: JsonObject;
        DataArray: JsonArray;
        ResponseJson: JsonObject;
        RecordId: Guid;
        ErrorText: Text;
    begin
        // [SCENARIO] AC01: Data.Records.Set on Storage Attachment Link ori is an error that names the dedicated types.
        RecordId := CreateGuid();
        Link.Init();
        Link."Table ID" := Database::Customer;
        Link."Record System Id" := RecordId;
        Link."File Name" := 'kept.txt';
        Link.Insert();

        PrimaryKey.Add('TableID', Database::Customer);
        PrimaryKey.Add('RecordSystemId', Format(RecordId, 0, 9));
        Fields.Add('FileName', 'hack.txt');
        RecordObject.Add('primaryKey', PrimaryKey);
        RecordObject.Add('fields', Fields);
        DataArray.Add(RecordObject);
        SetRequest.Add('tableName', 'Storage Attachment Link ori');
        SetRequest.Add('data', DataArray);

        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Data.Records.Set", SetRequest);

        ResponseJson := TempArgument.GetResponseJson();
        ErrorText := ReadText(ResponseJson, 'error');
        LibraryAssert.AreEqual('Error', ReadText(ResponseJson, 'status'), 'Data.Records.Set on the link table must return an error.');
        LibraryAssert.IsTrue(ErrorText.Contains('cannot be written'), 'The error should say the table cannot be written via Data.Records.Set.');
        LibraryAssert.IsTrue(ErrorText.EndsWith('Use ' + LinkWriteHintTok + '.'), 'The error should end with the dedicated message types.');
        Link.Get(Database::Customer, RecordId);
        LibraryAssert.AreEqual('kept.txt', Link."File Name", 'The link row must be unchanged after the rejected write.');
        LibraryAssert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Storage Attachment Link ori"), 'Link reads stay allowed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Attachment Link ori", false), 'Link writes are restricted.');
    end;

    [Test]
    procedure DataRecordsGet_OnAttachmentLink_ReturnsRows()
    var
        Link: Record "Storage Attachment Link ori";
        TempArgument: Record "Message Argument ori";
        GetRequest: JsonObject;
        ResponseJson: JsonObject;
        ResultToken: JsonToken;
        RecordId: Guid;
    begin
        // [SCENARIO] AC03: Data.Records.Get on Storage Attachment Link ori still returns rows.
        RecordId := CreateGuid();
        Link.Init();
        Link."Table ID" := Database::Customer;
        Link."Record System Id" := RecordId;
        Link."File Name" := 'readable.txt';
        Link.Insert();

        GetRequest.Add('tableName', 'Storage Attachment Link ori');
        ExecuteTypeWithRequest(TempArgument, TempArgument."Type"::"Data.Records.Get", GetRequest);

        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Data.Records.Get on the link table must succeed.');
        LibraryAssert.IsTrue(ResponseJson.Get('result', ResultToken), 'The read response should contain result.');
        LibraryAssert.IsTrue(ResultToken.AsArray().Count() > 0, 'The read should return link rows.');
    end;

    [Test]
    procedure PurgeOrphanLinks_RemovesEmptyKeys_KeepsValidRow()
    var
        Link: Record "Storage Attachment Link ori";
        StorageLinkUpgrade: Codeunit "Storage Link Upgrade ori";
        EmptyGuid: Guid;
        ValidId: Guid;
    begin
        // [SCENARIO] AC05: the purge removes Table ID 0 and empty Record System Id rows and leaves a valid link.
        if Link.Get(0, EmptyGuid) then
            Link.Delete();
        if Link.Get(Database::Customer, EmptyGuid) then
            Link.Delete();

        Link.Init();
        Link."Table ID" := 0;
        Link."Record System Id" := EmptyGuid;
        Link."File Name" := 'orphan-table.txt';
        Link.Insert();

        Link.Init();
        Link."Table ID" := Database::Customer;
        Link."Record System Id" := EmptyGuid;
        Link."File Name" := 'orphan-guid.txt';
        Link.Insert();

        ValidId := CreateGuid();
        Link.Init();
        Link."Table ID" := Database::Customer;
        Link."Record System Id" := ValidId;
        Link."File Name" := 'valid.txt';
        Link.Insert();

        StorageLinkUpgrade.PurgeOrphanAttachmentLinks();

        LibraryAssert.IsFalse(Link.Get(0, EmptyGuid), 'A Table ID 0 link must be removed.');
        LibraryAssert.IsFalse(Link.Get(Database::Customer, EmptyGuid), 'A link with an empty Record System Id must be removed.');
        LibraryAssert.IsTrue(Link.Get(Database::Customer, ValidId), 'A valid link must remain.');
        LibraryAssert.AreEqual('valid.txt', Link."File Name", 'The valid link file name must be unchanged.');
    end;

    local procedure ExecuteTypeWithRequest(var TempArgument: Record "Message Argument ori"; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
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
