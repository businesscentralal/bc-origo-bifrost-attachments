namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;

/// <summary>Issue 125: Storage.Directory.Delete refuses the connection root before any connector call.</summary>
codeunit 96238 "Storage Refusal 125 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Function;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'X125', Locked = true;

    /// <summary>AC01: the connection root is refused with InvalidParameter and the connector is never called.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_RootPath_RefusedBeforeConnectorCall()
    var
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
    begin
        // [GIVEN] A configured mock connection with an empty root.
        Initialize();
        LibraryAssert.AreEqual(0, MockState.GetDeleteCalls(), 'The fixture must not call the connector.');
        LibraryAssert.AreEqual(0, MockState.GetListCalls(), 'The fixture must not list the root.');
        // [WHEN] The delete names the connection root.
        Response := Execute(Enum::"Message Type ori"::"Storage.Directory.Delete", PathRequest('/'));
        // [THEN] The typed refusal identifies the raw received value and the connector was never called.
        AssertRootRefusal(Response, '/');
        LibraryAssert.AreEqual(0, MockState.GetDeleteCalls(), 'The connector delete must not run for the root.');
        LibraryAssert.AreEqual(0, MockState.GetListCalls(), 'The emptiness check must not list the root.');
    end;

    /// <summary>AC01: the root spelling '/' is refused with the raw received value, without a connector call.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_RootSpellings_RefusedWithReceivedValue()
    var
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
    begin
        // [GIVEN] The same empty mock root.
        Initialize();
        // [WHEN] A present path that canonicalizes to the connection root ('/') is submitted.
        // An empty or absent path is a MissingParameter error, and a double slash ('//') is rejected as an
        // unsafe path; neither reaches the root refusal, so only '/' is asserted here as a root spelling.
        Response := Execute(Enum::"Message Type ori"::"Storage.Directory.Delete", PathRequest('/'));
        AssertRootRefusal(Response, '/');
        // [THEN] The connection state is untouched and the connector is called zero times.
        LibraryAssert.AreEqual(0, MockState.GetDeleteCalls(), 'The root may not reach the connector delete.');
        LibraryAssert.AreEqual(0, MockState.GetListCalls(), 'The root may not reach the connector list.');
    end;

    /// <summary>AC01: the refusal is localized in Icelandic with the same stable code.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC01_RootRefusal_Localizes1039()
    var
        PreviousLanguage: Integer;
        Response: JsonObject;
        ResponseText: Text;
    begin
        // [GIVEN] Icelandic as the session language and the empty mock root.
        Initialize();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        // [WHEN] The root is deleted.
        Response := Execute(Enum::"Message Type ori"::"Storage.Directory.Delete", PathRequest('/'));
        GlobalLanguage(PreviousLanguage);
        // [THEN] The stable code and the translated details identify the refusal.
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'The root must be refused.');
        LibraryAssert.AreEqual('InvalidParameter', ReadText(Response, 'code'), 'The stable code is language-independent.');
        Response.WriteTo(ResponseText);
        LibraryAssert.IsTrue(ResponseText.Contains('Rót geymslutengingar'), 'Translate the root refusal explanation.');
        LibraryAssert.IsTrue(ResponseText.Contains('mappa sem liggur undir'), 'Translate the expected directory.');
        LibraryAssert.IsTrue(ResponseText.Contains('Nefndu möppuna'), 'Translate the recovery step.');
    end;

    /// <summary>AC02: the help errors chapter lists the root refusal with its code.</summary>
    [Test]
    procedure Scenario_AC02_HelpErrors_ListRootRefusal()
    var
        RequestJson: JsonObject;
        Response: JsonObject;
        DataText: Text;
    begin
        // [GIVEN] A storage help request.
        Initialize();
        // [WHEN] The guide is retrieved.
        Response := Execute(Enum::"Message Type ori"::"Help.Storage.Get", RequestJson);
        DataText := ReadDataText(Response, 'markdown');
        // [THEN] The errors chapter names the root refusal and its InvalidParameter code.
        LibraryAssert.IsTrue(DataText.Contains('## Errors'), 'The errors chapter must exist.');
        LibraryAssert.IsTrue(DataText.Contains('connection root'), 'The root refusal must be listed.');
        LibraryAssert.IsTrue(DataText.Contains('InvalidParameter'), 'The refusal code must be documented.');
    end;

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.Reset();
        if StorageSetup.Get(MockCodeTok) then
            StorageSetup.Delete();
        StorageSetup.Init();
        StorageSetup.Code := MockCodeTok;
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
    end;

    local procedure PathRequest(Path: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('storageCode', MockCodeTok);
        RequestJson.Add('path', Path);
    end;

    local procedure Execute(MessageType: Enum "Message Type ori"; RequestJson: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageVersion: Enum "Message Version ori";
        ResponseContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType, false);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure AssertRootRefusal(Response: JsonObject; Received: Text)
    var
        ResponseText: Text;
    begin
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'The root must be refused.');
        LibraryAssert.AreEqual('InvalidParameter', ReadText(Response, 'code'), 'The refusal must use InvalidParameter.');
        LibraryAssert.AreEqual('path', ReadText(Response, 'parameter'), 'The refusal must name the path parameter.');
        LibraryAssert.AreEqual(Received, ReadText(Response, 'received'), 'The refusal must echo the received value.');
        Response.WriteTo(ResponseText);
        LibraryAssert.IsTrue(ResponseText.Contains('connection root cannot be deleted'), 'Explain the root precondition.');
        LibraryAssert.IsTrue(ResponseText.Contains('directory below the connection root'), 'State the expected directory.');
        LibraryAssert.IsTrue(ResponseText.Contains('Name the folder to delete'), 'Give an actionable recovery step.');
    end;

    local procedure ReadText(ValueObject: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(ValueObject.Get(PropertyName, Token), 'Expected response property: ' + PropertyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadDataText(Response: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Response.Get('data', Token), 'A success response must contain data.');
        exit(ReadText(Token.AsObject(), PropertyName));
    end;
}
