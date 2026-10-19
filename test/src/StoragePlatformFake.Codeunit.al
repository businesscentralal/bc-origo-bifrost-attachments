namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;
using System.Utilities;

/// <summary>Test-only platform connector with account-isolated in-memory storage and no account tables.</summary>
codeunit 96239 "Storage Platform Fake ori" implements "External File Storage Connector"
{
    SingleInstance = true;

    var
        FoldedPaths: Boolean;
        FailExistenceCheck: Boolean;

    /// <summary>Configures an opaque connector-owned comparison rule for generic alias safety tests.</summary>
    /// <param name="NewFoldedPaths">True to fold case and percent escapes inside this test connector.</param>
    procedure SetFoldedPaths(NewFoldedPaths: Boolean)
    begin
        FoldedPaths := NewFoldedPaths;
    end;

    /// <summary>Controls failure of the connector's read-only destination check.</summary>
    /// <param name="NewFailExistenceCheck">True to reject existence checks before any mutation.</param>
    procedure SetFailExistenceCheck(NewFailExistenceCheck: Boolean)
    begin
        FailExistenceCheck := NewFailExistenceCheck;
    end;

    /// <summary>Lists the account's immediate files through the instrumented in-memory backend.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    /// <param name="FilePaginationData">Pagination state marked complete by this in-memory connector.</param>
    /// <param name="TempFileAccountContent">Temporary result rows returned to the facade.</param>
    procedure ListFiles(AccountId: Guid; Path: Text; FilePaginationData: Codeunit "File Pagination Data"; var TempFileAccountContent: Record "File Account Content" temporary)
    begin
        ListEntries(AccountId, Path, Enum::"Ext. File Storage File Type"::File, FilePaginationData, TempFileAccountContent);
    end;

    /// <summary>Returns the exact stored bytes through the platform stream contract.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    /// <param name="Stream">The platform stream used to transfer the exact file bytes.</param>
    procedure GetFile(AccountId: Guid; Path: Text; Stream: InStream)
    var
        Mock: Codeunit "Storage Mock Impl";
        TempBlob: Codeunit "Temp Blob";
        Content: HttpContent;
        ContentInStream: InStream;
    begin
        Mock.GetFile(AccountSetup(AccountId), ProviderPath(Path), TempBlob);
        // Materialize the return stream across the platform interface, like the Microsoft connector.
        TempBlob.CreateInStream(ContentInStream);
        Content.WriteFrom(ContentInStream);
        Content.ReadAs(Stream);
    end;

    /// <summary>Stores the incoming stream, preserving the account and path received from the facade.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    /// <param name="Stream">The platform stream used to transfer the exact file bytes.</param>
    procedure CreateFile(AccountId: Guid; Path: Text; Stream: InStream)
    var
        Mock: Codeunit "Storage Mock Impl";
        TempBlob: Codeunit "Temp Blob";
        ContentOutStream: OutStream;
    begin
        TempBlob.CreateOutStream(ContentOutStream);
        CopyStream(ContentOutStream, Stream);
        Mock.CreateFile(AccountSetup(AccountId), ProviderPath(Path), TempBlob);
    end;

    /// <summary>Copies within the account and exposes the existing deterministic write failure seam.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="SourcePath">Connector-relative source path.</param>
    /// <param name="TargetPath">Connector-relative destination path.</param>
    procedure CopyFile(AccountId: Guid; SourcePath: Text; TargetPath: Text)
    var
        Mock: Codeunit "Storage Mock Impl";
    begin
        Mock.CopyFile(AccountSetup(AccountId), ProviderPath(SourcePath), ProviderPath(TargetPath));
    end;

    /// <summary>Moves within the account without any provider-specific interpretation.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="SourcePath">Connector-relative source path.</param>
    /// <param name="TargetPath">Connector-relative destination path.</param>
    procedure MoveFile(AccountId: Guid; SourcePath: Text; TargetPath: Text)
    var
        Mock: Codeunit "Storage Mock Impl";
    begin
        Mock.MoveFile(AccountSetup(AccountId), ProviderPath(SourcePath), ProviderPath(TargetPath));
    end;

    /// <summary>Checks the account-isolated file map.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    /// <returns>True when the connector operation succeeds or the requested entry exists.</returns>
    procedure FileExists(AccountId: Guid; Path: Text): Boolean
    var
        Mock: Codeunit "Storage Mock Impl";
        InjectedExistenceErr: Label 'Injected platform existence failure.', Locked = true;
    begin
        if FailExistenceCheck then
            Error(InjectedExistenceErr);
        exit(Mock.FileExists(AccountSetup(AccountId), ProviderPath(Path)));
    end;

    /// <summary>Deletes from the account-isolated file map.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    procedure DeleteFile(AccountId: Guid; Path: Text)
    var
        Mock: Codeunit "Storage Mock Impl";
    begin
        Mock.DeleteFile(AccountSetup(AccountId), ProviderPath(Path));
    end;

    /// <summary>Lists the account's immediate directories.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    /// <param name="FilePaginationData">Pagination state marked complete by this in-memory connector.</param>
    /// <param name="TempFileAccountContent">Temporary result rows returned to the facade.</param>
    procedure ListDirectories(AccountId: Guid; Path: Text; FilePaginationData: Codeunit "File Pagination Data"; var TempFileAccountContent: Record "File Account Content" temporary)
    begin
        ListEntries(AccountId, Path, Enum::"Ext. File Storage File Type"::Directory, FilePaginationData, TempFileAccountContent);
    end;

    /// <summary>Creates a directory in the account-isolated map.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    procedure CreateDirectory(AccountId: Guid; Path: Text)
    var
        Mock: Codeunit "Storage Mock Impl";
    begin
        Mock.CreateDirectory(AccountSetup(AccountId), ProviderPath(Path));
    end;

    /// <summary>Checks the account-isolated directory map.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    /// <returns>True when the connector operation succeeds or the requested entry exists.</returns>
    procedure DirectoryExists(AccountId: Guid; Path: Text): Boolean
    var
        Mock: Codeunit "Storage Mock Impl";
    begin
        exit(Mock.DirectoryExists(AccountSetup(AccountId), ProviderPath(Path)));
    end;

    /// <summary>Deletes a directory from the account-isolated map.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <param name="Path">Connector-relative path received from the platform facade.</param>
    procedure DeleteDirectory(AccountId: Guid; Path: Text)
    var
        Mock: Codeunit "Storage Mock Impl";
    begin
        Mock.DeleteDirectory(AccountSetup(AccountId), ProviderPath(Path));
    end;

    /// <summary>The operation fake has no persistent account registry to enumerate.</summary>
    /// <param name="TempAccounts">Temporary account result supplied by the platform.</param>
    procedure GetAccounts(var TempAccounts: Record "File Account" temporary)
    begin
        TempAccounts.Reset();
        TempAccounts.DeleteAll();
    end;

    /// <summary>The operation fake has no account management UI.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    procedure ShowAccountInformation(AccountId: Guid)
    begin
    end;

    /// <summary>Registers a temporary account without consulting a connector-specific table.</summary>
    /// <param name="TempFileAccount">Temporary registered account returned to the platform.</param>
    /// <returns>True when the connector operation succeeds or the requested entry exists.</returns>
    procedure RegisterAccount(var TempFileAccount: Record "File Account" temporary): Boolean
    begin
        TempFileAccount.Init();
        TempFileAccount."Account Id" := CreateGuid();
        TempFileAccount.Name := 'In-memory interface account';
        TempFileAccount.Connector := Enum::"Ext. File Storage Connector"::"Interface Test ori";
        TempFileAccount.Insert();
        exit(true);
    end;

    /// <summary>Account registration has no persistent rows to delete.</summary>
    /// <param name="AccountId">Opaque account identifier received from the platform facade.</param>
    /// <returns>True when the connector operation succeeds or the requested entry exists.</returns>
    procedure DeleteAccount(AccountId: Guid): Boolean
    begin
        exit(true);
    end;

    /// <summary>The operation fake supplies no logo.</summary>
    /// <returns>The connector-provided text.</returns>
    procedure GetLogoAsBase64(): Text
    begin
        exit('');
    end;

    /// <summary>Returns the test connector's machine-facing description.</summary>
    /// <returns>The connector-provided text.</returns>
    procedure GetDescription(): Text[250]
    begin
        exit('In-memory platform interface test connector');
    end;

    local procedure ListEntries(AccountId: Guid; Path: Text; EntryType: Enum "Ext. File Storage File Type"; FilePaginationData: Codeunit "File Pagination Data"; var TempFileAccountContent: Record "File Account Content" temporary)
    var
        Mock: Codeunit "Storage Mock Impl";
    begin
        Mock.ListEntries(AccountSetup(AccountId), ProviderPath(Path), EntryType, TempFileAccountContent);
        if TempFileAccountContent.FindSet() then
            repeat
                TempFileAccountContent."Parent Directory" := CopyStr(Path, 1, MaxStrLen(TempFileAccountContent."Parent Directory"));
                TempFileAccountContent.Modify();
            until TempFileAccountContent.Next() = 0;
        FilePaginationData.SetEndOfListing(true);
    end;

    local procedure AccountSetup(AccountId: Guid) StorageSetup: Record "Storage Setup ori"
    begin
        // The private dictionary namespace proves the facade forwards the selected account GUID.
        StorageSetup."Base Path" := Format(AccountId, 0, 4);
    end;

    local procedure ProviderPath(Path: Text): Text
    var
        Uri: Codeunit Uri;
    begin
        if FoldedPaths then
            exit(LowerCase(Uri.UnescapeDataString(Path)));
        exit(Path);
    end;
}
