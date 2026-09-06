namespace Origo.Bifrost.Attachments;

/// <summary>
/// List part showing the configured storage connections. It is embedded in
/// <c>Attachments Setup ori</c> so an administrator sees every <c>storageCode</c> that Bifröst
/// requests can address without leaving the application setup page.
/// </summary>
page 10035678 "Storage Conn. Part ori"
{
    PageType = ListPart;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Storage Connections', Comment = 'is-IS=Geymslutengingar';
    SourceTable = "Storage Setup ori";
    CardPageId = "Storage Card ori";
    Editable = false;
    ContextSensitiveHelpPage = 'hnitbjorg-setup';

    layout
    {
        area(Content)
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
