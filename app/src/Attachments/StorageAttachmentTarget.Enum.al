namespace Origo.Bifrost.Hnitbjorg;

/// <summary>
/// Selects which Business Central attachment table a storage offload/restore action targets.
/// The value maps to a table id (see <see cref="Codeunit.StorageAttachmentMgt"/>) and is
/// carried as the <c>target</c> string in the attachment message types.
/// </summary>
enum 10035635 "Storage Attachment Target ori"
{
    Extensible = false;
    Caption = 'Bifrost Storage Attachment Target', Comment = 'is-IS=Markmið viðhengis Bifröst geymslu';

    /// <summary>The general <c>Document Attachment</c> table (media content).</summary>
    value(0; DocumentAttachment)
    {
        Caption = 'Document Attachment', Comment = 'is-IS=Skjalaviðhengi';
    }
    /// <summary>The <c>Incoming Document Attachment</c> table (BLOB content).</summary>
    value(1; IncomingDocument)
    {
        Caption = 'Incoming Document', Comment = 'is-IS=Innkomandi skjal';
    }
}
