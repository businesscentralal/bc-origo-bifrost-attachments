namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;

/// <summary>Issue 124 AC02: a non-SUPER user can resolve a connector account address the test creates.</summary>
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
        // Story #124, AC02 | Time: none | Risk: RecordRef.ReadPermission ignores indirect read.
        AssertRestrictedResolve(4560, 'c9ce86fe-cb70-4b79-be03-d21856b1a4ca', true);
    end;

    /// <summary>File Share account 4570 resolves under the restricted set from a row this test inserts.</summary>
    [Test]
    procedure Scenario_AC02_RestrictedUser_ResolvesFileShareAddress()
    begin
        // Story #124, AC02 | Time: none | Risk: RecordRef.ReadPermission ignores indirect read.
        AssertRestrictedResolve(4570, '79447b11-8301-4d02-a546-2261eb811296', false);
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
        LibraryAssert.IsTrue(Resolved, 'Indirect read must resolve the account address. ' + FailureText);
        LibraryAssert.IsFalse(TempArgument.HasCollectedErrors(), 'Resolution must not collect an error.');
        LibraryAssert.AreEqual('x124base/dir/file.txt', Address, 'The address must keep the base path and relative path.');
        LibraryAssert.AreEqual(Format(TableId, 0, 9) + ':' + HostName + '/' + RootName, Scope, 'The scope must use the inserted account and root.');
        LibraryAssert.AreEqual(ExpectedCaseSensitive, CaseSensitive, 'Case sensitivity must follow the connector.');
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
        StorageSetup: Record "Storage Setup ori";
        Account: RecordRef;
    begin
        if StorageSetup.Get(StorageCode) then
            StorageSetup.Delete(false);
        Account.Open(TableId);
        Account.Field(2).SetFilter('X124 *');
        Account.DeleteAll(false);
        Account.Close();
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
