namespace Origo.Bifrost.Attachments;

using Microsoft.Bank.BankAccount;
using Microsoft.Bank.DirectDebit;
using Microsoft.Bank.Payment;
using Microsoft.Finance.GeneralLedger.Journal;
using System.IO;
using System.Utilities;

/// <summary>
/// Captures the payment file that the base application's payment export would download to a browser,
/// so <c>DataExchange.PaymentExport.Run</c> can deliver it to storage. It is bound manually only for
/// the duration of one export. The SEPA credit transfer export and the Data Exchange payment export
/// (Exp. External Data Gen. Jnl.) both report the file as created, so the journal lines get the
/// standard exported marks and the credit transfer register keeps the file.
/// </summary>
codeunit 10035142 "DataExch Pay Capture ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        CapturedBlob: Codeunit "Temp Blob";
        CapturedFileName: Text;
        HasCapture: Boolean;
        ReExportApproved: Boolean;

    /// <summary>Records that the caller sent reExport true, so the export runs without the base-app question to export again.</summary>
    /// <param name="NewReExport">True when the caller asked to export already exported lines again.</param>
    procedure SetReExport(NewReExport: Boolean)
    begin
        ReExportApproved := NewReExport;
    end;

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

    /// <summary>
    /// With reExport true, runs the steps of the base-app ExportPaymentFile without its question to export
    /// again: the checks on Check Printed, the document numbers and the balancing bank account, then the
    /// payment export codeunit of the bank account (or Exp. Launcher Gen. Jnl.). The base-app events
    /// OnExportPaymentFileOnBeforeRunExport and OnExportPaymentFileOnAfterRunExport are local and are not raised on this path.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Gen. Journal Line", 'OnBeforeExportPaymentFile', '', false, false)]
    local procedure ExportAgainWithoutQuestion(var GenJournalLine: Record "Gen. Journal Line"; var IsHandled: Boolean)
    var
        BankAccount: Record "Bank Account";
    begin
        if IsHandled or not ReExportApproved then
            exit;
        if not GenJournalLine.FindSet() then
            exit;
        GenJournalLine.SetRange("Journal Template Name", GenJournalLine."Journal Template Name");
        GenJournalLine.SetRange("Journal Batch Name", GenJournalLine."Journal Batch Name");
        GenJournalLine.TestField("Check Printed", false);
        GenJournalLine.CheckDocNoOnLines();
        GenJournalLine.TestField("Bal. Account Type", GenJournalLine."Bal. Account Type"::"Bank Account");
        BankAccount.Get(GenJournalLine."Bal. Account No.");
        if BankAccount.GetPaymentExportCodeunitID() > 0 then
            Codeunit.Run(BankAccount.GetPaymentExportCodeunitID(), GenJournalLine)
        else
            Codeunit.Run(Codeunit::"Exp. Launcher Gen. Jnl.", GenJournalLine);
        IsHandled := true;
    end;
}
