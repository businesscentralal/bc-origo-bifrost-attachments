namespace Origo.Bifrost.Hnitbjorg;

using System.ExternalFileStorage;

/// <summary>
/// Modal lookup that lists the Business Central file accounts registered for a given
/// connector, so a <c>Bifrost Storage Setup</c> row can be bound to one of them.
/// Call <see cref="SetConnector"/> before running the page modally, then read the
/// chosen account with <see cref="GetSelectedAccount"/>.
/// </summary>
page 10035635 "Storage Account Lookup ori"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Select File Account', Comment = 'is-IS=Velja skráareikning';
    SourceTable = "File Account";
    SourceTableTemporary = true;
    Editable = false;
    Extensible = false;
    ContextSensitiveHelpPage = 'StorageAccountLookup.html';

    layout
    {
        area(content)
        {
            repeater(Accounts)
            {
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    Caption = 'Name', Comment = 'is-IS=Heiti';
                    ToolTip = 'Specifies the name of the registered file account.', Comment = 'is-IS=Tilgreinir heiti skráða skráareikningsins.';
                }
                field("Account Id"; Rec."Account Id")
                {
                    ApplicationArea = All;
                    Caption = 'Account Id', Comment = 'is-IS=Kenni reiknings';
                    ToolTip = 'Specifies the unique identifier of the registered file account.', Comment = 'is-IS=Tilgreinir einkvæmt kenni skráða skráareikningsins.';
                    Visible = false;
                }
            }
        }
    }

    var
        ConnectorFilter: Enum "Ext. File Storage Connector";

    trigger OnOpenPage()
    var
        FileAccount: Codeunit "File Account";
    begin
        FileAccount.GetAllAccounts(false, Rec);
        Rec.SetRange(Connector, ConnectorFilter);
        if Rec.FindFirst() then;
    end;

    /// <summary>Restricts the listed accounts to a single connector.</summary>
    /// <param name="Connector">The connector whose accounts are shown.</param>
    procedure SetConnector(Connector: Enum "Ext. File Storage Connector")
    begin
        ConnectorFilter := Connector;
    end;

    /// <summary>Copies the selected account into the caller's record.</summary>
    /// <param name="TempFileAccount">Out: the selected file account.</param>
    procedure GetSelectedAccount(var TempFileAccount: Record "File Account" temporary)
    begin
        TempFileAccount := Rec;
    end;
}
