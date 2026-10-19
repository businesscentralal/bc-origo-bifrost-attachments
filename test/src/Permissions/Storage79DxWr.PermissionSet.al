namespace Origo.Bifrost.Attachments.Test;

using System.IO;

/// <summary>Standard BC mutation of Data Exch. only, without Data Exch. Field. Isolates the second write check of Entry.Delete and CommitToDataExchange.</summary>
permissionset 96223 "Storage79 DxWr ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "Data Exch." = RIMD;
}
