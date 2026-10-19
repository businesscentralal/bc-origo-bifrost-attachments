namespace Origo.Bifrost.Attachments.Test;

using System.IO;

/// <summary>Standard BC mutation of the five definition tables DataExchange.Definition.Import writes beside BIFROST DataExch ori.</summary>
permissionset 96247 "Storage79 DxDef ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "Data Exch. Column Def" = RIMD,
        tabledata "Data Exch. Def" = RIMD,
        tabledata "Data Exch. Field Mapping" = RIMD,
        tabledata "Data Exch. Line Def" = RIMD,
        tabledata "Data Exch. Mapping" = RIMD;
}
