namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Opens the Attachments setup from the Bifröst page's Related menu.
/// </summary>
pageextension 10035136 "Bifrost Ext. ori" extends "Bifrost ori"
{
    actions
    {
        addafter(BifrostSetup)
        {
            action(AttachmentsSetup)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Attachments Setup', Comment = 'is-IS=Uppsetning Bifröst viðhengja';
                ToolTip = 'Open the setup page of Bifrost Attachments, where storage connections and file accounts are configured.', Comment = 'is-IS=Opna uppsetningarsíðu Bifröst viðhengja þar sem geymslutengingar og skráareikningar eru stilltir.';
                Image = Setup;
                RunObject = page "Attachments Setup ori";
            }
        }
    }
}
