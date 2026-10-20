namespace Origo.Bifrost.Attachments;

using System.IO;

/// <summary>
/// Isolated runner for the mappings of a Data Exch. entry. It is started with
/// <c>if Worker.Run(DataExch)</c> after the import was committed, so a failing mapping rolls back
/// only the processing and the imported entry stays for inspection.
/// </summary>
codeunit 10035143 "DataExch Process Worker ori"
{
    Access = Internal;
    TableNo = "Data Exch.";

    var
        LineDefCode: Code[20];

    trigger OnRun()
    var
        ImportMgt: Codeunit "DataExch Import Mgt ori";
    begin
        ImportMgt.RunMappings(Rec, LineDefCode);
    end;

    /// <summary>Limits the run to the mappings of one line definition; empty runs them all.</summary>
    /// <param name="NewLineDefCode">The line definition code, or empty.</param>
    procedure SetLineDef(NewLineDefCode: Code[20])
    begin
        LineDefCode := NewLineDefCode;
    end;
}
