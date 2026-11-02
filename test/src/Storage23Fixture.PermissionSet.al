namespace Origo.Bifrost.Attachments.Test;

/// <summary>Test-only permission coverage for isolated MCP fixture bytes and their connector.</summary>
permissionset 96250 "Storage23Fixture ori"
{
    Assignable = true;
    Caption = 'Storage 23 Fixture';
    Permissions =
        tabledata "Storage 23 Fixture File ori" = RIMD,
        table "Storage 23 Fixture File ori" = X,
        codeunit "Storage 23 Fixture Impl ori" = X;
}
