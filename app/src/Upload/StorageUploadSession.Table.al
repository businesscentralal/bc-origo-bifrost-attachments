namespace Origo.Bifrost.Hnitbjorg;

/// <summary>
/// Header for a chunked upload. A session lets a caller deliver a large file as a sequence of
/// small base64 chunks (see <see cref="Table.StorageUploadChunk"/>) that are assembled and
/// written to storage on commit, working around the per-request size limit of a single Cloud
/// Event. One row per in-progress or recently committed upload, keyed by a generated
/// <c>Upload Id</c>.
/// </summary>
/// <remarks>
/// The table is openly usable: <c>InherentPermissions</c> grants every user the rights needed
/// to run the upload flow without a permission-set assignment. Per-user isolation is enforced
/// in <see cref="Codeunit.StorageUploadMgt"/> with a <c>FilterGroup(2)</c> filter on
/// <c>SystemCreatedBy</c>, and the generic <c>Data.Records.*</c> message types are blocked from
/// the table by <see cref="Codeunit.StorageDataRestriction"/>. Abandoned sessions are pruned
/// by a retention policy registered in <see cref="Codeunit.StorageRetenPolicy"/>.
/// </remarks>
table 10035638 "Storage Upload Session ori"
{
    Caption = 'Bifrost Storage Upload Session', Comment = 'is-IS=Upphleðslulota Bifröst geymslu';
    DataClassification = CustomerContent;
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = RIMD;

    fields
    {
        field(1; "Upload Id"; Guid)
        {
            Caption = 'Upload Id', Comment = 'is-IS=Upphleðslukenni';
            ToolTip = 'Specifies the identifier returned when the upload session is created; it is passed back on every append, commit, abort and status call.', Comment = 'is-IS=Tilgreinir kennið sem skilað er þegar upphleðslulotan er stofnuð; það er sent með í hverri viðbótar-, staðfestingar-, hættu- og stöðubeiðni.';
        }
        field(2; "Storage Code"; Code[20])
        {
            Caption = 'Storage Code', Comment = 'is-IS=Geymslukóði';
            ToolTip = 'Specifies the storage connection the assembled file is written to on commit.', Comment = 'is-IS=Tilgreinir geymslutenginguna sem samsetta skráin er skrifuð í við staðfestingu.';
        }
        field(3; "File Name"; Text[250])
        {
            Caption = 'File Name', Comment = 'is-IS=Skráarheiti';
            ToolTip = 'Specifies the file name of the upload.', Comment = 'is-IS=Tilgreinir skráarheiti upphleðslunnar.';
        }
        field(4; "Target Path"; Text[2048])
        {
            Caption = 'Target Path', Comment = 'is-IS=Markslóð';
            ToolTip = 'Specifies the full destination path the assembled file is written to within the storage connection.', Comment = 'is-IS=Tilgreinir fulla áfangaslóð sem samsetta skráin er skrifuð á innan geymslutengingarinnar.';
        }
        field(5; "Declared Size"; Integer)
        {
            Caption = 'Declared Size', Comment = 'is-IS=Tilgreind stærð';
            ToolTip = 'Specifies the expected total byte count of the upload, when supplied; it is verified against the received size on commit.', Comment = 'is-IS=Tilgreinir væntanlega heildarstærð upphleðslunnar í bætum, þegar hún er gefin upp; hún er borin saman við móttekna stærð við staðfestingu.';
        }
        field(6; "Received Size"; Integer)
        {
            Caption = 'Received Size', Comment = 'is-IS=Móttekin stærð';
            ToolTip = 'Specifies the total number of bytes received across all appended chunks.', Comment = 'is-IS=Tilgreinir heildarfjölda móttekinna bæta yfir alla viðbætta bita.';
        }
        field(7; "Chunk Count"; Integer)
        {
            Caption = 'Chunk Count', Comment = 'is-IS=Fjöldi bita';
            ToolTip = 'Specifies how many chunks have been appended to the session.', Comment = 'is-IS=Tilgreinir hversu margir bitar hafa verið viðbættir lotunni.';
        }
        field(8; Status; Enum "Storage Upload Status ori")
        {
            Caption = 'Status', Comment = 'is-IS=Staða';
            ToolTip = 'Specifies whether the session is open for further chunks, has been committed to storage, or was aborted.', Comment = 'is-IS=Tilgreinir hvort lotan er opin fyrir frekari bita, hefur verið staðfest í geymslu, eða var hætt við.';
        }
    }

    keys
    {
        key(PK; "Upload Id")
        {
            Clustered = true;
        }
    }

    trigger OnDelete()
    var
        Chunk: Record "Storage Upload Chunk ori";
    begin
        Chunk.SetRange("Upload Id", "Upload Id");
        Chunk.DeleteAll(true);
    end;
}
