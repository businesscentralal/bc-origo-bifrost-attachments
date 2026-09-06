namespace Origo.Bifrost.Hnitbjorg;

/// <summary>
/// List of configured storage connections. Each row is the <c>storageCode</c> a Cloud
/// Event request uses to address a Business Central file account.
/// </summary>
page 10035637 "Storage Setup ori"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Bifrost Storage Setup', Comment = 'is-IS=Uppsetning Bifröst geymslu';
    SourceTable = "Storage Setup ori";
    CardPageId = "Storage Card ori";
    Editable = false;
    ContextSensitiveHelpPage = 'StorageSetup.html';

    layout
    {
        area(content)
        {
            repeater(Connections)
            {
                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
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
                }
                field("Base Path"; Rec."Base Path")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
