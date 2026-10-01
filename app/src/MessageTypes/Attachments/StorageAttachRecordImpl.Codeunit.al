namespace Origo.Bifrost.Attachments;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Attachment.CreateForRecord</c> message type. Creates a
/// <c>Document Attachment</c> on any Business Central record — a customer, a vendor, a fixed
/// asset, a posted document — from inline base64, from a file already in storage, or by copying
/// an attachment that already exists elsewhere in Business Central.
/// </summary>
codeunit 10035667 "Storage Attach Record Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Creates a document attachment on any record - customer, vendor, fixed asset, document - from base64, from storage, or by copying an existing attachment.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'attach a file, attach the invoice pdf to the vendor, add attachment to customer, attach document to sales order, document attachment, attach contract to fixed asset, copy attachment to another record', Comment = 'is-IS=hengja skrá við, hengja við skjal, hengja reikning við lánardrottin, bæta viðhengi við viðskiptamann, hengja skjal við sölupöntun, viðhengi skjals, viðhengi færslu, afrita viðhengi á aðra færslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Attaches a file of up to 240 MiB to any Business Central record as a document attachment, from base64, from storage or from another attachment.', Locked = true;
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.Attachment.CreateForRecord');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Attachment.CreateForRecord');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Attachment.CreateForRecord');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Attachment.CreateForRecord');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Storage.Attachment.CreateForRecord');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
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
        if AttachmentMgt.CreateForRecord(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
