namespace Origo.Bifrost.Attachments;

using Origo.Bifrost;

/// <summary>Builds the shared contract chapters for Bifröst Attachments message types.</summary>
codeunit 70013500 "Storage Contract Parts ori"
{
    Access = Internal;

    var
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
        UploadRecordIdLbl: Label 'For DocumentAttachment, identify the host by recordSystemId or no; required for tables without no addressing.', Comment = 'is-IS=Fyrir DocumentAttachment skal auðkenna hýsil með recordSystemId eða no; nauðsynlegt fyrir töflur án no-vistfangs.';
        TypeCodeLbl: Label 'The Data Exchange Type code, at most 20 characters.', Comment = 'is-IS=Kóði gagnaskiptagerðar, að hámarki 20 stafir.';
        ImportDefinitionLbl: Label 'The existing import definition code, at most 20 characters.', Comment = 'is-IS=Kóði fyrirliggjandi innflutningsskilgreiningar, að hámarki 20 stafir.';
        ExportDefinitionLbl: Label 'The existing export definition code, at most 20 characters.', Comment = 'is-IS=Kóði fyrirliggjandi útflutningsskilgreiningar, að hámarki 20 stafir.';
        TypeDescriptionLbl: Label 'Optional description within the Data Exchange Type Description field length.', Comment = 'is-IS=Valfrjáls lýsing innan lengdar lýsingarreits gagnaskiptagerðar.';
        ImportStorageLbl: Label 'Caller reference only: checked for syntax, not validated against configured storage connections and not stored on the entry header.', Comment = 'is-IS=Aðeins tilvísun kallanda: snið er athugað en ekki hvort geymslutenging sé skilgreind og tilvísunin er ekki vistuð í færsluhausnum.';
        ImportPathLbl: Label 'Caller reference only: checked for path syntax, not validated for file existence and not stored on the entry header. No file is read.', Comment = 'is-IS=Aðeins tilvísun kallanda: snið slóðar er athugað en ekki hvort skráin sé til og slóðin er ekki vistuð í færsluhausnum. Engin skrá er lesin.';
        ExportFileNameLbl: Label 'The output file name within the Data Exch. File Name field length.', Comment = 'is-IS=Heiti úttaksskrár innan lengdar skráarheitisreits gagnaskipta.';
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
        MatchingTypesLbl: Label 'The Data Exchange Types and their linked definitions.', Comment = 'is-IS=Gagnaskiptagerðir og tengdar skilgreiningar þeirra.';
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
        DataExchangeChangesLbl: Label 'Writes Data Exchange definition, type or entry records within the operation transaction. Import.Run and Export.Run currently stage an entry header only.', Comment = 'is-IS=Skrifar skilgreiningar, gerðir eða færslur gagnaskipta innan færslubókunar aðgerðarinnar. Import.Run og Export.Run undirbúa nú aðeins færsluhaus.';
        DataExchangePreconditionsLbl: Label 'The caller holds BIFROST DataExch ori; supplied definitions and entries must exist and support the operation. No storage connection is used.', Comment = 'is-IS=Kallandi hefur BIFROST DataExch ori; uppgefnar skilgreiningar og færslur verða að vera til og styðja aðgerðina. Engin geymslutenging er notuð.';
        TheStorageMessageIsIdentifiedByLbl: Label 'The storage message is identified by its message type; it has no subject record.', Comment = 'is-IS=Geymsluboðin eru auðkennd með boðgerð sinni; þau hafa enga efnisfærslu.';
        TheDataExchangeMessageIsIdentifiedLbl: Label 'The Data Exchange message is identified by its message type; it has no subject record.', Comment = 'is-IS=Gagnaskiptaboðin eru auðkennd með boðgerð sinni; þau hafa enga efnisfærslu.';
        TheConfiguredStorageConnectionCodeResolveLbl: Label 'The configured storage connection code. Resolve it with Storage.Account.List.', Comment = 'is-IS=Kóði uppsettrar geymslutengingar. Finndu hann með Storage.Account.List.';
        TheDirectoryPathRelativeToTheLbl: Label 'The directory path relative to the connection base path.', Comment = 'is-IS=Slóð möppunnar miðað við grunnslóð tengingarinnar.';
        TheFileOrDirectoryPathRelativeLbl: Label 'The file or directory path relative to the connection base path.', Comment = 'is-IS=Slóð skrárinnar eða möppunnar miðað við grunnslóð tengingarinnar.';
        TheDestinationFilePathRelativeToLbl: Label 'The destination file path relative to the connection base path.', Comment = 'is-IS=Áfangaslóð skrárinnar miðað við grunnslóð tengingarinnar.';
        TheCompleteFileContentEncodedAsLbl: Label 'The complete file content encoded as base64.', Comment = 'is-IS=Allt innihald skrárinnar kóðað sem base64.';
        TheSourceFilePathRelativeToLbl: Label 'The source file path relative to the connection base path.', Comment = 'is-IS=Slóð upprunaskrárinnar miðað við grunnslóð tengingarinnar.';
        TheAttachmentTableIncomingDocumentOrDocumentAttachmentLbl: Label 'The attachment table: IncomingDocument or DocumentAttachment.', Comment = 'is-IS=Viðhengjataflan: IncomingDocument eða DocumentAttachment.';
        TheAttachmentSystemIdLbl: Label 'The attachment SystemId.', Comment = 'is-IS=SystemId viðhengisins.';
        OptionalDestinationFolderLbl: Label 'Optional destination folder.', Comment = 'is-IS=Valfrjáls áfangamappa.';
        TheFilePathInStorageLbl: Label 'The file path in storage.', Comment = 'is-IS=Slóð skrárinnar í geymslu.';
        TheAttachmentFileNameLbl: Label 'The attachment file name.', Comment = 'is-IS=Skráarheiti viðhengisins.';
        AnExistingIncomingDocumentEntryNumberLbl: Label 'An existing incoming document entry number.', Comment = 'is-IS=Númer fyrirliggjandi færslu innkomandi skjals.';
        DescriptionForANewIncomingDocumentLbl: Label 'Description for a new incoming document.', Comment = 'is-IS=Lýsing fyrir nýtt innkomandi skjal.';
        TheHostRecordTableIdLbl: Label 'The host record table id.', Comment = 'is-IS=Töfluauðkenni hýsilfærslunnar.';
        TheHostRecordTableNameLbl: Label 'The host record table name.', Comment = 'is-IS=Töfluheiti hýsilfærslunnar.';
        TheHostRecordSystemIdLbl: Label 'The host record SystemId.', Comment = 'is-IS=SystemId hýsilfærslunnar.';
        TheHostRecordPrimaryKeyLbl: Label 'The host record primary key.', Comment = 'is-IS=Aðallykill hýsilfærslunnar.';
        InlineFileContentEncodedAsBase64Lbl: Label 'Inline file content encoded as base64.', Comment = 'is-IS=Innfellt skráarinnihald kóðað sem base64.';
        AcceptedAliasOfContentBase64DoNotLbl: Label 'Accepted alias of contentBase64. Do not send both.', Comment = 'is-IS=Samþykkt samheiti fyrir contentBase64. Ekki senda bæði.';
        TheSourceFilePathInStorageLbl: Label 'The source file path in storage.', Comment = 'is-IS=Slóð upprunaskrárinnar í geymslu.';
        TheLeafFileNameLbl: Label 'The leaf file name.', Comment = 'is-IS=Skráarheitið án slóðar.';
        TheFullDestinationPathLbl: Label 'The full destination path.', Comment = 'is-IS=Öll áfangaslóðin.';
        TheDestinationFolderLbl: Label 'The destination folder.', Comment = 'is-IS=Áfangamappan.';
        TheExpectedTotalSizeInBytesLbl: Label 'The expected total size in bytes.', Comment = 'is-IS=Áætluð heildarstærð í bætum.';
        TheUploadSessionIdLbl: Label 'The upload session id.', Comment = 'is-IS=Auðkenni upphleðslulotunnar.';
        TheOneBasedChunkSequenceLbl: Label 'The one-based chunk sequence.', Comment = 'is-IS=Raðnúmer gagnaeiningar, talið frá einum.';
        TheChunkContentEncodedAsBase64Lbl: Label 'The chunk content encoded as base64.', Comment = 'is-IS=Innihald gagnaeiningarinnar kóðað sem base64.';
        DocumentAttachmentOrIncomingDocumentLbl: Label 'DocumentAttachment or IncomingDocument.', Comment = 'is-IS=DocumentAttachment eða IncomingDocument.';
        AnOptionalReplacementFileNameLbl: Label 'An optional replacement file name.', Comment = 'is-IS=Valfrjálst skráarheiti í stað upprunalegs heitis.';
        OptionalDefinitionTypeFilterLbl: Label 'Optional definition type filter.', Comment = 'is-IS=Valfrjáls sía fyrir gerð skilgreiningar.';
        ImportOrExportLbl: Label 'Import or Export.', Comment = 'is-IS=Import eða Export.';
        OptionalDefinitionCodeFilterLbl: Label 'Optional definition code filter.', Comment = 'is-IS=Valfrjáls sía fyrir skilgreiningarkóða.';
        InclusiveStartDateOrDatetimeLbl: Label 'Inclusive start date or datetime.', Comment = 'is-IS=Upphafsdagsetning eða dagsetning og tími, að meðtöldu upphafi.';
        InclusiveEndDateOrDatetimeLbl: Label 'Inclusive end date or datetime.', Comment = 'is-IS=Lokadagsetning eða dagsetning og tími, að meðtöldum lokum.';
        TheDataExchangeEntryNumberLbl: Label 'The Data Exchange entry number.', Comment = 'is-IS=Númer gagnaskiptafærslunnar.';
        WhetherToIncludeFieldsLbl: Label 'Whether to include fields.', Comment = 'is-IS=Hvort reitir eigi að fylgja.';
        WhetherToIncludeFileContentLbl: Label 'Whether to include file content.', Comment = 'is-IS=Hvort skráarinnihald eigi að fylgja.';
        TheAttachmentTableAndSystemIdIdentifyLbl: Label 'The attachment table and SystemId identify the attachment.', Comment = 'is-IS=Viðhengjataflan og SystemId auðkenna viðhengið.';
        TheStorageConnectorOverviewAndMessageLbl: Label 'The storage connector overview and message type guidance.', Comment = 'is-IS=Yfirlit yfir geymslutengilinn og leiðbeiningar um boðgerðir.';
        TheDataExchangeDiscoveryOverviewAndLbl: Label 'The Data Exchange discovery overview and workflow guidance.', Comment = 'is-IS=Yfirlit yfir gagnaskiptagerðir og leiðbeiningar um verkflæði.';
        ConfiguredStorageConnectionsWithoutSecretsLbl: Label 'Configured storage connections without secrets. Each description is the stored Storage Setup ori.Description value, returned unchanged in every language, including app-seeded values; no translation table is used.', Comment = 'is-IS=Uppsettar geymslutengingar án leyndarmála. Hver lýsing er vistað gildi reitsins Storage Setup ori.Description og er skilað óbreytt á öllum tungumálum, einnig þegar forritið stofnaði gildið; engin þýðingartafla er notuð.';
        TheRequestedDirectoryPathLbl: Label 'The requested directory path.', Comment = 'is-IS=Umbeðin möppuslóð.';
        TheFilesOrDirectoriesFoundAtLbl: Label 'The files or directories found at the path.', Comment = 'is-IS=Skrárnar eða möppurnar sem fundust á slóðinni.';
        TheDownloadedFilePathLbl: Label 'The downloaded file path.', Comment = 'is-IS=Slóð sóttu skrárinnar.';
        TheFileSizeInBytesLbl: Label 'The file size in bytes.', Comment = 'is-IS=Stærð skrárinnar í bætum.';
        TheFileContentEncodedAsBase64Lbl: Label 'The file content encoded as base64.', Comment = 'is-IS=Innihald skrárinnar kóðað sem base64.';
        TheCheckedPathLbl: Label 'The checked path.', Comment = 'is-IS=Slóðin sem var athuguð.';
        WhetherThePathExistsLbl: Label 'Whether the path exists.', Comment = 'is-IS=Hvort slóðin sé til.';
        TheAffectedPathLbl: Label 'The affected path.', Comment = 'is-IS=Slóðin sem aðgerðin hefur áhrif á.';
        TheAttachmentTableLbl: Label 'The attachment table.', Comment = 'is-IS=Viðhengjataflan.';
        TheStoragePathLbl: Label 'The storage path.', Comment = 'is-IS=Geymsluslóðin.';
        TheAttachmentTargetLbl: Label 'The attachment target.', Comment = 'is-IS=Viðhengjamarkið.';
        TheNewAttachmentSystemIdLbl: Label 'The new attachment SystemId.', Comment = 'is-IS=SystemId nýja viðhengisins.';
        TheFinalAttachmentFileNameLbl: Label 'The final attachment file name.', Comment = 'is-IS=Endanlegt skráarheiti viðhengisins.';
        TheDestinationPathLbl: Label 'The destination path.', Comment = 'is-IS=Áfangaslóðin.';
        TheMaximumRawChunkSizeLbl: Label 'The maximum raw chunk size.', Comment = 'is-IS=Hámarksstærð hrárrar gagnaeiningar.';
        TheAcceptedChunkSequenceLbl: Label 'The accepted chunk sequence.', Comment = 'is-IS=Samþykkt raðnúmer gagnaeiningar.';
        BytesAccumulatedSoFarLbl: Label 'Bytes accumulated so far.', Comment = 'is-IS=Bæti sem hafa safnast hingað til.';
        TheCommittedUploadSessionIdLbl: Label 'The committed upload session id.', Comment = 'is-IS=Auðkenni staðfestu upphleðslulotunnar.';
        TheStorageConnectionLbl: Label 'The storage connection.', Comment = 'is-IS=Geymslutengingin.';
        TheCommittedFilePathLbl: Label 'The committed file path.', Comment = 'is-IS=Slóð staðfestu skrárinnar.';
        TheAbortedUploadSessionIdLbl: Label 'The aborted upload session id.', Comment = 'is-IS=Auðkenni upphleðslulotunnar sem var hætt við.';
        TheResultingStatusLbl: Label 'The resulting status.', Comment = 'is-IS=Staðan að aðgerð lokinni.';
        TheUploadStateLbl: Label 'The upload state.', Comment = 'is-IS=Staða upphleðslunnar.';
        ChunksStoredSoFarLbl: Label 'Chunks stored so far.', Comment = 'is-IS=Gagnaeiningar sem hafa verið vistaðar hingað til.';
        NumberOfMatchingDefinitionsLbl: Label 'Number of matching definitions.', Comment = 'is-IS=Fjöldi samsvarandi skilgreininga.';
        MatchingDefinitionsLbl: Label 'Matching definitions.', Comment = 'is-IS=Samsvarandi skilgreiningar.';
        TheDefinitionCodeLbl: Label 'The definition code.', Comment = 'is-IS=Skilgreiningarkóðinn.';
        LineDefinitionsLbl: Label 'Line definitions.', Comment = 'is-IS=Línuskilgreiningar.';
        ColumnDefinitionsLbl: Label 'Column definitions.', Comment = 'is-IS=Dálkaskilgreiningar.';
        FieldMappingsLbl: Label 'Field mappings.', Comment = 'is-IS=Reitavarpanir.';
        NumberOfMatchingEntriesLbl: Label 'Number of matching entries.', Comment = 'is-IS=Fjöldi samsvarandi færslna.';
        MatchingEntriesLbl: Label 'Matching entries.', Comment = 'is-IS=Samsvarandi færslur.';
        TheEntryNumberLbl: Label 'The entry number.', Comment = 'is-IS=Færslunúmerið.';
        PagedEntryFieldsLbl: Label 'Paged entry fields.', Comment = 'is-IS=Reitir færslunnar í síðuskiptu svari.';
        OptionalFileContentLbl: Label 'Optional file content.', Comment = 'is-IS=Valfrjálst skráarinnihald.';
        TheContentBase64ValueIsNotValidLbl: Label 'The contentBase64 value is not valid base64.', Comment = 'is-IS=Gildið í contentBase64 er ekki gilt base64.';
        SendValidBase64ContentLbl: Label 'Send valid base64 content.', Comment = 'is-IS=Sendu gilt base64-innihald.';
        ALinkedBusinessCentralAttachmentPreventsLbl: Label 'A linked Business Central attachment prevents the delete.', Comment = 'is-IS=Tengt Business Central viðhengi kemur í veg fyrir eyðinguna.';
        RestoreOrRemoveTheAttachmentFirstLbl: Label 'Restore or remove the attachment first.', Comment = 'is-IS=Endurheimtu eða fjarlægðu viðhengið fyrst.';
        TheDirectoryIsNotEmptyLbl: Label 'The directory is not empty.', Comment = 'is-IS=Mappan er ekki tóm.';
        ListItsFilesAndSubdirectoriesRemoveLbl: Label 'List its files and subdirectories, remove those entries, then retry.', Comment = 'is-IS=Listaðu skrár og undirmöppur hennar, fjarlægðu þær færslur og reyndu síðan aftur.';
        TheUploadSessionIsMissingClosedLbl: Label 'The upload session is missing, closed or incomplete.', Comment = 'is-IS=Upphleðslulotuna vantar, henni er lokað eða hún er ófullgerð.';
        BeginANewSessionOrCompleteLbl: Label 'Begin a new session or complete the missing chunks.', Comment = 'is-IS=Byrjaðu nýja lotu eða bættu við gagnaeiningunum sem vantar.';
        TheDefinitionCodeDoesNotExistLbl: Label 'The definition code does not exist.', Comment = 'is-IS=Skilgreiningarkóðinn er ekki til.';
        UseDataExchangeDefinitionListFirstLbl: Label 'Use DataExchange.Definition.List first.', Comment = 'is-IS=Notaðu DataExchange.Definition.List fyrst.';
        TheEntryNumberDoesNotExistLbl: Label 'The entry number does not exist.', Comment = 'is-IS=Færslunúmerið er ekki til.';
        UseDataExchangeEntryListFirstLbl: Label 'Use DataExchange.Entry.List first.', Comment = 'is-IS=Notaðu DataExchange.Entry.List fyrst.';
        TheStorageConnectorRejectsOrCannotLbl: Label 'The storage connector rejects or cannot complete the operation.', Comment = 'is-IS=Geymslutengillinn hafnar aðgerðinni eða getur ekki lokið henni.';
        CheckThePathConnectionAndConnectorLbl: Label 'Check the path, connection and connector error details.', Comment = 'is-IS=Athugaðu slóðina, tenginguna og villuupplýsingar tengilsins.';
        DeletesTheEntryInTheExternalLbl: Label 'Deletes the entry in the external storage. The delete happens outside the Business Central transaction and cannot be undone.', Comment = 'is-IS=Eyðir færslunni í ytri geymslu. Eyðingin fer fram utan færslubókunar Business Central og verður ekki afturkölluð.';
        WritesTheContentBackIntoTheLbl: Label 'Writes the content back into the Business Central attachment, then deletes the offloaded file in the external storage. The delete happens outside the Business Central transaction and cannot be undone.', Comment = 'is-IS=Skrifar innihaldið aftur í Business Central viðhengið og eyðir síðan útvistuðu skránni úr ytri geymslu. Eyðingin fer fram utan færslubókunar Business Central og verður ekki afturkölluð.';
        LinksTheBusinessCentralAttachmentToLbl: Label 'Links the Business Central attachment to the external file and clears its local content, then writes the file to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.', Comment = 'is-IS=Tengir Business Central viðhengið við ytri skrána og tæmir staðbundið innihald þess og skrifar síðan skrána í ytri geymslu. Ytri skrifin fara fram utan færslubókunar Business Central og eru ekki afturkölluð með henni.';
        AssemblesTheStagedChunksAndWritesLbl: Label 'Assembles the staged chunks and writes the file to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.', Comment = 'is-IS=Setur undirbúnar gagnaeiningar saman og skrifar skrána í ytri geymslu. Ytri skrifin fara fram utan færslubókunar Business Central og eru ekki afturkölluð með henni.';
        WritesToTheExternalStorageTheLbl: Label 'Writes to the external storage. The external write happens outside the Business Central transaction and is not rolled back with it.', Comment = 'is-IS=Skrifar í ytri geymslu. Ytri skrifin fara fram utan færslubókunar Business Central og eru ekki afturkölluð með henni.';
        WritesBusinessCentralRecordsOnlyUploadLbl: Label 'Writes Business Central records only (upload session, chunks or document attachments) inside the caller''s transaction; the external storage is not changed.', Comment = 'is-IS=Skrifar eingöngu Business Central færslur (upphleðslulotu, gagnaeiningar eða skjalaviðhengi) innan færslubókunar kallandans; ytri geymslunni er ekki breytt.';
        ReadsOnlyNothingIsChangedLbl: Label 'Reads only; nothing is changed.', Comment = 'is-IS=Les eingöngu; engu er breytt.';
        TheStorageConnectionExistsIsEnabledLbl: Label 'The storage connection exists, is enabled and permits the requested operation.', Comment = 'is-IS=Geymslutengingin er til, virk og leyfir umbeðna aðgerð.';
        ChooseAConfiguredStorageConnectionLbl: Label 'Choose a configured storage connection.', Comment = 'is-IS=Veldu uppsetta geymslutengingu.';
        ListFilesInAStorageConnectionLbl: Label 'List files in a storage connection.', Comment = 'is-IS=Listaðu skrár í geymslutengingu.';
        DiscoverAvailableDataExchangeDefinitionsLbl: Label 'Discover available Data Exchange definitions.', Comment = 'is-IS=Finndu tiltækar gagnaskiptaskilgreiningar.';
        ListProcessedDataExchangeEntriesLbl: Label 'List processed Data Exchange entries.', Comment = 'is-IS=Listaðu unnar gagnaskiptafærslur.';
        ListFilesAfterChoosingAStorageCodeLbl: Label 'List files after choosing a storageCode.', Comment = 'is-IS=Listaðu skrár eftir að hafa valið storageCode.';
        ListSubdirectoriesInsteadOfFilesLbl: Label 'List subdirectories instead of files.', Comment = 'is-IS=Listaðu undirmöppur í stað skráa.';
        DownloadOneListedFileLbl: Label 'Download one listed file.', Comment = 'is-IS=Sæktu eina af skránum á listanum.';
        CheckWhetherAFileExistsWithoutLbl: Label 'Check whether a file exists without downloading it.', Comment = 'is-IS=Athugaðu hvort skrá sé til án þess að sækja hana.';
        UploadAFileInsteadOfDownloadingLbl: Label 'Upload a file instead of downloading it.', Comment = 'is-IS=Hladdu upp skrá í stað þess að sækja hana.';
        UploadAFileLargerThanTheLbl: Label 'Upload a file larger than the single-call limit.', Comment = 'is-IS=Hladdu upp skrá sem er stærri en hámark fyrir eitt kall.';
        CheckWhetherTheFileExistsFirstLbl: Label 'Check whether the file exists first.', Comment = 'is-IS=Athugaðu fyrst hvort skráin sé til.';
        MoveTheFileAndRemoveTheLbl: Label 'Move the file and remove the original path.', Comment = 'is-IS=Færðu skrána og fjarlægðu upprunalegu slóðina.';
        CopyTheFileWhileKeepingTheLbl: Label 'Copy the file while keeping the original.', Comment = 'is-IS=Afritaðu skrána og haltu upprunalegu skránni.';
        ListFilesInsteadOfSubdirectoriesLbl: Label 'List files instead of subdirectories.', Comment = 'is-IS=Listaðu skrár í stað undirmappa.';
        RemoveADirectoryLbl: Label 'Remove a directory.', Comment = 'is-IS=Fjarlægðu möppu.';
        CheckWhetherTheDirectoryExistsFirstLbl: Label 'Check whether the directory exists first.', Comment = 'is-IS=Athugaðu fyrst hvort mappan sé til.';
        ListTheDirectoryContentsLbl: Label 'List the directory contents.', Comment = 'is-IS=Listaðu innihald möppunnar.';
        BringTheFileBackIntoTheLbl: Label 'Bring the file back into the database.', Comment = 'is-IS=Færðu skrána aftur inn í gagnagrunninn.';
        FindAStorageCodeLbl: Label 'Find a storageCode.', Comment = 'is-IS=Finndu storageCode.';
        MoveTheFileBackToStorageLbl: Label 'Move the file back to storage.', Comment = 'is-IS=Færðu skrána aftur í geymslu.';
        CreateANewLinkedAttachmentLbl: Label 'Create a new linked attachment.', Comment = 'is-IS=Stofnaðu nýtt tengt viðhengi.';
        UseThePathOfACommittedLbl: Label 'Use the path of a committed upload.', Comment = 'is-IS=Notaðu slóð staðfestrar upphleðslu.';
        BringTheLinkedFileIntoTheLbl: Label 'Bring the linked file into the database.', Comment = 'is-IS=Færðu tengdu skrána inn í gagnagrunninn.';
        AttachAChunkedUploadDirectlyToLbl: Label 'Attach a chunked upload directly to a record.', Comment = 'is-IS=Hengdu upphleðslu í gagnaeiningum beint við færslu.';
        MoveInlineContentToStorageLaterLbl: Label 'Move inline content to storage later.', Comment = 'is-IS=Færðu innfellt innihald í geymslu síðar.';
        SendEachChunkLbl: Label 'Send each chunk.', Comment = 'is-IS=Sendu hverja gagnaeiningu.';
        WriteTheCompletedFileToStorageLbl: Label 'Write the completed file to storage.', Comment = 'is-IS=Skrifaðu fullgerðu skrána í geymslu.';
        AttachTheCompletedFileWithoutStorageLbl: Label 'Attach the completed file without storage.', Comment = 'is-IS=Hengdu fullgerðu skrána við án geymslu.';
        CheckReceivedBytesLbl: Label 'Check received bytes.', Comment = 'is-IS=Athugaðu móttekin bæti.';
        CommitTheCompletedUploadLbl: Label 'Commit the completed upload.', Comment = 'is-IS=Staðfestu fullgerðu upphleðsluna.';
        DownloadTheCommittedFileLbl: Label 'Download the committed file.', Comment = 'is-IS=Sæktu staðfestu skrána.';
        AttachTheCommittedFileLbl: Label 'Attach the committed file.', Comment = 'is-IS=Hengdu staðfestu skrána við.';
        StartAFreshUploadLbl: Label 'Start a fresh upload.', Comment = 'is-IS=Byrjaðu nýja upphleðslu.';
        SendAnotherChunkLbl: Label 'Send another chunk.', Comment = 'is-IS=Sendu aðra gagnaeiningu.';
        CommitWhenCompleteLbl: Label 'Commit when complete.', Comment = 'is-IS=Staðfestu þegar allt er tilbúið.';
        MoveTheCreatedAttachmentToStorageLbl: Label 'Move the created attachment to storage later.', Comment = 'is-IS=Færðu nýstofnaða viðhengið í geymslu síðar.';
        ReadOneDefinitionInFullLbl: Label 'Read one definition in full.', Comment = 'is-IS=Lestu eina skilgreiningu í heild.';
        SeeWhichTypeUsesADefinitionLbl: Label 'See which type uses a definition.', Comment = 'is-IS=Sjáðu hvaða gerð notar skilgreiningu.';
        FindAnotherDefinitionCodeLbl: Label 'Find another definition code.', Comment = 'is-IS=Finndu annan skilgreiningarkóða.';
        ListAvailableDefinitionsLbl: Label 'List available definitions.', Comment = 'is-IS=Listaðu tiltækar skilgreiningar.';
        ReadTheReferencedDefinitionLbl: Label 'Read the referenced definition.', Comment = 'is-IS=Lestu skilgreininguna sem vísað er í.';
        ReadOneEntryAndItsFieldsLbl: Label 'Read one entry and its fields.', Comment = 'is-IS=Lestu eina færslu og reiti hennar.';
        FindAnotherEntryLbl: Label 'Find another entry.', Comment = 'is-IS=Finndu aðra færslu.';


    /// <summary>Builds the envelope shared by storage requests.</summary>
    procedure GetEnvelope(DataRequired: Boolean) Envelope: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', TheStorageMessageIsIdentifiedByLbl);
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
        Subject.Add('description', TheDataExchangeMessageIsIdentifiedLbl);
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

        if not (MessageType in ['Storage.Attachment.Restore', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status', 'DataExchange.Definition.Get', 'DataExchange.Entry.Get', 'DataExchange.Definition.List', 'DataExchange.Entry.List', 'DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Definition.Export', 'DataExchange.Import.Run', 'DataExchange.Export.Run', 'Storage.Upload.Begin', 'Storage.Upload.CommitToRecord']) then
            Parameters.Add(ContractMgt.Parameter('storageCode', 'string', true, TheConfiguredStorageConnectionCodeResolveLbl));
        case MessageType of
            'Storage.File.List', 'Storage.Directory.List':
                Parameters.Add(ContractMgt.Parameter('path', 'string', false, TheDirectoryPathRelativeToTheLbl));
            'Storage.File.Get', 'Storage.File.Delete', 'Storage.File.Exists', 'Storage.Directory.Create', 'Storage.Directory.Delete', 'Storage.Directory.Exists':
                Parameters.Add(ContractMgt.Parameter('path', 'string', true, TheFileOrDirectoryPathRelativeLbl));
            'Storage.File.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, TheDestinationFilePathRelativeToLbl));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, TheCompleteFileContentEncodedAsLbl));
                end;
            'Storage.File.Copy', 'Storage.File.Move':
                begin
                    Parameters.Add(ContractMgt.Parameter('sourcePath', 'string', true, TheSourceFilePathRelativeToLbl));
                    Parameters.Add(ContractMgt.Parameter('targetPath', 'string', true, TheDestinationFilePathRelativeToLbl));
                end;
            'Storage.Attachment.Offload':
                begin
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, TheAttachmentTableIncomingDocumentOrDocumentAttachmentLbl));
                    Parameters.Add(ContractMgt.Parameter('systemId', 'string', true, TheAttachmentSystemIdLbl));
                    Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, OptionalDestinationFolderLbl));
                end;
            'Storage.Attachment.Restore':
                begin
                    Parameters.Add(ContractMgt.Parameter('target', 'string', true, TheAttachmentTableIncomingDocumentOrDocumentAttachmentLbl));
                    Parameters.Add(ContractMgt.Parameter('systemId', 'string', true, TheAttachmentSystemIdLbl));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, TheFilePathInStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, TheAttachmentFileNameLbl));
                    Parameters.Add(ContractMgt.Parameter('incomingDocumentEntryNo', 'integer', false, AnExistingIncomingDocumentEntryNumberLbl));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, DescriptionForANewIncomingDocumentLbl));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, AttachmentStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('sourceTarget', 'string', false, SourceTargetLbl));
                    Parameters.Add(ContractMgt.Parameter('sourceSystemId', 'string', false, SourceSystemIdLbl));
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, TheHostRecordTableIdLbl));
                    Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, TheHostRecordTableNameLbl));
                    Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, TheHostRecordSystemIdLbl));
                    Parameters.Add(ContractMgt.Parameter('no', 'string', false, TheHostRecordPrimaryKeyLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, TheAttachmentFileNameLbl));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', false, InlineFileContentEncodedAsBase64Lbl));
                    Parameters.Add(ContractMgt.Parameter('content', 'string', false, AcceptedAliasOfContentBase64DoNotLbl));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, TheSourceFilePathInStorageLbl));
                end;
            'Storage.Upload.Begin':
                begin
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', false, UploadStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, TheLeafFileNameLbl));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', false, TheFullDestinationPathLbl));
                    Parameters.Add(ContractMgt.Parameter('folderPath', 'string', false, TheDestinationFolderLbl));
                    Parameters.Add(ContractMgt.Parameter('declaredSize', 'integer', false, TheExpectedTotalSizeInBytesLbl));
                end;
            'Storage.Upload.Append':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, TheUploadSessionIdLbl));
                    Parameters.Add(ContractMgt.Parameter('sequence', 'integer', true, TheOneBasedChunkSequenceLbl));
                    Parameters.Add(ContractMgt.Parameter('contentBase64', 'string', true, TheChunkContentEncodedAsBase64Lbl));
                end;
            'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.Status':
                Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, TheUploadSessionIdLbl));
            'Storage.Upload.CommitToRecord':
                begin
                    Parameters.Add(ContractMgt.Parameter('uploadId', 'string', true, TheUploadSessionIdLbl));
                    Parameters.Add(ContractMgt.Parameter('target', 'string', false, DocumentAttachmentOrIncomingDocumentLbl));
                    Parameters.Add(ContractMgt.Parameter('tableId', 'integer', false, UploadTableIdLbl));
                    Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, UploadTableNameLbl));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, IncomingDescriptionLbl));
                    Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, UploadRecordIdLbl));
                    Parameters.Add(ContractMgt.Parameter('no', 'string', false, TheHostRecordPrimaryKeyLbl));
                    Parameters.Add(ContractMgt.Parameter('incomingDocumentEntryNo', 'integer', false, AnExistingIncomingDocumentEntryNumberLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', false, AnOptionalReplacementFileNameLbl));
                end;
            'DataExchange.Definition.List':
                begin
                    Parameters.Add(ContractMgt.Parameter('type', 'string', false, OptionalDefinitionTypeFilterLbl));
                    Parameters.Add(ContractMgt.Parameter('direction', 'string', false, ImportOrExportLbl));
                end;
            'DataExchange.Definition.Get', 'DataExchange.Definition.Delete', 'DataExchange.Definition.Export':
                Parameters.Add(ContractMgt.Parameter('code', 'string', true, DefinitionCodeLbl));
            'DataExchange.Entry.List':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', false, OptionalDefinitionCodeFilterLbl));
                    Parameters.Add(ContractMgt.Parameter('dateFrom', 'string', false, InclusiveStartDateOrDatetimeLbl));
                    Parameters.Add(ContractMgt.Parameter('dateTo', 'string', false, InclusiveEndDateOrDatetimeLbl));
                    Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, SkipDescriptionLbl));
                    Parameters.Add(ContractMgt.Parameter('take', 'integer', false, TakeDescriptionLbl));
                end;
            'DataExchange.Entry.Get':
                begin
                    Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, TheDataExchangeEntryNumberLbl));
                    Parameters.Add(ContractMgt.Parameter('includeFields', 'boolean', false, WhetherToIncludeFieldsLbl));
                    Parameters.Add(ContractMgt.Parameter('includeFileContent', 'boolean', false, WhetherToIncludeFileContentLbl));
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
                    Parameters.Add(ContractMgt.Parameter('storageCode', 'string', true, ImportStorageLbl));
                    Parameters.Add(ContractMgt.Parameter('path', 'string', true, ImportPathLbl));
                end;
            'DataExchange.Export.Run':
                begin
                    Parameters.Add(ContractMgt.Parameter('dataExchDefCode', 'string', true, ExportDefinitionLbl));
                    Parameters.Add(ContractMgt.Parameter('fileName', 'string', true, ExportFileNameLbl));
                end;

        end;
    end;

    /// <summary>Builds the target chapter for attachment records.</summary>
    procedure GetAttachmentTarget() Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.target + data.systemId', 'attachment record', TheAttachmentTableAndSystemIdIdentifyLbl));
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
        end;
    end;

    /// <summary>Builds the success response fields for one message type.</summary>
    procedure GetResponse(MessageType: Text) Response: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        case MessageType of
            'Help.Storage.Get':
                Fields.Add(ContractMgt.ResponseField('markdown', 'string', TheStorageConnectorOverviewAndMessageLbl));
            'Help.DataExchange.Get':
                Fields.Add(ContractMgt.ResponseField('markdown', 'string', TheDataExchangeDiscoveryOverviewAndLbl));
            'Storage.Account.List':
                Fields.Add(ContractMgt.ResponseField('accounts', 'array', ConfiguredStorageConnectionsWithoutSecretsLbl));
            'Storage.File.List', 'Storage.Directory.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', TheRequestedDirectoryPathLbl));
                    Fields.Add(ContractMgt.ResponseField('entries', 'array', TheFilesOrDirectoriesFoundAtLbl));
                end;
            'Storage.File.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', TheDownloadedFilePathLbl));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', TheFileSizeInBytesLbl));
                    Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', TheFileContentEncodedAsBase64Lbl));
                end;
            'Storage.File.Exists', 'Storage.Directory.Exists':
                begin
                    Fields.Add(ContractMgt.ResponseField('path', 'string', TheCheckedPathLbl));
                    Fields.Add(ContractMgt.ResponseField('exists', 'boolean', WhetherThePathExistsLbl));
                end;
            'Storage.File.Create', 'Storage.File.Delete', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create', 'Storage.Directory.Delete':
                Fields.Add(ContractMgt.ResponseField('path', 'string', TheAffectedPathLbl));
            'Storage.Attachment.Offload':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', TheAttachmentTableLbl));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', TheAttachmentSystemIdLbl));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', TheStoragePathLbl));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', TheFileSizeInBytesLbl));
                end;
            'Storage.Attachment.Restore':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', TheAttachmentTableLbl));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', TheAttachmentSystemIdLbl));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', TheFileSizeInBytesLbl));
                end;
            'Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.CommitToRecord':
                begin
                    Fields.Add(ContractMgt.ResponseField('target', 'string', TheAttachmentTargetLbl));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', TheNewAttachmentSystemIdLbl));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', TheFinalAttachmentFileNameLbl));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', TheFileSizeInBytesLbl));
                end;
            'Storage.Upload.Begin':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', TheUploadSessionIdLbl));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', UploadResponseStorageLbl));
                    Fields.Add(ContractMgt.ResponseField('chunkSizeHint', 'integer', ChunkSizeHintLbl));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', TheDestinationPathLbl));
                    Fields.Add(ContractMgt.ResponseField('maxChunkBytes', 'integer', TheMaximumRawChunkSizeLbl));
                end;
            'Storage.Upload.Append':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', TheUploadSessionIdLbl));
                    Fields.Add(ContractMgt.ResponseField('sequence', 'integer', TheAcceptedChunkSequenceLbl));
                    Fields.Add(ContractMgt.ResponseField('received', 'integer', BytesAccumulatedSoFarLbl));
                end;
            'Storage.Upload.Commit':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', TheCommittedUploadSessionIdLbl));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', TheStorageConnectionLbl));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', TheCommittedFilePathLbl));
                    Fields.Add(ContractMgt.ResponseField('contentLength', 'integer', TheFileSizeInBytesLbl));
                end;
            'Storage.Upload.Abort':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', TheAbortedUploadSessionIdLbl));
                    Fields.Add(ContractMgt.ResponseField('status', 'string', TheResultingStatusLbl));
                end;
            'Storage.Upload.Status':
                begin
                    Fields.Add(ContractMgt.ResponseField('uploadId', 'string', TheUploadSessionIdLbl));
                    Fields.Add(ContractMgt.ResponseField('storageCode', 'string', UploadResponseStorageLbl));
                    Fields.Add(ContractMgt.ResponseField('fileName', 'string', UploadFileNameLbl));
                    Fields.Add(ContractMgt.ResponseField('path', 'string', UploadPathLbl));
                    Fields.Add(ContractMgt.ResponseField('declaredSize', 'integer', DeclaredSizeLbl));
                    Fields.Add(ContractMgt.ResponseField('status', 'string', TheUploadStateLbl));
                    Fields.Add(ContractMgt.ResponseField('received', 'integer', BytesAccumulatedSoFarLbl));
                    Fields.Add(ContractMgt.ResponseField('chunkCount', 'integer', ChunksStoredSoFarLbl));
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
                end;
            'DataExchange.Import.Run', 'DataExchange.Export.Run':
                begin
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', CreatedEntryLbl));
                    Fields.Add(ContractMgt.ResponseField('dataExchDefCode', 'string', DefinitionCodeLbl));
                    if MessageType = 'DataExchange.Export.Run' then
                        Fields.Add(ContractMgt.ResponseField('fileName', 'string', ExportFileNameLbl));
                end;
            'DataExchange.Type.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', MatchingCountLbl));
                    Fields.Add(ContractMgt.ResponseField('types', 'array', MatchingTypesLbl));
                end;
            'DataExchange.Definition.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', NumberOfMatchingDefinitionsLbl));
                    Fields.Add(ContractMgt.ResponseField('definitions', 'array', MatchingDefinitionsLbl));
                end;
            'DataExchange.Definition.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('code', 'string', TheDefinitionCodeLbl));
                    Fields.Add(ContractMgt.ResponseField('lineDefs', 'array', LineDefinitionsLbl));
                    Fields.Add(ContractMgt.ResponseField('columnDefs', 'array', ColumnDefinitionsLbl));
                    Fields.Add(ContractMgt.ResponseField('mappings', 'array', FieldMappingsLbl));
                end;
            'DataExchange.Entry.List':
                begin
                    Fields.Add(ContractMgt.ResponseField('skip', 'integer', PagingSkipLbl));
                    Fields.Add(ContractMgt.ResponseField('take', 'integer', PagingTakeLbl));
                    Fields.Add(ContractMgt.ResponseField('count', 'integer', NumberOfMatchingEntriesLbl));
                    Fields.Add(ContractMgt.ResponseField('entries', 'array', MatchingEntriesLbl));
                end;
            'DataExchange.Entry.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('skip', 'integer', PagingSkipLbl));
                    Fields.Add(ContractMgt.ResponseField('take', 'integer', PagingTakeLbl));
                    Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', TheEntryNumberLbl));
                    Fields.Add(ContractMgt.ResponseField('fields', 'array', PagedEntryFieldsLbl));
                    Fields.Add(ContractMgt.ResponseField('contentBase64', 'string', OptionalFileContentLbl));
                end;
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Builds the known errors returned by one message type.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if not (MessageType in ['Storage.Account.List', 'Help.Storage.Get', 'Help.DataExchange.Get', 'DataExchange.Type.List']) then begin
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingInputLbl, SupplyInputLbl));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidFormatLbl, CorrectInputLbl));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidInputLbl, CorrectInputLbl));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, MultipleInputLbl, CorrectInputLbl));
            if MessageType in ['DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Definition.Export', 'DataExchange.Import.Run', 'DataExchange.Export.Run'] then begin
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, MissingRecordLbl, ChooseRecordLbl));
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, UnusableDefinitionLbl, ChooseRecordLbl));
            end;
            if MessageType = 'DataExchange.Entry.Get' then
                Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, InlineLimitLbl, OmitInlineLbl));
        end;
        if MessageType in ['Storage.File.Create', 'Storage.Upload.Append'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, TheContentBase64ValueIsNotValidLbl, SendValidBase64ContentLbl));
        if MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ALinkedBusinessCentralAttachmentPreventsLbl, RestoreOrRemoveTheAttachmentFirstLbl));
        if MessageType = 'Storage.Directory.Delete' then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, TheDirectoryIsNotEmptyLbl, ListItsFilesAndSubdirectoriesRemoveLbl));
        if MessageType in ['Storage.Upload.Append', 'Storage.Upload.Commit', 'Storage.Upload.Abort', 'Storage.Upload.CommitToRecord'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, TheUploadSessionIsMissingClosedLbl, BeginANewSessionOrCompleteLbl));
        if MessageType in ['DataExchange.Definition.Get'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, TheDefinitionCodeDoesNotExistLbl, UseDataExchangeDefinitionListFirstLbl));
        if MessageType in ['DataExchange.Entry.Get'] then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, TheEntryNumberDoesNotExistLbl, UseDataExchangeEntryListFirstLbl));
        if MessageType.StartsWith('DataExchange.') then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, DataExchangeFailureLbl, DataExchangeFailureFixLbl))
        else
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, TheStorageConnectorRejectsOrCannotLbl, CheckThePathConnectionAndConnectorLbl));
    end;

    /// <summary>Builds the operation effect for one message type.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    begin
        case true of
            MessageType in ['DataExchange.Type.Set', 'DataExchange.Definition.Delete', 'DataExchange.Import.Run', 'DataExchange.Export.Run']:
                begin
                    Effect.Add('effect', 'write');
                    Effect.Add('changes', DataExchangeChangesLbl);
                end;
            MessageType in ['Storage.File.Delete', 'Storage.Directory.Delete']:
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', DeletesTheEntryInTheExternalLbl);
                end;
            MessageType = 'Storage.Attachment.Restore':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', WritesTheContentBackIntoTheLbl);
                end;
            MessageType = 'Storage.Attachment.Offload':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', LinksTheBusinessCentralAttachmentToLbl);
                end;
            MessageType = 'Storage.Upload.Commit':
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', AssemblesTheStagedChunksAndWritesLbl);
                end;
            MessageType in ['Storage.File.Create', 'Storage.File.Copy', 'Storage.File.Move', 'Storage.Directory.Create']:
                begin
                    Effect.Add('effect', 'irreversible');
                    Effect.Add('changes', WritesToTheExternalStorageTheLbl);
                end;
            MessageType in ['Storage.Attachment.CreateLinked', 'Storage.Attachment.CreateForRecord', 'Storage.Upload.Begin', 'Storage.Upload.Append', 'Storage.Upload.Abort', 'Storage.Upload.CommitToRecord']:
                begin
                    Effect.Add('effect', 'write');
                    Effect.Add('changes', WritesBusinessCentralRecordsOnlyUploadLbl);
                end;
            else begin
                Effect.Add('effect', 'read');
                Effect.Add('changes', ReadsOnlyNothingIsChangedLbl);
            end;
        end;
        Effect.Add('idempotent', MessageType in ['Storage.Account.List', 'Storage.File.List', 'Storage.File.Get', 'Storage.File.Exists', 'Storage.Directory.List', 'Storage.Directory.Exists', 'Storage.Upload.Status', 'DataExchange.Definition.List', 'DataExchange.Definition.Get', 'DataExchange.Type.List', 'DataExchange.Entry.List', 'DataExchange.Entry.Get']);
        // The Data Exchange tables are granted by BIFROST DataExch ori only; BIFROST Attach ori does not include them.
        if IsDataExchangeType(MessageType) then
            Effect.Add('permissionSet', 'BIFROST DataExch ori')
        else
            Effect.Add('permissionSet', 'BIFROST Attach ori');
        if IsDataExchangeType(MessageType) then
            Effect.Add('preconditions', DataExchangePreconditionsLbl)
        else
            Effect.Add('preconditions', TheStorageConnectionExistsIsEnabledLbl);
    end;

    /// <summary>Builds related message types for one message type.</summary>
    procedure GetRelated(MessageType: Text) Related: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Help.Storage.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Account.List', ChooseAConfiguredStorageConnectionLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.List', ListFilesInAStorageConnectionLbl));
                end;
            'Help.DataExchange.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', DiscoverAvailableDataExchangeDefinitionsLbl));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', ListProcessedDataExchangeEntriesLbl));
                end;
            'Storage.Account.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', ListFilesAfterChoosingAStorageCodeLbl));
            'Storage.File.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', ListSubdirectoriesInsteadOfFilesLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', DownloadOneListedFileLbl));
                end;
            'Storage.File.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Exists', CheckWhetherAFileExistsWithoutLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Create', UploadAFileInsteadOfDownloadingLbl));
                end;
            'Storage.File.Create':
                Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Begin', UploadAFileLargerThanTheLbl));
            'Storage.File.Delete':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Exists', CheckWhetherTheFileExistsFirstLbl));
            'Storage.File.Copy':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Move', MoveTheFileAndRemoveTheLbl));
            'Storage.File.Move':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.Copy', CopyTheFileWhileKeepingTheLbl));
            'Storage.Directory.List':
                Related.Add(ContractMgt.RelatedEntry('Storage.File.List', ListFilesInsteadOfSubdirectoriesLbl));
            'Storage.Directory.Create':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.Delete', RemoveADirectoryLbl));
            'Storage.Directory.Delete':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.Exists', CheckWhetherTheDirectoryExistsFirstLbl));
            'Storage.Directory.Exists':
                Related.Add(ContractMgt.RelatedEntry('Storage.Directory.List', ListTheDirectoryContentsLbl));
            'Storage.Attachment.Offload':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Restore', BringTheFileBackIntoTheLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Account.List', FindAStorageCodeLbl));
                end;
            'Storage.Attachment.Restore':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', MoveTheFileBackToStorageLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.CreateLinked', CreateANewLinkedAttachmentLbl));
                end;
            'Storage.Attachment.CreateLinked':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', UseThePathOfACommittedLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Restore', BringTheLinkedFileIntoTheLbl));
                end;
            'Storage.Attachment.CreateForRecord':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToRecord', AttachAChunkedUploadDirectlyToLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', MoveInlineContentToStorageLaterLbl));
                end;
            'Storage.Upload.Begin':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', SendEachChunkLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', WriteTheCompletedFileToStorageLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.CommitToRecord', AttachTheCompletedFileWithoutStorageLbl));
                end;
            'Storage.Upload.Append':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Status', CheckReceivedBytesLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', CommitTheCompletedUploadLbl));
                end;
            'Storage.Upload.Commit':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.File.Get', DownloadTheCommittedFileLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.CreateLinked', AttachTheCommittedFileLbl));
                end;
            'Storage.Upload.Abort':
                Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Begin', StartAFreshUploadLbl));
            'Storage.Upload.Status':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Append', SendAnotherChunkLbl));
                    Related.Add(ContractMgt.RelatedEntry('Storage.Upload.Commit', CommitWhenCompleteLbl));
                end;
            'Storage.Upload.CommitToRecord':
                Related.Add(ContractMgt.RelatedEntry('Storage.Attachment.Offload', MoveTheCreatedAttachmentToStorageLbl));
            'DataExchange.Definition.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', ReadOneDefinitionInFullLbl));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Type.List', SeeWhichTypeUsesADefinitionLbl));
                end;
            'DataExchange.Definition.Get':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', FindAnotherDefinitionCodeLbl));
            'DataExchange.Type.List':
                begin
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.List', ListAvailableDefinitionsLbl));
                    Related.Add(ContractMgt.RelatedEntry('DataExchange.Definition.Get', ReadTheReferencedDefinitionLbl));
                end;
            'DataExchange.Entry.List':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.Get', ReadOneEntryAndItsFieldsLbl));
            'DataExchange.Entry.Get':
                Related.Add(ContractMgt.RelatedEntry('DataExchange.Entry.List', FindAnotherEntryLbl));
        end;
    end;
}
