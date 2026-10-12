namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;

/// <summary>Execution support for restrictive story79 tests. The Foundation Setup ori read is a temporary test workaround for https://github.com/OrigoSoftwareSolutions/bc-origo-bifrost-core/issues/959 until that core fix ships. No attachment table data.</summary>
permissionset 96218 "Storage79 Test ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "Setup ori" = R,
        codeunit "Storage 79 Perm Tests ori" = X,
        codeunit "Storage Mock Impl" = X,
        codeunit "Storage Mock State" = X,
        codeunit "Library - Lower Permissions" = X,
        codeunit System.TestLibraries.Utilities."Library Assert" = X,
        codeunit System.TestLibraries.Security.AccessControl."Permissions Mock" = X;
}
