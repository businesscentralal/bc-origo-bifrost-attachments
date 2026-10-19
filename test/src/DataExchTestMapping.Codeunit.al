namespace Origo.Bifrost.Attachments.Test;

using System.IO;

/// <summary>
/// Mapping codeunit of the Generic Import test definition. Writes one <c>DataExch Test Target ori</c>
/// row per parsed line with the base app's column mapping, as a customer mapping codeunit would.
/// </summary>
codeunit 96240 "DataExch Test Mapping ori"
{
    TableNo = "Data Exch.";

    trigger OnRun()
    var
        Target: Record "DataExch Test Target ori";
        ProcessDataExch: Codeunit "Process Data Exch.";
        TargetRef: RecordRef;
    begin
        Target."Data Exch. No." := Rec."Entry No.";
        TargetRef.GetTable(Target);
        ProcessDataExch.ProcessAllLinesColumnMapping(Rec, TargetRef);
    end;
}
