namespace Origo.Bifrost.Hnitbjorg;

using Origo.Bifrost;
using System.Apps;
using System.Environment.Configuration;
using System.ExternalFileStorage;

/// <summary>
/// Extends the Bifrost Setup page with a Storage group in the Navigation area.
/// Provides access to the standard File Account Wizard, the standard File Accounts list,
/// and the Bifrost Storage Setup list for this extension.
/// </summary>
pageextension 10035635 "Setup Ext. ori" extends "Setup ori"
{
    actions
    {
        addlast(Navigation)
        {
            group(StorageGroup)
            {
                Caption = 'Storage', Comment = 'is-IS=Geymsla';
                Image = Departments;

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
                    begin
                        PurgeUploadData();
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        ShowHttpClientNotification();
    end;

    local procedure ShowHttpClientNotification()
    var
        NavAppSetting: Record "NAV App Setting";
        HttpNotification: Notification;
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        if NavAppSetting.Get(AppInfo.Id()) then
            if NavAppSetting."Allow HttpClient Requests" then
                exit;

        HttpNotification.Id := 'e7f5a04b-9c1d-4e6f-d0b4-6a8a2f1e5d07';
        HttpNotification.Scope := NotificationScope::LocalScope;
        HttpNotification.Message := HttpClientDisabledMsg;
        HttpNotification.AddAction(RunSetupWizardLbl, Codeunit::"Storage Http Notif. Action ori", 'RunSetupWizard');
        HttpNotification.AddAction(EnableHttpClientLbl, Codeunit::"Storage Http Notif. Action ori", 'OpenExtensionSettings');
        HttpNotification.Send();
    end;

    local procedure PurgeUploadData()
    var
        Session: Record "Storage Upload Session ori";
        Chunk: Record "Storage Upload Chunk ori";
        SessionCount: Integer;
        ChunkCount: Integer;
    begin
        ChunkCount := Chunk.Count();
        Chunk.DeleteAll(true);
        SessionCount := Session.Count();
        Session.DeleteAll(true);
        Message(PurgedMsg, SessionCount, ChunkCount);
    end;

    var
        HttpClientDisabledMsg: Label 'HTTP client requests are not enabled for the Bifrost Storage extension. Storage operations will not work until an administrator enables Allow HttpClient Requests in Extension Settings.', Comment = 'is-IS=HTTP-biðlarabeiðnir eru ekki virkar fyrir viðbótina Bifröst geymsla. Geymsluaðgerðir virka ekki fyrr en kerfisstjóri virkjar Leyfa HttpClient-beiðnir í stillingum viðbótar.';
        RunSetupWizardLbl: Label 'Run Setup Wizard', Comment = 'is-IS=Keyra leiðsagnarforrit';
        EnableHttpClientLbl: Label 'Open Extension Settings', Comment = 'is-IS=Opna stillingar viðbótar';
        PurgedMsg: Label 'Purged %1 upload session(s) and %2 chunk(s).', Comment = 'is-IS=Hreinsaði %1 upphleðslulotu/-lotur og %2 bita., %1 = session count, %2 = chunk count';
}
