namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.Status</c> message type. Reports the progress and
/// state of an upload session: its file name, destination, status, and how many bytes and chunks
/// have been received.
/// </summary>
codeunit 10035660 "Storage Upload Status Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    internal procedure IsEnabled(): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        exit(StorageSetup.ReadPermission());
    end;

    internal procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    internal procedure GetDescription(): Text[250]
    begin
        exit('Reports the progress and state of an upload session.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        UploadHelp: Codeunit "Storage Upload Help ori";
    begin
        UploadHelp.GetHelp(Enum::"Message Type ori"::"Storage.Upload.Status", Argument);
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        UploadMgt.GetStatus(Argument.GetRequestJson(), ResultData);
        RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
