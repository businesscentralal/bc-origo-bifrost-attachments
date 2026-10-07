namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>Registers the unchanged DataExchange.Export.Run message and its production bindings.</summary>
enumextension 70013519 "DataExch Export MsgType ori" extends "Message Type ori"
{
    value(70013519; "DataExchange.Export.Run")
    {
        Caption = 'DataExchange.Export.Run', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Export Run Impl ori", "Msg Discovery ori" = "DataExch Export Run Impl ori", "Msg Contract ori" = "DataExch Export Run Impl ori";
    }
}
