namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;
using System.Text;
using System.Utilities;

/// <summary>
/// In-memory <c>Bifrost Storage Connector</c> implementation used by the connector tests. Backed
/// by <c>Bifrost Storage Mock State</c>, it exercises the full message-type pipeline without a
/// live storage account. Paths are treated as opaque keys; the base path is not applied.
/// </summary>
codeunit 96200 "Storage Mock Impl" implements "Storage Connector ori"
{
    var
        FileNotFoundErr: Label 'Mock file ''%1'' was not found.', Comment = '%1 = path';
        DirNotFoundErr: Label 'Mock directory ''%1'' was not found.', Comment = '%1 = path';

    procedure TestConnection(StorageSetup: Record "Storage Setup ori")
    begin
        // The in-memory backend is always reachable.
    end;

    procedure ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)
    var
        MockState: Codeunit "Storage Mock State";
        Paths: List of [Text];
        EntryPath: Text;
    begin
        TempFileAccountContent.Reset();
        TempFileAccountContent.DeleteAll();
        if EntryType = EntryType::Directory then
            Paths := MockState.DirectoryPaths()
        else
            Paths := MockState.FilePaths();
        foreach EntryPath in Paths do
            if ParentOf(EntryPath) = Path then begin
                TempFileAccountContent.Init();
                TempFileAccountContent."Type" := EntryType;
                TempFileAccountContent.Name := CopyStr(LeafOf(EntryPath), 1, MaxStrLen(TempFileAccountContent.Name));
                TempFileAccountContent."Parent Directory" := CopyStr(Path, 1, MaxStrLen(TempFileAccountContent."Parent Directory"));
                if TempFileAccountContent.Insert() then;
            end;
    end;

    procedure GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        MockState: Codeunit "Storage Mock State";
        Base64Convert: Codeunit "Base64 Convert";
        ContentOutStream: OutStream;
    begin
        if not MockState.HasFile(Path) then
            Error(FileNotFoundErr, Path);
        TempBlob.CreateOutStream(ContentOutStream);
        Base64Convert.FromBase64(MockState.GetFileContent(Path), ContentOutStream);
    end;

    procedure CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        MockState: Codeunit "Storage Mock State";
        Base64Convert: Codeunit "Base64 Convert";
        ContentInStream: InStream;
    begin
        TempBlob.CreateInStream(ContentInStream);
        MockState.PutFile(Path, Base64Convert.ToBase64(ContentInStream));
    end;

    procedure DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        MockState: Codeunit "Storage Mock State";
    begin
        if not MockState.HasFile(Path) then
            Error(FileNotFoundErr, Path);
        MockState.RemoveFile(Path);
    end;

    procedure FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        MockState: Codeunit "Storage Mock State";
    begin
        exit(MockState.HasFile(Path));
    end;

    procedure CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    var
        MockState: Codeunit "Storage Mock State";
    begin
        if not MockState.HasFile(SourcePath) then
            Error(FileNotFoundErr, SourcePath);
        MockState.PutFile(TargetPath, MockState.GetFileContent(SourcePath));
    end;

    procedure MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    var
        MockState: Codeunit "Storage Mock State";
    begin
        if not MockState.HasFile(SourcePath) then
            Error(FileNotFoundErr, SourcePath);
        MockState.PutFile(TargetPath, MockState.GetFileContent(SourcePath));
        MockState.RemoveFile(SourcePath);
    end;

    procedure CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        MockState: Codeunit "Storage Mock State";
    begin
        MockState.AddDirectory(Path);
    end;

    procedure DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        MockState: Codeunit "Storage Mock State";
    begin
        if not MockState.HasDirectory(Path) then
            Error(DirNotFoundErr, Path);
        MockState.RemoveDirectory(Path);
    end;

    procedure DirectoryExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        MockState: Codeunit "Storage Mock State";
    begin
        exit(MockState.HasDirectory(Path));
    end;

    local procedure ParentOf(Path: Text): Text
    var
        Position: Integer;
    begin
        Position := LastSeparatorPosition(Path);
        if Position = 0 then
            exit('');
        exit(CopyStr(Path, 1, Position - 1));
    end;

    local procedure LeafOf(Path: Text): Text
    var
        Position: Integer;
    begin
        Position := LastSeparatorPosition(Path);
        if Position = 0 then
            exit(Path);
        exit(CopyStr(Path, Position + 1));
    end;

    local procedure LastSeparatorPosition(Path: Text): Integer
    var
        Index: Integer;
        Result: Integer;
    begin
        for Index := 1 to StrLen(Path) do
            if Path[Index] = '/' then
                Result := Index;
        exit(Result);
    end;
}
