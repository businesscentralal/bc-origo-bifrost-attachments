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

    /// <summary>Reports the permissions used to expose this message type; execution performs its own validation.</summary>
    /// <returns>True when the caller can read both storage setup and attachment links.</returns>
    procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
        AttachmentLink: Record "Storage Attachment Link ori";
    begin
        exit(StorageSetup.ReadPermission() and AttachmentLink.ReadPermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The Document Attachment table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Document Attachment");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description label in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Restores an offloaded attachment''s file from storage back into the database and deletes the remote copy.', Comment = 'is-IS=Endurheimtir viðhengisskrá úr geymslu í gagnagrunninn og eyðir afritinu í geymslunni.';
    begin
        exit(DescriptionLbl);
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
        SelectionDescriptionLbl: Label 'Brings an offloaded or storage-linked attachment back into the Business Central database and deletes the remote copy in storage.', Comment = 'is-IS=Færir viðhengi sem hefur verið flutt eða tengt við geymslu aftur í Business Central gagnagrunninn og eyðir afritinu í geymslunni.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Supplies the envelope chapter for this message type.</summary>
    /// <param name="Envelope">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    /// <summary>Supplies the target chapter for this message type.</summary>
    /// <param name="Target">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetAttachmentTarget();
        exit(true);
    end;

    /// <summary>Supplies the parameters chapter for this message type.</summary>
    /// <param name="Parameters">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.Attachment.Restore');
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Attachment.Restore');
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Attachment.Restore');
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Attachment.Restore');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no metering chapter.</summary>
    /// <param name="Metering">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the related chapter for this message type.</summary>
    /// <param name="Related">Out: replaced with the chapter built by Storage Contract Parts ori.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Storage.Attachment.Restore');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares that this implementation supplies no examples chapter.</summary>
    /// <param name="Examples">Unchanged; callers must ignore this value when the procedure returns false.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares that this implementation supplies no overview chapter.</summary>
    /// <param name="Overview">Out: cleared to empty.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        exit(false);
    end;

    /// <summary>Declares that this implementation supplies no notes chapter.</summary>
    /// <param name="Notes">Out: cleared to empty.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>Inbound for the requested mutation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Asserts version 1 and licensing, then delegates restoring attachment content from storage.</summary>
    /// <param name="Argument">In: request and message context. Out: success response when the manager succeeds; otherwise the manager supplies the error response. Raised failures propagate to the caller.</param>
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
