namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Help documents for <c>DataExchange.Definition.List</c> and <c>DataExchange.Definition.Get</c>.
/// </summary>
codeunit 70013527 "DataExch Def Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for one definition message type.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"DataExchange.Definition.List":
                ListHelp(Argument);
            MessageType::"DataExchange.Definition.Get":
                GetDefHelp(Argument);
        end;
    end;

    local procedure ListHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('DataExchange.Definition.List', 'Lists Data Exchange definitions and the Data Exchange Type codes that reference each one.', '');
        HelpBuilder.SetRouting('No `storageCode`. Optional filters narrow the definition list.');
        HelpBuilder.SetClosing(ClosingLine());
        HelpBuilder.AddParam('type', false, 'string', 'Definition type enum name, for example `Generic Import` or `Payment Export`. Omit to return every definition.');
        HelpBuilder.AddParam('direction', false, 'string', '`Import` or `Export`. A definition matches when its type name contains that word.');
        HelpBuilder.SetRequestExample('{ "direction": "Import" }');
        HelpBuilder.AddResponseField('count', 'integer', 'Number of definitions after filters.');
        HelpBuilder.AddResponseField('definitions', 'array', 'Rows with `code`, `name`, `type`, `fileType`, `readingWritingCodeunit`, `readingWritingXmlPort`, `extDataHandlingCodeunit`, `lineDefCount`, `mappingCount`, `usedByDataExchangeTypes`.');
        HelpBuilder.AddError('Unknown type name', 'Pass a Data Exch. Def type enum name, or omit `type`.');
        HelpBuilder.AddError('direction is not Import or Export', 'Omit `direction` or pass exactly one of those two words.');
        HelpBuilder.AddNextStep('To read columns and field mappings', 'DataExchange.Definition.Get', 'pass the returned `code`');
        HelpBuilder.AddNextStep('To see which incoming-document type uses a definition', 'DataExchange.Type.List', 'compare `dataExchDefCode` with `code`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure GetDefHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('DataExchange.Definition.Get', 'Returns one Data Exchange definition, including line definitions, column definitions and field mappings, ordered by their keys.', '');
        HelpBuilder.SetRouting('Address the definition by `code` from `DataExchange.Definition.List`.');
        HelpBuilder.SetClosing(ClosingLine());
        HelpBuilder.AddParam('code', true, 'string', 'Data Exch. Def code.');
        HelpBuilder.SetRequestExample('{ "code": "SEPA CAMT" }');
        HelpBuilder.AddResponseField('code', 'string', 'Definition code. The other list fields (`name`, `type`, `fileType`, codeunit and XMLport names, counts, `usedByDataExchangeTypes`) are included beside it.');
        HelpBuilder.AddResponseField('lineDefs', 'array', '`code`, `name`, `columnCount`, `dataLineTag`, `namespace`, ordered by line code.');
        HelpBuilder.AddResponseField('columnDefs', 'array', '`lineDef`, `columnNo`, `name`, `dataType`, `dataFormat`, `dataFormattingCulture`, `path`, `negativeSign`, `constant`, ordered by line code then column number.');
        HelpBuilder.AddResponseField('mappings', 'array', '`lineDef`, `tableId`, `tableName`, `mappingCodeunit`, `preMappingCodeunit`, `postMappingCodeunit`, `dataExchNoFieldId`, `useAsIntermediateTable`, and `fieldMappings` (`columnNo`, `fieldId`, `fieldName`, `optional`, `multiplier`, `overwriteValue`, `transformationRule`).');
        HelpBuilder.AddError('Missing code', 'Pass `code`.');
        HelpBuilder.AddError('Unknown code', 'Call `DataExchange.Definition.List` and use a returned `code`.');
        HelpBuilder.AddNextStep('To list definitions again', 'DataExchange.Definition.List', '');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure ClosingLine(): Text
    begin
        exit('Data Exchange overview: request help for `Help.DataExchange.Get`.');
    end;
}
