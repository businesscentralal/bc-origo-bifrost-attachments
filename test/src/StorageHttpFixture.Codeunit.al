namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;
using System.Utilities;

/// <summary>Loopback-only external file fixture for owned-container MCP tests. Never a production provider.</summary>
codeunit 96266 "Storage HTTP Fixture ori" implements "Storage Connector ori"
{
    var
        UnsupportedErr: Label 'This owned test fixture supports files only.', Locked = true;
        InvalidPathErr: Label 'Only isolated W8168 storage codes and simple w8168 file names are allowed.', Locked = true;
        TransportErr: Label 'The owned loopback fixture request failed.', Locked = true;
        StatusErr: Label 'The owned loopback fixture returned HTTP %1.', Locked = true;

    procedure TestConnection(StorageSetup: Record "Storage Setup ori")
    begin
        FileExists(StorageSetup, 'w8168-health.txt');
    end;

    procedure ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)
    begin
        Error(UnsupportedErr);
    end;

    procedure GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        Source: InStream;
        Destination: OutStream;
    begin
        if not Client.Get(Url(StorageSetup, Path), Response) then
            Error(TransportErr);
        CheckResponse(Response);
        Response.Content.ReadAs(Source);
        TempBlob.CreateOutStream(Destination);
        CopyStream(Destination, Source);
    end;

    procedure CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")
    var
        Client: HttpClient;
        Content: HttpContent;
        Response: HttpResponseMessage;
        Source: InStream;
    begin
        TempBlob.CreateInStream(Source);
        Content.WriteFrom(Source);
        if not Client.Post(Url(StorageSetup, Path), Content, Response) then
            Error(TransportErr);
        CheckResponse(Response);
    end;

    procedure DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
    begin
        if not Client.Delete(Url(StorageSetup, Path), Response) then
            Error(TransportErr);
        CheckResponse(Response);
    end;

    procedure FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
    begin
        if not Client.Get(Url(StorageSetup, Path), Response) then
            Error(TransportErr);
        if Response.HttpStatusCode() = 404 then
            exit(false);
        CheckResponse(Response);
        exit(true);
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

    local procedure Url(StorageSetup: Record "Storage Setup ori"; Path: Text): Text
    var
        Index: Integer;
        Allowed: Text;
    begin
        if (CopyStr(StorageSetup.Code, 1, 5) <> 'W8168') or
           (CopyStr(Path, 1, 5) <> 'w8168') or (StorageSetup."Base Path" <> '')
        then
            Error(InvalidPathErr);
        Allowed := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.';
        for Index := 1 to StrLen(StorageSetup.Code) do
            if StrPos(Allowed, CopyStr(StorageSetup.Code, Index, 1)) = 0 then
                Error(InvalidPathErr);
        for Index := 1 to StrLen(Path) do
            if StrPos(Allowed, CopyStr(Path, Index, 1)) = 0 then
                Error(InvalidPathErr);
        exit('http://localhost:9626/' + StorageSetup.Code + '/' + Path);
    end;

    local procedure CheckResponse(Response: HttpResponseMessage)
    begin
        if not Response.IsSuccessStatusCode() then
            Error(StatusErr, Response.HttpStatusCode());
    end;
}
