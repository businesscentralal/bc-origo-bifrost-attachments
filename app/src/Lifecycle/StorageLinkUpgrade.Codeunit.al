namespace Origo.Bifrost.Attachments;

using System.Upgrade;

/// <summary>
/// Deletes <c>Storage Attachment Link ori</c> rows that generic <c>Data.Records.Set</c>
/// inserted before the write restriction: Table ID 0, or an empty Record System Id.
/// Runs from install and once per company on upgrade.
/// </summary>
codeunit 10035683 "Storage Link Upgrade ori"
{
    Access = Internal;
    Subtype = Upgrade;
    Permissions = tabledata "Storage Attachment Link ori" = RD;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetOrphanLinkPurgeTag()) then
            exit;

        PurgeOrphanAttachmentLinks();
        UpgradeTag.SetUpgradeTag(GetOrphanLinkPurgeTag());
    end;

    /// <summary>
    /// Removes link rows whose Table ID is 0 or whose Record System Id is empty.
    /// Valid links are left in place.
    /// </summary>
    procedure PurgeOrphanAttachmentLinks()
    var
        Link: Record "Storage Attachment Link ori";
        EmptyGuid: Guid;
    begin
        Link.SetRange("Table ID", 0);
        Link.DeleteAll();
        Link.Reset();
        Link.SetRange("Record System Id", EmptyGuid);
        Link.DeleteAll();
    end;

    local procedure GetOrphanLinkPurgeTag(): Code[250]
    begin
        exit('Origo.Bifrost.Attachments-PurgeOrphanLinks-20260928');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", OnGetPerCompanyUpgradeTags, '', false, false)]
    local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        PerCompanyUpgradeTags.Add(GetOrphanLinkPurgeTag());
    end;
}
