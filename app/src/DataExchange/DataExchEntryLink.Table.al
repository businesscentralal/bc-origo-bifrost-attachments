namespace Origo.Bifrost.Attachments;

using System.IO;

/// <summary>
/// Marks a <c>Data Exch.</c> entry that a Bifröst message type created and records where its file
/// came from. The marker drives the retention policy: Business Central lets only the application
/// that owns a table register it for retention, so <c>Data Exch.</c> cannot be filtered by this app
/// directly. Deleting a marker row (by the retention policy or by <c>DataExchange.Entry.Delete</c>)
/// deletes the entry and its parsed fields with it, unless an incoming document still uses the entry.
/// </summary>
/// <remarks>
/// <c>InherentPermissions</c> lets every caller of the Data Exchange message types write the marker
/// without a permission-set assignment; the generic <c>Data.Records.*</c> types are blocked from the
/// table by <see cref="Codeunit.StorageDataRestriction"/>.
/// </remarks>
table 70013500 "DataExch Entry Link ori"
{
    Caption = 'Bifrost Data Exchange Entry', Comment = 'is-IS=Gagnaskiptafærsla Bifröst';
    DataClassification = SystemMetadata;
    Access = Internal;
    Extensible = false;
    InherentEntitlements = X;
    InherentPermissions = RIMD;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.', Comment = 'is-IS=Færslunúmer';
            ToolTip = 'Specifies the Data Exch. entry that a Bifröst message type created.', Comment = 'is-IS=Tilgreinir gagnaskiptafærsluna sem Bifröst-skeytagerð stofnaði.';
            TableRelation = "Data Exch."."Entry No.";
        }
        field(2; "Upload Id"; Guid)
        {
            Caption = 'Upload Id', Comment = 'is-IS=Upphleðslukenni';
            ToolTip = 'Specifies the chunked upload session the file came from, when it came from one.', Comment = 'is-IS=Tilgreinir upphleðslulotuna sem skráin kom úr, ef hún kom úr lotu.';
        }
        field(3; "Message Type"; Text[50])
        {
            Caption = 'Message Type', Comment = 'is-IS=Skeytagerð';
            ToolTip = 'Specifies the Bifröst message type that created the entry.', Comment = 'is-IS=Tilgreinir Bifröst-skeytagerðina sem stofnaði færsluna.';
        }
        field(4; "Storage Code"; Code[20])
        {
            Caption = 'Storage Code', Comment = 'is-IS=Geymslukóði';
            ToolTip = 'Specifies the storage connection the file was read from or written to.', Comment = 'is-IS=Tilgreinir geymslutenginguna sem skráin var lesin úr eða skrifuð í.';
        }
        field(5; Path; Text[2048])
        {
            Caption = 'Path', Comment = 'is-IS=Slóð';
            ToolTip = 'Specifies the storage path of the file.', Comment = 'is-IS=Tilgreinir geymsluslóð skrárinnar.';
        }
        field(6; Processed; Boolean)
        {
            Caption = 'Processed', Comment = 'is-IS=Unnið';
            ToolTip = 'Specifies whether the mappings of the definition were applied to the entry.', Comment = 'is-IS=Tilgreinir hvort vörpunum skilgreiningarinnar hefur verið beitt á færsluna.';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    trigger OnDelete()
    var
        DataExch: Record "Data Exch.";
    begin
        // An entry that an incoming document uses stays; only this marker goes.
        DataExch.SetLoadFields("Entry No.", "Incoming Entry No.");
        if DataExch.Get("Entry No.") then
            if DataExch."Incoming Entry No." = 0 then
                DataExch.Delete(true);
    end;
}
