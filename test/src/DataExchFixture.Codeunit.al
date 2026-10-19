namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.IO;
using System.Text;
using System.TestLibraries.Utilities;

/// <summary>
/// Shared fixtures for the Data Exchange phase tests: a Generic Import CSV definition that maps to
/// <c>DataExch Test Target ori</c>, a Generic Export CSV definition over Customer, the Mock storage
/// connection and dispatch helpers that go through Foundation's public dispatcher.
/// </summary>
codeunit 96241 "DataExch Fixture ori"
{
    var
        LibraryAssert: Codeunit "Library Assert";
        MockCodeTok: Label 'MOCK', Locked = true;
        LineDefTok: Label 'LINES', Locked = true;

    /// <summary>Resets the Mock storage and creates the enabled MOCK storage connection.</summary>
    procedure InitializeStorage()
    var
        StorageSetup: Record "Storage Setup ori";
        Session: Record "Storage Upload Session ori";
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.Reset();
        Session.DeleteAll(true);
        StorageSetup.DeleteAll();
        StorageSetup.Init();
        StorageSetup."Code" := MockCodeTok;
        StorageSetup.Description := 'Mock storage connection';
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::Mock;
        StorageSetup.Enabled := true;
        StorageSetup.Insert();
    end;

    /// <summary>The code of the Mock storage connection.</summary>
    /// <returns>MOCK.</returns>
    procedure StorageCode(): Text
    begin
        exit(MockCodeTok);
    end;

    /// <summary>Returns a new unique definition code with a prefix.</summary>
    /// <param name="Prefix">Two or three letters.</param>
    /// <returns>A code of 20 characters.</returns>
    procedure NewCode(Prefix: Text): Code[20]
    begin
        exit(CopyStr(Prefix + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
    end;

    /// <summary>
    /// Creates a Generic Import CSV definition: comma separated, columns Code, Name and Amount (en-US
    /// decimal), mapped to <c>DataExch Test Target ori</c> through <c>DataExch Test Mapping ori</c>.
    /// </summary>
    /// <param name="HeaderLines">Header lines the reader skips.</param>
    /// <returns>The definition code.</returns>
    procedure CreateImportDefinition(HeaderLines: Integer) DefCode: Code[20]
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        Mapping: Record "Data Exch. Mapping";
    begin
        DefCode := NewCode('DXI');
        DataExchDef.Init();
        DataExchDef.Code := DefCode;
        DataExchDef.Name := 'Test CSV import';
        DataExchDef.Type := DataExchDef.Type::"Generic Import";
        DataExchDef."File Type" := DataExchDef."File Type"::"Variable Text";
        DataExchDef."Column Separator" := DataExchDef."Column Separator"::Comma;
        DataExchDef."File Encoding" := DataExchDef."File Encoding"::"UTF-8";
        DataExchDef."Reading/Writing XMLport" := Xmlport::"Data Exch. Import - CSV";
        DataExchDef."Header Lines" := HeaderLines;
        DataExchDef.Insert();
        LineDef.Init();
        LineDef."Data Exch. Def Code" := DefCode;
        LineDef.Code := LineDefTok;
        LineDef.Name := 'Lines';
        LineDef."Column Count" := 3;
        LineDef.Insert();
        AddColumn(DefCode, 1, 'Code', 0);
        AddColumn(DefCode, 2, 'Name', 0);
        AddColumn(DefCode, 3, 'Amount', 2);
        Mapping.Init();
        Mapping."Data Exch. Def Code" := DefCode;
        Mapping."Data Exch. Line Def Code" := LineDefTok;
        Mapping."Table ID" := Database::"DataExch Test Target ori";
        Mapping.Name := 'Test target';
        Mapping."Mapping Codeunit" := Codeunit::"DataExch Test Mapping ori";
        Mapping."Data Exch. No. Field ID" := 1;
        Mapping."Data Exch. Line Field ID" := 2;
        Mapping.Insert();
        AddFieldMapping(DefCode, Database::"DataExch Test Target ori", 1, 3);
        AddFieldMapping(DefCode, Database::"DataExch Test Target ori", 2, 4);
        AddFieldMapping(DefCode, Database::"DataExch Test Target ori", 3, 5);
    end;

    /// <summary>Marks the mapping of a definition as an intermediate-table mapping (the incoming document path).</summary>
    /// <param name="DefCode">The definition code.</param>
    procedure UseIntermediateTable(DefCode: Code[20])
    var
        Mapping: Record "Data Exch. Mapping";
    begin
        Mapping.SetRange("Data Exch. Def Code", DefCode);
        Mapping.FindFirst();
        Mapping."Use as Intermediate Table" := true;
        Mapping.Modify();
    end;

    /// <summary>
    /// Creates a Generic Export CSV definition over Customer: columns No. and Name, written by the
    /// Export Generic CSV XMLport.
    /// </summary>
    /// <returns>The definition code.</returns>
    procedure CreateExportDefinition() DefCode: Code[20]
    var
        DataExchDef: Record "Data Exch. Def";
        LineDef: Record "Data Exch. Line Def";
        Mapping: Record "Data Exch. Mapping";
        Customer: Record Customer;
    begin
        DefCode := NewCode('DXE');
        DataExchDef.Init();
        DataExchDef.Code := DefCode;
        DataExchDef.Name := 'Test CSV export';
        DataExchDef.Type := DataExchDef.Type::"Generic Export";
        DataExchDef."File Type" := DataExchDef."File Type"::"Variable Text";
        DataExchDef."Column Separator" := DataExchDef."Column Separator"::Comma;
        DataExchDef."Reading/Writing XMLport" := Xmlport::"Export Generic CSV";
        DataExchDef.Insert();
        LineDef.Init();
        LineDef."Data Exch. Def Code" := DefCode;
        LineDef.Code := LineDefTok;
        LineDef.Name := 'Customers';
        LineDef."Column Count" := 2;
        LineDef.Insert();
        AddColumn(DefCode, 1, 'No.', 0);
        AddColumn(DefCode, 2, 'Name', 0);
        Mapping.Init();
        Mapping."Data Exch. Def Code" := DefCode;
        Mapping."Data Exch. Line Def Code" := LineDefTok;
        Mapping."Table ID" := Database::Customer;
        Mapping.Name := 'Customers';
        Mapping.Insert();
        AddFieldMapping(DefCode, Database::Customer, 1, Customer.FieldNo("No."));
        AddFieldMapping(DefCode, Database::Customer, 2, Customer.FieldNo(Name));
    end;

    /// <summary>Creates a definition header of the given type with no lines, for refusal tests.</summary>
    /// <param name="DefinitionType">The definition type.</param>
    /// <returns>The definition code.</returns>
    procedure CreateBareDefinition(DefinitionType: Enum "Data Exchange Definition Type") DefCode: Code[20]
    var
        DataExchDef: Record "Data Exch. Def";
    begin
        DefCode := NewCode('DXB');
        DataExchDef.Init();
        DataExchDef.Code := DefCode;
        DataExchDef.Type := DefinitionType;
        DataExchDef."Reading/Writing XMLport" := Xmlport::"Data Exch. Import - CSV";
        DataExchDef.Insert();
    end;

    /// <summary>Creates customers with a common name prefix and returns their numbers.</summary>
    /// <param name="Count">How many customers.</param>
    /// <param name="NamePrefix">The name prefix.</param>
    /// <returns>The customer numbers.</returns>
    procedure CreateCustomers(Count: Integer; NamePrefix: Text) CustomerNos: List of [Code[20]]
    var
        Customer: Record Customer;
        Index: Integer;
    begin
        for Index := 1 to Count do begin
            Customer.Init();
            Customer."No." := CopyStr('ZZT' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20);
            Customer.Name := CopyStr(NamePrefix + ' ' + Format(Index), 1, MaxStrLen(Customer.Name));
            Customer.Insert();
            CustomerNos.Add(Customer."No.");
        end;
    end;

    /// <summary>Dispatches a message type through Foundation's public dispatcher (Omit Commit path).</summary>
    /// <param name="MessageType">The message type.</param>
    /// <param name="RequestJson">The request data.</param>
    /// <returns>The JSON response.</returns>
    procedure Dispatch(MessageType: Enum "Message Type ori"; RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'A dispatch must return JSON.');
    end;

    /// <summary>Returns the data object of a success envelope, or the flat response itself.</summary>
    /// <param name="ResponseJson">The response.</param>
    /// <returns>The data object.</returns>
    procedure Data(ResponseJson: JsonObject) DataObject: JsonObject
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get('data', Token) then
            if Token.IsObject() then
                exit(Token.AsObject());
        exit(ResponseJson);
    end;

    /// <summary>Reads a text property; empty when absent.</summary>
    /// <param name="JsonObj">The object.</param>
    /// <param name="PropertyName">The property.</param>
    /// <returns>The text.</returns>
    procedure ReadText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Reads an integer property; 0 when absent.</summary>
    /// <param name="JsonObj">The object.</param>
    /// <param name="PropertyName">The property.</param>
    /// <returns>The integer.</returns>
    procedure ReadInt(JsonObj: JsonObject; PropertyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit(0);
        exit(Token.AsValue().AsInteger());
    end;

    /// <summary>Reads a boolean property; false when absent.</summary>
    /// <param name="JsonObj">The object.</param>
    /// <param name="PropertyName">The property.</param>
    /// <returns>The boolean.</returns>
    procedure ReadBool(JsonObj: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>Reads an object property; empty when absent.</summary>
    /// <param name="JsonObj">The object.</param>
    /// <param name="PropertyName">The property.</param>
    /// <returns>The object.</returns>
    procedure ReadObject(JsonObj: JsonObject; PropertyName: Text) Result: JsonObject
    var
        Token: JsonToken;
    begin
        if JsonObj.Get(PropertyName, Token) then
            if Token.IsObject() then
                Result := Token.AsObject();
    end;

    /// <summary>Reads an array property; empty when absent.</summary>
    /// <param name="JsonObj">The object.</param>
    /// <param name="PropertyName">The property.</param>
    /// <returns>The array.</returns>
    procedure ReadArray(JsonObj: JsonObject; PropertyName: Text) Result: JsonArray
    var
        Token: JsonToken;
    begin
        if JsonObj.Get(PropertyName, Token) then
            if Token.IsArray() then
                Result := Token.AsArray();
    end;

    /// <summary>Asserts a structured refusal: status Error and an error with the code on the parameter.</summary>
    /// <param name="ResponseJson">The response.</param>
    /// <param name="ExpectedCode">The expected error code.</param>
    /// <param name="ParameterName">The parameter the error names.</param>
    procedure AssertRefusal(ResponseJson: JsonObject; ExpectedCode: Text; ParameterName: Text)
    var
        ErrorsToken: JsonToken;
        ErrorToken: JsonToken;
        Detail: JsonObject;
    begin
        LibraryAssert.AreEqual('Error', ReadText(ResponseJson, 'status'), 'The call must be refused: ' + ReadText(ResponseJson, 'error'));
        if ResponseJson.Get('errors', ErrorsToken) then
            foreach ErrorToken in ErrorsToken.AsArray() do begin
                Detail := ErrorToken.AsObject();
                if (ReadText(Detail, 'parameter') = ParameterName) and (ReadText(Detail, 'code') = ExpectedCode) then begin
                    LibraryAssert.AreNotEqual('', ReadText(Detail, 'nextStep'), 'A refusal names a next step.');
                    exit;
                end;
            end;
        LibraryAssert.AreEqual(ExpectedCode, ReadText(ResponseJson, 'code'), 'Unexpected error code. ' + ReadText(ResponseJson, 'error'));
        LibraryAssert.AreEqual(ParameterName, ReadText(ResponseJson, 'parameter'), 'Unexpected error parameter.');
        LibraryAssert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'A refusal names a next step.');
    end;

    /// <summary>Encodes text as base64 (UTF-8).</summary>
    /// <param name="Content">The text.</param>
    /// <returns>The base64 text.</returns>
    procedure Encode(Content: Text): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
    begin
        exit(Base64Convert.ToBase64(Content, TextEncoding::UTF8));
    end;

    /// <summary>Decodes base64 to text (UTF-8).</summary>
    /// <param name="ContentBase64">The base64 text.</param>
    /// <returns>The text.</returns>
    procedure Decode(ContentBase64: Text): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
    begin
        exit(Base64Convert.FromBase64(ContentBase64, TextEncoding::UTF8));
    end;

    /// <summary>Two data lines for the import definition, CRLF separated.</summary>
    /// <param name="WithHeader">Whether a header line comes first.</param>
    /// <returns>The CSV text.</returns>
    procedure TwoLineCsv(WithHeader: Boolean) Csv: Text
    var
        CrLf: Text[2];
    begin
        CrLf[1] := 13;
        CrLf[2] := 10;
        if WithHeader then
            Csv := 'code,name,amount' + CrLf;
        Csv += 'A1,Alpha,10.5' + CrLf + 'B2,Beta,20' + CrLf;
    end;

    /// <summary>Counts the target rows written for an entry.</summary>
    /// <param name="EntryNo">The entry.</param>
    /// <returns>The row count.</returns>
    procedure TargetCount(EntryNo: Integer): Integer
    var
        Target: Record "DataExch Test Target ori";
    begin
        Target.SetRange("Data Exch. No.", EntryNo);
        exit(Target.Count());
    end;

    local procedure AddColumn(DefCode: Code[20]; ColumnNo: Integer; ColumnName: Text[250]; DataType: Option)
    var
        ColumnDef: Record "Data Exch. Column Def";
    begin
        ColumnDef.Init();
        ColumnDef."Data Exch. Def Code" := DefCode;
        ColumnDef."Data Exch. Line Def Code" := LineDefTok;
        ColumnDef."Column No." := ColumnNo;
        ColumnDef.Name := ColumnName;
        ColumnDef."Data Type" := DataType;
        if DataType = ColumnDef."Data Type"::Decimal then
            ColumnDef."Data Formatting Culture" := 'en-US';
        ColumnDef.Insert();
    end;

    local procedure AddFieldMapping(DefCode: Code[20]; TableId: Integer; ColumnNo: Integer; FieldId: Integer)
    var
        FieldMapping: Record "Data Exch. Field Mapping";
    begin
        FieldMapping.Init();
        FieldMapping."Data Exch. Def Code" := DefCode;
        FieldMapping."Data Exch. Line Def Code" := LineDefTok;
        FieldMapping."Table ID" := TableId;
        FieldMapping."Column No." := ColumnNo;
        FieldMapping."Field ID" := FieldId;
        FieldMapping.Optional := true;
        FieldMapping.Multiplier := 1;
        FieldMapping.Insert();
    end;
}
