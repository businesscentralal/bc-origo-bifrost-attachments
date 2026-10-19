namespace Origo.Bifrost.Attachments.Test;

/// <summary>
/// Target table of the Generic Import test definition: one row per imported line, written by the
/// mapping codeunit <c>DataExch Test Mapping ori</c> through the base app's Process Data Exch.
/// </summary>
table 96240 "DataExch Test Target ori"
{
    Caption = 'Data Exchange Test Target';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Data Exch. No."; Integer)
        {
            Caption = 'Data Exch. No.';
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "Code"; Code[20])
        {
            Caption = 'Code';
        }
        field(4; Name; Text[100])
        {
            Caption = 'Name';
        }
        field(5; Amount; Decimal)
        {
            Caption = 'Amount';
        }
    }

    keys
    {
        key(PK; "Data Exch. No.", "Line No.")
        {
            Clustered = true;
        }
    }
}
