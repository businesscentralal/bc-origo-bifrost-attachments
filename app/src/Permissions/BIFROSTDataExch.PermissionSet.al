namespace Origo.Bifrost.Attachments;

using System.IO;

/// <summary>
/// Read access to Data Exchange discovery, plus execute of the Data Exchange write types
/// (<c>DataExchange.Type.Set</c>, import, process, export, definition install and delete).
/// Table write on <c>Data Exchange Type</c> stays off this set so it remains the #79
/// read-only discovery role; the write types still hard-fail without table write at Execute.
/// The definition XML also reads field groupings and transformation rules. Execute on the base-app
/// reader and writer XMLports lets a holder import CSV files, export generic files and install or dump
/// definitions; the tables those XMLports write still need the standard permissions.
/// Holders do not need <c>BIFROST Attach ori</c>. A permission set extension cannot
/// grant or include these tables.
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
        tabledata "Data Exch. Field Grouping" = R,
        tabledata "Data Exch. Field Mapping" = R,
        tabledata "Data Exch. Line Def" = R,
        tabledata "Data Exch. Mapping" = R,
        tabledata "Data Exchange Type" = R,
        tabledata "DataExch Entry Link ori" = R,
        tabledata "Transformation Rule" = R,
        codeunit "Data Exchange Query ori" = X,
        codeunit "DataExch Def Delete Impl ori" = X,
        codeunit "DataExch Def Export Impl ori" = X,
        codeunit "DataExch Def Install Impl ori" = X,
        codeunit "DataExch Def Transfer ori" = X,
        codeunit "DataExch Def Get Impl ori" = X,
        codeunit "DataExch Def List Impl ori" = X,
        codeunit "DataExch Entry Delete Impl ori" = X,
        codeunit "DataExch Entry Get Impl ori" = X,
        codeunit "DataExch Entry List Impl ori" = X,
        codeunit "DataExch Entry Proc Impl ori" = X,
        codeunit "DataExch Export Mgt ori" = X,
        codeunit "DataExch Export Run Impl ori" = X,
        codeunit "DataExch Help Get Impl ori" = X,
        codeunit "DataExch Import Mgt ori" = X,
        codeunit "DataExch Import Run Impl ori" = X,
        codeunit "DataExch Inc Doc Proc ori" = X,
        codeunit "DataExch Pay Capture ori" = X,
        codeunit "DataExch Pay Export Impl ori" = X,
        codeunit "DataExch Process Worker ori" = X,
        codeunit "DataExch Type List Impl ori" = X,
        codeunit "DataExch Type Set Impl ori" = X,
        codeunit "DataExch View Filter ori" = X,
        codeunit "Storage Upload Commit DX ori" = X,
        xmlport "Data Exch. Import - CSV" = X,
        xmlport "Export Generic CSV" = X,
        xmlport "Export Generic Fixed Width" = X,
        xmlport "Imp / Exp Data Exch Def & Map" = X;
}
