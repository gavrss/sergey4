SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_Axapta]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@StartFiscalYear int = NULL,
	@SequenceBM int = 3, --1 = GL transactions, 2 = Opening balances, 4 = Budget transactions
	@JournalTable nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000642,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Journal_Axapta',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "Entity_MemberKey",  "TValue": "52982"},
		{"TKey" : "Book",  "TValue": "CBN_Main"}
		]',
	@Debug = 1

EXEC [spIU_DC_Journal_Axapta] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '52982', @Book = 'CBN_Main', @FiscalYear = 2020, @SequenceBM = 2, @Debug = 1
EXEC [spIU_DC_Journal_Axapta] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '52982', @Book = 'CBN_Main', @Debug = 1
EXEC [spIU_DC_Journal_Axapta] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '52982C', @Book = 'CBN_Main', @Debug = 1
EXEC [spIU_DC_Journal_Axapta] @UserID = -10, @InstanceID = 451, @VersionID = 1019, @Entity_MemberKey = 'ATL', @Book = 'MAIN', @SequenceBM = 4, @Debug = 1

EXEC [spIU_DC_Journal_Axapta] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@Owner nvarchar(10),
	@EntityID int,
	@Currency nchar(3),
	@SQLStatement nvarchar(max),
	@SQLSegment nvarchar(max),
	@SegmentNo int = -1,
	@AccountSourceCode nvarchar(50),
	@AccountSegmentNo int,
	@BalAcctDesc_ExistsYN bit,
	@RevisionBM int,
	@SourceID int,
	@SourceTypeID int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into #Journal from source Axapta',
			@MandatoryParameter = 'Entity_MemberKey|Book' --Without @, separated by |

		IF @Version = '2.0.3.2151' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@EntityID = E.EntityID,
			@Currency = EB.Currency
		FROM
			Entity E
			INNER JOIN Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.MemberKey = @Entity_MemberKey AND
			E.SelectYN <> 0

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = ST.[Owner],
			@StartFiscalYear = ISNULL(@StartFiscalYear, S.StartYear),
			@SourceID = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID]
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = 1
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF @SourceTypeID = 11 
			EXEC [spGet_Revision] @SourceID = @SourceID, @RevisionBM = @RevisionBM OUT
		ELSE
			SET @RevisionBM = 1

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @Debug <> 0
			SELECT 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@Owner] = @Owner,
				[@SourceDatabase] = @SourceDatabase,
				[@Currency] = @Currency,
				[@EntityID] = @EntityID,
				[@Book] = @Book,
				[@JournalTable] = @JournalTable

	SET @Step = 'Create temp table #Segment'
		CREATE TABLE #Segment
			(
			SourceCode nvarchar(50),
			SegmentNo int,
			DimensionName nvarchar(50)
			)

	SET @Step = 'Fill temp table #Segment'
		INSERT INTO #Segment
			(
			SourceCode,
			SegmentNo,
			DimensionName
			)
		SELECT 
			JSN.SourceCode,
			JSN.SegmentNo,
			D.DimensionName
		FROM
			Journal_SegmentNo JSN
			LEFT JOIN Dimension D ON D.DimensionID = JSN.DimensionID
		WHERE
			EntityID = @EntityID AND
			Book = @Book

		IF @Debug <> 0 SELECT TempTable = '#Segment', * FROM #Segment

		WHILE @SegmentNo < 20
			BEGIN
				SET @SegmentNo = @SegmentNo + 1
				IF @SegmentNo = 0
					SELECT @SQLSegment = '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN SourceCode ELSE '''''' END) + ',' FROM #Segment
				ELSE
					SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @SegmentNo) + '] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN SourceCode ELSE '''''' END) + ',' FROM #Segment
			END

		IF @Debug <> 0 PRINT @SQLSegment


	SET @Step = 'Get Segment for Account'
		SELECT
			@AccountSourceCode = SourceCode,
			@AccountSegmentNo = LEFT(stuff(SourceCode, 1, patindex('%[0-9]%', SourceCode)-1, ''), 1)
		FROM
			#Segment
		WHERE
			SegmentNo = 0
		IF @Debug <> 0 SELECT AccountSourceCode = @AccountSourceCode, AccountSegmentNo = @AccountSegmentNo

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

		IF @Debug <> 0 SELECT UserID = @UserID, InstanceID = @InstanceID, VersionID = @VersionID, EntityID = @EntityID, Book = @Book, StartFiscalYear = @StartFiscalYear, FiscalYear = @FiscalYear, FiscalPeriod = @FiscalPeriod
		
		EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriod = @FiscalPeriod, @JobID = @JobID

		IF @Debug <> 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth

	SET @Step = 'Create temp table #BalanceAccount'
		CREATE TABLE #BalanceAccount
			(
			Company nvarchar(8) COLLATE DATABASE_DEFAULT,
			COACode nvarchar(10) COLLATE DATABASE_DEFAULT,
			Account nvarchar(50) COLLATE DATABASE_DEFAULT,
			BalanceYN bit
			)

	SET @Step = 'Create temp table #Journal'
		IF OBJECT_ID(N'TempDB.dbo.#Journal', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Journal
					(
					[JobID] [int],
					[InstanceID] [int],
					[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [int],
					[FiscalPeriod] [int],
					[JournalSequence] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalNo] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalLine] [int],
					[YearMonth] [int],
					[TransactionTypeBM] [int],
					[BalanceYN] [bit],
					[Account] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment01] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment02] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment03] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment04] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment05] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment06] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment07] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment08] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment09] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment10] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment11] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment12] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment13] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment14] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment15] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment16] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment17] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment18] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment19] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment20] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalDate] [date],
					[TransactionDate] [date],
					[PostedDate] [date],
					[PostedStatus] [int],
					[PostedBy] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] [nchar](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Book] [float],
					[ValueCredit_Book] [float],
					[SourceModule] [nvarchar](20) COLLATE DATABASE_DEFAULT,
					[SourceModuleReference] [nvarchar](100) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Fill temptable #BalanceAccount'
		IF @SequenceBM & 5 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #BalanceAccount
						(
						Company,
						COACode,
						Account,
						BalanceYN
						)
					SELECT DISTINCT
						COASV.Company,
						COASV.COACode,
						Account = COASV.SegmentCode,
						BalanceYN = CASE WHEN COA.[Type] = ''B'' THEN 1 ELSE 0 END
					FROM
						' + @SourceDatabase + '.[Erp].[COASegValues] COASV 
						INNER JOIN ' + @SourceDatabase + '.[Erp].[COAActCat] COA ON COA.Company = COASV.Company AND COA.CategoryID = COASV.Category
					WHERE
						COASV.SegmentNbr = ' + CONVERT(nvarchar(10), @AccountSegmentNo)

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Insert GL transactions into temp table #Journal'
		IF @SequenceBM & 1 > 0
			BEGIN
				SET @SQLStatement = '
			INSERT INTO #Journal
				(
				[JobID],
				[InstanceID],
				[Entity],
				[Book],
				[FiscalYear],
				[FiscalPeriod],
				[JournalSequence],
				[JournalNo],
				[JournalLine],
				[YearMonth],
				[TransactionTypeBM],
				[BalanceYN],
				[Account],
				[Segment01],
				[Segment02],
				[Segment03],
				[Segment04],
				[Segment05],
				[Segment06],
				[Segment07],
				[Segment08],
				[Segment09],
				[Segment10],
				[Segment11],
				[Segment12],
				[Segment13],
				[Segment14],
				[Segment15],
				[Segment16],
				[Segment17],
				[Segment18],
				[Segment19],
				[Segment20],
				[JournalDate],
				[TransactionDate],
				[PostedDate],
				[PostedStatus],
				[PostedBy],
				[Source],
				[Scenario],
--				[Description_Head],
				[Description_Line],
				[Currency_Book],
				[ValueDebit_Book],
				[ValueCredit_Book],
				[SourceModule],
				[SourceModuleReference]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[Entity] = ''' + @Entity_MemberKey + ''',
--				[Book] = GLH.BookID,
				[Book] = GLD.BookID,
				[FiscalYear] = GLD.[FiscalYear],
				[FiscalPeriod] = GLD.[FiscalPeriod],
				[JournalSequence] = GLD.[SourceModule],
				[JournalNo] = CONVERT(nvarchar(50), GLD.[JournalNum]),
				[JournalLine] = GLD.[JournalLine],
				[YearMonth] = FP.[YearMonth],
				[TransactionTypeBM] = 1,
				[BalanceYN] = ISNULL(B.BalanceYN, 0),
				' + @SQLSegment + '
				[JournalDate] = GLD.[JEDate],
--				[TransactionDate] = GLH.[GlbPostedDate],
				[TransactionDate] = GLD.[PostedDate],
				[PostedDate] = GLD.[PostedDate],
				[PostedStatus] = GLD.[Posted],
				[PostedBy] = GLD.[PostedBy],
				[Source] = ''E10'',
				[Scenario] = ''ACTUAL'',
--				[Description_Head] = GLH.[Description] + CASE WHEN LEN(GLH.[CommentText]) > 0 THEN '', '' + LEFT(GLH.[CommentText], 200) ELSE '''' END,
				[Description_Line] = GLD.[Description],
				[Currency_Book] = ''' + @Currency + ''',
				[ValueDebit_Book] = GLD.BookDebitAmount,
				[ValueCredit_Book] = GLD.BookCreditAmount,
				[SourceModule] = GLD.SourceModule,
				[SourceModuleReference] = CASE GLD.SourceModule WHEN ''AR'' THEN CONVERT(nvarchar(100), GLD.ARInvoiceNum) WHEN ''AP'' THEN GLD.APInvoiceNum ELSE '''' END
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[GLJrnDtl] GLD
--				' + @SourceDatabase + '.[' + @Owner + '].[GLJrnHed] GLH
--				INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLJrnDtl] GLD ON GLD.Company = GLH.Company AND GLD.FiscalYear = GLH.FiscalYear AND GLD.JournalNum = GLH.JournalNum AND GLD.JournalCode = GLH.JournalCode AND GLD.BookID = GLH.BookID AND GLD.FiscalYearSuffix = GLH.FiscalYearSuffix
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GLD.[FiscalYear] AND FP.[FiscalPeriod] = GLD.[FiscalPeriod]
				LEFT JOIN #BalanceAccount B on B.Company = GLD.Company COLLATE DATABASE_DEFAULT AND B.COACode = GLD.COACode COLLATE DATABASE_DEFAULT AND B.Account = GLD.' + @AccountSourceCode + ' COLLATE DATABASE_DEFAULT
			WHERE
				GLD.[Company] = ''' + @Entity_MemberKey + ''' AND
				GLD.[BookID] = ''' + @Book + ''''
--				GLH.[Company] = ''' + @Entity_MemberKey + ''' AND
--				GLH.[BookID] = ''' + @Book + '''
				+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'GLD.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) END
				+ CASE WHEN @FiscalPeriod IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'GLD.[FiscalPeriod] = ' + CONVERT(nvarchar(10), @FiscalPeriod) END

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Insert opening balances into temp table #Journal'
		IF @SequenceBM & 2 > 0
			BEGIN
				EXEC spGet_ColumnExistsYN @DatabaseName = @SourceDatabase, @TableName = 'GLPeriodBal', @ColumnName = 'BalAcctDesc', @ExistsYN = @BalAcctDesc_ExistsYN OUT

				SET @SQLStatement = '
			INSERT INTO #Journal
				(
				[JobID],
				[InstanceID],
				[Entity],
				[Book],
				[FiscalYear],
				[FiscalPeriod],
				[JournalSequence],
				[JournalNo],
				[JournalLine],
				[YearMonth],
				[TransactionTypeBM],
				[BalanceYN],
				[Account],
				[Segment01],
				[Segment02],
				[Segment03],
				[Segment04],
				[Segment05],
				[Segment06],
				[Segment07],
				[Segment08],
				[Segment09],
				[Segment10],
				[Segment11],
				[Segment12],
				[Segment13],
				[Segment14],
				[Segment15],
				[Segment16],
				[Segment17],
				[Segment18],
				[Segment19],
				[Segment20],
				[JournalDate],
				[TransactionDate],
				[PostedDate],
				[PostedStatus],
				[PostedBy],
				[Source],
				[Scenario],
				[Description_Head],
				[Description_Line],
				[Currency_Book],
				[ValueDebit_Book],
				[ValueCredit_Book]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[Entity] = ''' + @Entity_MemberKey + ''',
				[Book] = GLPB.BookID,
				[FiscalYear] = GLPB.[FiscalYear],
				[FiscalPeriod] = GLPB.[FiscalPeriod],
				[JournalSequence] = ''OB_ERP'',
				[JournalNo] = ''0'',
				[JournalLine] = 0,
				[YearMonth] = FP.[YearMonth],
				[TransactionTypeBM] = 4,
				[BalanceYN] = 1,
				' + @SQLSegment + '
				[JournalDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
				[TransactionDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
				[PostedDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
				[PostedStatus] = 1,
				[PostedBy] = '''',
				[Source] = ''E10'',
				[Scenario] = ''ACTUAL'',
				[Description_Head] = ''Opening balance'',
				[Description_Line] = ' + CASE WHEN @BalAcctDesc_ExistsYN <> 0 THEN 'GLPB.[BalAcctDesc]' ELSE '''''' END + ',
				[Currency_Book] = ''' + @Currency + ''',
				[ValueDebit_Book] = CASE WHEN GLPB.OpenBalance >= 0 THEN GLPB.OpenBalance ELSE 0 END,
				[ValueCredit_Book] = CASE WHEN GLPB.OpenBalance < 0 THEN -1 * GLPB.OpenBalance ELSE 0 END
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[GLPeriodBal] GLPB
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GLPB.[FiscalYear] AND FP.[FiscalPeriod] = 1
			WHERE
				GLPB.[Company] = ''' + @Entity_MemberKey + ''' AND
				GLPB.[BookID] = ''' + @Book + ''' AND
				GLPB.[FiscalPeriod] = 0 AND
				GLPB.[BalanceType] = ''D'''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT

				IF @Debug <> 0 SELECT UserID = @UserID, InstanceID = @InstanceID, VersionID = @VersionID, Entity_MemberKey = @Entity_MemberKey, Book = @Book, StartFiscalYear = @StartFiscalYear, SequenceBM = @SequenceBM, Debug = @Debug
				EXEC [spIU_DC_Journal_OpeningBalance] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Entity_MemberKey = @Entity_MemberKey, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @SequenceBM = 2, @JournalTable = @JournalTable, @JobID = @JobID, @Debug = @Debug
			END

	SET @Step = 'Insert financial budget into temp table #Journal'

		IF @SequenceBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
			INSERT INTO #Journal
				(
				[JobID],
				[InstanceID],
				[Entity],
				[Book],
				[FiscalYear],
				[FiscalPeriod],
				[JournalSequence],
				[JournalNo],
				[JournalLine],
				[YearMonth],
				[TransactionTypeBM],
				[BalanceYN],
				[Account],
				[Segment01],
				[Segment02],
				[Segment03],
				[Segment04],
				[Segment05],
				[Segment06],
				[Segment07],
				[Segment08],
				[Segment09],
				[Segment10],
				[Segment11],
				[Segment12],
				[Segment13],
				[Segment14],
				[Segment15],
				[Segment16],
				[Segment17],
				[Segment18],
				[Segment19],
				[Segment20],
				[JournalDate],
				[TransactionDate],
				[PostedDate],
				[PostedStatus],
				[PostedBy],
				[Source],
				[Scenario],
				[Description_Head],
				[Description_Line],
				[Currency_Book],
				[ValueDebit_Book],
				[ValueCredit_Book]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[Entity] = ''' + @Entity_MemberKey + ''',
				[Book] = GLBD.BookID,
				[FiscalYear] = GLBD.[FiscalYear],
				[FiscalPeriod] = GLBD.[FiscalPeriod],
				[JournalSequence] = ''Budget'',
				[JournalNo] = ''0'',
				[JournalLine] = 0,
				[YearMonth] = FP.[YearMonth],
				[TransactionTypeBM] = 1,
				[BalanceYN] = ISNULL(B.BalanceYN, 0),
				' + @SQLSegment + '
				[JournalDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
				[TransactionDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
				[PostedDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
				[PostedStatus] = 1,
				[PostedBy] = '''',
				[Source] = ''E10'',
				[Scenario] = ' + CASE WHEN @RevisionBM & 1 > 0 THEN '''BUDGET_ERP''' ELSE 'GLBD.[BudgetCodeID]' END + ',
				[Description_Head] = ''Budget'',
				[Description_Line] = ' + CASE WHEN @RevisionBM & 1 > 0 THEN '''BUDGET_ERP''' ELSE 'GLBD.[BudgetCodeID]' END + ',
				[Currency_Book] = ''' + @Currency + ''',
				[ValueDebit_Book] = CASE WHEN GLBD.[BudgetAmt] >= 0 THEN GLBD.[BudgetAmt] ELSE 0 END,
				[ValueCredit_Book] = CASE WHEN GLBD.[BudgetAmt] < 0 THEN -1 * GLBD.[BudgetAmt] ELSE 0 END
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[GLBudgetDtl] GLBD
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GLBD.[FiscalYear] AND FP.[FiscalPeriod] = GLBD.[FiscalPeriod]
				LEFT JOIN #BalanceAccount B on B.Company = GLBD.Company COLLATE DATABASE_DEFAULT AND B.COACode = GLBD.COACode COLLATE DATABASE_DEFAULT AND B.Account = GLBD.' + @AccountSourceCode + ' COLLATE DATABASE_DEFAULT
			WHERE
				GLBD.[Company] = ''' + @Entity_MemberKey + ''' AND
				GLBD.[BookID] = ''' + @Book + ''' AND
				GLBD.[BudgetAmt] <> 0 AND
				GLBD.[BalanceType] = ''D'''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT

--SELECT * FROM [DSPSOURCE01].[pcSource_ausmtspilot102_cbn].[Erp].[GLBudgetDtl] F
--SELECT * FROM [DSPSOURCE03].[CCM_Epicor10].[Erp].[GLBudgetDtl]

			END

		IF @Debug <> 0 SELECT TempTable = '#Journal', * FROM #Journal ORDER BY FiscalYear, FiscalPeriod, Account, Segment01, Segment02

	SET @Step = 'Fill Journal table'
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = '#Journal', * FROM #Journal
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Segment
		DROP TABLE #BalanceAccount
		IF @CalledYN = 0 DROP TABLE #Journal

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
