namespace Origo.Bifrost.Attachments.Test;

/// <summary>Isolated persisted files for cross-session MCP regression fixtures; not a production storage provider.</summary>
table 96261 "Storage MCP File ori"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Storage Code"; Code[20]) { }
        field(2; Path; Text[250]) { }
        field(3; Content; Blob) { }
    }
    keys
    {
        key(PK; "Storage Code", Path) { Clustered = true; }
    }
}
