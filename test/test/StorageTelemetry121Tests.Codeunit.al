namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.Security.AccessControl;

/// <summary>Issue 121: publisher telemetry contains only bounded diagnostic metadata.</summary>
codeunit 96227 "Storage Telemetry121 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure Scenario_AC01_AC02_MirrorFailure_OnlySafeMetadata()
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        Dimensions: Dictionary of [Text, Text];
        AttachmentId: Guid;
    begin
        // Story #121, AC01/02 | Time: none | Risk: no customer data fixture required.
        AttachmentId := CreateGuid();
        Dimensions := AttachmentMgt.NativeFieldMirrorFailureDimensions(AttachmentId, true);
        Assert.AreEqual(3, Dimensions.Count(), 'Mirror telemetry must contain only the three safe fields.');
        Assert.AreEqual(Format(AttachmentId, 0, 4), Dimensions.Get('systemId'), 'Keep the safe correlation identifier.');
        Assert.AreEqual('NativeFieldAssignmentFailed', Dimensions.Get('errorCode'), 'Use a fixed failure category.');
        Assert.AreEqual('SetNativeExternalStorageFields', Dimensions.Get('operation'), 'Identify the failing operation.');
        Assert.IsFalse(Dimensions.ContainsKey('error'), 'Free error text must not reach publisher telemetry.');
        Assert.IsFalse(Dimensions.ContainsKey('company'), 'Company names must not reach publisher telemetry.');
    end;

    [Test]
    procedure Scenario_AC03_ClearMirrorFailure_IdentifiesRestoreOperation()
    var
        AttachmentMgt: Codeunit "Storage Attachment Mgt ori";
        Dimensions: Dictionary of [Text, Text];
    begin
        // Story #121, AC03 | Time: none | Risk: none.
        Dimensions := AttachmentMgt.NativeFieldMirrorFailureDimensions(CreateGuid(), false);
        Assert.AreEqual(3, Dimensions.Count(), 'Restore must use the same bounded metadata contract.');
        Assert.AreEqual('NativeFieldAssignmentFailed', Dimensions.Get('errorCode'), 'Retain the failure category.');
        Assert.AreEqual('ClearNativeExternalStorageFields', Dimensions.Get('operation'), 'Distinguish restore from offload.');
    end;

    [Test]
    procedure Scenario_AC01_AC02_AC03_TakeoverDenials_OnlySafeDiagnostics()
    var
        Takeover: Codeunit "Storage Takeover ori";
        Dimensions: Dictionary of [Text, Text];
    begin
        // Story #121, AC01/02/03 | Time: none | Risk: no permission or company data is changed.
        Dimensions := Takeover.TakeOverSkippedDimensions(10075985);
        Assert.AreEqual(4, Dimensions.Count(), 'Takeover telemetry must contain only four safe fields.');
        Assert.AreEqual('10075985', Dimensions.Get('tableId'), 'Keep the denied table identifier.');
        Assert.AreEqual('ReadPermissionDenied', Dimensions.Get('errorCode'), 'Distinguish a read denial.');
        Assert.AreEqual('TakeOver', Dimensions.Get('operation'), 'Keep the operation.');
        Assert.AreEqual('manual', Dimensions.Get('phase'), 'Keep lifecycle diagnostics.');
        Assert.IsFalse(Dimensions.ContainsKey('company'), 'Never send the current company name.');
        Assert.IsFalse(Dimensions.ContainsKey('error'), 'Never send free error text.');
        Dimensions := Takeover.TakeOverSkippedDimensions(Database::"Access Control");
        Assert.AreEqual(4, Dimensions.Count(), 'Write denial must have the same bounded contract.');
        Assert.AreEqual('WritePermissionDenied', Dimensions.Get('errorCode'), 'Distinguish a write denial.');
        Assert.AreEqual(Format(Database::"Access Control", 0, 9), Dimensions.Get('tableId'), 'Keep the denied object id.');
    end;
}
