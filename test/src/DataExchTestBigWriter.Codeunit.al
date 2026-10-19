namespace Origo.Bifrost.Attachments.Test;

using System.IO;

/// <summary>
/// Writing codeunit of a test export definition that produces a file just over 1 MB, so the inline
/// delivery limit can be tested without thousands of source records.
/// </summary>
codeunit 96245 "DataExch Test Big Writer ori"
{
    TableNo = "Data Exch.";

    trigger OnRun()
    var
        FileOutStream: OutStream;
    begin
        Rec."File Content".CreateOutStream(FileOutStream);
        FileOutStream.WriteText(PadStr('', 1100000, 'X'));
        Rec.Modify(true);
    end;
}
