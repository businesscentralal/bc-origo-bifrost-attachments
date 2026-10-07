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
        BlobSegmentModeLbl: Label 'Blob segment mode', Comment = 'is-IS=hlutastilling Blob';
        SharePointRootLbl: Label 'SharePoint decoded library root and comparison', Comment = 'is-IS=afkóðuð safnrót SharePoint og samanburður';
        ConnectorSchemaLbl: Label 'connector package schema', Comment = 'is-IS=skema tengipakka';
        AccountSchemaLbl: Label 'account field schema', Comment = 'is-IS=skema reikningsreita';
        AccountMetadataLbl: Label 'registered account metadata', Comment = 'is-IS=lýsigögn skráðs reiknings';
        AzureIdentityLbl: Label 'Azure account and resource identity', Comment = 'is-IS=auðkenni Azure-reiknings og tilfangs';
        FileShareComparisonLbl: Label 'File Share Unicode comparison', Comment = 'is-IS=Unicode-samanburður File Share';
        MetadataPermissionErr: Label 'The storage account address cannot be read with your permissions.', Comment = 'is-IS=Ekki er hægt að lesa slóð geymslureiknings með þínum heimildum.';
        MetadataExpectedLbl: Label 'verified public account metadata and operation capability', Comment = 'is-IS=staðfest opinber lýsigögn reiknings og stuðningur við aðgerð';
        MetadataNextStepLbl: Label 'Ask the administrator for read permission on the selected storage account.', Comment = 'is-IS=Biddu kerfisstjóra um lesheimild á völdum geymslureikningi.';
        ProviderUnverifiedErr: Label 'This storage operation requires provider information that has not been verified. Nothing was changed.', Comment = 'is-IS=Þessi geymsluaðgerð þarfnast upplýsinga um þjónustuveitu sem hafa ekki verið staðfestar. Engu var breytt.';
        ProviderNextStepLbl: Label 'Ask the administrator to verify the named provider capability before retrying this operation.', Comment = 'is-IS=Biddu kerfisstjóra um að staðfesta tilgreindan stuðning þjónustuveitu áður en aðgerðin er reynd aftur.';
        ProviderPathErr: Label 'The complete path is not supported by this storage provider. Nothing was changed.', Comment = 'is-IS=Þessi geymsluþjónusta styður ekki slóðina í heild. Engu var breytt.';
        FileDepthExpectedLbl: Label 'at most 250 directory components', Comment = 'is-IS=í mesta lagi 250 möppuhlutar';
        FileNameExpectedLbl: Label 'unambiguous Azure File Share names', Comment = 'is-IS=ótvíræð heiti í Azure File Share';
        ProviderPathNextStepLbl: Label 'Shorten the path or choose file names supported by the selected provider.', Comment = 'is-IS=Styttu slóðina eða veldu skráarheiti sem valin þjónusta styður.';
        InvalidPathErr: Label 'The storage path is invalid. Nothing was changed.', Comment = 'is-IS=Geymsluslóðin er ógild. Engu var breytt.';
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

    /// <summary>Checks known provider budgets before a mutation; unknown capabilities remain explicit delivery gates.</summary>
    internal procedure CheckMutationPath(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; ParameterName: Text; Path: Text; IsDirectory: Boolean): Boolean
    var
        Scope: Text;
        Address: Text;
        CaseSensitive: Boolean;
    begin
        if StorageSetup."Storage Type" <> StorageSetup."Storage Type"::"External File Storage" then
            exit(true);
        if not ResolvePhysicalAddress(Argument, StorageSetup, Path, Scope, Address, CaseSensitive) then
            exit(false);
        CheckProviderBudget(Argument, StorageSetup.Connector.AsInteger(), ParameterName, Address, IsDirectory);
        exit(not Argument.HasCollectedErrors());
    end;

    /// <summary>Validates complete resolved provider paths without reading an account or calling a provider.</summary>
    internal procedure CheckProviderBudget(var Argument: Record "Message Argument ori"; ConnectorId: Integer; ParameterName: Text; Address: Text; IsDirectory: Boolean)
    var
        Reader: Codeunit "Storage Request Reader ori";
    begin
        case ConnectorId of
            4560:
                begin
                    Reader.CheckAddressLength(Argument, ParameterName, Address, 1024);
                    // No HNS mode is exposed by the public account schema. Deep flat paths are
                    // not malformed: they require the actual account mode to be established.
                    if Address.Split('/').Count() > 61 then
                        AddUnverifiedOperation(Argument, ParameterName, BlobSegmentModeLbl);
                end;
            4570:
                CheckFileSharePath(Argument, ParameterName, Address, IsDirectory);
            4580:
                // Caller must supply the complete decoded server-relative path, including library root.
                Reader.CheckAddressLength(Argument, ParameterName, Address, 400);
        end;
    end;

    /// <summary>Resolves public nonsecret Azure account metadata and the exact base-prefixed address.</summary>
    internal procedure ResolvePhysicalAddress(var Argument: Record "Message Argument ori"; StorageSetup: Record "Storage Setup ori"; Path: Text; var Scope: Text; var Address: Text; var CaseSensitive: Boolean): Boolean
    var
        RequestMgt: Codeunit "Storage Request Mgt ori";
        Account: RecordRef;
        AccountId: FieldRef;
        HostName: Text;
        RootName: Text;
        AccountTableName: Text;
        RootFieldName: Text;
        ConnectorId: Integer;
    begin
        Address := RequestMgt.CombinedPath(StorageSetup."Base Path", Path);
        CaseSensitive := true;
        Scope := Format(StorageSetup."Storage Type".AsInteger(), 0, 9) + ':' + Format(StorageSetup.Connector.AsInteger(), 0, 9) + ':' + Format(StorageSetup."File Account Id", 0, 4);
        if StorageSetup."Storage Type" <> StorageSetup."Storage Type"::"External File Storage" then
            exit(true);
        ConnectorId := StorageSetup.Connector.AsInteger();
        case ConnectorId of
            4560:
                begin
                    AccountTableName := 'Ext. Blob Storage Account';
                    RootFieldName := 'Container Name';
                end;
            4570:
                begin
                    AccountTableName := 'Ext. File Share Account';
                    RootFieldName := 'File Share Name';
                    CaseSensitive := false;
                end;
            4580:
                begin
                    AddUnverifiedOperation(Argument, 'storageCode', SharePointRootLbl);
                    exit(false);
                end;
            else
                // No guessed provider limits or case folding for partner connectors.
                exit(true);
        end;
        if not KnownAccountModule(ConnectorId) then begin
            AddUnverifiedOperation(Argument, 'storageCode', ConnectorSchemaLbl);
            exit(false);
        end;
        Account.Open(ConnectorId);
        Account.ReadIsolation := IsolationLevel::RepeatableRead;
        if not Account.ReadPermission() then begin
            Account.Close();
            Argument.AddError("Bifrost Error Code ori"::PermissionDenied, MetadataPermissionErr, 'storageCode', StorageSetup.Code, MetadataExpectedLbl, MetadataNextStepLbl);
            exit(false);
        end;
        if (Account.Name <> AccountTableName) or not IsMetadataField(Account, 1, 'Id', FieldType::Guid) or
           not IsMetadataField(Account, 3, 'Storage Account Name', FieldType::Text) or not IsMetadataField(Account, 4, RootFieldName, FieldType::Text)
        then begin
            Account.Close();
            AddUnverifiedOperation(Argument, 'storageCode', AccountSchemaLbl);
            exit(false);
        end;
        // Only the three verified public fields are loaded; no secret fields or getters.
        Account.SetLoadFields(1, 3, 4);
        AccountId := Account.Field(1);
        AccountId.SetRange(StorageSetup."File Account Id");
        if not Account.FindFirst() then begin
            Account.Close();
            AddUnverifiedOperation(Argument, 'storageCode', AccountMetadataLbl);
            exit(false);
        end;
        HostName := Account.Field(3).Value;
        RootName := Account.Field(4).Value;
        Account.Close();
        if not IsAzureResourceName(HostName, false) or not IsAzureResourceName(RootName, true) then begin
            AddUnverifiedOperation(Argument, 'storageCode', AzureIdentityLbl);
            exit(false);
        end;
        Scope := Format(ConnectorId, 0, 9) + ':' + HostName + '/' + RootName;
        if (ConnectorId = 4570) and ContainsNonAscii(Address) then begin
            AddUnverifiedOperation(Argument, 'path', FileShareComparisonLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure KnownAccountModule(ConnectorId: Integer): Boolean
    var
        AccountModule: ModuleInfo;
        ModuleId: Guid;
    begin
        case ConnectorId of
            4560:
                ModuleId := 'c9ce86fe-cb70-4b79-be03-d21856b1a4ca';
            4570:
                ModuleId := '79447b11-8301-4d02-a546-2261eb811296';
        end;
        if not NavApp.GetModuleInfo(ModuleId, AccountModule) then
            exit(false);
        // Exact source inspected at 28.5.54151.55751. Other packages need schema/source evidence.
        exit((AccountModule.AppVersion.Major = 28) and (AccountModule.AppVersion.Minor = 5) and
             (AccountModule.AppVersion.Build = 54151) and (AccountModule.AppVersion.Revision = 55751));
    end;

    local procedure IsMetadataField(Account: RecordRef; FieldNumber: Integer; FieldName: Text; ExpectedType: FieldType): Boolean
    var
        MetadataField: FieldRef;
    begin
        if not Account.FieldExist(FieldNumber) then
            exit(false);
        MetadataField := Account.Field(FieldNumber);
        exit((MetadataField.Name = FieldName) and (MetadataField.Type = ExpectedType));
    end;

    local procedure IsAzureResourceName(ResourceName: Text; AllowDash: Boolean): Boolean
    var
        CharacterIndex: Integer;
    begin
        if ResourceName = '' then
            exit(false);
        for CharacterIndex := 1 to StrLen(ResourceName) do
            if not (ResourceName[CharacterIndex] in ['a' .. 'z', '0' .. '9']) then
                if (not AllowDash) or (ResourceName[CharacterIndex] <> '-') then
                    exit(false);
        exit(true);
    end;

    local procedure ContainsNonAscii(Address: Text): Boolean
    var
        CharacterIndex: Integer;
    begin
        for CharacterIndex := 1 to StrLen(Address) do
            if Address[CharacterIndex] > 127 then
                exit(true);
        exit(false);
    end;

    local procedure CheckFileSharePath(var Argument: Record "Message Argument ori"; ParameterName: Text; Address: Text; IsDirectory: Boolean)
    var
        Reader: Codeunit "Storage Request Reader ori";
        Segments: List of [Text];
        Segment: Text;
    begin
        Reader.CheckAddressLength(Argument, ParameterName, Address, 2048);
        Segments := Address.Split('/');
        if (Segments.Count() > 251) or (IsDirectory and (Segments.Count() > 250)) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, ProviderPathErr, ParameterName, Address, FileDepthExpectedLbl, ProviderPathNextStepLbl);
        foreach Segment in Segments do begin
            Reader.CheckAddressLength(Argument, ParameterName, Segment, 255);
            if Segment.EndsWith('.') or Segment.EndsWith(' ') or Segment.Contains(':') or Segment.Contains('*') or Segment.Contains('?') or
               Segment.Contains('"') or Segment.Contains('<') or Segment.Contains('>') or Segment.Contains('|')
            then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, ProviderPathErr, ParameterName, Address, FileNameExpectedLbl, ProviderPathNextStepLbl);
        end;
    end;

    /// <summary>Collects a specific unresolved operation gate without claiming malformed input or provider permission.</summary>
    internal procedure AddUnverifiedOperation(var Argument: Record "Message Argument ori"; ParameterName: Text; Capability: Text)
    begin
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, ProviderUnverifiedErr, ParameterName, Capability, MetadataExpectedLbl, ProviderNextStepLbl);
    end;

    local procedure MaxListPages(): Integer
    begin
        exit(1000);
    end;
}
