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
    RequiredTestIsolation = Function;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>A forced legacy read denial records a skip without raising.</summary>
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
        // Story #8, AC01 | Time: independent of Today/WorkDate | Risk: synthetic probe only.
        // [SCENARIO] A forced legacy read denial skips takeover and identifies the table.
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

    /// <summary>A forced Access Control write denial records the denied operation.</summary>
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
        // Story #8, AC01 | Time: independent of Today/WorkDate | Risk: synthetic probe only.
        // [SCENARIO] Access Control write denied → skip, Write denied in telemetry
        Initialize();
        DeniedTableId := 2000000053; // Access Control
        TakeoverState.SetProbeDenial(DeniedTableId);

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsFalse(Succeeded, 'Take-over must report skipped when Access Control write is denied.');
        Assert.IsTrue(TakeoverState.TryGetLastSkip(CapturedDenied, CapturedError), 'Skip must be recorded.');
        Assert.AreEqual(DeniedTableId, CapturedDenied, 'Denied table id must be Access Control.');
        Assert.IsTrue(CapturedError.Contains('Write denied'), 'Error text must report Write denied.');
    end;

    /// <summary>With no legacy tables or roles, a permitted probe completes without transfer.</summary>
    [Test]
    procedure AC02_ProbeOk_RunsTakeOverWithoutError()
    var
        Takeover: Codeunit "Storage Takeover ori";
        Succeeded: Boolean;
        DeniedTableId: Integer;
    begin
        // Story #8, AC02 | Time: independent of Today/WorkDate | Risk: absent legacy unit fixture.
        // [SCENARIO] A permitted probe completes; real DataTransfer needs lifecycle scope.
        Initialize();
        AssertLegacyTablesAbsent();
        AssertNoLegacyRoles();

        Assert.IsTrue(
            Takeover.TryProbeTakeOverPermissions(DeniedTableId),
            'Probe must pass when no denial is forced and legacy tables and roles are absent.');
        Assert.AreEqual(0, DeniedTableId, 'DeniedTableId must stay 0 when the probe passes.');

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsTrue(Succeeded, 'Install take-over must succeed when the probe passes.');
    end;

    /// <summary>Absent legacy tables and assignments leave both destination tables and roles unchanged.</summary>
    [Test]
    procedure AC03_LegacyAbsent_NoOpWithoutError()
    var
        StorageSetup: Record "Storage Setup ori";
        Link: Record "Storage Attachment Link ori";
        Takeover: Codeunit "Storage Takeover ori";
        SetupCount: Integer;
        LinkCount: Integer;
        RoleCount: Integer;
        Succeeded: Boolean;
    begin
        // Story #8, AC03 | Time: independent of Today/WorkDate | Risk: residual roles are a separate case.
        // [SCENARIO] No legacy data or roles means no rows or grants are created.
        Initialize();
        AssertLegacyTablesAbsent();
        AssertNoLegacyRoles();
        SetupCount := StorageSetup.Count();
        LinkCount := Link.Count();
        RoleCount := CountTargetRoles();

        Succeeded := Takeover.TryRunTakeOverAtInstall();

        Assert.IsTrue(Succeeded, 'Absent legacy tables must no-op successfully (probe passes, copy exits early).');
        Assert.AreEqual(SetupCount, StorageSetup.Count(), 'No-op must preserve setup row count.');
        Assert.AreEqual(LinkCount, Link.Count(), 'No-op must preserve link row count.');
        Assert.AreEqual(RoleCount, CountTargetRoles(), 'No-op must preserve target assignments.');
    end;

    /// <summary>Every tagged upgrade must still probe and log a denied legacy read.</summary>
    [Test]
    procedure Scenario_AC01_TaggedUpgradeDenied_RetriesWithoutChangingTargets()
    var
        Link: Record "Storage Attachment Link ori";
        StorageSetup: Record "Storage Setup ori";
        StorageUpgrade: Codeunit "Storage Link Upgrade ori";
        TakeoverState: Codeunit "Storage Takeover State ori";
        LinkId: Guid;
        SetupCount: Integer;
        LinkCount: Integer;
        DeniedTableId: Integer;
        ErrorText: Text;
    begin
        // Story #76, AC01 | Time: independent of Today/WorkDate | Risk: forced denial is not real identity proof.
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
        // Story #76, AC02 | Time: independent of Today/WorkDate | Risk: absent data tables can still leave roles.
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
        Link: Record "Storage Attachment Link ori";
        StorageSetup: Record "Storage Setup ori";
        StorageUpgrade: Codeunit "Storage Link Upgrade ori";
        TakeoverState: Codeunit "Storage Takeover State ori";
        LinkId: Guid;
        SetupCount: Integer;
        LinkCount: Integer;
        RoleCount: Integer;
        DeniedTableId: Integer;
        ErrorText: Text;
    begin
        // Story #76, AC03 | Time: independent of Today/WorkDate | Risk: requires no residual legacy roles.
        // [GIVEN] Explicitly absent legacy tables, a completed purge and populated destination tables.
        Initialize();
        AssertLegacyTablesAbsent();
        AssertNoLegacyRoles();
        EnsureOrphanPurgeTag();
        SeedDestinationSentinels(LinkId);
        SetupCount := StorageSetup.Count();
        LinkCount := Link.Count();
        RoleCount := CountTargetRoles();

        // [WHEN] Both the first and a repeat upgrade execute.
        StorageUpgrade.RunCompanyUpgrade();
        StorageUpgrade.RunCompanyUpgrade();

        // [THEN] The no-op adds no data, does not overwrite values and logs no permission skip.
        Assert.AreEqual(SetupCount, StorageSetup.Count(), 'No legacy setup may be invented.');
        Assert.AreEqual(LinkCount, Link.Count(), 'No legacy links may be invented.');
        Assert.AreEqual(RoleCount, CountTargetRoles(), 'No legacy role may be invented.');
        AssertDestinationSentinels(LinkId);
        Assert.IsFalse(TakeoverState.TryGetLastSkip(DeniedTableId, ErrorText), 'Absent legacy tables must not produce a denial.');
        DeleteDestinationSentinels(LinkId);
    end;

    /// <summary>An untagged denied upgrade still purges only invalid links and records the purge tag.</summary>
    [Test]
    procedure Scenario_AC01_UntaggedDeniedUpgrade_PurgesAndRecordsTag()
    var
        Link: Record "Storage Attachment Link ori";
        StorageSetup: Record "Storage Setup ori";
        StorageUpgrade: Codeunit "Storage Link Upgrade ori";
        TakeoverState: Codeunit "Storage Takeover State ori";
        UpgradeTag: Codeunit "Upgrade Tag";
        LinkId: Guid;
        OrphanId: Guid;
        LateOrphanId: Guid;
        EmptyGuid: Guid;
        DeniedTableId: Integer;
        ErrorText: Text;
    begin
        // Story #76, AC01/AC03 | Time: independent of Today/WorkDate | Risk: forced skip; scoped tag fixture only.
        // [GIVEN] No purge tag, a valid destination and both established invalid-link shapes.
        Initialize();
        RemoveCompanyOrphanPurgeTag();
        Assert.IsFalse(UpgradeTag.HasUpgradeTag(OrphanPurgeTag()), 'The fixture must exercise the untagged branch.');
        SeedDestinationSentinels(LinkId);
        OrphanId := CreateGuid();
        InsertOrphanLink(0, OrphanId);
        InsertOrphanLink(Database::"Storage Setup ori", EmptyGuid);
        InsertOrphanLink(0, EmptyGuid);
        TakeoverState.SetProbeDenial(10075986);

        // [WHEN] The upgrade cannot read the legacy setup table.
        StorageUpgrade.RunCompanyUpgrade();

        // [THEN] Skip does not suppress the original purge or its tag, and valid data survives.
        Assert.IsTrue(TakeoverState.TryGetLastSkip(DeniedTableId, ErrorText), 'Untagged upgrade must attempt takeover.');
        Assert.AreEqual(10075986, DeniedTableId, 'Skip must name the legacy setup table.');
        Assert.IsTrue(ErrorText.Contains('Read denied'), 'Skip must explain the denied read.');
        Assert.IsTrue(UpgradeTag.HasUpgradeTag(OrphanPurgeTag()), 'Probe skip must not prevent recording the purge tag.');
        Assert.IsFalse(Link.Get(0, OrphanId), 'Table ID zero must be purged.');
        Assert.IsFalse(Link.Get(Database::"Storage Setup ori", EmptyGuid), 'Empty record ID must be purged.');
        Assert.IsFalse(Link.Get(0, EmptyGuid), 'A row matching both invalid conditions must be purged.');
        AssertDestinationSentinels(LinkId);

        // [WHEN] A later tagged upgrade encounters the same denied source.
        LateOrphanId := CreateGuid();
        InsertOrphanLink(0, LateOrphanId);
        TakeoverState.ClearLastSkip();
        StorageUpgrade.RunCompanyUpgrade();

        // [THEN] Takeover is retried, while the one-time purge remains suppressed by its tag.
        Assert.IsTrue(TakeoverState.TryGetLastSkip(DeniedTableId, ErrorText), 'Tagged upgrade must retry the skipped takeover.');
        Assert.AreEqual(10075986, DeniedTableId, 'Repeated skip must retain its table identity.');
        Assert.IsTrue(Link.Get(0, LateOrphanId), 'An existing tag must prevent a second purge.');
        Link.Delete();
        AssertDestinationSentinels(LinkId);
        StorageSetup.Get('XRETRY76');
        StorageSetup.Description := 'Xwrite after skipped retry';
        StorageSetup.Modify();
        StorageSetup.Get('XRETRY76');
        Assert.AreEqual('Xwrite after skipped retry', StorageSetup.Description, 'Subsequent transaction work must remain usable.');
        DeleteDestinationSentinels(LinkId);
        TakeoverState.ClearProbeDenial();
        TakeoverState.ClearLastSkip();
    end;

    /// <summary>The tag fixture removes only the purge tag for the current company.</summary>
    [Test]
    procedure Scenario_AC03_TagFixture_PreservesUnrelatedTags()
    var
        UpgradeTags: RecordRef;
        OtherTag: Code[250];
        OtherCompany: Text[30];
    begin
        // Story #76, AC03 | Time: independent of Today/WorkDate | Risk: requires Function rollback.
        // [GIVEN] The target tag and sentinels differing in each part of its global key.
        Initialize();
        OtherTag := 'XRETRY76-UnrelatedTag';
        OtherCompany := 'XRETRY76-OtherCompany';
        Assert.AreNotEqual(OtherCompany, CompanyName(), 'The other-company sentinel must be distinct.');
        EnsureOrphanPurgeTag();
        InsertTagSentinel(OtherTag, CompanyName());
        InsertTagSentinel(OrphanPurgeTag(), OtherCompany);

        // [WHEN] Preparing the untagged-upgrade fixture.
        RemoveCompanyOrphanPurgeTag();

        // [THEN] Neither an unrelated tag nor another company loses its upgrade history.
        UpgradeTags.Open(9999);
        UpgradeTags.Field(1).SetRange(OrphanPurgeTag());
        UpgradeTags.Field(3).SetRange(CompanyName());
        Assert.IsTrue(UpgradeTags.IsEmpty(), 'Only the current-company purge tag must be removed.');
        UpgradeTags.Field(1).SetRange(OtherTag);
        Assert.AreEqual(1, UpgradeTags.Count(), 'A different tag in this company must survive.');
        UpgradeTags.Field(1).SetRange(OrphanPurgeTag());
        UpgradeTags.Field(3).SetRange(OtherCompany);
        Assert.AreEqual(1, UpgradeTags.Count(), 'The same tag in another company must survive.');
        UpgradeTags.Close();
        // Leave these rows to Function rollback; post-run snapshots must verify their removal.
    end;

    local procedure InsertTagSentinel(Tag: Code[250]; Company: Text[30])
    var
        UpgradeTags: RecordRef;
    begin
        UpgradeTags.Open(9999);
        UpgradeTags.Field(1).SetRange(Tag);
        UpgradeTags.Field(3).SetRange(Company);
        Assert.IsTrue(UpgradeTags.IsEmpty(), 'Tag sentinel already exists; require a clean disposable fixture.');
        UpgradeTags.Init();
        UpgradeTags.Field(1).Value := Tag;
        UpgradeTags.Field(3).Value := Company;
        UpgradeTags.Insert(false);
        UpgradeTags.Close();
    end;

    local procedure InsertOrphanLink(TableId: Integer; RecordSystemId: Guid)
    var
        Link: Record "Storage Attachment Link ori";
    begin
        Link.Init();
        Link."Table ID" := TableId;
        Link."Record System Id" := RecordSystemId;
        Link."File Name" := 'Xorphan76.txt';
        Link.Insert();
    end;

    local procedure RemoveCompanyOrphanPurgeTag()
    var
        UpgradeTags: RecordRef;
    begin
        // System Application 28: table 9999 is internal. Scope the unit fixture to this tag/company.
        // RequiredTestIsolation rejects an unsafe runner; actual rollback still needs runtime evidence.
        UpgradeTags.Open(9999);
        UpgradeTags.Field(1).SetRange(OrphanPurgeTag());
        UpgradeTags.Field(3).SetRange(CompanyName());
        UpgradeTags.DeleteAll(false);
        UpgradeTags.Close();
    end;

    local procedure OrphanPurgeTag(): Code[250]
    begin
        exit('Origo.Bifrost.Attachments-PurgeOrphanLinks-20260928');
    end;

    local procedure EnsureOrphanPurgeTag()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(OrphanPurgeTag()) then
            UpgradeTag.SetUpgradeTag(OrphanPurgeTag());
    end;

    local procedure AssertNoLegacyRoles()
    var
        AccessControl: RecordRef;
    begin
        AccessControl.Open(2000000053);
        AccessControl.Field(2).SetRange('CE Storage');
        AccessControl.Field(9).SetRange(LegacyAppId());
        Assert.IsTrue(AccessControl.IsEmpty(), 'No-op fixture requires no legacy assignments across any company; residual roles regrant separately.');
        AccessControl.Close();
    end;

    local procedure CountTargetRoles(): Integer
    var
        AccessControl: RecordRef;
        RowCount: Integer;
    begin
        AccessControl.Open(2000000053);
        AccessControl.Field(2).SetRange('BIFROST Attach ori');
        AccessControl.Field(9).SetRange(AttachmentsAppId());
        RowCount := AccessControl.Count();
        AccessControl.Close();
        exit(RowCount);
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
        LinkId := StorageSetup.SystemId;
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
