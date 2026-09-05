namespace Origo.Bifrost.Hnitbjorg;

/// <summary>
/// Handles the notification action to open Extension Management for enabling HTTP client requests.
/// </summary>
codeunit 10035666 "Storage Http Notif. Action ori"
{
    Access = Internal;

    internal procedure RunSetupWizard(Notification: Notification)
    begin
        Page.Run(Page::"Storage Setup Wizard ori");
    end;

    /// <summary>
    /// Opens the Extension Management page where the administrator can enable Allow HttpClient Requests.
    /// </summary>
    /// <param name="Notification">The notification that triggered the action.</param>
    internal procedure OpenExtensionSettings(Notification: Notification)
    begin
        Hyperlink(GetUrl(ClientType::Web, CompanyName, ObjectType::Page, 2500));
    end;
}
