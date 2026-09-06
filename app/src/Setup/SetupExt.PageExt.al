namespace Origo.Bifrost.Hnitbjorg;

using Origo.Bifrost;

/// <summary>
/// Adds Bifröst Hnitbjörg to the Apps group on the Bifröst Setup page. The single action
/// opens <c>Hnitbjorg Setup ori</c>, which owns everything this module contributes to setup.
/// </summary>
pageextension 10035635 "Setup Ext. ori" extends "Setup ori"
{
    actions
    {
        addlast(Apps)
        {
            action(HnitbjorgSetup)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Hnitbjorg Setup', Comment = 'is-IS=Uppsetning Bifröst Hnitbjargar';
                ToolTip = 'Open the setup page of Bifrost Hnitbjorg, where storage connections and file accounts are configured.', Comment = 'is-IS=Opna uppsetningarsíðu Bifröst Hnitbjargar þar sem geymslutengingar og skráareikningar eru stilltir.';
                Image = Setup;
                RunObject = page "Hnitbjorg Setup ori";
            }
        }
        addlast(Category_Apps)
        {
            actionref(HnitbjorgSetup_Promoted; HnitbjorgSetup) { }
        }
    }
}
