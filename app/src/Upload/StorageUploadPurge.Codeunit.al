namespace Origo.Bifrost.Attachments;

/// <summary>
/// Removes abandoned chunked-upload data. An upload session that is never committed or
/// aborted leaves its session row and its chunks behind; this codeunit deletes both so an
/// administrator can reclaim the space from the Bifrost Attachments setup page.
/// </summary>
codeunit 10035679 "Storage Upload Purge ori"
{
    Access = Internal;
    Permissions = tabledata "Storage Upload Session ori" = RD,
                  tabledata "Storage Upload Chunk ori" = RD;

    var
        PurgedMsg: Label 'Purged %1 upload session(s) and %2 chunk(s).', Comment = 'is-IS=Hreinsaði %1 upphleðslulotu/-lotur og %2 bita., %1 = session count, %2 = chunk count';

    /// <summary>
    /// Deletes every upload session and chunk and tells the user how much was removed.
    /// </summary>
    procedure PurgeAndNotify()
    var
        SessionCount: Integer;
        ChunkCount: Integer;
    begin
        Purge(SessionCount, ChunkCount);
        Message(PurgedMsg, SessionCount, ChunkCount);
    end;

    /// <summary>
    /// Deletes every upload session and chunk in the current company.
    /// Chunks are removed first so no chunk is ever orphaned by a partial run.
    /// </summary>
    /// <param name="SessionCount">Returns the number of upload sessions that were deleted.</param>
    /// <param name="ChunkCount">Returns the number of upload chunks that were deleted.</param>
    procedure Purge(var SessionCount: Integer; var ChunkCount: Integer)
    var
        UploadSession: Record "Storage Upload Session ori";
        UploadChunk: Record "Storage Upload Chunk ori";
    begin
        ChunkCount := UploadChunk.Count();
        UploadChunk.DeleteAll(true);
        SessionCount := UploadSession.Count();
        UploadSession.DeleteAll(true);
    end;
}
