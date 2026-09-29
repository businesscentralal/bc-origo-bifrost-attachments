namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Entry.Get</c>. Returns one Data Exch. entry.
/// </summary>
codeunit 70013526 "DataExch Entry Get Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns one Data Exch. entry, with paged fields and optional file content up to 1 MB.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        EntryHelp: Codeunit "DataExch Entry Help ori";
    begin
        EntryHelp.GetHelp(Enum::"Message Type ori"::"DataExchange.Entry.Get", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Query: Codeunit "Data Exchange Query ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Query.GetEntry(Argument);
    end;
}
