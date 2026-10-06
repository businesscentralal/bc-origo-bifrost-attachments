namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

enumextension 70013514 "DataExch DefDel MsgType ori" extends "Message Type ori"
{
    value(70013523; "DataExchange.Definition.Delete")
    {
        Caption = 'DataExchange.Definition.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Def Delete Impl ori", "Msg Discovery ori" = "DataExch Def Delete Impl ori", "Msg Contract ori" = "DataExch Def Delete Impl ori";
    }
}
