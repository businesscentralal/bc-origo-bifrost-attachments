namespace Origo.Bifrost.Attachments.Test;

using System.IO;

/// <summary>Standard BC mutation of Data Exch. and Data Exch. Field: the entry rows Entry.Delete and CommitToDataExchange write beside BIFROST DataExch ori.</summary>
permissionset 96224 "Storage79 DxRows ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "Data Exch." = RIMD,
        tabledata "Data Exch. Field" = RIMD;
}
