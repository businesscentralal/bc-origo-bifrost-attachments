namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.IO;

/// <summary>Source-derived BIFROST DataExch fixture omitting Data Exch. Field Mapping read only; all other discovery reads retained.</summary>
permissionset 96231 "Storage79 FldMap ori"
{
    Assignable = true;
    Access = Internal;

    Permissions =
        tabledata "Data Exch." = R,
        tabledata "Data Exch. Column Def" = R,
        tabledata "Data Exch. Def" = R,
        tabledata "Data Exch. Field" = R,
        tabledata "Data Exch. Line Def" = R,
        tabledata "Data Exch. Mapping" = R,
        tabledata "Data Exchange Type" = R,
        codeunit "Data Exchange Query ori" = X,
        codeunit "DataExch Def Get Impl ori" = X,
        codeunit "DataExch Def List Impl ori" = X,
        codeunit "DataExch Entry Get Impl ori" = X,
        codeunit "DataExch Entry List Impl ori" = X,
        codeunit "DataExch Help Get Impl ori" = X,
        codeunit "DataExch Type List Impl ori" = X;
}
