namespace Origo.Bifrost.Attachments.Test;

using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Attachments;
using System.ExternalFileStorage;
using System.Security.AccessControl;

/// <summary>Issue 124: account read is a direct user grant, and a missing connector table does not block resolution.</summary>
codeunit 96236 "Storage 124 Addr Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    /// <summary>Without read on 4560 or 4570, address resolution returns only PermissionDenied.</summary>
    [Test]
    procedure NoReadOnAccountTable_ReturnsPermissionDenied()
    begin
        // Story #124 | Time: none | Risk: a missing account grant must be a single PermissionDenied.
        AssertNoAccountRead(4560);
        AssertNoAccountRead(4570);
    end;

    /// <summary>Read granted on 4560 or 4570 through the user's own permission set resolves the address.</summary>
    [Test]
    procedure GrantedReadViaOwnPermissionSet_Resolves()
    begin
        // Story #124 | Time: none | Risk: direct read must come from the user's permission set, not a connector dependency.
        AssertGrantedAccountRead(4560, true);
        AssertGrantedAccountRead(4570, false);
    end;

    /// <summary>A tenant without table 4560 or 4570 still resolves the address and collects no error.</summary>
    [Test]
    procedure AbsentAccountTable_DoesNotBlock()
    begin
        // Story #124 | Time: none | Risk: storage setup must not fail when the connector app is not installed.
        AssertAbsentConnector(4560);
        AssertAbsentConnector(4570);
    end;

    local procedure AssertNoAccountRead(TableId: Integer)
    var
        StorageSetup: Record "Storage Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Customer: Record Customer;
        Provider: Codeunit "Storage Ext File Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
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
        if not PrepareConnector(TableId, StorageSetup, AccountId, HostName, RootName, StorageCode) then
            exit;
        Commit();

        // [WHEN] The actor has no read on the account table.
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

        // [THEN] The only refusal is PermissionDenied.
        LibraryAssert.IsFalse(Resolved, 'A user without account read must not resolve the address. ' + FailureText);
        AssertSingleErrorCode(TempArgument, 'PermissionDenied', FailureText);
    end;

    local procedure AssertGrantedAccountRead(TableId: Integer; ExpectedCaseSensitive: Boolean)
    var
        StorageSetup: Record "Storage Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Customer: Record Customer;
        Provider: Codeunit "Storage Ext File Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
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
        if not PrepareConnector(TableId, StorageSetup, AccountId, HostName, RootName, StorageCode) then
            exit;
        // The restrictive mock replaces user assignments, so the same role is added again for the act.
        GrantAccountRead(TableId);
        Commit();

        // [WHEN] The actor's own permission set grants read on this table number.
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('Storage124 Read ori');
        LowerPermissions.AddPermissionSet(AccountRoleId(TableId));
        LibraryAssert.IsTrue(LowerPermissions.HasChangedPermissions(), 'Permission enforcement must be active.');
        LibraryAssert.IsFalse(Customer.WritePermission(), 'The actor must not be SUPER.');
        LibraryAssert.IsTrue(TryDirectAccountRead(TableId), 'The user permission set must grant direct read on table ' + Format(TableId, 0, 9) + '.');
        if not TryResolveAddress(Provider, TempArgument, StorageSetup, Scope, Address, CaseSensitive, Resolved) then
            FailureText := GetLastErrorText()
        else
            if not Resolved then
                FailureText := CollectedErrors(TempArgument);
        LowerPermissions.StopLoggingNAVPermissions();
        DeleteOwnedRows(TableId, StorageCode);
        RevokeAccountRead(TableId);

        // [THEN] The address and scope come from the row this test inserted.
        LibraryAssert.IsTrue(Resolved, 'Direct read must resolve the account address. ' + FailureText);
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

    local procedure PrepareConnector(TableId: Integer; var StorageSetup: Record "Storage Setup ori"; var AccountId: Guid; var HostName: Text; var RootName: Text; var StorageCode: Code[20]): Boolean
    var
        Provider: Codeunit "Storage Ext File Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Not applicable when this tenant does not have the connector table.
        LowerPermissions.StopLoggingNAVPermissions();
        RevokeAccountRead(TableId);
        if Provider.AccountTableIsAbsent(TableId) then begin
            LowerPermissions.StartLoggingNAVPermissions();
            LowerPermissions.SetExactPermissionSet('Storage124 Read ori');
            LibraryAssert.IsTrue(LowerPermissions.HasChangedPermissions(), 'Permission enforcement must be active.');
            exit(false);
        end;

        StorageCode := NewCode();
        AccountId := CreateGuid();
        HostName := NewAzureName();
        RootName := NewAzureName();
        DeleteOwnedRows(TableId, StorageCode);
        InsertAccount(TableId, AccountId, HostName, RootName);
        InsertSetup(StorageSetup, StorageCode, TableId, AccountId);
        exit(true);
    end;

    local procedure GrantAccountRead(TableId: Integer)
    var
        TenantPermissionSet: Record "Tenant Permission Set";
        TenantPermission: Record "Tenant Permission";
        AccessControl: Record "Access Control";
        NullGuid: Guid;
        RoleId: Code[20];
    begin
        RoleId := AccountRoleId(TableId);
        RevokeAccountRead(TableId);

        TenantPermissionSet.Init();
        TenantPermissionSet."App ID" := NullGuid;
        TenantPermissionSet."Role ID" := RoleId;
        TenantPermissionSet.Name := CopyStr('X124 read ' + Format(TableId, 0, 9), 1, MaxStrLen(TenantPermissionSet.Name));
        TenantPermissionSet.Assignable := true;
        TenantPermissionSet.Insert(true);

        TenantPermission.Init();
        TenantPermission."App ID" := NullGuid;
        TenantPermission."Role ID" := RoleId;
        TenantPermission."Object Type" := TenantPermission."Object Type"::"Table Data";
        TenantPermission."Object ID" := TableId;
        TenantPermission.Type := TenantPermission.Type::Include;
        TenantPermission."Read Permission" := TenantPermission."Read Permission"::Yes;
        TenantPermission."Insert Permission" := TenantPermission."Insert Permission"::" ";
        TenantPermission."Modify Permission" := TenantPermission."Modify Permission"::" ";
        TenantPermission."Delete Permission" := TenantPermission."Delete Permission"::" ";
        TenantPermission."Execute Permission" := TenantPermission."Execute Permission"::" ";
        TenantPermission.Insert(true);

        AccessControl.Init();
        AccessControl."User Security ID" := UserSecurityId();
        AccessControl."Role ID" := RoleId;
        AccessControl."Company Name" := CopyStr(CompanyName(), 1, MaxStrLen(AccessControl."Company Name"));
        AccessControl.Scope := AccessControl.Scope::Tenant;
        AccessControl."App ID" := NullGuid;
        AccessControl.Insert(true);

        // Permissions Mock resolves roles from the legacy permission-set table. The read itself is the tenant row above.
        EnsureLegacyRoleVisible(RoleId, TenantPermissionSet.Name);
    end;

    local procedure RevokeAccountRead(TableId: Integer)
    var
        TenantPermissionSet: Record "Tenant Permission Set";
        TenantPermission: Record "Tenant Permission";
        AccessControl: Record "Access Control";
        NullGuid: Guid;
        RoleId: Code[20];
    begin
        RoleId := AccountRoleId(TableId);
        AccessControl.SetRange("User Security ID", UserSecurityId());
        AccessControl.SetRange("Role ID", RoleId);
        AccessControl.SetRange(Scope, AccessControl.Scope::Tenant);
        AccessControl.SetRange("App ID", NullGuid);
        if not AccessControl.IsEmpty() then
            AccessControl.DeleteAll(true);

        TenantPermission.SetRange("App ID", NullGuid);
        TenantPermission.SetRange("Role ID", RoleId);
        if not TenantPermission.IsEmpty() then
            TenantPermission.DeleteAll(true);

        if TenantPermissionSet.Get(NullGuid, RoleId) then
            TenantPermissionSet.Delete(true);
        DeleteLegacyRole(RoleId);
    end;

    local procedure EnsureLegacyRoleVisible(RoleId: Code[20]; RoleName: Text[30])
    var
        PermissionSet: RecordRef;
        RoleField: FieldRef;
    begin
        // Table 2000000004 "Permission Set". A tenant role is not listed there until this row exists.
        PermissionSet.Open(2000000004);
        RoleField := PermissionSet.Field(1);
        RoleField.SetRange(RoleId);
        if PermissionSet.FindFirst() then begin
            PermissionSet.Close();
            exit;
        end;
        PermissionSet.Init();
        PermissionSet.Field(1).Value := RoleId;
        PermissionSet.Field(2).Value := RoleName;
        PermissionSet.Insert(false);
        PermissionSet.Close();
    end;

    local procedure DeleteLegacyRole(RoleId: Code[20])
    var
        PermissionSet: RecordRef;
        RoleField: FieldRef;
    begin
        PermissionSet.Open(2000000004);
        RoleField := PermissionSet.Field(1);
        RoleField.SetRange(RoleId);
        if PermissionSet.FindFirst() then
            PermissionSet.Delete(false);
        PermissionSet.Close();
    end;

    local procedure AccountRoleId(TableId: Integer): Code[20]
    begin
        exit(CopyStr('X124-' + Format(TableId, 0, 9), 1, 20));
    end;

    local procedure AssertSingleErrorCode(var TempArgument: Record "Message Argument ori" temporary; ExpectedCode: Text; FailureText: Text)
    var
        Errors: JsonArray;
        ErrorToken: JsonToken;
    begin
        Errors := TempArgument.GetCollectedErrorsJson();
        LibraryAssert.AreEqual(1, Errors.Count(), 'The refusal must be the only error. ' + FailureText);
        Errors.Get(0, ErrorToken);
        LibraryAssert.AreEqual(ExpectedCode, JsonText(ErrorToken.AsObject(), 'code'), 'The refusal code must be ' + ExpectedCode + '.');
    end;

    local procedure JsonText(ValueObject: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(ValueObject.Get(PropertyName, Token), 'Expected error property: ' + PropertyName);
        exit(Token.AsValue().AsText());
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
