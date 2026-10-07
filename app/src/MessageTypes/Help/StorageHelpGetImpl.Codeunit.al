namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Help.Storage.Get</c> message type. Returns a Markdown overview
/// of the storage connector, release baseline, and every message type it exposes.
/// No request body is required.
/// </summary>
codeunit 10035655 "Storage Help Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether this message type is available to the current caller.</summary>
    /// <returns>True unconditionally; no permission or setup probe is performed here.</returns>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
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
        DescriptionLbl: Label 'Returns a Markdown overview of the storage connector and all its message types. No request body is required.', Comment = 'is-IS=Skilar Markdown-yfirliti yfir geymslutengilinn og allar boðgerðir hans. Enginn meginmálshluti beiðni er nauðsynlegur.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns the translated discovery search terms for this help message.</summary>
    /// <returns>Comma-separated terms from the keyword label in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'storage help, storage message types, how to use storage, storage API overview, storage documentation', Comment = 'is-IS=geymslu hjálp, geymsluboðgerðir, hvernig á að nota geymslu, yfirlit yfir geymslu API, geymsluskjöl';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the selection guidance for this help message.</summary>
    /// <returns>The existing selection-description label text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns the storage connector guide and message type map; use a specific storage type to perform an operation.', Comment = 'is-IS=Skilar leiðbeiningum um geymslutengilinn og yfirliti yfir boðgerðir; notaðu tiltekna geymsluboðgerð til að framkvæma aðgerð.';
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

    /// <summary>Declares that this message type provides no parameters chapter; leaves the supplied output unchanged.</summary>
    /// <param name="Parameters">Left unchanged; the caller must use the return value to determine chapter availability.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Replaces the response chapter with the shared contract metadata for <c>Help.Storage.Get</c>; does not execute the operation.</summary>
    /// <param name="Response">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Help.Storage.Get');
        exit(true);
    end;

    /// <summary>Replaces the errors chapter with the shared contract metadata for <c>Help.Storage.Get</c>; does not execute the operation.</summary>
    /// <param name="Errors">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Help.Storage.Get');
        exit(true);
    end;

    /// <summary>Replaces the effect chapter with the shared contract metadata for <c>Help.Storage.Get</c>; does not execute the operation.</summary>
    /// <param name="Effect">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Help.Storage.Get');
        exit(true);
    end;

    /// <summary>Declares that this message type provides no metering chapter; leaves the supplied output unchanged.</summary>
    /// <param name="Metering">Left unchanged; the caller must use the return value to determine chapter availability.</param>
    /// <returns>False; no chapter is advertised.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Replaces the related chapter with the shared contract metadata for <c>Help.Storage.Get</c>; does not execute the operation.</summary>
    /// <param name="Related">Replaced by the generated chapter.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Help.Storage.Get');
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

    /// <summary>Replaces the overview chapter with the existing getting-started guidance text; does not execute the message.</summary>
    /// <param name="Overview">Replaced by the overview text.</param>
    /// <returns>True; the chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Getting started: call Storage.Account.List, then use invoke_message_type and describe_message_type. Storage.Upload.Begin uses the bifrost-uploads/ default root.', Comment = 'is-IS=Fyrstu skref: kallaðu á Storage.Account.List og notaðu síðan invoke_message_type og describe_message_type. Storage.Upload.Begin notar sjálfgefnu rótina bifrost-uploads/.';
    begin
        Overview := OverviewLbl;
        exit(true);
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
    /// Checks version and answers with <c>data.format = markdown</c> and an empty <c>data.markdown</c> string.
    /// This execution path does not assert licensing, access a storage provider or generate the discovery guide text.
    /// </summary>
    /// <param name="Argument">Request context; receives the success or error response and response content type.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
        DataObject: JsonObject;
    begin
        Argument.AssertVersion1();
        DataObject.Add('format', 'markdown');
        DataObject.Add('markdown', '');
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;
}
