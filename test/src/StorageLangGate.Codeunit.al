namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;

/// <summary>
/// Carries the Foundation setup read that Dispatcher ori needs for the response language.
/// A restrictive test codeunit's Permissions property is an allow-list, so it cannot grant this
/// read to Foundation. This codeunit stays on the stack and supplies the indirect read.
/// </summary>
codeunit 96223 "Storage Lang Gate ori"
{
    Access = Internal;
    InherentPermissions = tabledata "Setup ori" = R;
    Permissions = tabledata "Setup ori" = R;

    procedure Execute(MessageType: Enum "Message Type ori"; MessageVersion: Enum "Message Version ori"; Subject: Text; Source: Text; ContentType: Text; var RequestContent: BigText; var ResponseContent: BigText; var ResponseContentType: Text[100])
    var
        Dispatcher: Codeunit "Dispatcher ori";
    begin
        Dispatcher.Execute(MessageType, MessageVersion, Subject, Source, ContentType, RequestContent, ResponseContent, ResponseContentType);
    end;

    procedure EnqueueAndProcess(MessageType: Enum "Message Type ori"; MessageVersion: Enum "Message Version ori"; Subject: Text; Source: Text; ContentType: Text; var RequestContent: BigText; var TaskId: Guid; LanguageId: Integer; var MessageId: Guid; var ResponseContent: BigText; var ResponseContentType: Text[100]; var ResponseTime: Duration)
    var
        Dispatcher: Codeunit "Dispatcher ori";
    begin
        Dispatcher.EnqueueAndProcess(MessageType, MessageVersion, Subject, Source, ContentType, RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
    end;
}
