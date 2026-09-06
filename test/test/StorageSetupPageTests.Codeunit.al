namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;

/// <summary>
/// Tests for the Bifröst viðhengi setup surface. They cover the new <c>Attachments Setup ori</c>
/// page (it opens, lists the configured storage connections and offers the four setup actions),
/// the single Apps action the app contributes to the shared <c>Setup ori</c> page, and the
/// upload-purge housekeeping logic behind the page action.
/// </summary>
codeunit 96207 "Storage Setup Page Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        MockCodeTok: Label 'BIFTS-SETUP', Locked = true;

    [Test]
    [HandlerFunctions('NotificationHandler')]
    procedure AttachmentsSetupPage_Opens_ListsStorageConnections()
    var
        AttachmentsSetup: TestPage "Attachments Setup ori";
    begin
        // [SCENARIO] The application setup page opens and shows the configured storage connections.
        Initialize();

        // [GIVEN] One configured storage connection
        InsertStorageConnection();

        // [WHEN] The Bifröst viðhengi setup page is opened
        AttachmentsSetup.OpenView();

        // [THEN] The embedded connection list shows the connection
        LibraryAssert.IsTrue(AttachmentsSetup.ConnectionList.First(), 'The connection list should contain a row.');
        LibraryAssert.AreEqual(MockCodeTok, AttachmentsSetup.ConnectionList."Code".Value(), 'The connection list should show the configured storage code.');
        AttachmentsSetup.Close();
    end;

    [Test]
    [HandlerFunctions('NotificationHandler')]
    procedure AttachmentsSetupPage_AllSetupActions_AreEnabled()
    var
        AttachmentsSetup: TestPage "Attachments Setup ori";
    begin
        // [SCENARIO] The four actions moved off the shared setup page are present and usable here.
        Initialize();

        // [WHEN] The Bifröst viðhengi setup page is opened
        AttachmentsSetup.OpenView();

        // [THEN] Every setup action is enabled
        LibraryAssert.IsTrue(AttachmentsSetup.FileAccountWizard.Enabled(), 'Storage Setup Wizard should be enabled.');
        LibraryAssert.IsTrue(AttachmentsSetup.FileAccounts.Enabled(), 'Storage Setup should be enabled.');
        LibraryAssert.IsTrue(AttachmentsSetup.StorageSetup.Enabled(), 'Bifrost Storage Setup should be enabled.');
        LibraryAssert.IsTrue(AttachmentsSetup.PurgeUploadSessions.Enabled(), 'Purge Upload Sessions should be enabled.');
        AttachmentsSetup.Close();
    end;

    [Test]
    [HandlerFunctions('NotificationHandler')]
    procedure BifrostSetupPage_ExposesOnlyTheAppsAction()
    var
        BifrostSetup: TestPage "Setup ori";
    begin
        // [SCENARIO] On the shared Bifröst Setup page this app contributes exactly one action:
        // the Apps entry that opens its own setup page. The former Storage navigation group and
        // its four actions are gone - a reference to any of them here would not compile.
        Initialize();

        // [WHEN] The shared Bifröst Setup page is opened
        BifrostSetup.OpenView();

        // [THEN] The single Apps action is available
        LibraryAssert.IsTrue(BifrostSetup.AttachmentsSetup.Enabled(), 'The Bifrost Attachments Apps action should be enabled.');
        LibraryAssert.IsTrue(BifrostSetup.AttachmentsSetup.Visible(), 'The Bifrost Attachments Apps action should be visible.');
        BifrostSetup.Close();
    end;

    [Test]
    procedure Purge_WithAbandonedSessions_DeletesSessionsAndChunks()
    var
        UploadSession: Record "Storage Upload Session ori";
        UploadChunk: Record "Storage Upload Chunk ori";
        UploadPurge: Codeunit "Storage Upload Purge ori";
        SessionCount: Integer;
        ChunkCount: Integer;
    begin
        // [SCENARIO] Purging removes every abandoned upload session and all of its chunks.
        Initialize();

        // [GIVEN] Two abandoned sessions holding three chunks in total
        InsertAbandonedUpload(2);
        InsertAbandonedUpload(1);

        // [WHEN] The purge runs
        UploadPurge.Purge(SessionCount, ChunkCount);

        // [THEN] It reports what it removed and leaves no rows behind
        LibraryAssert.AreEqual(2, SessionCount, 'Both sessions should be counted as purged.');
        LibraryAssert.AreEqual(3, ChunkCount, 'All three chunks should be counted as purged.');
        LibraryAssert.IsTrue(UploadSession.IsEmpty(), 'No upload session should remain.');
        LibraryAssert.IsTrue(UploadChunk.IsEmpty(), 'No upload chunk should remain.');
    end;

    [Test]
    procedure Purge_WithoutData_ReportsZeroAndSucceeds()
    var
        UploadPurge: Codeunit "Storage Upload Purge ori";
        SessionCount: Integer;
        ChunkCount: Integer;
    begin
        // [SCENARIO] Purging when there is nothing to purge is a no-op, not an error.
        Initialize();

        // [WHEN] The purge runs against empty tables
        UploadPurge.Purge(SessionCount, ChunkCount);

        // [THEN] It reports nothing removed
        LibraryAssert.AreEqual(0, SessionCount, 'No session should be reported.');
        LibraryAssert.AreEqual(0, ChunkCount, 'No chunk should be reported.');
    end;

    [Test]
    [HandlerFunctions('NotificationHandler,PurgedMessageHandler')]
    procedure PurgeAction_OnSetupPage_PurgesAndInformsTheUser()
    var
        UploadSession: Record "Storage Upload Session ori";
        AttachmentsSetup: TestPage "Attachments Setup ori";
    begin
        // [SCENARIO] The page action wires the purge codeunit up and reports the result.
        Initialize();

        // [GIVEN] An abandoned session with one chunk
        InsertAbandonedUpload(1);

        // [WHEN] The purge action is invoked from the setup page
        AttachmentsSetup.OpenView();
        AttachmentsSetup.PurgeUploadSessions.Invoke();
        AttachmentsSetup.Close();

        // [THEN] The session is gone (the message text is asserted in the handler)
        LibraryAssert.IsTrue(UploadSession.IsEmpty(), 'The abandoned session should have been purged.');
    end;

    local procedure Initialize()
    var
        StorageSetup: Record "Storage Setup ori";
        UploadSession: Record "Storage Upload Session ori";
        UploadChunk: Record "Storage Upload Chunk ori";
    begin
        UploadChunk.DeleteAll(true);
        UploadSession.DeleteAll(true);
        StorageSetup.DeleteAll();
    end;

    local procedure InsertStorageConnection()
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        StorageSetup.Init();
        StorageSetup."Code" := MockCodeTok;
        StorageSetup.Description := 'Setup page test connection';
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
    end;

    local procedure InsertAbandonedUpload(ChunkCount: Integer)
    var
        UploadSession: Record "Storage Upload Session ori";
        UploadChunk: Record "Storage Upload Chunk ori";
        UploadId: Guid;
        Index: Integer;
    begin
        UploadId := CreateGuid();
        UploadSession.Init();
        UploadSession."Upload Id" := UploadId;
        UploadSession."File Name" := 'abandoned.txt';
        UploadSession."Chunk Count" := ChunkCount;
        UploadSession.Status := UploadSession.Status::Open;
        UploadSession.Insert(true);

        for Index := 1 to ChunkCount do begin
            UploadChunk.Init();
            UploadChunk."Upload Id" := UploadId;
            UploadChunk."Sequence No." := Index;
            UploadChunk.Size := 1;
            UploadChunk.Insert(true);
        end;
    end;

    [SendNotificationHandler]
    procedure NotificationHandler(var TheNotification: Notification): Boolean
    begin
        exit(true);
    end;

    [MessageHandler]
    procedure PurgedMessageHandler(Msg: Text[1024])
    begin
        LibraryAssert.IsTrue(Msg.Contains('Purged'), 'The purge action should report what it removed.');
    end;
}
