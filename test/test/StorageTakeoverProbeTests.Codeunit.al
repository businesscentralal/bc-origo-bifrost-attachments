namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.Reflection;
using System.TestLibraries.Utilities;

/// <summary>
/// AC01–AC03 coverage for permission-tolerant install-time take-over (attachments#8).
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
        Takeover: Codeunit "Storage Takeover ori";
        TableMetadata: Record "Table Metadata";
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

    local procedure Initialize()
    var
        TakeoverState: Codeunit "Storage Takeover State ori";
    begin
        TakeoverState.ClearProbeDenial();
        TakeoverState.ClearLastSkip();
    end;
}
