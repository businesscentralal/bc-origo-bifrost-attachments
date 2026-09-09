namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Attachment.Restore</c> message type. Brings an offloaded
/// attachment's file back into the Business Central database from its storage connection and
/// deletes the remote copy, reversing <c>Storage.Attachment.Offload</c>.
/// </summary>
codeunit 10035642 "Storage Att. Restore Impl ori" implements "Msg Interface ori"
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
        exit('Restores an offloaded attachment''s file from storage back into the database and deletes the remote copy.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        AttachmentHelp: Codeunit "Storage Attachment Help ori";
    begin
        AttachmentHelp.GetHelp(Enum::"Message Type ori"::"Storage.Attachment.Restore", Argument);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        // This is an inbound (write) message type: the database work runs directly, not inside a
        // TryFunction (AL forbids INSERT there). Any error propagates to the framework, which
        // writes the standard { "status": "Error", "error": ... } response.
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        AttachmentMgt.Restore(Argument.GetRequestJson(), ResultData);
        RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
