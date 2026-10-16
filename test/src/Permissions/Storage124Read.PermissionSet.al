namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;

/// <summary>Base actor for issue 124. Account-table read is not included; a test grants it at runtime by table number.</summary>
permissionset 96236 "Storage124 Read ori"
{
    Assignable = true;
    Access = Internal;

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
