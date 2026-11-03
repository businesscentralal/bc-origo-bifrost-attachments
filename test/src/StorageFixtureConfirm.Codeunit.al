/// <summary>
/// Test helper that adds Foundation's explicit single-subject confirmation to fixture calls of
/// irreversible Attachments message types (#205).
/// </summary>
codeunit 96276 "Storage Fixture Confirm ori"
{
    Access = Internal;

    /// <summary>Returns the request text, confirmed with <c>expectedCount</c> = 1 for an irreversible type on Foundation 28.0.11 and later.</summary>
    /// <param name="MessageType">The fixture operation whose original assertions must execute.</param>
    /// <param name="RequestJson">The caller's request. It is never modified, because callers reuse it for later types that do not declare expectedCount.</param>
    procedure ConfirmedText(MessageType: Enum "Message Type ori"; RequestJson: JsonObject) RequestText: Text
    var
        ConfirmedJson: JsonObject;
        Token: JsonToken;
    begin
        Token := RequestJson.Clone();
        ConfirmedJson := Token.AsObject();
        AddFixtureConfirmation(MessageType, ConfirmedJson);
        ConfirmedJson.WriteTo(RequestText);
    end;

    /// <summary>Text overload of <c>ConfirmedText</c> for dispatch helpers that already serialized the request.</summary>
    procedure ConfirmedPayload(MessageType: Enum "Message Type ori"; Payload: Text): Text
    var
        RequestJson: JsonObject;
    begin
        if not RequestJson.ReadFrom(Payload) then
            exit(Payload);
        exit(ConfirmedText(MessageType, RequestJson));
    end;

    local procedure AddFixtureConfirmation(MessageType: Enum "Message Type ori"; var RequestJson: JsonObject)
    var
        FoundationInfo: ModuleInfo;
        FoundationAppId: Guid;
    begin
        if RequestJson.Contains('expectedCount') then
            exit;
        FoundationAppId := '7505e808-6e52-4b96-a328-82573391297a';
        if not NavApp.GetModuleInfo(FoundationAppId, FoundationInfo) then
            exit;
        if FoundationInfo.AppVersion() < Version.Create(28, 0, 11, 0) then
            exit;
        // Foundation's default counter is one request subject; the explicit value keeps the
        // existing business-effect and refusal assertions reachable.
        case MessageType of
            MessageType::"DataExchange.Definition.Export",
            MessageType::"DataExchange.PaymentExport.Run",
            MessageType::"Storage.File.Delete",
            MessageType::"Storage.Directory.Delete",
            MessageType::"Storage.Attachment.Restore",
            MessageType::"Storage.Attachment.Offload",
            MessageType::"Storage.Upload.Commit",
            MessageType::"Storage.File.Create",
            MessageType::"Storage.File.Copy",
            MessageType::"Storage.File.Move",
            MessageType::"Storage.Directory.Create":
                RequestJson.Add('expectedCount', 1);
        end;
    end;
}
