namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Help documents for <c>DataExchange.Entry.List</c> and <c>DataExchange.Entry.Get</c>.
/// </summary>
codeunit 70013529 "DataExch Entry Help ori"
{
    Access = Internal;

    /// <summary>Renders the Markdown help document for one entry message type.</summary>
    /// <param name="MessageType">The message type to document.</param>
    /// <param name="Argument">The message argument the rendered Markdown is written to.</param>
    procedure GetHelp(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    begin
        case MessageType of
            MessageType::"DataExchange.Entry.List":
                ListHelp(Argument);
            MessageType::"DataExchange.Entry.Get":
                GetEntryHelp(Argument);
        end;
    end;

    local procedure ListHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('DataExchange.Entry.List', 'Lists processed Data Exch. entries. Pagination uses Foundation skip/take rules.', '');
        HelpBuilder.SetRouting('Filter by definition code and created-at range. Page with `skip` and `take`.');
        HelpBuilder.SetClosing('Data Exchange overview: request help for `Help.DataExchange.Get`.');
        HelpBuilder.AddParam('dataExchDefCode', false, 'string', 'Only entries for this Data Exch. Def code.');
        HelpBuilder.AddParam('dateFrom', false, 'string', 'Inclusive start, invariant date `YYYY-MM-DD` or datetime.');
        HelpBuilder.AddParam('dateTo', false, 'string', 'Inclusive end. A date with no time covers that whole day.');
        HelpBuilder.AddParam('skip', false, 'integer', 'Records to skip. Defaults to 0. Negative is an error.');
        HelpBuilder.AddParam('take', false, 'integer', 'Page size. Defaults to 100 when omitted or 0. Negative is an error. Clamped to 1000.');
        HelpBuilder.SetRequestExample('{ "dataExchDefCode": "SEPA CAMT", "take": 20 }');
        HelpBuilder.AddResponseField('count', 'integer', 'Entries matching the filter, before paging.');
        HelpBuilder.AddResponseField('skip', 'integer', 'Applied skip.');
        HelpBuilder.AddResponseField('take', 'integer', 'Applied take.');
        HelpBuilder.AddResponseField('entries', 'array', '`entryNo`, `dataExchDefCode`, `dataExchLineDefCode`, `fileName`, `createdAt`, `hasFileContent`, `fieldCount`, `incomingEntryNo` (0 when not linked), `relatedRecord`.');
        HelpBuilder.SetNotes(PaginationNotes());
        HelpBuilder.AddError("Bifrost Error Code ori"::InvalidParameter, 'Negative skip or take', 'Pass skip >= 0 and take >= 0.');
        HelpBuilder.AddNextStep('To read fields for one entry', 'DataExchange.Entry.Get', 'pass the returned `entryNo`');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure GetEntryHelp(var Argument: Record "Message Argument ori")
    var
        HelpBuilder: Codeunit "Storage Help Builder ori";
    begin
        HelpBuilder.Init('DataExchange.Entry.Get', 'Returns one Data Exch. entry. Fields are paged. File content is included only when asked and only up to 1 MB.', '');
        HelpBuilder.SetRouting('Address the entry by `entryNo` from `DataExchange.Entry.List`.');
        HelpBuilder.SetClosing('Data Exchange overview: request help for `Help.DataExchange.Get`.');
        HelpBuilder.AddParam('entryNo', true, 'integer', 'Data Exch. entry number.');
        HelpBuilder.AddParam('includeFields', false, 'boolean', 'Include the paged `fields` array. Defaults to true.');
        HelpBuilder.AddParam('includeFileContent', false, 'boolean', 'Include `contentBase64`. Defaults to false. Refused when the file is above 1 MB.');
        HelpBuilder.AddParam('skip', false, 'integer', 'Field rows to skip when `includeFields` is true. Defaults to 0. Negative is an error.');
        HelpBuilder.AddParam('take', false, 'integer', 'Field page size. Defaults to 100 when omitted or 0. Negative is an error. Clamped to 1000.');
        HelpBuilder.SetRequestExample('{ "entryNo": 20, "includeFields": true, "skip": 0, "take": 50 }');
        HelpBuilder.AddResponseField('entryNo', 'integer', 'The entry. The list fields (`dataExchDefCode`, `fileName`, `createdAt`, `hasFileContent`, `fieldCount`, `incomingEntryNo`, `relatedRecord`) are included beside it.');
        HelpBuilder.AddResponseField('fields', 'array', 'Present when `includeFields` is true. Each item is `lineNo`, `columnNo`, `columnName`, `value`, `dataExchLineDefCode`.');
        HelpBuilder.AddResponseField('contentBase64', 'string', 'Present only when `includeFileContent` is true and the file is at most 1 MB.');
        HelpBuilder.AddResponseField('contentLength', 'integer', 'Byte length, present together with `contentBase64`.');
        HelpBuilder.SetNotes(PaginationNotes());
        HelpBuilder.AddError("Bifrost Error Code ori"::RecordNotFound, 'Missing or unknown entryNo', 'Pass an `entryNo` from `DataExchange.Entry.List`.');
        HelpBuilder.AddError("Bifrost Error Code ori"::LimitExceeded, 'File content above 1 MB', 'Omit `includeFileContent`. The call returns an error and no content.');
        HelpBuilder.AddNextStep('To choose another entry', 'DataExchange.Entry.List', '');
        Argument.SetResponseMarkdown(HelpBuilder.Render());
    end;

    local procedure PaginationNotes(): Text
    var
        Builder: TextBuilder;
    begin
        Builder.AppendLine('## Pagination Limits');
        Builder.AppendLine('`skip` defaults to 0 and rejects negative values. `take` defaults to 100 when omitted or zero, rejects negative values, and is clamped to the hard maximum of 1000.');
        exit(Builder.ToText());
    end;
}
