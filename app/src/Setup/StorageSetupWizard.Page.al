namespace Origo.Bifrost.Hnitbjorg;

using System.Apps;
using System.Environment.Configuration;

/// <summary>
/// Setup wizard for Bifrost Storage. Guides the user through enabling
/// HTTP client requests so the extension can communicate with external storage.
/// </summary>
page 10035638 "Storage Setup Wizard ori"
{
    PageType = NavigatePage;
    Caption = 'Bifrost Storage Setup', Comment = 'is-IS=Uppsetning Bifröst geymslu';
    ApplicationArea = All;
    Editable = true;
    ContextSensitiveHelpPage = 'storage-setup';

    layout
    {
        area(Content)
        {
            group(Step1Welcome)
            {
                Visible = (CurrentStep = 1);
                group(WelcomeHeader)
                {
                    Caption = 'Welcome to Bifrost Storage', Comment = 'is-IS=Velkomin í Bifröst geymslu';
                    ShowCaption = true;
                    InstructionalText = 'This wizard helps you set up external storage for Bifrost. The extension exposes Azure Blob, Azure File Share and SharePoint connectors as Bifrost message types, giving read/write access to cloud storage from Business Central.', Comment = 'is-IS=Þessi leiðsögn hjálpar þér að setja upp ytri geymslu fyrir Bifröst. Viðbótin býður upp á Azure Blob, Azure File Share og SharePoint tengla sem skilaboðagerðir Bifrastar og veitir þannig les- og skrifaðgang að skýjageymslu úr Business Central.';
                }
                group(WelcomeNote)
                {
                    Caption = 'Note', Comment = 'is-IS=Athugasemd';
                    InstructionalText = 'You need a configured file storage account (Azure Blob, Azure File Share, or SharePoint) and outbound HTTP must be enabled for this extension.', Comment = 'is-IS=Þú þarft uppsettan skráargeymslureikning (Azure Blob, Azure File Share eða SharePoint) og HTTP-biðlarabeiðnir þurfa að vera virkar fyrir þessa viðbót.';
                }
            }
            group(Step2Http)
            {
                Visible = (CurrentStep = 2);
                group(HttpHeader)
                {
                    Caption = 'Enable HTTP Client Requests', Comment = 'is-IS=Virkja HTTP-biðlarabeiðnir';
                    InstructionalText = 'Bifrost Storage requires outbound HTTP to communicate with external storage providers. Please enable Allow HttpClient Requests for this extension.', Comment = 'is-IS=Bifröst geymsla þarf útleið HTTP til að eiga samskipti við ytri geymsluveitendur. Vinsamlegast virkjaðu Leyfa HttpClient-beiðnir fyrir þessa viðbót.';
                }
                group(HttpStatus)
                {
                    Caption = 'Status', Comment = 'is-IS=Staða';
                    field(HttpEnabledField; HttpStatusTxt)
                    {
                        Caption = 'HTTP Client Requests', Comment = 'is-IS=HTTP-biðlarabeiðnir';
                        ToolTip = 'Shows whether HTTP client requests are currently enabled for this extension.', Comment = 'is-IS=Sýnir hvort HTTP-biðlarabeiðnir séu virkar fyrir þessa viðbót.';
                        Editable = false;
                        StyleExpr = HttpStatusStyle;
                    }
                }
            }
            group(Step3Finish)
            {
                Visible = (CurrentStep = 3);
                group(FinishHeader)
                {
                    Caption = 'Setup Complete', Comment = 'is-IS=Uppsetningu lokið';
                    InstructionalText = 'HTTP client requests are enabled. You can now configure storage connections from the Bifrost Storage Setup page. Use the Storage Setup Wizard action on the Bifrost Setup page to add file accounts.', Comment = 'is-IS=HTTP-biðlarabeiðnir eru virkar. Þú getur nú stillt geymslutengingar á uppsetningarsíðu Bifröst geymslu. Notaðu aðgerðina Leiðsagnarforrit geymsluuppsetningar á uppsetningarsíðu Bifrastar til að bæta við skráargeymslureikningum.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionBack)
            {
                Caption = 'Back', Comment = 'is-IS=Til baka';
                Image = PreviousRecord;
                InFooterBar = true;
                Enabled = BackEnabled;

                trigger OnAction()
                begin
                    CurrentStep -= 1;
                    UpdateControls();
                end;
            }
            action(ActionNext)
            {
                Caption = 'Next', Comment = 'is-IS=Áfram';
                Image = NextRecord;
                InFooterBar = true;
                Enabled = NextEnabled;
                Visible = (CurrentStep < 3);

                trigger OnAction()
                begin
                    CurrentStep += 1;
                    OnStepEnter();
                    UpdateControls();
                end;
            }
            action(ActionFinish)
            {
                Caption = 'Finish', Comment = 'is-IS=Ljúka';
                Image = Approve;
                InFooterBar = true;
                Visible = (CurrentStep = 3);

                trigger OnAction()
                begin
                    FinishWizard();
                    CurrPage.Close();
                end;
            }
            action(ActionEnableHttp)
            {
                Caption = 'Enable HTTP Client Requests', Comment = 'is-IS=Virkja HTTP-biðlarabeiðnir';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 2) and (not HttpEnabled) and CanWriteAppSetting;

                trigger OnAction()
                begin
                    EnableHttpClientRequests();
                    CheckHttpEnabled();
                    UpdateControls();
                end;
            }
            action(ActionOpenExtSettings)
            {
                Caption = 'Open Extension Settings', Comment = 'is-IS=Opna stillingar viðbótar';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 2) and (not HttpEnabled) and (not CanWriteAppSetting);

                trigger OnAction()
                begin
                    Hyperlink(GetUrl(ClientType::Web, CompanyName, ObjectType::Page, 2500));
                end;
            }
            action(ActionRefreshHttp)
            {
                Caption = 'Verify', Comment = 'is-IS=Staðfesta';
                Image = Refresh;
                InFooterBar = true;
                Visible = (CurrentStep = 2);

                trigger OnAction()
                begin
                    CheckHttpEnabled();
                    UpdateControls();
                end;
            }
        }
    }

    var
        HttpStatusTxt: Text;
        HttpStatusStyle: Text;
        HttpEnabled: Boolean;
        CanWriteAppSetting: Boolean;
        NextEnabled: Boolean;
        BackEnabled: Boolean;
        CurrentStep: Integer;
        HttpEnabledTok: Label 'Enabled', Comment = 'is-IS=Virkt';
        HttpDisabledTok: Label 'Not Enabled - Please enable Allow HttpClient Requests', Comment = 'is-IS=Ekki virkt - Vinsamlegast virkjaðu Leyfa HttpClient-beiðnir';

    trigger OnOpenPage()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        CurrentStep := 1;
        InitializeData();
        if GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"Storage Setup Wizard ori") then
            CurrentStep := 3;
        UpdateControls();
    end;

    local procedure InitializeData()
    var
        NavAppSetting: Record "NAV App Setting";
    begin
        CanWriteAppSetting := NavAppSetting.WritePermission();
        CheckHttpEnabled();
    end;

    local procedure OnStepEnter()
    begin
        if CurrentStep = 2 then
            CheckHttpEnabled();
    end;

    local procedure UpdateControls()
    begin
        BackEnabled := CurrentStep > 1;
        case CurrentStep of
            2:
                NextEnabled := HttpEnabled;
            else
                NextEnabled := true;
        end;
    end;

    local procedure CheckHttpEnabled()
    var
        NavAppSetting: Record "NAV App Setting";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        HttpEnabled := NavAppSetting.Get(AppInfo.Id()) and NavAppSetting."Allow HttpClient Requests";
        if HttpEnabled then begin
            HttpStatusTxt := HttpEnabledTok;
            HttpStatusStyle := 'Favorable';
        end else begin
            HttpStatusTxt := HttpDisabledTok;
            HttpStatusStyle := 'Unfavorable';
        end;
    end;

    local procedure EnableHttpClientRequests()
    var
        NavAppSetting: Record "NAV App Setting";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        if not NavAppSetting.Get(AppInfo.Id()) then begin
            NavAppSetting.Init();
            NavAppSetting."App ID" := AppInfo.Id();
            NavAppSetting.Insert();
        end;
        NavAppSetting."Allow HttpClient Requests" := true;
        NavAppSetting.Modify();
    end;

    local procedure FinishWizard()
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"Storage Setup Wizard ori");
    end;
}
