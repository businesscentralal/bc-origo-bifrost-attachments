namespace Origo.Bifrost.Attachments;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.CommitToRecord</c> message type. Assembles a
/// chunked upload session's data and attaches it directly to a Business Central record
/// without writing to external storage — the content goes straight into the database.
/// </summary>
codeunit 10035669 "Storage Upload Commit Rec ori" implements "Msg Interface ori"
{
    Access = Internal;

    internal procedure IsEnabled(): Boolean
    var
        DocumentAttachment: Record "Document Attachment";
    begin
        exit(DocumentAttachment.WritePermission());
    end;

    internal procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Document Attachment");
    end;

    internal procedure GetDescription(): Text[250]
    begin
        exit('Assembles uploaded chunks and attaches the file directly to a record without external storage.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        UploadHelp: Codeunit "Storage Upload Help ori";
    begin
        UploadHelp.GetHelp(Enum::"Message Type ori"::"Storage.Upload.CommitToRecord", Argument);
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        UploadMgt.CommitToRecord(Argument.GetRequestJson(), ResultData);
        RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
