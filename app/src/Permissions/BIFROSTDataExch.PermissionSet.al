namespace Origo.Bifrost.Attachments;

using System.IO;

/// <summary>
/// Read access to Data Exchange discovery. Import, process and export grants stay out
/// until those message types exist. Holders do not need <c>BIFROST Attach ori</c>.
/// <c>Storage Full ori</c> adds the same read grants to <c>BIFROST Full ori</c>.
/// </summary>
permissionset 70013548 "BIFROST DataExch ori"
{
    Access = Public;
    Assignable = true;
    Caption = 'Bifrost Data Exchange', Comment = 'is-IS=Bifröst gagnaskipti';

    Permissions =
        tabledata "Data Exch." = R,
        tabledata "Data Exch. Column Def" = R,
        tabledata "Data Exch. Def" = R,
        tabledata "Data Exch. Field" = R,
        tabledata "Data Exch. Field Mapping" = R,
        tabledata "Data Exch. Line Def" = R,
        tabledata "Data Exch. Mapping" = R,
        tabledata "Data Exchange Type" = R,
        codeunit "Data Exchange Query ori" = X,
        codeunit "DataExch Def Get Impl ori" = X,
        codeunit "DataExch Def Help ori" = X,
        codeunit "DataExch Def List Impl ori" = X,
        codeunit "DataExch Entry Get Impl ori" = X,
        codeunit "DataExch Entry Help ori" = X,
        codeunit "DataExch Entry List Impl ori" = X,
        codeunit "DataExch Help Get Impl ori" = X,
        codeunit "DataExch Overview Help ori" = X,
        codeunit "DataExch Type Help ori" = X,
        codeunit "DataExch Type List Impl ori" = X;
}
