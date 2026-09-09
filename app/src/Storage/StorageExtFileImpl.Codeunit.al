namespace Origo.Bifrost.Attachments;

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
        NoAccountErr: Label 'Storage connection ''%1'' has no file account selected.', Comment = '%1 = storage code';

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

    procedure DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.DeleteFile(ResolvePath(ExternalFileStorage, StorageSetup, Path)) then
            Error(GetLastErrorText());
    end;

    procedure FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        exit(ExternalFileStorage.FileExists(ResolvePath(ExternalFileStorage, StorageSetup, Path)));
    end;

    procedure CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.CopyFile(ResolvePath(ExternalFileStorage, StorageSetup, SourcePath), ResolvePath(ExternalFileStorage, StorageSetup, TargetPath)) then
            Error(GetLastErrorText());
    end;

    procedure MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.MoveFile(ResolvePath(ExternalFileStorage, StorageSetup, SourcePath), ResolvePath(ExternalFileStorage, StorageSetup, TargetPath)) then
            Error(GetLastErrorText());
    end;

    procedure CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.CreateDirectory(ResolvePath(ExternalFileStorage, StorageSetup, Path)) then
            Error(GetLastErrorText());
    end;

    procedure DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        ExternalFileStorage: Codeunit "External File Storage";
    begin
        Initialize(StorageSetup, ExternalFileStorage);
        if not ExternalFileStorage.DeleteDirectory(ResolvePath(ExternalFileStorage, StorageSetup, Path)) then
            Error(GetLastErrorText());
    end;

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

    /// <summary>Prefixes the request path with the connection base path, using connector-aware path math.</summary>
    /// <remarks>
    /// Normalises the caller-supplied path before combining: leading and trailing slashes are
    /// stripped so that "/" and "" are both treated as "list the base-path root". This prevents
    /// CombinePath from producing an invalid path such as "origodemo/" when the caller passes
    /// "/" to mean the top-level directory.
    /// </remarks>
    local procedure ResolvePath(var ExternalFileStorage: Codeunit "External File Storage"; StorageSetup: Record "Storage Setup ori"; Path: Text): Text
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
    begin
        if not RequestMgt.PathIsSafe(Path) then
            RequestMgt.ThrowUnsafePath(Path);
        Path := Path.TrimStart('/').TrimEnd('/');
        if StorageSetup."Base Path" = '' then
            exit(Path);
        if Path = '' then
            exit(StorageSetup."Base Path");
        exit(ExternalFileStorage.CombinePath(StorageSetup."Base Path", Path));
    end;

    local procedure MaxListPages(): Integer
    begin
        exit(1000);
    end;
}
