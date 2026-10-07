namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.Reflection;

/// <summary>
/// Phase 0 discovery tests: a seeded definition renders in order, entry fields page,
/// file content above 1 MB is refused, an empty type list returns count 0, and
/// <c>Data.Records.Set</c> on <c>Data Exch.</c> is blocked with the dedicated-type hint.
/// </summary>
codeunit 96213 "Data Exch Discovery Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";
        DefCodeTok: Label 'BIFT-DE0', Locked = true;
        LineATok: Label 'LINEA', Locked = true;
        LineBTok: Label 'LINEB', Locked = true;
        Type1Tok: Label 'BIFT-T1', Locked = true;
        Type2Tok: Label 'BIFT-T2', Locked = true;
        SmallFileTok: Label 'bift-phase0.txt', Locked = true;
        BigFileTok: Label 'bift-phase0-big.txt', Locked = true;
        WriteHintTok: Label 'DataExchange.Import.Run / Storage.Upload.CommitToDataExchange', Locked = true;

    [Test]
    procedure RepairedBindings_ResolveTheirOwnTargetTables()
    var
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Interface ori";
    begin
        // [SCENARIO] Compile-repair regression: enum collisions must not redirect requests.
        // Time: no date dependency. Risk: message-type interface resolution.
        // [GIVEN] Each affected public message name resolves through the production enum.
        // [WHEN] Its production implementation is resolved without calling an external service.
        // [THEN] Import and export address entries; type set and definition delete address their own tables.
        MessageType := MessageType::"DataExchange.Import.Run";
        Implementation := MessageType;
        LibraryAssert.AreEqual(Database::"Data Exch.", Implementation.GetFilterTableNo(), 'Import must resolve to the entry implementation.');
        MessageType := MessageType::"DataExchange.Type.Set";
        Implementation := MessageType;
        LibraryAssert.AreEqual(Database::"Data Exchange Type", Implementation.GetFilterTableNo(), 'Type set must resolve to the type implementation.');
        MessageType := MessageType::"DataExchange.Definition.Delete";
        Implementation := MessageType;
        LibraryAssert.AreEqual(Database::"Data Exch. Def", Implementation.GetFilterTableNo(), 'Definition delete must resolve to the definition implementation.');
        MessageType := MessageType::"DataExchange.Export.Run";
        Implementation := MessageType;
        LibraryAssert.AreEqual(Database::"Data Exch.", Implementation.GetFilterTableNo(), 'Export must resolve to the entry implementation.');
    end;

    [Test]
    procedure DefinitionListAndGet_RenderSeededDefinitionInOrder()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DataObject: JsonObject;
        Definitions: JsonArray;
        Definition: JsonObject;
        LineDefs: JsonArray;
        ColumnDefs: JsonArray;
        Mappings: JsonArray;
        FieldMappings: JsonArray;
        UsedBy: JsonArray;
    begin
        // [SCENARIO] AC01/AC02: a seeded definition is listed with the types that use it,
        // and Get returns line defs, columns and field mappings complete and ordered.
        SeedDefinition();

        RequestJson.Add('code', DefCodeTok);
        ExecuteType(TempArgument, TempArgument."Type"::"DataExchange.Definition.Get", RequestJson);
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Definition.Get should succeed.');
        DataObject := ReadData(ResponseJson);
        LibraryAssert.AreEqual(DefCodeTok, ReadObjText(DataObject, 'code'), 'code');
        LibraryAssert.AreEqual('Phase 0 seed', ReadObjText(DataObject, 'name'), 'name');
        LibraryAssert.AreEqual('Generic Import', ReadObjText(DataObject, 'type'), 'type');
        LibraryAssert.AreEqual('Variable Text', ReadObjText(DataObject, 'fileType'), 'fileType');
        LibraryAssert.AreEqual('Type Helper', ReadObjText(DataObject, 'readingWritingCodeunit'), 'reading codeunit name');
        LibraryAssert.AreEqual('', ReadObjText(DataObject, 'readingWritingXmlPort'), 'xmlport empty');
        LibraryAssert.AreEqual('Type Helper', ReadObjText(DataObject, 'extDataHandlingCodeunit'), 'ext data handling');
        LibraryAssert.AreEqual(2, ReadObjInt(DataObject, 'lineDefCount'), 'lineDefCount');
        LibraryAssert.AreEqual(2, ReadObjInt(DataObject, 'mappingCount'), 'mappingCount');

        UsedBy := ReadArray(DataObject, 'usedByDataExchangeTypes');
        LibraryAssert.AreEqual(2, UsedBy.Count(), 'two types reference the definition');
        LibraryAssert.AreEqual(Type1Tok, ReadArrayText(UsedBy, 0), 'types ordered by code, first');
        LibraryAssert.AreEqual(Type2Tok, ReadArrayText(UsedBy, 1), 'types ordered by code, second');

        LineDefs := ReadArray(DataObject, 'lineDefs');
        LibraryAssert.AreEqual(2, LineDefs.Count(), 'two line defs');
        Definition := ReadRow(LineDefs, 0);
        LibraryAssert.AreEqual(LineATok, ReadObjText(Definition, 'code'), 'line defs ordered by code');
        LibraryAssert.AreEqual('Ntry', ReadObjText(Definition, 'dataLineTag'), 'dataLineTag');
        LibraryAssert.AreEqual('urn:test', ReadObjText(Definition, 'namespace'), 'namespace');
        LibraryAssert.AreEqual(LineBTok, ReadObjText(ReadRow(LineDefs, 1), 'code'), 'second line def');

        ColumnDefs := ReadArray(DataObject, 'columnDefs');
        LibraryAssert.AreEqual(2, ColumnDefs.Count(), 'two columns');
        Definition := ReadRow(ColumnDefs, 0);
        LibraryAssert.AreEqual(1, ReadObjInt(Definition, 'columnNo'), 'columns ordered by column no.');
        LibraryAssert.AreEqual('Amount', ReadObjText(Definition, 'name'), 'column name');
        LibraryAssert.AreEqual('Decimal', ReadObjText(Definition, 'dataType'), 'dataType');
        LibraryAssert.AreEqual('0.00', ReadObjText(Definition, 'dataFormat'), 'dataFormat');
        LibraryAssert.AreEqual('en-US', ReadObjText(Definition, 'dataFormattingCulture'), 'culture');
        LibraryAssert.AreEqual('/Amt', ReadObjText(Definition, 'path'), 'path');
        LibraryAssert.AreEqual('-', ReadObjText(Definition, 'negativeSign'), 'negativeSign');
        LibraryAssert.AreEqual(2, ReadObjInt(ReadRow(ColumnDefs, 1), 'columnNo'), 'second column');

        Mappings := ReadArray(DataObject, 'mappings');
        LibraryAssert.AreEqual(2, Mappings.Count(), 'two mappings');
        Definition := ReadRow(Mappings, 0);
        LibraryAssert.AreEqual(LineATok, ReadObjText(Definition, 'lineDef'), 'mappings ordered by line def');
        LibraryAssert.AreEqual(Database::Customer, ReadObjInt(Definition, 'tableId'), 'tableId');
        LibraryAssert.AreEqual('Customer', ReadObjText(Definition, 'tableName'), 'tableName');
        LibraryAssert.AreEqual('Type Helper', ReadObjText(Definition, 'mappingCodeunit'), 'mapping codeunit');
        LibraryAssert.AreEqual('', ReadObjText(Definition, 'preMappingCodeunit'), 'pre-mapping empty');
        LibraryAssert.IsTrue(ReadObjBool(Definition, 'useAsIntermediateTable'), 'intermediate flag');
        FieldMappings := ReadArray(Definition, 'fieldMappings');
        LibraryAssert.AreEqual(2, FieldMappings.Count(), 'two field mappings');
        Definition := ReadRow(FieldMappings, 0);
        LibraryAssert.AreEqual(1, ReadObjInt(Definition, 'columnNo'), 'field mappings ordered by column');
        LibraryAssert.AreEqual(1, ReadObjInt(Definition, 'fieldId'), 'fieldId');
        LibraryAssert.AreEqual('No.', ReadObjText(Definition, 'fieldName'), 'fieldName');
        LibraryAssert.AreEqual(2.0, ReadObjDec(Definition, 'multiplier'), 'multiplier');

        Clear(RequestJson);
        RequestJson.Add('type', 'Generic Import');
        RequestJson.Add('direction', 'Import');
        ExecuteType(TempArgument, TempArgument."Type"::"DataExchange.Definition.List", RequestJson);
        ResponseJson := TempArgument.GetResponseJson();
        LibraryAssert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'Definition.List should succeed.');
        Definitions := ReadArray(ReadData(ResponseJson), 'definitions');
        LibraryAssert.IsTrue(ArrayHasCode(Definitions, DefCodeTok), 'the seeded definition is in the filtered list');
    end;

    [Test]
    procedure TypeList_EmptyCompany_ReturnsCountZero()
    var
        DataExchType: Record "Data Exchange Type";
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
        DataObject: JsonObject;
    begin
        // [SCENARIO] AC03: a company with no Data Exchange Type rows returns count 0 and does not error.
        DataExchType.DeleteAll();
        ExecuteType(TempArgument, TempArgument."Type"::"DataExchange.Type.List", RequestJson);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Type.List should succeed.');
        DataObject := ReadData(TempArgument.GetResponseJson());
        LibraryAssert.AreEqual(0, ReadObjInt(DataObject, 'count'), 'count');
        LibraryAssert.AreEqual(0, ReadArray(DataObject, 'types').Count(), 'types');
    end;

    [Test]
    procedure EntryGet_PagesFields_AndRefusesFileAboveOneMegabyte()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
        DataObject: JsonObject;
        Fields: JsonArray;
        SmallEntryNo: Integer;
        BigEntryNo: Integer;
    begin
        // [SCENARIO] AC04: fields are paged, and includeFileContent above 1 MB returns a clear error.
        SeedDefinition();
        SmallEntryNo := InsertEntry(SmallFileTok, 'hello', false);
        BigEntryNo := InsertEntry(BigFileTok, '', true);

        RequestJson.Add('entryNo', SmallEntryNo);
        RequestJson.Add('includeFields', true);
        RequestJson.Add('skip', 1);
        RequestJson.Add('take', 1);
        ExecuteType(TempArgument, TempArgument."Type"::"DataExchange.Entry.Get", RequestJson);
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Entry.Get should succeed.');
        DataObject := ReadData(TempArgument.GetResponseJson());
        LibraryAssert.AreEqual(3, ReadObjInt(DataObject, 'fieldCount'), 'fieldCount is the unpaged total');
        LibraryAssert.AreEqual(1, ReadObjInt(DataObject, 'skip'), 'skip');
        LibraryAssert.AreEqual(1, ReadObjInt(DataObject, 'take'), 'take');
        LibraryAssert.IsFalse(DataObject.Contains('contentBase64'), 'file content stays out unless asked for');
        Fields := ReadArray(DataObject, 'fields');
        LibraryAssert.AreEqual(1, Fields.Count(), 'one field on the page');
        LibraryAssert.AreEqual('second', ReadObjText(ReadRow(Fields, 0), 'value'), 'skip 1 is the second field');
        LibraryAssert.AreEqual('Amount 2', ReadObjText(ReadRow(Fields, 0), 'columnName'), 'column name');

        Clear(RequestJson);
        RequestJson.Add('entryNo', SmallEntryNo);
        RequestJson.Add('includeFields', false);
        RequestJson.Add('includeFileContent', true);
        ExecuteType(TempArgument, TempArgument."Type"::"DataExchange.Entry.Get", RequestJson);
        DataObject := ReadData(TempArgument.GetResponseJson());
        LibraryAssert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'small file content should succeed.');
        LibraryAssert.IsFalse(DataObject.Contains('fields'), 'includeFields false omits fields');
        LibraryAssert.AreEqual(5, ReadObjInt(DataObject, 'contentLength'), 'contentLength');
        LibraryAssert.AreEqual('aGVsbG8=', ReadObjText(DataObject, 'contentBase64'), 'contentBase64');
        LibraryAssert.IsTrue(ReadObjBool(DataObject, 'hasFileContent'), 'hasFileContent');
        LibraryAssert.AreEqual(42, ReadObjInt(DataObject, 'incomingEntryNo'), 'incomingEntryNo');

        Clear(RequestJson);
        RequestJson.Add('entryNo', BigEntryNo);
        RequestJson.Add('includeFileContent', true);
        ExecuteType(TempArgument, TempArgument."Type"::"DataExchange.Entry.Get", RequestJson);
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'oversized content is an error.');
        LibraryAssert.IsTrue(
            ReadText(TempArgument.GetResponseJson(), 'error').Contains('above the 1 MB limit'),
            'the error should say the file is above the 1 MB limit.');
    end;

    [Test]
    procedure DataRecordsSet_OnDataExch_ReturnsHint()
    var
        TempArgument: Record "Message Argument ori";
        SetRequest: JsonObject;
        RecordObject: JsonObject;
        Fields: JsonObject;
        DataArray: JsonArray;
        ErrorText: Text;
    begin
        // [SCENARIO] AC05: Data.Records.Set on Data Exch. is blocked and names the dedicated writers.
        Fields.Add('File Name', 'hack.txt');
        RecordObject.Add('fields', Fields);
        DataArray.Add(RecordObject);
        SetRequest.Add('tableName', 'Data Exch.');
        SetRequest.Add('data', DataArray);

        ExecuteType(TempArgument, TempArgument."Type"::"Data.Records.Set", SetRequest);

        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'status');
        ErrorText := ReadText(TempArgument.GetResponseJson(), 'error');
        LibraryAssert.IsTrue(ErrorText.Contains('cannot be written'), 'restricted write text');
        LibraryAssert.IsTrue(ErrorText.EndsWith('Use ' + WriteHintTok + '.'), 'hint suffix');
        LibraryAssert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Data Exch."), 'reads stay allowed');
    end;

    [Test]
    procedure NegativeSkip_AndMissingCode_ReturnErrors()
    var
        TempArgument: Record "Message Argument ori";
        RequestJson: JsonObject;
    begin
        // [SCENARIO] A missing definition code is status Error, and a negative skip is rejected.
        ExecuteType(TempArgument, TempArgument."Type"::"DataExchange.Definition.Get", RequestJson);
        LibraryAssert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'missing code');
        LibraryAssert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'error').Contains('code'), 'the error names code');

        Clear(RequestJson);
        RequestJson.Add('entryNo', 1);
        RequestJson.Add('skip', -1);
        asserterror ExecuteType(TempArgument, TempArgument."Type"::"DataExchange.Entry.Get", RequestJson);
        LibraryAssert.ExpectedError('skip must be zero or greater');
    end;

    [Test]
    procedure Help_NamesTypes_AndCarriesPaginationLimits()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        MessageType: Enum "Message Type ori";
        Markdown: Text;
    begin
        // [SCENARIO] The contract exposes the overview relationships and paged entry parameters.
        ContractMgt.GetContract(MessageType::"Help.DataExchange.Get", Contract);
        Contract.WriteTo(Markdown);
        LibraryAssert.IsTrue(Markdown.Contains('DataExchange.Definition.List'), 'overview related definitions');
        LibraryAssert.IsTrue(Markdown.Contains('DataExchange.Entry.List'), 'overview related entries');

        Clear(Contract);
        ContractMgt.GetContract(MessageType::"DataExchange.Entry.List", Contract);
        Contract.WriteTo(Markdown);
        LibraryAssert.IsTrue(Markdown.Contains('dataExchDefCode'), 'definition filter');
        LibraryAssert.IsTrue(Markdown.Contains('skip'), 'skip parameter');
        LibraryAssert.IsTrue(Markdown.Contains('take'), 'take parameter');
    end;

    local procedure SeedDefinition()
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        ColumnDef: Record "Data Exch. Column Def";
        Mapping: Record "Data Exch. Mapping";
        FieldMapping: Record "Data Exch. Field Mapping";
        DataExchType: Record "Data Exchange Type";
    begin
        if DataExchType.Get(Type1Tok) then
            DataExchType.Delete();
        if DataExchType.Get(Type2Tok) then
            DataExchType.Delete();
        if DataExchDef.Get(DefCodeTok) then
            DataExchDef.Delete(true);

        DataExchDef.Init();
        DataExchDef.Code := DefCodeTok;
        DataExchDef.Name := 'Phase 0 seed';
        DataExchDef.Type := DataExchDef.Type::"Generic Import";
        DataExchDef."File Type" := DataExchDef."File Type"::"Variable Text";
        DataExchDef."Reading/Writing Codeunit" := Codeunit::"Type Helper";
        DataExchDef."Ext. Data Handling Codeunit" := Codeunit::"Type Helper";
        DataExchDef."User Feedback Codeunit" := Codeunit::"Type Helper";
        DataExchDef."Data Handling Codeunit" := Codeunit::"Type Helper";
        DataExchDef.Insert();

        LineDef.Init();
        LineDef."Data Exch. Def Code" := DefCodeTok;
        LineDef.Code := LineBTok;
        LineDef.Name := 'Line B';
        LineDef.Insert();

        LineDef.Init();
        LineDef."Data Exch. Def Code" := DefCodeTok;
        LineDef.Code := LineATok;
        LineDef.Name := 'Line A';
        LineDef."Column Count" := 2;
        LineDef."Data Line Tag" := 'Ntry';
        LineDef.Namespace := 'urn:test';
        LineDef.Insert();

        ColumnDef.Init();
        ColumnDef.Validate("Data Exch. Def Code", DefCodeTok);
        ColumnDef.Validate("Data Exch. Line Def Code", LineATok);
        ColumnDef.Validate("Column No.", 2);
        ColumnDef.Name := 'Amount 2';
        ColumnDef."Data Type" := ColumnDef."Data Type"::Text;
        ColumnDef.Insert();

        ColumnDef.Init();
        ColumnDef.Validate("Data Exch. Def Code", DefCodeTok);
        ColumnDef.Validate("Data Exch. Line Def Code", LineATok);
        ColumnDef.Validate("Column No.", 1);
        ColumnDef.Name := 'Amount';
        ColumnDef."Data Type" := ColumnDef."Data Type"::Decimal;
        ColumnDef."Data Format" := '0.00';
        ColumnDef."Data Formatting Culture" := 'en-US';
        ColumnDef.Path := '/Amt';
        ColumnDef."Negative-Sign Identifier" := '-';
        ColumnDef.Insert();

        Mapping.Init();
        Mapping."Data Exch. Def Code" := DefCodeTok;
        Mapping."Data Exch. Line Def Code" := LineBTok;
        Mapping."Table ID" := Database::Vendor;
        Mapping."Mapping Codeunit" := Codeunit::"Type Helper";
        Mapping.Insert();

        Mapping.Init();
        Mapping."Data Exch. Def Code" := DefCodeTok;
        Mapping."Data Exch. Line Def Code" := LineATok;
        Mapping."Table ID" := Database::Customer;
        Mapping."Mapping Codeunit" := Codeunit::"Type Helper";
        Mapping."Data Exch. No. Field ID" := 1;
        Mapping."Use as Intermediate Table" := true;
        Mapping.Insert();

        FieldMapping.Init();
        FieldMapping."Data Exch. Def Code" := DefCodeTok;
        FieldMapping."Data Exch. Line Def Code" := LineATok;
        FieldMapping."Table ID" := Database::Customer;
        FieldMapping."Column No." := 2;
        FieldMapping."Field ID" := 2;
        FieldMapping.Optional := true;
        FieldMapping.Multiplier := 1;
        FieldMapping.Insert();

        FieldMapping.Init();
        FieldMapping."Data Exch. Def Code" := DefCodeTok;
        FieldMapping."Data Exch. Line Def Code" := LineATok;
        FieldMapping."Table ID" := Database::Customer;
        FieldMapping."Column No." := 1;
        FieldMapping."Field ID" := 1;
        FieldMapping.Multiplier := 2;
        FieldMapping."Overwrite Value" := true;
        FieldMapping.Insert();

        DataExchType.Init();
        DataExchType.Code := Type2Tok;
        DataExchType.Description := 'Second';
        DataExchType."Data Exch. Def. Code" := DefCodeTok;
        DataExchType.Insert();

        DataExchType.Init();
        DataExchType.Code := Type1Tok;
        DataExchType.Description := 'First';
        DataExchType."Data Exch. Def. Code" := DefCodeTok;
        DataExchType.Insert();
    end;

    local procedure InsertEntry(FileName: Text[250]; Content: Text; Oversized: Boolean): Integer
    var
        DataExch: Record "Data Exch.";
        DataExchField: Record "Data Exch. Field";
        OutStream: OutStream;
        Chunk: Text;
        Remaining: Integer;
    begin
        DataExch.SetRange("File Name", FileName);
        DataExch.DeleteAll(true);

        DataExch.Init();
        DataExch."File Name" := FileName;
        DataExch."Data Exch. Def Code" := DefCodeTok;
        DataExch."Data Exch. Line Def Code" := LineATok;
        DataExch."Incoming Entry No." := 42;
        DataExch."File Content".CreateOutStream(OutStream, TextEncoding::UTF8);
        if Oversized then begin
            Chunk := PadStr('', 1024, 'x');
            Remaining := 1048577;
            while Remaining >= 1024 do begin
                OutStream.WriteText(Chunk);
                Remaining -= 1024;
            end;
            if Remaining > 0 then
                OutStream.WriteText(PadStr('', Remaining, 'x'));
        end else
            if Content <> '' then
                OutStream.WriteText(Content);
        DataExch.Insert(true);

        if not Oversized then begin
            DataExchField.InsertRec(DataExch."Entry No.", 1, 1, 'first', LineATok);
            DataExchField.InsertRec(DataExch."Entry No.", 1, 2, 'second', LineATok);
            DataExchField.InsertRec(DataExch."Entry No.", 2, 1, 'third', LineATok);
        end;
        exit(DataExch."Entry No.");
    end;

    local procedure ExecuteType(var TempArgument: Record "Message Argument ori"; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
        RequestText: Text;
        ResponseText: Text;
        ResponseJson: JsonObject;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument."Type" := MessageType;
        TempArgument.Insert(true);
        TempArgument.SetResponseJson(ResponseJson);
    end;

    local procedure ReadRow(Rows: JsonArray; Index: Integer) Row: JsonObject
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Rows.Get(Index, Token), 'row ' + Format(Index));
        Row := Token.AsObject();
    end;

    local procedure ReadArrayText(Rows: JsonArray; Index: Integer): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Rows.Get(Index, Token), 'value ' + Format(Index));
        exit(Token.AsValue().AsText());
    end;

    local procedure ArrayHasCode(Rows: JsonArray; Code: Text): Boolean
    var
        Token: JsonToken;
        Row: JsonObject;
    begin
        foreach Token in Rows do begin
            Row := Token.AsObject();
            if ReadObjText(Row, 'code') = Code then
                exit(true);
        end;
        exit(false);
    end;

    local procedure ReadArray(JsonObj: JsonObject; PropertyName: Text) Result: JsonArray
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(JsonObj.Get(PropertyName, Token), PropertyName);
        Result := Token.AsArray();
    end;

    local procedure ReadData(ResponseJson: JsonObject) DataObject: JsonObject
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(ResponseJson.Get('data', Token), 'data');
        DataObject := Token.AsObject();
    end;

    local procedure ReadObjText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadObjInt(JsonObj: JsonObject; PropertyName: Text): Integer
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(JsonObj.Get(PropertyName, Token), PropertyName);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadObjDec(JsonObj: JsonObject; PropertyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(JsonObj.Get(PropertyName, Token), PropertyName);
        exit(Token.AsValue().AsDecimal());
    end;

    local procedure ReadObjBool(JsonObj: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(JsonObj.Get(PropertyName, Token), PropertyName);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure ReadText(JsonObj: JsonObject; PropertyName: Text): Text
    begin
        exit(ReadObjText(JsonObj, PropertyName));
    end;
}
