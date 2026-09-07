namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Makes Bifrost Attachments known to Bifröst Foundation's application registry. Foundation's
/// shared <c>Setup ori</c> page is the only place where setup notifications for a Bifröst module
/// are raised, and it can only speak for an application that has registered itself. Registering
/// gives Foundation this app's identity, its display name and the page to open when the
/// administrator follows the notification's "Start setup wizard" action.
/// </summary>
codeunit 10035680 "Attachments Registration ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), Page::"Attachments Setup ori");
    end;
}
