namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Implementation of the <c>Storage.Upload.Begin</c> message type. Opens a chunked upload
/// session and returns the <c>uploadId</c> used to append chunks and commit the file.
/// </summary>
codeunit 10035658 "Storage Upload Begin Impl ori" implements "Msg Interface ori"
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
        exit('Opens a chunked upload session for delivering a large file as a sequence of small chunks.');
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        UploadHelp: Codeunit "Storage Upload Help ori";
    begin
        UploadHelp.GetHelp(Enum::"Message Type ori"::"Storage.Upload.Begin", Argument);
    end;

    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        UploadMgt: Codeunit "Storage Upload Mgt ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        ResultData: JsonObject;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        UploadMgt.BeginUpload(Argument.GetRequestJson(), ResultData);
        RequestMgt.RespondSuccess(Argument, ResultData);
    end;
}
