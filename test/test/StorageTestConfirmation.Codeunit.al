namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Runs test dispatches through Foundation's counted-confirmation preview protocol.</summary>
codeunit 96219 "Storage Test Confirmation ori"
{
    /// <summary>Runs the request and confirms only when Foundation returns a no-write preview.</summary>
    /// <param name="Dispatcher">The public Foundation dispatcher.</param>
    /// <param name="MessageType">The registered message type being dispatched.</param>
    /// <param name="RequestJson">The request payload to dispatch.</param>
    /// <param name="LanguageId">Optional queue language; zero uses direct dispatch.</param>
    /// <param name="UseCommittedExecute">True uses Execute with OmitCommit=false; false preserves the default uncommitted Execute overload.</param>
    procedure Dispatch(var Dispatcher: Codeunit "Dispatcher ori"; MessageType: Enum "Message Type ori"; var RequestJson: JsonObject; LanguageId: Integer; UseCommittedExecute: Boolean) ResponseJson: JsonObject
    var
        LibraryAssert: Codeunit "Library Assert";
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
        ExpectedCountToken: JsonToken;
        ExpectedCount: Integer;
        ConfirmedRequestJson: JsonObject;
    begin
        SendRequest(Dispatcher, MessageType, RequestJson, LanguageId, UseCommittedExecute, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        LibraryAssert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'The public dispatcher must return JSON.');
        if RequestJson.Contains('expectedCount') then
            exit;
        if ReadText(ResponseJson, 'code') <> 'ConfirmationRequired' then
            exit;

        if not ResponseJson.Get('expected', ExpectedCountToken) then
            exit;
        if not ExpectedCountToken.IsValue() then
            exit;
        if not Evaluate(ExpectedCount, ExpectedCountToken.AsValue().AsText()) then
            exit;

        RequestJson.WriteTo(RequestText);
        if not ConfirmedRequestJson.ReadFrom(RequestText) then
            exit;
        ConfirmedRequestJson.Add('expectedCount', ExpectedCount);
        SendRequest(Dispatcher, MessageType, ConfirmedRequestJson, LanguageId, UseCommittedExecute, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Clear(ResponseJson);
        LibraryAssert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'The public dispatcher must return JSON.');
    end;

    local procedure SendRequest(var Dispatcher: Codeunit "Dispatcher ori"; MessageType: Enum "Message Type ori"; RequestJson: JsonObject; LanguageId: Integer; UseCommittedExecute: Boolean; var ResponseContent: BigText; var ResponseContentType: Text[100])
    var
        RequestContent: BigText;
        RequestText: Text;
        MessageVersion: Enum "Message Version ori";
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
    begin
        Clear(ResponseContent);
        Clear(ResponseContentType);
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        if LanguageId > 0 then begin
            Commit();
            Dispatcher.EnqueueAndProcess(MessageType, MessageVersion, '', '', 'application/json', RequestContent, TaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
            exit;
        end;
        if UseCommittedExecute then
            Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType, false)
        else
            Dispatcher.Execute(MessageType, MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
    end;

    local procedure ReadText(ResponseJson: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;
}
