namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Attachment.CreateLinked</c> message type. Turns a file
/// already sitting in storage (typically delivered with the <c>Storage.Upload.*</c> chunked
/// upload) into an incoming-document attachment that is served transparently from storage,
/// without the file passing through the database from the caller.
/// </summary>
codeunit 10035640 "Storage Attach Link Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
        AttachmentLink: Record "Storage Attachment Link ori";
    begin
        exit(StorageSetup.ReadPermission() and AttachmentLink.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Attaches a file already in storage to a new or existing incoming document, served transparently from storage.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        AttachmentHelp: Codeunit "Storage Attachment Help ori";
    begin
        AttachmentHelp.GetHelp(Enum::"Message Type ori"::"Storage.Attachment.CreateLinked", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        AttachmentMgt.CreateLinked(Argument.GetRequestJson(), ResultData);
        RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
