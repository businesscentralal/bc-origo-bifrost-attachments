namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;

/// <summary>
/// Adds the <c>Bifrost Offloaded</c> FlowField to <c>Incoming Document Attachment</c>.
/// The field is true when the attachment's content has been offloaded to external storage
/// and a corresponding <c>Bifrost Storage Attachment Link</c> row exists.
/// </summary>
tableextension 10035635 "Storage Inc. Doc. Attach. ori" extends "Incoming Document Attachment"
{
    fields
    {
        field(10035635; "Offloaded ori"; Boolean)
        {
            Caption = 'Bifrost Offloaded', Comment = 'is-IS=Bifröst útvistað';
            ToolTip = 'Specifies whether the attachment content has been offloaded to external storage.', Comment = 'is-IS=Tilgreinir hvort innihald viðhengisins hafi verið útvistað í ytri geymslu.';
            FieldClass = FlowField;
            // 133 = Database::"Incoming Document Attachment"
            CalcFormula = exist("Storage Attachment Link ori" where("Table ID" = const(133), "Record System Id" = field(SystemId)));
            Editable = false;
        }
    }
}
