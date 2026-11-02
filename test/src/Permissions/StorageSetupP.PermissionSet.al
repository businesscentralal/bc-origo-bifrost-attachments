namespace Origo.Bifrost.Attachments.Test;

using System.Environment.Configuration;

/// <summary>Platform reads required by the shared setup page, without feature-app Execute grants.</summary>
permissionset 96268 "Storage Setup P ori"
{
    Assignable = true;
    Access = Internal;
    IncludedPermissionSets = "Guided Experience - View";
    Permissions = tabledata "NAV App Setting" = r;
}
