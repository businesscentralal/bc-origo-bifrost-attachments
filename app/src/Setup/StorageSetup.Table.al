namespace Origo.Bifrost.Attachments;

using System.ExternalFileStorage;

/// <summary>
/// One row per configured storage connection. Each row binds a short <c>Code</c> — the
/// value carried in a Bifrost request's <c>storageCode</c> — to a Business Central
/// external file storage account (a <c>Connector</c> plus a registered <c>File Account Id</c>).
/// Storage message types resolve the row by <c>Code</c> and route the action through the
/// <c>Storage Type</c> interface, which delegates to the
/// <c>External File Storage</c> facade. Secrets are owned by the connector apps, never stored here.
/// </summary>
table 10035636 "Storage Setup ori"
{
    Caption = 'Bifrost Storage Setup', Comment = 'is-IS=Uppsetning Bifröst geymslu';
    DataClassification = CustomerContent;
    LookupPageId = "Storage Setup ori";
    DrillDownPageId = "Storage Setup ori";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code', Comment = 'is-IS=Kóði';
            NotBlank = true;
            ToolTip = 'Specifies the code that a Bifrost request passes as ''storageCode'' to select this storage connection.', Comment = 'is-IS=Tilgreinir kóðann sem Bifröst-beiðni sendir sem ''storageCode'' til að velja þessa geymslutengingu.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description', Comment = 'is-IS=Lýsing';
            ToolTip = 'Specifies a human-readable description of the storage connection.', Comment = 'is-IS=Tilgreinir læsilega lýsingu á geymslutengingunni.';
        }
        field(3; "Storage Type"; Enum "Storage Type ori")
        {
            Caption = 'Storage Type', Comment = 'is-IS=Geymslutegund';
            ToolTip = 'Specifies how storage actions are carried out. The default routes through the Business Central External File Storage facade.', Comment = 'is-IS=Tilgreinir hvernig geymsluaðgerðir eru framkvæmdar. Sjálfgefið leiðir í gegnum ytri skráageymslu Business Central.';
        }
        field(4; Connector; Enum "Ext. File Storage Connector")
        {
            Caption = 'Connector', Comment = 'is-IS=Tengill';
            ToolTip = 'Specifies the Business Central external file storage connector (for example Azure Blob, Azure File Share or SharePoint) that owns the file account.', Comment = 'is-IS=Tilgreinir ytri skráageymslutengil Business Central (til dæmis Azure Blob, Azure File Share eða SharePoint) sem á skráareikninginn.';

            trigger OnValidate()
            begin
                if Connector <> xRec.Connector then
                    ClearFileAccount();
            end;
        }
        field(5; "File Account Id"; Guid)
        {
            Caption = 'File Account Id', Comment = 'is-IS=Kenni skráareiknings';
            ToolTip = 'Specifies the registered Business Central file account used for this storage connection.', Comment = 'is-IS=Tilgreinir skráða skráareikninginn í Business Central sem notaður er fyrir þessa geymslutengingu.';
        }
        field(6; "File Account Name"; Text[250])
        {
            Caption = 'File Account Name', Comment = 'is-IS=Heiti skráareiknings';
            Editable = false;
            ToolTip = 'Specifies the display name of the selected file account.', Comment = 'is-IS=Tilgreinir birtingarheiti valda skráareikningsins.';
        }
        field(7; "Base Path"; Text[250])
        {
            Caption = 'Base Path', Comment = 'is-IS=Grunnslóð';
            ToolTip = 'Specifies an optional path prefix prepended to every path used through this connection. Leave blank to address the account root.', Comment = 'is-IS=Tilgreinir valfrjálst slóðarforskeyti sem bætt er framan við hverja slóð sem notuð er um þessa tengingu. Skildu eftir autt til að vísa á rót reikningsins.';
        }
        field(8; Enabled; Boolean)
        {
            Caption = 'Enabled', Comment = 'is-IS=Virk';
            ToolTip = 'Specifies whether this storage connection can be used by Bifrost requests.', Comment = 'is-IS=Tilgreinir hvort Bifröst-beiðnir geta notað þessa geymslutengingu.';
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(Brick; "Code", Description, "File Account Name", Enabled) { }
        fieldgroup(DropDown; "Code", Description, "File Account Name") { }
    }

    /// <summary>Clears the selected file account when the connector changes.</summary>
    procedure ClearFileAccount()
    begin
        Clear("File Account Id");
        Clear("File Account Name");
    end;

    /// <summary>Returns true when a file account has been selected for this row.</summary>
    /// <returns>True when <c>File Account Id</c> is not the empty GUID.</returns>
    procedure HasFileAccount(): Boolean
    begin
        exit(not IsNullGuid("File Account Id"));
    end;

    /// <summary>Tests the storage connection and shows a success message, or errors if the backend cannot be reached.</summary>
    procedure TestConnection()
    var
        StorageConnector: Interface "Storage Connector ori";
        ConnectionOkMsg: Label 'The storage connection ''%1'' is reachable.', Comment = '%1 = storage code';
    begin
        TestField("Code");
        if not HasFileAccount() then
            Error(NoAccountErr);
        StorageConnector := "Storage Type";
        StorageConnector.TestConnection(Rec);
        Message(ConnectionOkMsg, "Code");
    end;

    var
        NoAccountErr: Label 'Select a file account before testing the connection.';
}
