namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Extends <c>Message Type ori</c> with the Data Exchange pipeline types of phases 1, 3b and 4:
/// commit an upload into a Data Exch. entry, process or delete an entry, install a definition from
/// XML and export a payment journal batch. Captions are <c>Locked = true</c> because the keys are
/// the public wire contract.
/// </summary>
enumextension 10035140 "DataExch Pipeline MsgType ori" extends "Message Type ori"
{
    /// <summary>Commits a chunked upload into a parsed Data Exch. entry.</summary>
    value(10035165; "Storage.Upload.CommitToDataExchange")
    {
        Caption = 'Storage.Upload.CommitToDataExchange', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Upload Commit DX ori", "Msg Discovery ori" = "Storage Upload Commit DX ori", "Msg Contract ori" = "Storage Upload Commit DX ori";
    }
    /// <summary>Applies the definition mappings to a parsed entry.</summary>
    value(10035166; "DataExchange.Entry.Process")
    {
        Caption = 'DataExchange.Entry.Process', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Entry Proc Impl ori", "Msg Discovery ori" = "DataExch Entry Proc Impl ori", "Msg Contract ori" = "DataExch Entry Proc Impl ori";
    }
    /// <summary>Deletes an entry and its parsed fields.</summary>
    value(10035168; "DataExchange.Entry.Delete")
    {
        Caption = 'DataExchange.Entry.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Entry Delete Impl ori", "Msg Discovery ori" = "DataExch Entry Delete Impl ori", "Msg Contract ori" = "DataExch Entry Delete Impl ori";
    }
    /// <summary>Installs Data Exchange definitions from the standard definition XML.</summary>
    value(10035172; "DataExchange.Definition.Import")
    {
        Caption = 'DataExchange.Definition.Import', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Def Install Impl ori", "Msg Discovery ori" = "DataExch Def Install Impl ori", "Msg Contract ori" = "DataExch Def Install Impl ori";
    }
    /// <summary>Exports a payment journal batch to a bank payment file in storage.</summary>
    value(10035173; "DataExchange.PaymentExport.Run")
    {
        Caption = 'DataExchange.PaymentExport.Run', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Pay Export Impl ori", "Msg Discovery ori" = "DataExch Pay Export Impl ori", "Msg Contract ori" = "DataExch Pay Export Impl ori";
    }
}
