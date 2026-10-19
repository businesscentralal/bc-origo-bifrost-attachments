namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;
using System.ExternalFileStorage;
using System.Utilities;

/// <summary>
/// Production <c>Bifrost Storage Connector</c> implementation. Delegates every storage action
/// to the Business Central <c>External File Storage</c> facade, initialized from the
/// connector and registered file account on the setup row. This keeps the connector
/// backend-agnostic: Azure Blob, Azure File Share, SharePoint and any other registered
/// <c>Ext. File Storage Connector</c> are all reached through the same facade. The
/// connector apps own authentication and secrets.
/// </summary>
codeunit 10035661 "Storage Ext File Impl ori" implements "Storage Connector ori"
{
    Access = Internal;
    var
        InvalidPathErr: Label 'The storage path is invalid. Nothing was changed.', Comment = 'is-IS=Geymsluslóðin er ógild. Engu var breytt.';
        NoAccountErr: Label 'Storage connection ''%1'' has no file account selected.', Comment = '%1 = storage code||is-IS=Geymslutengingin „%1“ hefur engan skráareikning valinn.';

    /// <summary>Lists the configured base-path root through the External File Storage facade; initialization or provider failures propagate.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    procedure TestConnection(StorageSetup: Record "Storage Setup ori")
    var
        TempFileAccountContent: Record "File Account Content" temporary;
        ExternalFileStorage: Codeunit "External File Storage";
        FilePaginationData: Codeunit "File Pagination Data";
    begin
        // Listing the root proves the account is reachable and the credentials are valid.
        Initialize(StorageSetup, ExternalFileStorage);
        ExternalFileStorage.ListFiles(ResolvePath(ExternalFileStorage, StorageSetup, ''), FilePaginationData, TempFileAccountContent);
    end;

    /// <summary>Replaces the temporary result with file or directory entries, following provider pagination for at most 1000 pages. Duplicate keys are ignored; reaching the page cap returns the entries collected so far.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="Path">Path relative to the configured base path; empty selects that base root.</param>
    /// <param name="EntryType">Directory selects directory listing; all other values select file listing.</param>
    /// <param name="TempFileAccountContent">Out: cleared and populated with the collected provider entries.</param>
    procedure ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)
    var
        TempBatch: Record "File Account Content" temporary;
        ExternalFileStorage: Codeunit "External File Storage";
        FilePaginationData: Codeunit "File Pagination Data";
        FullPath: Text;
        PageGuard: Integer;
    begin
        TempFileAccountContent.Reset();
        TempFileAccountContent.DeleteAll();
        Initialize(StorageSetup, ExternalFileStorage);
        FullPath := ResolvePath(ExternalFileStorage, StorageSetup, Path);

        repeat
            PageGuard += 1;
            Clear(TempBatch);
            TempBatch.DeleteAll();
            if EntryType = EntryType::Directory then
                ExternalFileStorage.ListDirectories(FullPath, FilePaginationData, TempBatch)
            else
                ExternalFileStorage.ListFiles(FullPath, FilePaginationData, TempBatch);
            if TempBatch.FindSet() then
                repeat
                    TempFileAccountContent := TempBatch;
                    if TempFileAccountContent.Insert() then;
                until TempBatch.Next() = 0;
        until FilePaginationData.IsEndOfListing() or (PageGuard >= MaxListPages());
    end;

    /// <summary>Reads a provider file into the supplied temporary blob and raises the provider error when retrieval fails.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="Path">File or directory path relative to the configured base path; validated before provider access.</param>
    /// <param name="TempBlob">Out: receives the retrieved file bytes.</param>
    procedure GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        ExternalFileStorage: Codeunit "External File Storage";
        ContentInStream: InStream;
        ContentOutStream: OutStream;
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.GetFile(ResolvePath(ExternalFileStorage, StorageSetup, Path), ContentInStream) then
            Error(GetLastErrorText());
        TempBlob.CreateOutStream(ContentOutStream);
        CopyStream(ContentOutStream, ContentInStream);
    end;

    /// <summary>Streams the supplied blob to the resolved provider path and raises the provider error when creation fails.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="Path">File or directory path relative to the configured base path; validated before provider access.</param>
    /// <param name="TempBlob">In: file bytes to send to the provider.</param>
    procedure CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        ExternalFileStorage: Codeunit "External File Storage";
        ContentInStream: InStream;
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        TempBlob.CreateInStream(ContentInStream);
        if not ExternalFileStorage.CreateFile(ResolvePath(ExternalFileStorage, StorageSetup, Path), ContentInStream) then
            Error(GetLastErrorText());
    end;

    /// <summary>Deletes the resolved provider file and raises the provider error on failure.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="Path">File or directory path relative to the configured base path; validated before provider access.</param>
    procedure DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.DeleteFile(ResolvePath(ExternalFileStorage, StorageSetup, Path)) then
            Error(GetLastErrorText());
    end;

    /// <summary>Queries the provider for a file at the resolved path; initialization and path-validation errors propagate.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="Path">File or directory path relative to the configured base path; validated before provider access.</param>
    /// <returns>The provider existence result for the resolved file path.</returns>
    procedure FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        exit(ExternalFileStorage.FileExists(ResolvePath(ExternalFileStorage, StorageSetup, Path)));
    end;

    /// <summary>Copies a file between resolved paths on the configured provider and raises the provider error on failure.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="SourcePath">Source file path relative to the configured base path.</param>
    /// <param name="TargetPath">Destination file path relative to the configured base path.</param>
    procedure CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.CopyFile(ResolvePath(ExternalFileStorage, StorageSetup, SourcePath), ResolvePath(ExternalFileStorage, StorageSetup, TargetPath)) then
            Error(GetLastErrorText());
    end;

    /// <summary>Moves a file between resolved paths on the configured provider and raises the provider error on failure.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="SourcePath">Source file path relative to the configured base path.</param>
    /// <param name="TargetPath">Destination file path relative to the configured base path.</param>
    procedure MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.MoveFile(ResolvePath(ExternalFileStorage, StorageSetup, SourcePath), ResolvePath(ExternalFileStorage, StorageSetup, TargetPath)) then
            Error(GetLastErrorText());
    end;

    /// <summary>Creates the resolved directory through the provider and raises the provider error on failure.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="Path">File or directory path relative to the configured base path; validated before provider access.</param>
    procedure CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.CreateDirectory(ResolvePath(ExternalFileStorage, StorageSetup, Path)) then
            Error(GetLastErrorText());
    end;

    /// <summary>Deletes the resolved directory through the provider and raises the provider error on failure.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="Path">File or directory path relative to the configured base path; validated before provider access.</param>
    procedure DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.DeleteDirectory(ResolvePath(ExternalFileStorage, StorageSetup, Path)) then
            Error(GetLastErrorText());
    end;

    /// <summary>Queries the provider for a directory at the resolved path; initialization and path-validation errors propagate.</summary>
    /// <param name="StorageSetup">Configured connector, file account and base path used to initialize the facade.</param>
    /// <param name="Path">File or directory path relative to the configured base path; validated before provider access.</param>
    /// <returns>The provider existence result for the resolved directory path.</returns>
    procedure DirectoryExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        exit(ExternalFileStorage.DirectoryExists(ResolvePath(ExternalFileStorage, StorageSetup, Path)));
    end;

    /// <summary>Initializes the facade with the file account registered on the setup row.</summary>
    local procedure Initialize(StorageSetup: Record "Storage Setup ori"; var ExternalFileStorage: Codeunit "External File Storage")
    var
        TempFileAccount: Record "File Account" temporary;
    begin
        if not StorageSetup.HasFileAccount() then
            Error(NoAccountErr, StorageSetup."Code");
        TempFileAccount.Init();
        TempFileAccount."Account Id" := StorageSetup."File Account Id";
        TempFileAccount.Connector := StorageSetup.Connector;
        TempFileAccount.Name := StorageSetup."File Account Name";
        TempFileAccount.Insert();
        ExternalFileStorage.Initialize(TempFileAccount);
    end;

    /// <summary>Prefixes the request path with the connection base path, using the platform path helper.</summary>
    /// <remarks>
    /// Normalises the caller-supplied path before combining: leading and trailing slashes are
    /// stripped so that "/" and "" are both treated as "list the base-path root". This prevents
    /// CombinePath from producing an invalid path such as "origodemo/" when the caller passes
    /// "/" to mean the top-level directory.
    /// </remarks>
    local procedure ResolvePath(ExternalFileStorage: Codeunit "External File Storage"; StorageSetup: Record "Storage Setup ori"; Path: Text): Text
    var
        TempArgument: Record "Message Argument ori" temporary;
        Reader: Codeunit "Storage Request Reader ori";
        RequestMgt: Codeunit "Storage Request Mgt ori";
        BasePath: Text;
    begin
        // Direct AL callers and stored legacy links share the request preflight.
        if not Reader.CheckStoragePath(TempArgument, StorageSetup, 'path', Path, true) then
            TempArgument.RaiseCollectedErrors("Bifrost Error Code ori"::InvalidParameter, InvalidPathErr);
        BasePath := RequestMgt.CanonicalPath(StorageSetup."Base Path");
        if BasePath = '' then
            exit(Path);
        if Path = '' then
            exit(BasePath);
        exit(ExternalFileStorage.CombinePath(BasePath, Path));
    end;

    local procedure MaxListPages(): Integer
    begin
        exit(1000);
    end;
}
