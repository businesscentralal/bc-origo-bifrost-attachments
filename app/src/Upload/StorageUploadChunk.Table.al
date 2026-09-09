namespace Origo.Bifrost.Attachments;

using System.Utilities;

/// <summary>
/// One appended chunk of a chunked upload (see <see cref="Table.StorageUploadSession"/>).
/// Each row holds the decoded bytes of a single chunk and its position in the sequence; on
/// commit the chunks are read back in <c>Sequence No.</c> order and concatenated into the file
/// written to storage. Rows are removed when their session is committed, aborted, or pruned.
/// </summary>
/// <remarks>
/// Like the session header, the table carries <c>InherentPermissions</c> so any user can upload,
/// and is blocked from the generic <c>Data.Records.*</c> message types by
/// <see cref="Codeunit.StorageDataRestriction"/>. Chunks are only ever reached after the owning
/// session has been resolved under the per-user <c>FilterGroup(2)</c> filter, so they inherit the
/// same isolation.
/// </remarks>
table 10035637 "Storage Upload Chunk ori"
{
    Caption = 'Bifrost Storage Upload Chunk', Comment = 'is-IS=Upphleðslubiti Bifröst geymslu';
    DataClassification = CustomerContent;
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = RIMD;

    fields
    {
        field(1; "Upload Id"; Guid)
        {
            Caption = 'Upload Id', Comment = 'is-IS=Upphleðslukenni';
            ToolTip = 'Specifies the upload session this chunk belongs to.', Comment = 'is-IS=Tilgreinir upphleðslulotuna sem þessi biti tilheyrir.';
        }
        field(2; "Sequence No."; Integer)
        {
            Caption = 'Sequence No.', Comment = 'is-IS=Raðnúmer';
            ToolTip = 'Specifies the position of this chunk in the assembled file; chunks are concatenated in ascending sequence order.', Comment = 'is-IS=Tilgreinir staðsetningu þessa bita í samsettu skránni; bitar eru tengdir saman í hækkandi raðnúmeri.';
        }
        field(3; Content; Blob)
        {
            Caption = 'Content', Comment = 'is-IS=Innihald';
            ToolTip = 'Specifies the decoded bytes of this chunk.', Comment = 'is-IS=Tilgreinir afkóðuð bæti þessa bita.';
        }
        field(4; Size; Integer)
        {
            Caption = 'Size', Comment = 'is-IS=Stærð';
            ToolTip = 'Specifies the number of bytes held by this chunk.', Comment = 'is-IS=Tilgreinir fjölda bæta sem þessi biti geymir.';
        }
    }

    keys
    {
        key(PK; "Upload Id", "Sequence No.")
        {
            Clustered = true;
        }
    }

    /// <summary>Writes the supplied content into this chunk's <c>Content</c> blob.</summary>
    /// <param name="TempBlob">The chunk bytes to store.</param>
    procedure SetContentFromBlob(var TempBlob: Codeunit "Temp Blob")
    var
        SourceInStream: InStream;
        ContentOutStream: OutStream;
    begin
        TempBlob.CreateInStream(SourceInStream);
        Content.CreateOutStream(ContentOutStream);
        CopyStream(ContentOutStream, SourceInStream);
    end;

    /// <summary>Appends this chunk's content to a destination stream, for assembling the file.</summary>
    /// <param name="DestinationOutStream">The stream the chunk content is copied onto.</param>
    procedure AppendContentTo(DestinationOutStream: OutStream)
    var
        ContentInStream: InStream;
    begin
        CalcFields(Content);
        if not Content.HasValue() then
            exit;
        Content.CreateInStream(ContentInStream);
        CopyStream(DestinationOutStream, ContentInStream);
    end;
}
