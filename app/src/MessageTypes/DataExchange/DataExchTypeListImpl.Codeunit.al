namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Type.List</c>. Lists Data Exchange Type rows.
/// </summary>
codeunit 70013524 "DataExch Type List Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DataExchType: Record "Data Exchange Type";
    begin
        exit(DataExchType.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Lists Data Exchange Types and the definition type each one resolves to.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        TypeHelp: Codeunit "DataExch Type Help ori";
    begin
        TypeHelp.GetHelp(Enum::"Message Type ori"::"DataExchange.Type.List", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Query: Codeunit "Data Exchange Query ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Query.ListTypes(Argument);
    end;
}
