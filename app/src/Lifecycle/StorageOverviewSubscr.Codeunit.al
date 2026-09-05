namespace Origo.Bifrost.Hnitbjorg;

using Origo.Bifrost;

/// <summary>
/// Subscribes to the <c>Bifrost Message Events.OnAfterCreatingOverview</c>
/// integration event and appends a single row for the <c>Help.Storage.Get</c>
/// discovery endpoint to the overview Markdown table built by
/// <c>Help.Bifrost.Get</c>.
/// </summary>
codeunit 10035638 "Storage Overview Subscr ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Message Events ori", 'OnAfterCreatingOverview', '', false, false)]
    local procedure OnAfterCreatingOverview(Overview: TextBuilder)
    begin
        Overview.AppendLine('| `Help.Storage.Get` | Storage connector directory - file, directory, upload, and attachment message types for Business Central external file storage. |');
    end;
}
