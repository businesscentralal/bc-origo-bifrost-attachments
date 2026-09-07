namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.ExternalFileStorage;
using System.Text;
using System.Utilities;

/// <summary>
/// Shared helper for the storage message-type implementations. Resolves the
/// <c>storageCode</c> to a <c>Bifrost Storage Setup</c> row and its
/// <c>Bifrost Storage Connector</c> implementation, reads common request parameters, runs each
/// storage action, and packages every result into the uniform Bifrost response
/// envelope <c>{ status, data | error }</c>. Binary file content is carried as base64.
/// </summary>
codeunit 10035662 "Storage Request Mgt ori"
{
    Access = Internal;

    var
        MissingParamErr: Label 'Missing required ''%1'' in the request.', Comment = '%1 = parameter name', Locked = true;
        UnknownCodeErr: Label 'No storage connection is configured for storageCode ''%1''.', Comment = '%1 = storage code', Locked = true;
        DisabledCodeErr: Label 'The storage connection ''%1'' is disabled.', Comment = '%1 = storage code', Locked = true;
        UnsafePathErr: Label 'The path ''%1'' is not allowed: no path segment may be ''.'' or ''..''.', Comment = '%1 = the rejected path', Locked = true;

    /// <summary>
    /// Rejects a caller-supplied path that tries to walk out of the connection's base path.
    /// The base path is the only confinement boundary a storage connection has, so a relative
    /// segment must never reach the connector. On rejection the error response is written onto
    /// the argument and false is returned.
    /// </summary>
    /// <param name="Argument">The Bifrost argument (receives the error response on rejection).</param>
    /// <param name="Path">The caller-supplied path to check.</param>
    /// <returns>True when the path carries no relative segment.</returns>
    procedure CheckPath(var Argument: Record "Message Argument ori"; Path: Text): Boolean
    begin
        if PathIsSafe(Path) then
            exit(true);
        Argument.RespondWithError(StrSubstNo(UnsafePathErr, Path));
        exit(false);
    end;

    /// <summary>
    /// Tests whether a path is free of relative segments. Both slash directions are considered,
    /// because the connectors accept either.
    /// </summary>
    /// <param name="Path">The path to test.</param>
    /// <returns>True when no segment of the path is '.' or '..'.</returns>
    procedure PathIsSafe(Path: Text): Boolean
    var
        Segments: List of [Text];
        Segment: Text;
    begin
        Segments := ConvertStr(Path, '\', '/').Split('/');
        foreach Segment in Segments do
            if (Segment = '.') or (Segment = '..') then
                exit(false);
        exit(true);
    end;

    /// <summary>Raises the "unsafe path" error. Used where a path is built rather than responded to.</summary>
    /// <param name="Path">The rejected path.</param>
    procedure ThrowUnsafePath(Path: Text)
    begin
        Error(UnsafePathErr, Path);
    end;

    /// <summary>
    /// Resolves the request's <c>storageCode</c> to a configured, enabled storage setup row
    /// and its connector implementation. On failure it writes an error response onto the
    /// argument and returns false.
    /// </summary>
    /// <param name="Argument">The Bifrost argument (receives the error response on failure).</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="StorageSetup">Out: the resolved setup row.</param>
    /// <param name="Connector">Out: the resolved connector implementation.</param>
    /// <returns>True when a usable storage connection was resolved.</returns>
    procedure ResolveSetup(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var StorageSetup: Record "Storage Setup ori"; var Connector: Interface "Storage Connector ori"): Boolean
    var
        StorageCode: Text;
    begin
        if not RequireParam(Argument, RequestJson, 'storageCode', StorageCode) then
            exit(false);
        if not StorageSetup.Get(CopyStr(StorageCode, 1, MaxStrLen(StorageSetup."Code"))) then begin
            Argument.RespondWithError(StrSubstNo(UnknownCodeErr, StorageCode));
            exit(false);
        end;
        if not StorageSetup.Enabled then begin
            Argument.RespondWithError(StrSubstNo(DisabledCodeErr, StorageCode));
            exit(false);
        end;
        Connector := StorageSetup."Storage Type";
        exit(true);
    end;

    /// <summary>Reads a string property from a JSON object, returning '' when absent or null.</summary>
    /// <param name="RequestJson">The JSON object to read from.</param>
    /// <param name="PropertyName">The property name to read.</param>
    /// <returns>The property value as text, or an empty string.</returns>
    procedure GetText(RequestJson: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    /// <summary>
    /// Reads a required string parameter. On failure it writes an error response onto the
    /// argument and returns false.
    /// </summary>
    /// <param name="Argument">The Bifrost argument (receives the error response on failure).</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="PropertyName">The required property name.</param>
    /// <param name="Value">Out: the parameter value.</param>
    /// <returns>True when the parameter was present and non-empty.</returns>
    procedure RequireParam(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; PropertyName: Text; var Value: Text): Boolean
    begin
        Value := GetText(RequestJson, PropertyName);
        if Value = '' then begin
            Argument.RespondWithError(StrSubstNo(MissingParamErr, PropertyName));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Lists files or directories under a path and responds with an entries array.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The directory whose contents are listed.</param>
    /// <param name="EntryType">Whether files or directories are listed.</param>
    procedure ExecuteList(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type")
    var
        TempFileAccountContent: Record "File Account Content" temporary;
        DataObject: JsonObject;
        EntriesArray: JsonArray;
    begin
        if not CheckPath(Argument, Path) then
            exit;
        if not TryList(StorageSetup, Connector, Path, EntryType, TempFileAccountContent) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        if TempFileAccountContent.FindSet() then
            repeat
                EntriesArray.Add(EntryToJson(TempFileAccountContent));
            until TempFileAccountContent.Next() = 0;
        DataObject.Add('path', Path);
        DataObject.Add('entries', EntriesArray);
        RespondSuccess(Argument, DataObject);
    end;

    /// <summary>Downloads a file and responds with its base64 content.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The file path to read.</param>
    procedure ExecuteGetFile(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        DataObject: JsonObject;
        ContentInStream: InStream;
    begin
        if not CheckPath(Argument, Path) then
            exit;
        if not TryGetFile(StorageSetup, Connector, Path, TempBlob) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        TempBlob.CreateInStream(ContentInStream);
        DataObject.Add('path', Path);
        DataObject.Add('contentLength', TempBlob.Length());
        DataObject.Add('contentBase64', Base64Convert.ToBase64(ContentInStream));
        RespondSuccess(Argument, DataObject);
    end;

    /// <summary>Uploads base64 content to a file path and responds with the stored size.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The destination file path.</param>
    /// <param name="ContentBase64">The base64-encoded content to store.</param>
    procedure ExecuteCreateFile(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; ContentBase64: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        DataObject: JsonObject;
        ContentOutStream: OutStream;
    begin
        if not CheckPath(Argument, Path) then
            exit;
        TempBlob.CreateOutStream(ContentOutStream);
        Base64Convert.FromBase64(ContentBase64, ContentOutStream);
        if not TryCreateFile(StorageSetup, Connector, Path, TempBlob) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        DataObject.Add('path', Path);
        DataObject.Add('contentLength', TempBlob.Length());
        RespondSuccess(Argument, DataObject);
    end;

    /// <summary>Deletes a file and responds with the deleted path.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The file path to delete.</param>
    procedure ExecuteDeleteFile(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
    begin
        if not CheckPath(Argument, Path) then
            exit;
        if not TryAssertCanDeleteStorageFile(AttachmentMgt, StorageSetup."Code", Path) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        if TryDeleteFile(StorageSetup, Connector, Path) then
            RespondPath(Argument, Path)
        else
            Argument.RespondWithError(GetLastErrorText());
    end;

    /// <summary>Creates a directory and responds with the created path.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The directory path to create.</param>
    procedure ExecuteCreateDirectory(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        if not CheckPath(Argument, Path) then
            exit;
        if TryCreateDirectory(StorageSetup, Connector, Path) then
            RespondPath(Argument, Path)
        else
            Argument.RespondWithError(GetLastErrorText());
    end;

    /// <summary>Deletes a directory and responds with the deleted path.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The directory path to delete.</param>
    procedure ExecuteDeleteDirectory(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
    begin
        if not CheckPath(Argument, Path) then
            exit;
        if not TryAssertCanDeleteStorageDirectory(AttachmentMgt, StorageSetup."Code", Path) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        if TryDeleteDirectory(StorageSetup, Connector, Path) then
            RespondPath(Argument, Path)
        else
            Argument.RespondWithError(GetLastErrorText());
    end;

    /// <summary>Copies a file and responds with the source and target paths.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="SourcePath">The source path.</param>
    /// <param name="TargetPath">The target path.</param>
    procedure ExecuteCopyFile(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; SourcePath: Text; TargetPath: Text)
    begin
        if not CheckPath(Argument, SourcePath) then
            exit;
        if not CheckPath(Argument, TargetPath) then
            exit;
        if TryCopyFile(StorageSetup, Connector, SourcePath, TargetPath) then
            RespondTransfer(Argument, SourcePath, TargetPath)
        else
            Argument.RespondWithError(GetLastErrorText());
    end;

    /// <summary>Moves a file and responds with the source and target paths.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="SourcePath">The source path.</param>
    /// <param name="TargetPath">The target path.</param>
    procedure ExecuteMoveFile(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; SourcePath: Text; TargetPath: Text)
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
    begin
        if not CheckPath(Argument, SourcePath) then
            exit;
        if not CheckPath(Argument, TargetPath) then
            exit;
        if not TryAssertCanMoveStorageFile(AttachmentMgt, StorageSetup."Code", SourcePath) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        if not TryMoveFile(StorageSetup, Connector, SourcePath, TargetPath) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        AttachmentMgt.UpdateMovedStorageFile(StorageSetup."Code", SourcePath, TargetPath);
        RespondTransfer(Argument, SourcePath, TargetPath);
    end;

    /// <summary>Checks whether a file exists and responds with the result.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The file path to check.</param>
    procedure ExecuteFileExists(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        RunExists(Argument, StorageSetup, Connector, Enum::"Ext. File Storage File Type"::File, Path);
    end;

    /// <summary>Checks whether a directory exists and responds with the result.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The directory path to check.</param>
    procedure ExecuteDirectoryExists(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        RunExists(Argument, StorageSetup, Connector, Enum::"Ext. File Storage File Type"::Directory, Path);
    end;

    local procedure RespondPath(var Argument: Record "Message Argument ori"; Path: Text)
    var
        DataObject: JsonObject;
    begin
        DataObject.Add('path', Path);
        RespondSuccess(Argument, DataObject);
    end;

    local procedure RespondTransfer(var Argument: Record "Message Argument ori"; SourcePath: Text; TargetPath: Text)
    var
        DataObject: JsonObject;
    begin
        DataObject.Add('sourcePath', SourcePath);
        DataObject.Add('targetPath', TargetPath);
        RespondSuccess(Argument, DataObject);
    end;

    local procedure RunExists(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; EntryType: Enum "Ext. File Storage File Type"; Path: Text)
    var
        DataObject: JsonObject;
        Exists: Boolean;
    begin
        if not CheckPath(Argument, Path) then
            exit;
        if not TryExists(StorageSetup, Connector, EntryType, Path, Exists) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        DataObject.Add('path', Path);
        DataObject.Add('exists', Exists);
        RespondSuccess(Argument, DataObject);
    end;

    /// <summary>Writes a success envelope carrying the supplied data object onto the argument.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="DataObject">The payload placed under <c>data</c>.</param>
    procedure RespondSuccess(var Argument: Record "Message Argument ori"; DataObject: JsonObject)
    var
        ResponseJson: JsonObject;
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('data', DataObject);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := 'text/json';
    end;

    local procedure EntryToJson(var TempFileAccountContent: Record "File Account Content" temporary) EntryObject: JsonObject
    begin
        EntryObject.Add('name', TempFileAccountContent.Name);
        EntryObject.Add('type', EntryTypeName(TempFileAccountContent."Type"));
        EntryObject.Add('parentDirectory', TempFileAccountContent."Parent Directory");
    end;

    local procedure EntryTypeName(EntryType: Enum "Ext. File Storage File Type"): Text
    begin
        case EntryType of
            EntryType::Directory:
                exit('Directory');
            EntryType::File:
                exit('File');
        end;
    end;

    [TryFunction]
    local procedure TryList(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)
    begin
        Connector.ListEntries(StorageSetup, Path, EntryType, TempFileAccountContent);
    end;

    [TryFunction]
    local procedure TryGetFile(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    begin
        Connector.GetFile(StorageSetup, Path, TempBlob);
    end;

    [TryFunction]
    local procedure TryCreateFile(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    begin
        Connector.CreateFile(StorageSetup, Path, TempBlob);
    end;

    [TryFunction]
    local procedure TryAssertCanDeleteStorageFile(var AttachmentMgt: Codeunit "Storage Attachment Mgt ori"; StorageCode: Code[20]; Path: Text)
    begin
        AttachmentMgt.AssertCanDeleteStorageFile(StorageCode, Path);
    end;

    [TryFunction]
    local procedure TryAssertCanDeleteStorageDirectory(var AttachmentMgt: Codeunit "Storage Attachment Mgt ori"; StorageCode: Code[20]; DirectoryPath: Text)
    begin
        AttachmentMgt.AssertCanDeleteStorageDirectory(StorageCode, DirectoryPath);
    end;

    [TryFunction]
    local procedure TryAssertCanMoveStorageFile(var AttachmentMgt: Codeunit "Storage Attachment Mgt ori"; StorageCode: Code[20]; SourcePath: Text)
    begin
        AttachmentMgt.AssertCanMoveStorageFile(StorageCode, SourcePath);
    end;


    [TryFunction]
    local procedure TryDeleteFile(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        Connector.DeleteFile(StorageSetup, Path);
    end;

    [TryFunction]
    local procedure TryCreateDirectory(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        Connector.CreateDirectory(StorageSetup, Path);
    end;

    [TryFunction]
    local procedure TryDeleteDirectory(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        Connector.DeleteDirectory(StorageSetup, Path);
    end;

    [TryFunction]
    local procedure TryCopyFile(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; SourcePath: Text; TargetPath: Text)
    begin
        Connector.CopyFile(StorageSetup, SourcePath, TargetPath);
    end;

    [TryFunction]
    local procedure TryMoveFile(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; SourcePath: Text; TargetPath: Text)
    begin
        Connector.MoveFile(StorageSetup, SourcePath, TargetPath);
    end;

    [TryFunction]
    local procedure TryExists(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; EntryType: Enum "Ext. File Storage File Type"; Path: Text; var Exists: Boolean)
    begin
        if EntryType = EntryType::Directory then
            Exists := Connector.DirectoryExists(StorageSetup, Path)
        else
            Exists := Connector.FileExists(StorageSetup, Path);
    end;
}
