namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

enumextension 10035138 "DataExch Import MsgType ori" extends "Message Type ori"
{
    value(10035170; "DataExchange.Import.Run")
    {
        Caption = 'DataExchange.Import.Run', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Import Run Impl ori", "Msg Discovery ori" = "DataExch Import Run Impl ori", "Msg Contract ori" = "DataExch Import Run Impl ori";
    }
}
