namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;
using System.Text;
using System.Utilities;

/// <summary>Tests the production adapter through an arbitrary platform connector without account metadata tables.</summary>
codeunit 96236 "Storage Interface Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    RequiredTestIsolation = Function;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>The restricted actor exercises every storage operation through the platform interface.</summary>
    [Test]
    procedure Scenario_Interface_RestrictedActor_Roundtrips()
    var
        StorageSetup: Record "Storage Setup ori";
        TempEntries: Record "File Account Content" temporary;
        Provider: Codeunit "Storage Ext File Impl ori";
        MockState: Codeunit "Storage Mock State";
        Content: Codeunit "Temp Blob";
        Result: Codeunit "Temp Blob";
    begin
        // [GIVEN] Advertised app/API roles and an account with no connector-specific table.
        Initialize(StorageSetup);
        PutContent(Content, 'interface bytes');
        LowerActor();
        // [WHEN] The production adapter delegates through External File Storage to the test enum member.
        Provider.TestConnection(StorageSetup);
        Provider.CreateDirectory(StorageSetup, 'dir');
        LibraryAssert.IsTrue(Provider.DirectoryExists(StorageSetup, 'dir'), 'Directory creation must reach the registered connector.');
        Provider.ListEntries(StorageSetup, '', Enum::"Ext. File Storage File Type"::Directory, TempEntries);
        LibraryAssert.AreEqual(1, TempEntries.Count(), 'The facade must list the created directory.');
        TempEntries.FindFirst();
        LibraryAssert.AreEqual('dir', TempEntries.Name, 'Listing returns the connector directory name.');
        LibraryAssert.AreEqual('base', TempEntries."Parent Directory", 'Listing returns the composed base path.');
        Provider.CreateFile(StorageSetup, 'dir/File%20Name.txt', Content);
        LibraryAssert.IsTrue(Provider.FileExists(StorageSetup, 'dir/File%20Name.txt'), 'The exact connector path must exist.');
        Provider.GetFile(StorageSetup, 'dir/File%20Name.txt', Result);
        AssertContent(Result, 'interface bytes');
        Provider.ListEntries(StorageSetup, 'dir', Enum::"Ext. File Storage File Type"::File, TempEntries);
        LibraryAssert.AreEqual(1, TempEntries.Count(), 'Listing must return the created file.');
        TempEntries.FindFirst();
        LibraryAssert.AreEqual('File%20Name.txt', TempEntries.Name, 'Connector-owned percent spelling must remain unchanged.');
        Provider.CopyFile(StorageSetup, 'dir/File%20Name.txt', 'dir/copy.txt');
        Provider.MoveFile(StorageSetup, 'dir/copy.txt', 'dir/moved.txt');
        LibraryAssert.IsFalse(Provider.FileExists(StorageSetup, 'dir/copy.txt'), 'Move removes its source.');
        Provider.GetFile(StorageSetup, 'dir/moved.txt', Result);
        AssertContent(Result, 'interface bytes');
        // [THEN] GUID, base path and bytes reached the connector unchanged, with independently observable deletion.
        LibraryAssert.AreEqual(Encode('interface bytes'), MockState.GetFileContent(Format(StorageSetup."File Account Id", 0, 4) + '/base/dir/moved.txt'), 'The facade must forward the selected account GUID and composed path.');
        Provider.DeleteFile(StorageSetup, 'dir/File%20Name.txt');
        Provider.DeleteFile(StorageSetup, 'dir/moved.txt');
        Provider.DeleteDirectory(StorageSetup, 'dir');
        LibraryAssert.IsFalse(Provider.FileExists(StorageSetup, 'dir/moved.txt'), 'Deleted file must be absent.');
        LibraryAssert.IsFalse(Provider.DirectoryExists(StorageSetup, 'dir'), 'Deleted directory must be absent.');
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    /// <summary>Opaque account IDs isolate identical paths without reading a provider account table.</summary>
    [Test]
    procedure Scenario_Interface_Accounts_KeepDistinctBytes()
    var
        FirstSetup: Record "Storage Setup ori";
        SecondSetup: Record "Storage Setup ori";
        Provider: Codeunit "Storage Ext File Impl ori";
        Content: Codeunit "Temp Blob";
        Result: Codeunit "Temp Blob";
    begin
        // [GIVEN] Distinct account IDs on the same registered connector.
        Initialize(FirstSetup);
        SecondSetup := FirstSetup;
        SecondSetup."File Account Id" := CreateGuid();
        LowerActor();
        // [WHEN] Each account stores different bytes at the same relative path.
        PutContent(Content, 'first account');
        Provider.CreateFile(FirstSetup, 'same.txt', Content);
        LibraryAssert.IsFalse(Provider.FileExists(SecondSetup, 'same.txt'), 'The facade must forward the selected account.');
        PutContent(Content, 'second account');
        Provider.CreateFile(SecondSetup, 'same.txt', Content);
        // [THEN] Fresh reads retain the independently stored bytes.
        Provider.GetFile(FirstSetup, 'same.txt', Result);
        AssertContent(Result, 'first account');
        Provider.GetFile(SecondSetup, 'same.txt', Result);
        AssertContent(Result, 'second account');
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    /// <summary>Selected-connector failures propagate without changing source content.</summary>
    [Test]
    procedure Scenario_Interface_ProviderFailure_PreservesSource()
    var
        StorageSetup: Record "Storage Setup ori";
        Provider: Codeunit "Storage Ext File Impl ori";
        MockState: Codeunit "Storage Mock State";
        Content: Codeunit "Temp Blob";
        Result: Codeunit "Temp Blob";
    begin
        // [GIVEN] Source bytes written through the real production adapter and facade.
        Initialize(StorageSetup);
        PutContent(Content, 'preserved source');
        LowerActor();
        Provider.CreateFile(StorageSetup, 'source.txt', Content);
        // [WHEN] The selected connector rejects create, copy and move before any effect.
        MockState.FailNextWrite();
        asserterror Provider.CreateFile(StorageSetup, 'new.txt', Content);
        AssertInjectedFailure();
        MockState.FailNextWrite();
        asserterror Provider.CopyFile(StorageSetup, 'source.txt', 'copy.txt');
        AssertInjectedFailure();
        MockState.FailNextWrite();
        asserterror Provider.MoveFile(StorageSetup, 'source.txt', 'moved.txt');
        AssertInjectedFailure();
        // [THEN] The failures leave no target and preserve independently readable source bytes.
        LibraryAssert.IsFalse(Provider.FileExists(StorageSetup, 'new.txt'), 'Failed create leaves no target.');
        LibraryAssert.IsFalse(Provider.FileExists(StorageSetup, 'copy.txt'), 'Failed copy leaves no target.');
        LibraryAssert.IsFalse(Provider.FileExists(StorageSetup, 'moved.txt'), 'Failed move leaves no target.');
        Provider.GetFile(StorageSetup, 'source.txt', Result);
        AssertContent(Result, 'preserved source');
        asserterror Provider.GetFile(StorageSetup, 'missing.txt', Result);
        LibraryAssert.IsTrue(GetLastErrorText().Contains('was not found'), 'Read refusal must come from the selected connector.');
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    /// <summary>Application traversal rejection happens before any connector mutation.</summary>
    [Test]
    procedure Scenario_Interface_UnsafePath_ReachesNoWrite()
    var
        StorageSetup: Record "Storage Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Provider: Codeunit "Storage Ext File Impl ori";
        MockState: Codeunit "Storage Mock State";
        Content: Codeunit "Temp Blob";
        Response: JsonObject;
    begin
        // [GIVEN] An arbitrary connector with independently counted writes.
        Initialize(StorageSetup);
        PutContent(Content, 'never written');
        LowerActor();
        // [WHEN] The application receives traversal syntax.
        asserterror Provider.CreateFile(StorageSetup, '../escape.txt', Content);
        LibraryAssert.AreNotEqual('', GetLastErrorText(), 'The invalid path must be refused.');
        // Match the dispatcher's error boundary: consume the structured helper error.
        // Otherwise its single-instance context can mask a later plain connector error.
        TempArgument.RespondWithLastError();
        Response := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'The unsafe path must return a structured refusal.');
        LibraryAssert.AreEqual('InvalidParameter', ReadText(Response, 'code'), 'The refusal must come from path validation.');
        LibraryAssert.AreEqual('../escape.txt', ReadText(Response, 'received'), 'The path refusal must retain the attempted escape.');
        // [THEN] Interface writes and content creation never occurred.
        LibraryAssert.AreEqual(0, MockState.GetWriteCalls(), 'Validation must precede connector writes.');
        LibraryAssert.AreEqual(0, MockState.FilePaths().Count(), 'A refused request creates no file.');
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    /// <summary>Connector-owned case and encoded aliases cannot turn an unlinked move into source deletion.</summary>
    [Test]
    procedure Scenario_Interface_TargetAliases_RefuseBeforeWrite()
    var
        StorageSetup: Record "Storage Setup ori";
        Provider: Codeunit "Storage Ext File Impl ori";
        PlatformFake: Codeunit "Storage Platform Fake ori";
        MockState: Codeunit "Storage Mock State";
        Content: Codeunit "Temp Blob";
        Result: Codeunit "Temp Blob";
        BeforeCalls: Integer;
    begin
        // [GIVEN] An opaque connector that owns its case and percent-alias comparison.
        Initialize(StorageSetup);
        PlatformFake.SetFoldedPaths(true);
        PutContent(Content, 'alias source');
        LowerActor();
        Provider.CreateFile(StorageSetup, 'source.txt', Content);
        BeforeCalls := MockState.GetWriteCalls();
        // [WHEN] Raw request spellings differ, but connector FileExists identifies the existing source.
        AssertTransferRefusal(StorageSetup, 'SOURCE.TXT', true, 'PreconditionFailed');
        AssertTransferRefusal(StorageSetup, '%73ource.txt', true, 'PreconditionFailed');
        AssertTransferRefusal(StorageSetup, 'SOURCE.TXT', false, 'PreconditionFailed');
        AssertTransferRefusal(StorageSetup, '%73ource.txt', false, 'PreconditionFailed');
        // [THEN] The request helper refused every transfer before copy/move and source bytes remain intact.
        LibraryAssert.AreEqual(BeforeCalls, MockState.GetWriteCalls(), 'No transfer may reach the connector mutation.');
        Provider.GetFile(StorageSetup, 'source.txt', Result);
        AssertContent(Result, 'alias source');
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    /// <summary>A failed destination existence probe becomes an error without any transfer effect.</summary>
    [Test]
    procedure Scenario_Interface_ExistenceFailure_RefusesTransfer()
    var
        StorageSetup: Record "Storage Setup ori";
        Provider: Codeunit "Storage Ext File Impl ori";
        PlatformFake: Codeunit "Storage Platform Fake ori";
        MockState: Codeunit "Storage Mock State";
        Content: Codeunit "Temp Blob";
        Result: Codeunit "Temp Blob";
        BeforeCalls: Integer;
    begin
        // [GIVEN] Existing source bytes and a connector that fails the read-only destination probe.
        Initialize(StorageSetup);
        PutContent(Content, 'preserved probe source');
        LowerActor();
        Provider.CreateFile(StorageSetup, 'source.txt', Content);
        BeforeCalls := MockState.GetWriteCalls();
        PlatformFake.SetFailExistenceCheck(true);
        // [WHEN] Copy and move try to establish whether the destination already exists.
        AssertTransferRefusal(StorageSetup, 'new.txt', true, 'BusinessCentralError');
        AssertTransferRefusal(StorageSetup, 'new.txt', false, 'BusinessCentralError');
        PlatformFake.SetFailExistenceCheck(false);
        // [THEN] Both source and target readback prove that no mutation followed the failed probe.
        LibraryAssert.AreEqual(BeforeCalls, MockState.GetWriteCalls(), 'A failed probe must precede every connector mutation.');
        LibraryAssert.IsFalse(Provider.FileExists(StorageSetup, 'new.txt'), 'A failed probe creates no target.');
        Provider.GetFile(StorageSetup, 'source.txt', Result);
        AssertContent(Result, 'preserved probe source');
        LowerPermissions.StopLoggingNAVPermissions();
    end;

    local procedure AssertTransferRefusal(StorageSetup: Record "Storage Setup ori"; TargetPath: Text; IsMove: Boolean; ExpectedCode: Text)
    var
        TempArgument: Record "Message Argument ori" temporary;
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        Response: JsonObject;
    begin
        TempArgument.Init();
        if IsMove then
            TempArgument.Type := TempArgument.Type::"Storage.File.Move"
        else
            TempArgument.Type := TempArgument.Type::"Storage.File.Copy";
        TempArgument.Insert(true);
        Connector := Enum::"Storage Type ori"::"External File Storage";
        if IsMove then
            RequestMgt.ExecuteMoveFile(TempArgument, StorageSetup, Connector, 'source.txt', TargetPath)
        else
            RequestMgt.ExecuteCopyFile(TempArgument, StorageSetup, Connector, 'source.txt', TargetPath);
        Response := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Error', ReadText(Response, 'status'), 'The transfer must be refused.');
        LibraryAssert.AreEqual(ExpectedCode, ReadText(Response, 'code'), 'An unrelated failure is not this regression result.');
        if ExpectedCode = 'PreconditionFailed' then begin
            LibraryAssert.AreEqual('targetPath', ReadText(Response, 'parameter'), 'Refusal must identify the destination.');
            LibraryAssert.AreEqual(TargetPath, ReadText(Response, 'received'), 'Refusal must keep the caller spelling.');
            LibraryAssert.AreNotEqual('', ReadText(Response, 'nextStep'), 'Refusal must give a next step.');
        end else
            LibraryAssert.IsTrue(ReadText(Response, 'error').Contains('Injected platform existence failure'), 'The error must identify the selected connector probe failure.');
    end;

    local procedure ReadText(Response: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Response.Get(PropertyName, Token), 'The response must contain ' + PropertyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure Initialize(var StorageSetup: Record "Storage Setup ori")
    var
        MockState: Codeunit "Storage Mock State";
        PlatformFake: Codeunit "Storage Platform Fake ori";
    begin
        LowerPermissions.StopLoggingNAVPermissions();
        MockState.Reset();
        PlatformFake.SetFoldedPaths(false);
        PlatformFake.SetFailExistenceCheck(false);
        StorageSetup.Init();
        StorageSetup.Code := 'XINTERFACE';
        StorageSetup.Enabled := true;
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::"External File Storage";
        StorageSetup.Connector := Enum::"Ext. File Storage Connector"::"Interface Test ori";
        StorageSetup."File Account Id" := CreateGuid();
        StorageSetup."Base Path" := 'base';
    end;

    local procedure LowerActor()
    var
        Customer: Record Customer;
    begin
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('Storage Iface ori');
        LibraryAssert.IsTrue(LowerPermissions.HasChangedPermissions(), 'Permission enforcement must be active.');
        LibraryAssert.IsFalse(Customer.WritePermission(), 'The facade actor must not inherit SUPER.');
    end;

    local procedure PutContent(var TempBlob: Codeunit "Temp Blob"; ContentText: Text)
    var
        ContentOutStream: OutStream;
    begin
        Clear(TempBlob);
        TempBlob.CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText(ContentText);
    end;

    local procedure AssertContent(var TempBlob: Codeunit "Temp Blob"; Expected: Text)
    var
        Base64Convert: Codeunit "Base64 Convert";
        ContentInStream: InStream;
    begin
        TempBlob.CreateInStream(ContentInStream);
        LibraryAssert.AreEqual(Encode(Expected), Base64Convert.ToBase64(ContentInStream), 'Fresh connector reads must preserve the exact bytes.');
    end;

    local procedure Encode(ContentText: Text): Text
    var
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        ContentInStream: InStream;
    begin
        PutContent(TempBlob, ContentText);
        TempBlob.CreateInStream(ContentInStream);
        exit(Base64Convert.ToBase64(ContentInStream));
    end;

    local procedure AssertInjectedFailure()
    begin
        LibraryAssert.IsTrue(GetLastErrorText().Contains('Injected storage write failure'), 'The failure must come from the selected connector, not an unrelated permission or account lookup.');
    end;
}
