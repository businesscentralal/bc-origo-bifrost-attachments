namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.ExternalFileStorage;

/// <summary>
/// Implementation of the <c>Storage.Account.List</c> message type. Lists the configured
/// storage connections — their codes, descriptions, connectors and enabled state — so a
/// caller can discover the <c>storageCode</c> values to use. No secrets are exposed.
/// </summary>
codeunit 10035639 "Storage Account List Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Lists the configured storage connections (codes, descriptions, connectors and enabled state). No secrets are exposed.', Comment = 'is-IS=Listar uppsettar geymslutengingar (kóða, lýsingar, tengla og hvort þær séu virkar). Engin leyndarmál eru birt.';
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
        KeywordsLbl: Label 'storage connections, which storage accounts, list storage accounts, configured storage, cloud storage setup, where are files stored, azure blob connection, sharepoint connection, file share connection, storage code', Comment = 'is-IS=geymslutengingar, geymslutenging, hvaða geymslur, geymslureikningar, uppsettar geymslur, skýjageymsla, skýjageymslu, hvar eru skrár geymdar, sharepoint tenging, geymslukóði';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Lists the configured storage connections to Azure Blob Storage, Azure File Share or SharePoint so a caller can pick the storage code; it reads no files.', Comment = 'is-IS=Listar uppsettar geymslutengingar við Azure Blob Storage, Azure File Share eða SharePoint svo kallandi geti valið geymslukóða; les engar skrár.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Replaces the envelope chapter with shared version 1.0 JSON metadata, declaring optional request data and no subject record.</summary>
    /// <param name="Envelope">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope(false);
        exit(true);
    end;

    /// <summary>Declares that this message type provides no target chapter; leaves the supplied output unchanged.</summary>
    /// <param name="Target">Left unchanged; the caller must use the return value to determine chapter availability.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Replaces the parameters chapter with the shared contract metadata for <c>Storage.Account.List</c>; does not execute the operation.</summary>
    /// <param name="Parameters">Replaced by the generated chapter.</param>
    /// <returns>False; no chapter is advertised. The output is still replaced by the shared parameter array (empty for this type).</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Storage.Account.List');
        exit(false);
    end;

    /// <summary>Replaces the response chapter with the shared contract metadata for <c>Storage.Account.List</c>; does not execute the operation.</summary>
    /// <param name="Response">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Storage.Account.List');
        exit(true);
    end;

    /// <summary>Replaces the errors chapter with the shared contract metadata for <c>Storage.Account.List</c>; does not execute the operation.</summary>
    /// <param name="Errors">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Storage.Account.List');
        exit(true);
    end;

    /// <summary>Replaces the effect chapter with the shared contract metadata for <c>Storage.Account.List</c>; does not execute the operation.</summary>
    /// <param name="Effect">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Storage.Account.List');
        exit(true);
    end;

    /// <summary>Declares that this message type provides no metering chapter; leaves the supplied output unchanged.</summary>
    /// <param name="Metering">Left unchanged; the caller must use the return value to determine chapter availability.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Replaces the related chapter with the shared contract metadata for <c>Storage.Account.List</c>; does not execute the operation.</summary>
    /// <param name="Related">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Storage.Account.List');
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
    /// Checks version and licensing, reads configured storage rows in the current company, and answers with <c>data.accounts</c>.
    /// Each entry contains code, description, connector name, base path and enabled state; no provider files or setup rows are changed.
    /// </summary>
    /// <param name="Argument">Request context; receives the success or error response and response content type.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        DataObject: JsonObject;
        AccountsArray: JsonArray;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        StorageSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        StorageSetup.SetLoadFields("Code", Description, Connector, "Base Path", Enabled);
        if StorageSetup.FindSet() then
            repeat
                AccountsArray.Add(AccountToJson(StorageSetup));
            until StorageSetup.Next() = 0;
        DataObject.Add('accounts', AccountsArray);
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;

    local procedure AccountToJson(var StorageSetup: Record "Storage Setup ori") AccountObject: JsonObject
    begin
        AccountObject.Add('code', StorageSetup."Code");
        AccountObject.Add('description', StorageSetup.Description);
        AccountObject.Add('connector', ConnectorName(StorageSetup.Connector));
        AccountObject.Add('basePath', StorageSetup."Base Path");
        AccountObject.Add('enabled', StorageSetup.Enabled);
    end;

    local procedure ConnectorName(Connector: Enum "Ext. File Storage Connector"): Text
    var
        Ordinals: List of [Integer];
        Names: List of [Text];
        Index: Integer;
    begin
        Ordinals := Connector.Ordinals();
        Names := Connector.Names();
        Index := Ordinals.IndexOf(Connector.AsInteger());
        if Index = 0 then
            exit('');
        exit(Names.Get(Index));
    end;
}
