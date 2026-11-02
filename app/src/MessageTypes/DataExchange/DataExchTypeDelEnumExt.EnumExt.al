namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

enumextension 10035201 "DataExch TypeDel EnumExt ori" extends "Message Type ori"
{
    value(10035174; "DataExchange.Type.Delete")
    {
        Caption = 'DataExchange.Type.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Type Delete Impl ori", "Msg Discovery ori" = "DataExch Type Delete Impl ori", "Msg Contract ori" = "DataExch Type Delete Impl ori";
    }
}
