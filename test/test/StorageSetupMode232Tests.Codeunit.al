namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;

/// <summary>
/// #232: Attachments follows Foundation setup mode through the public facade. Setup mode opens only the
/// Data Exchange setup/configuration tables; every protected table stays restricted.
/// Foundation setup mode itself is internal to Foundation, so these tests override the facade answer through the
/// internal seam <c>OnBeforeIsSetupModeActive</c>. The real facade is covered by the MCP evidence on the PR.
/// </summary>
codeunit 96282 "Storage Setup Mode 232 Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    EventSubscriberInstance = Manual;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        SetupModeActive: Boolean;

    [Test]
    procedure SetupModeOff_SetupTables_StayRestricted()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // [SCENARIO] AC04 Without setup mode the configuration tables are refused as before.
        SetupModeActive := false;
        BindSubscription(this);
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exchange Type", false), 'Type is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Def", false), 'Definition is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Line Def", false), 'Line definition is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Column Def", false), 'Column definition is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Mapping", false), 'Mapping is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Field Mapping", false), 'Field mapping is restricted.');
        UnbindSubscription(this);
    end;

    [Test]
    procedure SetupModeOn_SetupTables_AreOpen()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // [SCENARIO] AC02 While setup mode is active only the configuration tables open.
        SetupModeActive := true;
        BindSubscription(this);
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exchange Type", false), 'Type opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Def", false), 'Definition opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Line Def", false), 'Line definition opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Column Def", false), 'Column definition opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Mapping", false), 'Mapping opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Field Mapping", false), 'Field mapping opens.');
        UnbindSubscription(this);
    end;

    [Test]
    procedure SetupModeOn_ProtectedTables_StayRestricted()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // [SCENARIO] AC02/AC04 Protected tables and fields never open, with or without Force.
        SetupModeActive := true;
        BindSubscription(this);
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Setup ori", false), 'Storage setup (connection) stays closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Setup ori", true), 'Storage setup stays closed with Force.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Upload Session ori", false), 'Upload sessions stay closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Upload Chunk ori", false), 'Upload chunks stay closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Storage Upload Session ori"), 'Upload session reads stay closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch.", false), 'Data Exch. stays closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Field", false), 'Data Exch. Field stays closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Attachment Link ori", false), 'Links stay closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"DataExch Entry Link ori", false), 'Entry links stay closed.');
        UnbindSubscription(this);
    end;

    [Test]
    procedure DataRecordsSet_TypeRow_WrittenOnlyInSetupMode()
    var
        DataExchangeType: Record "Data Exchange Type";
        TempArgument: Record "Message Argument ori" temporary;
        TypeCode: Code[20];
    begin
        // [SCENARIO] AC04 A setup table is refused through Data.Records.Set when off and written when on.
        TypeCode := CopyStr('X232' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(TypeCode));
        BindSubscription(this);
        SetupModeActive := false;
        ExecuteSet(TempArgument, TypeCode);
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'Refused while setup mode is off.');
        LibraryAssert.IsFalse(DataExchangeType.Get(TypeCode), 'No row while off.');

        SetupModeActive := true;
        ExecuteSet(TempArgument, TypeCode);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Written while setup mode is on.');
        LibraryAssert.IsTrue(DataExchangeType.Get(TypeCode), 'Row exists after the setup write.');
        DataExchangeType.Delete();
        UnbindSubscription(this);
    end;

    local procedure ExecuteSet(var TempArgument: Record "Message Argument ori" temporary; TypeCode: Code[20])
    var
        Dispatcher: Codeunit "Dispatcher ori";
        MessageVersion: Enum "Message Version ori";
        Request: JsonObject;
        RecordObject: JsonObject;
        PrimaryKey: JsonObject;
        Fields: JsonObject;
        DataArray: JsonArray;
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
        ResponseJson: JsonObject;
    begin
        PrimaryKey.Add('Code', TypeCode);
        Fields.Add('Description', 'Setup mode test');
        RecordObject.Add('primaryKey', PrimaryKey);
        RecordObject.Add('fields', Fields);
        DataArray.Add(RecordObject);
        Request.Add('tableName', 'Data Exchange Type');
        Request.Add('data', DataArray);
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(TempArgument."Type"::"Data.Records.Set", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument."Type" := TempArgument."Type"::"Data.Records.Set";
        TempArgument.Insert(true);
        TempArgument.SetResponseJson(ResponseJson);
    end;

    local procedure ReadText(Json: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Json.Get(PropertyName, Token) then
            exit(Token.AsValue().AsText());
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Storage Data Restriction ori", 'OnBeforeIsSetupModeActive', '', false, false)]
    local procedure OverrideSetupMode(var Active: Boolean; var Handled: Boolean)
    begin
        Active := SetupModeActive;
        Handled := true;
    end;
}
