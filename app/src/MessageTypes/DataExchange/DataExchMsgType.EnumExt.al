namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Extends <c>Message Type ori</c> with the Data Exchange Phase 0 discovery types.
/// The values live on this enum extension (block 2) rather than on
/// <c>Storage Msg Type ori</c>. Captions are <c>Locked = true</c> because the keys
/// are the public wire contract.
/// </summary>
enumextension 70013510 "DataExch Msg Type ori" extends "Message Type ori"
{
    /// <summary>Returns a Markdown overview of Data Exchange discovery and how the types chain.</summary>
    value(70013510; "Help.DataExchange.Get")
    {
        Caption = 'Help.DataExchange.Get', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Help Get Impl ori", "Msg Discovery ori" = "DataExch Help Get Impl ori", "Msg Contract ori" = "DataExch Help Get Impl ori";
    }
    /// <summary>Lists Data Exchange definitions.</summary>
    value(70013511; "DataExchange.Definition.List")
    {
        Caption = 'DataExchange.Definition.List', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Def List Impl ori", "Msg Discovery ori" = "DataExch Def List Impl ori", "Msg Contract ori" = "DataExch Def List Impl ori";
    }
    /// <summary>Returns one Data Exchange definition, including line defs, columns and field mappings.</summary>
    value(70013512; "DataExchange.Definition.Get")
    {
        Caption = 'DataExchange.Definition.Get', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Def Get Impl ori", "Msg Discovery ori" = "DataExch Def Get Impl ori", "Msg Contract ori" = "DataExch Def Get Impl ori";
    }
    /// <summary>Lists Data Exchange Types and the definition each one points at.</summary>
    value(70013513; "DataExchange.Type.List")
    {
        Caption = 'DataExchange.Type.List', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Type List Impl ori", "Msg Discovery ori" = "DataExch Type List Impl ori", "Msg Contract ori" = "DataExch Type List Impl ori";
    }
    /// <summary>Lists processed Data Exch. entries.</summary>
    value(70013514; "DataExchange.Entry.List")
    {
        Caption = 'DataExchange.Entry.List', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Entry List Impl ori", "Msg Discovery ori" = "DataExch Entry List Impl ori", "Msg Contract ori" = "DataExch Entry List Impl ori";
    }
    /// <summary>Returns one Data Exch. entry, optionally with paged fields and file content.</summary>
    value(70013515; "DataExchange.Entry.Get")
    {
        Caption = 'DataExchange.Entry.Get', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Entry Get Impl ori", "Msg Discovery ori" = "DataExch Entry Get Impl ori", "Msg Contract ori" = "DataExch Entry Get Impl ori";
    }
}
