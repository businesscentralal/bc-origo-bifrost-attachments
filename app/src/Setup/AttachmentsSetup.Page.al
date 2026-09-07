namespace Origo.Bifrost.Attachments;

using System.ExternalFileStorage;

/// <summary>
/// Setup page of the Bifrost Attachments application. It is opened from the Apps group on the
/// Bifröst Setup page and gathers everything an administrator needs for this module: the list
/// of configured storage connections, the standard file account setup, and the housekeeping
/// action that removes abandoned upload sessions. It raises no setup notification of its own -
/// those belong to the shared Bifröst Setup page, which reaches this app through
/// <c>Attachments Registration ori</c>.
/// </summary>
page 10035677 "Attachments Setup ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Bifrost Attachments Setup', Comment = 'is-IS=Uppsetning Bifröst viðhengja';
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    ContextSensitiveHelpPage = 'hnitbjorg-setup';

    layout
    {
        area(Content)
        {
            group(Connections)
            {
                Caption = 'Storage Connections', Comment = 'is-IS=Geymslutengingar';

                part(ConnectionList; "Storage Conn. Part ori")
                {
                    ApplicationArea = All;
                    Caption = 'Storage Connections', Comment = 'is-IS=Geymslutengingar';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(FileAccountWizard)
            {
                ApplicationArea = All;
                Caption = 'Storage Setup Wizard', Comment = 'is-IS=Leiðsagnarforrit geymsluuppsetningar';
                ToolTip = 'Run the guided setup to add a new file storage account (Azure Blob, Azure File Share, SharePoint, etc.).', Comment = 'is-IS=Keyra leiðsagnarforritið til að bæta við nýjum skráargeymslureikningi (Azure Blob, Azure File Share, SharePoint, o.fl.).';
                Image = Setup;
                RunObject = page "File Account Wizard";
            }
            action(FileAccounts)
            {
                ApplicationArea = All;
                Caption = 'Storage Setup', Comment = 'is-IS=Uppsetning geymslu';
                ToolTip = 'View and manage the registered file storage accounts.', Comment = 'is-IS=Skoða og stjórna skráðum skráargeymslureikningum.';
                Image = Accounts;
                RunObject = page "File Accounts";
            }
            action(StorageSetup)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Storage Setup', Comment = 'is-IS=Uppsetning Bifröst geymslu';
                ToolTip = 'View and manage storage connections used to route Bifrost file requests to file accounts.', Comment = 'is-IS=Skoða og stjórna geymslutengingum sem eru notaðar til að beina skráarbeiðnum Bifrastar á skráargeymslureikninga.';
                Image = Attach;
                RunObject = page "Storage Setup ori";
            }
            action(PurgeUploadSessions)
            {
                ApplicationArea = All;
                Caption = 'Purge Upload Sessions', Comment = 'is-IS=Hreinsa upphleðslulotur';
                ToolTip = 'Deletes abandoned upload sessions and their chunks. Sessions that were never committed or aborted leave data behind; this action removes it.', Comment = 'is-IS=Eyðir yfirgefnum upphleðslulotum og bitum þeirra. Lotur sem aldrei voru staðfestar eða hætt við skilja eftir gögn; þessi aðgerð fjarlægir þau.';
                Image = ClearLog;

                trigger OnAction()
                var
                    UploadPurge: Codeunit "Storage Upload Purge ori";
                begin
                    UploadPurge.PurgeAndNotify();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process', Comment = 'is-IS=Vinnsla';

                actionref(FileAccountWizard_Promoted; FileAccountWizard) { }
                actionref(StorageSetup_Promoted; StorageSetup) { }
                actionref(FileAccounts_Promoted; FileAccounts) { }
                actionref(PurgeUploadSessions_Promoted; PurgeUploadSessions) { }
            }
        }
    }
}
