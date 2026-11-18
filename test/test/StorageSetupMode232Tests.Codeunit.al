namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Diagnostics;
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

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure SetupModeOff_SetupTables_StayRestricted()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Seam: Codeunit "Storage Setup Mode Seam 232";
    begin
        // [SCENARIO] AC04 Without setup mode the configuration tables are refused as before.
        Seam.SetActive(false);
        BindSubscription(Seam);
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exchange Type", false), 'Type is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Def", false), 'Definition is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Line Def", false), 'Line definition is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Column Def", false), 'Column definition is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Mapping", false), 'Mapping is restricted.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Field Mapping", false), 'Field mapping is restricted.');
        UnbindSubscription(Seam);
    end;

    [Test]
    procedure SetupModeOn_SetupTables_AreOpen()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Seam: Codeunit "Storage Setup Mode Seam 232";
    begin
        // [SCENARIO] AC02 While setup mode is active only the configuration tables open.
        Seam.SetActive(true);
        BindSubscription(Seam);
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exchange Type", false), 'Type opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Def", false), 'Definition opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Line Def", false), 'Line definition opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Column Def", false), 'Column definition opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Mapping", false), 'Mapping opens.');
        LibraryAssert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Field Mapping", false), 'Field mapping opens.');
        UnbindSubscription(Seam);
    end;

    [Test]
    procedure SetupModeOn_ProtectedTables_StayRestricted()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Seam: Codeunit "Storage Setup Mode Seam 232";
    begin
        // [SCENARIO] AC02/AC04 Protected tables and fields never open, with or without Force.
        Seam.SetActive(true);
        BindSubscription(Seam);
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Setup ori", false), 'Storage setup (connection) stays closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Setup ori", true), 'Storage setup stays closed with Force.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Upload Session ori", false), 'Upload sessions stay closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Upload Chunk ori", false), 'Upload chunks stay closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Storage Upload Session ori"), 'Upload session reads stay closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch.", false), 'Data Exch. stays closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Data Exch. Field", false), 'Data Exch. Field stays closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Storage Attachment Link ori", false), 'Links stay closed.');
        LibraryAssert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"DataExch Entry Link ori", false), 'Entry links stay closed.');
        UnbindSubscription(Seam);
    end;

    [Test]
    procedure DataRecordsSet_TypeRow_RestrictionLiftedOnlyInSetupMode()
    var
        DataExchangeType: Record "Data Exchange Type";
        TempArgument: Record "Message Argument ori" temporary;
        Seam: Codeunit "Storage Setup Mode Seam 232";
        TypeCode: Code[20];
    begin
        // [SCENARIO] AC04 Data.Records.Set refuses the table when off and persists the requested values when on.
        // Cover the field with Change Log without weakening the write guard. The test runner rolls setup back.
        EnableTypeChangeLog();
        TypeCode := CopyStr('X232' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(TypeCode));
        BindSubscription(Seam);
        Seam.SetActive(false);
        ExecuteSet(TempArgument, TypeCode);
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'Refused while setup mode is off.');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'error').Contains('cannot be written'), 'Refused as a restricted table while off.');
        LibraryAssert.IsFalse(DataExchangeType.Get(TypeCode), 'No row while off.');

        Seam.SetActive(true);
        ExecuteSet(TempArgument, TypeCode);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Write succeeds while on: ' + GetResponseText(TempArgument));
        LibraryAssert.IsTrue(DataExchangeType.Get(TypeCode), 'The successful write must persist a row.');
        LibraryAssert.AreEqual(TypeCode, DataExchangeType.Code, 'The requested primary key is persisted.');
        LibraryAssert.AreEqual('Setup mode test', DataExchangeType.Description, 'The requested description is persisted.');
        DataExchangeType.Delete();
        UnbindSubscription(Seam);
    end;

    [Test]
    procedure SetupModeHelp_English_ExplainsAccessAndLogging()
    begin
        AssertSetupModeHelp(1033, '## Setup mode', 'Each allowed write is logged.');
    end;

    [Test]
    procedure SetupModeHelp_Icelandic_ExplainsAccessAndLogging()
    begin
        AssertSetupModeHelp(1039, '## Uppsetningarhamur', 'Öll leyfð skrif eru skráð.');
    end;

    local procedure AssertSetupModeHelp(LanguageId: Integer; ExpectedHeading: Text; ExpectedLogging: Text)
    var
        TempArgument: Record "Message Argument ori" temporary;
        HelpImpl: Codeunit "Storage Help Get Impl ori";
        DataToken: JsonToken;
        Markdown: Text;
        PreviousLanguage: Integer;
    begin
        // [SCENARIO] AC05 Both supported languages explain setup mode through the help response.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        TempArgument.Init();
        TempArgument."Type" := TempArgument."Type"::"Help.Storage.Get";
        TempArgument.Insert();
        HelpImpl.ExecuteBifrostTask(TempArgument);
        GlobalLanguage(PreviousLanguage);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Help succeeds.');
        TempArgument.GetResponseJson().Get('data', DataToken);
        Markdown := ReadText(DataToken.AsObject(), 'markdown');
        LibraryAssert.IsTrue(Markdown.Contains(ExpectedHeading), 'The setup heading follows the requested language.');
        LibraryAssert.IsTrue(Markdown.Contains(ExpectedLogging), 'The setup guidance explains write logging in the requested language.');
        LibraryAssert.IsTrue(Markdown.Contains('`Data Exch. Field Mapping`'), 'The allowed setup tables are named.');
        LibraryAssert.IsTrue(Markdown.Contains('`Storage Setup ori`'), 'The protected connector setup is named.');
    end;

    local procedure EnableTypeChangeLog()
    var
        ChangeLogSetup: Record "Change Log Setup";
        ChangeLogSetupTable: Record "Change Log Setup (Table)";
    begin
        if not ChangeLogSetup.Get() then begin
            ChangeLogSetup.Init();
            ChangeLogSetup.Insert();
        end;
        ChangeLogSetup."Change Log Activated" := true;
        ChangeLogSetup.Modify();
        if not ChangeLogSetupTable.Get(Database::"Data Exchange Type") then begin
            ChangeLogSetupTable.Init();
            ChangeLogSetupTable."Table No." := Database::"Data Exchange Type";
            ChangeLogSetupTable.Insert();
        end;
        ChangeLogSetupTable."Log Modification" := ChangeLogSetupTable."Log Modification"::"All Fields";
        ChangeLogSetupTable.Modify();
    end;

    local procedure ExecuteSet(var TempArgument: Record "Message Argument ori" temporary; TypeCode: Code[20])
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        Request: JsonObject;
        RecordObject: JsonObject;
        PrimaryKey: JsonObject;
        Fields: JsonObject;
        DataArray: JsonArray;
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

    local procedure GetResponseText(var TempArgument: Record "Message Argument ori" temporary): Text
    var
        Text: Text;
    begin
        TempArgument.GetResponseJson().WriteTo(Text);
        exit(Text);
    end;

    local procedure ReadText(Json: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Json.Get(PropertyName, Token) then
            exit(Token.AsValue().AsText());
    end;
}
