namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>Builds the shared contract chapters for Bifröst Attachments message types.</summary>
codeunit 10035183 "Storage Contract Parts ori"
{
    Access = Internal;

    var
        SuccessEnvelopeLbl: Label 'Every success answers status Success. The fields below belong to the data object, not to the top level.', Comment = 'is-IS=Öll svör sem heppnast hafa stöðuna Success. Reitirnir hér að neðan tilheyra hlutnum data, ekki efsta stigi svarsins.';
        ProcessWarningsLbl: Label 'Objects with a stable code and a localized message: NoMappingCodeunit or RecordIdsCapped.', Comment = 'is-IS=Hlutir með stöðugum kóða (code) og þýddum skilaboðum (message): NoMappingCodeunit eða RecordIdsCapped.';
        DocumentTypeNameLbl: Label 'The language-independent document type enum name, never its numeric ordinal.', Comment = 'is-IS=Tungumálaóháð heiti talningargildis skjalagerðar, aldrei tölugildi þess.';
        DataExchangeFailureLbl: Label 'Business Central cannot complete the Data Exchange operation.', Comment = 'is-IS=Business Central getur ekki lokið gagnaskiptaaðgerðinni.';
        DataExchangeFailureFixLbl: Label 'Check the supplied definition or entry and the Business Central error details.', Comment = 'is-IS=Athugaðu uppgefna skilgreiningu eða færslu og villuupplýsingar Business Central.';
        PagingSkipLbl: Label 'Number of rows or fields skipped.', Comment = 'is-IS=Fjöldi færslna eða reita sem var sleppt.';
        PagingTakeLbl: Label 'Effective page size.', Comment = 'is-IS=Virk síðustærð.';
        SkipDescriptionLbl: Label 'Rows or fields to skip; a nonnegative integer.', Comment = 'is-IS=Færslur eða reitir sem á að sleppa; heiltala sem er ekki neikvæð.';
        TakeDescriptionLbl: Label 'Page size from 0 to 1000. Omitted or 0 uses 100; larger values are refused.', Comment = 'is-IS=Síðustærð frá 0 til 1000. Sleppi eða 0 notar 100; hærri gildum er hafnað.';
        AttachmentStorageLbl: Label 'Required with path when attaching a stored file. Omit for inline content or a source attachment.', Comment = 'is-IS=Nauðsynlegt með path þegar skrá úr geymslu er hengd við. Slepptu fyrir innfellt innihald eða upprunaviðhengi.';
        SourceTargetLbl: Label 'Required with sourceSystemId: IncomingDocument or DocumentAttachment. Choose exactly one source: contentBase64 (or content), storageCode with path, or sourceTarget with sourceSystemId.', Comment = 'is-IS=Nauðsynlegt með sourceSystemId: IncomingDocument eða DocumentAttachment. Veldu nákvæmlega eina uppsprettu: contentBase64 (eða content), storageCode með path eða sourceTarget með sourceSystemId.';
        SourceSystemIdLbl: Label 'The source attachment SystemId; required with sourceTarget.', Comment = 'is-IS=SystemId upprunaviðhengis; nauðsynlegt með sourceTarget.';
        UploadStorageLbl: Label 'Required for Storage.Upload.Commit to storage. Omit when the session will use Storage.Upload.CommitToRecord.', Comment = 'is-IS=Nauðsynlegt fyrir Storage.Upload.Commit í geymslu. Slepptu þegar lotan mun nota Storage.Upload.CommitToRecord.';
        UploadTableIdLbl: Label 'The host record table id; use tableId or tableName for DocumentAttachment. Not used for IncomingDocument.', Comment = 'is-IS=Töfluauðkenni hýsilfærslu; notaðu tableId eða tableName fyrir DocumentAttachment. Ekki notað fyrir IncomingDocument.';
        UploadTableNameLbl: Label 'Accepted table name instead of tableId for DocumentAttachment.', Comment = 'is-IS=Heiti töflu sem má nota í stað tableId fyrir DocumentAttachment.';
        IncomingDescriptionLbl: Label 'Description for a new IncomingDocument; ignored for DocumentAttachment.', Comment = 'is-IS=Lýsing fyrir nýtt IncomingDocument; hunsað fyrir DocumentAttachment.';
        UploadRecordIdLbl: Label 'For DocumentAttachment, identify the host by recordSystemId or no; required for tables without no addressing.', Comment = 'is-IS=Fyrir DocumentAttachment skal auðkenna hýsil með recordSystemId eða no; nauðsynlegt fyrir töflur sem ekki eru auðkenndar með no.';
        TypeCodeLbl: Label 'The Data Exchange Type code, at most 20 characters.', Comment = 'is-IS=Kóði gerðar gagnaskipta, að hámarki 20 stafir.';
        ImportDefinitionLbl: Label 'The existing import definition code, at most 20 characters.', Comment = 'is-IS=Kóði fyrirliggjandi innflutningsskilgreiningar, að hámarki 20 stafir.';
        ExportDefinitionLbl: Label 'The existing export definition code, at most 20 characters.', Comment = 'is-IS=Kóði fyrirliggjandi útflutningsskilgreiningar, að hámarki 20 stafir.';
        TypeDescriptionLbl: Label 'Optional description within the Data Exchange Type Description field length.', Comment = 'is-IS=Valfrjáls lýsing innan lengdar lýsingarreits gerðar gagnaskipta.';
        ImportStorageLbl: Label 'The storage connection of the file. Required with path unless contentBase64 is sent. Resolve it with Storage.Account.List.', Comment = 'is-IS=Geymslutenging skrárinnar. Nauðsynleg með path nema contentBase64 sé sent. Finndu hana með Storage.Account.List.';
        ImportPathLbl: Label 'The file path in storage. Required with storageCode unless contentBase64 is sent. The file is read and stays unchanged.', Comment = 'is-IS=Slóð skrárinnar í geymslu. Nauðsynleg með storageCode nema contentBase64 sé sent. Skráin er lesin og helst óbreytt.';
        ExportFileNameLbl: Label 'Optional output file name within the Data Exch. File Name field length. Default: the definition code, a timestamp and the extension of the file type.', Comment = 'is-IS=Valfrjálst heiti úttaksskrár innan lengdar skráarheitisreits gagnaskipta. Sjálfgefið: kóði skilgreiningar, tímastimpill og ending skráargerðarinnar.';
        InlineContentLbl: Label 'The file content encoded as base64, at most 1 MB. Send instead of storageCode and path.', Comment = 'is-IS=Innihald skrárinnar kóðað sem base64, mest 1 MB. Sendu í stað storageCode og path.';
        ProcessImportLbl: Label 'When true, the import is committed and the definition mappings run at once, as DataExchange.Entry.Process does. Default false.', Comment = 'is-IS=Þegar true er innflutningurinn staðfestur og varpanir skilgreiningarinnar keyrðar strax, eins og DataExchange.Entry.Process gerir. Sjálfgefið false.';
        KeepFileLbl: Label 'When true, the assembled file is also written to the storage path of the upload session. Default false.', Comment = 'is-IS=Þegar true er samsetta skráin einnig skrifuð á geymsluslóð upphleðslulotunnar. Sjálfgefið false.';
        DeliveryStorageLbl: Label 'The storage connection the file is written to. Send it, or inline true, or both.', Comment = 'is-IS=Geymslutengingin sem skráin er skrifuð í. Sendu hana, eða inline true, eða hvort tveggja.';
        DefinitionDeliveryStorageLbl: Label 'Optional storage connection for writing the definition XML. Omit all delivery parameters for the header only; use inline true for XML without storage, or combine both destinations.', Comment = 'is-IS=Valfrjáls geymslutenging til að skrifa XML skilgreiningarinnar. Slepptu öllum afhendingarbreytum fyrir hausinn eingöngu; notaðu inline true fyrir XML án geymslu eða sameinaðu báða áfangastaði.';
        DefinitionDeliveredStorageLbl: Label 'The storage connection used when the definition XML was written; omitted for header-only or inline-only requests.', Comment = 'is-IS=Geymslutengingin sem var notuð þegar XML skilgreiningarinnar var skrifað; sleppt þegar aðeins er beðið um haus eða innfellt XML.';
        DefinitionExportEffectLbl: Label 'Header-only and inline-only requests read the definition without changing it. With storageCode, writes the XML to external storage and refuses an existing file unless overwrite is true. This write is irreversible: it happens outside the Business Central transaction and is not rolled back with it.', Comment = 'is-IS=Beiðnir um haus eingöngu eða innfellt XML eingöngu lesa skilgreininguna án þess að breyta henni. Með storageCode er XML skrifað í ytri geymslu og hafnar fyrirliggjandi skrá nema overwrite sé true. Skrifin eru óafturkræf: þau fara fram utan færslu Business Central og eru ekki afturkölluð með henni.';
        DeliveryPathLbl: Label 'The destination file path in storage. Default: folderPath (or the connection root) with the file name.', Comment = 'is-IS=Áfangaslóð skrárinnar í geymslu. Sjálfgefið: folderPath (eða rót tengingarinnar) með skráarheitinu.';
        DeliveryFolderLbl: Label 'The destination folder in storage; the file name is appended. Do not send with path.', Comment = 'is-IS=Áfangamappa í geymslu; skráarheitinu er bætt aftan við. Ekki senda með path.';
        DeliveryInlineLbl: Label 'When true, the file is returned as contentBase64; refused when it is larger than 1 MB.', Comment = 'is-IS=Þegar true er skránni skilað sem contentBase64; hafnað ef hún er stærri en 1 MB.';
        ExportTableLbl: Label 'The source table id; it must be the table of the definition mapping. Send it (or tableName), or recordIds.', Comment = 'is-IS=Auðkenni upprunatöflu; hún verður að vera tafla skilgreiningarvörpunarinnar. Sendu það (eða tableName), eða recordIds.';
        ExportTableViewLbl: Label 'Optional Business Central table view on the source table, for example WHERE(No.=FILTER(10000..30000)). Validated like Data.Records.Get.', Comment = 'is-IS=Valfrjáls töflusýn Business Central á upprunatöfluna, til dæmis WHERE(No.=FILTER(10000..30000)). Sannreynd eins og í Data.Records.Get.';
        ExportRecordIdsLbl: Label 'SystemIds of the source records to export, 1 to 1000. Do not send with tableView.', Comment = 'is-IS=SystemId-gildi upprunafærslnanna sem á að flytja út, 1 til 1000. Ekki senda með tableView.';
        ExportLineDefLbl: Label 'Optional line definition whose mapping is used. Default: the first mapping of the definition.', Comment = 'is-IS=Valfrjáls línuskilgreining sem vörpunin er notuð frá. Sjálfgefið: fyrsta vörpun skilgreiningarinnar.';
        EntryNoLbl: Label 'The Data Exchange entry number.', Comment = 'is-IS=Númer gagnaskiptafærslunnar.';
        MappingLineDefLbl: Label 'Optional line definition whose mappings run alone. Default: every mapping of the definition.', Comment = 'is-IS=Valfrjáls línuskilgreining þar sem aðeins varpanir hennar eru keyrðar. Sjálfgefið: allar varpanir skilgreiningarinnar.';
        DefinitionUploadLbl: Label 'The uploadId of a complete chunked upload that holds the XML. The upload is consumed.', Comment = 'is-IS=uploadId fullgerðrar upphleðslu í bútum sem geymir XML-skjalið. Upphleðslan er notuð upp.';
        StorageOverwriteLbl: Label 'Default false. An existing destination is refused with PreconditionFailed on path. Set overwrite true to replace it explicitly. Files backing attachments remain protected.', Comment = 'is-IS=Sjálfgefið false. Fyrirliggjandi áfangastað er hafnað með PreconditionFailed á path. Settu overwrite true til að skipta honum sérstaklega út. Skrár sem geyma viðhengi eru áfram verndaðar.';
        StorageOverwriteNextLbl: Label 'Choose a new path or send overwrite true. Restore or remove any linked attachment before replacing its file.', Comment = 'is-IS=Veldu nýja slóð eða sendu overwrite true. Endurheimtu eða fjarlægðu tengt viðhengi áður en skipt er um skrá þess.';
        RestoreOwnedFileLbl: Label 'Writes the content back into the Business Central attachment and removes its link. Deletes the external file only when this attachment created a new file. Pre-existing files, explicitly overwritten files and legacy links with unknown ownership are preserved.', Comment = 'is-IS=Skrifar innihaldið aftur í viðhengið í Business Central og fjarlægir tengingu þess. Eyðir ytri skránni aðeins ef þetta viðhengi stofnaði nýja skrá. Fyrirliggjandi skrár, sérstaklega yfirskrifaðar skrár og eldri tengingar með óþekkt eignarhald eru varðveittar.';
        LinkedSourceEffectLbl: Label 'Storage input links the existing file and takes responsibility for serving attachment content from it, without copying or taking deletion ownership. Restore copies the content into Business Central and preserves the source file; deleting the attachment also preserves that file.', Comment = 'is-IS=Inntak úr geymslu tengir fyrirliggjandi skrá og tekur ábyrgð á að afhenda innihald viðhengis úr henni án þess að afrita eða taka eignarhald til eyðingar. Endurheimt afritar innihaldið í Business Central og varðveitir upprunaskrána; eyðing viðhengisins varðveitir einnig þá skrá.';
        OverwriteLbl: Label 'When true, an existing definition with the same code is deleted and installed again. Default false.', Comment = 'is-IS=Þegar true er skilgreiningu með sama kóða eytt og hún sett upp aftur. Sjálfgefið false.';
        NewCodeLbl: Label 'Optional code to install a file with one definition under, for example to copy a definition.', Comment = 'is-IS=Valfrjáls kóði til að setja upp skrá með einni skilgreiningu undir, til dæmis til að afrita skilgreiningu.';
        JournalTemplateLbl: Label 'The payment journal template name, exactly as stored.', Comment = 'is-IS=Heiti sniðmáts greiðslubókar, nákvæmlega eins og það er vistað.';
        JournalBatchLbl: Label 'The payment journal batch name, exactly as stored.', Comment = 'is-IS=Heiti keyrslu greiðslubókar, nákvæmlega eins og það er vistað.';
        PaymentFileNameLbl: Label 'Optional file name. Default: the name the payment export chooses, for example the credit transfer identifier.', Comment = 'is-IS=Valfrjálst skráarheiti. Sjálfgefið: heitið sem útflutningur greiðslna velur, til dæmis auðkenni millifærslunnar.';
        ImportResultLbl: Label 'Parsed result: lines and fields read by the definition reader.', Comment = 'is-IS=Þáttuð niðurstaða: línur og reitir sem lesari skilgreiningarinnar las.';
        ProcessResultLbl: Label 'When process is true: processed, targets, warnings and errors of the mapping run. Each warning is an object with code and message.', Comment = 'is-IS=Þegar process er true: processed, targets, warnings og errors úr keyrslu varpananna. Hver viðvörun er hlutur með code og message.';
        TargetsLbl: Label 'One object per target table: tableId, tableName, recordsInserted, recordsModified and up to 100 recordIds (SystemIds).', Comment = 'is-IS=Einn hlutur fyrir hverja marktöflu: tableId, tableName, recordsInserted, recordsModified og allt að 100 recordIds (SystemId-gildi).';
        DeliveredLengthLbl: Label 'The file size in bytes.', Comment = 'is-IS=Stærð skrárinnar í bætum.';
        DeliveredContentLbl: Label 'The file content as base64, when inline is true.', Comment = 'is-IS=Innihald skrárinnar sem base64, þegar inline er true.';
        DeliveredPathLbl: Label 'The storage path the file was written to, when storageCode was sent.', Comment = 'is-IS=Geymsluslóðin sem skráin var skrifuð á, þegar storageCode var sent.';
        DefinitionCodeLbl: Label 'The complete Data Exchange definition code, at most 20 characters.', Comment = 'is-IS=Allur kóði gagnaskiptaskilgreiningar, að hámarki 20 stafir.';
        UploadResponseStorageLbl: Label 'The session storage connection code; empty for a record-only upload.', Comment = 'is-IS=Geymslutengingarkóði lotunnar; tómt fyrir upphleðslu eingöngu í færslu.';
        ChunkSizeHintLbl: Label 'The recommended raw chunk size in bytes.', Comment = 'is-IS=Ráðlögð stærð hrárrar gagnaeiningar í bætum.';
        UploadFileNameLbl: Label 'The session file name.', Comment = 'is-IS=Skráarheiti lotunnar.';
        UploadPathLbl: Label 'The session storage path.', Comment = 'is-IS=Geymsluslóð lotunnar.';
        DeclaredSizeLbl: Label 'The declared file size in bytes.', Comment = 'is-IS=Uppgefin skráarstærð í bætum.';
        DefinitionNameLbl: Label 'The definition name.', Comment = 'is-IS=Heiti skilgreiningar.';
        DefinitionTypeLbl: Label 'The definition type name.', Comment = 'is-IS=Gerðarheiti skilgreiningar.';
        CreatedEntryLbl: Label 'The created Data Exchange entry number.', Comment = 'is-IS=Númer gagnaskiptafærslunnar sem var stofnuð.';
        MatchingCountLbl: Label 'Number of matching rows.', Comment = 'is-IS=Fjöldi samsvarandi færslna.';
        MatchingTypesLbl: Label 'The Data Exchange Types and their linked definitions.', Comment = 'is-IS=Gerðir gagnaskipta og tengdar skilgreiningar þeirra.';
        MissingInputLbl: Label 'A required request parameter is missing.', Comment = 'is-IS=Nauðsynlega færibreytu vantar í beiðnina.';
        SupplyInputLbl: Label 'Provide the named parameter and retry.', Comment = 'is-IS=Gefðu upp tilgreinda færibreytu og reyndu aftur.';
        InvalidFormatLbl: Label 'A parameter has the wrong JSON type or format.', Comment = 'is-IS=Færibreyta hefur ranga JSON-gerð eða snið.';
        CorrectInputLbl: Label 'Correct every reported parameter using expected and nextStep, then retry.', Comment = 'is-IS=Leiðréttu allar tilgreindar færibreytur samkvæmt expected og nextStep og reyndu aftur.';
        InvalidInputLbl: Label 'A parameter is outside the allowed values or length.', Comment = 'is-IS=Færibreyta er utan leyfilegra gilda eða lengdar.';
        MultipleInputLbl: Label 'Several parameters are invalid; errors lists every problem.', Comment = 'is-IS=Margar færibreytur eru ógildar; errors telur upp öll vandamálin.';
        MissingRecordLbl: Label 'The supplied definition code does not exist.', Comment = 'is-IS=Uppgefinn skilgreiningarkóði er ekki til.';
        ChooseRecordLbl: Label 'Choose an existing compatible definition using DataExchange.Definition.List.', Comment = 'is-IS=Veldu fyrirliggjandi samhæfa skilgreiningu með DataExchange.Definition.List.';
        UnusableDefinitionLbl: Label 'The definition is referenced or incompatible with this operation.', Comment = 'is-IS=Vísað er í skilgreininguna eða hún er ósamhæf við þessa aðgerð.';
        InlineLimitLbl: Label 'The requested inline file content exceeds 1 MiB.', Comment = 'is-IS=Umbeðið innfellt skráarinnihald er yfir 1 MiB.';
        OmitInlineLbl: Label 'Omit includeFileContent or send false and retrieve the file through storage.', Comment = 'is-IS=Slepptu includeFileContent eða sendu false og sæktu skrána í gegnum geymslu.';
        DataExchangeChangesLbl: Label 'Writes Data Exchange definitions, types, entries and parsed fields, and the business records of processed mappings, within the transaction of the call. A file written to storage is the last step; a later failure rolls the call back. With process true the import is committed before the mappings run.', Comment = 'is-IS=Skrifar skilgreiningar, gerðir, færslur og þáttaða reiti gagnaskipta, og viðskiptafærslur unninna varpana, innan færslu kallsins. Skrif skráar í geymslu eru síðasta skrefið; síðari villa afturkallar kallið. Með process true er innflutningurinn staðfestur áður en varpanirnar keyra.';
        DataExchangePreconditionsLbl: Label 'The caller holds BIFROST DataExch ori and the Business Central permissions of the tables the operation writes; supplied definitions and entries must exist and support the operation. A storageCode must name an enabled storage connection.', Comment = 'is-IS=Kallandi hefur BIFROST DataExch ori og heimildir Business Central á töflunum sem aðgerðin skrifar í; uppgefnar skilgreiningar og færslur verða að vera til og styðja aðgerðina. storageCode verður að vísa á virka geymslutengingu.';
        PaymentChangesLbl: Label 'Runs the base-app payment export, which commits its own steps: the journal lines are marked Exported to Payment File and a credit transfer register keeps the file. The file is then written to storage; that write is not rolled back.', Comment = 'is-IS=Keyrir útflutning greiðslna grunnkerfisins sem staðfestir eigin skref: línurnar eru merktar Flutt út í greiðsluskrá og millifærsluskrá geymir skrána. Skráin er síðan skrifuð í geymslu og þau skrif eru ekki afturkölluð.';
        DataExchangeTypeParamLbl: Label 'Optional Data Exchange Type code for IncomingDocument. The type must already exist.', Comment = 'is-IS=Valfrjáls kóði gerðar gagnaskipta fyrir IncomingDocument. Gerðin verður að vera til.';
        ProcessParamLbl: Label 'When true, run CreateDocumentWithDataExchange after the incoming document is created. Default false. The upload still succeeds when processing reports errors.', Comment = 'is-IS=Þegar true er CreateDocumentWithDataExchange keyrt eftir að skjalið í innleið er stofnað. Sjálfgefið false. Upphleðslan heppnast samt þó vinnslan skili villum.';
        VendorNoParamLbl: Label 'Optional vendor number for a new incoming document.', Comment = 'is-IS=Valfrjálst lánardrottinsnúmer fyrir nýtt skjal í innleið.';
        DataExchangeTypeResponseLbl: Label 'The Data Exchange Type applied to the incoming document.', Comment = 'is-IS=Gerð gagnaskipta sem var sett á skjalið í innleið.';
        ProcessedResponseLbl: Label 'True when CreateDocumentWithDataExchange created a document.', Comment = 'is-IS=Satt þegar CreateDocumentWithDataExchange stofnaði skjal.';
        CreatedDocumentResponseLbl: Label 'The created document type, number and systemId when processing succeeded.', Comment = 'is-IS=Gerð, númer og systemId stofnaðs skjals þegar vinnsla tókst.';
        IncomingStatusResponseLbl: Label 'Stable incoming document status name after processing, for example Failed or Created.', Comment = 'is-IS=Fast stöðuheiti skjals í innleið eftir úrvinnslu, til dæmis Failed eða Created.';
        ProcessErrorsResponseLbl: Label 'Processing errors as objects containing code, message and nextStep; an empty array means no processing errors were reported.', Comment = 'is-IS=Úrvinnsluvillur sem hlutir með code, message og nextStep; tómt fylki þýðir að engar úrvinnsluvillur voru tilkynntar.';


    /// <summary>Returns recorded request and answer pairs for a public message type.</summary>
    /// <param name="MessageType">The public message type name.</param>
    /// <returns>The recorded examples; empty for an unknown type.</returns>
    procedure GetExamples(MessageType: Text) Examples: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        // Recorded from the owned COSMO W1 runtime. Exact source/version and
        // per-example bc28-w1 verification status are retained with the PR evidence.
        case MessageType of
            'Help.Storage.Get':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Help.Storage.Get","data":{},"lcid":1033}',
                        '{"status":"Success","data":{"format":"markdown","markdown":"# Bifrost Attachments - storage message types\r\n\r\nRead and write files in external storage (Azure Blob Storage, Azure File Share or SharePoint) through the Business Central external file storage connectors, stage large files in chunks and keep document attachments in storage instead of the database.\r\n\r\nStorage file writes refuse an existing destination by default. Send overwrite: true only to intentionally replace an unlinked file. Copy and Move always refuse an existing destination. CreateForRecord and CreateLinked link pre-existing storage files without acquiring deletion ownership: Restore and attachment deletion preserve those files.\r\n\r\n## Getting started\r\n\r\n1. Call `Storage.Account.List` to see the storage connections set up on the Attachments Setup page. Each row has a `storageCode`.\r\n2. Send that `storageCode` with every other storage call. Paths are relative to the base folder of the connection and use forward slashes; `.` and `..` segments, backslashes and double slashes are refused.\r\n3. Read the full contract of one type with `Help.Implementation.Get` (subject = the message type).\r\nStorage operations use the registered Business Central Exte'
                    + 'rnal File Storage connector interface. Attachments does not select behavior from connector IDs or inspect connector-owned account tables, and it requires no minimum connector version or build: any connector registered with External File Storage works. The registered connector owns credentials, provider-specific path rules and backend errors. Attachments validates its own request syntax and storage field lengths before calling the connector.\r\nAttachment protection spans setups using the same registered account and canonical logical path. Reuse that registration for shared attachment storage and keep path spelling consistent. Separate account registrations are separate scopes, even if they reach the same physical files; the interface exposes no physical identity or case-comparison contract.\r\nStorage.File.Copy and Storage.File.Move require a destination that the connector reports as abs'
                    + 'ent. An existing destination returns PreconditionFailed before a write. Linked moves require the storage implementation to guarantee source preservation on failure; the platform facade cannot provide that guarantee.\r\n\r\n## Message types\r\n\r\n| Area | Message type | Purpose |\r\n|---|---|---|\r\n| Accounts | `Storage.Account.List` | Lists the configured storage connections. |\r\n| Files | `Storage.File.List` | Lists the files in a folder. |\r\n| Files | `Storage.File.Get` | Returns the content of one file as base64. |\r\n| Files | `Storage.File.Exists` | Tells whether a file exists. |\r\n| Files | `Storage.File.Create` | Writes a file from base64 content. |\r\n| Files | `Storage.File.Copy` | Copies a file to a new path. |\r\n| Files | `Storage.File.Move` | Moves or renames a file; a linked file keeps its attachment link. |\r\n| Files | `Storage.File.Delete` | Deletes a file that no a'
                    + 'ttachment uses. |\r\n| Directories | `Storage.Directory.List` | Lists the subfolders of a folder. |\r\n| Directories | `Storage.Directory.Exists` | Tells whether a folder exists. |\r\n| Directories | `Storage.Directory.Create` | Creates a folder. |\r\n| Directories | `Storage.Directory.Delete` | Deletes a folder that holds no linked file. |\r\n| Attachments | `Storage.Attachment.Offload` | Moves the content of a document attachment to storage and links it. |\r\n| Attachments | `Storage.Attachment.Restore` | Writes linked content back into the attachment. Deletes only a file newly created by that attachment; pre-existing files and legacy links are preserved. |\r\n| Attachments | `Storage.Attachment.CreateLinked` | Attaches a stored file to a new or existing incoming document. Optional `dataExchangeType`, `process` and `vendorNo`. |\r\n| Attachments | `Storage.Attachment.CreateForRecord` | Creates an attachment on a record from base64 content. |\r\n| Uploads | `Sto'
                    + 'rage.Upload.Begin` | Opens a chunked upload session. |\r\n| Uploads | `Storage.Upload.Append` | Adds the next chunk to an open session. |\r\n| Uploads | `Storage.Upload.Status` | Returns the state of a session. |\r\n| Uploads | `Storage.Upload.Commit` | Assembles the chunks and writes the file to storage. |\r\n| Uploads | `Storage.Upload.CommitToRecord` | Assembles the chunks and attaches the file to a record or incoming document. IncomingDocument accepts `dataExchangeType`, `process` and `vendorNo`. |\r\n| Uploads | `Storage.Upload.CommitToDataExchange` | Assembles the chunks into a parsed Data Exch. entry of an import definition; optional `process` and `keepFileInStorage`. See `Help.DataExchange.Get`. |\r\n| Uploads | `Storage.Upload.Abort` | Discards an open session and its chunks. |\r\n\r\n## Chunked uploads\r\n\r\nUse an upload session when a file is larger than one request can carr'
                    + 'y: `Storage.Upload.Begin`, then `Storage.Upload.Append` once per chunk in order, then `Storage.Upload.Commit`, `Storage.Upload.CommitToRecord` or `Storage.Upload.CommitToDataExchange`. `Storage.Upload.Begin` returns `chunkSizeHint` and `maxChunkBytes`. Files are written under the `bifrost-uploads/` root unless the request names a folder. A session belongs to the user who opened it.\r\n\r\nTo feed an incoming document: `Storage.Upload.Begin` → `Storage.Upload.Append` → `Storage.Upload.CommitToRecord` with `target` IncomingDocument and optional `dataExchangeType`, `process` and `vendorNo`. Wire the type first with `DataExchange.Type.Set`. Processing errors stay on the incoming document as `processErrors`; the commit still returns Success. A file already in storage uses `Storage.Attachment.CreateLinked` with the same parameters.\r\n\r\n## Linked files\r\n\r\nA stored file that backs a docum'
                    + 'ent attachment is protected. Deleting it and writing a create, copy, move or upload commit onto its path are refused with `PreconditionFailed`; use `Storage.Attachment.Restore` to bring the content back first.\r\n\r\n## Errors\r\n\r\nA refused call answers `status = Error` with `code`, `parameter`, `received`, `expected` and `nextStep` for every problem found, so all problems can be fixed in one retry.\r\n\r\n`Storage.Directory.Delete` refuses the connection root path with `InvalidParameter` before the connector is called; name a folder below the root to delete.\r\n\r\n## Permissions\r\n\r\nAssign the `BIFROST Attach ori` permission set. The Data Exchange message types are described by `Help.DataExchange.Get` and need `BIFROST DataExch ori`.\r\n"}}'));
            'Storage.Account.List':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Storage.Account.List","data":{},"lcid":1033}',
                        '{"status":"Success","data":{"accounts":[]}}'));
            'Storage.File.List':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Storage.File.List","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.File.List\". Always read the help before calling a message type."}'));
            'Storage.File.Get':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Storage.File.Get","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help/example.txt"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.File.Get\". Always read the help before calling a message type."}'));
            'Storage.File.Create':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.File.Create","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help/example.txt","contentBase64":"SGVsbG8="},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.File.Create\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.File.Create","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"3 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"storageCode\" is missing.","parameter":"storageCode","received":"(missing)","expected":"a value for \"storageCode\"","nextStep":"Provide \"storageCode\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"path\" is missing.","parameter":"path","received":"(missing)","expected":"a value for \"path\"","nextStep":"Provide \"path\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"contentBase64\" is missing.","parameter":"contentBase64","received":"(missing)","expected":"a value for \"contentBase64\"","nextStep":"Provide \"contentBase64\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject'
                    + ' \"Storage.File.Create\". Always read the help before calling a message type."}'));
                end;
            'Storage.File.Delete':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.File.Delete","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help/example.txt"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.File.Delete\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.File.Delete","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"storageCode\" is missing.","parameter":"storageCode","received":"(missing)","expected":"a value for \"storageCode\"","nextStep":"Provide \"storageCode\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"path\" is missing.","parameter":"path","received":"(missing)","expected":"a value for \"path\"","nextStep":"Provide \"path\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.File.Delete\". Always read the help before calling a message type."}'));
                end;
            'Storage.File.Copy':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.File.Copy","data":{"storageCode":"X160-NOT-CONFIGURED","sourcePath":"X160-help/example.txt","targetPath":"X160-help/copy.txt"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.File.Copy\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.File.Copy","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"3 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"storageCode\" is missing.","parameter":"storageCode","received":"(missing)","expected":"a value for \"storageCode\"","nextStep":"Provide \"storageCode\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"sourcePath\" is missing.","parameter":"sourcePath","received":"(missing)","expected":"a value for \"sourcePath\"","nextStep":"Provide \"sourcePath\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"targetPath\" is missing.","parameter":"targetPath","received":"(missing)","expected":"a value for \"targetPath\"","nextStep":"Provide \"targetPath\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type '
                    + 'with subject \"Storage.File.Copy\". Always read the help before calling a message type."}'));
                end;
            'Storage.File.Move':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.File.Move","data":{"storageCode":"X160-NOT-CONFIGURED","sourcePath":"X160-help/example.txt","targetPath":"X160-help/moved.txt"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.File.Move\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.File.Move","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"3 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"storageCode\" is missing.","parameter":"storageCode","received":"(missing)","expected":"a value for \"storageCode\"","nextStep":"Provide \"storageCode\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"sourcePath\" is missing.","parameter":"sourcePath","received":"(missing)","expected":"a value for \"sourcePath\"","nextStep":"Provide \"sourcePath\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"targetPath\" is missing.","parameter":"targetPath","received":"(missing)","expected":"a value for \"targetPath\"","nextStep":"Provide \"targetPath\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type '
                    + 'with subject \"Storage.File.Move\". Always read the help before calling a message type."}'));
                end;
            'Storage.File.Exists':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Storage.File.Exists","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help/example.txt"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.File.Exists\". Always read the help before calling a message type."}'));
            'Storage.Directory.List':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Storage.Directory.List","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Directory.List\". Always read the help before calling a message type."}'));
            'Storage.Directory.Create':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Directory.Create","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Directory.Create\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Directory.Create","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"storageCode\" is missing.","parameter":"storageCode","received":"(missing)","expected":"a value for \"storageCode\"","nextStep":"Provide \"storageCode\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"path\" is missing.","parameter":"path","received":"(missing)","expected":"a value for \"path\"","nextStep":"Provide \"path\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Directory.Create\". Always read the help before calling a message type."}'));
                end;
            'Storage.Directory.Delete':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Directory.Delete","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Directory.Delete\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Directory.Delete","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"storageCode\" is missing.","parameter":"storageCode","received":"(missing)","expected":"a value for \"storageCode\"","nextStep":"Provide \"storageCode\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"path\" is missing.","parameter":"path","received":"(missing)","expected":"a value for \"path\"","nextStep":"Provide \"path\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Directory.Delete\". Always read the help before calling a message type."}'));
                end;
            'Storage.Directory.Exists':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Storage.Directory.Exists","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Directory.Exists\". Always read the help before calling a message type."}'));
            'Storage.Attachment.Offload':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Attachment.Offload","data":{"storageCode":"X160-NOT-CONFIGURED","target":"DocumentAttachment","systemId":"not-a-guid","folderPath":"X160-help"},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"InvalidParameterFormat","error":"Parameter \"systemId\" has value \"not-a-guid\", which is not a valid GUID. Expected a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301.","parameter":"systemId","received":"not-a-guid","expected":"a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301","nextStep":"Send the value as a GUID, as returned by the call that created it."},{"code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Attachment.Offload\". Always read the help before calling a message typ'
                    + 'e."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Attachment.Offload","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"3 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"target\" is missing.","parameter":"target","received":"(missing)","expected":"a value for \"target\"","nextStep":"Provide \"target\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"systemId\" is missing.","parameter":"systemId","received":"(missing)","expected":"a value for \"systemId\"","nextStep":"Provide \"systemId\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"storageCode\" is missing.","parameter":"storageCode","received":"(missing)","expected":"a value for \"storageCode\"","nextStep":"Provide \"storageCode\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.A'
                    + 'ttachment.Offload\". Always read the help before calling a message type."}'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Attachment.Restore","data":{"target":"DocumentAttachment","systemId":"not-a-guid"},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameterFormat","error":"Parameter \"systemId\" has value \"not-a-guid\", which is not a valid GUID. Expected a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301.","parameter":"systemId","received":"not-a-guid","expected":"a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301","nextStep":"Send the value as a GUID, as returned by the call that created it.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Attachment.Restore\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Attachment.Restore","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"target\" is missing.","parameter":"target","received":"(missing)","expected":"a value for \"target\"","nextStep":"Provide \"target\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"systemId\" is missing.","parameter":"systemId","received":"(missing)","expected":"a value for \"systemId\"","nextStep":"Provide \"systemId\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Attachment.Restore\". Always read the help before calling a message type."}'));
                end;
            'Storage.Upload.Begin':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Upload.Begin","data":{"fileName":"X160-help/example.txt","declaredSize":5},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameter","error":"Parameter \"fileName\" must be a file name without folders or relative segments.","parameter":"fileName","received":"X160-help/example.txt","expected":"a nonempty file name without slash or backslash","nextStep":"Send only the file name, for example INV-001.pdf, without a folder path.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.Begin\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Upload.Begin","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"fileName\" is missing.","parameter":"fileName","received":"(missing)","expected":"a value for \"fileName\"","nextStep":"Provide \"fileName\" and send the request again."},{"code":"InvalidParameter","error":"Parameter \"fileName\" must be a file name without folders or relative segments.","parameter":"fileName","expected":"a nonempty file name without slash or backslash","nextStep":"Send only the file name, for example INV-001.pdf, without a folder path."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.Begin\". Always read the help before calling a message type."}'));
                end;
            'Storage.Upload.Append':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Upload.Append","data":{"uploadId":"not-a-guid","sequence":1,"contentBase64":"SGVsbG8="},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameterFormat","error":"Parameter \"uploadId\" has value \"not-a-guid\", which is not a valid GUID. Expected a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301.","parameter":"uploadId","received":"not-a-guid","expected":"a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301","nextStep":"Send the value as a GUID, as returned by the call that created it.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.Append\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Upload.Append","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"3 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"uploadId\" is missing.","parameter":"uploadId","received":"(missing)","expected":"a value for \"uploadId\"","nextStep":"Provide \"uploadId\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"sequence\" is missing.","parameter":"sequence","received":"(missing)","expected":"a value for \"sequence\"","nextStep":"Provide \"sequence\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"contentBase64\" is missing.","parameter":"contentBase64","received":"(missing)","expected":"a value for \"contentBase64\"","nextStep":"Provide \"contentBase64\" and send the request again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with sub'
                    + 'ject \"Storage.Upload.Append\". Always read the help before calling a message type."}'));
                end;
            'Storage.Upload.Commit':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Upload.Commit","data":{"uploadId":"not-a-guid"},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameterFormat","error":"Parameter \"uploadId\" has value \"not-a-guid\", which is not a valid GUID. Expected a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301.","parameter":"uploadId","received":"not-a-guid","expected":"a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301","nextStep":"Send the value as a GUID, as returned by the call that created it.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.Commit\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Upload.Commit","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MissingParameter","error":"Required parameter \"uploadId\" is missing.","parameter":"uploadId","received":"(missing)","expected":"a value for \"uploadId\"","nextStep":"Provide \"uploadId\" and send the request again.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.Commit\". Always read the help before calling a message type."}'));
                end;
            'Storage.Upload.Abort':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Upload.Abort","data":{"uploadId":"not-a-guid"},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameterFormat","error":"Parameter \"uploadId\" has value \"not-a-guid\", which is not a valid GUID. Expected a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301.","parameter":"uploadId","received":"not-a-guid","expected":"a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301","nextStep":"Send the value as a GUID, as returned by the call that created it.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.Abort\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Upload.Abort","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MissingParameter","error":"Required parameter \"uploadId\" is missing.","parameter":"uploadId","received":"(missing)","expected":"a value for \"uploadId\"","nextStep":"Provide \"uploadId\" and send the request again.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.Abort\". Always read the help before calling a message type."}'));
                end;
            'Storage.Upload.Status':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Storage.Upload.Status","data":{"uploadId":"not-a-guid"},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameterFormat","error":"Parameter \"uploadId\" has value \"not-a-guid\", which is not a valid GUID. Expected a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301.","parameter":"uploadId","received":"not-a-guid","expected":"a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301","nextStep":"Send the value as a GUID, as returned by the call that created it.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.Status\". Always read the help before calling a message type."}'));
            'Storage.Attachment.CreateLinked':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Attachment.CreateLinked","data":{"storageCode":"X160-NOT-CONFIGURED","path":"X160-help/example.txt","fileName":"example.txt"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No storage connection is configured for storageCode \"X160-NOT-CONFIGURED\".","parameter":"storageCode","received":"X160-NOT-CONFIGURED","nextStep":"Call Storage.Account.List to see the configured storage codes.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Attachment.CreateLinked\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Attachment.CreateLinked","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"5 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"storageCode\" is missing.","parameter":"storageCode","received":"(missing)","expected":"a value for \"storageCode\"","nextStep":"Provide \"storageCode\" and send the request again."},{"code":"MissingParameter","error":"Required parameter \"path\" is missing.","parameter":"path","received":"(missing)","expected":"a value for \"path\"","nextStep":"Provide \"path\" and send the request again."},{"code":"InvalidParameter","error":"Parameter \"fileName\" must be a file name without folders or relative segments.","parameter":"path","expected":"a nonempty file name without slash or backslash","nextStep":"Send a path inside the connection, e.g. invoices/2026/INV-001.pdf."},{"code":"MissingParameter","error":"Required parameter \"fi'
                    + 'leName\" is missing.","parameter":"fileName","received":"(missing)","expected":"a value for \"fileName\"","nextStep":"Provide \"fileName\" and send the request again."},{"code":"InvalidParameter","error":"Parameter \"fileName\" must be a file name without folders or relative segments.","parameter":"fileName","expected":"a nonempty file name without slash or backslash","nextStep":"Send only the file name, for example INV-001.pdf, without a folder path."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Attachment.CreateLinked\". Always read the help before calling a message type."}'));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Attachment.CreateForRecord","data":{"target":"IncomingDocument","fileName":"example.txt","contentBase64":"not-base64!"},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Send tableId or tableName to say which table the record is in.","parameter":"tableId","expected":"tableId or tableName"},{"code":"InvalidParameterFormat","error":"Parameter \"contentBase64\" is not valid base64 content.","parameter":"contentBase64","expected":"base64 content","nextStep":"Encode the file bytes as standard base64 and send them again."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Attachment.CreateForRecord\". Always read the help before calling a message type.","warnings":[{"code":"UnknownParameter","message":"Parameter \"target\" is not declared by this message type and may be ignored.","parameter":"target","nextStep":"Remove this key or consult Help.Implementation.Get for '
                    + 'the declared parameters."}]}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Attachment.CreateForRecord","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Send tableId or tableName to say which table the record is in.","parameter":"tableId","expected":"tableId or tableName"},{"code":"InvalidParameter","error":"Send exactly one content source: contentBase64 (or the alias content), storageCode with path, or sourceTarget with sourceSystemId.","parameter":"contentBase64, storageCode, sourceSystemId","expected":"exactly one of contentBase64 (or the alias content), storageCode with path, sourceTarget with sourceSystemId"}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Attachment.CreateForRecord\". Always read the help before calling a message type."}'));
                end;
            'Storage.Upload.CommitToRecord':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Upload.CommitToRecord","data":{"uploadId":"not-a-guid","target":"IncomingDocument"},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameterFormat","error":"Parameter \"uploadId\" has value \"not-a-guid\", which is not a valid GUID. Expected a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301.","parameter":"uploadId","received":"not-a-guid","expected":"a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301","nextStep":"Send the value as a GUID, as returned by the call that created it.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.CommitToRecord\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Upload.CommitToRecord","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MissingParameter","error":"Required parameter \"uploadId\" is missing.","parameter":"uploadId","received":"(missing)","expected":"a value for \"uploadId\"","nextStep":"Provide \"uploadId\" and send the request again.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.CommitToRecord\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.Definition.Delete':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.Definition.Delete","data":{"code":"X160-MISSING"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"Data Exchange definition X160-MISSING was not found.","parameter":"code","received":"X160-MISSING","expected":"an existing Data Exchange definition","nextStep":"Call DataExchange.Definition.List and use the exact definition code.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Definition.Delete\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.Definition.Delete","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MissingParameter","error":"Parameter \"code\" is required.","parameter":"code","received":"not supplied","expected":"a JSON string of at most 20 characters","nextStep":"Send \"code\" as a JSON string of at most 20 characters and retry.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Definition.Delete\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.Definition.Export':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.Definition.Export","data":{"code":"X160-MISSING","inline":true},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No Data Exch. Def exists for code ''X160-MISSING''.","parameter":"code","received":"X160-MISSING","expected":"Use a code returned by DataExchange.Definition.List.","nextStep":"Use a code returned by DataExchange.Definition.List.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Definition.Export\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.Definition.Export","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MissingParameter","error":"Missing required ''code'' in the request.","parameter":"code","received":"(missing)","expected":"a JSON string","nextStep":"Provide \"code\" and send the request again.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Definition.Export\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.Export.Run':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.Export.Run","data":{"dataExchDefCode":"X160-MISSING","tableId":18,"inline":true},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"Data Exchange definition X160-MISSING was not found.","parameter":"dataExchDefCode","received":"X160-MISSING","expected":"an existing Generic Export definition","nextStep":"Call DataExchange.Definition.List with direction Export and use the exact code of a Generic Export definition.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Export.Run\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.Export.Run","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"3 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Parameter \"dataExchDefCode\" is required.","parameter":"dataExchDefCode","received":"not supplied","expected":"a JSON string of at most 20 characters","nextStep":"Send \"dataExchDefCode\" as a JSON string of at most 20 characters and retry."},{"code":"MissingParameter","error":"Name the records to export with tableId or tableName (and an optional tableView), or with recordIds.","parameter":"tableId","received":"(missing)","expected":"tableId or tableName, or recordIds","nextStep":"Send tableId 18 with tableView WHERE(No.=FILTER(10000..30000)), for example, or a recordIds array of SystemIds."},{"code":"MissingParameter","error":"Choose where the file goes: storageCode with path or folderPath, or inline true.","parameter":"storageCode","received'
                    + '":"(missing)","expected":"storageCode, or inline true","nextStep":"Send storageCode (find it with Storage.Account.List), or inline true for a file of at most 1 MB."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Export.Run\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.Import.Run':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.Import.Run","data":{"dataExchDefCode":"X160-MISSING","contentBase64":"SGVsbG8="},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"Data Exchange definition X160-MISSING was not found.","parameter":"dataExchDefCode","received":"X160-MISSING","expected":"an existing Generic Import or Payroll Import definition","nextStep":"Call DataExchange.Definition.List with direction Import and use the exact code of a Generic Import or Payroll Import definition.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Import.Run\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.Import.Run","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Parameter \"dataExchDefCode\" is required.","parameter":"dataExchDefCode","received":"not supplied","expected":"a JSON string of at most 20 characters","nextStep":"Send \"dataExchDefCode\" as a JSON string of at most 20 characters and retry."},{"code":"MissingParameter","error":"Send contentBase64 or storageCode with path to select the file to import.","parameter":"contentBase64","received":"(missing)","expected":"exactly one source: contentBase64, or storageCode with path","nextStep":"Send contentBase64 or storageCode with path to select the file to import."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Import.Run\". Always read the help before calling a message type."}'));
                end;
            'Help.DataExchange.Get':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"Help.DataExchange.Get","data":{},"lcid":1033}',
                        '{"status":"Success","data":{"format":"markdown","markdown":"# Bifrost Attachments - Data Exchange message types\r\n\r\nRun the Business Central Data Exchange Framework (Data Exch. Def, Data Exchange Type and Data Exch. entries) without the user interface: install definitions, import files into parsed entries, apply the mappings, and export records or payment journals to files in storage.\r\n\r\n## Pipeline\r\n\r\n1. **Install or discover** a definition: `DataExchange.Definition.Import` installs the standard definition XML (`storageCode` + `path`, `contentBase64` up to 1 MB, or a chunked `uploadId`; `overwrite`, `newCode`). `DataExchange.Definition.List` and `DataExchange.Definition.Get` show what exists; `DataExchange.Definition.Export` returns the header by default; `inline: true` adds the XML, and `storageCode` + `path`/`folderPath` writes the XML to storage. Both XML destinations may '
                    + 'be requested. Storage writes refuse an existing file by default; overwrite: true explicitly allows replacement. Linked attachment files remain protected. External writes cannot be rolled back.\r\n2. **Import** a file with a Generic Import or Payroll Import definition: `DataExchange.Import.Run` (`storageCode` + `path` of a stored file, which stays unchanged, or `contentBase64` up to 1 MB) or, for a large file, `Storage.Upload.Begin` -> `Storage.Upload.Append` -> `Storage.Upload.CommitToDataExchange` (`uploadId`, `dataExchDefCode`, optional `keepFileInStorage`). Both create a Data Exch. entry, run the definition reader and return `entryNo`, `lineCount` and `fieldCount`. A file the reader cannot read is refused and leaves no entry.\r\n3. **Inspect** the parsed fields: `DataExchange.Entry.Get` (`entryNo`, paged `fields`), `DataExchange.Entry.List` for older entries.\r\n4. **Process** the entry: `DataExchange.Entry.Process` runs the definition mappings and returns `targets[]` (table, inserted and modified '
                    + 'counts, record SystemIds). Or send `process: true` on the import to do both in one call; the import is then committed first, and a processing error is returned in `processResult.errors` while the entry stays.\r\n5. **Export**: `DataExchange.Export.Run` runs a Generic Export definition over `tableId`/`tableName` with `tableView`, or over `recordIds`, and delivers the file to storage (`storageCode` + `path` or `folderPath`) and/or `inline` (up to 1 MB). `DataExchange.PaymentExport.Run` exports a payment journal batch (`journalTemplate`, `journalBatch`) with the payment export format of its bank account, marks the lines as exported and delivers the bank file.\r\n6. **Clean up**: `DataExchange.Entry.Delete` deletes an entry and its fields. Entries created by these types are also removed by the retention policy on Bifrost Data Exchange Entry (30 days by default).\r\n\r\nIncoming documents are'
                    + ' the other import path: wire a Generic Import definition that maps to the intermediate table with `DataExchange.Type.Set`, then send the file with `Storage.Upload.CommitToRecord` or `Storage.Attachment.CreateLinked` (`target` IncomingDocument, `dataExchangeType`, `process`). `DataExchange.Entry.Process` refuses intermediate-table mappings and points there. Bank statements are imported with `Finance.BankReconciliation.Create`.\r\n\r\n## Which type do I need?\r\n\r\n| I want to | Message type |\r\n|---|---|\r\n| Find a definition code | `DataExchange.Definition.List` |\r\n| See how a definition maps columns to fields | `DataExchange.Definition.Get` |\r\n| Install a definition from its XML | `DataExchange.Definition.Import` |\r\n| Get a definition as XML, or only its header | `DataExchange.Definition.Export` |\r\n| Remove a definition nothing uses | `DataExchange.Definition.Delete` |\r\n| S'
                    + 'ee which Data Exchange Types exist | `DataExchange.Type.List` |\r\n| Bind a Data Exchange Type to an import definition | `DataExchange.Type.Set` |\r\n| Import a stored file or small inline content | `DataExchange.Import.Run` |\r\n| Import a large file sent in chunks | `Storage.Upload.CommitToDataExchange` |\r\n| Write the parsed lines to the business tables | `DataExchange.Entry.Process` |\r\n| Export records to a file | `DataExchange.Export.Run` |\r\n| Create the bank payment file of a payment journal | `DataExchange.PaymentExport.Run` |\r\n| List, read or delete entries | `DataExchange.Entry.List`, `DataExchange.Entry.Get`, `DataExchange.Entry.Delete` |\r\n\r\n## Chaining\r\n\r\nEvery code a list returns is the exact value the next call expects: `code` from `DataExchange.Definition.List` or `codes[]` from `DataExchange.Definition.Import` goes into `code` of `DataExchange.Definition.Get'
                    + '`, `DataExchange.Definition.Export` and `DataExchange.Definition.Delete`, and into `dataExchDefCode` of `DataExchange.Type.Set`, `DataExchange.Import.Run`, `Storage.Upload.CommitToDataExchange`, `DataExchange.Export.Run` and `DataExchange.Entry.List`. `entryNo` from an import, an export or `DataExchange.Entry.List` goes into `DataExchange.Entry.Get`, `DataExchange.Entry.Process` and `DataExchange.Entry.Delete`. `storageCode` and `path` of an export go into `Storage.File.Get`. Codes are never trimmed, upper-cased or shortened; send them exactly as returned.\r\n\r\n## Errors\r\n\r\nA refused call answers `status = Error` with `code`, `parameter`, `received`, `expected` and `nextStep` for every problem found. A failure after a write (a reader or mapping error, a file over 1 MB with `inline`, a failed storage write) rolls the call back. Read `Help.Implementation.Get` (subject = the message t'
                    + 'ype) for the full contract of one type.\r\n\r\n## Permissions\r\n\r\nAssign `BIFROST DataExch ori` with the Foundation API baseline. This role grants table read access, including the definition read by `DataExchange.Definition.Export`; it does not grant table writes. Definition.Export is registered Inbound because its optional storage output writes an external file; the storage connector also requires its own permissions.\r\nThe write types additionally require the standard Business Central permissions of the tables they write: Data Exch. and Data Exch. Field for imports and exports, the definition tables for `DataExchange.Definition.Import` and `DataExchange.Definition.Delete`, the target tables of the mappings for processing, and Gen. Journal Line and Credit Transfer Register for payment exports. Types with `storageCode` also use the storage connection. `BIFROST Attach ori` does not gr'
                    + 'ant these Data Exchange table permissions.\r\n"}}'));
            'DataExchange.Definition.List':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"DataExchange.Definition.List","data":{},"lcid":1033}',
                        '{"status":"Success","data":{"count":13,"definitions":[{"code":"ECB-EXCHANGE-RATES","name":"European Central Bank Currency Exchange Rates","type":"Generic Import","fileType":"Xml","readingWritingCodeunit":"Import XML File to Data Exch.","readingWritingXmlPort":"","extDataHandlingCodeunit":"","lineDefCount":1,"mappingCount":1,"usedByDataExchangeTypes":["ECB-EXCHANGE-RATES"]},{"code":"EDOCPEPPOLCRMEMOIMP","name":"e-Doc PEPPOL - Credit Memo Import","type":"Generic Import","fileType":"Xml","readingWritingCodeunit":"Import XML File to Data Exch.","readingWritingXmlPort":"","extDataHandlingCodeunit":"","lineDefCount":3,"mappingCount":3,"usedByDataExchangeTypes":[]},{"code":"EDOCPEPPOLINVIMP","name":"e-Doc PEPPOL - Invoice Import","type":"Generic Import","fileType":"Xml","readingWritingCodeunit":"Import XML File to Data Exch.","readingWritingXmlPort":"","extDataHandlingCodeunit":"","lineDefCount'
                    + '":3,"mappingCount":3,"usedByDataExchangeTypes":[]},{"code":"EDOCPEPPOLSALCRMEXP","name":"e-Doc PEPPOL - Sales Credit Memo Export","type":"Generic Export","fileType":"Xml","readingWritingCodeunit":"Export Generic XML","readingWritingXmlPort":"","extDataHandlingCodeunit":"E-Doc. DED PEPPOL External","lineDefCount":18,"mappingCount":18,"usedByDataExchangeTypes":[]},{"code":"EDOCPEPPOLSALINVEXP","name":"e-Doc PEPPOL - Sales Invoice Export","type":"Generic Export","fileType":"Xml","readingWritingCodeunit":"Export Generic XML","readingWritingXmlPort":"","extDataHandlingCodeunit":"E-Doc. DED PEPPOL External","lineDefCount":17,"mappingCount":17,"usedByDataExchangeTypes":[]},{"code":"EDOCPEPPOLSRVCRMEXP","name":"e-Doc PEPPOL - Service Credit Memo Export","type":"Generic Export","fileType":"Xml","readingWritingCodeunit":"Export Generic XML","readingWritingXmlPort":"","extDataHandlingCodeunit":"E-D'
                    + 'oc. DED PEPPOL External","lineDefCount":18,"mappingCount":18,"usedByDataExchangeTypes":[]},{"code":"EDOCPEPPOLSRVINVEXP","name":"e-Doc PEPPOL - Service Invoice Export","type":"Generic Export","fileType":"Xml","readingWritingCodeunit":"Export Generic XML","readingWritingXmlPort":"","extDataHandlingCodeunit":"E-Doc. DED PEPPOL External","lineDefCount":17,"mappingCount":17,"usedByDataExchangeTypes":[]},{"code":"OCRCREDITMEMO","name":"OCR - Credit Memo","type":"Generic Import","fileType":"Xml","readingWritingCodeunit":"Import XML File to Data Exch.","readingWritingXmlPort":"","extDataHandlingCodeunit":"","lineDefCount":1,"mappingCount":1,"usedByDataExchangeTypes":["OCRCREDITMEMO"]},{"code":"OCRINVOICE","name":"OCR - Invoice","type":"Generic Import","fileType":"Xml","readingWritingCodeunit":"Import XML File to Data Exch.","readingWritingXmlPort":"","extDataHandlingCodeunit":"","lineDefCount":'
                    + '2,"mappingCount":2,"usedByDataExchangeTypes":["OCRINVOICE"]},{"code":"PEPPOLCREDITMEMO","name":"PEPPOL - Credit Memo","type":"Generic Import","fileType":"Xml","readingWritingCodeunit":"Import XML File to Data Exch.","readingWritingXmlPort":"","extDataHandlingCodeunit":"","lineDefCount":2,"mappingCount":2,"usedByDataExchangeTypes":["PEPPOLCREDITMEMO"]},{"code":"PEPPOLINVOICE","name":"PEPPOL - Invoice","type":"Generic Import","fileType":"Xml","readingWritingCodeunit":"Import XML File to Data Exch.","readingWritingXmlPort":"","extDataHandlingCodeunit":"","lineDefCount":2,"mappingCount":2,"usedByDataExchangeTypes":["PEPPOLINVOICE"]},{"code":"SEPA CAMT","name":"SEPA CAMT","type":"Bank Statement Import","fileType":"Xml","readingWritingCodeunit":"Import Bank Statement","readingWritingXmlPort":"","extDataHandlingCodeunit":"Read Data Exch. from File","lineDefCount":1,"mappingCount":2,"usedByDataE'
                    + 'xchangeTypes":["SEPA CAMT"]},{"code":"SEPA CAMT 053-08","name":"SEPA CAMT 053.001.08","type":"Bank Statement Import","fileType":"Xml","readingWritingCodeunit":"Import Bank Statement","readingWritingXmlPort":"","extDataHandlingCodeunit":"Read Data Exch. from File","lineDefCount":1,"mappingCount":2,"usedByDataExchangeTypes":["SEPA CAMT 053-08"]}]}}'));
            'DataExchange.Definition.Get':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"DataExchange.Definition.Get","data":{"code":"X160-MISSING"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"No Data Exch. Def exists for code ''X160-MISSING''.","parameter":"code","received":"X160-MISSING","expected":"Use a code returned by DataExchange.Definition.List.","nextStep":"Use a code returned by DataExchange.Definition.List.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Definition.Get\". Always read the help before calling a message type."}'));
            'DataExchange.Type.List':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"DataExchange.Type.List","data":{},"lcid":1033}',
                        '{"status":"Success","data":{"count":7,"types":[{"code":"ECB-EXCHANGE-RATES","description":"European Central Bank Currency Exchange Rates","dataExchDefCode":"ECB-EXCHANGE-RATES","userFeedbackCodeunit":"","validationCodeunit":"","dataHandlingCodeunit":"","type":"Generic Import"},{"code":"OCRCREDITMEMO","description":"OCR - Credit Memo","dataExchDefCode":"OCRCREDITMEMO","userFeedbackCodeunit":"","validationCodeunit":"","dataHandlingCodeunit":"Map DataExch To Intermediate","type":"Generic Import"},{"code":"OCRINVOICE","description":"OCR - Invoice","dataExchDefCode":"OCRINVOICE","userFeedbackCodeunit":"","validationCodeunit":"","dataHandlingCodeunit":"Map DataExch To Intermediate","type":"Generic Import"},{"code":"PEPPOLCREDITMEMO","description":"PEPPOL - Credit Memo","dataExchDefCode":"PEPPOLCREDITMEMO","userFeedbackCodeunit":"","validationCodeunit":"","dataHandlingCodeunit":"Map DataExch To'
                    + ' Intermediate","type":"Generic Import"},{"code":"PEPPOLINVOICE","description":"PEPPOL - Invoice","dataExchDefCode":"PEPPOLINVOICE","userFeedbackCodeunit":"","validationCodeunit":"","dataHandlingCodeunit":"Map DataExch To Intermediate","type":"Generic Import"},{"code":"SEPA CAMT","description":"SEPA CAMT","dataExchDefCode":"SEPA CAMT","userFeedbackCodeunit":"","validationCodeunit":"","dataHandlingCodeunit":"","type":"Bank Statement Import"},{"code":"SEPA CAMT 053-08","description":"SEPA CAMT 053.001.08","dataExchDefCode":"SEPA CAMT 053-08","userFeedbackCodeunit":"","validationCodeunit":"","dataHandlingCodeunit":"","type":"Bank Statement Import"}]}}'));
            'DataExchange.Entry.List':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"DataExchange.Entry.List","data":{"dataExchDefCode":"X160-MISSING","take":1},"lcid":1033}',
                        '{"status":"Success","data":{"count":0,"skip":0,"take":1,"entries":[]}}'));
            'DataExchange.Entry.Get':
                Examples.Add(ContractMgt.Example('Inspect the response with no configured prerequisites',
                        '{"type":"DataExchange.Entry.Get","data":{"entryNo":-1},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameter","error":"''entryNo'' must be an integer.","parameter":"entryNo","received":"-1","expected":"an integer greater than 0","nextStep":"Send \"entryNo\" as an integer within the allowed range.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Entry.Get\". Always read the help before calling a message type."}'));
            'Storage.Upload.CommitToDataExchange':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"Storage.Upload.CommitToDataExchange","data":{"uploadId":"not-a-guid","dataExchDefCode":"X160-MISSING"},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameterFormat","error":"Parameter \"uploadId\" has value \"not-a-guid\", which is not a valid GUID. Expected a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301.","parameter":"uploadId","received":"not-a-guid","expected":"a GUID, e.g. 3f2504e0-4f89-11d3-9a0c-0305e82c3301","nextStep":"Send the value as a GUID, as returned by the call that created it.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.CommitToDataExchange\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"Storage.Upload.CommitToDataExchange","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Required parameter \"uploadId\" is missing.","parameter":"uploadId","received":"(missing)","expected":"a value for \"uploadId\"","nextStep":"Provide \"uploadId\" and send the request again."},{"code":"MissingParameter","error":"Parameter \"dataExchDefCode\" is required.","parameter":"dataExchDefCode","received":"not supplied","expected":"a JSON string of at most 20 characters","nextStep":"Send \"dataExchDefCode\" as a JSON string of at most 20 characters and retry."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"Storage.Upload.CommitToDataExchange\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.Entry.Process':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.Entry.Process","data":{"entryNo":-1},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameter","error":"Parameter \"entryNo\" must be greater than 0.","parameter":"entryNo","received":"-1","expected":"an existing entry number","nextStep":"Use an entryNo returned by DataExchange.Import.Run or DataExchange.Entry.List.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Entry.Process\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.Entry.Process","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MissingParameter","error":"Required parameter \"entryNo\" is missing.","parameter":"entryNo","received":"(missing)","expected":"a value for \"entryNo\"","nextStep":"Provide \"entryNo\" and send the request again.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Entry.Process\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.Entry.Delete':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.Entry.Delete","data":{"entryNo":-1},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameter","error":"Parameter \"entryNo\" must be greater than 0.","parameter":"entryNo","received":"-1","expected":"an existing entry number","nextStep":"Use an entryNo returned by DataExchange.Entry.List.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Entry.Delete\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.Entry.Delete","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MissingParameter","error":"Required parameter \"entryNo\" is missing.","parameter":"entryNo","received":"(missing)","expected":"a value for \"entryNo\"","nextStep":"Provide \"entryNo\" and send the request again.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Entry.Delete\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.Definition.Import':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.Definition.Import","data":{"contentBase64":"not-base64!"},"lcid":1033}',
                        '{"status":"Error","code":"InvalidParameterFormat","error":"Parameter \"contentBase64\" is not valid base64 content.","parameter":"contentBase64","expected":"base64 content","nextStep":"Encode the file bytes as standard base64 and send them again.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Definition.Import\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.Definition.Import","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Parameter \"storageCode\" is required.","parameter":"storageCode","received":"not supplied","expected":"a JSON string of at most 20 characters","nextStep":"Send \"storageCode\" as a JSON string of at most 20 characters and retry."},{"code":"MissingParameter","error":"Parameter \"path\" is required.","parameter":"path","received":"not supplied","expected":"a JSON string of at most 2048 characters","nextStep":"Send \"path\" as a JSON string of at most 2048 characters and retry."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Definition.Import\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.PaymentExport.Run':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.PaymentExport.Run","data":{"journalTemplate":"X160-MISSING","journalBatch":"X160-MISSING","inline":true},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"InvalidParameterFormat","error":"Parameter \"journalTemplate\" exceeds the maximum of 10 characters.","parameter":"journalTemplate","received":"X160-MISSING","expected":"a JSON string of at most 10 characters","nextStep":"Send \"journalTemplate\" as a JSON string of at most 10 characters and retry."},{"code":"InvalidParameterFormat","error":"Parameter \"journalBatch\" exceeds the maximum of 10 characters.","parameter":"journalBatch","received":"X160-MISSING","expected":"a JSON string of at most 10 characters","nextStep":"Send \"journalBatch\" as a JSON string of at most 10 characters and retry."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.PaymentExport.Run\". Always read the help before calling a message type'
                    + '."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.PaymentExport.Run","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"3 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Parameter \"journalTemplate\" is required.","parameter":"journalTemplate","received":"not supplied","expected":"a JSON string of at most 10 characters","nextStep":"Send \"journalTemplate\" as a JSON string of at most 10 characters and retry."},{"code":"MissingParameter","error":"Parameter \"journalBatch\" is required.","parameter":"journalBatch","received":"not supplied","expected":"a JSON string of at most 10 characters","nextStep":"Send \"journalBatch\" as a JSON string of at most 10 characters and retry."},{"code":"MissingParameter","error":"Choose where the file goes: storageCode with path or folderPath, or inline true.","parameter":"storageCode","received":"(missing)","expected":"storageCode, or inline true","nextStep":"Send storageCode (f'
                    + 'ind it with Storage.Account.List), or inline true for a file of at most 1 MB."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.PaymentExport.Run\". Always read the help before calling a message type."}'));
                end;
            'DataExchange.Type.Set':
                begin
                    Examples.Add(ContractMgt.Example('A request refused before any change',
                        '{"type":"DataExchange.Type.Set","data":{"code":"X160-TYPE","dataExchDefCode":"X160-MISSING"},"lcid":1033}',
                        '{"status":"Error","code":"RecordNotFound","error":"Data Exchange definition X160-MISSING was not found.","parameter":"dataExchDefCode","received":"X160-MISSING","expected":"an existing Generic Import definition","nextStep":"Call DataExchange.Definition.List and select a definition of an accepted kind using its exact code.","hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Type.Set\". Always read the help before calling a message type."}'));
                    Examples.Add(ContractMgt.Example('Refusal: required request data is missing',
                        '{"type":"DataExchange.Type.Set","data":{},"lcid":1033}',
                        '{"status":"Error","code":"MultipleErrors","error":"2 problems in the request. Nothing was changed.","errors":[{"code":"MissingParameter","error":"Parameter \"code\" is required.","parameter":"code","received":"not supplied","expected":"a JSON string of at most 20 characters","nextStep":"Send \"code\" as a JSON string of at most 20 characters and retry."},{"code":"MissingParameter","error":"Parameter \"dataExchDefCode\" is required.","parameter":"dataExchDefCode","received":"not supplied","expected":"a JSON string of at most 20 characters","nextStep":"Send \"dataExchDefCode\" as a JSON string of at most 20 characters and retry."}],"hint":"For usage details, call the \"Help.Implementation.Get\" message type with subject \"DataExchange.Type.Set\". Always read the help before calling a message type."}'));
                end;
        end;
    end;

    /// <summary>Builds the English overview for a storage or Data Exchange message type.</summary>
    /// <param name="MessageType">The public message type name.</param>
    /// <returns>The overview chapter; empty for an unknown type.</returns>
    procedure GetOverview(MessageType: Text): Text
    begin
        case MessageType of
            'Storage.Account.List':
                exit('Lists configured storage connections with their codes, descriptions, connectors, base paths and enabled status. Choose an enabled connection code for storageCode; no connector credentials are returned.');
            'Storage.File.List':
                exit('Lists files below a directory relative to the selected connection. Use the returned relative paths with Storage.File.Get; this call does not download file content.');
            'Storage.File.Get':
                exit('Downloads one file from the selected connection and returns its content as base64. The path is relative to the connection; the file stays in storage.');
            'Storage.File.Create':
                exit('Decodes contentBase64 and writes a file to the selected connection at a relative path. This external write is outside the Business Central transaction.');
            'Storage.File.Delete':
                exit('Deletes one file at a relative path in the selected connection. The external deletion cannot be rolled back with the Business Central transaction.');
            'Storage.File.Copy':
                exit('Copies a file between two relative paths in the selected connection. The source remains available; the external write is outside the Business Central transaction.');
            'Storage.File.Move':
                exit('Moves a file between two relative paths in the selected connection. The external change cannot be rolled back with the Business Central transaction.');
            'Storage.File.Exists':
                exit('Checks whether a file exists at a relative path in the selected connection. It returns the existence result without downloading or changing the file.');
            'Storage.Directory.List':
                exit('Lists directories below a relative path in the selected connection. It does not list file content or change the storage.');
            'Storage.Directory.Create':
                exit('Creates a directory at a relative path in the selected connection. The external write is outside the Business Central transaction.');
            'Storage.Directory.Delete':
                exit('Deletes a directory at a relative path in the selected connection. The external deletion cannot be rolled back with the Business Central transaction.');
            'Storage.Directory.Exists':
                exit('Checks whether a directory exists at a relative path in the selected connection. It does not create the directory.');
            'Storage.Attachment.Offload':
                exit('Moves the content of an existing IncomingDocument or DocumentAttachment into storage and keeps a link so Business Central can still open it. The external file write is outside the Business Central transaction.');
            'Storage.Attachment.Restore':
                exit('Restores an offloaded IncomingDocument or DocumentAttachment to Business Central and deletes its stored file. The external deletion cannot be rolled back with the Business Central transaction.');
            'Storage.Upload.Begin':
                exit('Opens a chunked upload and returns its uploadId. Append numbered base64 chunks, then choose Commit, CommitToRecord or CommitToDataExchange; use Abort to discard an open session.');
            'Storage.Upload.Append':
                exit('Stores one numbered base64 chunk in an open upload session. Repeating the same sequence number replaces that chunk; use Storage.Upload.Status to inspect progress.');
            'Storage.Upload.Commit':
                exit('Assembles the chunks of an upload session and writes the file to its storage connection. The external write is outside the Business Central transaction; use CommitToRecord for a record-only upload.');
            'Storage.Upload.Abort':
                exit('Discards an open upload session and its chunks without writing a file to external storage. Use this to cancel an upload that will not be committed.');
            'Storage.Upload.Status':
                exit('Returns the state, declared size and received chunks of an upload session. It does not append content or commit the upload.');
            'Storage.Attachment.CreateLinked':
                exit('Links a file already in storage to a new or existing Incoming Document. It uses the storage connection and relative path instead of uploading another copy.');
            'Storage.Attachment.CreateForRecord':
                exit('Creates an IncomingDocument or DocumentAttachment from inline base64, a stored file or another attachment. Choose exactly one source and identify the destination record as described in target and parameters.');
            'Storage.Upload.CommitToRecord':
                exit('Assembles an upload session and creates an IncomingDocument or DocumentAttachment. No external storage is required unless keepFile is requested.');
            'DataExchange.Definition.List':
                exit('Lists Data Exchange definitions available to the caller, including their codes and types. Select a compatible code before importing or exporting data.');
            'DataExchange.Definition.Get':
                exit('Returns the structure of one Data Exchange definition, including its line, column and mapping metadata. It does not run the definition or import a file.');
            'DataExchange.Type.List':
                exit('Lists Data Exchange Types and their linked import and export definitions. Use the returned codes to choose or configure the definition used by a workflow.');
            'DataExchange.Entry.List':
                exit('Lists Data Exchange entries visible to the caller. Use an entry number with Entry.Get to inspect it or Entry.Process to run its mappings.');
            'DataExchange.Entry.Get':
                exit('Returns one Data Exchange entry and its parsed data. File content is included only when requested and within the inline limit; no mappings are run.');
        end;
        exit('');
    end;

    /// <summary>Builds the envelope shared by storage requests.</summary>
    procedure GetEnvelope(DataRequired: Boolean) Envelope: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The storage message is identified by its message type; it has no subject record.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', DataRequired);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Builds the envelope shared by Data Exchange requests.</summary>
    /// <param name="DataRequired">Whether the request must carry data.</param>
    /// <returns>The envelope chapter.</returns>
    procedure GetDataExchangeEnvelope(DataRequired: Boolean) Envelope: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The Data Exchange message is identified by its message type; it has no subject record.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', DataRequired);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Tells whether a message type belongs to the Data Exchange family, including its help type.</summary>
    /// <param name="MessageType">The message type name.</param>
    /// <returns>True for DataExchange.* and Help.DataExchange.Get.</returns>
    procedure IsDataExchangeType(MessageType: Text): Boolean
    begin
        exit(MessageType.StartsWith('DataExchange.') or (MessageType = 'Help.DataExchange.Get'));
    end;

    /// <summary>Builds the request parameters read by one message type.</summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Storage.Account.List', 'Help.Storage.Get', 'Help.DataExchange.Get', 'DataExchange.Type.List'] then
            exit;

        if MessageType in ['Storage.File.Create', 'Storage.Attachment.Offload', 'Storage.Upload.Commit',
            'DataExchange.Definition.Export', 'DataExchange.Export.Run', 'DataExchange.PaymentExport.Run', 'Storage.Upload.CommitToDataExchange'] then
            Parameters.Add(ContractMgt.Parameter('overwrite', 'boolean', false, StorageOverwriteLbl));
        if not (MessageType in ['Storage.Attachment.Restore', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status', 'DataExchange.Definition.Get', 'DataExchange.Entry.Get', 'DataExchange.Definition.List', 'DataExchange.Entry.List', 'DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Definition.Export', 'DataExchange.Import.Run', 'DataExchange.Export.Run', 'Storage.Upload.Begin', 'Storage.Upload.CommitToRecord',
            'Storage.Upload.CommitToDataExchange', 'DataExchange.Entry.Process', 'DataExchange.Entry.Delete', 'DataExchange.Definition.Import', 'DataExchange.PaymentExport.Run']) then
            Parameters.Add(ContractMgt.Parameter('storageCode', 'string', true, 'The configured storage connection code. Resolve it with Storage.Account.List.'));
        case MessageType of
            'Storage.File.List', 'Storage.Directory.List':
                Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The directory path relative to the connection base path.'));
            'Storage.File.Get', 'Storage.File.Delete', 'Storage.File.Exists', 'Storage.Directory.Create', 'Storage.Directory.Delete', 'Storage.Directory.Exists':
                Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The file or directory path relative to the connection base path.'));
            'Storage.File.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The destination file path relative to the connection base path.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, 'The complete file content encoded as base64.'));
                end;
            'Storage.File.Copy', 'Storage.File.Move':
                begin
                    Parameters.Add(ContractMgt.Parameter('sourcePath', 'string', true, 'The source file path relative to the connection base path.'));
                    Parameters.Add(ContractMgt.Parameter('targetPath', 'string', true, 'The destination file path relative to the connection base path.'));
                end;
            'Storage.Attachment.Offload':
                begin
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, 'The attachment table: IncomingDocument or DocumentAttachment.'));
                    Parameters.Add(ContractMgt.Parameter('systemId', 'string', true, 'The attachment SystemId.'));
                    Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, 'Optional destination folder.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, 'The attachment table: IncomingDocument or DocumentAttachment.'));
                    Parameters.Add(ContractMgt.Parameter('systemId', 'string', true, 'The attachment SystemId.'));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, 'The file path in storage.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, 'The attachment file name.'));
                    Parameters.Add(ContractMgt.Parameter('incomingDocumentEntryNo', 'integer', false, 'An existing incoming document entry number.'));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'Description for a new incoming document.'));
                    Parameters.Add(ContractMgt.Parameter('dataExchangeType', 'string', false, DataExchangeTypeParamLbl));
                    Parameters.Add(ContractMgt.Parameter('process', 'boolean', false, ProcessParamLbl));
                    Parameters.Add(ContractMgt.Parameter('vendorNo', 'string', false, VendorNoParamLbl));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, AttachmentStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('sourceTarget', 'string', false, SourceTargetLbl));
                    Parameters.Add(ContractMgt.Parameter('sourceSystemId', 'string', false, SourceSystemIdLbl));
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, 'The host record table id.'));
                    Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, 'The host record table name.'));
                    Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'The host record SystemId.'));
                    Parameters.Add(ContractMgt.Parameter('no', 'string', false, 'The host record primary key.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, 'The attachment file name.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', false, 'Inline file content encoded as base64.'));
                    Parameters.Add(ContractMgt.Parameter('content', 'string', false, 'Accepted alias of contentBase64. Do not send both.'));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The source file path in storage.'));
                end;
            'Storage.Upload.Begin':
                begin
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, UploadStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, 'The leaf file name.'));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, 'The full destination path.'));
                    Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, 'The destination folder.'));
                    Parameters.Add(ContractMgt.Parameter('declaredSize', 'integer', false, 'The expected total size in bytes.'));
                end;
            'Storage.Upload.Append':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
                    Parameters.Add(ContractMgt.Parameter('sequence', 'integer', true, 'The one-based chunk sequence.'));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, 'The chunk content encoded as base64.'));
                end;
            'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status':
                Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
            'Storage.Upload.CommitToRecord':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
                    Parameters.Add(ContractMgt.Parameter('target', 'string', false, 'DocumentAttachment or IncomingDocument.'));
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, UploadTableIdLbl));
                    Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, UploadTableNameLbl));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, IncomingDescriptionLbl));
                    Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, UploadRecordIdLbl));
                    Parameters.Add(ContractMgt.Parameter('no', 'string', false, 'The host record primary key.'));
                    Parameters.Add(ContractMgt.Parameter('incomingDocumentEntryNo', 'integer', false, 'An existing incoming document entry number.'));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, 'An optional replacement file name.'));
                    Parameters.Add(ContractMgt.Parameter('dataExchangeType', 'string', false, DataExchangeTypeParamLbl));
                    Parameters.Add(ContractMgt.Parameter('process', 'boolean', false, ProcessParamLbl));
                    Parameters.Add(ContractMgt.Parameter('vendorNo', 'string', false, VendorNoParamLbl));
                end;
            'DataExchange.Definition.List':
                begin
                    Parameters.Add(ContractMgt.Parameter('type', 'string', false, 'Optional definition type filter.'));
                    Parameters.Add(ContractMgt.Parameter('direction', 'string', false, 'Import or Export.'));
                end;
            'DataExchange.Definition.Get', 'DataExchange.Definition.Delete':
                Parameters.Add(ContractMgt.Parameter('code', 'string', true, DefinitionCodeLbl));
            'DataExchange.Definition.Export':
                begin
                    Parameters.Add(ContractMgt.Parameter('code', 'string', true, DefinitionCodeLbl));
                    AddDeliveryParameters(Parameters, MessageType = 'DataExchange.Definition.Export');
                end;
            'Storage.Upload.CommitToDataExchange':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, 'The upload session id.'));
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', true, ImportDefinitionLbl));
                    Parameters.Add(ContractMgt.Parameter('process', 'boolean', false, ProcessImportLbl));
                    Parameters.Add(ContractMgt.Parameter('keepFileInStorage', 'boolean', false, KeepFileLbl));
                end;
            'DataExchange.Entry.Process':
                begin
                    Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, EntryNoLbl));
                    Parameters.Add(ContractMgt.Parameter('mappingLineDef', 'string', false, MappingLineDefLbl));
                end;
            'DataExchange.Entry.Delete':
                Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, EntryNoLbl));
            'DataExchange.Definition.Import':
                begin
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, ImportStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, ImportPathLbl));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', false, InlineContentLbl));
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', false, DefinitionUploadLbl));
                    Parameters.Add(ContractMgt.Parameter('overwrite', 'boolean', false, OverwriteLbl));
                    Parameters.Add(ContractMgt.Parameter('newCode', 'string', false, NewCodeLbl));
                end;
            'DataExchange.PaymentExport.Run':
                begin
                    Parameters.Add(ContractMgt.Parameter('journalTemplate', 'string', true, JournalTemplateLbl));
                    Parameters.Add(ContractMgt.Parameter('journalBatch', 'string', true, JournalBatchLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, PaymentFileNameLbl));
                    AddDeliveryParameters(Parameters, MessageType = 'DataExchange.Definition.Export');
                end;
            'DataExchange.Entry.List':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', false, 'Optional definition code filter.'));
                    Parameters.Add(ContractMgt.Parameter('dateFrom', 'string', false, 'Inclusive start date or datetime.'));
                    Parameters.Add(ContractMgt.Parameter('dateTo', 'string', false, 'Inclusive end date or datetime.'));
                    Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, SkipDescriptionLbl));
                    Parameters.Add(ContractMgt.Parameter('take', 'integer', false, TakeDescriptionLbl));
                end;
            'DataExchange.Entry.Get':
                begin
                    Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, 'The Data Exchange entry number.'));
                    Parameters.Add(ContractMgt.Parameter('includeFields', 'boolean', false, 'Whether to include fields.'));
                    Parameters.Add(ContractMgt.Parameter('includeFileContent', 'boolean', false, 'Whether to include file content.'));
                    Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, SkipDescriptionLbl));
                    Parameters.Add(ContractMgt.Parameter('take', 'integer', false, TakeDescriptionLbl));
                end;
            'DataExchange.Type.Set':
                begin
                    Parameters.Add(ContractMgt.Parameter('code', 'string', true, TypeCodeLbl));
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', true, ImportDefinitionLbl));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, TypeDescriptionLbl));
                end;
            'DataExchange.Import.Run':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', true, ImportDefinitionLbl));
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, ImportStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, ImportPathLbl));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', false, InlineContentLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, 'Optional file name stored on the entry. Default: the file name of the path, or the definition code.'));
                    Parameters.Add(ContractMgt.Parameter('process', 'boolean', false, ProcessImportLbl));
                end;
            'DataExchange.Export.Run':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', true, ExportDefinitionLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, ExportFileNameLbl));
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, ExportTableLbl));
                    Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, 'Accepted table name instead of tableId.'));
                    Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, ExportTableViewLbl));
                    Parameters.Add(ContractMgt.Parameter('recordIds', 'array', false, ExportRecordIdsLbl));
                    Parameters.Add(ContractMgt.Parameter('lineDef', 'string', false, ExportLineDefLbl));
                    AddDeliveryParameters(Parameters, MessageType = 'DataExchange.Definition.Export');
                end;

        end;
    end;

    local procedure SupportsStorageOverwrite(MessageType: Text): Boolean
    begin
        exit(MessageType in ['Storage.File.Create', 'Storage.Attachment.Offload', 'Storage.Upload.Commit',
            'DataExchange.Definition.Export', 'DataExchange.Export.Run', 'DataExchange.PaymentExport.Run', 'Storage.Upload.CommitToDataExchange']);
    end;

    local procedure AddDeliveryParameters(var Parameters: JsonArray; HeaderOnlyAllowed: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if HeaderOnlyAllowed then
            Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, DefinitionDeliveryStorageLbl))
        else
            Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, DeliveryStorageLbl));
        Parameters.Add(ContractMgt.Parameter('path', 'string', false, DeliveryPathLbl));
        Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, DeliveryFolderLbl));
        Parameters.Add(ContractMgt.Parameter('inline', 'boolean', false, DeliveryInlineLbl));
    end;

    /// <summary>Builds the target chapter for attachment records.</summary>
    procedure GetAttachmentTarget() Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.target + data.systemId', 'attachment record', 'The attachment table and SystemId identify the attachment.'));
    end;

    /// <summary>Describes the existing record addressed by a shipped Data Exchange operation.</summary>
    /// <param name="MessageType">The registered message type.</param>
    /// <returns>The record address expressed through Foundation target entries.</returns>
    procedure GetDataExchangeTarget(MessageType: Text) Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'DataExchange.Type.Set':
                Target.Add(ContractMgt.TargetEntry('data.code', 'Data Exchange Type', TypeCodeLbl));
            'DataExchange.Definition.Delete', 'DataExchange.Definition.Export':
                Target.Add(ContractMgt.TargetEntry('data.code', 'Data Exch. Def', DefinitionCodeLbl));
            'DataExchange.Import.Run', 'DataExchange.Export.Run':
                Target.Add(ContractMgt.TargetEntry('data.dataExchDefCode', 'Data Exch. Def', DefinitionCodeLbl));
            'DataExchange.Entry.Process', 'DataExchange.Entry.Delete':
                Target.Add(ContractMgt.TargetEntry('data.entryNo', 'Data Exch.', EntryNoLbl));
            'DataExchange.PaymentExport.Run':
                Target.Add(ContractMgt.TargetEntry('data.journalTemplate + data.journalBatch', 'Gen. Journal Batch', JournalBatchLbl));
        end;
    end;

    /// <summary>Builds the success response fields for one message type.</summary>
    procedure GetResponse(MessageType: Text) Response: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Response.Add('description', SuccessEnvelopeLbl);
        Response.Add('status', 'Success');
        Response.Add('payloadPath', 'data');
        case MessageType of
            'Help.Storage.Get':
                Fields.Add(ContractMgt.ResponseField('markdown', 'string', 'The storage connector overview and message type guidance.'));
            'Help.DataExchange.Get':
                Fields.Add(ContractMgt.ResponseField('markdown', 'string', 'The Data Exchange discovery overview and workflow guidance.'));
            'Storage.Account.List':
                Fields.Add(ContractMgt.ResponseField('accounts', 'array', 'Configured storage connections without secrets. Each description is the stored Storage Setup ori.Description value, returned unchanged in every language, including app-seeded values; no translation table is used.'));
            'Storage.File.List', 'Storage.Directory.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The requested directory path.'));
                    Fields.Add(ContractMgt.ResponseField('entries', 'array', 'The files or directories found at the path.'));
                end;
            'Storage.File.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The downloaded file path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                    Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', 'The file content encoded as base64.'));
                end;
            'Storage.File.Exists', 'Storage.Directory.Exists':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The checked path.'));
                    Fields.Add(ContractMgt.ResponseField('exists', 'boolean', 'Whether the path exists.'));
                end;
            'Storage.File.Create', 'Storage.File.Delete', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create', 'Storage.Directory.Delete':
                Fields.Add(ContractMgt.ResponseField('path', 'string', 'The affected path.'));
            'Storage.Attachment.Offload':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment table.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The storage path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment table.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.CommitToRecord':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', 'The attachment target.'));
                    if MessageType in ['Storage.Attachment.CreateForRecord', 'Storage.Upload.CommitToRecord'] then
                        Fields.Add(ContractMgt.ResponseField('documentType', 'string', DocumentTypeNameLbl));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The new attachment SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', 'The final attachment file name.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                    if MessageType in ['Storage.Attachment.CreateLinked', 'Storage.Upload.CommitToRecord'] then begin
                        Fields.Add(ContractMgt.ResponseField('dataExchangeType', 'string', DataExchangeTypeResponseLbl));
                        Fields.Add(ContractMgt.ResponseField('processed', 'boolean', ProcessedResponseLbl));
                        Fields.Add(ContractMgt.ResponseField('createdDocument', 'object', CreatedDocumentResponseLbl));
                        Fields.Add(ContractMgt.ResponseField('processErrors', 'array', ProcessErrorsResponseLbl));
                        Fields.Add(ContractMgt.ResponseField('incomingDocumentStatus', 'string', IncomingStatusResponseLbl));
                    end;
                end;
            'Storage.Upload.Begin':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', UploadResponseStorageLbl));
                    Fields.Add(ContractMgt.ResponseField('chunkSizeHint', 'integer', ChunkSizeHintLbl));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The destination path.'));
                    Fields.Add(ContractMgt.ResponseField('maxChunkBytes', 'integer', 'The maximum raw chunk size.'));
                end;
            'Storage.Upload.Append':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('sequence', 'integer', 'The accepted chunk sequence.'));
                    Fields.Add(ContractMgt.ResponseField('received', 'integer', 'Bytes accumulated so far.'));
                end;
            'Storage.Upload.Commit':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The committed upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', 'The storage connection.'));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', 'The committed file path.'));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', 'The file size in bytes.'));
                end;
            'Storage.Upload.Abort':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The aborted upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'The resulting status.'));
                end;
            'Storage.Upload.Status':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', UploadResponseStorageLbl));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', UploadFileNameLbl));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', UploadPathLbl));
                    Fields.Add(ContractMgt.ResponseField('declaredSize', 'integer', DeclaredSizeLbl));
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'The upload state.'));
                    Fields.Add(ContractMgt.ResponseField('received', 'integer', 'Bytes accumulated so far.'));
                    Fields.Add(ContractMgt.ResponseField('chunkCount', 'integer', 'Chunks stored so far.'));
                end;
            'DataExchange.Type.Set':
                begin
                    Fields.Add(ContractMgt.ResponseField('code', 'string', TypeCodeLbl));
                    Fields.Add(ContractMgt.ResponseField('dataExchDefCode', 'string', ImportDefinitionLbl));
                end;
            'DataExchange.Definition.Delete':
                Fields.Add(ContractMgt.ResponseField('code', 'string', DefinitionCodeLbl));
            'DataExchange.Definition.Export':
                begin
                    Fields.Add(ContractMgt.ResponseField('code', 'string', DefinitionCodeLbl));
                    Fields.Add(ContractMgt.ResponseField('name', 'string', DefinitionNameLbl));
                    Fields.Add(ContractMgt.ResponseField('type', 'string', DefinitionTypeLbl));
                    AddDeliveryFields(Fields, MessageType = 'DataExchange.Definition.Export');
                end;
            'DataExchange.Import.Run', 'DataExchange.Export.Run', 'Storage.Upload.CommitToDataExchange':
                begin
                    if MessageType = 'Storage.Upload.CommitToDataExchange' then
                        Fields.Add(ContractMgt.ResponseField('uploadId', 'string', 'The committed upload session id.'));
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', CreatedEntryLbl));
                    Fields.Add(ContractMgt.ResponseField('dataExchDefCode', 'string', DefinitionCodeLbl));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', 'The file name stored on the entry.'));
                    if MessageType = 'DataExchange.Export.Run' then begin
                        Fields.Add(ContractMgt.ResponseField('recordCount', 'integer', 'Number of exported source records.'));
                        AddDeliveryFields(Fields, MessageType = 'DataExchange.Definition.Export');
                    end else begin
                        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', ImportResultLbl));
                        Fields.Add(ContractMgt.ResponseField('fieldCount', 'integer', ImportResultLbl));
                        Fields.Add(ContractMgt.ResponseField('storageCode', 'string', 'The storage connection of the file, when it came from or went to storage.'));
                        Fields.Add(ContractMgt.ResponseField('path', 'string', 'The storage path of the file, when it came from or went to storage.'));
                        Fields.Add(ContractMgt.ResponseField('processed', 'boolean', 'True when the mappings ran without an error.'));
                        Fields.Add(ContractMgt.ResponseField('processResult', 'object', ProcessResultLbl));
                    end;
                end;
            'DataExchange.Entry.Process':
                begin
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', EntryNoLbl));
                    Fields.Add(ContractMgt.ResponseField('dataExchDefCode', 'string', DefinitionCodeLbl));
                    Fields.Add(ContractMgt.ResponseField('processed', 'boolean', 'True when the mappings ran.'));
                    Fields.Add(ContractMgt.ResponseField('targets', 'array', TargetsLbl));
                    Fields.Add(ContractMgt.ResponseField('warnings', 'array', ProcessWarningsLbl));
                end;
            'DataExchange.Entry.Delete':
                begin
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', EntryNoLbl));
                    Fields.Add(ContractMgt.ResponseField('dataExchDefCode', 'string', DefinitionCodeLbl));
                    Fields.Add(ContractMgt.ResponseField('deletedFieldCount', 'integer', 'Number of parsed fields deleted with the entry.'));
                end;
            'DataExchange.Definition.Import':
                begin
                    Fields.Add(ContractMgt.ResponseField('codes', 'array', 'The installed definition codes.'));
                    Fields.Add(ContractMgt.ResponseField('lineDefs', 'integer', 'Number of line definitions installed.'));
                    Fields.Add(ContractMgt.ResponseField('mappings', 'integer', 'Number of mappings installed.'));
                    Fields.Add(ContractMgt.ResponseField('overwritten', 'array', 'Codes of existing definitions that were replaced.'));
                end;
            'DataExchange.PaymentExport.Run':
                begin
                    Fields.Add(ContractMgt.ResponseField('journalTemplate', 'string', JournalTemplateLbl));
                    Fields.Add(ContractMgt.ResponseField('journalBatch', 'string', JournalBatchLbl));
                    Fields.Add(ContractMgt.ResponseField('bankAccountNo', 'string', 'The balancing bank account whose export format was used.'));
                    Fields.Add(ContractMgt.ResponseField('paymentExportFormat', 'string', 'The Bank Export/Import Setup code used.'));
                    Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Number of lines in the batch.'));
                    Fields.Add(ContractMgt.ResponseField('exportedLineCount', 'integer', 'Number of lines marked Exported to Payment File.'));
                    Fields.Add(ContractMgt.ResponseField('creditTransferRegisterNo', 'integer', 'The credit transfer register that keeps the file.'));
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The Data Exch. entry, for a Data Exchange payment export format.'));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', 'The payment file name.'));
                    AddDeliveryFields(Fields, MessageType = 'DataExchange.Definition.Export');
                end;
            'DataExchange.Type.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', MatchingCountLbl));
                    Fields.Add(ContractMgt.ResponseField('types', 'array', MatchingTypesLbl));
                end;
            'DataExchange.Definition.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Number of matching definitions.'));
                    Fields.Add(ContractMgt.ResponseField('definitions', 'array', 'Matching definitions.'));
                end;
            'DataExchange.Definition.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('code', 'string', 'The definition code.'));
                    Fields.Add(ContractMgt.ResponseField('lineDefs', 'array', 'Line definitions.'));
                    Fields.Add(ContractMgt.ResponseField('columnDefs', 'array', 'Column definitions.'));
                    Fields.Add(ContractMgt.ResponseField('mappings', 'array', 'Field mappings.'));
                end;
            'DataExchange.Entry.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('skip', 'integer', PagingSkipLbl));
                    Fields.Add(ContractMgt.ResponseField('take', 'integer', PagingTakeLbl));
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Number of matching entries.'));
                    Fields.Add(ContractMgt.ResponseField('entries', 'array', 'Matching entries.'));
                end;
            'DataExchange.Entry.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('skip', 'integer', PagingSkipLbl));
                    Fields.Add(ContractMgt.ResponseField('take', 'integer', PagingTakeLbl));
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number.'));
                    Fields.Add(ContractMgt.ResponseField('fields', 'array', 'Paged entry fields.'));
                    Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', 'Optional file content.'));
                end;
        end;
        Response.Add('fields', Fields);
    end;

    local procedure AddDeliveryFields(var Fields: JsonArray; HeaderOnlyAllowed: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if HeaderOnlyAllowed then
            Fields.Add(ContractMgt.ResponseField('storageCode', 'string', DefinitionDeliveredStorageLbl))
        else
            Fields.Add(ContractMgt.ResponseField('storageCode', 'string', DeliveryStorageLbl));
        Fields.Add(ContractMgt.ResponseField('path', 'string', DeliveredPathLbl));
        Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', DeliveredLengthLbl));
        Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', DeliveredContentLbl));
    end;

    /// <summary>Builds the known errors returned by one message type.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingPathLbl: Label 'A missing storage file or folder returns RecordNotFound on path or sourcePath, using the path exactly as sent without account, container or base-path details.', Comment = 'is-IS=Geymsluskrá eða mappa sem vantar skilar RecordNotFound á path eða sourcePath með slóðinni nákvæmlega eins og hún var send, án upplýsinga um reikning, geymsluhólf eða grunnslóð.';
        MissingPathNextLbl: Label 'Use Storage.File.List or Storage.File.Exists to check the path, then retry.', Comment = 'is-IS=Notaðu Storage.File.List eða Storage.File.Exists til að athuga slóðina og reyndu aftur.';
        ProviderFailureLbl: Label 'Other storage provider failures return BusinessCentralError with localized text and no provider URL.', Comment = 'is-IS=Aðrar villur hjá geymsluveitunni skila BusinessCentralError með þýddum texta án vefslóðar veitunnar.';
        ProviderNextLbl: Label 'Check the storage connection and provider permissions, then retry.', Comment = 'is-IS=Athugaðu geymslutenginguna og heimildir hjá geymsluveitunni og reyndu aftur.';
        ProcessFailureLbl: Label 'With process true, a retained incoming document can report processed false. processErrors contains code, message and nextStep; incomingDocumentStatus reports its current status.', Comment = 'is-IS=Með process true getur varðveitt skjal í innleið skilað processed false. processErrors inniheldur code, message og nextStep; incomingDocumentStatus sýnir núverandi stöðu þess.';
        ProcessNextLbl: Label 'Inspect Incoming.Document.Get, correct the definition or source file, then retry Incoming.Document.Process.', Comment = 'is-IS=Skoðaðu Incoming.Document.Get, leiðréttu skilgreininguna eða upprunaskrána og reyndu svo Incoming.Document.Process aftur.';
        ImportFormatLbl: Label 'The file cannot be read in the definition file type. The refusal identifies contentBase64, path or uploadId and reports only the file name or size, never its content.', Comment = 'is-IS=Ekki er hægt að lesa skrána samkvæmt skráargerð skilgreiningarinnar. Höfnunin tilgreinir contentBase64, path eða uploadId og sýnir aðeins skráarheiti eða stærð, aldrei innihaldið.';
        ImportFormatNextLbl: Label 'Supply the required XML, CSV or fixed width file and retry. Inspect the definition with DataExchange.Definition.Get; use DataExchange.Definition.Export for the definition XML format.', Comment = 'is-IS=Sendu tilskilda XML-skrá, CSV-skrá eða skrá með fastri breidd og reyndu aftur. Skoðaðu skilgreininguna með DataExchange.Definition.Get; notaðu DataExchange.Definition.Export fyrir XML-snið skilgreiningarinnar.';
        ImportBoundaryLbl: Label 'Business Central errors caught while reading the source before writes include parameter and nextStep. Unexpected reader or database errors after writes retain the Foundation BusinessCentralError response; the failed import is rolled back with no entry.', Comment = 'is-IS=Business Central villur sem gripnar eru við lestur uppsprettunnar áður en skrif hefjast innihalda parameter og nextStep. Óvæntar villur í lesara eða gagnagrunni eftir skrif halda svarinu BusinessCentralError frá Foundation; misheppnaður innflutningur er afturkallaður án færslu.';
        ImportBoundaryNextLbl: Label 'Check the source and definition before retrying. Post-write errors may lack parameter and nextStep until Foundation supports rollback-safe error context.', Comment = 'is-IS=Athugaðu uppsprettuna og skilgreininguna áður en reynt er aftur. Villur eftir skrif geta verið án parameter og nextStep þar til Foundation styður villusamhengi sem varðveitir afturköllun.';
    begin
        if MessageType in ['Storage.File.Get', 'Storage.File.Copy', 'Storage.File.Delete', 'Storage.Directory.Delete', 'Storage.Attachment.CreateLinked', 'DataExchange.Definition.Import'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, MissingPathLbl, MissingPathNextLbl));
        if MessageType in ['Storage.Attachment.CreateLinked', 'Storage.Upload.CommitToRecord'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ProcessFailureLbl, ProcessNextLbl));
        if not (MessageType in ['Storage.Account.List', 'Help.Storage.Get', 'Help.DataExchange.Get', 'DataExchange.Type.List']) then begin
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingInputLbl, SupplyInputLbl));
            if MessageType in ['DataExchange.Import.Run', 'DataExchange.Definition.Import', 'Storage.Upload.CommitToDataExchange'] then
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ImportFormatLbl, ImportFormatNextLbl))
            else
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidFormatLbl, CorrectInputLbl));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidInputLbl, CorrectInputLbl));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, MultipleInputLbl, CorrectInputLbl));
            if MessageType in ['DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Definition.Export', 'DataExchange.Import.Run', 'DataExchange.Export.Run', 'Storage.Upload.CommitToDataExchange', 'DataExchange.Definition.Import'] then begin
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, MissingRecordLbl, ChooseRecordLbl));
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, UnusableDefinitionLbl, ChooseRecordLbl));
            end;
            if MessageType in ['DataExchange.Entry.Process', 'DataExchange.Entry.Delete'] then begin
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The entry number does not exist.', 'Use DataExchange.Entry.List first.'));
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The entry belongs to an incoming document, was already processed, or its definition maps to the intermediate table or has no mapping.', 'Follow nextStep; incoming document entries are processed with Incoming.Document.Process.'));
            end;
            if MessageType = 'DataExchange.Entry.Process' then
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot write a target table of the mapping.', 'Ask an administrator for permission on the target table.'));
            if MessageType = 'DataExchange.PaymentExport.Run' then begin
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The journal batch does not exist.', 'Send the exact template and batch names.'));
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The batch has no lines, its balancing bank account has no payment export format, or the export file could not be captured.', 'Follow nextStep and retry.'));
            end;
            if MessageType = 'DataExchange.Entry.Get' then
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, InlineLimitLbl, OmitInlineLbl));
            if MessageType in ['DataExchange.Import.Run', 'DataExchange.Export.Run', 'DataExchange.Definition.Import', 'DataExchange.Definition.Export', 'DataExchange.PaymentExport.Run'] then
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, 'Inline content or an inline file is larger than 1 MB.', 'Use storageCode with path, or a chunked upload.'));
        end;
        if SupportsStorageOverwrite(MessageType) then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, StorageOverwriteLbl, StorageOverwriteNextLbl));
        if UsesStorageCode(MessageType) then begin
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The storageCode does not name a storage connection.', 'Use Storage.Account.List to find the storageCode.'));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The storage connection is disabled.', 'Enable it on the Bifrost Storage Connection card, or use another storageCode.'));
        end;
        if MessageType = 'Storage.Directory.Delete' then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The path names the connection root.', 'Name a directory below the root to delete.'));
        if MessageType in ['Storage.File.Create', 'Storage.Upload.Append'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'The contentBase64 value is not valid base64.', 'Send valid base64 content.'));
        if MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'A linked Business Central attachment prevents the delete.', 'Restore or remove the attachment first.'));
        if MessageType in ['Storage.File.Copy', 'Storage.File.Move'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The connector reports that the destination file already exists.', 'Choose a new destination file name or folder.'));
        if MessageType = 'Storage.File.Move' then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The selected storage implementation cannot guarantee source preservation for a failed linked move.', 'Restore the attachment before moving the file, or use an implementation that supports linked moves.'));
        if MessageType = 'Storage.Directory.Delete' then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The directory is not empty.', 'List its files and subdirectories, remove those entries, then retry.'));
        if MessageType in ['Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.CommitToRecord', 'Storage.Upload.CommitToDataExchange', 'DataExchange.Definition.Import'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The upload session is missing, closed or incomplete.', 'Begin a new session or complete the missing chunks.'));
        if MessageType in ['DataExchange.Definition.Get'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The definition code does not exist.', 'Use DataExchange.Definition.List first.'));
        if MessageType in ['DataExchange.Entry.Get'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The entry number does not exist.', 'Use DataExchange.Entry.List first.'));
        if MessageType in ['Storage.File.Get', 'Storage.File.Copy', 'Storage.File.Delete', 'Storage.Directory.Delete', 'Storage.Attachment.CreateLinked', 'DataExchange.Definition.Import'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ProviderFailureLbl, ProviderNextLbl))
        else
        if MessageType in ['DataExchange.Import.Run', 'DataExchange.Definition.Import', 'Storage.Upload.CommitToDataExchange'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ImportBoundaryLbl, ImportBoundaryNextLbl))
        else
            if MessageType.StartsWith('DataExchange.') then
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, DataExchangeFailureLbl, DataExchangeFailureFixLbl))
            else
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The storage connector rejects or cannot complete the operation.', 'Check the path, connection and connector error details.'));
    end;

    local procedure UsesStorageCode(MessageType: Text): Boolean
    begin
        exit(MessageType in ['Storage.File.List', 'Storage.File.Get', 'Storage.File.Exists', 'Storage.File.Create', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.File.Delete',
            'Storage.Directory.List', 'Storage.Directory.Exists', 'Storage.Directory.Create', 'Storage.Directory.Delete',
            'Storage.Attachment.Offload', 'Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Begin',
            'DataExchange.Import.Run', 'DataExchange.Export.Run', 'DataExchange.Definition.Import', 'DataExchange.Definition.Export', 'DataExchange.PaymentExport.Run']);
    end;

    /// <summary>Builds the operation effect for one message type.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    var
        Changes: JsonToken;
    begin
        case true of
            MessageType in ['DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Import.Run', 'DataExchange.Export.Run', 'Storage.Upload.CommitToDataExchange',
                'DataExchange.Entry.Process', 'DataExchange.Entry.Delete', 'DataExchange.Definition.Import']:
                begin
                    Effect.Add('effect', 'write');
                    Effect.Add('changes', DataExchangeChangesLbl);
                end;
            MessageType = 'DataExchange.Definition.Export':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', DefinitionExportEffectLbl);
                end;
            MessageType = 'DataExchange.PaymentExport.Run':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', PaymentChangesLbl);
                end;
            MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete']:
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Deletes the entry in the external storage. The delete happens outside the Business Central transaction and cannot be undone.');
                end;
            MessageType = 'Storage.Attachment.Restore':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', RestoreOwnedFileLbl);
                end;
            MessageType = 'Storage.Attachment.Offload':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Links the Business Central attachment to the external file and clears its local content, then writes the file to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.');
                end;
            MessageType = 'Storage.Upload.Commit':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Assembles the staged chunks and writes the file to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.');
                end;
            MessageType in ['Storage.File.Create', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create']:
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', 'Writes to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.');
                end;
            MessageType in ['Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Begin', 'Storage.Upload.Append', 'Storage.Upload.Abort', 'Storage.Upload.CommitToRecord']:
                begin
                    Effect.Add('effect', 'write');
                    Effect.Add('changes', 'Writes Business Central records only (upload session, chunks or document attachments) inside the caller''s transaction; the external storage is not changed.');
                end;
            else begin
                Effect.Add('effect', 'read');
                Effect.Add('changes', 'Reads only; nothing is changed.');
            end;
        end;
        if SupportsStorageOverwrite(MessageType) then begin
            Effect.Get('changes', Changes);
            Effect.Replace('changes', Changes.AsValue().AsText() + ' ' + StorageOverwriteLbl);
        end;
        if MessageType in ['Storage.Attachment.CreateForRecord', 'Storage.Attachment.CreateLinked'] then
            Effect.Replace('changes', LinkedSourceEffectLbl);
        Effect.Add('idempotent', MessageType in ['Storage.Account.List', 'Storage.File.List', 'Storage.File.Get', 'Storage.File.Exists', 'Storage.Directory.List', 'Storage.Directory.Exists', 'Storage.Upload.Status', 'DataExchange.Definition.List', 'DataExchange.Definition.Get', 'DataExchange.Type.List', 'DataExchange.Entry.List', 'DataExchange.Entry.Get']);
        // The Data Exchange tables are granted by BIFROST DataExch ori only; BIFROST Attach ori does not include them.
        if IsDataExchangeType(MessageType) or (MessageType = 'Storage.Upload.CommitToDataExchange') then
            Effect.Add('permissionSet', 'BIFROST DataExch ori')
        else
            Effect.Add('permissionSet', 'BIFROST Attach ori');
        if IsDataExchangeType(MessageType) or (MessageType = 'Storage.Upload.CommitToDataExchange') then
            Effect.Add('preconditions', DataExchangePreconditionsLbl)
        else
            Effect.Add('preconditions', 'The storage connection exists, is enabled and permits the requested operation.');
    end;

    /// <summary>Builds related message types for one message type.</summary>
    procedure GetRelated(MessageType: Text) Related: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Help.Storage.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Account.List', 'Choose a configured storage connection.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files in a storage connection.'));
                end;
            'Help.DataExchange.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'Discover available Data Exchange definitions.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', 'List processed Data Exchange entries.'));
                end;
            'Storage.Account.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files after choosing a storageCode.'));
            'Storage.File.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', 'List subdirectories instead of files.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Download one listed file.'));
                end;
            'Storage.File.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Exists', 'Check whether a file exists without downloading it.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Create', 'Upload a file instead of downloading it.'));
                end;
            'Storage.File.Create':
                Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Begin', 'Upload a file larger than the single-call limit.'));
            'Storage.File.Delete':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Exists', 'Check whether the file exists first.'));
            'Storage.File.Copy':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Move', 'Move the file and remove the original path.'));
            'Storage.File.Move':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Copy', 'Copy the file while keeping the original.'));
            'Storage.Directory.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', 'List files instead of subdirectories.'));
            'Storage.Directory.Create':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.Delete', 'Remove a directory.'));
            'Storage.Directory.Delete':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.Exists', 'Check whether the directory exists first.'));
            'Storage.Directory.Exists':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', 'List the directory contents.'));
            'Storage.Attachment.Offload':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Restore', 'Bring the file back into the database.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Account.List', 'Find a storageCode.'));
                end;
            'Storage.Attachment.Restore':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move the file back to storage.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.CreateLinked', 'Create a new linked attachment.'));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Use the path of a committed upload.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Restore', 'Bring the linked file into the database.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Type.Set', 'Wire a Data Exchange Type before process.'));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToRecord', 'Attach a chunked upload directly to a record.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move inline content to storage later.'));
                end;
            'Storage.Upload.Begin':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', 'Send each chunk.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Write the completed file to storage.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToRecord', 'Attach the completed file without storage.'));
                end;
            'Storage.Upload.Append':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Status', 'Check received bytes.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Commit the completed upload.'));
                end;
            'Storage.Upload.Commit':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Download the committed file.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.CreateLinked', 'Attach the committed file.'));
                end;
            'Storage.Upload.Abort':
                Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Begin', 'Start a fresh upload.'));
            'Storage.Upload.Status':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', 'Send another chunk.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', 'Commit when complete.'));
                end;
            'Storage.Upload.CommitToRecord':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', 'Move the created attachment to storage later.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Type.Set', 'Wire a Data Exchange Type before process.'));
                end;
            'DataExchange.Definition.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read one definition in full.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Type.List', 'See which type uses a definition.'));
                end;
            'DataExchange.Definition.Get':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'Find another definition code.'));
            'DataExchange.Type.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', 'List available definitions.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read the referenced definition.'));
                end;
            'DataExchange.Entry.List':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Get', 'Read one entry and its fields.'));
            'DataExchange.Entry.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', 'Find another entry.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Process', 'Apply the mappings to the parsed fields.'));
                end;
            'Storage.Upload.CommitToDataExchange':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', 'Send the chunks first.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Get', 'Inspect the parsed fields.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Process', 'Apply the mappings when process was false.'));
                end;
            'DataExchange.Entry.Process':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Get', 'Inspect the parsed fields before processing.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Import.Run', 'Import a file into a new entry.'));
                end;
            'DataExchange.Entry.Delete':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', 'Find the entry to delete.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Get', 'Read the entry before deleting it.'));
                end;
            'DataExchange.Definition.Import':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Export', 'Write a definition as XML.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read the installed definition.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Type.Set', 'Wire an import definition to incoming documents.'));
                end;
            'DataExchange.Export.Run':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', 'Read the export definition and its mapping table.'));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Read the exported file back from storage.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.PaymentExport.Run', 'Export a payment journal batch instead.'));
                end;
            'DataExchange.PaymentExport.Run':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', 'Read the payment file back from storage.'));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Export.Run', 'Export records with a Generic Export definition instead.'));
                end;
        end;
    end;
}
