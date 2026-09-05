namespace Origo.Bifrost.Hnitbjorg;

using Microsoft.Foundation.Attachment;

/// <summary>
/// Widens the set of tables that can carry a <c>Document Attachment</c>.
/// <para>
/// The base application decides which field identifies a record for attachment purposes in
/// <c>Document Attachment Mgmt.TableHasNumberFieldPrimayKey</c>, which is a fixed list —
/// customers, vendors, items, employees, fixed assets, jobs, resources and the sales and
/// purchase documents. Every other table falls through to the
/// <c>OnAfterTableHasNumberFieldPrimaryKey</c> event with no answer, and an attachment created
/// for it would end up with an empty key.
/// </para>
/// <para>
/// This subscriber answers for the tables the base list leaves out but that are addressable all
/// the same: any table whose primary key is a single code field of twenty characters or less —
/// G/L accounts, bank accounts, contacts, locations, and anything an extension adds in the same
/// shape. It never overrides an answer the base application already gave, and it stays silent
/// for composite keys, where one field cannot identify the record.
/// </para>
/// </summary>
codeunit 10035668 "Storage Attach Key Subscr ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Document Attachment Mgmt", 'OnAfterTableHasNumberFieldPrimaryKey', '', false, false)]
    local procedure OnAfterTableHasNumberFieldPrimaryKey(TableNo: Integer; var Result: Boolean; var FieldNo: Integer)
    var
        ResolvedFieldNo: Integer;
    begin
        if Result then
            exit;
        if not TableHasSingleCodeKey(TableNo, ResolvedFieldNo) then
            exit;
        FieldNo := ResolvedFieldNo;
        Result := true;
    end;

    /// <summary>Returns true when the table's primary key is one code field of at most 20 characters.</summary>
    /// <param name="TableNo">The table to inspect.</param>
    /// <param name="FieldNo">Out: the field number of that key field, or 0.</param>
    local procedure TableHasSingleCodeKey(TableNo: Integer; var FieldNo: Integer): Boolean
    var
        RecordRef: RecordRef;
        FieldRef: FieldRef;
        KeyRef: KeyRef;
    begin
        FieldNo := 0;
        if not TryOpenTable(RecordRef, TableNo) then
            exit(false);

        KeyRef := RecordRef.KeyIndex(1);
        if KeyRef.FieldCount() <> 1 then begin
            RecordRef.Close();
            exit(false);
        end;

        FieldRef := KeyRef.FieldIndex(1);
        if FieldRef.Type() <> FieldType::Code then begin
            RecordRef.Close();
            exit(false);
        end;
        if FieldRef.Length() > MaxKeyLengthTok() then begin
            RecordRef.Close();
            exit(false);
        end;

        FieldNo := FieldRef.Number();
        RecordRef.Close();
        exit(true);
    end;

    /// <summary>The width of <c>Document Attachment."No."</c>, which the key value has to fit in.</summary>
    local procedure MaxKeyLengthTok(): Integer
    begin
        exit(20);
    end;

    [TryFunction]
    local procedure TryOpenTable(var RecordRef: RecordRef; TableNo: Integer)
    begin
        RecordRef.Open(TableNo);
    end;
}
