namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using Origo.Bifrost.Attachments;

/// <summary>Advertised app/API roles and generic test execution with no provider metadata table grants.</summary>
permissionset 96236 "Storage Iface ori"
{
    Assignable = true;
    Access = Internal;
    IncludedPermissionSets = "BIFROST Attach ori", "BIFROST API ori";

    Permissions =
        tabledata "Message Argument ori" = RIMD,
        tabledata "Storage Setup ori" = R,
        codeunit "Storage Interface Tests ori" = X,
        codeunit "Storage Platform Fake ori" = X,
        codeunit "Storage Mock Impl" = X,
        codeunit "Storage Mock State" = X,
        codeunit "Library - Lower Permissions" = X,
        codeunit System.TestLibraries.Utilities."Library Assert" = X,
        codeunit System.TestLibraries.Security.AccessControl."Permissions Mock" = X;
}
