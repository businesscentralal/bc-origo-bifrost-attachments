namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Builds AI-optimised Markdown help documents for the storage connector message types.
/// Uses a builder pattern: call <c>Init</c>, then <c>AddParam</c>/<c>AddError</c>/setters,
/// then <c>Render</c> to produce the final document. The document carries the sections every
/// Bifröst message type has - Overview, Request Parameters, Response Shape, Errors and Related
/// Message Types - so an agent reads every type the same way. The shared description of the error
/// shape is appended by Bifröst Foundation's <c>Help.Implementation.Get</c>, not here.
/// </summary>
codeunit 10035643 "Storage Help Builder ori"
{
    Access = Internal;

    var
        TitleVar: Text;
        DescriptionVar: Text;
        DirectionVar: Text;
        FacadeOpVar: Text;
        RoutingVar: Text;
        RequestExampleVar: Text;
        ResponseNoteVar: Text;
        NotesVar: Text;
        RelatedVar: Text;
        SideEffectsVar: Text;
        ClosingVar: Text;
        ParamsBuilder: TextBuilder;
        ErrorsBuilder: TextBuilder;
        ResponseFieldsBuilder: TextBuilder;
        NextStepsBuilder: TextBuilder;
        RelatedTypes: List of [Text];
        RelatedPurposes: List of [Text];
        ParamCount: Integer;
        ResponseFieldCount: Integer;
        NextStepCount: Integer;
        RoutedByStorageCode: Boolean;
        HasPathParameter: Boolean;
        HasRequiredParameter: Boolean;
        HasFormattedParameter: Boolean;

    /// <summary>Initializes the builder for a single message type document.</summary>
    /// <param name="MessageType">The full message type name (e.g. 'Storage.File.Get').</param>
    /// <param name="Description">One or two sentence summary of what it does.</param>
    /// <param name="FacadeOperation">The underlying External File Storage operation (e.g. 'GetFile').</param>
    procedure Init(MessageType: Text; Description: Text; FacadeOperation: Text)
    begin
        TitleVar := MessageType;
        DescriptionVar := Description;
        DirectionVar := 'Outbound';
        FacadeOpVar := FacadeOperation;
        RoutingVar := 'The request''s `storageCode` selects a `Bifrost Storage Setup` row; the action runs against that row''s file account. Discover codes with `Storage.Account.List`.';
        RoutedByStorageCode := true;
        RequestExampleVar := '';
        ResponseNoteVar := '';
        NotesVar := '';
        RelatedVar := '';
        SideEffectsVar := '';
        ClosingVar := 'Connector overview and the list of configured connections: request help for `Help.Storage.Get` and call `Storage.Account.List`.';
        ParamCount := 0;
        ResponseFieldCount := 0;
        NextStepCount := 0;
        HasPathParameter := false;
        HasRequiredParameter := false;
        HasFormattedParameter := false;
        Clear(ParamsBuilder);
        Clear(ErrorsBuilder);
        Clear(ResponseFieldsBuilder);
        Clear(NextStepsBuilder);
        Clear(RelatedTypes);
        Clear(RelatedPurposes);
    end;

    /// <summary>Adds one row to the Request Parameters table. Call once per request parameter.</summary>
    /// <param name="ParamName">The JSON property name.</param>
    /// <param name="Required">Whether the parameter is required for a successful call.</param>
    /// <param name="DataType">The value type (string, base64 string, boolean, integer).</param>
    /// <param name="Description">What the parameter means or controls.</param>
    procedure AddParam(ParamName: Text; Required: Boolean; DataType: Text; Description: Text)
    begin
        ParamCount += 1;
        if ParamCount = 1 then begin
            ParamsBuilder.AppendLine('| Parameter | Required | Type | Description |');
            ParamsBuilder.AppendLine('|---|---|---|---|');
        end;
        if Required then
            HasRequiredParameter := true;
        if ParamName.EndsWith('ath') then
            HasPathParameter := true;
        if not DataType.StartsWith('string') or DataType.Contains('GUID') then
            HasFormattedParameter := true;
        ParamsBuilder.Append('| `');
        ParamsBuilder.Append(ParamName);
        ParamsBuilder.Append('` | ');
        if Required then
            ParamsBuilder.Append('**Yes**')
        else
            ParamsBuilder.Append('No');
        ParamsBuilder.Append(' | ');
        ParamsBuilder.Append(DataType);
        ParamsBuilder.Append(' | ');
        ParamsBuilder.Append(Description);
        ParamsBuilder.AppendLine(' |');
    end;

    /// <summary>Sets the message direction shown in the Overview section. Defaults to <c>Outbound</c>.</summary>
    /// <param name="Direction">The direction text, for example 'Inbound (write)'.</param>
    procedure SetDirection(Direction: Text)
    begin
        DirectionVar := Direction;
    end;

    /// <summary>Sets the JSON request example. A backslash starts a new line.</summary>
    /// <param name="Example">The request example.</param>
    procedure SetRequestExample(Example: Text)
    begin
        RequestExampleVar := ToLines(Example);
    end;

    /// <summary>Sets the one-line description of what <c>data</c> contains in a successful response.</summary>
    /// <param name="Note">The note.</param>
    procedure SetResponseNote(Note: Text)
    begin
        ResponseNoteVar := Note;
    end;

    /// <summary>Adds one row to the Errors table, specific to this message type.</summary>
    /// <param name="ErrorCode">The <c>code</c> the caller receives.</param>
    /// <param name="Condition">When the error occurs.</param>
    /// <param name="Resolution">What the caller should do to resolve it.</param>
    procedure AddError(ErrorCode: Enum "Bifrost Error Code ori"; Condition: Text; Resolution: Text)
    begin
        AppendErrorRow(ErrorCodeName(ErrorCode), Condition, Resolution);
    end;

    /// <summary>
    /// Overrides the routing note shown in the Overview section. Use it when the type is not
    /// addressed by <c>storageCode</c> (for example a chunked-upload step keyed by <c>uploadId</c>);
    /// the standard storage-code errors are then left out of the Errors table.
    /// </summary>
    /// <param name="Routing">The routing/identification note (Markdown).</param>
    procedure SetRouting(Routing: Text)
    begin
        RoutingVar := Routing;
        RoutedByStorageCode := false;
    end;

    /// <summary>
    /// Adds one row to the structured Response fields table. Use it instead of <c>SetResponseNote</c>
    /// when an agent needs to read individual fields out of <c>data</c> to chain the next call.
    /// </summary>
    /// <param name="FieldName">The JSON property name inside <c>data</c>.</param>
    /// <param name="DataType">The value type (string, integer, boolean, base64 string, ...).</param>
    /// <param name="Description">What the field carries and how a caller uses it next.</param>
    procedure AddResponseField(FieldName: Text; DataType: Text; Description: Text)
    begin
        ResponseFieldCount += 1;
        if ResponseFieldCount = 1 then begin
            ResponseFieldsBuilder.AppendLine('| Field | Type | Description |');
            ResponseFieldsBuilder.AppendLine('|---|---|---|');
        end;
        ResponseFieldsBuilder.AppendLine('| `' + FieldName + '` | ' + DataType + ' | ' + Description + ' |');
    end;

    /// <summary>
    /// Adds an explicit next-step pointer so an agent can auto-navigate from this message type to
    /// the one it should call next, carrying the right value forward. The type is also listed under
    /// Related Message Types.
    /// </summary>
    /// <param name="WhenText">The condition or goal, e.g. 'To send the file contents'.</param>
    /// <param name="MessageType">The message type to call next, e.g. 'Storage.Upload.Append'.</param>
    /// <param name="CarryText">Which value to pass forward, e.g. 'pass the returned `uploadId`'.</param>
    procedure AddNextStep(WhenText: Text; MessageType: Text; CarryText: Text)
    begin
        NextStepCount += 1;
        NextStepsBuilder.Append('- ' + WhenText + ' → call `' + MessageType + '`');
        if CarryText <> '' then
            NextStepsBuilder.Append(' (' + CarryText + ')');
        NextStepsBuilder.AppendLine('.');
        AddRelated(MessageType, WhenText);
    end;

    /// <summary>Adds a message type to the Related Message Types section. A type is listed once.</summary>
    /// <param name="MessageType">The related message type, e.g. 'Storage.File.Get'.</param>
    /// <param name="Purpose">Why a caller would use it, e.g. 'Download a file'.</param>
    procedure AddRelated(MessageType: Text; Purpose: Text)
    begin
        if RelatedTypes.Contains(MessageType) then
            exit;
        RelatedTypes.Add(MessageType);
        RelatedPurposes.Add(Purpose);
    end;

    /// <summary>Sets the Side effects section (Markdown). A backslash starts a new line.</summary>
    /// <param name="SideEffects">The side effects.</param>
    procedure SetSideEffects(SideEffects: Text)
    begin
        SideEffectsVar := ToLines(SideEffects);
    end;

    /// <summary>Sets the Notes section content (Markdown). A backslash starts a new line.</summary>
    /// <param name="Notes">The notes.</param>
    procedure SetNotes(Notes: Text)
    begin
        NotesVar := ToLines(Notes);
    end;

    /// <summary>
    /// Replaces the closing line under the horizontal rule. The default points at the storage overview.
    /// </summary>
    /// <param name="Closing">The closing Markdown line.</param>
    procedure SetClosing(Closing: Text)
    begin
        ClosingVar := Closing;
    end;

    /// <summary>Sets the Related Operations section (Markdown).</summary>
    procedure SetRelated(Related: Text)
    begin
        RelatedVar := Related;
    end;

    /// <summary>Renders the final Markdown document from all accumulated builder state.</summary>
    /// <returns>The complete AI-optimised help document.</returns>
    procedure Render(): Text
    var
        Builder: TextBuilder;
        Index: Integer;
    begin
        Builder.AppendLine('# ' + TitleVar + ' - Help');
        Builder.AppendLine('');

        Builder.AppendLine('## Overview');
        Builder.AppendLine(DescriptionVar);
        Builder.AppendLine('');
        Builder.AppendLine('- **Direction:** ' + DirectionVar);
        Builder.AppendLine('- **Content-Type:** text/json');
        Builder.AppendLine('- **Invoke:** call the `invoke_message_type` tool with `type` = `' + TitleVar + '` and the parameters below as the `data` object.');
        if FacadeOpVar <> '' then
            Builder.AppendLine('- **External File Storage operation:** `' + FacadeOpVar + '`');
        if RoutingVar <> '' then
            Builder.AppendLine('- **Routing:** ' + RoutingVar);
        Builder.AppendLine('');

        Builder.AppendLine('## Request Parameters');
        Builder.AppendLine('');
        if ParamCount > 0 then
            Builder.Append(ParamsBuilder.ToText())
        else
            Builder.AppendLine('This message type takes no parameters.');
        Builder.AppendLine('');
        Builder.AppendLine('### Example');
        Builder.AppendLine('```json');
        Builder.AppendLine(RequestExampleVar);
        Builder.AppendLine('```');
        Builder.AppendLine('');

        Builder.AppendLine('## Response Shape');
        Builder.AppendLine('```json');
        Builder.AppendLine('{ "status": "Success", "data": ... }');
        Builder.AppendLine('```');
        if ResponseFieldCount > 0 then begin
            Builder.AppendLine('');
            Builder.AppendLine('`data` fields:');
            Builder.AppendLine('');
            Builder.Append(ResponseFieldsBuilder.ToText());
        end else
            if ResponseNoteVar <> '' then
                Builder.AppendLine('`data` contains ' + ResponseNoteVar + '.');
        Builder.AppendLine('');
        Builder.AppendLine('Always branch on `status` before reading `data`.');
        Builder.AppendLine('');

        Builder.AppendLine('## Errors');
        Builder.AppendLine('');
        Builder.AppendLine('An error answers `status` = `Error` with a stable `code`, the `error` text and, where they apply, `parameter`, `received`, `expected` and `nextStep`. Every problem in the request values is reported at once.');
        Builder.AppendLine('');
        Builder.AppendLine('| Code | When | What to do |');
        Builder.AppendLine('|---|---|---|');
        Builder.Append(StandardErrorRows());
        Builder.Append(ErrorsBuilder.ToText());
        Builder.AppendLine('');

        if SideEffectsVar <> '' then begin
            Builder.AppendLine('## Side effects');
            Builder.AppendLine('');
            Builder.AppendLine(SideEffectsVar);
            Builder.AppendLine('');
        end;

        if NotesVar <> '' then begin
            Builder.AppendLine('## Notes');
            Builder.AppendLine(NotesVar);
            Builder.AppendLine('');
        end;

        if NextStepCount > 0 then begin
            Builder.AppendLine('## Next Steps');
            Builder.Append(NextStepsBuilder.ToText());
            Builder.AppendLine('');
        end;

        Builder.AppendLine('## Related Message Types');
        for Index := 1 to RelatedTypes.Count() do
            Builder.AppendLine('- `' + RelatedTypes.Get(Index) + '` - ' + RelatedPurposes.Get(Index));
        if not RelatedTypes.Contains('Help.Storage.Get') then
            Builder.AppendLine('- `Help.Storage.Get` - Overview of the storage connector and all its message types');
        Builder.AppendLine('');

        if RelatedVar <> '' then begin
            Builder.AppendLine('## Related operations');
            Builder.AppendLine(RelatedVar);
            Builder.AppendLine('');
        end;

        Builder.AppendLine('---');
        if ClosingVar <> '' then
            Builder.AppendLine(ClosingVar);

        exit(Builder.ToText());
    end;

    local procedure StandardErrorRows() Rows: Text
    var
        RowsBuilder: TextBuilder;
    begin
        if HasRequiredParameter then
            AppendRow(RowsBuilder, 'MissingParameter', 'A required parameter is missing; `parameter` names it.', 'Send the parameter.');
        if HasFormattedParameter then
            AppendRow(RowsBuilder, 'InvalidParameterFormat', 'A value has the wrong form, for example text where an integer or a GUID is expected.', 'Send the value in the form `expected` shows.');
        if HasPathParameter then
            AppendRow(RowsBuilder, 'InvalidParameter', 'A path has a `.` or `..` segment.', 'Send a path inside the connection, relative to its base path.');
        if RoutedByStorageCode then begin
            AppendRow(RowsBuilder, 'RecordNotFound', 'No storage connection is configured for `storageCode`.', 'Call `Storage.Account.List` and use one of its codes.');
            AppendRow(RowsBuilder, 'PreconditionFailed', 'The storage connection is disabled.', 'Enable it on the Bifröst Attachments setup page, or use another `storageCode`.');
            AppendRow(RowsBuilder, 'BusinessCentralError', 'The storage service or its connector refused the call; `error` is the connector''s own text.', 'Check the path and the connection, then retry.');
        end;
        Rows := RowsBuilder.ToText();
    end;

    local procedure AppendErrorRow(CodeName: Text; Condition: Text; Resolution: Text)
    begin
        AppendRow(ErrorsBuilder, CodeName, Condition, Resolution);
    end;

    local procedure AppendRow(var RowsBuilder: TextBuilder; CodeName: Text; Condition: Text; Resolution: Text)
    begin
        RowsBuilder.AppendLine('| `' + CodeName + '` | ' + Condition + ' | ' + Resolution + ' |');
    end;

    local procedure ErrorCodeName(ErrorCode: Enum "Bifrost Error Code ori"): Text
    begin
        exit(Enum::"Bifrost Error Code ori".Names().Get(Enum::"Bifrost Error Code ori".Ordinals().IndexOf(ErrorCode.AsInteger())));
    end;

    local procedure ToLines(Value: Text): Text
    var
        LineFeed: Text[1];
    begin
        LineFeed[1] := 10;
        exit(Value.Replace('\', LineFeed));
    end;
}
