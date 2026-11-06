namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.File.CopyToStaging</c> message type. Copies one file from a storage
/// connection into one Foundation staging row and answers its stagingId.
/// </summary>
codeunit 10035203 "Storage File CopyToStaging ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Copies a file from a storage connection into one Foundation staging row and returns its stagingId.', Comment = 'is-IS=Afritar skrá úr geymslutengingu í eina bráðabirgðafærslu í Bifröst-grunni og skilar stagingId hennar.';
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
        KeywordsLbl: Label 'stage the stored file, copy storage file to staging, file to staging id, hand stored file to prompt, use stored file in report layout, read from storage into staging', Comment = 'is-IS=geyma geymda skrá tímabundið, afrita geymsluskrá í bráðabirgðageymslu, skrá í stagingId, afhenda geymda skrá til fyrirspurnar, nota geymda skrá í skýrslusniði, lesa úr geymslu í bráðabirgðageymslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Copies one existing storage file into one Foundation staging row and returns stagingId for a consuming message type; the storage file is unchanged, and Storage.File.Get is the type that returns the content as base64 instead.', Comment = 'is-IS=Afritar eina skrá úr geymslu í eina bráðabirgðafærslu í Bifröst-grunni og skilar stagingId fyrir móttökugerð; geymsluskráin breytist ekki, en Storage.File.Get skilar innihaldinu sem base64.';
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
        exit(Guide.GetTarget('Storage.File.CopyToStaging', Target));
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.File.CopyToStaging');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.File.CopyToStaging');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.File.CopyToStaging');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.File.CopyToStaging');
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
        Related := ContractParts.GetRelated('Storage.File.CopyToStaging');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetWorkflow('Storage.File.CopyToStaging', Workflow));
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        Examples := ContractParts.GetExamples('Storage.File.CopyToStaging');
        Guide.PrependSuccessExample('Storage.File.CopyToStaging', Examples);
        exit(Examples.Count() > 0);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Overview := ContractParts.GetOverview('Storage.File.CopyToStaging');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetNotes('Storage.File.CopyToStaging', Notes));
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        Path: Text;
        ContentType: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        Reader.ReadPath(Argument, RequestJson, 'path', true, Path);
        Reader.ReadText(Argument, RequestJson, 'contentType', false, ContentType);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteCopyToStaging(Argument, StorageSetup, Connector, Path, ContentType, Reader.MaxContentBytes());
    end;
}
