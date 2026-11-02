namespace Origo.Bifrost.Attachments.Test;

/// <summary>Owned test-only file content that persists between MCP sessions; never stores external credentials.</summary>
table 96250 "Storage 23 Fixture File ori"
{
    DataClassification = CustomerContent;
    Caption = 'Storage 23 Fixture File';

    fields
    {
        field(1; "Storage Code"; Code[20])
        {
            Caption = 'Storage Code';
        }
        field(2; Path; Text[250])
        {
            Caption = 'Path';
        }
        field(3; Content; Blob)
        {
            Caption = 'Content';
        }
    }
    keys
    {
        key(PK; "Storage Code", Path)
        {
            Clustered = true;
        }
    }
}
