namespace Origo.Bifrost.Hnitbjorg;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Attachment.CreateForRecord</c> message type. Creates a
/// <c>Document Attachment</c> on any Business Central record — a customer, a vendor, a fixed
/// asset, a posted document — from inline base64, from a file already in storage, or by copying
/// an attachment that already exists elsewhere in Business Central.
/// </summary>
codeunit 10035667 "Storage Attach Record Impl ori" implements "Msg Interface ori"
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
        exit('Creates a document attachment on any record - customer, vendor, fixed asset, document - from base64, from storage, or by copying an existing attachment.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        AttachmentHelp: Codeunit "Storage Attachment Help ori";
    begin
        AttachmentHelp.GetHelp(Enum::"Message Type ori"::"Storage.Attachment.CreateForRecord", Argument);
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        AttachmentMgt.CreateForRecord(Argument.GetRequestJson(), ResultData);
        RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
