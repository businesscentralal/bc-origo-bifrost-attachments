namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.Reflection;
using System.TestLibraries.Utilities;
using System.Upgrade;

/// <summary>
/// Permission-probe and upgrade retry regression coverage (attachments#8 and #76).
/// Forced denials verify control flow only, not genuinely restricted install/upgrade identities.
/// Uses the install probe seam (<c>Storage Takeover State ori</c> probe denial) which matches
/// the production <c>OnInstallAppPerCompany</c> path — same pattern as Foundation core#43.
/// </summary>
codeunit 96210 "Storage Takeover Probe Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AC01_ProbeDenied_SkipsTakeOverWithoutError()
    var
        Takeover: Codeunit "Storage Takeover ori";
        TakeoverState: Codeunit "Storage Takeover State ori";
        Succeeded: Boolean;
        DeniedTableId: Integer;
        CapturedDenied: Integer;
        CapturedError: Text;
    begin
        // [SCENARIO] AC01: legacy table present but read denied → skip, no error, telemetry names the table
        Initialize();
        DeniedTableId := 10075985;
        TakeoverState.SetProbeDenial(DeniedTableId);

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsFalse(Succeeded, 'Take-over must report skipped when the install probe denies a table.');
        Assert.IsTrue(
            TakeoverState.TryGetLastSkip(CapturedDenied, CapturedError),
            'Skip telemetry capture must record the denial.');
        Assert.AreEqual(DeniedTableId, CapturedDenied, 'Denied table id must be the probed legacy table.');
        Assert.IsTrue(
            CapturedError.Contains('Read denied'),
            'Skip error text must report Read denied for a legacy source table.');
    end;

    [Test]
    procedure AC01b_AccessControlWriteDenied_SkipsWithoutError()
    var
        Takeover: Codeunit "Storage Takeover ori";
        TakeoverState: Codeunit "Storage Takeover State ori";
        Succeeded: Boolean;
        DeniedTableId: Integer;
        CapturedDenied: Integer;
        CapturedError: Text;
    begin
        // [SCENARIO] AC01 variant: Access Control write denied → skip, Write denied in telemetry
        Initialize();
        DeniedTableId := 2000000053; // Access Control
        TakeoverState.SetProbeDenial(DeniedTableId);

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsFalse(Succeeded, 'Take-over must report skipped when Access Control write is denied.');
        Assert.IsTrue(TakeoverState.TryGetLastSkip(CapturedDenied, CapturedError), 'Skip must be recorded.');
        Assert.AreEqual(DeniedTableId, CapturedDenied, 'Denied table id must be Access Control.');
        Assert.IsTrue(CapturedError.Contains('Write denied'), 'Error text must report Write denied.');
    end;

    [Test]
    procedure AC02_ProbeOk_RunsTakeOverWithoutError()
    var
        Takeover: Codeunit "Storage Takeover ori";
        Succeeded: Boolean;
        DeniedTableId: Integer;
    begin
        // [SCENARIO] AC02: probe passes (legacy absent or readable) → TryRunTakeOverAtInstall succeeds
        Initialize();

        Assert.IsTrue(
            Takeover.TryProbeTakeOverPermissions(DeniedTableId),
            'Probe must pass when no denial is forced and legacy tables are absent or readable.');
        Assert.AreEqual(0, DeniedTableId, 'DeniedTableId must stay 0 when the probe passes.');

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsTrue(Succeeded, 'Install take-over must succeed when the probe passes.');
    end;

    [Test]
    procedure AC03_LegacyAbsent_NoOpWithoutError()
    var
        TableMetadata: Record "Table Metadata";
        Takeover: Codeunit "Storage Takeover ori";
        Succeeded: Boolean;
    begin
        // [SCENARIO] AC03: legacy CE Storage tables absent → take-over is a no-op, no error
        Initialize();
        Assert.IsFalse(
            TableMetadata.Get(10075985),
            'W1 unit host must not have CE Storage Attachment Link (10075985).');
        Assert.IsFalse(
            TableMetadata.Get(10075986),
            'W1 unit host must not have Cloud Events Storage Setup (10075986).');

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsTrue(Succeeded, 'Absent legacy tables must no-op successfully (probe passes, copy exits early).');
    end;

    /// <summary>Every tagged upgrade must still probe and log a denied legacy read.</summary>
    [Test]
    procedure Scenario_AC01_TaggedUpgradeDenied_RetriesWithoutChangingTargets()
    var
        StorageUpgrade: Codeunit "Storage Link Upgrade ori";
        TakeoverState: Codeunit "Storage Takeover State ori";
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        LinkId: Guid;
        SetupCount: Integer;
        LinkCount: Integer;
        DeniedTableId: Integer;
        ErrorText: Text;
    begin
        // [GIVEN] A previous install already registered the purge tag and populated destinations.
        Initialize();
        EnsureOrphanPurgeTag();
        SeedDestinationSentinels(LinkId);
        SetupCount := StorageSetup.Count();
        LinkCount := Link.Count();
        TakeoverState.SetProbeDenial(10075985);

        // [WHEN] The company upgrade runs twice with the same denied legacy grant.
        StorageUpgrade.RunCompanyUpgrade();
        Assert.IsTrue(TakeoverState.TryGetLastSkip(DeniedTableId, ErrorText), 'First upgrade must report the denied probe.');
        Assert.AreEqual(10075985, DeniedTableId, 'Telemetry must name the denied legacy table.');
        TakeoverState.ClearLastSkip();
        StorageUpgrade.RunCompanyUpgrade();

        // [THEN] No completion marker suppresses a later probe, and destination values remain intact.
        Assert.IsTrue(TakeoverState.TryGetLastSkip(DeniedTableId, ErrorText), 'Second upgrade must retry despite the purge tag.');
        Assert.AreEqual(10075985, DeniedTableId, 'The repeated denial must name the same table.');
        Assert.IsTrue(ErrorText.Contains('Read denied'), 'The skip must explain the legacy read denial.');
        Assert.AreEqual(SetupCount, StorageSetup.Count(), 'Denied retries must not add or remove setup rows.');
        Assert.AreEqual(LinkCount, Link.Count(), 'Denied tagged retries must not add or remove link rows.');
        AssertDestinationSentinels(LinkId);
        DeleteDestinationSentinels(LinkId);
        TakeoverState.ClearProbeDenial();
    end;

    /// <summary>A denied install can be followed by an upgrade that grants a missing role only once.</summary>
    [Test]
    procedure Scenario_AC02_DeniedInstallThenPermittedUpgrade_RegrantsOnce()
    var
        Takeover: Codeunit "Storage Takeover ori";
        StorageUpgrade: Codeunit "Storage Link Upgrade ori";
        TakeoverState: Codeunit "Storage Takeover State ori";
        LegacyCount: Integer;
    begin
        // [GIVEN] No legacy data tables, one legacy role and an install denied Access Control writes.
        Initialize();
        AssertLegacyTablesAbsent();
        EnsureOrphanPurgeTag();
        SeedLegacyRole();
        LegacyCount := CountFixtureRole('CE Storage', LegacyAppId());
        Assert.AreEqual(1, LegacyCount, 'The legacy role fixture must exist before the probe.');
        Assert.AreEqual(0, CountFixtureRole('BIFROST Attach ori', AttachmentsAppId()), 'No target role may pre-exist.');
        TakeoverState.SetProbeDenial(2000000053);
        Assert.IsFalse(Takeover.TryRunTakeOverAtInstall(), 'Denied install must skip.');
        Assert.AreEqual(0, CountFixtureRole('BIFROST Attach ori', AttachmentsAppId()), 'Denied install must not grant a role.');
        Assert.AreEqual(LegacyCount, CountFixtureRole('CE Storage', LegacyAppId()), 'Denied install must preserve the legacy role.');

        // [WHEN] The forced denial is cleared for a later upgrade and the following upgrade.
        TakeoverState.ClearProbeDenial();
        TakeoverState.ClearLastSkip();
        StorageUpgrade.RunCompanyUpgrade();
        Assert.AreEqual(1, CountFixtureRole('BIFROST Attach ori', AttachmentsAppId()), 'Permitted upgrade must grant the role despite the purge tag.');
        StorageUpgrade.RunCompanyUpgrade();

        // [THEN] Exactly one target grant exists and the source assignment was never removed.
        Assert.AreEqual(1, CountFixtureRole('BIFROST Attach ori', AttachmentsAppId()), 'Second upgrade must not duplicate the grant.');
        Assert.AreEqual(LegacyCount, CountFixtureRole('CE Storage', LegacyAppId()), 'Retries must preserve the legacy role.');
        DeleteFixtureRoles();
    end;

    /// <summary>With legacy tables absent, repeated upgrades preserve populated destination data.</summary>
    [Test]
    procedure Scenario_AC03_LegacyAbsent_RepeatedUpgradePreservesTargets()
    var
        StorageUpgrade: Codeunit "Storage Link Upgrade ori";
        TakeoverState: Codeunit "Storage Takeover State ori";
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        LinkId: Guid;
        SetupCount: Integer;
        LinkCount: Integer;
        DeniedTableId: Integer;
        ErrorText: Text;
    begin
        // [GIVEN] Explicitly absent legacy tables, a completed purge and populated destination tables.
        Initialize();
        AssertLegacyTablesAbsent();
        EnsureOrphanPurgeTag();
        SeedDestinationSentinels(LinkId);
        SetupCount := StorageSetup.Count();
        LinkCount := Link.Count();

        // [WHEN] Both the first and a repeat upgrade execute.
        StorageUpgrade.RunCompanyUpgrade();
        StorageUpgrade.RunCompanyUpgrade();

        // [THEN] The no-op adds no data, does not overwrite values and logs no permission skip.
        Assert.AreEqual(SetupCount, StorageSetup.Count(), 'No legacy setup may be invented.');
        Assert.AreEqual(LinkCount, Link.Count(), 'No legacy links may be invented.');
        AssertDestinationSentinels(LinkId);
        Assert.IsFalse(TakeoverState.TryGetLastSkip(DeniedTableId, ErrorText), 'Absent legacy tables must not produce a denial.');
        DeleteDestinationSentinels(LinkId);
    end;

    local procedure EnsureOrphanPurgeTag()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag('Origo.Bifrost.Attachments-PurgeOrphanLinks-20260928') then
            UpgradeTag.SetUpgradeTag('Origo.Bifrost.Attachments-PurgeOrphanLinks-20260928');
    end;

    local procedure AssertLegacyTablesAbsent()
    var
        TableMetadata: Record "Table Metadata";
    begin
        Assert.IsFalse(TableMetadata.Get(10075985), 'Unit fixture requires legacy links absent; present-table evidence uses a separate lifecycle host.');
        Assert.IsFalse(TableMetadata.Get(10075986), 'Unit fixture requires legacy setup absent; never silently skip this test.');
    end;

    local procedure SeedDestinationSentinels(var LinkId: Guid)
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
    begin
        StorageSetup.Init();
        StorageSetup.Code := 'XRETRY76';
        StorageSetup.Description := 'Xexisting setup';
        StorageSetup.Insert();
        LinkId := CreateGuid();
        Link.Init();
        Link."Table ID" := Database::"Storage Setup ori";
        Link."Record System Id" := LinkId;
        Link."File Name" := 'Xexisting.txt';
        Link."Storage Code" := StorageSetup.Code;
        Link.Insert();
    end;

    local procedure AssertDestinationSentinels(LinkId: Guid)
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
    begin
        StorageSetup.SetLoadFields(Description);
        StorageSetup.Get('XRETRY76');
        Assert.AreEqual('Xexisting setup', StorageSetup.Description, 'Existing setup must not be overwritten.');
        Link.SetLoadFields("File Name", "Storage Code");
        Link.Get(Database::"Storage Setup ori", LinkId);
        Assert.AreEqual('Xexisting.txt', Link."File Name", 'Existing link must not be overwritten.');
        Assert.AreEqual(StorageSetup.Code, Link."Storage Code", 'Existing link storage code must not change.');
    end;

    local procedure DeleteDestinationSentinels(LinkId: Guid)
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
    begin
        StorageSetup.Get('XRETRY76');
        StorageSetup.Delete();
        Link.Get(Database::"Storage Setup ori", LinkId);
        Link.Delete();
    end;

    local procedure SeedLegacyRole()
    var
        AccessControl: RecordRef;
    begin
        DeleteFixtureRoles();
        AccessControl.Open(2000000053);
        AccessControl.Init();
        AccessControl.Field(1).Value := UserSecurityId();
        AccessControl.Field(2).Value := 'CE Storage';
        AccessControl.Field(3).Value := 'XRETRY76';
        AccessControl.Field(8).Value := 0;
        AccessControl.Field(9).Value := LegacyAppId();
        AccessControl.Insert(false);
        AccessControl.Close();
    end;

    local procedure CountFixtureRole(RoleId: Code[20]; ApplicationId: Guid): Integer
    var
        AccessControl: RecordRef;
        RowCount: Integer;
    begin
        OpenFixtureRole(AccessControl, RoleId, ApplicationId);
        RowCount := AccessControl.Count();
        AccessControl.Close();
        exit(RowCount);
    end;

    local procedure OpenFixtureRole(var AccessControl: RecordRef; RoleId: Code[20]; ApplicationId: Guid)
    begin
        AccessControl.Open(2000000053);
        AccessControl.Field(1).SetRange(UserSecurityId());
        AccessControl.Field(2).SetRange(RoleId);
        AccessControl.Field(3).SetRange('XRETRY76');
        AccessControl.Field(8).SetRange(0);
        AccessControl.Field(9).SetRange(ApplicationId);
    end;

    local procedure DeleteFixtureRoles()
    var
        AccessControl: RecordRef;
    begin
        OpenFixtureRole(AccessControl, 'CE Storage', LegacyAppId());
        AccessControl.DeleteAll(false);
        AccessControl.Close();
        OpenFixtureRole(AccessControl, 'BIFROST Attach ori', AttachmentsAppId());
        AccessControl.DeleteAll(false);
        AccessControl.Close();
    end;

    local procedure LegacyAppId(): Guid
    begin
        exit('7acf9361-f558-442b-a516-f5e5dd92aecb');
    end;

    local procedure AttachmentsAppId(): Guid
    begin
        exit('672df32a-a0c5-4a22-b591-0efa38023e95');
    end;

    local procedure Initialize()
    var
        TakeoverState: Codeunit "Storage Takeover State ori";
    begin
        TakeoverState.ClearProbeDenial();
        TakeoverState.ClearLastSkip();
    end;
}
