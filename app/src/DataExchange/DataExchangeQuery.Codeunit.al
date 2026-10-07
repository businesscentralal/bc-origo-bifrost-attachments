namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.IO;
using System.Reflection;
using System.Text;

/// <summary>
/// Read-only queries behind the Data Exchange discovery message types.
/// Implementations stay thin and call this codeunit. Base-table reads on the
/// message hot path are covered by the <c>Permissions</c> property.
/// </summary>
codeunit 70013520 "Data Exchange Query ori"
{
    Access = Internal;
    Permissions =
        tabledata "Data Exch." = R,
        tabledata "Data Exch. Column Def" = R,
        tabledata "Data Exch. Def" = R,
        tabledata "Data Exch. Field" = R,
        tabledata "Data Exch. Field Mapping" = R,
        tabledata "Data Exch. Line Def" = R,
        tabledata "Data Exch. Mapping" = R,
        tabledata "Data Exchange Type" = R,
        tabledata AllObjWithCaption = R,
        tabledata "Field" = R;

    var
        MissingParamErr: Label 'Missing required ''%1'' in the request.', Comment = '%1 = parameter name||is-IS=Nauðsynlega færibreytuna ''%1'' vantar í beiðnina.';
        UnknownDefErr: Label 'No Data Exch. Def exists for code ''%1''.', Comment = '%1 = definition code||is-IS=Engin skilgreining gagnaskipta er til fyrir kóðann ''%1''.';
        UnknownEntryErr: Label 'Data Exch. entry %1 was not found.', Comment = '%1 = entry no.||is-IS=Gagnaskiptafærsla %1 fannst ekki.';
        UnknownTypeErr: Label 'Unknown Data Exch. Def type ''%1''.', Comment = '%1 = type name||is-IS=Óþekkt gerð skilgreiningar gagnaskipta ''%1''.';
        UnknownDirectionErr: Label 'direction must be Import or Export.', Comment = 'is-IS=direction verður að vera Import eða Export.';
        BooleanParamErr: Label '''%1'' must be a boolean.', Comment = '%1 = parameter name||is-IS=''%1'' verður að vera Boole-gildi.';
        IntegerParamErr: Label '''%1'' must be an integer.', Comment = '%1 = parameter name||is-IS=''%1'' verður að vera heiltala.';
        DateParamErr: Label '''%1'' must be an invariant date (YYYY-MM-DD) or datetime.', Comment = '%1 = parameter name||is-IS=''%1'' verður að vera dagsetning á óháðu sniði (YYYY-MM-DD) eða dagsetning og tími.';
        FileTooLargeErr: Label 'File content is %1 bytes, which is above the 1 MB limit for includeFileContent.', Comment = '%1 = byte length||is-IS=Skráarinnihaldið er %1 bæti, sem er yfir 1 MB hámarkinu fyrir includeFileContent.';
        FileSizeExpectedLbl: Label 'at most 1 MB', Comment = 'is-IS=að hámarki 1 MB';
        BooleanExpectedLbl: Label 'true or false', Comment = 'is-IS=true eða false';
        DirectionExpectedLbl: Label 'Import or Export', Comment = 'is-IS=Import eða Export';
        TextParamErr: Label 'Parameter "%1" must be a JSON string.', Comment = '%1 = parameter name, is-IS=Færibreytan "%1" verður að vera JSON-strengur.';
        EmptyValueLbl: Label '(empty string)', Comment = 'is-IS=(tómur strengur)';
        MissingValueLbl: Label '(missing)', Comment = 'is-IS=(vantar)';
        PagingLimitErr: Label 'take must not exceed 1000.', Comment = 'is-IS=take má ekki vera yfir 1000.';
        PagingExpectedLbl: Label 'an integer from 0 to 1000; 0 uses the default page size of 100', Comment = 'is-IS=heiltala frá 0 til 1000; 0 notar sjálfgefna síðustærð, 100';
        TextExpectedLbl: Label 'a JSON string', Comment = 'is-IS=JSON-strengur';
        SendTextLbl: Label 'Send "%1" as a JSON string.', Comment = '%1 = parameter name, is-IS=Sendu "%1" sem JSON-streng.';
        SendRequiredLbl: Label 'Provide "%1" and send the request again.', Comment = '%1 = parameter name, is-IS=Gefðu upp "%1" og sendu beiðnina aftur.';
        CodeLengthErr: Label 'Parameter "%1" exceeds the maximum length of %2 characters.', Comment = '%1 = parameter name, %2 = maximum length, is-IS=Færibreytan "%1" er lengri en leyfilegt hámark, %2 stafir.';
        CodeLengthExpectedLbl: Label 'at most %1 characters', Comment = '%1 = maximum length, is-IS=að hámarki %1 stafir';
        ShortenCodeLbl: Label 'Use the complete code within the stated length; values are never truncated.', Comment = 'is-IS=Notaðu allan kóðann innan tilgreindrar lengdar; gildi eru aldrei stytt.';
        ChooseTypeLbl: Label 'Use a type name returned by DataExchange.Definition.List.', Comment = 'is-IS=Notaðu gerðarheiti sem DataExchange.Definition.List skilar.';
        ChooseDirectionLbl: Label 'Send Import or Export, or omit direction to list both.', Comment = 'is-IS=Sendu Import eða Export, eða slepptu direction til að birta hvort tveggja.';
        ChooseDefinitionLbl: Label 'Use a code returned by DataExchange.Definition.List.', Comment = 'is-IS=Notaðu kóða sem DataExchange.Definition.List skilar.';
        ChooseEntryLbl: Label 'Use an entryNo returned by DataExchange.Entry.List.', Comment = 'is-IS=Notaðu entryNo sem DataExchange.Entry.List skilar.';
        SendBooleanLbl: Label 'Send "%1" as true or false, or omit it to use the default.', Comment = '%1 = parameter name, is-IS=Sendu "%1" sem true eða false, eða slepptu því til að nota sjálfgefið gildi.';
        SendIntegerLbl: Label 'Send "%1" as an integer within the allowed range.', Comment = '%1 = parameter name, is-IS=Sendu "%1" sem heiltölu innan leyfilegra marka.';
        NonNegativeLbl: Label 'an integer greater than or equal to 0', Comment = 'is-IS=heiltala sem er stærri en eða jöfn 0';
        PositiveIntegerLbl: Label 'an integer greater than 0', Comment = 'is-IS=heiltala sem er stærri en 0';
        DateExpectedLbl: Label 'YYYY-MM-DD or an invariant datetime', Comment = 'is-IS=YYYY-MM-DD eða dagsetning og tími á óháðu sniði';
        SendDateLbl: Label 'Send "%1" as YYYY-MM-DD or an invariant datetime, or omit it.', Comment = '%1 = parameter name, is-IS=Sendu "%1" sem YYYY-MM-DD eða dagsetningu og tíma á óháðu sniði, eða slepptu því.';
        DateRangeErr: Label 'dateFrom must not be later than dateTo.', Comment = 'is-IS=dateFrom má ekki vera síðar en dateTo.';
        DateRangeExpectedLbl: Label 'dateFrom less than or equal to dateTo', Comment = 'is-IS=dateFrom fyrr en eða jafnt og dateTo';
        CorrectDateRangeLbl: Label 'Correct the start and end dates and send the request again.', Comment = 'is-IS=Leiðréttu upphafs- og lokadagsetningar og sendu beiðnina aftur.';
        OmitFileContentLbl: Label 'Send includeFileContent as false or omit it; retrieve the file through its storage workflow.', Comment = 'is-IS=Sendu includeFileContent sem false eða slepptu því; sæktu skrána í gegnum geymsluferlið.';

    /// <summary>Lists Data Exch. Def rows, optionally filtered by type name and Import/Export direction.</summary>
    /// <param name="Argument">The message argument. Receives the success or error response.</param>
    procedure ListDefinitions(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        Rows: JsonArray;
        TypeText: Text;
        DirectionText: Text;
        DefType: Enum "Data Exchange Definition Type";
        FilterByType: Boolean;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadText(Argument, RequestJson, 'type', false, 0, TypeText);
        ReadText(Argument, RequestJson, 'direction', false, 0, DirectionText);
        if (DirectionText <> '') and not DirectionIsValid(DirectionText) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, UnknownDirectionErr, 'direction', DirectionText, DirectionExpectedLbl, ChooseDirectionLbl);
        if TypeText <> '' then
            if TryTypeFromName(TypeText, DefType) then
                FilterByType := true
            else
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnknownTypeErr, TypeText), 'type', TypeText, EnumNames(DefType), ChooseTypeLbl);
        if RespondIfErrors(Argument) then
            exit;

        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchDef.SetLoadFields(Code, Name, Type, "File Type", "Reading/Writing Codeunit", "Reading/Writing XMLport", "Ext. Data Handling Codeunit");
        if FilterByType then
            DataExchDef.SetRange(Type, DefType);
        if DataExchDef.FindSet() then
            repeat
                if TypeMatchesDirection(DataExchDef.Type, DirectionText) then
                    Rows.Add(DefinitionToJson(DataExchDef));
            until DataExchDef.Next() = 0;

        DataObject.Add('count', Rows.Count());
        DataObject.Add('definitions', Rows);
        RespondSuccess(Argument, DataObject);
    end;

    /// <summary>Returns one definition with its line definitions, column definitions and field mappings.</summary>
    /// <param name="Argument">The message argument. Receives the success or error response.</param>
    procedure GetDefinition(var Argument: Record "Message Argument ori")
    var
        DataExchDef: Record "Data Exch. Def";
        RequestJson: JsonObject;
        CodeText: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadText(Argument, RequestJson, 'code', true, MaxStrLen(DataExchDef.Code), CodeText);
        if RespondIfErrors(Argument) then
            exit;

        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchDef.SetLoadFields(Code, Name, Type, "File Type", "Reading/Writing Codeunit", "Reading/Writing XMLport", "Ext. Data Handling Codeunit");
        if not DataExchDef.Get(CodeText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownDefErr, CodeText), 'code', CodeText, ChooseDefinitionLbl, ChooseDefinitionLbl);
            exit;
        end;

        RespondSuccess(Argument, DefinitionDetailToJson(DataExchDef));
    end;

    /// <summary>
    /// Lists Data Exchange Type rows. Codeunit names and the definition type are resolved
    /// from the linked Data Exch. Def, which is where those fields are stored.
    /// </summary>
    /// <param name="Argument">The message argument. Receives the success response.</param>
    procedure ListTypes(var Argument: Record "Message Argument ori")
    var
        DataExchType: Record "Data Exchange Type";
        DataObject: JsonObject;
        Rows: JsonArray;
    begin
        DataExchType.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchType.SetLoadFields(Code, Description, "Data Exch. Def. Code");
        if DataExchType.FindSet() then
            repeat
                Rows.Add(TypeToJson(DataExchType));
            until DataExchType.Next() = 0;

        DataObject.Add('count', Rows.Count());
        DataObject.Add('types', Rows);
        RespondSuccess(Argument, DataObject);
    end;

    /// <summary>Lists Data Exch. entries. <c>skip</c>/<c>take</c> go through <c>EvaluateSkipTake</c>.</summary>
    /// <param name="Argument">The message argument. Receives the success or error response.</param>
    procedure ListEntries(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        Rows: JsonArray;
        DateFrom: DateTime;
        DateTo: DateTime;
        HasFrom: Boolean;
        HasTo: Boolean;
        Skip: Integer;
        Take: Integer;
        TotalCount: Integer;
        DefCode: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadPaging(Argument, RequestJson);
        ReadFilterDateTime(Argument, RequestJson, 'dateFrom', DateFrom, HasFrom);
        ReadFilterDateTime(Argument, RequestJson, 'dateTo', DateTo, HasTo);
        ReadText(Argument, RequestJson, 'dataExchDefCode', false, MaxStrLen(DataExch."Data Exch. Def Code"), DefCode);
        if HasFrom and HasTo and (DateFrom > DateTo) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, DateRangeErr, 'dateFrom', Format(DateFrom, 0, 9), DateRangeExpectedLbl, CorrectDateRangeLbl);
        if RespondIfErrors(Argument) then
            exit;
        Argument.EvaluateSkipTake(RequestJson, Skip, Take);
        DataExch.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExch.SetLoadFields("Entry No.", "File Name", "File Content", "Data Exch. Def Code", "Data Exch. Line Def Code", "Incoming Entry No.", "Related Record", SystemCreatedAt);
        if DefCode <> '' then
            DataExch.SetRange("Data Exch. Def Code", DefCode);
        if HasFrom and HasTo then
            DataExch.SetRange(SystemCreatedAt, DateFrom, DateTo)
        else
            if HasFrom then
                DataExch.SetFilter(SystemCreatedAt, '%1..', DateFrom)
            else
                if HasTo then
                    DataExch.SetFilter(SystemCreatedAt, '..%1', DateTo);

        TotalCount := DataExch.Count();
        if (Skip < TotalCount) and DataExch.FindSet() then begin
            if Skip > 0 then
                DataExch.Next(Skip);
            repeat
                Rows.Add(EntryToJson(DataExch));
                if Rows.Count() >= Take then
                    break;
            until DataExch.Next() = 0;
        end;

        DataObject.Add('count', TotalCount);
        DataObject.Add('skip', Skip);
        DataObject.Add('take', Take);
        DataObject.Add('entries', Rows);
        RespondSuccess(Argument, DataObject);
    end;

    /// <summary>
    /// Returns one Data Exch. entry. Fields are paged with <c>EvaluateSkipTake</c> when
    /// <c>includeFields</c> is true (the default). <c>includeFileContent</c> is refused above 1 MB.
    /// </summary>
    /// <param name="Argument">The message argument. Receives the success or error response.</param>
    procedure GetEntry(var Argument: Record "Message Argument ori")
    var
        DataExch: Record "Data Exch.";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        IncludeFields: Boolean;
        IncludeFileContent: Boolean;
        EntryNo: Integer;
        Skip: Integer;
        Take: Integer;
        ContentLength: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        ReadPaging(Argument, RequestJson);
        ReadBoolean(Argument, RequestJson, 'includeFields', true, IncludeFields);
        ReadBoolean(Argument, RequestJson, 'includeFileContent', false, IncludeFileContent);
        ReadInteger(Argument, RequestJson, 'entryNo', true, 1, EntryNo);
        if RespondIfErrors(Argument) then
            exit;
        Argument.EvaluateSkipTake(RequestJson, Skip, Take);

        DataExch.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExch.SetLoadFields("Entry No.", "File Name", "File Content", "Data Exch. Def Code", "Data Exch. Line Def Code", "Incoming Entry No.", "Related Record", SystemCreatedAt);
        if not DataExch.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownEntryErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), PositiveIntegerLbl, ChooseEntryLbl);
            exit;
        end;

        DataObject := EntryToJson(DataExch);
        if IncludeFileContent then begin
            ContentLength := FileContentLength(DataExch);
            if ContentLength > MaxInlineBytes() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, StrSubstNo(FileTooLargeErr, ContentLength), 'includeFileContent', Format(ContentLength, 0, 9), FileSizeExpectedLbl, OmitFileContentLbl);
                exit;
            end;
            DataObject.Add('contentLength', ContentLength);
            DataObject.Add('contentBase64', FileContentBase64(DataExch));
        end;
        DataObject.Add('skip', Skip);
        DataObject.Add('take', Take);
        if IncludeFields then
            DataObject.Add('fields', FieldPage(DataExch, Skip, Take));
        RespondSuccess(Argument, DataObject);
    end;

    local procedure DefinitionToJson(DataExchDef: Record "Data Exch. Def") Row: JsonObject
    var
        LineDef: Record "Data Exch. Line Def";
        Mapping: Record "Data Exch. Mapping";
    begin
        LineDef.SetRange("Data Exch. Def Code", DataExchDef.Code);
        Mapping.SetRange("Data Exch. Def Code", DataExchDef.Code);
        Row.Add('code', DataExchDef.Code);
        Row.Add('name', DataExchDef.Name);
        Row.Add('type', EnumName(DataExchDef.Type));
        Row.Add('fileType', FileTypeName(DataExchDef));
        Row.Add('readingWritingCodeunit', CodeunitName(DataExchDef."Reading/Writing Codeunit"));
        Row.Add('readingWritingXmlPort', XmlPortName(DataExchDef."Reading/Writing XMLport"));
        Row.Add('extDataHandlingCodeunit', CodeunitName(DataExchDef."Ext. Data Handling Codeunit"));
        Row.Add('lineDefCount', LineDef.Count());
        Row.Add('mappingCount', Mapping.Count());
        Row.Add('usedByDataExchangeTypes', TypesUsingDefinition(DataExchDef.Code));
    end;

    local procedure DefinitionDetailToJson(DataExchDef: Record "Data Exch. Def") Row: JsonObject
    begin
        Row := DefinitionToJson(DataExchDef);
        Row.Add('lineDefs', LineDefsToJson(DataExchDef.Code));
        Row.Add('columnDefs', ColumnDefsToJson(DataExchDef.Code));
        Row.Add('mappings', MappingsToJson(DataExchDef.Code));
    end;

    local procedure LineDefsToJson(DefCode: Code[20]) Rows: JsonArray
    var
        LineDef: Record "Data Exch. Line Def";
        Row: JsonObject;
    begin
        LineDef.ReadIsolation := IsolationLevel::ReadCommitted;
        LineDef.SetLoadFields(Code, Name, "Column Count", "Data Line Tag", Namespace);
        LineDef.SetRange("Data Exch. Def Code", DefCode);
        if LineDef.FindSet() then
            repeat
                Clear(Row);
                Row.Add('code', LineDef.Code);
                Row.Add('name', LineDef.Name);
                Row.Add('columnCount', LineDef."Column Count");
                Row.Add('dataLineTag', LineDef."Data Line Tag");
                Row.Add('namespace', LineDef.Namespace);
                Rows.Add(Row);
            until LineDef.Next() = 0;
    end;

    local procedure ColumnDefsToJson(DefCode: Code[20]) Rows: JsonArray
    var
        ColumnDef: Record "Data Exch. Column Def";
        Row: JsonObject;
    begin
        ColumnDef.ReadIsolation := IsolationLevel::ReadCommitted;
        ColumnDef.SetLoadFields("Data Exch. Line Def Code", "Column No.", Name, "Data Type", "Data Format", "Data Formatting Culture", Path, "Negative-Sign Identifier", Constant);
        ColumnDef.SetRange("Data Exch. Def Code", DefCode);
        if ColumnDef.FindSet() then
            repeat
                Clear(Row);
                Row.Add('lineDef', ColumnDef."Data Exch. Line Def Code");
                Row.Add('columnNo', ColumnDef."Column No.");
                Row.Add('name', ColumnDef.Name);
                Row.Add('dataType', DataTypeName(ColumnDef));
                Row.Add('dataFormat', ColumnDef."Data Format");
                Row.Add('dataFormattingCulture', ColumnDef."Data Formatting Culture");
                Row.Add('path', ColumnDef.Path);
                Row.Add('negativeSign', ColumnDef."Negative-Sign Identifier");
                Row.Add('constant', ColumnDef.Constant);
                Rows.Add(Row);
            until ColumnDef.Next() = 0;
    end;

    local procedure MappingsToJson(DefCode: Code[20]) Rows: JsonArray
    var
        Mapping: Record "Data Exch. Mapping";
        Row: JsonObject;
    begin
        Mapping.ReadIsolation := IsolationLevel::ReadCommitted;
        Mapping.SetLoadFields("Data Exch. Line Def Code", "Table ID", "Mapping Codeunit", "Pre-Mapping Codeunit", "Post-Mapping Codeunit", "Data Exch. No. Field ID", "Use as Intermediate Table");
        Mapping.SetRange("Data Exch. Def Code", DefCode);
        if Mapping.FindSet() then
            repeat
                Clear(Row);
                Row.Add('lineDef', Mapping."Data Exch. Line Def Code");
                Row.Add('tableId', Mapping."Table ID");
                Row.Add('tableName', TableName(Mapping."Table ID"));
                Row.Add('mappingCodeunit', CodeunitName(Mapping."Mapping Codeunit"));
                Row.Add('preMappingCodeunit', CodeunitName(Mapping."Pre-Mapping Codeunit"));
                Row.Add('postMappingCodeunit', CodeunitName(Mapping."Post-Mapping Codeunit"));
                Row.Add('dataExchNoFieldId', Mapping."Data Exch. No. Field ID");
                Row.Add('useAsIntermediateTable', Mapping."Use as Intermediate Table");
                Row.Add('fieldMappings', FieldMappingsToJson(DefCode, Mapping."Data Exch. Line Def Code", Mapping."Table ID"));
                Rows.Add(Row);
            until Mapping.Next() = 0;
    end;

    local procedure FieldMappingsToJson(DefCode: Code[20]; LineDefCode: Code[20]; TableId: Integer) Rows: JsonArray
    var
        FieldMapping: Record "Data Exch. Field Mapping";
        Row: JsonObject;
    begin
        FieldMapping.ReadIsolation := IsolationLevel::ReadCommitted;
        FieldMapping.SetLoadFields("Column No.", "Field ID", Optional, Multiplier, "Overwrite Value", "Transformation Rule");
        FieldMapping.SetRange("Data Exch. Def Code", DefCode);
        FieldMapping.SetRange("Data Exch. Line Def Code", LineDefCode);
        FieldMapping.SetRange("Table ID", TableId);
        if FieldMapping.FindSet() then
            repeat
                Clear(Row);
                Row.Add('columnNo', FieldMapping."Column No.");
                Row.Add('fieldId', FieldMapping."Field ID");
                Row.Add('fieldName', TableFieldName(TableId, FieldMapping."Field ID"));
                Row.Add('optional', FieldMapping.Optional);
                Row.Add('multiplier', FieldMapping.Multiplier);
                Row.Add('overwriteValue', FieldMapping."Overwrite Value");
                Row.Add('transformationRule', FieldMapping."Transformation Rule");
                Rows.Add(Row);
            until FieldMapping.Next() = 0;
    end;

    local procedure TypeToJson(DataExchType: Record "Data Exchange Type") Row: JsonObject
    var
        DataExchDef: Record "Data Exch. Def";
        TypeName: Text;
        UserFeedback: Text;
        Validation: Text;
        DataHandling: Text;
    begin
        DataExchDef.SetLoadFields(Type, "User Feedback Codeunit", "Validation Codeunit", "Data Handling Codeunit");
        if DataExchDef.Get(DataExchType."Data Exch. Def. Code") then begin
            TypeName := EnumName(DataExchDef.Type);
            UserFeedback := CodeunitName(DataExchDef."User Feedback Codeunit");
            Validation := CodeunitName(DataExchDef."Validation Codeunit");
            DataHandling := CodeunitName(DataExchDef."Data Handling Codeunit");
        end;
        Row.Add('code', DataExchType.Code);
        Row.Add('description', DataExchType.Description);
        Row.Add('dataExchDefCode', DataExchType."Data Exch. Def. Code");
        Row.Add('userFeedbackCodeunit', UserFeedback);
        Row.Add('validationCodeunit', Validation);
        Row.Add('dataHandlingCodeunit', DataHandling);
        Row.Add('type', TypeName);
    end;

    local procedure TypesUsingDefinition(DefCode: Code[20]) Codes: JsonArray
    var
        DataExchType: Record "Data Exchange Type";
    begin
        DataExchType.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchType.SetLoadFields(Code);
        DataExchType.SetRange("Data Exch. Def. Code", DefCode);
        if DataExchType.FindSet() then
            repeat
                Codes.Add(DataExchType.Code);
            until DataExchType.Next() = 0;
    end;

    local procedure EntryToJson(DataExch: Record "Data Exch.") Row: JsonObject
    var
        CreatedAt: Text;
    begin
        if DataExch.SystemCreatedAt <> 0DT then
            CreatedAt := Format(DataExch.SystemCreatedAt, 0, 9);
        Row.Add('entryNo', DataExch."Entry No.");
        Row.Add('dataExchDefCode', DataExch."Data Exch. Def Code");
        Row.Add('dataExchLineDefCode', DataExch."Data Exch. Line Def Code");
        Row.Add('fileName', DataExch."File Name");
        Row.Add('createdAt', CreatedAt);
        Row.Add('hasFileContent', DataExch."File Content".HasValue());
        Row.Add('fieldCount', FieldCount(DataExch."Entry No."));
        Row.Add('incomingEntryNo', DataExch."Incoming Entry No.");
        Row.Add('relatedRecord', Format(DataExch."Related Record"));
    end;

    local procedure FieldPage(DataExch: Record "Data Exch."; Skip: Integer; Take: Integer) Rows: JsonArray
    var
        DataExchField: Record "Data Exch. Field";
        TotalCount: Integer;
    begin
        DataExchField.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchField.SetLoadFields("Line No.", "Column No.", Value, "Value BLOB", "Data Exch. Line Def Code");
        DataExchField.SetRange("Data Exch. No.", DataExch."Entry No.");
        TotalCount := DataExchField.Count();
        if (Skip >= TotalCount) or (not DataExchField.FindSet()) then
            exit;
        if Skip > 0 then
            DataExchField.Next(Skip);
        repeat
            Rows.Add(FieldToJson(DataExch, DataExchField));
            if Rows.Count() >= Take then
                break;
        until DataExchField.Next() = 0;
    end;

    local procedure FieldToJson(DataExch: Record "Data Exch."; DataExchField: Record "Data Exch. Field") Row: JsonObject
    begin
        Row.Add('lineNo', DataExchField."Line No.");
        Row.Add('columnNo', DataExchField."Column No.");
        Row.Add('columnName', ColumnName(DataExch."Data Exch. Def Code", DataExchField."Data Exch. Line Def Code", DataExchField."Column No."));
        Row.Add('value', DataExchField.GetValue());
        Row.Add('dataExchLineDefCode', DataExchField."Data Exch. Line Def Code");
    end;

    local procedure FieldCount(EntryNo: Integer): Integer
    var
        DataExchField: Record "Data Exch. Field";
    begin
        DataExchField.SetRange("Data Exch. No.", EntryNo);
        exit(DataExchField.Count());
    end;

    local procedure ColumnName(DefCode: Code[20]; LineDefCode: Code[20]; ColumnNo: Integer): Text
    var
        ColumnDef: Record "Data Exch. Column Def";
    begin
        ColumnDef.SetLoadFields(Name);
        if ColumnDef.Get(DefCode, LineDefCode, ColumnNo) then
            exit(ColumnDef.Name);
        exit('');
    end;

    local procedure FileContentLength(var DataExch: Record "Data Exch."): Integer
    var
        InStream: InStream;
    begin
        DataExch.CalcFields("File Content");
        if not DataExch."File Content".HasValue() then
            exit(0);
        DataExch."File Content".CreateInStream(InStream);
        exit(InStream.Length);
    end;

    local procedure FileContentBase64(var DataExch: Record "Data Exch."): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
        InStream: InStream;
    begin
        DataExch.CalcFields("File Content");
        if not DataExch."File Content".HasValue() then
            exit('');
        DataExch."File Content".CreateInStream(InStream);
        exit(Base64Convert.ToBase64(InStream));
    end;

    local procedure MaxInlineBytes(): Integer
    begin
        exit(1048576);
    end;

    local procedure RespondSuccess(var Argument: Record "Message Argument ori"; DataObject: JsonObject)
    var
        ResponseJson: JsonObject;
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('data', DataObject);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := 'text/json';
    end;

    local procedure RespondIfErrors(var Argument: Record "Message Argument ori"): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        exit(Reader.RespondIfErrors(Argument));
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; MaximumLength: Integer; var TextValue: Text): Boolean
    var
        Token: JsonToken;
        Written: Text;
    begin
        Clear(TextValue);
        if not RequestJson.Get(ParameterName, Token) then begin
            if not Required then
                exit(true);
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParamErr, ParameterName), ParameterName, MissingValueLbl, TextExpectedLbl, StrSubstNo(SendRequiredLbl, ParameterName));
            exit(false);
        end;
        Token.WriteTo(Written);
        if not Written.StartsWith('"') then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TextParamErr, ParameterName), ParameterName, Written, TextExpectedLbl, StrSubstNo(SendTextLbl, ParameterName));
            exit(false);
        end;
        TextValue := Token.AsValue().AsText();
        if Required and (TextValue = '') then begin
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParamErr, ParameterName), ParameterName, EmptyValueLbl, TextExpectedLbl, StrSubstNo(SendRequiredLbl, ParameterName));
            exit(false);
        end;
        if (MaximumLength > 0) and (StrLen(TextValue) > MaximumLength) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(CodeLengthErr, ParameterName, MaximumLength), ParameterName, TextValue, StrSubstNo(CodeLengthExpectedLbl, MaximumLength), ShortenCodeLbl);
            Clear(TextValue);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; DefaultValue: Boolean; var BooleanValue: Boolean)
    var
        Token: JsonToken;
        Written: Text;
    begin
        BooleanValue := DefaultValue;
        if not RequestJson.Get(ParameterName, Token) then
            exit;
        Token.WriteTo(Written);
        case Written of
            'true':
                BooleanValue := true;
            'false':
                BooleanValue := false;
            else
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(BooleanParamErr, ParameterName), ParameterName, Written, BooleanExpectedLbl, StrSubstNo(SendBooleanLbl, ParameterName));
        end;
    end;

    local procedure ReadPaging(var Argument: Record "Message Argument ori"; RequestJson: JsonObject)
    var
        Parsed: Integer;
    begin
        ReadInteger(Argument, RequestJson, 'skip', false, 0, Parsed);
        Clear(Parsed);
        ReadInteger(Argument, RequestJson, 'take', false, 0, Parsed);
        if Parsed > 1000 then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, PagingLimitErr, 'take', Format(Parsed, 0, 9), PagingExpectedLbl, StrSubstNo(SendIntegerLbl, 'take'));
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; Minimum: Integer; var IntegerValue: Integer)
    var
        Token: JsonToken;
        Written: Text;
        Expected: Text;
    begin
        if Minimum = 0 then
            Expected := NonNegativeLbl
        else
            Expected := PositiveIntegerLbl;
        if not RequestJson.Get(ParameterName, Token) then begin
            if Required then
                Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParamErr, ParameterName), ParameterName, MissingValueLbl, Expected, StrSubstNo(SendRequiredLbl, ParameterName));
            exit;
        end;
        Token.WriteTo(Written);
        // Preserve digit-string paging values accepted by Foundation as well as JSON integers.
        if Token.IsValue() then
            if not Token.AsValue().IsNull() then
                Written := Token.AsValue().AsText();
        if IsIntegerText(Written) then
            if Evaluate(IntegerValue, Written, 9) then begin
                if IntegerValue < Minimum then
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(IntegerParamErr, ParameterName), ParameterName, Written, Expected, StrSubstNo(SendIntegerLbl, ParameterName));
                exit;
            end;
        Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(IntegerParamErr, ParameterName), ParameterName, Written, Expected, StrSubstNo(SendIntegerLbl, ParameterName));
    end;

    local procedure IsIntegerText(Written: Text): Boolean
    var
        Index: Integer;
        FirstDigit: Integer;
    begin
        FirstDigit := 1;
        if Written.StartsWith('-') then
            FirstDigit := 2;
        if StrLen(Written) < FirstDigit then
            exit(false);
        for Index := FirstDigit to StrLen(Written) do
            if not (Written[Index] in ['0' .. '9']) then
                exit(false);
        exit(true);
    end;

    local procedure ReadFilterDateTime(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; var DateTimeValue: DateTime; var IsPresent: Boolean)
    var
        TextValue: Text;
        ParsedDate: Date;
        Valid: Boolean;
    begin
        IsPresent := false;
        Clear(DateTimeValue);
        if not ReadText(Argument, RequestJson, ParameterName, false, 0, TextValue) then
            exit;
        if TextValue = '' then
            exit;
        if TextValue.Contains('T') or TextValue.Contains(':') then
            Valid := Evaluate(DateTimeValue, TextValue, 9)
        else begin
            Valid := Evaluate(ParsedDate, TextValue, 9);
            if Valid then
                if ParameterName = 'dateTo' then
                    DateTimeValue := CreateDateTime(ParsedDate, 235959T)
                else
                    DateTimeValue := CreateDateTime(ParsedDate, 0T);
        end;
        IsPresent := Valid and (DateTimeValue <> 0DT);
        if not IsPresent then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(DateParamErr, ParameterName), ParameterName, TextValue, DateExpectedLbl, StrSubstNo(SendDateLbl, ParameterName));
    end;

    local procedure EnumNames(DefType: Enum "Data Exchange Definition Type") Result: Text
    var
        TypeName: Text;
    begin
        foreach TypeName in DefType.Names() do begin
            if Result <> '' then
                Result += ', ';
            Result += TypeName;
        end;
    end;

    local procedure DirectionIsValid(DirectionText: Text): Boolean
    begin
        if DirectionText = '' then
            exit(true);
        exit((UpperCase(DirectionText) = 'IMPORT') or (UpperCase(DirectionText) = 'EXPORT'));
    end;

    local procedure TypeMatchesDirection(DefType: Enum "Data Exchange Definition Type"; DirectionText: Text): Boolean
    var
        Name: Text;
    begin
        if DirectionText = '' then
            exit(true);
        Name := EnumName(DefType);
        if UpperCase(DirectionText) = 'IMPORT' then
            exit(Name.Contains('Import'));
        exit(Name.Contains('Export'));
    end;

    local procedure TryTypeFromName(TypeName: Text; var DefType: Enum "Data Exchange Definition Type"): Boolean
    var
        Ordinals: List of [Integer];
        Names: List of [Text];
        Index: Integer;
    begin
        Ordinals := DefType.Ordinals();
        Names := DefType.Names();
        for Index := 1 to Names.Count() do
            if UpperCase(Names.Get(Index)) = UpperCase(TypeName) then begin
                DefType := Enum::"Data Exchange Definition Type".FromInteger(Ordinals.Get(Index));
                exit(true);
            end;
        exit(false);
    end;

    local procedure EnumName(DefType: Enum "Data Exchange Definition Type"): Text
    var
        Ordinals: List of [Integer];
        Names: List of [Text];
        Index: Integer;
    begin
        Ordinals := DefType.Ordinals();
        Names := DefType.Names();
        Index := Ordinals.IndexOf(DefType.AsInteger());
        if Index = 0 then
            exit('');
        exit(Names.Get(Index));
    end;

    local procedure FileTypeName(DataExchDef: Record "Data Exch. Def"): Text
    begin
        case DataExchDef."File Type" of
            DataExchDef."File Type"::Xml:
                exit('Xml');
            DataExchDef."File Type"::"Variable Text":
                exit('Variable Text');
            DataExchDef."File Type"::"Fixed Text":
                exit('Fixed Text');
            DataExchDef."File Type"::Json:
                exit('Json');
            else
                exit('');
        end;
    end;

    local procedure DataTypeName(ColumnDef: Record "Data Exch. Column Def"): Text
    begin
        case ColumnDef."Data Type" of
            ColumnDef."Data Type"::Text:
                exit('Text');
            ColumnDef."Data Type"::Date:
                exit('Date');
            ColumnDef."Data Type"::Decimal:
                exit('Decimal');
            ColumnDef."Data Type"::DateTime:
                exit('DateTime');
            ColumnDef."Data Type"::Boolean:
                exit('Boolean');
            else
                exit('');
        end;
    end;

    local procedure CodeunitName(CodeunitId: Integer): Text
    var
        AllObj: Record AllObjWithCaption;
    begin
        exit(LookupObjectName(AllObj."Object Type"::Codeunit, CodeunitId));
    end;

    local procedure XmlPortName(XmlPortId: Integer): Text
    var
        AllObj: Record AllObjWithCaption;
    begin
        exit(LookupObjectName(AllObj."Object Type"::XMLport, XmlPortId));
    end;

    local procedure TableName(TableId: Integer): Text
    var
        AllObj: Record AllObjWithCaption;
    begin
        exit(LookupObjectName(AllObj."Object Type"::Table, TableId));
    end;

    local procedure LookupObjectName(ObjectType: Option; ObjectId: Integer): Text
    var
        AllObj: Record AllObjWithCaption;
    begin
        if ObjectId = 0 then
            exit('');
        AllObj.SetLoadFields("Object Name");
        if AllObj.Get(ObjectType, ObjectId) then
            exit(AllObj."Object Name");
        exit('');
    end;

    local procedure TableFieldName(TableId: Integer; FieldId: Integer): Text
    var
        FieldRec: Record "Field";
    begin
        if (TableId = 0) or (FieldId = 0) then
            exit('');
        FieldRec.SetLoadFields(FieldName);
        if FieldRec.Get(TableId, FieldId) then
            exit(FieldRec.FieldName);
        exit('');
    end;
}
