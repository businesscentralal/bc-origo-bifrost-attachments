namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>
/// Validates a caller's <c>tableView</c> for a table with Foundation's <c>ApplyTableView</c> (an unknown
/// or unfilterable field fails closed with a structured refusal) and keeps the applied view, so
/// <c>DataExchange.Export.Run</c> can select its source records without applying an unchecked view.
/// </summary>
codeunit 70013511 "DataExch View Filter ori"
{
    Access = Internal;

    var
        Refusal: JsonObject;
        MessageType: Enum "Message Type ori";
        TableView: Text;
        AppliedView: Text;
        TableNo: Integer;
        Valid: Boolean;

    trigger OnRun()
    var
        TempViewArgument: Record "Message Argument ori" temporary;
        SourceRef: RecordRef;
        ViewRequest: JsonObject;
    begin
        Valid := false;
        Clear(Refusal);
        SourceRef.Open(TableNo);
        TempViewArgument.Init();
        TempViewArgument."Type" := MessageType;
        TempViewArgument.Insert(true);
        ViewRequest.Add('tableView', TableView);
        Valid := TempViewArgument.ApplyTableView(ViewRequest, SourceRef);
        if Valid then
            AppliedView := SourceRef.GetView()
        else
            Refusal := TempViewArgument.GetResponseJson();
    end;

    /// <summary>Sets the table and the view to validate before <c>Run</c>.</summary>
    /// <param name="NewMessageType">The message type the view belongs to.</param>
    /// <param name="NewTableNo">The table the view filters.</param>
    /// <param name="NewTableView">The caller's view text.</param>
    procedure SetSource(NewMessageType: Enum "Message Type ori"; NewTableNo: Integer; NewTableView: Text)
    begin
        MessageType := NewMessageType;
        TableNo := NewTableNo;
        TableView := NewTableView;
    end;

    /// <summary>Tells whether the view was valid.</summary>
    /// <returns>True when Foundation accepted and applied the view.</returns>
    procedure IsValid(): Boolean
    begin
        exit(Valid);
    end;

    /// <summary>Returns the applied view, as GetView renders it.</summary>
    /// <returns>The view text.</returns>
    procedure GetAppliedView(): Text
    begin
        exit(AppliedView);
    end;

    /// <summary>Returns Foundation's structured refusal of an invalid view.</summary>
    /// <returns>The error response.</returns>
    procedure GetRefusal(): JsonObject
    begin
        exit(Refusal);
    end;
}
