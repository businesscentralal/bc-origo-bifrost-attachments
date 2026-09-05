namespace Origo.Bifrost.Hnitbjorg;

/// <summary>
/// Lifecycle state of a chunked upload session (see <see cref="Table.StorageUploadSession"/>).
/// A session is <c>Open</c> while chunks are being appended, becomes <c>Committed</c> once its
/// assembled content has been written to storage, and is <c>Aborted</c> when the caller
/// discards it before committing.
/// </summary>
enum 10035637 "Storage Upload Status ori"
{
    Extensible = false;
    Caption = 'Bifrost Storage Upload Status', Comment = 'is-IS=Staða upphleðslu Bifröst geymslu';

    /// <summary>The session accepts further chunks and has not been committed.</summary>
    value(0; Open)
    {
        Caption = 'Open', Comment = 'is-IS=Opið';
    }
    /// <summary>The session's chunks have been assembled and written to storage.</summary>
    value(1; Committed)
    {
        Caption = 'Committed', Comment = 'is-IS=Staðfest';
    }
    /// <summary>The session was discarded before it was committed.</summary>
    value(2; Aborted)
    {
        Caption = 'Aborted', Comment = 'is-IS=Hætt við';
    }
}
