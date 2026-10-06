namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

enumextension 70013511 "DataExch Import MsgType ori" extends "Message Type ori"
{
    value(70013516; "DataExchange.Import.Run")
    {
        Caption = 'DataExchange.Import.Run', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Import Run Impl ori", "Msg Discovery ori" = "DataExch Import Run Impl ori", "Msg Contract ori" = "DataExch Import Run Impl ori";
    }
}
