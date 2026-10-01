namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.File.Copy</c> message type. Copies a file within the
/// configured storage connection.
/// </summary>
codeunit 10035648 "Storage File Copy Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Copies a file within the configured storage connection.');
    end;

    /// <summary>
    /// Search terms users say for this type, English with the Icelandic translation. Used to rank
    /// search results; never shown to the caller.
    /// </summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'copy the file, duplicate a file in storage, copy to another folder, make a copy of the document, copy blob, keep a backup copy', Comment = 'is-IS=afrita skrá, afrita skrána, tvöfalda skrá í geymslu, afrita í aðra möppu, gera afrit af skjali, afrit af skjalinu, halda afriti';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Copies a file to another path within the same storage connection and keeps the original; use the move type to relocate it instead.', Locked = true;
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
        Parameters := ContractParts.GetParameters('Storage.File.Copy');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.File.Copy');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.File.Copy');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.File.Copy');
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
        Related := ContractParts.GetRelated('Storage.File.Copy');
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
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        SourcePath: Text;
        TargetPath: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        Reader.ReadPath(Argument, RequestJson, 'sourcePath', true, SourcePath);
        Reader.ReadPath(Argument, RequestJson, 'targetPath', true, TargetPath);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteCopyFile(Argument, StorageSetup, Connector, SourcePath, TargetPath);
    end;
}
