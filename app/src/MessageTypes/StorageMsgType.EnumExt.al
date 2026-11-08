namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Extends the Bifrost Base <c>Bifrost Message Type</c> enum with the storage
/// connector message types. Each value binds the <c>Bifrost Msg Interface</c> to a
/// dedicated <c>*Impl</c> codeunit that routes the action through the configured storage
/// connection. Captions are <c>Locked = true</c> because Bifrost message identifiers
/// are part of the public wire contract.
/// </summary>
enumextension 10035142 "Storage Msg Type ori" extends "Message Type ori"
{
    /// <summary>Returns a Markdown overview of the storage connector and all its message types.</summary>
    value(10035135; "Help.Storage.Get")
    {
        Caption = 'Help.Storage.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Help Get Impl ori", "Msg Discovery ori" = "Storage Help Get Impl ori", "Msg Contract ori" = "Storage Help Get Impl ori";
    }
    /// <summary>Lists the configured storage connections (codes and connectors; no secrets).</summary>
    value(10035136; "Storage.Account.List")
    {
        Caption = 'Storage.Account.List', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Account List Impl ori", "Msg Discovery ori" = "Storage Account List Impl ori", "Msg Contract ori" = "Storage Account List Impl ori";
    }
    /// <summary>Lists the files in a directory.</summary>
    value(10035137; "Storage.File.List")
    {
        Caption = 'Storage.File.List', Locked = true;
        Implementation = "Msg Interface ori" = "Storage File List Impl ori", "Msg Discovery ori" = "Storage File List Impl ori", "Msg Contract ori" = "Storage File List Impl ori";
    }
    /// <summary>Downloads a file as base64.</summary>
    value(10035138; "Storage.File.Get")
    {
        Caption = 'Storage.File.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Storage File Get Impl ori", "Msg Discovery ori" = "Storage File Get Impl ori", "Msg Contract ori" = "Storage File Get Impl ori";
    }
    /// <summary>Uploads a base64 file.</summary>
    value(10035139; "Storage.File.Create")
    {
        Caption = 'Storage.File.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Storage File Create Impl ori", "Msg Discovery ori" = "Storage File Create Impl ori", "Msg Contract ori" = "Storage File Create Impl ori";
    }
    /// <summary>Deletes a file.</summary>
    value(10035140; "Storage.File.Delete")
    {
        Caption = 'Storage.File.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Storage File Delete Impl ori", "Msg Discovery ori" = "Storage File Delete Impl ori", "Msg Contract ori" = "Storage File Delete Impl ori";
    }
    /// <summary>Copies a file.</summary>
    value(10035141; "Storage.File.Copy")
    {
        Caption = 'Storage.File.Copy', Locked = true;
        Implementation = "Msg Interface ori" = "Storage File Copy Impl ori", "Msg Discovery ori" = "Storage File Copy Impl ori", "Msg Contract ori" = "Storage File Copy Impl ori";
    }
    /// <summary>Moves a file.</summary>
    value(10035142; "Storage.File.Move")
    {
        Caption = 'Storage.File.Move', Locked = true;
        Implementation = "Msg Interface ori" = "Storage File Move Impl ori", "Msg Discovery ori" = "Storage File Move Impl ori", "Msg Contract ori" = "Storage File Move Impl ori";
    }
    /// <summary>Checks whether a file exists.</summary>
    value(10035143; "Storage.File.Exists")
    {
        Caption = 'Storage.File.Exists', Locked = true;
        Implementation = "Msg Interface ori" = "Storage File Exists Impl ori", "Msg Discovery ori" = "Storage File Exists Impl ori", "Msg Contract ori" = "Storage File Exists Impl ori";
    }
    /// <summary>Lists the directories in a directory.</summary>
    value(10035144; "Storage.Directory.List")
    {
        Caption = 'Storage.Directory.List', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Dir List Impl ori", "Msg Discovery ori" = "Storage Dir List Impl ori", "Msg Contract ori" = "Storage Dir List Impl ori";
    }
    /// <summary>Creates a directory.</summary>
    value(10035145; "Storage.Directory.Create")
    {
        Caption = 'Storage.Directory.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Dir Create Impl ori", "Msg Discovery ori" = "Storage Dir Create Impl ori", "Msg Contract ori" = "Storage Dir Create Impl ori";
    }
    /// <summary>Deletes a directory.</summary>
    value(10035146; "Storage.Directory.Delete")
    {
        Caption = 'Storage.Directory.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Dir Delete Impl ori", "Msg Discovery ori" = "Storage Dir Delete Impl ori", "Msg Contract ori" = "Storage Dir Delete Impl ori";
    }
    /// <summary>Checks whether a directory exists.</summary>
    value(10035147; "Storage.Directory.Exists")
    {
        Caption = 'Storage.Directory.Exists', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Dir Exists Impl ori", "Msg Discovery ori" = "Storage Dir Exists Impl ori", "Msg Contract ori" = "Storage Dir Exists Impl ori";
    }
    /// <summary>Offloads an attachment's file to storage and clears it from the database.</summary>
    value(10035148; "Storage.Attachment.Offload")
    {
        Caption = 'Storage.Attachment.Offload', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Att. Offload Impl ori", "Msg Discovery ori" = "Storage Att. Offload Impl ori", "Msg Contract ori" = "Storage Att. Offload Impl ori";
    }
    /// <summary>Restores an offloaded attachment's file from storage back into the database.</summary>
    value(10035149; "Storage.Attachment.Restore")
    {
        Caption = 'Storage.Attachment.Restore', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Att. Restore Impl ori", "Msg Discovery ori" = "Storage Att. Restore Impl ori", "Msg Contract ori" = "Storage Att. Restore Impl ori";
    }
    /// <summary>Opens a chunked upload session for delivering a large file in pieces.</summary>
    value(10035150; "Storage.Upload.Begin")
    {
        Caption = 'Storage.Upload.Begin', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Upload Begin Impl ori", "Msg Discovery ori" = "Storage Upload Begin Impl ori", "Msg Contract ori" = "Storage Upload Begin Impl ori";
    }
    /// <summary>Appends one base64 chunk to an open upload session.</summary>
    value(10035151; "Storage.Upload.Append")
    {
        Caption = 'Storage.Upload.Append', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Upload Append Impl ori", "Msg Discovery ori" = "Storage Upload Append Impl ori", "Msg Contract ori" = "Storage Upload Append Impl ori";
    }
    /// <summary>Assembles an upload session's chunks and writes the file to storage.</summary>
    value(10035152; "Storage.Upload.Commit")
    {
        Caption = 'Storage.Upload.Commit', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Upload Commit Impl ori", "Msg Discovery ori" = "Storage Upload Commit Impl ori", "Msg Contract ori" = "Storage Upload Commit Impl ori";
    }
    /// <summary>Discards an open upload session without writing to storage.</summary>
    value(10035153; "Storage.Upload.Abort")
    {
        Caption = 'Storage.Upload.Abort', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Upload Abort Impl ori", "Msg Discovery ori" = "Storage Upload Abort Impl ori", "Msg Contract ori" = "Storage Upload Abort Impl ori";
    }
    /// <summary>Reports the progress and state of an upload session.</summary>
    value(10035154; "Storage.Upload.Status")
    {
        Caption = 'Storage.Upload.Status', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Upload Status Impl ori", "Msg Discovery ori" = "Storage Upload Status Impl ori", "Msg Contract ori" = "Storage Upload Status Impl ori";
    }
    /// <summary>Attaches a file already in storage to a new or existing incoming document.</summary>
    value(10035155; "Storage.Attachment.CreateLinked")
    {
        Caption = 'Storage.Attachment.CreateLinked', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Attach Link Impl ori", "Msg Discovery ori" = "Storage Attach Link Impl ori", "Msg Contract ori" = "Storage Attach Link Impl ori";
    }
    /// <summary>Creates a document attachment on any record, from base64, from storage, or by copying an existing attachment.</summary>
    value(10035156; "Storage.Attachment.CreateForRecord")
    {
        Caption = 'Storage.Attachment.CreateForRecord', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Attach Record Impl ori", "Msg Discovery ori" = "Storage Attach Record Impl ori", "Msg Contract ori" = "Storage Attach Record Impl ori";
    }
    /// <summary>Assembles uploaded chunks and attaches the file to a record without external storage.</summary>
    value(10035157; "Storage.Upload.CommitToRecord")
    {
        Caption = 'Storage.Upload.CommitToRecord', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Upload Commit Rec ori", "Msg Discovery ori" = "Storage Upload Commit Rec ori", "Msg Contract ori" = "Storage Upload Commit Rec ori";
    }
    /// <summary>Hands a complete chunked upload to a consuming app through Foundation staging.</summary>
    value(10035174; "Storage.Upload.CommitToStaging")
    {
        Caption = 'Storage.Upload.CommitToStaging', Locked = true;
        Implementation = "Msg Interface ori" = "Storage Upload Staging ori", "Msg Discovery ori" = "Storage Upload Staging ori", "Msg Contract ori" = "Storage Upload Staging ori";
    }
}
