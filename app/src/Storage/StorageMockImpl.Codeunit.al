namespace Origo.Bifrost.Attachments;

using System.ExternalFileStorage;
using System.Utilities;

/// <summary>Credential-free Mock connector. Persists company-local content and makes no HTTP requests.</summary>
codeunit 10035202 "Storage Mock Impl ori" implements "Storage Connector ori", "Storage Linked Move ori", "Storage Namespace ori"
{
    Access = Internal;

    /// <summary>Identifies the company-local namespace of a Mock connection.</summary>
    /// <returns>The connection code; separate codes never share Mock content.</returns>
    procedure GetNamespace(StorageSetup: Record "Storage Setup ori"): Text
    begin
        exit(StorageSetup.Code);
    end;

    /// <summary>All Mock move writes share the Business Central transaction.</summary>
    /// <returns>True; a failed transaction retains the source.</returns>
    procedure SupportsLinkedMove(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Checks that a connection identifies its own Mock namespace.</summary>
    procedure TestConnection(StorageSetup: Record "Storage Setup ori")
    begin
        StorageSetup.TestField(Code);
    end;

    /// <summary>Lists immediate children of the requested directory.</summary>
    procedure ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)
    var
        Entry: Record "Storage Mock Entry ori";
    begin
        TempFileAccountContent.Reset();
        TempFileAccountContent.DeleteAll();
        Path := ResolvePath(StorageSetup, Path);
        Entry.ReadIsolation := IsolationLevel::ReadCommitted;
        Entry.SetRange("Storage Code", StorageSetup.Code);
        Entry.SetRange("Entry Type", EntryType);
        if Entry.FindSet() then
            repeat
                if ParentPath(Entry.Path) = Path then begin
                    TempFileAccountContent.Init();
                    TempFileAccountContent.Type := EntryType;
                    TempFileAccountContent.Name := CopyStr(LeafName(Entry.Path), 1, MaxStrLen(TempFileAccountContent.Name));
                    TempFileAccountContent."Parent Directory" := CopyStr(Path, 1, MaxStrLen(TempFileAccountContent."Parent Directory"));
                    if TempFileAccountContent.Insert() then;
                end;
            until Entry.Next() = 0;
    end;

    /// <summary>Reads a file in this connection's namespace.</summary>
    procedure GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        Entry: Record "Storage Mock Entry ori";
        Source: InStream;
        Destination: OutStream;
    begin
        GetEntry(StorageSetup, Path, Enum::"Ext. File Storage File Type"::File, Entry);
        Entry.CalcFields(Content);
        Entry.Content.CreateInStream(Source);
        TempBlob.CreateOutStream(Destination);
        CopyStream(Destination, Source);
    end;

    /// <summary>Stores file bytes without a provider call.</summary>
    procedure CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        Entry: Record "Storage Mock Entry ori";
        Source: InStream;
        Destination: OutStream;
    begin
        PrepareEntry(StorageSetup, Path, Enum::"Ext. File Storage File Type"::File, Entry);
        Clear(Entry.Content);
        Entry.Content.CreateOutStream(Destination);
        TempBlob.CreateInStream(Source);
        CopyStream(Destination, Source);
        Entry.Modify(true);
    end;

    /// <summary>Deletes a file in this connection only.</summary>
    procedure DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        Entry: Record "Storage Mock Entry ori";
    begin
        GetEntry(StorageSetup, Path, Enum::"Ext. File Storage File Type"::File, Entry);
        Entry.Delete(true);
    end;

    /// <summary>Reports whether this connection contains the file.</summary>
    procedure FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    begin
        exit(Exists(StorageSetup, Path, Enum::"Ext. File Storage File Type"::File));
    end;

    /// <summary>Copies bytes within this connection.</summary>
    procedure CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        GetFile(StorageSetup, SourcePath, TempBlob);
        CreateFile(StorageSetup, TargetPath, TempBlob);
    end;

    /// <summary>Moves bytes within this connection.</summary>
    procedure MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    begin
        CopyFile(StorageSetup, SourcePath, TargetPath);
        DeleteFile(StorageSetup, SourcePath);
    end;

    /// <summary>Creates an explicit directory.</summary>
    procedure CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        Entry: Record "Storage Mock Entry ori";
    begin
        PrepareEntry(StorageSetup, Path, Enum::"Ext. File Storage File Type"::Directory, Entry);
    end;

    /// <summary>Deletes an empty directory; never removes descendant files.</summary>
    procedure DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        Entry: Record "Storage Mock Entry ori";
        Child: Record "Storage Mock Entry ori";
        DirectoryNotEmptyErr: Label 'The Mock directory is not empty.', Comment = 'is-IS=Prófunarmappan er ekki tóm.';
    begin
        GetEntry(StorageSetup, Path, Enum::"Ext. File Storage File Type"::Directory, Entry);
        Child.ReadIsolation := IsolationLevel::ReadCommitted;
        Child.SetRange("Storage Code", StorageSetup.Code);
        if Child.FindSet() then
            repeat
                if Child.Path.StartsWith(Entry.Path + '/') then
                    Error(DirectoryNotEmptyErr);
            until Child.Next() = 0;
        Entry.Delete(true);
    end;

    /// <summary>Reports root or an explicit directory in this connection.</summary>
    procedure DirectoryExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    begin
        if Path.TrimStart('/').TrimEnd('/') = '' then
            exit(true);
        exit(Exists(StorageSetup, Path, Enum::"Ext. File Storage File Type"::Directory));
    end;

    local procedure Exists(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"): Boolean
    var
        Entry: Record "Storage Mock Entry ori";
    begin
        Entry.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Entry.Get(StorageSetup.Code, ResolvePath(StorageSetup, Path)) then
            exit(false);
        exit(Entry."Entry Type" = EntryType);
    end;

    local procedure GetEntry(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var Entry: Record "Storage Mock Entry ori")
    begin
        Entry.Get(StorageSetup.Code, ResolvePath(StorageSetup, Path));
        Entry.TestField("Entry Type", EntryType);
    end;

    local procedure PrepareEntry(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var Entry: Record "Storage Mock Entry ori")
    begin
        Path := ResolvePath(StorageSetup, Path);
        if Entry.Get(StorageSetup.Code, Path) then begin
            Entry.TestField("Entry Type", EntryType);
            exit;
        end;
        Entry.Init();
        Entry."Storage Code" := StorageSetup.Code;
        Entry.Path := CopyStr(Path, 1, MaxStrLen(Entry.Path));
        Entry."Entry Type" := EntryType;
        Entry.Insert(true);
    end;

    local procedure ResolvePath(StorageSetup: Record "Storage Setup ori"; Path: Text): Text
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
        InvalidPathErr: Label 'The Mock storage path is invalid or longer than 250 characters.', Comment = 'is-IS=Slóð prófunargeymslu er ógild eða lengri en 250 stafir.';
    begin
        Path := RequestMgt.CombinedPath(StorageSetup."Base Path", Path);
        if (StrLen(Path) > 250) or not RequestMgt.PathIsSafe(Path) then
            Error(InvalidPathErr);
        exit(Path);
    end;

    local procedure ParentPath(Path: Text): Text
    var
        Index: Integer;
    begin
        for Index := StrLen(Path) downto 1 do
            if Path[Index] = '/' then
                exit(CopyStr(Path, 1, Index - 1));
        exit('');
    end;

    local procedure LeafName(Path: Text): Text
    var
        Parent: Text;
    begin
        Parent := ParentPath(Path);
        if Parent = '' then
            exit(Path);
        exit(CopyStr(Path, StrLen(Parent) + 2));
    end;
}
