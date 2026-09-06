namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Adds Bifrost Attachments to the Apps group on the Bifröst Setup page. The single action
/// opens <c>Attachments Setup ori</c>, which owns everything this module contributes to setup.
/// </summary>
pageextension 10035635 "Setup Ext. ori" extends "Setup ori"
{
    actions
    {
        addlast(Apps)
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
        addlast(Category_Apps)
        {
            actionref(AttachmentsSetup_Promoted; AttachmentsSetup) { }
        }
    }
}
