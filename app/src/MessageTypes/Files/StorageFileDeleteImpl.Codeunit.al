namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.File.Delete</c> message type. Deletes a file from the
/// configured storage connection.
/// </summary>
codeunit 10035650 "Storage File Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether this message type is available to the current caller.</summary>
    /// <returns>Whether the caller has read permission on <c>Storage Setup ori</c>; this does not check for a configured or enabled connection.</returns>
    procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        exit(StorageSetup.ReadPermission());
    end;

    /// <summary>Declares that this message type has no record-filter table.</summary>
    /// <returns>Zero.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Returns the short description of this message type for discovery.</summary>
    /// <returns>The existing description text, without executing the message.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Deletes a file from the configured storage connection.', Comment = 'is-IS=Eyðir skrá úr uppsettri geymslutengingu.';
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
        KeywordsLbl: Label 'delete the file, remove file from storage, delete stored pdf, erase the document from cloud, delete blob, remove file from sharepoint, clean up a file', Comment = 'is-IS=eyða skrá, eyða skránni, fjarlægja skrá úr geymslu, eyða geymdri pdf, eyða skjali úr skýinu, eyða skjalinu, fjarlægja skrá úr sharepoint';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Deletes a single file from a storage connection; to remove a whole folder use the directory delete type instead.', Comment = 'is-IS=Eyðir einni skrá úr geymslutengingu; notaðu boðgerðina fyrir eyðingu mappa til að eyða heilli möppu.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Replaces the envelope chapter with shared version 1.0 JSON metadata, declaring required request data and no subject record.</summary>
    /// <param name="Envelope">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(true);
        exit(true);
    end;

    /// <summary>Declares that this message type provides no target chapter; leaves the supplied output unchanged.</summary>
    /// <param name="Target">Left unchanged; the caller must use the return value to determine chapter availability.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Replaces the parameters chapter with the shared contract metadata for <c>Storage.File.Delete</c>; does not execute the operation.</summary>
    /// <param name="Parameters">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.File.Delete');
        exit(true);
    end;

    /// <summary>Replaces the response chapter with the shared contract metadata for <c>Storage.File.Delete</c>; does not execute the operation.</summary>
    /// <param name="Response">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.File.Delete');
        exit(true);
    end;

    /// <summary>Replaces the errors chapter with the shared contract metadata for <c>Storage.File.Delete</c>; does not execute the operation.</summary>
    /// <param name="Errors">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.File.Delete');
        exit(true);
    end;

    /// <summary>Replaces the effect chapter with the shared contract metadata for <c>Storage.File.Delete</c>; does not execute the operation.</summary>
    /// <param name="Effect">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.File.Delete');
        exit(true);
    end;

    /// <summary>Declares that this message type provides no metering chapter; leaves the supplied output unchanged.</summary>
    /// <param name="Metering">Left unchanged; the caller must use the return value to determine chapter availability.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Replaces the related chapter with the shared contract metadata for <c>Storage.File.Delete</c>; does not execute the operation.</summary>
    /// <param name="Related">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Storage.File.Delete');
        exit(true);
    end;

    /// <summary>Declares that this message type provides no workflow chapter; leaves the supplied output unchanged.</summary>
    /// <param name="Workflow">Left unchanged; the caller must use the return value to determine chapter availability.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares that this message type provides no examples chapter; leaves the supplied output unchanged.</summary>
    /// <param name="Examples">Left unchanged; the caller must use the return value to determine chapter availability.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares that this message type provides no overview chapter and clears the supplied text.</summary>
    /// <param name="Overview">Cleared to empty text, even though no chapter is supplied.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        exit(false);
    end;

    /// <summary>Declares that this message type provides no notes chapter and clears the supplied text.</summary>
    /// <param name="Notes">Cleared to empty text, even though no chapter is supplied.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    /// <summary>Declares this message type as outbound in Foundation metadata.</summary>
    /// <returns><c>Msg Direction ori.Outbound</c>.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>
    /// Checks version and licensing, resolves the storage setup and connector, and collects the request path errors before delegation.
    /// Delegates file deletion to the request manager, including its provider and linked-file guards; success answers with <c>data.path</c>.
    /// Collected setup or input errors answer on the argument and stop this handler before the delegated operation; delegated errors may answer or propagate.
    /// </summary>
    /// <param name="Argument">Request context; receives the success or error response and response content type.</param>
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
        Reader.ReadPath(Argument, RequestJson, 'path', true, Path);
        if Reader.RespondIfErrors(Argument) then
            exit;
        RequestMgt.ExecuteDeleteFile(Argument, StorageSetup, Connector, Path);
    end;
}
