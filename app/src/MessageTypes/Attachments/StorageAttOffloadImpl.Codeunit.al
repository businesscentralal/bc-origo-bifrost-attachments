namespace Origo.Bifrost.Attachments;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Attachment.Offload</c> message type. Moves an attachment
/// record's file content to a configured storage connection and clears it from the database;
/// the file stays transparently available to Business Central and can be brought back with
/// <c>Storage.Attachment.Restore</c>.
/// </summary>
codeunit 10035641 "Storage Att. Offload Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
        AttachmentLink: Record "Storage Attachment Link ori";
    begin
        exit(StorageSetup.ReadPermission() and AttachmentLink.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Document Attachment");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Offloads an attachment''s file to a storage connection and clears it from the database, keeping it transparently available.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'offload attachments, move attachments to cloud, free up database space, reduce database size, archive attachments to storage, move pdfs out of the database, database capacity, shrink attachment storage', Comment = 'is-IS=færa viðhengi í skýið, færa viðhengi í geymslu, losa pláss í gagnagrunni, minnka gagnagrunn, minnka gagnagrunninn, geyma viðhengi utan gagnagrunns, færa pdf úr gagnagrunni, gagnagrunnsrými';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Moves an existing attachment file out of the Business Central database into storage while it stays openable; use restore to bring it back.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        AttachmentHelp: Codeunit "Storage Attachment Help ori";
    begin
        AttachmentHelp.GetHelp(Enum::"Message Type ori"::"Storage.Attachment.Offload", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        // Every problem the request or the data can show is answered before the first write.
        // A failure after a write (for example the storage upload) is raised, so the write rolls back.
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if AttachmentMgt.Offload(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
