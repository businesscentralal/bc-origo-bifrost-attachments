namespace Origo.Bifrost.Attachments.Test;

/// <summary>
/// Restrictive permission set for no-read-permission take-over tests (attachments#8).
/// Grants execute on the take-over codeunits and intentionally grants no tabledata on the
/// legacy Cloud Events Storage tables (10075985 / 10075986). On W1 those tables are absent;
/// AC01 uses the <c>Storage Takeover State ori</c> probe-denial seam (Foundation core#43 pattern).
/// </summary>
permissionset 96211 "Test No Source Read"
{
    Caption = 'Test No Source Read', Comment = 'is-IS=Próf án lesheimildar', MaxLength = 30;
    Assignable = true;

    Permissions =
        codeunit "Storage Takeover ori" = X,
        codeunit "Storage Takeover State ori" = X;
}
