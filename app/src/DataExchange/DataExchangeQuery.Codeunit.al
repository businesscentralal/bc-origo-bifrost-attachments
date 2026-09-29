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
        MissingParamErr: Label 'Missing required ''%1'' in the request.', Comment = '%1 = parameter name', Locked = true;
        UnknownDefErr: Label 'No Data Exch. Def exists for code ''%1''.', Comment = '%1 = definition code', Locked = true;
        UnknownEntryErr: Label 'Data Exch. entry %1 was not found.', Comment = '%1 = entry no.', Locked = true;
        UnknownTypeErr: Label 'Unknown Data Exch. Def type ''%1''.', Comment = '%1 = type name', Locked = true;
        UnknownDirectionErr: Label 'direction must be Import or Export.', Locked = true;
        BooleanParamErr: Label '''%1'' must be a boolean.', Comment = '%1 = parameter name', Locked = true;
        IntegerParamErr: Label '''%1'' must be an integer.', Comment = '%1 = parameter name', Locked = true;
        DateParamErr: Label '''%1'' must be an invariant date (YYYY-MM-DD) or datetime.', Comment = '%1 = parameter name', Locked = true;
        FileTooLargeErr: Label 'File content is %1 bytes, which is above the 1 MB limit for includeFileContent.', Comment = '%1 = byte length', Locked = true;
        IntegerMissing: Boolean;

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
        TypeText := GetText(RequestJson, 'type');
        DirectionText := GetText(RequestJson, 'direction');
        if not DirectionIsValid(DirectionText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, UnknownDirectionErr, 'direction', DirectionText, 'Import or Export', '');
            exit;
        end;
        if TypeText <> '' then begin
            if not TryTypeFromName(TypeText, DefType) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnknownTypeErr, TypeText), 'type', TypeText, '', '');
                exit;
            end;
            FilterByType := true;
        end;

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
        CodeText := GetText(RequestJson, 'code');
        if CodeText = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParamErr, 'code'), 'code', '', '', '');
            exit;
        end;

        DataExchDef.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExchDef.SetLoadFields(Code, Name, Type, "File Type", "Reading/Writing Codeunit", "Reading/Writing XMLport", "Ext. Data Handling Codeunit");
        if not DataExchDef.Get(CopyStr(CodeText, 1, MaxStrLen(DataExchDef.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownDefErr, CodeText), 'code', CodeText, '', '');
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
        Argument.EvaluateSkipTake(RequestJson, Skip, Take);
        if not TryReadFilterDateTime(RequestJson, 'dateFrom', DateFrom, HasFrom) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(DateParamErr, 'dateFrom'), 'dateFrom', '', 'YYYY-MM-DD', '');
            exit;
        end;
        if not TryReadFilterDateTime(RequestJson, 'dateTo', DateTo, HasTo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(DateParamErr, 'dateTo'), 'dateTo', '', 'YYYY-MM-DD', '');
            exit;
        end;

        DefCode := GetText(RequestJson, 'dataExchDefCode');
        DataExch.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExch.SetLoadFields("Entry No.", "File Name", "File Content", "Data Exch. Def Code", "Data Exch. Line Def Code", "Incoming Entry No.", "Related Record", SystemCreatedAt);
        if DefCode <> '' then
            DataExch.SetRange("Data Exch. Def Code", CopyStr(DefCode, 1, MaxStrLen(DataExch."Data Exch. Def Code")));
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
        Argument.EvaluateSkipTake(RequestJson, Skip, Take);
        if not TryReadBoolean(RequestJson, 'includeFields', true, IncludeFields) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(BooleanParamErr, 'includeFields'), 'includeFields', '', 'true or false', '');
            exit;
        end;
        if not TryReadBoolean(RequestJson, 'includeFileContent', false, IncludeFileContent) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(BooleanParamErr, 'includeFileContent'), 'includeFileContent', '', 'true or false', '');
            exit;
        end;
        if not TryReadRequiredInteger(RequestJson, 'entryNo', EntryNo) then begin
            if IntegerMissing then
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParamErr, 'entryNo'), 'entryNo', '', '', '')
            else
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(IntegerParamErr, 'entryNo'), 'entryNo', '', 'integer', '');
            exit;
        end;

        DataExch.ReadIsolation := IsolationLevel::ReadCommitted;
        DataExch.SetLoadFields("Entry No.", "File Name", "File Content", "Data Exch. Def Code", "Data Exch. Line Def Code", "Incoming Entry No.", "Related Record", SystemCreatedAt);
        if not DataExch.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownEntryErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), '', '');
            exit;
        end;

        DataObject := EntryToJson(DataExch);
        if IncludeFileContent then begin
            ContentLength := FileContentLength(DataExch);
            if ContentLength > MaxInlineBytes() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, StrSubstNo(FileTooLargeErr, ContentLength), 'includeFileContent', Format(ContentLength, 0, 9), 'at most 1 MB', '');
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

    local procedure GetText(RequestJson: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure TryReadBoolean(RequestJson: JsonObject; PropertyName: Text; DefaultValue: Boolean; var Value: Boolean): Boolean
    var
        Token: JsonToken;
        Written: Text;
    begin
        Value := DefaultValue;
        if not RequestJson.Get(PropertyName, Token) then
            exit(true);
        if not Token.IsValue() or Token.AsValue().IsNull() then
            exit(true);
        Token.WriteTo(Written);
        if Written = 'true' then begin
            Value := true;
            exit(true);
        end;
        if Written = 'false' then begin
            Value := false;
            exit(true);
        end;
        exit(false);
    end;

    local procedure TryReadRequiredInteger(RequestJson: JsonObject; PropertyName: Text; var Value: Integer): Boolean
    var
        Token: JsonToken;
        Written: Text;
    begin
        IntegerMissing := false;
        if not RequestJson.Get(PropertyName, Token) or (not Token.IsValue()) or Token.AsValue().IsNull() then begin
            IntegerMissing := true;
            exit(false);
        end;
        Token.WriteTo(Written);
        if not IsIntegerText(Written) then
            exit(false);
        exit(Evaluate(Value, Written, 9));
    end;

    local procedure IsIntegerText(Written: Text): Boolean
    var
        Index: Integer;
        Digit: Text;
    begin
        if Written = '' then
            exit(false);
        if Written.StartsWith('-') then
            Written := CopyStr(Written, 2);
        if Written = '' then
            exit(false);
        for Index := 1 to StrLen(Written) do begin
            Digit := CopyStr(Written, Index, 1);
            if (Digit < '0') or (Digit > '9') then
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryReadFilterDateTime(RequestJson: JsonObject; PropertyName: Text; var Value: DateTime; var IsPresent: Boolean): Boolean
    var
        Token: JsonToken;
        TextValue: Text;
        ParsedDate: Date;
    begin
        IsPresent := false;
        Value := 0DT;
        if not RequestJson.Get(PropertyName, Token) then
            exit(true);
        if not Token.IsValue() or Token.AsValue().IsNull() then
            exit(true);
        TextValue := Token.AsValue().AsText();
        if TextValue = '' then
            exit(true);
        if TextValue.Contains('T') or TextValue.Contains(':') then begin
            if not Evaluate(Value, TextValue, 9) then
                exit(false);
            IsPresent := true;
            exit(true);
        end;
        if not Evaluate(ParsedDate, TextValue, 9) then
            exit(false);
        if PropertyName = 'dateTo' then
            Value := CreateDateTime(ParsedDate, 235959T)
        else
            Value := CreateDateTime(ParsedDate, 0T);
        IsPresent := true;
        exit(true);
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
