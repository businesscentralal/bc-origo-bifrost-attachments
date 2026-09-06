namespace Origo.Bifrost.Attachments;

/// <summary>
/// Builds AI-optimised Markdown help documents for the storage connector message types.
/// Uses a builder pattern: call <c>Init</c>, then <c>AddParam</c>/<c>AddError</c>/setters,
/// then <c>Render</c> to produce the final document. Each section is designed for
/// unambiguous machine parsing: structured parameter tables, explicit types, request and
/// response examples, and common errors. Used by the initial-release help surface.
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
        ParamsBuilder: TextBuilder;
        ErrorsBuilder: TextBuilder;
        ResponseFieldsBuilder: TextBuilder;
        NextStepsBuilder: TextBuilder;
        ParamCount: Integer;
        ErrorCount: Integer;
        ResponseFieldCount: Integer;
        NextStepCount: Integer;

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
        RequestExampleVar := '';
        ResponseNoteVar := '';
        NotesVar := '';
        RelatedVar := '';
        ParamCount := 0;
        ErrorCount := 0;
        ResponseFieldCount := 0;
        NextStepCount := 0;
        Clear(ParamsBuilder);
        Clear(ErrorsBuilder);
        Clear(ResponseFieldsBuilder);
        Clear(NextStepsBuilder);
    end;

    /// <summary>Adds one row to the Parameters table. Call once per request parameter.</summary>
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

    /// <summary>Sets the message direction shown in the Metadata section. Defaults to <c>Outbound</c>.</summary>
    /// <param name="Direction">The direction text, for example 'Inbound (write)'.</param>
    procedure SetDirection(Direction: Text)
    begin
        DirectionVar := Direction;
    end;

    /// <summary>Sets the JSON request example shown in the Request section.</summary>
    procedure SetRequestExample(Example: Text)
    begin
        RequestExampleVar := Example;
    end;

    /// <summary>Sets the one-line description of what <c>data</c> contains in a successful response.</summary>
    procedure SetResponseNote(Note: Text)
    begin
        ResponseNoteVar := Note;
    end;

    /// <summary>Adds one row to the Common Errors table.</summary>
    /// <param name="Condition">The error condition.</param>
    /// <param name="Resolution">What the caller should do to resolve it.</param>
    procedure AddError(Condition: Text; Resolution: Text)
    begin
        ErrorCount += 1;
        if ErrorCount = 1 then begin
            ErrorsBuilder.AppendLine('| Error | Resolution |');
            ErrorsBuilder.AppendLine('|---|---|');
        end;
        ErrorsBuilder.Append('| ');
        ErrorsBuilder.Append(Condition);
        ErrorsBuilder.Append(' | ');
        ErrorsBuilder.Append(Resolution);
        ErrorsBuilder.AppendLine(' |');
    end;

    /// <summary>
    /// Overrides the routing note shown in the Metadata section. Use it when the type is not
    /// addressed by <c>storageCode</c> (for example a chunked-upload step keyed by <c>uploadId</c>).
    /// </summary>
    /// <param name="Routing">The routing/identification note (Markdown).</param>
    procedure SetRouting(Routing: Text)
    begin
        RoutingVar := Routing;
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
    /// the one it should call next, carrying the right value forward.
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
    end;

    /// <summary>Sets the Notes section content (Markdown).</summary>
    procedure SetNotes(Notes: Text)
    begin
        NotesVar := Notes;
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
    begin
        Builder.AppendLine('# ' + TitleVar);
        Builder.AppendLine('');
        Builder.AppendLine(DescriptionVar);
        Builder.AppendLine('');

        Builder.AppendLine('## Metadata');
        Builder.AppendLine('- **Direction:** ' + DirectionVar);
        Builder.AppendLine('- **Content-Type:** text/json');
        Builder.AppendLine('- **Invoke:** call the `call_message_type` tool with `type` = `' + TitleVar + '` and the parameters below as the `data` object.');
        if FacadeOpVar <> '' then
            Builder.AppendLine('- **External File Storage operation:** `' + FacadeOpVar + '`');
        if RoutingVar <> '' then
            Builder.AppendLine('- **Routing:** ' + RoutingVar);
        Builder.AppendLine('');

        if ParamCount > 0 then begin
            Builder.AppendLine('## Parameters');
            Builder.AppendLine('');
            Builder.Append(ParamsBuilder.ToText());
            Builder.AppendLine('');
        end;

        Builder.AppendLine('## Request example');
        Builder.AppendLine('```json');
        Builder.AppendLine(RequestExampleVar);
        Builder.AppendLine('```');
        Builder.AppendLine('');

        Builder.AppendLine('## Response');
        Builder.AppendLine('Success:');
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
        Builder.AppendLine('Failure (the framework wraps any raised error):');
        Builder.AppendLine('```json');
        Builder.AppendLine('{ "status": "Error", "error": "<message>" }');
        Builder.AppendLine('```');
        Builder.AppendLine('Always branch on `status` before reading `data`.');
        Builder.AppendLine('');

        if ErrorCount > 0 then begin
            Builder.AppendLine('## Common errors');
            Builder.AppendLine('');
            Builder.Append(ErrorsBuilder.ToText());
            Builder.AppendLine('');
        end;

        if NotesVar <> '' then begin
            Builder.AppendLine('## Notes');
            Builder.AppendLine(NotesVar);
            Builder.AppendLine('');
        end;

        if NextStepCount > 0 then begin
            Builder.AppendLine('## Next steps');
            Builder.Append(NextStepsBuilder.ToText());
            Builder.AppendLine('');
        end;

        if RelatedVar <> '' then begin
            Builder.AppendLine('## Related operations');
            Builder.AppendLine(RelatedVar);
            Builder.AppendLine('');
        end;

        Builder.AppendLine('---');
        Builder.AppendLine('Connector overview and the list of configured connections: request help for `Help.Storage.Get` and call `Storage.Account.List`.');

        exit(Builder.ToText());
    end;
}
