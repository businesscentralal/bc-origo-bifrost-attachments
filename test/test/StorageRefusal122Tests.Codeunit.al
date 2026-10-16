namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;

/// <summary>Issue 122: explicit header-only import references and safe directory refusals.</summary>
codeunit 96228 "Storage Refusal122 Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    /// <summary>AC01 selects the documented header-only alternative without inventing storage effects.</summary>
    [Test]
    procedure Scenario_AC01_UnknownReferences_CreateOnlyHeader1033()
    begin
        AssertHeaderOnlyImport(1033);
    end;

    /// <summary>The documented reference-only behavior also holds on the localized queue path.</summary>
    [Test]
    procedure Scenario_AC01_UnknownReferences_CreateOnlyHeader1039()
    begin
        AssertHeaderOnlyImport(1039);
    end;

    /// <summary>The import contract distinguishes unvalidated references from resolved storage.</summary>
    [Test]
    procedure Scenario_AC01_Contract_ExplainsUnvalidatedReferences()
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
        Parameters: JsonArray;
        ParametersText: Text;
    begin
        // [GIVEN] The shipped header-only import operation.
        // [WHEN] Its public parameters are described.
        Parameters := ContractParts.GetParameters('DataExchange.Import.Run');
        Parameters.WriteTo(ParametersText);
        // [THEN] Neither a configured connection nor an existing file is promised.
        LibraryAssert.IsTrue(ParametersText.Contains('not validated against configured storage connections'), 'Explain that unknown storage codes are accepted.');
        LibraryAssert.IsTrue(ParametersText.Contains('not validated for file existence'), 'Explain that unknown file paths are accepted.');
        LibraryAssert.IsTrue(ParametersText.Contains('not stored on the entry header'), 'Do not claim references are persisted when only a header is created.');
    end;

    /// <summary>A file prevents deleting its parent, with a typed refusal and unchanged content.</summary>
    [Test]
    procedure Scenario_AC02_FileChild_RefusesAndPreservesContent()
    var
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
    begin
        // [GIVEN] An isolated connector containing a directory and a file.
        Initialize(StorageSetup);
        MockState.AddDirectory('X122');
        MockState.PutFile('X122/Xfile.txt', 'WE==');
        // [WHEN] The real directory operation is attempted.
        Response := DeleteDirectory(StorageSetup, 'X122');
        // [THEN] The named precondition refusal preserves both directory and content.
        AssertDirectoryNotEmpty(Response);
        LibraryAssert.IsTrue(MockState.HasDirectory('X122'), 'Refusal must preserve the parent.');
        LibraryAssert.AreEqual('WE==', MockState.GetFileContent('X122/Xfile.txt'), 'Refusal must preserve the file bytes.');
    end;

    /// <summary>A subdirectory prevents deleting its parent even when no files exist.</summary>
    [Test]
    procedure Scenario_AC02_DirectoryChild_RefusesAndPreservesTree()
    var
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
    begin
        // [GIVEN] A directory with an empty subdirectory.
        Initialize(StorageSetup);
        MockState.AddDirectory('X122');
        MockState.AddDirectory('X122/Xchild');
        // [WHEN] The parent is deleted.
        Response := DeleteDirectory(StorageSetup, 'X122');
        // [THEN] An empty child directory still makes the parent non-empty.
        AssertDirectoryNotEmpty(Response);
        LibraryAssert.IsTrue(MockState.HasDirectory('X122'), 'The parent must survive.');
        LibraryAssert.IsTrue(MockState.HasDirectory('X122/Xchild'), 'The child must survive.');
    end;

    /// <summary>The emptiness check uses the same configured base path as deletion.</summary>
    [Test]
    procedure Scenario_AC02_BasePath_RefusesNestedFile()
    var
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
    begin
        // [GIVEN] Files below a configured base path, with an outer-slash request spelling.
        Initialize(StorageSetup);
        StorageSetup."Base Path" := 'Xbase';
        StorageSetup.Modify();
        MockState.AddDirectory('Xbase/X122');
        MockState.PutFile('Xbase/X122/Xfile.txt', 'WE==');
        // [WHEN] The relative directory is deleted.
        Response := DeleteDirectory(StorageSetup, '/X122/');
        // [THEN] Preflight and provider address the same directory.
        AssertDirectoryNotEmpty(Response);
        LibraryAssert.IsTrue(MockState.HasFile('Xbase/X122/Xfile.txt'), 'The base-path file must survive.');
    end;

    /// <summary>An unrelated sibling does not prevent deleting an empty directory.</summary>
    [Test]
    procedure Scenario_AC02_EmptyDirectory_DeletesOnlyTarget()
    var
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
    begin
        // [GIVEN] An empty directory and a similarly named sibling containing a file.
        Initialize(StorageSetup);
        MockState.AddDirectory('X122');
        MockState.AddDirectory('X122other');
        MockState.PutFile('X122other/Xfile.txt', 'WE==');
        // [WHEN] Only the empty directory is deleted.
        Response := DeleteDirectory(StorageSetup, 'X122');
        // [THEN] The operation succeeds and preserves the sibling.
        LibraryAssert.AreEqual('Success', TextProperty(Response, 'status'), 'Empty directory delete must still succeed.');
        LibraryAssert.IsFalse(MockState.HasDirectory('X122'), 'The empty target must be deleted.');
        LibraryAssert.IsTrue(MockState.HasFile('X122other/Xfile.txt'), 'An unrelated sibling must survive.');
    end;

    /// <summary>The shared contract documents the exact error code returned by the operation.</summary>
    [Test]
    procedure Scenario_AC02_Contract_ListsNonEmptyPrecondition()
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
        Errors: JsonArray;
        ErrorsText: Text;
    begin
        // [GIVEN] The shipped directory delete contract.
        // [WHEN] Its errors chapter is described.
        Errors := ContractParts.GetErrors('Storage.Directory.Delete');
        Errors.WriteTo(ErrorsText);
        // [THEN] The specific precondition and recovery are discoverable.
        LibraryAssert.IsTrue(ErrorsText.Contains('PreconditionFailed'), 'Document the returned error code.');
        LibraryAssert.IsTrue(ErrorsText.Contains('The directory is not empty.'), 'Document the non-empty condition.');
        LibraryAssert.IsTrue(ErrorsText.Contains('subdirectories'), 'Explain how to resolve the precondition.');
    end;

    /// <summary>The non-empty refusal is localized without exposing native connector text.</summary>
    [Test]
    procedure Scenario_AC02_NonEmptyDirectory_Localizes1039()
    var
        StorageSetup: Record "Storage Setup ori";
        MockState: Codeunit "Storage Mock State";
        Response: JsonObject;
        ResponseText: Text;
        PreviousLanguage: Integer;
        Succeeded: Boolean;
    begin
        // [GIVEN] A non-empty directory and Icelandic as the operation language.
        Initialize(StorageSetup);
        MockState.AddDirectory('X122');
        MockState.PutFile('X122/Xfile.txt', 'WE==');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        // [WHEN] The action is attempted; restore session language even on a native error.
        Succeeded := TryDeleteDirectory(StorageSetup, Response);
        GlobalLanguage(PreviousLanguage);
        // [THEN] The stable code has translated explanatory details and preserves data.
        LibraryAssert.IsTrue(Succeeded, 'The non-empty refusal must return a structured response.');
        LibraryAssert.AreEqual('PreconditionFailed', TextProperty(Response, 'code'), 'The stable code is language-independent.');
        Response.WriteTo(ResponseText);
        LibraryAssert.IsTrue(ResponseText.Contains('ekki tóm'), 'Translate the non-empty explanation.');
        LibraryAssert.IsTrue(ResponseText.Contains('undirmöppur'), 'Translate the recovery step.');
        LibraryAssert.IsTrue(MockState.HasFile('X122/Xfile.txt'), 'Localized refusal must preserve content.');
    end;

    local procedure Initialize(var StorageSetup: Record "Storage Setup ori")
    var
        LowerPermissions: Codeunit "Library - Lower Permissions";
        MockState: Codeunit "Storage Mock State";
    begin
        // Fixture setup uses the runner's original grants; the actor phase remains restrictive.
        LowerPermissions.StopLoggingNAVPermissions();
        MockState.Reset();
        StorageSetup.Init();
        StorageSetup.Code := NewCode();
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
    end;

    local procedure AssertHeaderOnlyImport(LanguageId: Integer)
    var
        Definition: Record "Data Exch. Def";
        DataExch: Record "Data Exch.";
        StorageSetup: Record "Storage Setup ori";
        Dispatcher: Codeunit "Dispatcher ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        RequestContent: BigText;
        ResponseContent: BigText;
        Request: JsonObject;
        Response: JsonObject;
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseType: Text[100];
        Payload: Text;
        ResponseText: Text;
        UnknownStorageCode: Code[20];
        EntryToken: JsonToken;
    begin
        // [GIVEN] A self-created definition and a storage code that does not exist.
        LowerPermissions.StopLoggingNAVPermissions();
        Definition.Code := NewCode();
        Definition.Type := Definition.Type::"Generic Import";
        Definition.Insert(true);
        UnknownStorageCode := NewCode();
        StorageSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        LibraryAssert.IsFalse(StorageSetup.Get(UnknownStorageCode), 'The reference must genuinely be unknown.');
        Request.Add('dataExchDefCode', Definition.Code);
        Request.Add('storageCode', UnknownStorageCode);
        Request.Add('path', 'X122/Xmissing.csv');
        Request.WriteTo(Payload);
        RequestContent.AddText(Payload);
        // [WHEN] The registered handler receives the requested locale through the public queue path.
        LowerPermissions.StopLoggingNAVPermissions();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('Lang Setup Read ori');
        LowerPermissions.AddPermissionSet('BIFROST API ori');
        Dispatcher.EnqueueAndProcess("Message Type ori"::"DataExchange.Import.Run", "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ResponseType, ResponseTime);
        LowerPermissions.StopLoggingNAVPermissions();
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(Response.ReadFrom(ResponseText), 'The registered handler must return JSON.');
        // [THEN] The documented alternative accepts the references but only creates a header.
        LibraryAssert.AreEqual('Accepted', TextProperty(Response, 'status'), 'The documented reference-only request must be accepted. Self-created request response: ' + CopyStr(ResponseText, 1, 1000));
        LibraryAssert.IsTrue(Response.Get('entryNo', EntryToken), 'Return the actual created header.');
        DataExch.Get(EntryToken.AsValue().AsInteger());
        LibraryAssert.AreEqual(Definition.Code, DataExch."Data Exch. Def Code", 'The header must use the supplied definition.');
        LibraryAssert.AreEqual('', DataExch."File Name", 'Do not persist the caller path as a file name.');
        DataExch.CalcFields("File Content");
        LibraryAssert.IsFalse(DataExch."File Content".HasValue(), 'Do not read a provider file.');
        DataExch.SetRange("Data Exch. Def Code", Definition.Code);
        LibraryAssert.AreEqual(1, DataExch.Count(), 'Only one header must be created.');
    end;

    local procedure DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
    begin
        Connector := StorageSetup."Storage Type";
        RequestMgt.ExecuteDeleteDirectory(TempArgument, StorageSetup, Connector, Path);
        exit(TempArgument.GetResponseJson());
    end;

    [TryFunction]
    local procedure TryDeleteDirectory(StorageSetup: Record "Storage Setup ori"; var Response: JsonObject)
    begin
        Response := DeleteDirectory(StorageSetup, 'X122');
    end;

    local procedure AssertDirectoryNotEmpty(Response: JsonObject)
    var
        ResponseText: Text;
    begin
        LibraryAssert.AreEqual('Error', TextProperty(Response, 'status'), 'Non-empty directory must refuse.');
        LibraryAssert.AreEqual('PreconditionFailed', TextProperty(Response, 'code'), 'Use a documented precondition code, not BusinessCentralError.');
        Response.WriteTo(ResponseText);
        LibraryAssert.IsTrue(ResponseText.Contains('path'), 'Identify the rejected path.');
        LibraryAssert.IsTrue(ResponseText.Contains('empty directory'), 'Explain the expected precondition.');
        LibraryAssert.IsTrue(ResponseText.Contains('subdirectories'), 'Give an actionable recovery step.');
    end;

    local procedure TextProperty(Response: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Response.Get(PropertyName, Token), 'Missing response property: ' + PropertyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
    end;
}
