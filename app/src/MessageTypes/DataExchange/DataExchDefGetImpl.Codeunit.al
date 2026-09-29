namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;

/// <summary>
/// Implementation of <c>DataExchange.Definition.Get</c>. Returns one definition in full.
/// </summary>
codeunit 70013523 "DataExch Def Get Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        exit(DataExchDef.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns one Data Exchange definition, including line definitions, columns and field mappings.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        DefHelp: Codeunit "DataExch Def Help ori";
    begin
        DefHelp.GetHelp(Enum::"Message Type ori"::"DataExchange.Definition.Get", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Query: Codeunit "Data Exchange Query ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Query.GetDefinition(Argument);
    end;
}
