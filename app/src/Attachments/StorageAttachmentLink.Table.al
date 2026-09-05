namespace Origo.Bifrost.Hnitbjorg;

/// <summary>
/// Tracks attachment records whose file content has been offloaded to external storage.
/// One row per externalized attachment, keyed by the host attachment table id and the
/// attachment record's <c>SystemId</c>. The row records the storage connection and path so
/// the content can be served transparently on read and brought back on restore. While a row
/// exists the attachment's local content (BLOB or media) is empty.
/// </summary>
table 10035635 "Storage Attachment Link ori"
{
    Caption = 'Bifrost Storage Attachment Link', Comment = 'is-IS=Viðhengjatenging Bifröst geymslu';
    DataClassification = CustomerContent;
    Access = Internal;

    fields
    {
        field(1; "Table ID"; Integer)
        {
            Caption = 'Table ID', Comment = 'is-IS=Töflukenni';
            ToolTip = 'Specifies the Business Central attachment table whose record was offloaded.', Comment = 'is-IS=Tilgreinir viðhengjatöfluna í Business Central sem færslan var útvistuð úr.';
        }
        field(2; "Record System Id"; Guid)
        {
            Caption = 'Record System Id', Comment = 'is-IS=Kerfiskenni færslu';
            ToolTip = 'Specifies the SystemId of the attachment record whose content was offloaded.', Comment = 'is-IS=Tilgreinir kerfiskenni viðhengjafærslunnar sem innihald var útvistað fyrir.';
        }
        field(3; "Storage Code"; Code[20])
        {
            Caption = 'Storage Code', Comment = 'is-IS=Geymslukóði';
            ToolTip = 'Specifies the storage connection that holds the offloaded content.', Comment = 'is-IS=Tilgreinir geymslutenginguna sem geymir útvistaða innihaldið.';
        }
        field(4; "Storage Path"; Text[2048])
        {
            Caption = 'Storage Path', Comment = 'is-IS=Geymsluslóð';
            ToolTip = 'Specifies the path of the offloaded file within the storage connection.', Comment = 'is-IS=Tilgreinir slóð útvistuðu skráarinnar innan geymslutengingarinnar.';
        }
        field(5; "File Name"; Text[250])
        {
            Caption = 'File Name', Comment = 'is-IS=Skráarheiti';
            ToolTip = 'Specifies the file name of the offloaded content.', Comment = 'is-IS=Tilgreinir skráarheiti útvistaða innihaldsins.';
        }
        field(6; "Content Size"; Integer)
        {
            Caption = 'Content Size', Comment = 'is-IS=Stærð innihalds';
            ToolTip = 'Specifies the size in bytes of the offloaded content.', Comment = 'is-IS=Tilgreinir stærð útvistaða innihaldsins í bætum.';
        }
        field(7; "Inc. Doc. Entry No."; Integer)
        {
            Caption = 'Incoming Document Entry No.', Comment = 'is-IS=Færslunúmer innkomandi skjals';
            ToolTip = 'Specifies the incoming document entry number, when the target is an incoming document attachment.', Comment = 'is-IS=Tilgreinir færslunúmer innkomandi skjals þegar markmiðið er viðhengi innkomandi skjals.';
        }
        field(8; "Inc. Doc. Line No."; Integer)
        {
            Caption = 'Incoming Document Line No.', Comment = 'is-IS=Línunúmer innkomandi skjals';
            ToolTip = 'Specifies the incoming document attachment line number, when the target is an incoming document attachment.', Comment = 'is-IS=Tilgreinir línunúmer viðhengis innkomandi skjals þegar markmiðið er viðhengi innkomandi skjals.';
        }
        field(9; "Offloaded At"; DateTime)
        {
            Caption = 'Offloaded At', Comment = 'is-IS=Útvistað þann';
            ToolTip = 'Specifies when the content was offloaded to storage.', Comment = 'is-IS=Tilgreinir hvenær innihaldið var útvistað í geymslu.';
        }
        field(10; "Offloaded By"; Guid)
        {
            Caption = 'Offloaded By', Comment = 'is-IS=Útvistað af';
            ToolTip = 'Specifies the user that offloaded the content.', Comment = 'is-IS=Tilgreinir notandann sem útvistaði innihaldinu.';
        }
    }

    keys
    {
        key(PK; "Table ID", "Record System Id")
        {
            Clustered = true;
        }
        key(ByEntry; "Table ID", "Inc. Doc. Entry No.")
        {
        }
        key(ByStoragePath; "Storage Code", "Storage Path")
        {
        }
    }
}
