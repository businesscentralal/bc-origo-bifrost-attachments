namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.File.CreateFromStaging</c> message type. Writes the content of one
/// Foundation staging row to a file path in a storage connection and consumes the row (Take).
/// </summary>
codeunit 10035201 "Storage File CreateFromStg ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Writes a Foundation staging row to a file path in a storage connection and consumes the row.', Comment = 'is-IS=Skrifar bráðabirgðafærslu úr Bifröst-grunni á skráarslóð í geymslutengingu og eyðir færslunni.';
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
        KeywordsLbl: Label 'save staged file to storage, store the staging id, write staging to cloud folder, staged upload to storage path, put staged file in sharepoint, move staging into blob storage', Comment = 'is-IS=vista bráðabirgðaskrá í geymslu, geyma stagingId, skrifa bráðabirgðaskrá í skýjamöppu, bráðabirgðaupphleðsla á geymsluslóð, setja bráðabirgðaskrá í sharepoint, færa bráðabirgðaskrá í blob-geymslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Writes one Foundation staging row, by stagingId, to a storage file path and consumes the row; Storage.File.Create takes base64 instead.', Comment = 'is-IS=Skrifar eina bráðabirgðafærslu úr Bifröst-grunni, eftir stagingId, á skráarslóð í geymslu og eyðir færslunni; Storage.File.Create tekur við base64.';
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
        exit(Guide.GetTarget('Storage.File.CreateFromStaging', Target));
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.File.CreateFromStaging');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.File.CreateFromStaging');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.File.CreateFromStaging');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.File.CreateFromStaging');
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
        Related := ContractParts.GetRelated('Storage.File.CreateFromStaging');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetWorkflow('Storage.File.CreateFromStaging', Workflow));
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        Examples := ContractParts.GetExamples('Storage.File.CreateFromStaging');
        Guide.PrependSuccessExample('Storage.File.CreateFromStaging', Examples);
        exit(Examples.Count() > 0);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Overview := ContractParts.GetOverview('Storage.File.CreateFromStaging');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        Guide: Codeunit "Storage Contract Guide ori";
    begin
        exit(Guide.GetNotes('Storage.File.CreateFromStaging', Notes));
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
        StagingId: Guid;
        Path: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        Reader.ReadPath(Argument, RequestJson, 'path', true, Path);
        Reader.ReadGuid(Argument, RequestJson, 'stagingId', true, StagingId);
        RequestMgt.ReadExpectedSingleCount(Argument, RequestJson);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteCreateFromStaging(Argument, StorageSetup, Connector, Path, StagingId);
    end;
}
