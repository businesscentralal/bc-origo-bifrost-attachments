namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;
using System.TestLibraries.Utilities;

/// <summary>Fixture isolation rejects foreign paths before issuing an HTTP request.</summary>
codeunit 96267 "Storage HTTP Fixture Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit "Library Assert";

    /// <summary>Foreign connection codes cannot access the loopback service.</summary>
    [Test]
    procedure ForeignStorageRejected()
    begin
        AssertRejected('CUSTOMER', 'w8168-test.txt', '');
    end;

    /// <summary>Parent paths cannot escape the fixture directory.</summary>
    [Test]
    procedure TraversalRejected()
    begin
        AssertRejected('W8168-TEST', 'w8168/../other.txt', '');
    end;

    /// <summary>Request query strings cannot change the destination.</summary>
    [Test]
    procedure QueryStringRejected()
    begin
        AssertRejected('W8168-TEST', 'w8168-test?path=other', '');
    end;

    /// <summary>The fixture never accepts an alternate base path.</summary>
    [Test]
    procedure BasePathRejected()
    begin
        AssertRejected('W8168-TEST', 'w8168-test.txt', 'other');
    end;

    local procedure AssertRejected(StorageCode: Code[20]; Path: Text; BasePath: Text)
    var
        TempSetup: Record "Storage Setup ori" temporary;
        Connector: Codeunit "Storage HTTP Fixture ori";
    begin
        TempSetup.Code := StorageCode;
        TempSetup."Base Path" := CopyStr(BasePath, 1, MaxStrLen(TempSetup."Base Path"));
        asserterror Connector.DeleteFile(TempSetup, Path);
        LibraryAssert.ExpectedError('Only isolated W8168 storage codes and simple w8168 file names are allowed.');
    end;
}
