namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

enumextension 70013516 "DataExch Type Set EnumExt ori" extends "Message Type ori"
{
    value(70013516; "DataExchange.Type.Set")
    {
        Caption = 'DataExchange.Type.Set', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Type Set Impl ori", "Msg Discovery ori" = "DataExch Type Set Impl ori", "Msg Contract ori" = "DataExch Type Set Impl ori";
    }
}
