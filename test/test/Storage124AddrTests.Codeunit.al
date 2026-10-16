namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;

/// <summary>Issue 124 AC02: a non-SUPER user can resolve a connector account address, and a missing connector table does not block resolution.</summary>
codeunit 96236 "Storage 124 Addr Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    /// <summary>Blob account 4560 resolves under the restricted set from a row this test inserts.</summary>
    [Test]
    procedure Scenario_AC02_RestrictedUser_ResolvesBlobAddress()
    begin
        // Story #124, AC02 | Time: none | Risk: the account read must work without direct table permission.
        AssertRestrictedResolve(4560, 'c9ce86fe-cb70-4b79-be03-d21856b1a4ca', true);
    end;

    /// <summary>File Share account 4570 resolves under the restricted set from a row this test inserts.</summary>
    [Test]
    procedure Scenario_AC02_RestrictedUser_ResolvesFileShareAddress()
    begin
        // Story #124, AC02 | Time: none | Risk: the account read must work without direct table permission.
        AssertRestrictedResolve(4570, '79447b11-8301-4d02-a546-2261eb811296', false);
    end;

    /// <summary>A tenant without table 4560 or 4570 still resolves the address and collects no error.</summary>
    [Test]
    procedure Scenario_AC02_AbsentAccountTable_DoesNotBlock()
    begin
        // Story #124 | Time: none | Risk: storage setup must not fail when the connector app is not installed.
        AssertAbsentConnector(4560);
        AssertAbsentConnector(4570);
    end;

    local procedure AssertRestrictedResolve(TableId: Integer; ModuleId: Guid; ExpectedCaseSensitive: Boolean)
    var
        StorageSetup: Record "Storage Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Customer: Record Customer;
        Provider: Codeunit "Storage Ext File Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        AccountModule: ModuleInfo;
        AccountId: Guid;
        HostName: Text;
        RootName: Text;
        Scope: Text;
        Address: Text;
        FailureText: Text;
        CaseSensitive: Boolean;
        Resolved: Boolean;
        StorageCode: Code[20];
    begin
        // [GIVEN] A connector account and setup row created from scratch under the runner's own grants.
        LowerPermissions.StopLoggingNAVPermissions();
        if Provider.AccountTableIsAbsent(TableId) then begin
            // The absent-table test owns a tenant that does not have this connector app.
            LowerPermissions.StartLoggingNAVPermissions();
            LowerPermissions.SetExactPermissionSet('Storage124 Read ori');
            LibraryAssert.IsTrue(LowerPermissions.HasChangedPermissions(), 'Permission enforcement must be active.');
            exit;
        end;
        LibraryAssert.IsTrue(NavApp.GetModuleInfo(ModuleId, AccountModule), 'The connector app for table ' + Format(TableId, 0, 9) + ' must be installed.');
        LibraryAssert.IsTrue("Ext. File Storage Connector".Ordinals().Contains(TableId), 'The connector enum must include table ' + Format(TableId, 0, 9) + '.');
        StorageCode := NewCode();
        AccountId := CreateGuid();
        HostName := NewAzureName();
        RootName := NewAzureName();
        DeleteOwnedRows(TableId, StorageCode);
        InsertAccount(TableId, AccountId, HostName, RootName);
        InsertSetup(StorageSetup, StorageCode, TableId, AccountId);
        Commit();

        // [WHEN] A permission set with no account-table read resolves the address.
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('Storage124 Read ori');
        LibraryAssert.IsTrue(LowerPermissions.HasChangedPermissions(), 'Permission enforcement must be active.');
        LibraryAssert.IsFalse(Customer.WritePermission(), 'The actor must not be SUPER.');
        LibraryAssert.IsFalse(TryDirectAccountRead(TableId), 'The actor must lack direct read on table ' + Format(TableId, 0, 9) + '.');
        if not TryResolveAddress(Provider, TempArgument, StorageSetup, Scope, Address, CaseSensitive, Resolved) then
            FailureText := GetLastErrorText()
        else
            if not Resolved then
                FailureText := CollectedErrors(TempArgument);
        LowerPermissions.StopLoggingNAVPermissions();
        DeleteOwnedRows(TableId, StorageCode);

        // [THEN] The physical address and scope come from the row this test inserted.
        LibraryAssert.IsTrue(Resolved, 'The account read must resolve the address the test inserted. ' + FailureText);
        LibraryAssert.IsFalse(TempArgument.HasCollectedErrors(), 'Resolution must not collect an error.');
        LibraryAssert.AreEqual('x124base/dir/file.txt', Address, 'The address must keep the base path and relative path.');
        LibraryAssert.AreEqual(Format(TableId, 0, 9) + ':' + HostName + '/' + RootName, Scope, 'The scope must use the inserted account and root.');
        LibraryAssert.AreEqual(ExpectedCaseSensitive, CaseSensitive, 'Case sensitivity must follow the connector.');
    end;

    local procedure AssertAbsentConnector(TableId: Integer)
    var
        StorageSetup: Record "Storage Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Provider: Codeunit "Storage Ext File Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        AccountId: Guid;
        Scope: Text;
        Address: Text;
        FailureText: Text;
        ExpectedScope: Text;
        StorageCode: Code[20];
        CaseSensitive: Boolean;
        Resolved: Boolean;
        TableAbsent: Boolean;
        MissingTableAbsent: Boolean;
    begin
        // [GIVEN] The runner can see whether the connector table is installed.
        LowerPermissions.StopLoggingNAVPermissions();
        TableAbsent := Provider.AccountTableIsAbsent(TableId);
        MissingTableAbsent := Provider.AccountTableIsAbsent(962360);
        AccountId := CreateGuid();
        StorageCode := NewCode();
        if TableAbsent then begin
            InsertSetupByNumber(StorageCode, TableId, AccountId);
            StorageSetup.Get(StorageCode);
            Commit();
        end;

        // [WHEN] The restricted set resolves an address for a connector whose table is not installed.
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('Storage124 Read ori');
        LibraryAssert.IsTrue(LowerPermissions.HasChangedPermissions(), 'Permission enforcement must be active.');
        if TableAbsent then
            if not TryResolveAddress(Provider, TempArgument, StorageSetup, Scope, Address, CaseSensitive, Resolved) then
                FailureText := GetLastErrorText()
            else
                if not Resolved then
                    FailureText := CollectedErrors(TempArgument);
        LowerPermissions.StopLoggingNAVPermissions();

        // [THEN] Absence is graceful. A tenant that has the connector table still proves a missing id is absent.
        if TableAbsent then begin
            DeleteSetup(StorageCode);
            ExpectedScope := Format(StorageSetup."Storage Type".AsInteger(), 0, 9) + ':' + Format(TableId, 0, 9) + ':' + Format(AccountId, 0, 4);
            LibraryAssert.IsTrue(Resolved, 'A missing connector table must still resolve the address. ' + FailureText);
            LibraryAssert.IsFalse(TempArgument.HasCollectedErrors(), 'A missing connector table must not collect an error.');
            LibraryAssert.AreEqual('x124base/dir/file.txt', Address, 'The address must keep the base path and relative path.');
            LibraryAssert.AreEqual(ExpectedScope, Scope, 'Scope must stay generic when the account table is not present.');
        end else
            LibraryAssert.IsTrue(MissingTableAbsent, 'A table that is not installed must be reported absent.');
    end;

    [TryFunction]
    local procedure TryResolveAddress(var Provider: Codeunit "Storage Ext File Impl ori"; var TempArgument: Record "Message Argument ori" temporary; StorageSetup: Record "Storage Setup ori"; var Scope: Text; var Address: Text; var CaseSensitive: Boolean; var Resolved: Boolean)
    begin
        Resolved := Provider.ResolvePhysicalAddress(TempArgument, StorageSetup, 'dir/file.txt', Scope, Address, CaseSensitive);
    end;

    local procedure CollectedErrors(var TempArgument: Record "Message Argument ori" temporary): Text
    var
        Errors: JsonArray;
        ErrorsText: Text;
    begin
        Errors := TempArgument.GetCollectedErrorsJson();
        Errors.WriteTo(ErrorsText);
        exit(CopyStr(ErrorsText, 1, 500));
    end;

    local procedure InsertSetup(var StorageSetup: Record "Storage Setup ori"; StorageCode: Code[20]; TableId: Integer; AccountId: Guid)
    begin
        StorageSetup.Init();
        StorageSetup.Code := StorageCode;
        StorageSetup."Storage Type" := StorageSetup."Storage Type"::"External File Storage";
        StorageSetup.Connector := "Ext. File Storage Connector".FromInteger(TableId);
        StorageSetup."File Account Id" := AccountId;
        StorageSetup."Base Path" := 'x124base';
        StorageSetup.Enabled := true;
        StorageSetup.Insert(false);
    end;

    local procedure InsertSetupByNumber(StorageCode: Code[20]; TableId: Integer; AccountId: Guid)
    var
        StorageSetup: RecordRef;
    begin
        // Field 4 is the connector enum. The ordinal is stored by number so this compiles without the connector app.
        StorageSetup.Open(Database::"Storage Setup ori");
        StorageSetup.Init();
        StorageSetup.Field(1).Value := StorageCode;
        StorageSetup.Field(3).Value := "Storage Type ori"::"External File Storage".AsInteger();
        StorageSetup.Field(4).Value := TableId;
        StorageSetup.Field(5).Value := AccountId;
        StorageSetup.Field(7).Value := 'x124base';
        StorageSetup.Field(8).Value := true;
        StorageSetup.Insert(false);
        StorageSetup.Close();
    end;

    local procedure InsertAccount(TableId: Integer; AccountId: Guid; HostName: Text; RootName: Text)
    var
        Account: RecordRef;
    begin
        Account.Open(TableId);
        Account.Init();
        Account.Field(1).Value := AccountId;
        Account.Field(2).Value := CopyStr('X124 ' + HostName, 1, 250);
        Account.Field(3).Value := HostName;
        Account.Field(4).Value := RootName;
        Account.Insert(false);
        Account.Close();
    end;

    local procedure DeleteOwnedRows(TableId: Integer; StorageCode: Code[20])
    var
        Account: RecordRef;
    begin
        DeleteSetup(StorageCode);
        Account.Open(TableId);
        Account.Field(2).SetFilter('X124 *');
        Account.DeleteAll(false);
        Account.Close();
    end;

    local procedure DeleteSetup(StorageCode: Code[20])
    var
        StorageSetup: Record "Storage Setup ori";
    begin
        if StorageSetup.Get(StorageCode) then
            StorageSetup.Delete(false);
    end;

    [TryFunction]
    local procedure TryDirectAccountRead(TableId: Integer)
    var
        Account: RecordRef;
    begin
        Account.Open(TableId);
        if not Account.ReadPermission() then
            Error('The account table is not directly readable.');
    end;

    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr('X124' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
    end;

    local procedure NewAzureName(): Text
    begin
        exit('x124' + LowerCase(CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 12)));
    end;
}
