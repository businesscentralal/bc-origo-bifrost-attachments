namespace Origo.Bifrost.Attachments;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.CommitToRecord</c> message type. Assembles a
/// chunked upload session's data and attaches it directly to a Business Central record
/// without writing to external storage — the content goes straight into the database.
/// </summary>
codeunit 10035669 "Storage Upload Commit Rec ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    var
        DescriptionLbl: Label 'Assembles uploaded chunks and attaches the file directly to a record without external storage.', Comment = 'is-IS=Sameinar upphlaðna hluta og tengir skrána beint við færslu án ytri geymslu.';
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
        KeywordsLbl: Label 'attach large file to record, attach big pdf to vendor, finish upload as attachment, large incoming document, upload big scan to incoming document, attach uploaded file without storage, save upload as document attachment', Comment = 'is-IS=hengja stóra skrá við færslu, hengja stóra pdf við lánardrottin, ljúka upphleðslu sem viðhengi, stórt innkomið skjal, hlaða stórri skönnun í innkomið skjal, hengja upphlaðna skrá við án geymslu, vista upphleðslu sem viðhengi';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Assembles an upload session and attaches the file to a Business Central record or incoming document in the database, with no storage connection.', Comment = 'is-IS=Sameinar upphleðslulotu og tengir skrána við Business Central færslu eða innkomuskjal í gagnagrunninum, án geymslutengingar.';
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
        Parameters := ContractParts.GetParameters('Storage.Upload.CommitToRecord');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Upload.CommitToRecord');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Upload.CommitToRecord');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Upload.CommitToRecord');
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
        Related := ContractParts.GetRelated('Storage.Upload.CommitToRecord');
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
