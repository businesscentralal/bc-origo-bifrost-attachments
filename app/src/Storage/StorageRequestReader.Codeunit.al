namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.Text;
using System.Utilities;

/// <summary>
/// Reads the request values of the storage message types and collects every problem on the
/// message argument instead of stopping at the first one. The answers use the same codes and
/// wording as the typed readers of Bifröst Foundation: a missing required value is
/// <c>MissingParameter</c>, a value of the wrong form is <c>InvalidParameterFormat</c> (with
/// <c>received</c> and <c>expected</c>), a value of the right form that is not allowed is
/// <c>InvalidParameter</c>, and content over the size a single call can carry is
/// <c>LimitExceeded</c>. A present but invalid value never falls back to a default.
/// Read every value of a request first, then call <see cref="RespondIfErrors"/> once.
/// </summary>
codeunit 10035682 "Storage Request Reader ori"
{
    Access = Internal;

    var
        RequiredParameterMissingErr: Label 'Required parameter "%1" is missing.', Comment = '%1 = parameter name, is-IS=Nauðsynleg færibreyta "%1" vantar.';
        InvalidParameterFormatErr: Label 'Parameter "%1" has value "%2", which is not a valid %3. Expected %4.', Comment = '%1 = parameter, %2 = received value, %3 = type, %4 = expected format, is-IS=Færibreyta "%1" hefur gildið "%2", sem er ekki í gildu sniði (%3). Væntanlegt er %4.';
        NotAValueErr: Label 'Parameter "%1" must be a single value, not a JSON object or array.', Comment = '%1 = parameter, is-IS=Færibreyta "%1" verður að vera eitt gildi, ekki JSON-hlutur eða fylki.';
        UnsafePathErr: Label 'Parameter "%1" has an unsafe or ambiguous path "%2". Use slash-separated names without relative segments, empty inner segments, control characters or backslashes.', Comment = '%1 = parameter, %2 = rejected path, is-IS=Færibreytan "%1" hefur óörugga eða tvíræða slóð "%2". Notaðu heiti aðskilin með skástrikum án afstæðra hluta, tómra innri hluta, stýristafa eða bakskástrika.';
        NegativeValueErr: Label 'Parameter "%1" has value %2, but it cannot be negative.', Comment = '%1 = parameter, %2 = received value, is-IS=Færibreyta "%1" hefur gildið %2 en það má ekki vera neikvætt.';
        NotBase64Err: Label 'Parameter "%1" is not valid base64 content.', Comment = '%1 = parameter, is-IS=Færibreyta "%1" er ekki gilt base64-innihald.';
        ContentTooLargeErr: Label 'Parameter "%1" carries about %2 bytes, more than the %3 bytes one call can carry.', Comment = '%1 = parameter, %2 = approximate size in bytes, %3 = maximum size in bytes, is-IS=Færibreyta "%1" ber um %2 bæti, meira en þau %3 bæti sem eitt kall getur borið.';
        TextTooLongErr: Label 'Parameter "%1" has %2 characters; the maximum is %3. Nothing was changed.', Comment = '%1 = parameter, %2 = length, %3 = maximum length, is-IS=Færibreytan "%1" er %2 stafir; hámarkið er %3. Engu var breytt.';
        TextLengthExpectedLbl: Label 'at most %1 characters', Comment = '%1 = maximum length, is-IS=í mesta lagi %1 stafir';
        ShortenTextLbl: Label 'Shorten the file name or folder path and try again; storage addresses cannot be truncated.', Comment = 'is-IS=Styttu skráarheitið eða möppuslóðina og reyndu aftur; ekki má stytta geymsluslóðir sjálfkrafa.';
        InvalidFileNameErr: Label 'Parameter "fileName" must be a file name without folders or relative segments.', Comment = 'is-IS=Færibreytan "fileName" verður að vera skráarheiti án mappa eða afstæðra slóðarhluta.';
        FileNameExpectedLbl: Label 'a nonempty file name without slash or backslash', Comment = 'is-IS=skráarheiti sem er ekki tómt og inniheldur hvorki skástrik né bakskástrik';
        ProblemsInRequestErr: Label '%1 problems in the request. Nothing was changed.', Comment = '%1 = number of problems, is-IS=%1 vandamál í beiðninni. Engu var breytt.';
        TextExpectedLbl: Label 'a JSON string', Comment = 'is-IS=JSON-strengur';
        IntegerTypeLbl: Label 'integer', Comment = 'is-IS=heiltala';
        IntegerExpectedLbl: Label 'an integer, e.g. 3', Comment = 'is-IS=heiltala, t.d. 3';
        NonNegativeExpectedLbl: Label '0 or more', Comment = 'is-IS=0 eða meira';
        GuidTypeLbl: Label 'GUID', Comment = 'is-IS=GUID';
        GuidExpectedLbl: Label 'a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301', Comment = 'is-IS=GUID, t.d. 3f2504e0-4f89-11d3-9a0c-0305e82c3301';
        PathExpectedLbl: Label 'a path relative to the connection base path, without "." or ".." segments', Comment = 'is-IS=slóð miðað við grunnslóð tengingarinnar, án "." eða ".." hluta';
        Base64ExpectedLbl: Label 'base64 content', Comment = 'is-IS=base64-innihald';
        ContentLimitExpectedLbl: Label 'at most %1 bytes (240 MiB)', Comment = '%1 = maximum size in bytes, is-IS=í mesta lagi %1 bæti (240 MiB)';
        SendIntegerFormatLbl: Label 'Send the value as an integer.', Comment = 'is-IS=Sendu gildið sem heiltölu.';
        SendGuidFormatLbl: Label 'Send the value as a GUID, as returned by the call that created it.', Comment = 'is-IS=Sendu gildið sem GUID, eins og kallið sem stofnaði það skilaði því.';
        SendRelativePathLbl: Label 'Send a path inside the connection, e.g. invoices/2026/INV-001.pdf.', Comment = 'is-IS=Sendu slóð innan tengingarinnar, t.d. invoices/2026/INV-001.pdf.';
        SendBase64Lbl: Label 'Encode the file bytes as standard base64 and send them again.', Comment = 'is-IS=Kóðaðu bæti skrárinnar sem venjulegt base64 og sendu þau aftur.';
        SplitIntoChunksLbl: Label 'Send the file in parts with Storage.Upload.Begin, Storage.Upload.Append and Storage.Upload.Commit.', Comment = 'is-IS=Sendu skrána í hlutum með Storage.Upload.Begin, Storage.Upload.Append og Storage.Upload.Commit.';

    /// <summary>
    /// Reads a text value. Absent, JSON null and an empty string count as not given: a required
    /// value then adds <c>MissingParameter</c>; an optional one leaves <paramref name="Value"/> empty.
    /// </summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="ParameterName">The JSON property to read.</param>
    /// <param name="Required">Whether the value must be given.</param>
    /// <param name="Value">Out: the value, or an empty text.</param>
    /// <returns>True when the value is usable (given, or optional and not given).</returns>
    procedure ReadText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
    begin
        Value := '';
        if not RequestJson.Get(ParameterName, Token) then
            exit(AcceptAbsent(Argument, ParameterName, Required));
        if not Token.IsValue() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotAValueErr, ParameterName), ParameterName, TokenText(Token), TextExpectedLbl, '');
            exit(false);
        end;
        if Token.AsValue().IsNull() then
            exit(AcceptAbsent(Argument, ParameterName, Required));
        Value := Token.AsValue().AsText();
        if Value = '' then
            exit(AcceptAbsent(Argument, ParameterName, Required));
        exit(true);
    end;

    /// <summary>
    /// Reads a storage path and rejects a path with a <c>.</c> or <c>..</c> segment with
    /// <c>InvalidParameter</c>, because the connection's base path is its only confinement boundary.
    /// </summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="ParameterName">The JSON property to read.</param>
    /// <param name="Required">Whether the value must be given.</param>
    /// <param name="Path">Out: the path, or an empty text.</param>
    /// <returns>True when the path is usable.</returns>
    procedure ReadPath(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; var Path: Text): Boolean
    begin
        if not ReadText(Argument, RequestJson, ParameterName, Required, Path) then
            exit(false);
        if not CheckPath(Argument, ParameterName, Path) then
            exit(false);
        Path := CanonicalPath(Path);
        exit(true);
    end;

    /// <summary>Adds <c>InvalidParameter</c> for a path that walks out of the connection's base path.</summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="ParameterName">The request parameter the path came from.</param>
    /// <param name="Path">The path to check.</param>
    /// <returns>True when the path carries no relative segment.</returns>
    procedure CheckPath(var Argument: Record "Message Argument ori"; ParameterName: Text; Path: Text): Boolean
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
    begin
        if not CheckTextLength(Argument, ParameterName, Path, 2048) then
            exit(false);
        if RequestMgt.PathIsSafe(Path) then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnsafePathErr, ParameterName, Path), ParameterName, Path, PathExpectedLbl, SendRelativePathLbl);
        exit(false);
    end;

    /// <summary>
    /// Reads an integer: a JSON number without a fraction, or a string of digits with an optional
    /// leading minus. When the value is not given, <paramref name="Value"/> keeps the caller's default.
    /// </summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="ParameterName">The JSON property to read.</param>
    /// <param name="Required">Whether the value must be given.</param>
    /// <param name="Value">In: the default. Out: the value read.</param>
    /// <returns>True when the value is usable.</returns>
    procedure ReadInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; var Value: Integer): Boolean
    var
        Token: JsonToken;
        RawText: Text;
        Parsed: Integer;
    begin
        if not RequestJson.Get(ParameterName, Token) then
            exit(AcceptAbsent(Argument, ParameterName, Required));
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                exit(AcceptAbsent(Argument, ParameterName, Required));
        RawText := TokenText(Token);
        if RawText = '' then
            exit(AcceptAbsent(Argument, ParameterName, Required));
        if Token.IsValue() and IsDigitRun(RawText) then
            if Evaluate(Parsed, RawText, 9) then begin
                Value := Parsed;
                exit(true);
            end;
        AddFormatError(Argument, ParameterName, RawText, IntegerTypeLbl, IntegerExpectedLbl, SendIntegerFormatLbl);
        exit(false);
    end;

    /// <summary>Reads an integer that may not be negative, see <see cref="ReadInteger"/>.</summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="ParameterName">The JSON property to read.</param>
    /// <param name="Required">Whether the value must be given.</param>
    /// <param name="Value">In: the default. Out: the value read.</param>
    /// <returns>True when the value is usable.</returns>
    procedure ReadNonNegativeInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; var Value: Integer): Boolean
    begin
        if not ReadInteger(Argument, RequestJson, ParameterName, Required, Value) then
            exit(false);
        if Value >= 0 then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NegativeValueErr, ParameterName, Format(Value, 0, 9)), ParameterName, Format(Value, 0, 9), NonNegativeExpectedLbl, '');
        exit(false);
    end;

    /// <summary>Reads a GUID such as an <c>uploadId</c> or a <c>systemId</c>.</summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="ParameterName">The JSON property to read.</param>
    /// <param name="Required">Whether the value must be given.</param>
    /// <param name="Value">Out: the GUID, or a null GUID when not given.</param>
    /// <returns>True when the value is usable.</returns>
    procedure ReadGuid(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; var Value: Guid): Boolean
    var
        RawText: Text;
    begin
        Clear(Value);
        if not ReadText(Argument, RequestJson, ParameterName, Required, RawText) then
            exit(false);
        if RawText = '' then
            exit(true);
        if Evaluate(Value, RawText) then
            exit(true);
        AddFormatError(Argument, ParameterName, RawText, GuidTypeLbl, GuidExpectedLbl, SendGuidFormatLbl);
        exit(false);
    end;

    /// <summary>
    /// Reads base64 content and decodes it into <paramref name="TempBlob"/>. Content over
    /// <see cref="MaxContentBytes"/> adds <c>LimitExceeded</c> without decoding it; content that is
    /// not base64 adds <c>InvalidParameterFormat</c>. The content itself is never echoed back.
    /// </summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="ParameterName">The JSON property to read.</param>
    /// <param name="Required">Whether the content must be given.</param>
    /// <param name="TempBlob">Out: the decoded content.</param>
    /// <returns>True when the content is usable (decoded, or optional and not given).</returns>
    procedure ReadBase64Content(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; var TempBlob: Codeunit "Temp Blob"): Boolean
    var
        ContentBase64: Text;
        ApproximateBytes: BigInteger;
    begin
        Clear(TempBlob);
        if not ReadText(Argument, RequestJson, ParameterName, Required, ContentBase64) then
            exit(false);
        if ContentBase64 = '' then
            exit(true);
        ApproximateBytes := StrLen(ContentBase64);
        ApproximateBytes := ApproximateBytes div 4 * 3;
        if not IsWithinContentLimit(ApproximateBytes) then begin
            Argument.AddError("Bifrost Error Code ori"::LimitExceeded,
                StrSubstNo(ContentTooLargeErr, ParameterName, Format(ApproximateBytes, 0, 9), Format(MaxContentBytes(), 0, 9)),
                ParameterName, Format(ApproximateBytes, 0, 9), StrSubstNo(ContentLimitExpectedLbl, Format(MaxContentBytes(), 0, 9)), SplitIntoChunksLbl);
            exit(false);
        end;
        if TryDecodeBase64(ContentBase64, TempBlob) then
            exit(true);
        Clear(TempBlob);
        Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotBase64Err, ParameterName), ParameterName, '', Base64ExpectedLbl, SendBase64Lbl);
        exit(false);
    end;

    /// <summary>
    /// The most content one call can carry, in bytes: 240 MiB. The content travels as base64 in
    /// the request body, which Business Central online caps at 350 MB per OData request; 240 MiB
    /// encodes to about 336 MB and leaves room for the rest of the request.
    /// </summary>
    /// <returns>251,658,240.</returns>
    procedure MaxContentBytes(): Integer
    begin
        exit(251658240);
    end;

    /// <summary>Tells whether a content size fits in one call, see <see cref="MaxContentBytes"/>.</summary>
    /// <param name="ContentBytes">The (decoded) content size in bytes.</param>
    /// <returns>True when the size is within the limit.</returns>
    procedure IsWithinContentLimit(ContentBytes: BigInteger): Boolean
    begin
        exit(ContentBytes <= MaxContentBytes());
    end;

    /// <summary>
    /// Answers every collected problem at once when there is at least one: a single problem is
    /// answered on its own; several are listed in <c>errors[]</c> under <c>MultipleErrors</c>.
    /// </summary>
    /// <param name="Argument">The message argument that collected the problems.</param>
    /// <returns>True when an error response was written; the caller then stops.</returns>
    procedure RespondIfErrors(var Argument: Record "Message Argument ori"): Boolean
    begin
        if not Argument.HasCollectedErrors() then
            exit(false);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, StrSubstNo(ProblemsInRequestErr, Argument.GetCollectedErrorsJson().Count()));
        exit(true);
    end;

    /// <summary>Collects a length error instead of silently truncating a stored address or name.</summary>
    /// <param name="Argument">The argument collecting validation errors.</param>
    /// <param name="ParameterName">The offending parameter or generated address.</param>
    /// <param name="TextValue">The complete value to validate.</param>
    /// <param name="MaximumLength">The destination capacity.</param>
    /// <returns>True when the complete value fits.</returns>
    internal procedure CheckTextLength(var Argument: Record "Message Argument ori"; ParameterName: Text; TextValue: Text; MaximumLength: Integer): Boolean
    begin
        if StrLen(TextValue) <= MaximumLength then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TextTooLongErr, ParameterName, StrLen(TextValue), MaximumLength), ParameterName, Format(StrLen(TextValue), 0, 9), StrSubstNo(TextLengthExpectedLbl, MaximumLength), ShortenTextLbl);
        exit(false);
    end;

    /// <summary>Checks an address sink capacity without truncation; malformed addresses use InvalidParameter.</summary>
    internal procedure CheckAddressLength(var Argument: Record "Message Argument ori"; ParameterName: Text; Address: Text; Capacity: Integer): Boolean
    begin
        if StrLen(Address) <= Capacity then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TextTooLongErr, ParameterName, StrLen(Address), Capacity), ParameterName, Format(StrLen(Address), 0, 9), StrSubstNo(TextLengthExpectedLbl, Capacity), ShortenTextLbl);
        exit(false);
    end;

    /// <summary>Checks a complete filename before a session, attachment or remote file is written.</summary>
    /// <param name="Argument">The argument collecting validation errors.</param>
    /// <param name="FileName">The complete filename, including its extension.</param>
    /// <returns>True when the filename fits the storage field and contains no folder.</returns>
    internal procedure CheckFileName(var Argument: Record "Message Argument ori"; FileName: Text): Boolean
    var
        Link: Record "Storage Attachment Link ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
    begin
        if not CheckTextLength(Argument, 'fileName', FileName, MaxStrLen(Link."File Name")) then
            exit(false);
        if (FileName <> '') and not FileName.Contains('/') and not FileName.Contains('\') and RequestMgt.PathIsSafe(FileName) then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, InvalidFileNameErr, 'fileName', FileName, FileNameExpectedLbl, SendRelativePathLbl);
        exit(false);
    end;

    /// <summary>Validates the complete relative and base-prefixed address before storage or database writes.</summary>
    /// <param name="Argument">The argument collecting validation errors.</param>
    /// <param name="StorageSetup">The selected storage connection and base path.</param>
    /// <param name="ParameterName">The path parameter to identify in errors.</param>
    /// <param name="Path">The complete relative path; returns its canonical spelling.</param>
    /// <param name="AllowRoot">Whether this is a directory operation that may address the base root.</param>
    /// <returns>True when the address is valid and fits storage fields.</returns>
    internal procedure CheckStoragePath(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; ParameterName: Text; var Path: Text; AllowRoot: Boolean): Boolean
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
        BasePath: Text;
        FullPath: Text;
    begin
        if not CheckPath(Argument, ParameterName, Path) then
            exit(false);
        Path := RequestMgt.CanonicalPath(Path);
        if (not AllowRoot) and (Path = '') then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, InvalidFileNameErr, ParameterName, Path, FileNameExpectedLbl, SendRelativePathLbl);
            exit(false);
        end;
        BasePath := RequestMgt.CanonicalPath(StorageSetup."Base Path");
        if not CheckPath(Argument, 'basePath', BasePath) then
            exit(false);
        FullPath := Path;
        if BasePath <> '' then begin
            FullPath := BasePath;
            if Path <> '' then
                FullPath += '/' + Path;
        end;
        exit(CheckTextLength(Argument, ParameterName, FullPath, 2048));
    end;

    local procedure CanonicalPath(Path: Text): Text
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
    begin
        exit(RequestMgt.CanonicalPath(Path));
    end;

    /// <summary>Parses request data read-only and collects malformed or non-object input.</summary>
    /// <param name="Argument">The request and Foundation collector.</param>
    /// <param name="RequestJson">Receives the parsed request object.</param>
    /// <returns>True when the data is a JSON object.</returns>
    internal procedure ReadMutationRequest(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject): Boolean
    var
        InvalidRequestErr: Label 'The request data must be a JSON object.', Comment = 'is-IS=Gögn beiðninnar verða að vera JSON-hlutur.';
        InvalidRequestLbl: Label 'malformed JSON or a non-object value', Comment = 'is-IS=ógilt JSON eða gildi sem er ekki hlutur';
        ObjectExpectedLbl: Label 'a JSON object containing the request parameters', Comment = 'is-IS=JSON-hlutur sem inniheldur færibreytur beiðninnar';
        SendObjectLbl: Label 'Send the parameters as a valid JSON object and retry.', Comment = 'is-IS=Sendu færibreyturnar sem gildan JSON-hlut og reyndu aftur.';
    begin
        Clear(RequestJson);
        if TryReadMutationRequest(Argument, RequestJson) then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidRequestErr, 'data', InvalidRequestLbl, ObjectExpectedLbl, SendObjectLbl);
        exit(false);
    end;

    /// <summary>Reads raw JSON strings without coercion or truncation. Optional absence is accepted; explicit null is refused.</summary>
    /// <param name="Argument">The Foundation error collector.</param>
    /// <param name="RequestJson">The parsed request.</param>
    /// <param name="ParameterName">The exact wire key.</param>
    /// <param name="Required">Whether absence or an empty string is an error.</param>
    /// <param name="MaxLength">The positive raw character limit.</param>
    /// <param name="ParsedText">Receives the valid text, otherwise empty.</param>
    /// <returns>True for valid text or an absent optional key.</returns>
    internal procedure ReadMutationText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; Required: Boolean; MaxLength: Integer; var ParsedText: Text): Boolean
    var
        InputToken: JsonToken;
        Written: Text;
        RawText: Text;
        ExpectedText: Text;
        RequiredErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er nauðsynleg.';
        InvalidTextErr: Label 'Parameter "%1" must be a JSON string.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" verður að vera JSON-strengur.';
        TooLongErr: Label 'Parameter "%1" exceeds the maximum of %2 characters.', Comment = '%1 = parameter name, %2 = maximum length||is-IS=Færibreytan "%1" er lengri en leyfilegt hámark, %2 stafir.';
        BoundedStringLbl: Label 'a JSON string of at most %1 characters', Comment = '%1 = maximum length||is-IS=JSON-strengur sem er mest %1 stafir';
        MissingLbl: Label 'not supplied', Comment = 'is-IS=ekki gefið upp';
        SendTextLbl: Label 'Send "%1" as %2 and retry.', Comment = '%1 = parameter name, %2 = expected format||is-IS=Sendu "%1" sem %2 og reyndu aftur.';
    begin
        ParsedText := '';
        ExpectedText := StrSubstNo(BoundedStringLbl, MaxLength);
        if not RequestJson.Get(ParameterName, InputToken) then begin
            if not Required then
                exit(true);
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(RequiredErr, ParameterName), ParameterName, MissingLbl, ExpectedText, StrSubstNo(SendTextLbl, ParameterName, ExpectedText));
            exit(false);
        end;
        // JSON serialization starts with a quote only for strings. AsText alone also coerces numbers and booleans.
        InputToken.WriteTo(Written);
        if not Written.StartsWith('"') then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidTextErr, ParameterName), ParameterName, Written, ExpectedText, StrSubstNo(SendTextLbl, ParameterName, ExpectedText));
            exit(false);
        end;
        RawText := InputToken.AsValue().AsText();
        if Required and (StrLen(RawText) = 0) then begin
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(RequiredErr, ParameterName), ParameterName, Written, ExpectedText, StrSubstNo(SendTextLbl, ParameterName, ExpectedText));
            exit(false);
        end;
        if StrLen(RawText) > MaxLength then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongErr, ParameterName, MaxLength), ParameterName, RawText, ExpectedText, StrSubstNo(SendTextLbl, ParameterName, ExpectedText));
            exit(false);
        end;
        ParsedText := RawText;
        exit(true);
    end;

    /// <summary>Reads a canonical Code20 key without silently uppercasing or trimming caller input.</summary>
    /// <param name="Argument">The Foundation error collector.</param>
    /// <param name="RequestJson">The parsed request.</param>
    /// <param name="ParameterName">The exact required wire key.</param>
    /// <param name="ParsedCode">Receives the unchanged canonical key, otherwise empty.</param>
    /// <returns>True only for a nonempty JSON string that already has its BC Code20 spelling.</returns>
    internal procedure ReadMutationCode(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; ParameterName: Text; var ParsedCode: Code[20]): Boolean
    var
        RawText: Text;
        CanonicalCode: Code[2048];
        Received: Text;
        InputToken: JsonToken;
        CanonicalErr: Label 'Parameter "%1" must use its canonical Business Central code.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" verður að nota staðlaðan Business Central-kóða.';
        CanonicalExpectedLbl: Label 'an uppercase code of at most 20 characters without surrounding spaces', Comment = 'is-IS=kóði með hástöfum, mest 20 stafir og án bila í upphafi eða lokin';
        SendCanonicalLbl: Label 'Use the exact code returned by the corresponding list method; the canonical spelling of this value is "%1".', Comment = '%1 = canonical code||is-IS=Notaðu nákvæmlega kóðann sem samsvarandi listaaðferð skilar; staðlað form þessa gildis er "%1".';
    begin
        Clear(ParsedCode);
        if not ReadMutationText(Argument, RequestJson, ParameterName, true, MaxStrLen(ParsedCode), RawText) then
            exit(false);
        // The raw bound was checked before this scratch conversion. Compare character ordinals, never AL text equality.
        CanonicalCode := RawText;
        if not SameMutationCodeOrdinals(RawText, CanonicalCode) then begin
            Received := RawText;
            if StrLen(CanonicalCode) = 0 then begin
                RequestJson.Get(ParameterName, InputToken);
                InputToken.WriteTo(Received);
            end;
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(CanonicalErr, ParameterName), ParameterName, Received, CanonicalExpectedLbl, StrSubstNo(SendCanonicalLbl, CanonicalCode));
            exit(false);
        end;
        ParsedCode := CanonicalCode;
        exit(true);
    end;

    local procedure SameMutationCodeOrdinals(RawText: Text; CanonicalCode: Code[2048]): Boolean
    var
        CharacterIndex: Integer;
        RawOrdinal: Integer;
        CanonicalOrdinal: Integer;
    begin
        if StrLen(RawText) <> StrLen(CanonicalCode) then
            exit(false);
        for CharacterIndex := 1 to StrLen(RawText) do begin
            RawOrdinal := RawText[CharacterIndex];
            CanonicalOrdinal := CanonicalCode[CharacterIndex];
            if RawOrdinal <> CanonicalOrdinal then
                exit(false);
        end;
        exit(true);
    end;

    [TryFunction]
    local procedure TryReadMutationRequest(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject)
    begin
        RequestJson := Argument.GetRequestJson();
    end;

    local procedure AcceptAbsent(var Argument: Record "Message Argument ori"; ParameterName: Text; Required: Boolean): Boolean
    begin
        if not Required then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(RequiredParameterMissingErr, ParameterName), ParameterName, '', '', '');
        exit(false);
    end;

    local procedure AddFormatError(var Argument: Record "Message Argument ori"; ParameterName: Text; Received: Text; TypeName: Text; Expected: Text; NextStep: Text)
    begin
        Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidParameterFormatErr, ParameterName, Received, TypeName, Expected), ParameterName, Received, Expected, NextStep);
    end;

    local procedure TokenText(Token: JsonToken) Result: Text
    begin
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        Token.WriteTo(Result);
    end;

    local procedure IsDigitRun(Value: Text): Boolean
    var
        Index: Integer;
        FirstDigit: Integer;
    begin
        FirstDigit := 1;
        if Value.StartsWith('-') then
            FirstDigit := 2;
        if StrLen(Value) < FirstDigit then
            exit(false);
        for Index := FirstDigit to StrLen(Value) do
            if not (Value[Index] in ['0' .. '9']) then
                exit(false);
        exit(true);
    end;

    [TryFunction]
    local procedure TryDecodeBase64(ContentBase64: Text; var TempBlob: Codeunit "Temp Blob")
    var
        Base64Convert: Codeunit "Base64 Convert";
        ContentOutStream: OutStream;
    begin
        TempBlob.CreateOutStream(ContentOutStream);
        Base64Convert.FromBase64(ContentBase64, ContentOutStream);
    end;
}
