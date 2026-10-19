namespace Origo.Bifrost.Attachments;

using Microsoft.Bank.DirectDebit;
using Microsoft.Bank.Payment;
using System.IO;
using System.Utilities;

/// <summary>
/// Captures the payment file that the base application's payment export would download to a browser,
/// so <c>DataExchange.PaymentExport.Run</c> can deliver it to storage. It is bound manually only for
/// the duration of one export. The SEPA credit transfer export and the Data Exchange payment export
/// (Exp. External Data Gen. Jnl.) both report the file as created, so the journal lines get the
/// standard exported marks and the credit transfer register keeps the file.
/// </summary>
codeunit 70013504 "DataExch Pay Capture ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        CapturedBlob: Codeunit "Temp Blob";
        CapturedFileName: Text;
        HasCapture: Boolean;

    /// <summary>Returns the captured payment file.</summary>
    /// <param name="TempBlob">Returns the file content.</param>
    /// <param name="FileName">Returns the file name the export chose.</param>
    /// <returns>True when a file was captured.</returns>
    procedure GetFile(var TempBlob: Codeunit "Temp Blob"; var FileName: Text): Boolean
    begin
        if not HasCapture then
            exit(false);
        TempBlob := CapturedBlob;
        FileName := CapturedFileName;
        exit(true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"SEPA CT-Export File", 'OnBeforeBLOBExport', '', false, false)]
    local procedure CaptureSepaFile(var TempBlob: Codeunit "Temp Blob"; CreditTransferRegister: Record "Credit Transfer Register"; UseComonDialog: Boolean; var FieldCreated: Boolean; var IsHandled: Boolean)
    begin
        CapturedBlob := TempBlob;
        CapturedFileName := CreditTransferRegister.Identifier + '.xml';
        HasCapture := true;
        FieldCreated := true;
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Exp. External Data Gen. Jnl.", 'OnBeforeExportToFile', '', false, false)]
    local procedure CaptureDataExchFile(DataExch: Record "Data Exch."; var FileName: Text; var Handled: Boolean)
    begin
        DataExch.CalcFields("File Content");
        Clear(CapturedBlob);
        CapturedBlob.FromRecord(DataExch, DataExch.FieldNo("File Content"));
        CapturedFileName := FileName;
        HasCapture := true;
        Handled := true;
    end;
}
