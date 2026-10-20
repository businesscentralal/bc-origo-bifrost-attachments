namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;
using System.Utilities;

/// <summary>Imports a file into a Data Exch. entry with an import definition and parses its fields; optionally applies the mappings.</summary>
codeunit 10035166 "DataExch Import Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ImportFile(Rec);
    end;

    /// <summary>Reports whether the caller can write the affected table.</summary>
    procedure IsEnabled(): Boolean
    var
        DataExch: Record "Data Exch.";
    begin
        exit(DataExch.WritePermission());
    end;

    /// <summary>Returns the table associated with this message type.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Data Exch.");
    end;

    /// <summary>Describes the current operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Imports a file from storage or inline content into a Data Exch. entry and parses its fields with a Generic Import or Payroll Import definition.', Comment = 'is-IS=Flytur skrá úr geymslu eða innfellt innihald inn í gagnaskiptafærslu og þáttar reiti hennar með skilgreiningu fyrir almennan innflutning eða launainnflutning.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'data exchange import, import file, parse file, generic import', Comment = 'is-IS=innflutningur gagnaskipta, flytja inn skrá, þátta skrá, almennur innflutningur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains when to select this message type.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Imports a file that is already in storage, or small inline content, with a Generic Import or Payroll Import definition. Use Storage.Upload.CommitToDataExchange for a chunked upload.', Locked = true;
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the supported wire envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Envelope := ContractParts.GetDataExchangeEnvelope(true);
        Envelope.Add('messageType', 'DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Reports that this operation has no envelope target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Target := ContractParts.GetDataExchangeTarget('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Describes the accepted request keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Describes operation refusals.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Describes the database effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('DataExchange.Import.Run');
        exit(true);
    end;

    /// <summary>Reports that this operation adds no custom metering chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Get', 'Inspect the parsed fields of the entry.'));
        Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Process', 'Apply the mappings after inspecting the fields.'));
        Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToDataExchange', 'Import a file sent as a chunked upload.'));
        exit(true);
    end;

    /// <summary>Reports that no custom workflow chapter is supplied.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Reports that no example chapter is supplied.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Storage Contract Parts ori";
    begin
        Examples := ContractParts.GetExamples('DataExchange.Import.Run');
        exit(Examples.Count() > 0);
    end;

    /// <summary>Summarizes the operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reads the file from storage (the file stays there) or from contentBase64 (at most 1 MB), inserts a Data Exch. entry with the file content and runs the definition reader, so the parsed Data Exch. Field rows can be inspected with DataExchange.Entry.Get. With process true the mappings run as well.', Comment = 'is-IS=Les skrána úr geymslu (skráin er þar áfram) eða úr contentBase64 (mest 1 MB), stofnar gagnaskiptafærslu með innihaldi skrárinnar og keyrir lesara skilgreiningarinnar svo skoða megi þáttuðu reitina með DataExchange.Entry.Get. Með process true eru varpanirnar einnig keyrðar.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains operation restrictions.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Bank Statement Import definitions are refused; import bank statements with Finance.BankReconciliation.Create. Export definitions are refused. A file the reader cannot read answers an error and leaves no entry. With process true the import is committed first, so a processing error is reported in processResult.errors and the entry stays for DataExchange.Entry.Process. A successful call answers status Accepted.', Comment = 'is-IS=Skilgreiningum fyrir innflutning bankayfirlita er hafnað; flyttu bankayfirlit inn með Finance.BankReconciliation.Create. Útflutningsskilgreiningum er hafnað. Skrá sem lesarinn getur ekki lesið skilar villu og engin færsla verður eftir. Með process true er innflutningurinn staðfestur fyrst, svo vinnsluvilla birtist í processResult.errors og færslan bíður DataExchange.Entry.Process. Kall sem heppnast skilar stöðunni Accepted.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates all input before creating a header; execution errors propagate in the caller transaction.</summary>
    /// <param name="Argument">The licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        // A non-object request is refused here, before the worker reads it with GetRequestJson.
        if not Reader.ReadMutationRequest(Argument) then begin
            Reader.RespondIfErrors(Argument);
            exit;
        end;
        // No Boolean return: a reader error rolls back the whole import. Only process true commits, after the import.
        Codeunit.Run(Codeunit::"DataExch Import Run Impl ori", Argument);
    end;

    local procedure ImportFile(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        StorageSetup: Record "Storage Setup ori";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ProcessResult: JsonObject;
        DefCode: Code[20];
        StorageCode: Code[20];
        Path: Text;
        FileName: Text;
        InlineSource: Boolean;
        Process: Boolean;
        EmptyGuid: Guid;
        OneSourceErr: Label 'Send the file either as contentBase64 or as storageCode with path, not both.', Comment = 'is-IS=Sendu skrána annaðhvort sem contentBase64 eða sem storageCode með path, ekki hvort tveggja.';
        OneSourceExpectedLbl: Label 'exactly one source: contentBase64, or storageCode with path', Comment = 'is-IS=nákvæmlega ein uppspretta: contentBase64, eða storageCode með path';
        OneSourceNextStepLbl: Label 'Remove storageCode and path to import the inline content, or remove contentBase64 to import the stored file.', Comment = 'is-IS=Fjarlægðu storageCode og path til að flytja inn innfellda innihaldið, eða fjarlægðu contentBase64 til að flytja inn skrána úr geymslu.';
    begin
        RequestJson := Argument.GetRequestJson();
        Reader.ReadMutationCode(Argument, RequestJson, 'dataExchDefCode', DefCode);
        InlineSource := RequestJson.Contains('contentBase64');
        if InlineSource then begin
            if Reader.ReadBase64Content(Argument, RequestJson, 'contentBase64', true, TempBlob) then
                ImportMgt.CheckInlineSize(Argument, 'contentBase64', TempBlob.Length());
            if RequestJson.Contains('storageCode') or RequestJson.Contains('path') then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, OneSourceErr, 'contentBase64', '', OneSourceExpectedLbl, OneSourceNextStepLbl);
        end else begin
            Reader.ReadMutationCode(Argument, RequestJson, 'storageCode', StorageCode);
            if Reader.ReadMutationText(Argument, RequestJson, 'path', true, 2048, Path) then
                Reader.CheckPath(Argument, 'path', Path);
        end;
        if Reader.ReadMutationText(Argument, RequestJson, 'fileName', false, MaxStrLen(DataExch."File Name"), FileName) then
            if FileName <> '' then
                Reader.CheckFileName(Argument, FileName);
        Reader.ReadBoolean(Argument, RequestJson, 'process', false, Process);
        if Reader.RespondIfErrors(Argument) then
            exit;
        ImportMgt.CheckImportDefinition(Argument, DefCode, 'dataExchDefCode');
        if Reader.RespondIfErrors(Argument) then
            exit;
        if not InlineSource then
            if RequestMgt.ResolveSetup(Argument, StorageCode, 'storageCode', StorageSetup, Connector) then
                Reader.CheckStoragePath(Argument, StorageSetup, 'path', Path, false);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch.", true) then
            exit;
        if Reader.RespondIfTablePermissionDenied(Argument, Database::"Data Exch. Field", true) then
            exit;
        ImportMgt.CheckReader(Argument, DefCode, 'dataExchDefCode');
        if Reader.RespondIfErrors(Argument) then
            exit;
        // The stored file is only read; it stays in storage unchanged.
        if not InlineSource then
            if not RequestMgt.TryReadStorageFile(StorageSetup, Connector, Path, TempBlob) then begin
                ImportMgt.RespondFileReadError(Argument, Path);
                exit;
            end;
        if FileName = '' then
            if InlineSource then
                FileName := DefaultFileName(DefCode)
            else
                FileName := RequestMgt.LeafName(Path);

        if InlineSource then
            ImportMgt.CheckFileFormat(Argument, DefCode, TempBlob, 'contentBase64', FileName)
        else
            ImportMgt.CheckFileFormat(Argument, DefCode, TempBlob, 'path', FileName);
        if Reader.RespondIfErrors(Argument) then
            exit;

        // A reader error is raised and rolls back the entry and every parsed field with it.
        ImportMgt.ImportFile(DefCode, FileName, TempBlob, EmptyGuid, 'DataExchange.Import.Run', StorageCode, Path, DataExch);

        // The shipped wire shape is flat with status Accepted; the import result is added beside it.
        ResponseJson.Add('status', 'Accepted');
        ImportMgt.AddImportResult(DataExch, ResponseJson);
        if not InlineSource then begin
            ResponseJson.Add('storageCode', StorageCode);
            ResponseJson.Add('path', Path);
        end;
        if Process then begin
            ResponseJson.Add('processed', ImportMgt.ProcessIsolated(DataExch."Entry No.", ProcessResult));
            ResponseJson.Add('processResult', ProcessResult);
        end else
            ResponseJson.Add('processed', false);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure DefaultFileName(DefCode: Code[20]): Text
    var
        DataExch: Record "Data Exch.";
    begin
        DataExch."Data Exch. Def Code" := DefCode;
        exit(DefCode + DataExch.GetFileExtension());
    end;
}
