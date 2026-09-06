namespace Origo.Bifrost.Attachments;

using System.ExternalFileStorage;
using System.Utilities;

/// <summary>
/// Abstraction over a single configured storage backend. Each value of
/// <c>Bifrost Storage Type</c> binds this interface to an implementation. The
/// production implementation delegates to the Business Central <c>External File Storage</c>
/// facade; the test app supplies an in-memory mock.
/// </summary>
/// <remarks>
/// All methods receive the resolved <c>Bifrost Storage Setup</c> row so the
/// implementation can locate the underlying file account. Methods that do not return a
/// value raise an error on failure; callers wrap them so the failure surfaces in the
/// Bifrost response envelope.
/// </remarks>
interface "Storage Connector ori"
{
    /// <summary>Verifies that the configured backend can be reached. Raises an error when it cannot.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    procedure TestConnection(StorageSetup: Record "Storage Setup ori")

    /// <summary>Lists the files or directories directly under a path.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Path">The directory whose contents are listed.</param>
    /// <param name="EntryType">Whether files or directories are listed.</param>
    /// <param name="TempFileAccountContent">Out: the listed entries (temporary).</param>
    procedure ListEntries(StorageSetup: Record "Storage Setup ori"; Path: Text; EntryType: Enum "Ext. File Storage File Type"; var TempFileAccountContent: Record "File Account Content" temporary)

    /// <summary>Downloads a file's content into a blob. Raises an error when the file cannot be read.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Path">The file path to read.</param>
    /// <param name="TempBlob">Out: the file content.</param>
    procedure GetFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")

    /// <summary>Uploads a blob to a file path. Raises an error when the file cannot be written.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Path">The destination file path.</param>
    /// <param name="TempBlob">The content to store.</param>
    procedure CreateFile(StorageSetup: Record "Storage Setup ori"; Path: Text; var TempBlob: Codeunit "Temp Blob")

    /// <summary>Deletes a file. Raises an error when the file cannot be deleted.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Path">The file path to delete.</param>
    procedure DeleteFile(StorageSetup: Record "Storage Setup ori"; Path: Text)

    /// <summary>Returns whether a file exists.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Path">The file path to check.</param>
    /// <returns>True when the file exists.</returns>
    procedure FileExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean

    /// <summary>Copies a file. Raises an error on failure.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="SourcePath">The source file path.</param>
    /// <param name="TargetPath">The destination file path.</param>
    procedure CopyFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)

    /// <summary>Moves a file. Raises an error on failure.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="SourcePath">The source file path.</param>
    /// <param name="TargetPath">The destination file path.</param>
    procedure MoveFile(StorageSetup: Record "Storage Setup ori"; SourcePath: Text; TargetPath: Text)

    /// <summary>Creates a directory. Raises an error on failure.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Path">The directory path to create.</param>
    procedure CreateDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)

    /// <summary>Deletes a directory. Raises an error on failure.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Path">The directory path to delete.</param>
    procedure DeleteDirectory(StorageSetup: Record "Storage Setup ori"; Path: Text)

    /// <summary>Returns whether a directory exists.</summary>
    /// <param name="StorageSetup">The resolved storage setup row.</param>
    /// <param name="Path">The directory path to check.</param>
    /// <returns>True when the directory exists.</returns>
    procedure DirectoryExists(StorageSetup: Record "Storage Setup ori"; Path: Text): Boolean
}
