namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Implementation of the <c>Storage.Directory.List</c> message type. Lists the
/// subdirectories of a directory in the configured storage connection.
/// </summary>
codeunit 10035647 "Storage Dir List Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Lists the subdirectories of a directory in the configured storage connection.', Comment = 'is-IS=Listar undirmöppur möppu í uppsettri geymslutengingu.';
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
        KeywordsLbl: Label 'list folders, subfolders, show folder tree, what folders are there, browse directories, list directories, sub directories in storage', Comment = 'is-IS=lista möppur, undirmöppur, undirmöppum, sýna möpputré, hvaða möppur eru til, skoða möppur, möppur í geymslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Lists the subfolders of one folder in a storage connection; use the file listing type to see the files in that folder.', Comment = 'is-IS=Listar undirmöppur einnar möppu í geymslutengingu; notaðu skráalista til að sjá skrár í möppunni.';
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
        Parameters := ContractParts.GetParameters('Storage.Directory.List');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Directory.List');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Directory.List');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Directory.List');
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
        Related := ContractParts.GetRelated('Storage.Directory.List');
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
        Path: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        RequestJson := Argument.GetRequestJson();
        RequestMgt.ReadSetup(Argument, RequestJson, StorageSetup, Connector);
        Reader.ReadPath(Argument, RequestJson, 'path', false, Path);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteList(Argument, StorageSetup, Connector, Path, Enum::"Ext. File Storage File Type"::Directory);
    end;
}
