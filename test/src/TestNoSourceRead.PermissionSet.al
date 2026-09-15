namespace Origo.Bifrost.Attachments.Test;

/// <summary>
/// Named Restrictive permission set for no-read-permission take-over tests (attachments#8 /
/// docex PR #12 pattern). Intentionally empty: legacy Cloud Events tables 10075985 / 10075986
/// are not in this app, and Attachments target tables are Internal (AL0185 under compiler-folder
/// if listed here). AC01 uses the <c>Storage Takeover State ori</c> probe-denial seam
/// (Foundation core#43), matching production install skip behavior.
/// </summary>
permissionset 96211 "Test No Source Read"
{
    Caption = 'Test No Source Read', Comment = 'is-IS=Próf án lesheimildar', MaxLength = 30;
    Assignable = true;
}
