namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;

/// <summary>#232 test seam: overrides the Foundation setup mode answer seen by the Attachments restriction subscribers.</summary>
codeunit 96283 "Storage Setup Mode Seam 232"
{
    EventSubscriberInstance = Manual;

    var
        SetupModeActive: Boolean;

    procedure SetActive(Active: Boolean)
    begin
        SetupModeActive := Active;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Storage Data Restriction ori", 'OnBeforeIsSetupModeActive', '', false, false)]
    local procedure OverrideSetupMode(var Active: Boolean; var Handled: Boolean)
    begin
        Active := SetupModeActive;
        Handled := true;
    end;
}
