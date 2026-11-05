namespace Origo.Bifrost.Attachments;

using System.ExternalFileStorage;

/// <summary>Company-local Mock storage content, isolated by connection and logical path.</summary>
table 10035141 "Storage Mock Entry ori"
{
    Access = Internal;
    DataClassification = CustomerContent;
    Caption = 'Mock Storage Entry', Comment = 'is-IS=Færsla prófunargeymslu';
    fields
    {
        field(1; "Storage Code"; Code[20])
        {
            Caption = 'Storage Code', Comment = 'is-IS=Geymslukóði';
            TableRelation = "Storage Setup ori";
        }
        field(2; Path; Text[250])
        {
            Caption = 'Path', Comment = 'is-IS=Slóð';
        }
        field(3; "Entry Type"; Enum "Ext. File Storage File Type")
        {
            Caption = 'Entry Type', Comment = 'is-IS=Færslugerð';
        }
        field(4; Content; Blob)
        {
            Caption = 'Content', Comment = 'is-IS=Innihald';
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
