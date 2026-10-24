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
codeunit 10035193 "Storage Request Mgt ori"
{
    Access = Internal;

    var
        TransferDestinationExistsErr: Label 'The transfer destination already exists. Nothing was changed.', Comment = 'is-IS=Áfangastaður tilfærslunnar er þegar til. Engu var breytt.';
        NewTransferTargetLbl: Label 'a destination that does not already exist', Comment = 'is-IS=áfangastaður sem er ekki þegar til';
        NewTransferTargetNextStepLbl: Label 'Choose a new target path and retry the transfer.', Comment = 'is-IS=Veldu nýja áfangaslóð og reyndu tilfærsluna aftur.';
        MoveRecoveryErr: Label 'This file is linked to an attachment and cannot be moved directly. Nothing was changed.', Comment = 'is-IS=Þessi skrá er tengd viðhengi og ekki er hægt að færa hana beint. Engu var breytt.';
        MoveRecoveryNextStepLbl: Label 'Restore the attachment first, then move the file.', Comment = 'is-IS=Endurheimtu viðhengið fyrst og færðu svo skrána.';
        MoveRecoveryLbl: Label 'a file that can be moved without affecting a linked attachment', Comment = 'is-IS=skrá sem má færa án þess að hafa áhrif á tengt viðhengi';
        LinkPermissionsExpectedLbl: Label 'read and write permission on every linked attachment', Comment = 'is-IS=les- og skrifheimild á öllum tengdum viðhengjum';
        LinkPermissionsNextStepLbl: Label 'Ask the administrator to grant attachment access before retrying.', Comment = 'is-IS=Biddu kerfisstjóra um að veita aðgang að viðhengjum áður en þú reynir aftur.';
        UnsafePathErr: Label 'The path ''%1'' is not allowed: no path segment may be ''.'' or ''..''.', Comment = '%1 = the rejected path||is-IS=Slóðin „%1“ er ekki leyfð: enginn hluti slóðarinnar má vera „.“ eða „..“.';
        UnknownCodeErr: Label 'No storage connection is configured for storageCode "%1".', Comment = '%1 = storage code, is-IS=Engin geymslutenging er skilgreind fyrir storageCode "%1".';
        DisabledCodeErr: Label 'The storage connection "%1" is disabled.', Comment = '%1 = storage code, is-IS=Geymslutengingin "%1" er óvirk.';
        UnknownCodeNextStepLbl: Label 'Call Storage.Account.List to see the configured storage codes.', Comment = 'is-IS=Kallaðu á Storage.Account.List til að sjá skilgreinda geymslukóða.';
        DisabledCodeNextStepLbl: Label 'Enable the connection on the Bifröst Attachments setup page, or use another storageCode.', Comment = 'is-IS=Virkjaðu tenginguna á uppsetningarsíðu Bifröst viðhengja eða notaðu annan storageCode.';
        EnabledExpectedLbl: Label 'an enabled storage connection', Comment = 'is-IS=virk geymslutenging';
        LinkedFileDeleteErr: Label 'File "%1" backs a Business Central attachment and cannot be deleted directly from storage.', Comment = '%1 = storage path, is-IS=Skráin "%1" geymir viðhengi í Business Central og ekki er hægt að eyða henni beint úr geymslunni.';
        LinkedDirectoryDeleteErr: Label 'Directory "%1" contains files that back Business Central attachments and cannot be deleted directly from storage.', Comment = '%1 = directory path, is-IS=Mappan "%1" inniheldur skrár sem geyma viðhengi í Business Central og ekki er hægt að eyða henni beint úr geymslunni.';
        DirectoryNotEmptyErr: Label 'Directory "%1" is not empty.', Comment = '%1 = directory path||is-IS=Mappan "%1" er ekki tóm.';
        EmptyDirectoryExpectedLbl: Label 'an empty directory', Comment = 'is-IS=tóm mappa';
        EmptyDirectoryNextStepLbl: Label 'List the files and subdirectories, remove those entries, then retry.', Comment = 'is-IS=Sýndu skrár og undirmöppur, fjarlægðu þær og reyndu svo aftur.';
        LinkedDeleteNextStepLbl: Label 'Restore the attachment with Storage.Attachment.Restore, or delete the attachment in Business Central, then delete the file.', Comment = 'is-IS=Endurheimtu viðhengið með Storage.Attachment.Restore eða eyddu viðhenginu í Business Central og eyddu svo skránni.';
        LinkedFileWriteErr: Label 'File "%1" backs a Business Central attachment and cannot be overwritten by a raw storage operation.', Comment = '%1 = storage path, is-IS=Skráin "%1" geymir viðhengi í Business Central og ekki má yfirskrifa hana með beinni geymsluaðgerð.';
        LinkedWriteNextStepLbl: Label 'Use Storage.Attachment operations to change the attachment, or choose a destination that is not linked to an attachment.', Comment = 'is-IS=Notaðu Storage.Attachment-aðgerðir til að breyta viðhenginu eða veldu áfangastað sem er ekki tengdur viðhengi.';
        DifferentPathsErr: Label 'Source and destination resolve to the same storage file.', Comment = 'is-IS=Uppruni og áfangastaður vísa á sömu skrá í geymslunni.';
        DifferentPathsNextStepLbl: Label 'Choose a different destination file name or folder.', Comment = 'is-IS=Veldu annað skráarheiti eða aðra möppu fyrir áfangastaðinn.';
        UnlinkedExpectedLbl: Label 'a file that no attachment is linked to', Comment = 'is-IS=skrá sem ekkert viðhengi er tengt við';
        ExistingDestinationErr: Label 'The destination file already exists.', Comment = 'is-IS=Áfangaskráin er þegar til.';
        NewDestinationExpectedLbl: Label 'a new file path, or overwrite true', Comment = 'is-IS=ný skráarslóð eða overwrite true';
        ExistingDestinationNextLbl: Label 'Choose another path or send overwrite true to replace the existing file. Linked attachment files cannot be overwritten.', Comment = 'is-IS=Veldu aðra slóð eða sendu overwrite true til að skipta út fyrirliggjandi skrá. Ekki má yfirskrifa skrár sem tengjast viðhengjum.';
        DestinationCheckErr: Label 'The storage destination could not be checked.', Comment = 'is-IS=Ekki tókst að athuga áfangastað í geymslu.';
        DestinationCheckNextLbl: Label 'Check the storage connection and permissions, then retry. No file was written.', Comment = 'is-IS=Athugaðu geymslutenginguna og heimildir og reyndu aftur. Engin skrá var skrifuð.';

    /// <summary>Collects overwrite and linked-file refusals before storage writes. Existing files require explicit consent.</summary>
    internal procedure CollectWriteDestinationErrors(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; ParameterName: Text; var Existing: Boolean)
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
        Overwrite: Boolean;
    begin
        Existing := false;
        Reader.ReadBoolean(Argument, Argument.GetRequestJson(), 'overwrite', false, Overwrite);
        if Argument.HasCollectedErrors() then
            exit;
        if AttachmentMgt.IsStorageFileLinked(StorageSetup.Code, Path) then begin
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(LinkedFileWriteErr, Path), ParameterName, Path, UnlinkedExpectedLbl, LinkedWriteNextStepLbl);
            exit;
        end;
        if not TryExists(StorageSetup, Connector, Enum::"Ext. File Storage File Type"::File, Path, Existing) then begin
            ClearLastError();
            Argument.AddError("Bifrost Error Code ori"::BusinessCentralError, DestinationCheckErr, ParameterName, Path, '', DestinationCheckNextLbl);
            exit;
        end;
        if Existing and not Overwrite then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, ExistingDestinationErr, ParameterName, Path, NewDestinationExpectedLbl, ExistingDestinationNextLbl);
    end;

    /// <summary>Checks an external write destination and answers collected refusals before any mutation.</summary>
    internal procedure CheckWriteDestination(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; ParameterName: Text; var Existing: Boolean): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        CollectWriteDestinationErrors(Argument, StorageSetup, Connector, Path, ParameterName, Existing);
        exit(not Reader.RespondIfErrors(Argument));
    end;

    /// <summary>Answers a failed connector operation without exposing provider URLs or internal paths.</summary>
    /// <remarks>A successful existence probe distinguishes a missing resource from an unavailable provider.</remarks>
    /// <param name="Argument">Original request and structured error response.</param>
    /// <param name="StorageSetup">Resolved storage setup.</param>
    /// <param name="Connector">Selected connector; no provider-specific lookup is used.</param>
    /// <param name="Path">Validated logical path to probe.</param>
    /// <param name="ParameterName">Original request field containing the path.</param>
    /// <param name="EntryType">Whether the failing operation requires a file or directory.</param>
    internal procedure RespondStorageFailure(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; ParameterName: Text; EntryType: Enum "Ext. File Storage File Type")
    var
        Exists: Boolean;
        ReceivedPath: Text;
        MissingErr: Label 'The storage file or folder "%1" was not found.', Comment = '%1 = caller path||is-IS=Geymsluskráin eða mappan "%1" fannst ekki.';
        MissingExpectedLbl: Label 'an existing file or folder at the requested path', Comment = 'is-IS=skrá eða mappa sem er til á umbeðinni slóð';
        MissingNextLbl: Label 'Use Storage.File.List or Storage.File.Exists to check the path, then retry.', Comment = 'is-IS=Notaðu Storage.File.List eða Storage.File.Exists til að athuga slóðina og reyndu aftur.';
        ProviderErr: Label 'The storage provider could not complete the operation.', Comment = 'is-IS=Geymsluveitan gat ekki lokið aðgerðinni.';
        ProviderNextLbl: Label 'Check the storage connection and provider permissions, then retry.', Comment = 'is-IS=Athugaðu geymslutenginguna og heimildir hjá geymsluveitunni og reyndu aftur.';
    begin
        // Read the original request spelling, not the normalized path or configured base path.
        ReceivedPath := GetText(Argument.GetRequestJson(), ParameterName);
        if ReceivedPath = '' then
            ReceivedPath := Path;
        if TryExists(StorageSetup, Connector, EntryType, Path, Exists) then
            if not Exists then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingErr, ReceivedPath), ParameterName, ReceivedPath, MissingExpectedLbl, MissingNextLbl);
                exit;
            end;
        Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, ProviderErr, ParameterName, ReceivedPath, '', ProviderNextLbl);
    end;

    /// <summary>Rejects relative, ambiguous and control-character paths before provider normalization.</summary>
    /// <param name="Path">The complete path to test.</param>
    /// <returns>True for an unambiguous slash-separated path or the directory root.</returns>
    procedure PathIsSafe(Path: Text): Boolean
    var
        Segments: List of [Text];
        Segment: Text;
        CharacterIndex: Integer;
    begin
        Path := CanonicalPath(Path);
        if Path = '' then
            exit(true);
        if Path.Contains('\') or Path.Contains('//') then
            exit(false);
        for CharacterIndex := 1 to StrLen(Path) do
            if (Path[CharacterIndex] < 32) or (Path[CharacterIndex] = 127) then
                exit(false);
        Segments := Path.Split('/');
        foreach Segment in Segments do
            if (Segment = '.') or (Segment = '..') then
                exit(false);
        exit(true);
    end;

    /// <summary>Returns the relative identity used by requests, links and provider addressing.</summary>
    /// <param name="Path">A path whose outer slashes do not change its target.</param>
    /// <returns>The path with outer slashes removed; an empty path denotes the connection root.</returns>
    internal procedure CanonicalPath(Path: Text): Text
    begin
        exit(Path.TrimStart('/').TrimEnd('/'));
    end;

    /// <summary>Combines canonical base and relative paths without changing case or internal characters.</summary>
    internal procedure CombinedPath(BasePath: Text; Path: Text): Text
    begin
        BasePath := CanonicalPath(BasePath);
        Path := CanonicalPath(Path);
        if BasePath = '' then
            exit(Path);
        if Path = '' then
            exit(BasePath);
        exit(BasePath + '/' + Path);
    end;

    /// <summary>Compares UTF-16 code units, independent of database collation; never changes stored spelling.</summary>
    internal procedure PathsEqual(FirstPath: Text; SecondPath: Text; CaseSensitive: Boolean): Boolean
    var
        CharacterIndex: Integer;
    begin
        if not CaseSensitive then begin
            FirstPath := UpperCase(FirstPath);
            SecondPath := UpperCase(SecondPath);
        end;
        if StrLen(FirstPath) <> StrLen(SecondPath) then
            exit(false);
        for CharacterIndex := 1 to StrLen(FirstPath) do
            if FirstPath[CharacterIndex] <> SecondPath[CharacterIndex] then
                exit(false);
        exit(true);
    end;

    /// <summary>Refuses a raw write to a file that backs an attachment before any write occurs.</summary>
    /// <param name="Argument">The argument receiving the actionable error.</param>
    /// <param name="StorageCode">The destination storage connection.</param>
    /// <param name="Path">The destination path.</param>
    /// <param name="ParameterName">The request parameter naming the destination.</param>
    /// <returns>True when no attachment references the destination.</returns>
    internal procedure CheckUnlinkedDestination(var Argument: Record "Message Argument ori"; StorageCode: Code[20]; Path: Text; ParameterName: Text): Boolean
    var
        StorageSetup: Record "Storage Setup ori";
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        Reader: Codeunit "Storage Request Reader ori";
    begin
        StorageSetup.Get(StorageCode);
        Reader.CheckStoragePath(Argument, StorageSetup, ParameterName, Path, false);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        if not AttachmentMgt.IsStorageFileLinked(StorageCode, Path) then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(LinkedFileWriteErr, Path), ParameterName, Path, UnlinkedExpectedLbl, LinkedWriteNextStepLbl);
        exit(false);
    end;

    /// <summary>Raises the "unsafe path" error. Used where a path is built rather than read from a request.</summary>
    /// <param name="Path">The rejected path.</param>
    procedure ThrowUnsafePath(Path: Text)
    begin
        Error(UnsafePathErr, Path);
    end;

    /// <summary>
    /// Reads the required <c>storageCode</c> and resolves it to an enabled storage setup row and
    /// its connector. Problems are collected on the argument, see <see cref="ResolveSetup"/>.
    /// </summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="RequestJson">The request JSON.</param>
    /// <param name="StorageSetup">Out: the resolved setup row.</param>
    /// <param name="Connector">Out: the resolved connector implementation.</param>
    /// <returns>True when a usable storage connection was resolved.</returns>
    procedure ReadSetup(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var StorageSetup: Record "Storage Setup ori"; var Connector: Interface "Storage Connector ori"): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
        StorageCode: Text;
    begin
        if not Reader.ReadText(Argument, RequestJson, 'storageCode', true, StorageCode) then
            exit(false);
        exit(ResolveSetup(Argument, StorageCode, 'storageCode', StorageSetup, Connector));
    end;

    /// <summary>
    /// Resolves a storage code to an enabled storage setup row and its connector. An unknown code
    /// adds <c>RecordNotFound</c> and a disabled connection adds <c>PreconditionFailed</c>, both with
    /// a next step; nothing is answered yet.
    /// </summary>
    /// <param name="Argument">The message argument that collects the problems.</param>
    /// <param name="StorageCode">The storage code to resolve.</param>
    /// <param name="ParameterName">The request parameter the code came from.</param>
    /// <param name="StorageSetup">Out: the resolved setup row.</param>
    /// <param name="Connector">Out: the resolved connector implementation.</param>
    /// <returns>True when a usable storage connection was resolved.</returns>
    procedure ResolveSetup(var Argument: Record "Message Argument ori"; StorageCode: Text; ParameterName: Text; var StorageSetup: Record "Storage Setup ori"; var Connector: Interface "Storage Connector ori"): Boolean
    begin
        if (StrLen(StorageCode) > MaxStrLen(StorageSetup."Code")) or (not StorageSetup.Get(CopyStr(StorageCode, 1, MaxStrLen(StorageSetup."Code")))) then begin
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownCodeErr, StorageCode), ParameterName, StorageCode, '', UnknownCodeNextStepLbl);
            exit(false);
        end;
        if not StorageSetup.Enabled then begin
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DisabledCodeErr, StorageCode), ParameterName, StorageCode, EnabledExpectedLbl, DisabledCodeNextStepLbl);
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
        if not CheckOperationPath(Argument, StorageSetup, 'path', Path, true) then
            exit;
        if not TryList(StorageSetup, Connector, Path, EntryType, TempFileAccountContent) then begin
            Argument.RespondWithLastError();
            exit;
        end;
        if TempFileAccountContent.FindSet() then
            repeat
                EntriesArray.Add(EntryToJson(TempFileAccountContent, Path));
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
        if not CheckOperationPath(Argument, StorageSetup, 'path', Path, false) then
            exit;
        if not TryGetFile(StorageSetup, Connector, Path, TempBlob) then begin
            RespondStorageFailure(Argument, StorageSetup, Connector, Path, 'path', Enum::"Ext. File Storage File Type"::File);
            exit;
        end;
        TempBlob.CreateInStream(ContentInStream);
        DataObject.Add('path', Path);
        DataObject.Add('contentLength', TempBlob.Length());
        DataObject.Add('contentBase64', Base64Convert.ToBase64(ContentInStream));
        RespondSuccess(Argument, DataObject);
    end;

    /// <summary>Uploads decoded content to a file path and responds with the stored size.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The destination file path.</param>
    /// <param name="TempBlob">The content to store, decoded by the request reader.</param>
    procedure ExecuteCreateFile(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        DataObject: JsonObject;
        Existing: Boolean;
    begin
        if not CheckOperationPath(Argument, StorageSetup, 'path', Path, false) then
            exit;
        if not CheckWriteDestination(Argument, StorageSetup, Connector, Path, 'path', Existing) then
            exit;
        if not TryCreateFile(StorageSetup, Connector, Path, TempBlob) then begin
            Argument.RespondWithLastError();
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
        if not CheckOperationPath(Argument, StorageSetup, 'path', Path, false) then
            exit;
        if AttachmentMgt.IsStorageFileLinked(StorageSetup."Code", Path) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(LinkedFileDeleteErr, Path), 'path', Path, UnlinkedExpectedLbl, LinkedDeleteNextStepLbl);
            exit;
        end;
        if TryDeleteFile(StorageSetup, Connector, Path) then
            RespondPath(Argument, Path)
        else
            RespondStorageFailure(Argument, StorageSetup, Connector, Path, 'path', Enum::"Ext. File Storage File Type"::File);
    end;

    /// <summary>Creates a directory and responds with the created path.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The directory path to create.</param>
    procedure ExecuteCreateDirectory(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        if not CheckOperationPath(Argument, StorageSetup, 'path', Path, true) then
            exit;
        if TryCreateDirectory(StorageSetup, Connector, Path) then
            RespondPath(Argument, Path)
        else
            Argument.RespondWithLastError();
    end;

    /// <summary>Deletes a directory and responds with the deleted path.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The directory path to delete.</param>
    procedure ExecuteDeleteDirectory(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        DirectoryIsEmpty: Boolean;
    begin
        if not CheckOperationPath(Argument, StorageSetup, 'path', Path, true) then
            exit;
        if AttachmentMgt.IsStorageDirectoryLinked(StorageSetup."Code", Path) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(LinkedDirectoryDeleteErr, Path), 'path', Path, UnlinkedExpectedLbl, LinkedDeleteNextStepLbl);
            exit;
        end;
        if not TryDirectoryIsEmpty(StorageSetup, Connector, Path, DirectoryIsEmpty) then begin
            RespondStorageFailure(Argument, StorageSetup, Connector, Path, 'path', Enum::"Ext. File Storage File Type"::Directory);
            exit;
        end;
        if not DirectoryIsEmpty then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DirectoryNotEmptyErr, Path), 'path', Path, EmptyDirectoryExpectedLbl, EmptyDirectoryNextStepLbl);
            exit;
        end;
        if TryDeleteDirectory(StorageSetup, Connector, Path) then
            RespondPath(Argument, Path)
        else
            RespondStorageFailure(Argument, StorageSetup, Connector, Path, 'path', Enum::"Ext. File Storage File Type"::Directory);
    end;

    /// <summary>Copies a file and responds with the source and target paths.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="SourcePath">The source path.</param>
    /// <param name="TargetPath">The target path.</param>
    procedure ExecuteCopyFile(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; SourcePath: Text; TargetPath: Text)
    begin
        if not CheckTransferPaths(Argument, StorageSetup, SourcePath, TargetPath) then
            exit;
        if not CheckTransferDestination(Argument, StorageSetup, Connector, TargetPath) then
            exit;
        if not CheckUnlinkedDestination(Argument, StorageSetup.Code, TargetPath, 'targetPath') then
            exit;
        if TryCopyFile(StorageSetup, Connector, SourcePath, TargetPath) then
            RespondTransfer(Argument, SourcePath, TargetPath)
        else
            RespondStorageFailure(Argument, StorageSetup, Connector, SourcePath, 'sourcePath', Enum::"Ext. File Storage File Type"::File);
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
        Reader: Codeunit "Storage Request Reader ori";
        BlockReason: Text;
    begin
        if not CheckTransferPaths(Argument, StorageSetup, SourcePath, TargetPath) then
            exit;
        if not CheckTransferDestination(Argument, StorageSetup, Connector, TargetPath) then
            exit;
        if not CheckUnlinkedDestination(Argument, StorageSetup.Code, TargetPath, 'targetPath') then
            exit;
        if not AttachmentMgt.CanUpdateLinksOf(StorageSetup."Code", SourcePath, BlockReason) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, BlockReason, 'sourcePath', SourcePath, LinkPermissionsExpectedLbl, LinkPermissionsNextStepLbl);
            exit;
        end;
        AttachmentMgt.CheckMovedPath(Argument, StorageSetup.Code, SourcePath, TargetPath);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if AttachmentMgt.IsStorageFileLinked(StorageSetup.Code, SourcePath) and
           not SupportsLinkedMove(Connector)
        then begin
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, MoveRecoveryErr, 'sourcePath', SourcePath, MoveRecoveryLbl, MoveRecoveryNextStepLbl);
            Reader.RespondIfErrors(Argument);
            exit;
        end;
        // Database changes first; a raised connector error rolls them back with the message.
        // Do not catch that error and turn it into a successful transaction after changing links.
        AttachmentMgt.UpdateMovedStorageFile(StorageSetup."Code", SourcePath, TargetPath);
        Connector.MoveFile(StorageSetup, SourcePath, TargetPath);
        RespondTransfer(Argument, SourcePath, TargetPath);
    end;

    /// <summary>Checks whether a file exists and responds with the result.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The file path to check.</param>
    procedure ExecuteFileExists(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        if not CheckOperationPath(Argument, StorageSetup, 'path', Path, false) then
            exit;
        RunExists(Argument, StorageSetup, Connector, Enum::"Ext. File Storage File Type"::File, Path);
    end;

    /// <summary>Checks whether a directory exists and responds with the result.</summary>
    /// <param name="Argument">The Bifrost argument that receives the response.</param>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The directory path to check.</param>
    procedure ExecuteDirectoryExists(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text)
    begin
        if not CheckOperationPath(Argument, StorageSetup, 'path', Path, true) then
            exit;
        RunExists(Argument, StorageSetup, Connector, Enum::"Ext. File Storage File Type"::Directory, Path);
    end;

    local procedure CheckOperationPath(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; ParameterName: Text; var Path: Text; AllowRoot: Boolean): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        Reader.CheckStoragePath(Argument, StorageSetup, ParameterName, Path, AllowRoot);
        exit(not Reader.RespondIfErrors(Argument));
    end;

    local procedure CheckTransferPaths(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; var SourcePath: Text; var TargetPath: Text): Boolean
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        Reader.CheckStoragePath(Argument, StorageSetup, 'sourcePath', SourcePath, false);
        Reader.CheckStoragePath(Argument, StorageSetup, 'targetPath', TargetPath, false);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        if PathsEqual(SourcePath, TargetPath, true) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DifferentPathsErr, 'targetPath', TargetPath, '', DifferentPathsNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure SupportsLinkedMove(Connector: Interface "Storage Connector ori"): Boolean
    var
        LinkedMove: Interface "Storage Linked Move ori";
    begin
        if not (Connector is "Storage Linked Move ori") then
            exit(false);
        LinkedMove := Connector as "Storage Linked Move ori";
        exit(LinkedMove.SupportsLinkedMove());
    end;

    local procedure CheckTransferDestination(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; TargetPath: Text): Boolean
    var
        Exists: Boolean;
    begin
        // The connector decides whether the target spelling already denotes a file,
        // including any case or encoded aliases understood by that connector.
        if not TryExists(StorageSetup, Connector, Enum::"Ext. File Storage File Type"::File, TargetPath, Exists) then begin
            Argument.RespondWithLastError();
            exit(false);
        end;
        if Exists then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, TransferDestinationExistsErr, 'targetPath', TargetPath, NewTransferTargetLbl, NewTransferTargetNextStepLbl);
            exit(false);
        end;
        exit(true);
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
        if not TryExists(StorageSetup, Connector, EntryType, Path, Exists) then begin
            Argument.RespondWithLastError();
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

    local procedure EntryToJson(var TempFileAccountContent: Record "File Account Content" temporary; RelativeParentPath: Text) EntryObject: JsonObject
    var
        NameParts: List of [Text];
    begin
        // Provider metadata can contain the account base path. Only the caller's
        // relative directory and the entry's leaf name belong in the wire contract.
        NameParts := ConvertStr(TempFileAccountContent.Name, '\', '/').TrimEnd('/').Split('/');
        EntryObject.Add('name', NameParts.Get(NameParts.Count()));
        EntryObject.Add('type', EntryTypeName(TempFileAccountContent."Type"));
        EntryObject.Add('parentDirectory', RelativeParentPath);
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

    /// <summary>Reads a file through the connector. A connector failure returns false and keeps the error for RespondWithLastError.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The file path, already checked with CheckStoragePath.</param>
    /// <param name="TempBlob">Returns the file content.</param>
    [TryFunction]
    internal procedure TryReadStorageFile(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    begin
        Connector.GetFile(StorageSetup, Path, TempBlob);
    end;

    /// <summary>Writes a file through the connector. A connector failure returns false and keeps the error.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Connector">The resolved connector implementation.</param>
    /// <param name="Path">The file path, already checked with CheckStoragePath and CheckUnlinkedDestination.</param>
    /// <param name="TempBlob">The file content.</param>
    [TryFunction]
    internal procedure TryWriteStorageFile(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    begin
        Connector.CreateFile(StorageSetup, Path, TempBlob);
    end;

    /// <summary>Returns the last segment of a storage path.</summary>
    /// <param name="Path">The path.</param>
    /// <returns>The file name part of the path.</returns>
    internal procedure LeafName(Path: Text): Text
    var
        Segments: List of [Text];
    begin
        Path := CanonicalPath(Path);
        if Path = '' then
            exit('');
        Segments := Path.Split('/');
        exit(Segments.Get(Segments.Count()));
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
    local procedure TryDirectoryIsEmpty(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; Path: Text; var DirectoryIsEmpty: Boolean)
    var
        TempFileAccountContent: Record "File Account Content" temporary;
    begin
        DirectoryIsEmpty := false;
        Connector.ListEntries(StorageSetup, Path, Enum::"Ext. File Storage File Type"::File, TempFileAccountContent);
        if not TempFileAccountContent.IsEmpty() then
            exit;
        TempFileAccountContent.Reset();
        TempFileAccountContent.DeleteAll();
        Connector.ListEntries(StorageSetup, Path, Enum::"Ext. File Storage File Type"::Directory, TempFileAccountContent);
        DirectoryIsEmpty := TempFileAccountContent.IsEmpty();
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
    local procedure TryExists(StorageSetup: Record "Storage Setup ori"; Connector: Interface "Storage Connector ori"; EntryType: Enum "Ext. File Storage File Type"; Path: Text; var Exists: Boolean)
    begin
        if EntryType = EntryType::Directory then
            Exists := Connector.DirectoryExists(StorageSetup, Path)
        else
            Exists := Connector.FileExists(StorageSetup, Path);
    end;
}
