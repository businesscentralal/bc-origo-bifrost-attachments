namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;
using System.Utilities;

/// <summary>
/// Test-only persistent storage seam. MCP calls use the normal production dispatcher, upload,
/// linked attachment and base-app processing paths; this adapter supplies isolated fixture bytes.
/// It does not intercept licensing or claim external-provider integration certification.
/// </summary>
codeunit 96250 "Storage 23 Fixture Impl ori" implements "Storage Connector ori"
{
    var
        UnsupportedErr: Label 'This test fixture supports file create, read, delete, exists and list only.', Locked = true;

    /// <summary>Tests the local fixture store; there is no external account.</summary>
    procedure TestConnection(StorageSetup: Record "Storage Setup ori")
    begin
    end;

    /// <summary>Lists files belonging only to this fixture storage code and directory.</summary>
    procedure ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)
    var
        StoredFile: Record "Storage 23 Fixture File ori";
        SlashAt: Integer;
        ParentPath: Text;
        FileName: Text;
    begin
        TempFileAccountContent.Reset();
        TempFileAccountContent.DeleteAll();
        if EntryType <> EntryType::File then
            exit;
        StoredFile.SetRange("Storage Code", StorageSetup.Code);
        if StoredFile.FindSet() then
            repeat
                SlashAt := StoredFile.Path.LastIndexOf('/');
                if SlashAt = 0 then begin
                    ParentPath := '';
                    FileName := StoredFile.Path;
                end else begin
                    ParentPath := CopyStr(StoredFile.Path, 1, SlashAt - 1);
                    FileName := CopyStr(StoredFile.Path, SlashAt + 1);
                end;
                if ParentPath = Path then begin
                    TempFileAccountContent.Init();
                    TempFileAccountContent."Type" := EntryType;
                    TempFileAccountContent.Name := CopyStr(FileName, 1, MaxStrLen(TempFileAccountContent.Name));
                    TempFileAccountContent."Parent Directory" := CopyStr(ParentPath, 1, MaxStrLen(TempFileAccountContent."Parent Directory"));
                    TempFileAccountContent.Insert();
                end;
            until StoredFile.Next() = 0;
    end;

    /// <summary>Reads exact persisted fixture bytes through the production connector interface.</summary>
    procedure GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        StoredFile: Record "Storage 23 Fixture File ori";
        ContentIn: InStream;
        ContentOut: OutStream;
    begin
        StoredFile.Get(StorageSetup.Code, Path);
        StoredFile.CalcFields(Content);
        StoredFile.Content.CreateInStream(ContentIn);
        TempBlob.CreateOutStream(ContentOut);
        CopyStream(ContentOut, ContentIn);
    end;

    /// <summary>Persists caller-created fixture bytes, scoped by storage code and exact path.</summary>
    procedure CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        StoredFile: Record "Storage 23 Fixture File ori";
        ContentIn: InStream;
        ContentOut: OutStream;
        Exists: Boolean;
    begin
        Exists := StoredFile.Get(StorageSetup.Code, Path);
        if not Exists then begin
            StoredFile.Init();
            StoredFile."Storage Code" := StorageSetup.Code;
            StoredFile.Path := CopyStr(Path, 1, MaxStrLen(StoredFile.Path));
        end;
        TempBlob.CreateInStream(ContentIn);
        StoredFile.Content.CreateOutStream(ContentOut);
        CopyStream(ContentOut, ContentIn);
        if Exists then
            StoredFile.Modify()
        else
            StoredFile.Insert();
    end;

    /// <summary>Deletes only the exact file owned by the selected fixture storage code.</summary>
    procedure DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        StoredFile: Record "Storage 23 Fixture File ori";
    begin
        StoredFile.Get(StorageSetup.Code, Path);
        StoredFile.Delete();
    end;

    /// <summary>Reports whether the exact fixture file exists.</summary>
    procedure FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        StoredFile: Record "Storage 23 Fixture File ori";
    begin
        exit(StoredFile.Get(StorageSetup.Code, Path));
    end;

    /// <summary>Refuses an operation outside this fixture's verification scope.</summary>
    procedure CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    begin
        Error(UnsupportedErr);
    end;

    /// <summary>Refuses an operation outside this fixture's verification scope.</summary>
    procedure MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    begin
        Error(UnsupportedErr);
    end;

    /// <summary>Refuses an operation outside this fixture's verification scope.</summary>
    procedure CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    begin
        Error(UnsupportedErr);
    end;

    /// <summary>Refuses an operation outside this fixture's verification scope.</summary>
    procedure DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    begin
        Error(UnsupportedErr);
    end;

    /// <summary>The fixture has a root directory only.</summary>
    procedure DirectoryExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    begin
        exit(Path = '');
    end;
}
