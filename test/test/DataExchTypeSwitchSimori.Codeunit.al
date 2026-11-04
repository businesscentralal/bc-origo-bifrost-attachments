namespace Origo.Bifrost.Attachments.Test;

using Microsoft.EServices.EDocument;

/// <summary>
/// Manual-bind subscriber that mimics Business Central's Data Exch. Type Selector, which replaces
/// the Data Exchange Type of an incoming document when an attachment is inserted (#197).
/// </summary>
codeunit 96276 "DataExch Type Switch Sim ori"
{
    EventSubscriberInstance = Manual;

    var
        SwitchToType: Code[20];

    /// <summary>Sets the type that the simulated selector writes after the next attachment insert.</summary>
    procedure SetSwitchToType(NewType: Code[20])
    begin
        SwitchToType := NewType;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Incoming Document Attachment", OnAfterInsertEvent, '', false, false)]
    local procedure SwitchTypeOnAttachmentInsert(var Rec: Record "Incoming Document Attachment"; RunTrigger: Boolean)
    var
        IncomingDocument: Record "Incoming Document";
    begin
        if Rec.IsTemporary() or (SwitchToType = '') then
            exit;
        if IncomingDocument.Get(Rec."Incoming Document Entry No.") then begin
            IncomingDocument."Data Exchange Type" := SwitchToType;
            IncomingDocument.Modify();
        end;
    end;
}
