namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Bank.Payment;
using Microsoft.Finance.GeneralLedger.Journal;
using System.IO;

/// <summary>
/// #251 test double for a bank payment export format: the Processing Codeunit of the test Bank
/// Export/Import Setup. It writes a small file to a Data Exch. entry, marks the batch lines exported
/// and hands the file over through Exp. External Data Gen. Jnl., like a Data Exchange payment export,
/// so DataExchange.PaymentExport.Run captures it. No bank or external call is made.
/// </summary>
codeunit 96249 "DataExch Fake PayExport ori"
{
    Access = Internal;
    TableNo = "Gen. Journal Line";

    trigger OnRun()
    var
        DataExch: Record "Data Exch.";
        DataExchDef: Record "Data Exch. Def";
        GenJournalLine: Record "Gen. Journal Line";
        OutStr: OutStream;
    begin
        if not DataExchDef.Get(DefCodeTok) then begin
            DataExchDef.Init();
            DataExchDef.Code := DefCodeTok;
            DataExchDef.Name := DefCodeTok;
            DataExchDef.Type := DataExchDef.Type::"Payment Export";
            DataExchDef."File Type" := DataExchDef."File Type"::"Variable Text";
            DataExchDef.Insert();
        end;
        DataExch.Init();
        DataExch."Data Exch. Def Code" := DataExchDef.Code;
        DataExch."File Name" := FileNameTok;
        DataExch."File Content".CreateOutStream(OutStr);
        OutStr.WriteText(StrSubstNo(ContentTok, Rec."Journal Template Name", Rec."Journal Batch Name", Format(CreateGuid())));
        DataExch.Insert(true);
        GenJournalLine.SetRange("Journal Template Name", Rec."Journal Template Name");
        GenJournalLine.SetRange("Journal Batch Name", Rec."Journal Batch Name");
        GenJournalLine.ModifyAll("Data Exch. Entry No.", DataExch."Entry No.");
        GenJournalLine.ModifyAll("Exported to Payment File", true);
        Codeunit.Run(Codeunit::"Exp. External Data Gen. Jnl.", DataExch);
    end;

    var
        DefCodeTok: Label 'ZZPAY251', Locked = true;
        FileNameTok: Label 'zzpay251.txt', Locked = true;
        ContentTok: Label 'PAY251;%1;%2;%3', Locked = true;
}
