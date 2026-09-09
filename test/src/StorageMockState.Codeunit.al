namespace Origo.Bifrost.Attachments.Test;

using Origo.Bifrost.Attachments;

/// <summary>
/// Single-instance in-memory file system backing the <c>Bifrost Storage Mock Impl</c> test
/// connector. Files are stored as path → base64 content; directories as a set of paths.
/// Tests call <see cref="Reset"/> in their Initialize step to start from an empty state.
/// </summary>
codeunit 96201 "Storage Mock State"
{
    SingleInstance = true;

    var
        Files: Dictionary of [Text, Text];
        Directories: List of [Text];

    /// <summary>Clears all mock files and directories.</summary>
    procedure Reset()
    begin
        Clear(Files);
        Clear(Directories);
    end;

    /// <summary>Stores (or overwrites) a file with base64 content.</summary>
    /// <param name="Path">The file path.</param>
    /// <param name="ContentBase64">The base64-encoded content.</param>
    procedure PutFile(Path: Text; ContentBase64: Text)
    begin
        Files.Set(Path, ContentBase64);
    end;

    /// <summary>Returns the base64 content of a file.</summary>
    /// <param name="Path">The file path.</param>
    /// <returns>The stored base64 content.</returns>
    procedure GetFileContent(Path: Text): Text
    begin
        exit(Files.Get(Path));
    end;

    /// <summary>Returns whether a file exists.</summary>
    /// <param name="Path">The file path.</param>
    /// <returns>True when the file exists.</returns>
    procedure HasFile(Path: Text): Boolean
    begin
        exit(Files.ContainsKey(Path));
    end;

    /// <summary>Removes a file.</summary>
    /// <param name="Path">The file path.</param>
    procedure RemoveFile(Path: Text)
    begin
        if Files.ContainsKey(Path) then
            Files.Remove(Path);
    end;

    /// <summary>Returns all stored file paths.</summary>
    /// <returns>The list of file paths.</returns>
    procedure FilePaths(): List of [Text]
    begin
        exit(Files.Keys());
    end;

    /// <summary>Adds a directory path.</summary>
    /// <param name="Path">The directory path.</param>
    procedure AddDirectory(Path: Text)
    begin
        if not Directories.Contains(Path) then
            Directories.Add(Path);
    end;

    /// <summary>Removes a directory path.</summary>
    /// <param name="Path">The directory path.</param>
    procedure RemoveDirectory(Path: Text)
    begin
        if Directories.Contains(Path) then
            Directories.Remove(Path);
    end;

    /// <summary>Returns whether a directory exists.</summary>
    /// <param name="Path">The directory path.</param>
    /// <returns>True when the directory exists.</returns>
    procedure HasDirectory(Path: Text): Boolean
    begin
        exit(Directories.Contains(Path));
    end;

    /// <summary>Returns all stored directory paths.</summary>
    /// <returns>The list of directory paths.</returns>
    procedure DirectoryPaths(): List of [Text]
    begin
        exit(Directories);
    end;
}
