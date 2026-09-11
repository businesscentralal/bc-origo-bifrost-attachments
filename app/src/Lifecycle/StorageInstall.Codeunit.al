namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.Environment.Configuration;
using System.Media;
using System.Upgrade;

/// <summary>
/// The single install entry point of the app. It first hands over to
/// <c>Storage Takeover ori</c>, which copies the data of the published Origo Cloud Events
/// Storage app, and only then registers the change log guard exceptions, the assisted setup
/// and the initial-release upgrade tag - so everything registered here sees the taken-over
/// data. The connector keeps no singleton setup: storage connections are created as needed in
/// <c>Bifrost Storage Setup</c>.
/// </summary>
codeunit 10035637 "Storage Install ori"
{
    Subtype = Install;
    Access = Internal;
    Permissions = tabledata "Setup ori" = R;

    trigger OnInstallAppPerCompany()
    var
        StorageTakeover: Codeunit "Storage Takeover ori";
    begin
        StorageTakeover.TakeOverAll();
        RegisterChangeLogGuardExceptions();
        RegisterAssistedSetup();
        SetUpgradeTags();
    end;

    local procedure RegisterChangeLogGuardExceptions()
    var
        BifrostSetup: Record "Setup ori";
    begin
        if not BifrostSetup.Get() then
            exit;
        BifrostSetup.AddChangeLogGuardException(Database::"Storage Attachment Link ori", 0);
    end;

    local procedure RegisterAssistedSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        if not GuidedExperience.Exists("Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"Storage Setup Wizard ori") then
            GuidedExperience.InsertAssistedSetup(
                SetupWizardTitleTok, SetupWizardShortTitleTok, SetupWizardDescriptionTok,
                0, ObjectType::Page, Page::"Storage Setup Wizard ori",
                "Assisted Setup Group"::Extensions, '', "Video Category"::Uncategorized, '');
    end;

    local procedure SetUpgradeTags()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetInitialReleaseTag()) then
            UpgradeTag.SetUpgradeTag(GetInitialReleaseTag());
    end;

    /// <summary>Returns the per-company upgrade tag for the initial storage connector release.</summary>
    /// <returns>The initial-release upgrade tag.</returns>
    procedure GetInitialReleaseTag(): Code[250]
    begin
        exit('Origo.Bifrost.Attachments-Initial-20260905');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", OnGetPerCompanyUpgradeTags, '', false, false)]
    local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        PerCompanyUpgradeTags.Add(GetInitialReleaseTag());
    end;

    var
        SetupWizardTitleTok: Label 'Set up Bifrost Attachments', Comment = 'is-IS=Setja upp Bifröst viðhengi';
        SetupWizardShortTitleTok: Label 'Bifrost Attachments', Comment = 'is-IS=Bifröst viðhengi';
        SetupWizardDescriptionTok: Label 'Enable HTTP client requests and configure external storage connections for Bifrost.', Comment = 'is-IS=Virkja HTTP-biðlarabeiðnir og stilla ytri geymslutengingar fyrir Bifröst.';
}
