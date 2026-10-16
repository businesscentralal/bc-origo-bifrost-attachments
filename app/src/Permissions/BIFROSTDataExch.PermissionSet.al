namespace Origo.Bifrost.Attachments;

using System.IO;

/// <summary>
/// Read access to Data Exchange discovery, plus execute of <c>DataExchange.Type.Set</c>.
/// Table write on <c>Data Exchange Type</c> stays off this set so it remains the #79
/// read-only discovery role; Type.Set still hard-fails without table write at Execute.
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
        tabledata "Data Exch. Field Mapping" = R,
        tabledata "Data Exch. Line Def" = R,
        tabledata "Data Exch. Mapping" = R,
        tabledata "Data Exchange Type" = R,
        codeunit "Data Exchange Query ori" = X,
        codeunit "DataExch Def Get Impl ori" = X,
        codeunit "DataExch Def List Impl ori" = X,
        codeunit "DataExch Entry Get Impl ori" = X,
        codeunit "DataExch Entry List Impl ori" = X,
        codeunit "DataExch Help Get Impl ori" = X,
        codeunit "DataExch Inc Doc Proc ori" = X,
        codeunit "DataExch Type List Impl ori" = X,
        codeunit "DataExch Type Set Impl ori" = X;
}
