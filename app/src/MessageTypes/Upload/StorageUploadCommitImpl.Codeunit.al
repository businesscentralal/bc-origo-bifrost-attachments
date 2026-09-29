namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.Commit</c> message type. Assembles an open session's
/// chunks in order and writes the resulting file to the storage connection, then clears the
/// chunks.
/// </summary>
codeunit 10035659 "Storage Upload Commit Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        exit(StorageSetup.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Assembles an upload session''s chunks and writes the file to the storage connection.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'finish upload to storage, complete the upload, save uploaded file to cloud, commit upload, assemble the chunks, finalise upload, finalize upload', Comment = 'is-IS=ljúka upphleðslu, klára upphleðslu, klára upphleðsluna, vista upphlaðna skrá í skýið, setja saman búta, staðfesta upphleðslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Assembles the chunks of an upload session and writes the file to its storage connection; it does not attach the file to any record.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        UploadHelp: Codeunit "Storage Upload Help ori";
    begin
        UploadHelp.GetHelp(Enum::"Message Type ori"::"Storage.Upload.Commit", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        // Every problem the request or the data can show is answered before the first write.
        // A failure after a write (for example the storage upload) is raised, so the write rolls back.
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if UploadMgt.CommitUpload(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
