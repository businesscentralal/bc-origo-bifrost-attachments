namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Bank.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;

/// <summary>
/// Direct grants for a restrictive dispatcher call. Setup ori is the language read Foundation does not
/// carry. The Data Exchange grants are the tables those message types read or change. Indirect Permissions
/// on a caller codeunit did not grant the setup read.
/// </summary>
permissionset 96235 "Lang Setup Read ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "Setup ori" = R,
        tabledata "Bank Export/Import Setup" = R,
        tabledata "Data Exch." = RIMD,
        tabledata "Data Exch. Column Def" = RIMD,
        tabledata "Data Exch. Def" = RIMD,
        tabledata "Data Exch. Field" = RIMD,
        tabledata "Data Exch. Field Mapping" = RIMD,
        tabledata "Data Exch. Line Def" = RIMD,
        tabledata "Data Exch. Mapping" = RIMD,
        tabledata "Data Exchange Type" = RIMD,
        codeunit "Dispatcher ori" = X,
        codeunit "DataExch Def Delete Impl ori" = X,
        codeunit "DataExch Export Run Impl ori" = X,
        codeunit "DataExch Import Run Impl ori" = X,
        codeunit "DataExch Type Set Impl ori" = X,
        codeunit "Storage Request Mgt ori" = X,
        codeunit "Storage Request Reader ori" = X;
}
