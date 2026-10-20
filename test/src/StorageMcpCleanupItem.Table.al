namespace Origo.Bifrost.Attachments.Test;

/// <summary>Explicit record identities registered by an isolated MCP run for owned fixture cleanup.</summary>
table 96262 "Storage MCP Cleanup Item ori"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Run Id"; Code[20]) { }
        field(2; "Table Id"; Integer) { }
        field(3; "Record System Id"; Guid) { }
    }
    keys
    {
        key(PK; "Run Id", "Table Id", "Record System Id") { Clustered = true; }
    }
}
