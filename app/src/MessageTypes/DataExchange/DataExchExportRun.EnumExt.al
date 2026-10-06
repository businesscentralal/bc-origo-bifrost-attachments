namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

enumextension 70013519 "DataExch Export Run EnumExt ori" extends "Message Type ori"
{
    value(70013519; "DataExchange.Export.Run")
    {
        Caption = 'DataExchange.Export.Run', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Export Run Impl ori", "Msg Discovery ori" = "DataExch Export Run Impl ori", "Msg Contract ori" = "DataExch Export Run Impl ori";
    }
}
