namespace Origo.Bifrost.Attachments;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.CommitToRecord</c> message type. Assembles a
/// chunked upload session's data and attaches it directly to a Business Central record
/// without writing to external storage — the content goes straight into the database.
/// </summary>
codeunit 10035669 "Storage Upload Commit Rec ori" implements "Msg Interface ori", "Msg Discovery ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DocumentAttachment: Record "Document Attachment";
    begin
        exit(DocumentAttachment.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Document Attachment");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Assembles uploaded chunks and attaches the file directly to a record without external storage.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'attach large file to record, attach big pdf to vendor, finish upload as attachment, large incoming document, upload big scan to incoming document, attach uploaded file without storage, save upload as document attachment', Comment = 'is-IS=hengja stóra skrá við færslu, hengja stóra pdf við lánardrottin, ljúka upphleðslu sem viðhengi, stórt innkomið skjal, hlaða stórri skönnun í innkomið skjal, hengja upphlaðna skrá við án geymslu, vista upphleðslu sem viðhengi';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Assembles an upload session and attaches the file to a Business Central record or incoming document in the database, with no storage connection.', Locked = true;
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
        UploadHelp.GetHelp(Enum::"Message Type ori"::"Storage.Upload.CommitToRecord", Argument);
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
        if UploadMgt.CommitToRecord(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
