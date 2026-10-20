namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

enumextension 10035136 "DataExch Def Exp EnumExt ori" extends "Message Type ori"
{
    value(10035169; "DataExchange.Definition.Export")
    {
        Caption = 'DataExchange.Definition.Export', Locked = true;
        Implementation = "Msg Interface ori" = "DataExch Def Export Impl ori", "Msg Discovery ori" = "DataExch Def Export Impl ori", "Msg Contract ori" = "DataExch Def Export Impl ori";
    }
}
