namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for <c>Storage Takeover ori</c> Access Control re-grant
/// (<c>CE Storage</c> → <c>BIFROST Attach ori</c>).
/// <para>
/// Seeds and asserts against system table 2000000053 via <c>RecordRef</c> so the test app
/// compiles under CI compiler-folder (AL0185) without granting <c>tabledata "Access Control"</c>
/// on any user-assignable permission set — same pattern as Foundation PR #22.
/// </para>
/// </summary>
codeunit 96209 "Storage Takeover Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        CompanySentinelTok: Label 'XTEST-TAKEOVER-AC', Locked = true;
        LegacyRoleIdTok: Label 'CE Storage', Locked = true;
        BifrostRoleIdTok: Label 'BIFROST Attach ori', Locked = true;

    [Test]
    procedure TakeOverAccessControl_LegacyRow_InsertsMatchingBifrostRole()
    var
        AccessControl: RecordRef;
        Takeover: Codeunit "Storage Takeover ori";
        UserId: Guid;
        Company: Text[30];
        Granted: Integer;
        AttachmentsAppId: Guid;
        LegacyAppId: Guid;
        Found: Boolean;
    begin
        // [SCENARIO] TC001: A seeded legacy CE Storage Access Control row is copied to
        // BIFROST Attach ori for the same user, company and scope
        InitializeAccessControlFixture(UserId, Company, LegacyAppId, AttachmentsAppId);

        // [GIVEN] A legacy CE Storage assignment
        SeedLegacyAccessControl(UserId, LegacyRoleIdTok, Company, LegacyAppId);

        // [WHEN] TakeOverAccessControl runs
        Granted := Takeover.TakeOverAccessControl();

        // [THEN] One BIFROST row was granted for the same user, company and scope
        Assert.AreEqual(1, Granted, 'One BIFROST Access Control row must be granted.');
        AccessControl.Open(2000000053);
        AccessControl.Field(1).Value := UserId;
        AccessControl.Field(2).Value := BifrostRoleIdTok;
        AccessControl.Field(3).Value := Company;
        AccessControl.Field(8).Value := 0; // Scope::System
        AccessControl.Field(9).Value := AttachmentsAppId;
        Found := AccessControl.Find('=');
        AccessControl.Close();
        Assert.IsTrue(
            Found,
            'The matching BIFROST Access Control row must exist for the same user, company and scope.');

        CleanupAccessControlFixture(UserId, Company, LegacyAppId, AttachmentsAppId);
    end;

    [Test]
    procedure TakeOverAccessControl_ExistingBifrostRow_DoesNotDuplicate()
    var
        AccessControl: RecordRef;
        Takeover: Codeunit "Storage Takeover ori";
        UserId: Guid;
        Company: Text[30];
        FirstRun: Integer;
        SecondRun: Integer;
        AttachmentsAppId: Guid;
        LegacyAppId: Guid;
        BifrostCount: Integer;
    begin
        // [SCENARIO] TC002: Re-running take-over with the BIFROST row already present inserts nothing
        InitializeAccessControlFixture(UserId, Company, LegacyAppId, AttachmentsAppId);

        // [GIVEN] A legacy CE assignment and a first TakeOverAccessControl that created the BIFROST row
        SeedLegacyAccessControl(UserId, LegacyRoleIdTok, Company, LegacyAppId);
        FirstRun := Takeover.TakeOverAccessControl();
        Assert.AreEqual(1, FirstRun, 'The first run must grant the BIFROST row.');

        // [WHEN] TakeOverAccessControl runs again with the BIFROST row already present
        SecondRun := Takeover.TakeOverAccessControl();

        // [THEN] Nothing further is inserted and the BIFROST row was not duplicated
        Assert.AreEqual(0, SecondRun, 'A re-run with the BIFROST row present must insert nothing.');
        AccessControl.Open(2000000053);
        AccessControl.Field(1).SetRange(UserId);
        AccessControl.Field(2).SetRange(BifrostRoleIdTok);
        AccessControl.Field(3).SetRange(Company);
        AccessControl.Field(8).SetRange(0); // Scope::System
        AccessControl.Field(9).SetRange(AttachmentsAppId);
        BifrostCount := AccessControl.Count();
        AccessControl.Close();
        Assert.AreEqual(1, BifrostCount, 'The BIFROST Access Control row must not be duplicated.');

        CleanupAccessControlFixture(UserId, Company, LegacyAppId, AttachmentsAppId);
    end;

    [Test]
    procedure TakeOverAccessControl_NoLegacyRows_GrantsZeroWithoutError()
    var
        Takeover: Codeunit "Storage Takeover ori";
        UserId: Guid;
        Company: Text[30];
        Granted: Integer;
        AttachmentsAppId: Guid;
        LegacyAppId: Guid;
    begin
        // [SCENARIO] TC003: With no legacy Access Control rows, TakeOverAccessControl grants zero and does not error
        InitializeAccessControlFixture(UserId, Company, LegacyAppId, AttachmentsAppId);

        // [GIVEN] No legacy CE Storage Access Control rows (cleanup removed any leftovers)

        // [WHEN] TakeOverAccessControl runs
        Granted := Takeover.TakeOverAccessControl();

        // [THEN] Granted is zero and the call did not raise
        Assert.AreEqual(0, Granted, 'With no legacy rows, Granted must be 0.');

        CleanupAccessControlFixture(UserId, Company, LegacyAppId, AttachmentsAppId);
    end;

    local procedure InitializeAccessControlFixture(var UserId: Guid; var Company: Text[30]; var LegacyAppId: Guid; var AttachmentsAppId: Guid)
    begin
        // Real user so Access Control.Insert(true) in TakeOverAccessControl can validate the assignee;
        // a unique company sentinel keeps cleanup from touching a real assignment.
        UserId := UserSecurityId();
        Company := CopyStr(CompanySentinelTok, 1, MaxStrLen(Company));
        LegacyAppId := '7acf9361-f558-442b-a516-f5e5dd92aecb'; // Origo Cloud Events Storage
        AttachmentsAppId := '672df32a-a0c5-4a22-b591-0efa38023e95'; // Bifrost Attachments
        CleanupAccessControlFixture(UserId, Company, LegacyAppId, AttachmentsAppId);
    end;

    local procedure SeedLegacyAccessControl(UserId: Guid; RoleId: Code[20]; Company: Text[30]; LegacyAppId: Guid)
    var
        AccessControl: RecordRef;
    begin
        // Table 2000000053 Access Control via RecordRef to avoid AL0185 on CI compiler-folder
        AccessControl.Open(2000000053);
        AccessControl.Init();
        AccessControl.Field(1).Value := UserId; // User Security ID
        AccessControl.Field(2).Value := RoleId; // Role ID
        AccessControl.Field(3).Value := Company; // Company Name
        AccessControl.Field(8).Value := 0; // Scope::System
        AccessControl.Field(9).Value := LegacyAppId; // App ID
        AccessControl.Insert(false);
        AccessControl.Close();
    end;

    local procedure CleanupAccessControlFixture(UserId: Guid; Company: Text[30]; LegacyAppId: Guid; AttachmentsAppId: Guid)
    var
        AccessControl: RecordRef;
    begin
        AccessControl.Open(2000000053);
        AccessControl.Field(1).Value := UserId;
        AccessControl.Field(2).Value := LegacyRoleIdTok;
        AccessControl.Field(3).Value := Company;
        AccessControl.Field(8).Value := 0; // Scope::System
        AccessControl.Field(9).Value := LegacyAppId;
        if AccessControl.Find('=') then
            AccessControl.Delete(false);
        AccessControl.Field(1).Value := UserId;
        AccessControl.Field(2).Value := BifrostRoleIdTok;
        AccessControl.Field(3).Value := Company;
        AccessControl.Field(8).Value := 0;
        AccessControl.Field(9).Value := AttachmentsAppId;
        if AccessControl.Find('=') then
            AccessControl.Delete(false);
        AccessControl.Close();
        CleanupAllTestAccessControlRows();
    end;

    /// <summary>
    /// Deletes every Access Control row for the XTEST-TAKEOVER-AC company sentinel (CE + BIFROST).
    /// Uses RecordRef on table 2000000053 so the test app compiles under CI compiler-folder (AL0185).
    /// </summary>
    local procedure CleanupAllTestAccessControlRows()
    var
        AccessControl: RecordRef;
        CompanyField: FieldRef;
        CompanyFilter: Text[30];
    begin
        CompanyFilter := CompanySentinelTok;
        AccessControl.Open(2000000053);
        CompanyField := AccessControl.Field(3); // Company Name
        CompanyField.SetRange(CompanyFilter);
        while AccessControl.FindFirst() do
            AccessControl.Delete(false);
        AccessControl.Close();
    end;
}
