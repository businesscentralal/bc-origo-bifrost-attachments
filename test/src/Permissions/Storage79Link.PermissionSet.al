namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;

/// <summary>Source-derived BIFROST Attach fixture with attachment link read only. No production role replacement.</summary>
permissionset 96222 "Storage79 Link ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "Storage Attachment Link ori" = R,
        tabledata "Storage Setup ori" = RIMD,
        tabledata "Storage Upload Chunk ori" = RIMD,
        tabledata "Storage Upload Session ori" = RIMD,
        codeunit "Attachments Registration ori" = X,
        codeunit "Storage Account List Impl ori" = X,
        codeunit "Storage Att. Offload Impl ori" = X,
        codeunit "Storage Att. Restore Impl ori" = X,
        codeunit "Storage Attach Key Subscr ori" = X,
        codeunit "Storage Attach Link Impl ori" = X,
        codeunit "Storage Attach Record Impl ori" = X,
        codeunit "Storage Attachment Mgt ori" = X,
        codeunit "Storage Attachment Subscr ori" = X,
        codeunit "Storage Data Restriction ori" = X,
        codeunit "Storage Dir Create Impl ori" = X,
        codeunit "Storage Dir Delete Impl ori" = X,
        codeunit "Storage Dir Exists Impl ori" = X,
        codeunit "Storage Dir List Impl ori" = X,
        codeunit "Storage Ext File Impl ori" = X,
        codeunit "Storage File Copy Impl ori" = X,
        codeunit "Storage File Create Impl ori" = X,
        codeunit "Storage File Delete Impl ori" = X,
        codeunit "Storage File Exists Impl ori" = X,
        codeunit "Storage File Get Impl ori" = X,
        codeunit "Storage File List Impl ori" = X,
        codeunit "Storage File Move Impl ori" = X,
        codeunit "Storage Help Get Impl ori" = X,
        codeunit "Storage Install ori" = X,
        codeunit "Storage Link Upgrade ori" = X,
        codeunit "Storage Overview Subscr ori" = X,
        codeunit "Storage Request Mgt ori" = X,
        codeunit "Storage Request Reader ori" = X,
        codeunit "Storage Reten. Policy ori" = X,
        codeunit "Storage Takeover ori" = X,
        codeunit "Storage Takeover State ori" = X,
        codeunit "Storage Upload Abort Impl ori" = X,
        codeunit "Storage Upload Append Impl ori" = X,
        codeunit "Storage Upload Begin Impl ori" = X,
        codeunit "Storage Upload Commit Impl ori" = X,
        codeunit "Storage Upload Commit Rec ori" = X,
        codeunit "Storage Upload Mgt ori" = X,
        codeunit "Storage Upload Purge ori" = X,
        codeunit "Storage Upload Status Impl ori" = X,
        page "Attachments Setup ori" = X,
        page "Storage Account Lookup ori" = X,
        page "Storage Card ori" = X,
        page "Storage Conn. Part ori" = X,
        page "Storage Setup ori" = X,
        page "Storage Setup Wizard ori" = X;
}
