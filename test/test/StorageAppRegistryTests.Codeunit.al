namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.Apps;

/// <summary>
/// Tests that Bifrost Attachments registers itself with Bifröst Foundation's application
/// registry. Setup notifications live on the shared Bifröst Setup page only, and that page can
/// speak for this module solely because <c>Attachments Registration ori</c> answers Foundation's
/// <c>OnRegisterApps</c> event with this app's identity and its setup page.
/// </summary>
codeunit 96208 "Storage App Registry Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        AppNameTok: Label 'Bifrost Attachments', Locked = true;

    [Test]
    procedure AppRegistry_ListsThisApp_WithItsSetupPage()
    var
        InstalledApp: Record "NAV App Installed App";
        TempRegisteredApp: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
    begin
        // [SCENARIO] Foundation's registry knows Bifrost Attachments and where to send the
        // administrator when the setup notification's "Start setup wizard" action is used.
        // NavApp.GetCurrentModuleInfo cannot be used here - called from this test codeunit it
        // would return the identity of the test app itself, not of Bifrost Attachments, so the
        // main app's id is resolved from the installed-extensions table by name instead.

        // [GIVEN] The installed Bifrost Attachments extension
        InstalledApp.SetLoadFields("App ID");
        InstalledApp.SetRange(Name, AppNameTok);
        LibraryAssert.IsTrue(InstalledApp.FindFirst(), 'Bifrost Attachments must be installed for this test to run.');

        // [WHEN] Foundation collects the registered applications
        AppRegistry.GetApps(TempRegisteredApp);

        // [THEN] This app is one of them
        LibraryAssert.IsTrue(TempRegisteredApp.Get(InstalledApp."App ID"), 'Bifrost Attachments should be registered with the Bifrost application registry.');

        // [THEN] It points at its own setup page and carries its display name
        LibraryAssert.AreEqual(Page::"Attachments Setup ori", TempRegisteredApp."Setup Page Id", 'The registry should point at the Bifrost Attachments setup page.');
        LibraryAssert.AreEqual(AppNameTok, TempRegisteredApp."App Name", 'The registry should carry the application name.');
    end;
}
