namespace Origo.Bifrost.Attachments.Test;

/// <summary>
/// Grants the Data Exchange test target table, so restrictive Data Exchange import and process tests
/// can write the rows a mapping produces (AS0103: every table has a matching permission set).
/// </summary>
permissionset 96246 "DX Test Target ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "DataExch Test Target ori" = RIMD;
}
