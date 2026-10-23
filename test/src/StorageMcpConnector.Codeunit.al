namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;
using System.Utilities;

/// <summary>Test-only persisted connector for isolated MCP contract checks, not provider, transaction or licensing certification.</summary>
codeunit 96262 "Storage MCP Connector ori" implements "Storage Connector ori"
{
    var
        UnsupportedErr: Label 'This test fixture supports files only.', Locked = true;
        PathTooLongErr: Label 'The test fixture path is longer than 250 characters.', Locked = true;

    procedure TestConnection(StorageSetup: Record "Storage Setup ori")
    begin
    end;

    procedure ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)
    var
        File: Record "Storage MCP File ori";
        Segments: List of [Text];
        Prefix: Text;
        RelativePath: Text;
        EntryPath: Text;
    begin
        TempFileAccountContent.Reset();
        TempFileAccountContent.DeleteAll();
        Path := ResolvePath(StorageSetup, Path).TrimEnd('/');
        Prefix := Path;
        if Prefix <> '' then
            Prefix += '/';
        File.SetRange("Storage Code", StorageSetup.Code);
        if File.FindSet() then
            repeat
                if File.Path.StartsWith(Prefix) then begin
                    RelativePath := CopyStr(File.Path, StrLen(Prefix) + 1);
                    Segments := RelativePath.Split('/');
                    Clear(EntryPath);
                    if (EntryType = EntryType::File) and (Segments.Count() = 1) and (RelativePath <> '') then
                        EntryPath := File.Path;
                    if (EntryType = EntryType::Directory) and (Segments.Count() > 1) then
                        EntryPath := Prefix + Segments.Get(1);
                    if EntryPath <> '' then begin
                        TempFileAccountContent.Init();
                        TempFileAccountContent."Type" := EntryType;
                        // Deliberately return provider-prefixed names as well as parents:
                        // the public serializer must keep both private.
                        TempFileAccountContent.Name := CopyStr(EntryPath, 1, MaxStrLen(TempFileAccountContent.Name));
                        TempFileAccountContent."Parent Directory" := CopyStr(Path, 1, MaxStrLen(TempFileAccountContent."Parent Directory"));
                        if TempFileAccountContent.Insert() then;
                    end;
                end;
            until File.Next() = 0;
    end;

    procedure GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        File: Record "Storage MCP File ori";
        Source: InStream;
        Destination: OutStream;
    begin
        File.Get(StorageSetup.Code, ResolvePath(StorageSetup, Path));
        File.CalcFields(Content);
        File.Content.CreateInStream(Source);
        TempBlob.CreateOutStream(Destination);
        CopyStream(Destination, Source);
    end;

    procedure CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        File: Record "Storage MCP File ori";
        Source: InStream;
        Destination: OutStream;
    begin
        Path := ResolvePath(StorageSetup, Path);
        if not File.Get(StorageSetup.Code, Path) then begin
            File.Init();
            File."Storage Code" := StorageSetup.Code;
            File.Path := CopyStr(Path, 1, MaxStrLen(File.Path));
            File.Insert();
        end;
        Clear(File.Content);
        File.Content.CreateOutStream(Destination);
        TempBlob.CreateInStream(Source);
        CopyStream(Destination, Source);
        File.Modify();
    end;

    procedure DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        File: Record "Storage MCP File ori";
    begin
        File.Get(StorageSetup.Code, ResolvePath(StorageSetup, Path));
        File.Delete();
    end;

    procedure FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        File: Record "Storage MCP File ori";
    begin
        exit(File.Get(StorageSetup.Code, ResolvePath(StorageSetup, Path)));
    end;

    procedure CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        GetFile(StorageSetup, SourcePath, TempBlob);
        CreateFile(StorageSetup, TargetPath, TempBlob);
    end;

    procedure MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)
    begin
        CopyFile(StorageSetup, SourcePath, TargetPath);
        DeleteFile(StorageSetup, SourcePath);
    end;

    procedure CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    begin
        Error(UnsupportedErr);
    end;

    procedure DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)
    begin
        Error(UnsupportedErr);
    end;

    procedure DirectoryExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    begin
        exit(false);
    end;

    local procedure ResolvePath(StorageSetup: Record "Storage Setup ori"; Path: Text): Text
    begin
        Path := Path.TrimStart('/').TrimEnd('/');
        if StorageSetup."Base Path" <> '' then
            Path := StorageSetup."Base Path".TrimStart('/').TrimEnd('/') + '/' + Path;
        if StrLen(Path) > 250 then
            Error(PathTooLongErr);
        exit(Path);
    end;
}
