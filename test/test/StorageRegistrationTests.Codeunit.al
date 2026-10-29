namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.TestLibraries.Utilities;

/// <summary>Setup must open for a licence administrator with Attachments installed.</summary>
codeunit 96268 "Storage Registration Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure LicenceAdmin_OpensSetup_English()
    begin
        AssertLicenceAdminOpensSetup(1033);
    end;

    [Test]
    procedure LicenceAdmin_OpensSetup_Icelandic()
    begin
        AssertLicenceAdminOpensSetup(1039);
    end;

    local procedure AssertLicenceAdminOpensSetup(LanguageId: Integer)
    var
        BifrostSetup: Record "Setup ori";
        TempRegisteredApp: Record "Registered App ori" temporary;
        StorageSetup: Record "Storage Setup ori";
        AppRegistry: Codeunit "App Registry ori";
        SetupPage: TestPage "Setup ori";
        SavedLanguageId: Integer;
        Registered: Boolean;
        SetupEditable: Boolean;
        SyncVisible: Boolean;
        StorageWritable: Boolean;
        RegisteredSetupPageId: Integer;
    begin
        // [GIVEN] Only the real licence-admin role and the page's platform read baseline.
        // Prepare setup before lowering grants; never change consent, trials, licensing or quota.
        LowerPermissions.StopLoggingNAVPermissions();
        BifrostSetup.InsertIfNotExists();
        BifrostSetup.Get();
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST LicAdm ori');
        LowerPermissions.AddPermissionSet('Storage Setup P ori');

        // [WHEN] Opening the actual Foundation setup invokes the installed app subscribers.
        // Do not invoke Sync: opening the page needs no backend or licensing-state writes.
        SetupPage.OpenView();
        SetupEditable := SetupPage.Editable();
        SyncVisible := SetupPage.RefreshLicense.Visible();
        SetupPage.Close();
        AppRegistry.GetApps(TempRegisteredApp);
        Registered := TempRegisteredApp.Get('{672df32a-a0c5-4a22-b591-0efa38023e95}');
        RegisteredSetupPageId := TempRegisteredApp."Setup Page Id";
        StorageWritable := StorageSetup.WritePermission();
        LowerPermissions.StopLoggingNAVPermissions();
        GlobalLanguage(SavedLanguageId);

        // [THEN] Registration works without making a licence administrator a feature administrator.
        Assert.IsTrue(Registered, 'Attachments must register for a restricted licence administrator.');
        Assert.AreEqual(Page::"Attachments Setup ori", RegisteredSetupPageId, 'The registry must retain the Attachments setup target.');
        Assert.IsFalse(SetupEditable, 'The licence administrator must not gain setup editing permission.');
        Assert.IsTrue(SyncVisible, 'The licence administrator must retain the Sync action.');
        Assert.IsFalse(StorageWritable, 'Registration must not grant storage setup writes.');
    end;
}
