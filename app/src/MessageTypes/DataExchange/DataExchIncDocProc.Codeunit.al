namespace Origo.Bifrost.Attachments;

using Microsoft.EServices.EDocument;
using Origo.Bifrost;

/// <summary>
/// Isolated runner for <c>Incoming Document.CreateDocumentWithDataExchange</c>. A processing
/// failure rolls back only this codeunit, so the incoming document created by
/// <c>Storage.Upload.CommitToRecord</c> or <c>Storage.Attachment.CreateLinked</c> remains.
/// </summary>
codeunit 70013532 "DataExch Inc Doc Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ProcessIncomingDocument(Rec);
    end;

    /// <summary>Runs the built-in document creation for the incoming document named in the request.</summary>
    /// <param name="Argument">Request carrying <c>incomingDocumentEntryNo</c>.</param>
    local procedure ProcessIncomingDocument(var Argument: Record "Message Argument ori")
    var
        IncomingDocument: Record "Incoming Document";
        Reader: Codeunit "Storage Request Reader ori";
        RequestJson: JsonObject;
        EntryNo: Integer;
        MissingDocumentErr: Label 'Incoming document %1 was not found.', Comment = '%1 = entry number||is-IS=Skjal í innleið %1 fannst ekki.';
        ExpectedDocumentLbl: Label 'an existing incoming document entry number', Comment = 'is-IS=númer fyrirliggjandi skjals í innleið';
        SelectDocumentLbl: Label 'Create the incoming document first, then process it.', Comment = 'is-IS=Stofnaðu skjalið í innleið fyrst og vinndu það síðan.';
    begin
        RequestJson := Argument.GetRequestJson();
        Reader.ReadInteger(Argument, RequestJson, 'incomingDocumentEntryNo', true, EntryNo);
        if Reader.RespondIfErrors(Argument) then
            exit;
        IncomingDocument.ReadIsolation := IsolationLevel::UpdLock;
        if not IncomingDocument.Get(EntryNo) then
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingDocumentErr, Format(EntryNo, 0, 9)), 'incomingDocumentEntryNo', Format(EntryNo, 0, 9), ExpectedDocumentLbl, SelectDocumentLbl)
        else
            IncomingDocument.CreateDocumentWithDataExchange();
    end;
}
