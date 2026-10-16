namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;

/// <summary>Restricted actor for issue 124. Includes BIFROST Attach ori, whose account-table grant is indirect read only.</summary>
permissionset 96236 "Storage124 Read ori"
{
    Assignable = true;
    Access = Internal;
    IncludedPermissionSets = "BIFROST Attach ori";

    Permissions =
        tabledata "Message Argument ori" = RIMD,
        tabledata "Storage Setup ori" = R,
        codeunit "Storage 124 Addr Tests ori" = X,
        codeunit "Storage Ext File Impl ori" = X,
        codeunit "Storage Request Mgt ori" = X,
        codeunit "Library - Lower Permissions" = X,
        codeunit System.TestLibraries.Utilities."Library Assert" = X,
        codeunit System.TestLibraries.Security.AccessControl."Permissions Mock" = X;
}
