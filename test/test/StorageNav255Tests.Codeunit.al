namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;

/// <summary>
/// Verifies the Bifröst Related action opens Attachments setup in both supported languages.
/// </summary>
codeunit 96285 "Storage Nav255 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    /// <summary>Runs the English Related action and checks its destination.</summary>
    [Test]
    procedure RelatedSetup_English_OpensSetup()
    begin
        // Story #255, AC1-3 | Time: independent of Today/WorkDate | Risk: Foundation navigation
        VerifySetupAction(1033, 'Bifrost Attachments Setup');
    end;

    /// <summary>Runs the Icelandic Related action and checks both captions.</summary>
    [Test]
    procedure RelatedSetup_Icelandic_OpensSetup()
    begin
        // Story #255, AC1-3 | Time: independent of Today/WorkDate | Risk: Foundation navigation
        VerifySetupAction(1039, 'Uppsetning Bifröst viðhengja');
    end;

    /// <summary>Checks navigation before any storage connection is configured.</summary>
    [Test]
    procedure RelatedSetup_NoConnections_OpensSetup()
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        // Story #255, AC1/3 | Time: independent of Today/WorkDate | Risk: None
        // [GIVEN] No connection is configured. Test isolation restores existing rows.
        StorageSetup.DeleteAll();
        VerifySetupAction(1033, 'Bifrost Attachments Setup');
    end;

    local procedure VerifySetupAction(LanguageId: Integer; ExpectedCaption: Text)
    var
        Bifrost: TestPage "Bifrost ori";
        AttachmentsSetup: TestPage "Attachments Setup ori";
        PreviousLanguage: Integer;
    begin
        // [GIVEN] The read-only Bifröst page in the requested language.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Bifrost.OpenView();
        LibraryAssert.IsTrue(Bifrost.AttachmentsSetup.Visible(), 'Attachments setup must be visible in Related.');
        LibraryAssert.IsTrue(Bifrost.AttachmentsSetup.Enabled(), 'Attachments setup must be enabled.');

        // [WHEN] The Related action runs.
        AttachmentsSetup.Trap();
        Bifrost.AttachmentsSetup.Invoke();

        // [THEN] RunObject opens the app setup page.
        LibraryAssert.AreEqual(ExpectedCaption, AttachmentsSetup.Caption(), 'The existing Attachments setup page must open.');
        AttachmentsSetup.Close();
        Bifrost.Close();
        GlobalLanguage(PreviousLanguage);
    end;
}
