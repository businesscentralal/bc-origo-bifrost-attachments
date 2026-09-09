namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Adds the storage connector to Foundation's "BIFROST Full ori" role, so a Bifröst
/// administrator gets it without a second assignment. The grants are the same ones the
/// assignable "BIFROST Attach ori" set carries - keep the two lists in step.
/// </summary>
permissionsetextension 10035635 "Storage Full ori" extends "BIFROST Full ori"
{
    Permissions =
        tabledata "Storage Attachment Link ori" = RIMD,
        tabledata "Storage Setup ori" = RIMD,
        tabledata "Storage Upload Chunk ori" = RIMD,
        tabledata "Storage Upload Session ori" = RIMD,
        codeunit "Attachments Registration ori" = X,
        codeunit "Storage Account Help ori" = X,
        codeunit "Storage Account List Impl ori" = X,
        codeunit "Storage Att. Offload Impl ori" = X,
        codeunit "Storage Att. Restore Impl ori" = X,
        codeunit "Storage Attach Key Subscr ori" = X,
        codeunit "Storage Attach Link Impl ori" = X,
        codeunit "Storage Attach Record Impl ori" = X,
        codeunit "Storage Attachment Help ori" = X,
        codeunit "Storage Attachment Mgt ori" = X,
        codeunit "Storage Attachment Subscr ori" = X,
        codeunit "Storage Data Restriction ori" = X,
        codeunit "Storage Dir Create Impl ori" = X,
        codeunit "Storage Dir Delete Impl ori" = X,
        codeunit "Storage Dir Exists Impl ori" = X,
        codeunit "Storage Dir Help ori" = X,
        codeunit "Storage Dir List Impl ori" = X,
        codeunit "Storage Ext File Impl ori" = X,
        codeunit "Storage File Copy Impl ori" = X,
        codeunit "Storage File Create Impl ori" = X,
        codeunit "Storage File Delete Impl ori" = X,
        codeunit "Storage File Exists Impl ori" = X,
        codeunit "Storage File Get Impl ori" = X,
        codeunit "Storage File Help ori" = X,
        codeunit "Storage File List Impl ori" = X,
        codeunit "Storage File Move Impl ori" = X,
        codeunit "Storage Help Builder ori" = X,
        codeunit "Storage Help Get Impl ori" = X,
        codeunit "Storage Install ori" = X,
        codeunit "Storage Overview Help ori" = X,
        codeunit "Storage Overview Subscr ori" = X,
        codeunit "Storage Request Mgt ori" = X,
        codeunit "Storage Reten. Policy ori" = X,
        codeunit "Storage Takeover ori" = X,
        codeunit "Storage Upload Abort Impl ori" = X,
        codeunit "Storage Upload Append Impl ori" = X,
        codeunit "Storage Upload Begin Impl ori" = X,
        codeunit "Storage Upload Commit Impl ori" = X,
        codeunit "Storage Upload Commit Rec ori" = X,
        codeunit "Storage Upload Help ori" = X,
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
