namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;
using System.Utilities;

/// <summary>
/// Installs and dumps Data Exchange definitions as the standard definition XML, the file the base
/// application's Import and Export Data Exchange Definition actions read and write (XMLport
/// <c>Imp / Exp Data Exch Def &amp; Map</c>). Used by <c>DataExchange.Definition.Import</c> and
/// <c>DataExchange.Definition.Export</c>.
/// </summary>
codeunit 70013505 "DataExch Def Transfer ori"
{
    Access = Internal;

    var
        OneSourceErr: Label 'Send exactly one source: storageCode with path, contentBase64 or uploadId.', Comment = 'is-IS=Sendu nákvæmlega eina uppsprettu: storageCode með path, contentBase64 eða uploadId.';
        OneSourceExpectedLbl: Label 'exactly one of storageCode with path, contentBase64 or uploadId', Comment = 'is-IS=nákvæmlega eitt af storageCode með path, contentBase64 eða uploadId';
        OneSourceNextStepLbl: Label 'Send the XML inline as contentBase64 (at most 1 MB), name a stored file with storageCode and path, or send the uploadId of a complete chunked upload.', Comment = 'is-IS=Sendu XML-skjalið innfellt sem contentBase64 (mest 1 MB), tilgreindu skrá í geymslu með storageCode og path, eða sendu uploadId fullgerðrar upphleðslu í bútum.';
        NotXmlErr: Label 'The file is not a well-formed Data Exchange definition XML document.', Comment = 'is-IS=Skráin er ekki gilt XML-skjal með skilgreiningu gagnaskipta.';
        XmlExpectedLbl: Label 'the XML that the Export Data Exchange Definition action writes, with a root element and DataExchDef elements', Comment = 'is-IS=XML-skjalið sem aðgerðin Flytja út skilgreiningu gagnaskipta skrifar, með rótarstaki og DataExchDef-stökum';
        ExportFirstLbl: Label 'Export a definition with DataExchange.Definition.Export to see the expected format.', Comment = 'is-IS=Fluttu skilgreiningu út með DataExchange.Definition.Export til að sjá væntanlegt snið.';
        NoDefinitionErr: Label 'The file contains no DataExchDef element.', Comment = 'is-IS=Skráin inniheldur ekkert DataExchDef-stak.';
        CodeInvalidErr: Label 'The file contains the definition code "%1", which is not a valid code of at most 20 characters.', Comment = '%1 = code||is-IS=Skráin inniheldur skilgreiningarkóðann „%1“, sem er ekki gildur kóði, mest 20 stafir.';
        CodeExpectedLbl: Label 'an uppercase code of at most 20 characters', Comment = 'is-IS=kóði með hástöfum, mest 20 stafir';
        ExistsErr: Label 'Data Exchange definition %1 already exists.', Comment = '%1 = code||is-IS=Skilgreining gagnaskipta %1 er þegar til.';
        ExistsExpectedLbl: Label 'a definition code that does not exist yet, or overwrite true', Comment = 'is-IS=skilgreiningarkóði sem er ekki til, eða overwrite true';
        ExistsNextStepLbl: Label 'Send overwrite true to replace the definition, or newCode to install it under another code.', Comment = 'is-IS=Sendu overwrite true til að skipta skilgreiningunni út, eða newCode til að setja hana upp undir öðrum kóða.';
        NewCodeManyErr: Label 'newCode can rename only a file with one definition; this file has %1.', Comment = '%1 = count||is-IS=newCode getur aðeins endurnefnt skrá með einni skilgreiningu; þessi skrá hefur %1.';
        NewCodeExpectedLbl: Label 'a file with exactly one DataExchDef element', Comment = 'is-IS=skrá með nákvæmlega einu DataExchDef-staki';
        NewCodeNextStepLbl: Label 'Omit newCode, or install the definitions one file at a time.', Comment = 'is-IS=Slepptu newCode eða settu skilgreiningarnar upp eina skrá í einu.';

    /// <summary>
    /// Runs <c>DataExchange.Definition.Import</c>: reads the XML from storage, inline content or an upload,
    /// checks every definition code, and installs the definitions with the standard XMLport.
    /// </summary>
    /// <param name="Argument">The request; receives the response.</param>
    procedure ImportDefinitions(var Argument: Record "Message Argument ori")
    var
        StorageSetup: Record "Storage Setup ori";
        DataExchDef: Record "Data Exch. Def";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        TempBlob: Codeunit "Temp Blob";
        Connector: Interface "Storage Connector ori";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        Codes: List of [Text];
        Overwritten: JsonArray;
        Installed: JsonArray;
        Code: Text;
        StorageCode: Code[20];
        NewCode: Code[20];
        Path: Text;
        UploadFileName: Text;
        Overwrite: Boolean;
        UploadId: Guid;
        SourceCount: Integer;
        Consumed: Boolean;
        LineDefCount: Integer;
        MappingCount: Integer;
        SourceParameter: Text;
        SourceFileName: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Contains('contentBase64') then begin
            SourceCount += 1;
            if Reader.ReadBase64Content(Argument, RequestJson, 'contentBase64', true, TempBlob) then
                ImportMgt.CheckInlineSize(Argument, 'contentBase64', TempBlob.Length());
        end;
        if RequestJson.Contains('uploadId') then begin
            SourceCount += 1;
            Reader.ReadGuid(Argument, RequestJson, 'uploadId', true, UploadId);
        end;
        if RequestJson.Contains('storageCode') or RequestJson.Contains('path') or (SourceCount = 0) then begin
            SourceCount += 1;
            Reader.ReadMutationCode(Argument, RequestJson, 'storageCode', StorageCode);
            if Reader.ReadMutationText(Argument, RequestJson, 'path', true, 2048, Path) then
                Reader.CheckPath(Argument, 'path', Path);
        end;
        if SourceCount > 1 then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, OneSourceErr, 'storageCode', '', OneSourceExpectedLbl, OneSourceNextStepLbl);
        Reader.ReadBoolean(Argument, RequestJson, 'overwrite', false, Overwrite);
        if RequestJson.Contains('newCode') then
            Reader.ReadMutationCode(Argument, RequestJson, 'newCode', NewCode);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if Path <> '' then
            if RequestMgt.ResolveSetup(Argument, StorageCode, 'storageCode', StorageSetup, Connector) then
                Reader.CheckStoragePath(Argument, StorageSetup, 'path', Path, false);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if RespondIfDefinitionWriteDenied(Argument) then
            exit;
        if Path <> '' then
            if not RequestMgt.TryReadStorageFile(StorageSetup, Connector, Path, TempBlob) then begin
                ImportMgt.RespondFileReadError(Argument, Path);
                exit;
            end;
        if not IsNullGuid(UploadId) then begin
            // The upload is consumed here; a later refusal is raised so the session stays open.
            if not UploadMgt.ConsumeUpload(Argument, UploadId, TempBlob, UploadFileName) then
                exit;
            Consumed := true;
        end;

        SourceParameter := 'contentBase64';
        if Path <> '' then begin
            SourceParameter := 'path';
            SourceFileName := RequestMgt.LeafName(Path);
        end;
        if not IsNullGuid(UploadId) then begin
            SourceParameter := 'uploadId';
            SourceFileName := UploadFileName;
        end;
        CheckDefinitionXml(Argument, TempBlob, NewCode, Overwrite, Codes, SourceParameter, SourceFileName);
        if Argument.HasCollectedErrors() then begin
            if Consumed then
                Argument.RaiseCollectedErrors("Bifrost Error Code ori"::MultipleErrors, NotXmlErr);
            Reader.RespondIfErrors(Argument);
            exit;
        end;
        if NewCode <> '' then
            RenameDefinition(TempBlob, NewCode);
        foreach Code in Codes do
            if DataExchDef.Get(Code) then begin
                DataExchDef.Delete(true);
                Overwritten.Add(Code);
            end;
        InstallXml(TempBlob);
        foreach Code in Codes do begin
            Installed.Add(Code);
            LineDefCount += CountLineDefs(CopyStr(Code, 1, 20));
            MappingCount += CountMappings(CopyStr(Code, 1, 20));
        end;
        DataObject.Add('codes', Installed);
        DataObject.Add('lineDefs', LineDefCount);
        DataObject.Add('mappings', MappingCount);
        DataObject.Add('overwritten', Overwritten);
        RequestMgt.RespondSuccess(Argument, DataObject);
    end;

    /// <summary>Writes one definition with its lines, columns and mappings as the standard definition XML.</summary>
    /// <param name="DefCode">The definition code.</param>
    /// <param name="TempBlob">Returns the XML.</param>
    procedure ExportDefinitionXml(DefCode: Code[20]; var TempBlob: Codeunit "Temp Blob")
    var
        DataExchDef: Record "Data Exch. Def";
        XmlOutStream: OutStream;
    begin
        DataExchDef.SetRange(Code, DefCode);
        TempBlob.CreateOutStream(XmlOutStream);
        Xmlport.Export(Xmlport::"Imp / Exp Data Exch Def & Map", XmlOutStream, DataExchDef);
    end;

    local procedure RespondIfDefinitionWriteDenied(var Argument: Record "Message Argument ori"): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
        TableIds: List of [Integer];
        TableId: Integer;
    begin
        TableIds.Add(Database::"Data Exch. Def");
        TableIds.Add(Database::"Data Exch. Line Def");
        TableIds.Add(Database::"Data Exch. Column Def");
        TableIds.Add(Database::"Data Exch. Mapping");
        TableIds.Add(Database::"Data Exch. Field Mapping");
        foreach TableId in TableIds do
            if Reader.RespondIfTablePermissionDenied(Argument, TableId, true) then
                exit(true);
        exit(false);
    end;

    local procedure CheckDefinitionXml(var Argument: Record "Message Argument ori"; var TempBlob: Codeunit "Temp Blob"; NewCode: Code[20]; Overwrite: Boolean; var Codes: List of [Text]; SourceParameter: Text; SourceFileName: Text)
    var
        DataExchDef: Record "Data Exch. Def";
        ImportMgt: Codeunit "DataExch Import Mgt ori";
        Document: XmlDocument;
        Definitions: XmlNodeList;
        Definition: XmlNode;
        CodeAttribute: XmlAttribute;
        Code: Text;
    begin
        Clear(Codes);
        if not TryReadXml(TempBlob, Document) then begin
            ImportMgt.AddFileFormatError(Argument, SourceParameter, SourceFileName, TempBlob.Length(), 'XML');
            exit;
        end;
        Document.SelectNodes('/root/DataExchDef', Definitions);
        if Definitions.Count() = 0 then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, NoDefinitionErr, SourceParameter, SourceFileName, XmlExpectedLbl, ExportFirstLbl);
            exit;
        end;
        if (NewCode <> '') and (Definitions.Count() <> 1) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NewCodeManyErr, Definitions.Count()), 'newCode', NewCode, NewCodeExpectedLbl, NewCodeNextStepLbl);
            exit;
        end;
        foreach Definition in Definitions do begin
            Code := '';
            if Definition.AsXmlElement().Attributes().Get('Code', CodeAttribute) then
                Code := CodeAttribute.Value();
            if NewCode <> '' then
                Code := NewCode;
            if (Code = '') or (StrLen(Code) > MaxStrLen(DataExchDef.Code)) or (Code <> UpperCase(Code)) then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(CodeInvalidErr, Code), SourceParameter, Code, CodeExpectedLbl, ExportFirstLbl)
            else begin
                Codes.Add(Code);
                DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
                DataExchDef.SetLoadFields(Code);
                if (not Overwrite) and DataExchDef.Get(Code) then
                    Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ExistsErr, Code), 'overwrite', Code, ExistsExpectedLbl, ExistsNextStepLbl);
            end;
        end;
    end;

    [TryFunction]
    local procedure TryReadXml(var TempBlob: Codeunit "Temp Blob"; var Document: XmlDocument)
    var
        XmlInStream: InStream;
    begin
        TempBlob.CreateInStream(XmlInStream);
        XmlDocument.ReadFrom(XmlInStream, Document);
    end;

    local procedure RenameDefinition(var TempBlob: Codeunit "Temp Blob"; NewCode: Code[20])
    var
        Document: XmlDocument;
        Definition: XmlNode;
        XmlOutStream: OutStream;
    begin
        TryReadXml(TempBlob, Document);
        Document.SelectSingleNode('/root/DataExchDef', Definition);
        Definition.AsXmlElement().SetAttribute('Code', NewCode);
        Clear(TempBlob);
        TempBlob.CreateOutStream(XmlOutStream, TextEncoding::UTF8);
        Document.WriteTo(XmlOutStream);
    end;

    local procedure InstallXml(var TempBlob: Codeunit "Temp Blob")
    var
        XmlInStream: InStream;
    begin
        TempBlob.CreateInStream(XmlInStream);
        Xmlport.Import(Xmlport::"Imp / Exp Data Exch Def & Map", XmlInStream);
    end;

    local procedure CountLineDefs(DefCode: Code[20]): Integer
    var
        DataExchLineDef: Record "Data Exch. Line Def";
    begin
        DataExchLineDef.SetRange("Data Exch. Def Code", DefCode);
        exit(DataExchLineDef.Count());
    end;

    local procedure CountMappings(DefCode: Code[20]): Integer
    var
        DataExchMapping: Record "Data Exch. Mapping";
    begin
        DataExchMapping.SetRange("Data Exch. Def Code", DefCode);
        exit(DataExchMapping.Count());
    end;
}
