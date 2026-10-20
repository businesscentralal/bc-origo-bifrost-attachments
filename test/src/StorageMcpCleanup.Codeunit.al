namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Attachments;

/// <summary>Deletes only explicitly registered issue166 fixture identities. Run only in the worker-owned verification container.</summary>
codeunit 96263 "Storage MCP Cleanup ori"
{
    trigger OnRun()
    var
        Item: Record "Storage MCP Cleanup Item ori";
        Target: RecordRef;
        InvalidFixtureErr: Label 'The cleanup registry contains an unsupported fixture.', Locked = true;
    begin
        if Item.FindSet(true) then
            repeat
                if CopyStr(Item."Run Id", 1, 5) <> 'W9166' then
                    Error(InvalidFixtureErr);
                if not (Item."Table Id" in [Database::Customer, Database::"Document Attachment", Database::"Incoming Document",
                    Database::"Incoming Document Attachment", Database::"Storage Setup ori", Database::"Storage Upload Session ori", Database::"Storage MCP File ori"]) then
                    Error(InvalidFixtureErr);
                Target.Open(Item."Table Id");
                if Target.GetBySystemId(Item."Record System Id") then
                    Target.Delete(true);
                Target.Close();
                Item.Delete();
            until Item.Next() = 0;
    end;
}
