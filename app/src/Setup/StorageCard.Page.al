namespace Origo.Bifrost.Attachments;

using System.ExternalFileStorage;

/// <summary>
/// Card for a single storage connection. Lets an administrator bind a <c>storageCode</c>
/// to a registered Business Central file account and an optional base path, and to test
/// that the backend can be reached.
/// </summary>
page 10035636 "Storage Card ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Bifrost Storage Connection', Comment = 'is-IS=Bifröst geymslutenging';
    SourceTable = "Storage Setup ori";
    ContextSensitiveHelpPage = 'storage-card';

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General', Comment = 'is-IS=Almennt';

                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                }
            }
            group(Backend)
            {
                Caption = 'Backend', Comment = 'is-IS=Bakendi';

                field("Storage Type"; Rec."Storage Type")
                {
                    ApplicationArea = All;
                }
                field(Connector; Rec.Connector)
                {
                    ApplicationArea = All;
                }
                field("File Account Name"; Rec."File Account Name")
                {
                    ApplicationArea = All;
                    AssistEdit = true;

                    trigger OnAssistEdit()
                    begin
                        LookupFileAccount();
                    end;
                }
                field("Base Path"; Rec."Base Path")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(SelectFileAccount)
            {
                ApplicationArea = All;
                Caption = 'Select File Account', Comment = 'is-IS=Velja skráareikning';
                ToolTip = 'Selects one of the file accounts registered for the chosen connector.', Comment = 'is-IS=Velur einn af skráareikningunum sem skráðir eru fyrir valda tengilinn.';
                Image = Setup;

                trigger OnAction()
                begin
                    LookupFileAccount();
                end;
            }
            action(TestConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Connection', Comment = 'is-IS=Prófa tengingu';
                ToolTip = 'Verifies that the configured storage backend can be reached.', Comment = 'is-IS=Staðfestir að hægt sé að ná í uppsetta geymslubakendann.';
                Image = TestReport;

                trigger OnAction()
                begin
                    Rec.TestConnection();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process', Comment = 'is-IS=Vinnsla';

                actionref(SelectFileAccount_Promoted; SelectFileAccount) { }
                actionref(TestConnection_Promoted; TestConnection) { }
            }
        }
    }

    /// <summary>Opens the account lookup for the chosen connector and stores the selection.</summary>
    local procedure LookupFileAccount()
    var
        TempFileAccount: Record "File Account" temporary;
        AccountLookup: Page "Storage Account Lookup ori";
    begin
        AccountLookup.SetConnector(Rec.Connector);
        AccountLookup.LookupMode(true);
        if AccountLookup.RunModal() <> Action::LookupOK then
            exit;
        AccountLookup.GetSelectedAccount(TempFileAccount);
        Rec."File Account Id" := TempFileAccount."Account Id";
        Rec."File Account Name" := TempFileAccount.Name;
        Rec.Modify(true);
    end;
}
