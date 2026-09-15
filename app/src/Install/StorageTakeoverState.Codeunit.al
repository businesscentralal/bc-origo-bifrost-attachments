namespace Origo.Bifrost.Attachments;

/// <summary>
/// Session-scoped state for the Attachments legacy take-over probe (#8).
/// Mirrors Foundation <c>Take-Over State ori</c> probe-denial and last-skip telemetry
/// seams so unit tests can force a denial without Origo Cloud Events Storage installed.
/// Ambiguity A1: no singleton pending flag — skip is telemetry-only and idempotent.
/// </summary>
codeunit 10035681 "Storage Takeover State ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        ProbeDenialTableId: Integer;
        ProbeDenialActive: Boolean;
        LastDeniedTableId: Integer;
        LastSkipErrorText: Text;
        HasLastSkip: Boolean;

    /// <summary>Test hook: next probe pretends this table id is denied (read or Access Control write).</summary>
    internal procedure SetProbeDenial(TableId: Integer)
    begin
        ProbeDenialTableId := TableId;
        ProbeDenialActive := true;
    end;

    /// <summary>Test hook: clears the probe denial override.</summary>
    internal procedure ClearProbeDenial()
    begin
        ProbeDenialTableId := 0;
        ProbeDenialActive := false;
    end;

    /// <summary>Returns whether a test probe denial is active and which table id it targets.</summary>
    internal procedure TryGetProbeDenial(var TableId: Integer): Boolean
    begin
        if not ProbeDenialActive then
            exit(false);
        TableId := ProbeDenialTableId;
        exit(true);
    end;

    /// <summary>Records the last take-over skip (denied table + error text) for test assertions.</summary>
    internal procedure SetLastSkip(DeniedTableId: Integer; ErrorText: Text)
    begin
        LastDeniedTableId := DeniedTableId;
        LastSkipErrorText := ErrorText;
        HasLastSkip := true;
    end;

    /// <summary>Test hook: returns the last recorded skip, if any.</summary>
    internal procedure TryGetLastSkip(var DeniedTableId: Integer; var ErrorText: Text): Boolean
    begin
        if not HasLastSkip then
            exit(false);
        DeniedTableId := LastDeniedTableId;
        ErrorText := LastSkipErrorText;
        exit(true);
    end;

    /// <summary>Test hook: clears the last skip capture.</summary>
    internal procedure ClearLastSkip()
    begin
        LastDeniedTableId := 0;
        LastSkipErrorText := '';
        HasLastSkip := false;
    end;
}
