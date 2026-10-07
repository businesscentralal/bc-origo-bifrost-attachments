namespace Origo.Bifrost.Attachments.Test;

/// <summary>Execution support for restrictive story79 tests. Grants no production table data and no wildcard execute.</summary>
permissionset 96218 "Storage79 Test ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        codeunit "Storage 79 Perm Tests ori" = X,
        codeunit "Storage Mock Impl" = X,
        codeunit "Storage Mock State" = X,
        codeunit "Library - Lower Permissions" = X,
        codeunit System.TestLibraries.Utilities."Library Assert" = X,
        codeunit System.TestLibraries.Security.AccessControl."Permissions Mock" = X;
}
