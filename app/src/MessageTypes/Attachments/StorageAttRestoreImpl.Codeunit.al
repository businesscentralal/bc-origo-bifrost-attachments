namespace Origo.Bifrost.Attachments;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Attachment.Restore</c> message type. Brings an offloaded
/// attachment's file back into the Business Central database from its storage connection and
/// deletes the remote copy, reversing <c>Storage.Attachment.Offload</c>.
/// </summary>
codeunit 10035642 "Storage Att. Restore Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Restores an offloaded attachment''s file from storage back into the database and deletes the remote copy.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'restore attachment, bring attachment back into database, undo offload, move attachment back from cloud, reload attachment from storage, recall offloaded file', Comment = 'is-IS=endurheimta viðhengi, endurheimta viðhengið, sækja viðhengi aftur í gagnagrunn, afturkalla flutning viðhengis, færa viðhengi til baka úr skýinu, endurheimta skrá úr geymslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Brings an offloaded or storage-linked attachment back into the Business Central database and deletes the remote copy in storage.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Envelope := ContractParts.GetEnvelope(true); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Target := ContractParts.GetAttachmentTarget(); exit(true); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Parameters := ContractParts.GetParameters('Storage.Attachment.Restore'); exit(true); end;
    procedure GetResponse(var Response: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Response := ContractParts.GetResponse('Storage.Attachment.Restore'); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Errors := ContractParts.GetErrors('Storage.Attachment.Restore'); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Effect := ContractParts.GetEffect('Storage.Attachment.Restore'); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean
    var ContractParts: Codeunit "Storage Contract Parts ori";
    begin Related := ContractParts.GetRelated('Storage.Attachment.Restore'); exit(true); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean begin exit(false); end;
    procedure GetNotes(var Notes: Text): Boolean begin exit(false); end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        AttachmentHelp: Codeunit "Storage Attachment Help ori";
    begin
        AttachmentHelp.GetHelp(Enum::"Message Type ori"::"Storage.Attachment.Restore", Argument);
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
        if AttachmentMgt.Restore(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
