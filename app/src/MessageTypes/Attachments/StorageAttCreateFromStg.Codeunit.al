namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Attachment.CreateFromStaging</c> message type. Creates a document or incoming
/// document attachment from one Foundation staging row, offloads it to storage and consumes the row (Take).
/// </summary>
codeunit 10035204 "Storage Att. CreateFromStg ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    var
        DescriptionLbl: Label 'Creates an offloaded attachment on a record or incoming document from a Foundation staging row and consumes the row.', Comment = 'is-IS=Býr til útvistað viðhengi á færslu eða innsendu skjali úr bráðabirgðafærslu í Bifröst-grunni og eyðir færslunni.';
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
        KeywordsLbl: Label 'attach staged file to record, staging id to attachment, attach staged pdf to invoice, staged file to incoming document, offloaded attachment from staging, store staged attachment in cloud', Comment = 'is-IS=hengja bráðabirgðaskrá við færslu, stagingId í viðhengi, hengja bráðabirgða-pdf við reikning, bráðabirgðaskrá í innsent skjal, útvistað viðhengi úr bráðabirgðageymslu, geyma bráðabirgðaviðhengi í skýinu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Turns one Foundation staging row, by stagingId, into an attachment stored in external storage and consumes the row; Storage.Upload.CommitToRecord keeps the content in Business Central.', Comment = 'is-IS=Breytir einni bráðabirgðafærslu úr Bifröst-grunni, eftir stagingId, í viðhengi sem er geymt í ytri geymslu og eyðir færslunni; Storage.Upload.CommitToRecord geymir efnið í Business Central.';
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
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetTarget('Storage.Attachment.CreateFromStaging', Target));
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.Attachment.CreateFromStaging');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Attachment.CreateFromStaging');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Attachment.CreateFromStaging');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Attachment.CreateFromStaging');
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
        Related := ContractParts.GetRelated('Storage.Attachment.CreateFromStaging');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetWorkflow('Storage.Attachment.CreateFromStaging', Workflow));
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        Examples := ContractParts.GetExamples('Storage.Attachment.CreateFromStaging');
        Guide.PrependSuccessExample('Storage.Attachment.CreateFromStaging', Examples);
        exit(Examples.Count() > 0);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Overview := ContractParts.GetOverview('Storage.Attachment.CreateFromStaging');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetNotes('Storage.Attachment.CreateFromStaging', Notes));
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
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if AttachmentMgt.CreateFromStaging(Argument, ResultData) then
            RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
