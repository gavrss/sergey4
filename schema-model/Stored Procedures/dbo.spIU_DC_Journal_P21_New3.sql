SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_DC_Journal_P21_New3]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@FiscalPeriodString nvarchar(1000) = NULL,
	@StartFiscalYear int = NULL,
	@SequenceBM int = 3, --1 = GL transactions, 2 = Opening balances, 4 = Budget transactions
	@JournalTable nvarchar(100) = NULL,
	@FullReloadYN bit = 0,
	@MaxSourceCounter bigint = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000945,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_DC_Journal_P21] @UserID = -10, @InstanceID = 515, @VersionID = 1064, @SequenceBM = 1, @Entity_MemberKey = 'REM', @Book = GL, @FiscalYear = 2023, @FiscalPeriod = 5, @DebugBM = 2

EXEC [spIU_DC_Journal_P21_New3] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@JSON nvarchar(max),
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@LinkedServer nvarchar(100),
	@Owner nvarchar(10),
	@EntityID int,
	@Currency nchar(3),
	@SQLStatement nvarchar(max),
	@SQLSegment nvarchar(max),
	@SegmentNo int = -1,
--	@AccountSourceCode nvarchar(50),
--	@AccountSegmentNo int,
--	@InvcHead_ExistsYN bit,
--	@Customer_ExistsYN bit,
--	@BalAcctDesc_ExistsYN bit,
--	@RevisionBM int,
	@SourceID int,
	@SourceTypeID int = 5,
	@SequenceOB int,
	@SourceTypeName nvarchar(50),
--	@InvoiceString nvarchar(max),
--	@MaxSourceBudgetCounter bigint = NULL,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into #Journal from source Epicor P21',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added ProductGroup.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added Customer, Supplier and Contact.'
		IF @Version = '2.1.1.2172' SET @Description = 'Set Segments default to empty string.'
		IF @Version = '2.1.1.2175' SET @Description = 'Add SSIS execute by SQLJob'
		IF @Version = '2.1.2.2191' SET @Description = 'Removed hardcoded Entity prefix for Segment01'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After Set StartTime', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
	
	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

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
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName]
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeID = @SourceTypeID
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF CHARINDEX('.', @SourceDatabase) <> 0
			SET @LinkedServer = REPLACE(REPLACE(LEFT(@SourceDatabase, CHARINDEX('.', @SourceDatabase) - 1), '[', ''), ']', '')

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @DebugBM & 2 > 0
			SELECT 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@Owner] = @Owner,
				[@StartFiscalYear] = @StartFiscalYear,
				[@SourceDatabase] = @SourceDatabase,
				[@LinkedServer] = @LinkedServer,
				[@Currency] = @Currency,
				[@EntityID] = @EntityID,
				[@Book] = @Book,
				[@JournalTable] = @JournalTable,
				[@SourceID] = @SourceID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName

		IF @SequenceBM & 3 > 0 AND @LinkedServer IS NOT NULL
			EXEC [spGet_Connection] @LinkedServer = @LinkedServer

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

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment

		WHILE @SegmentNo < 20
			BEGIN
				SET @SegmentNo = @SegmentNo + 1
				IF @SegmentNo = 0
					SELECT @SQLSegment = '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN SourceCode ELSE '''''' END) + ',' FROM #Segment
				ELSE
					SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @SegmentNo) + '] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN SourceCode ELSE '''''' END) + ',' FROM #Segment
			END

		IF @DebugBM & 2 > 0 PRINT @SQLSegment
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After creating some local temp tables', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

		IF @FiscalPeriod IS NOT NULL AND @FiscalPeriodString IS NULL
			SET @FiscalPeriodString = @FiscalPeriod

		IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@EntityID] = @EntityID, [@Book] = @Book, [@StartFiscalYear] = @StartFiscalYear, [@FiscalYear] = @FiscalYear, [@FiscalPeriodString] = @FiscalPeriodString

--		EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriodString = @FiscalPeriodString, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID
		EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriodString = @FiscalPeriodString, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID

		DELETE #FiscalPeriod WHERE FiscalYear > YEAR(GetDate())

		IF @DebugBM & 2 > 0  SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After filling temp table #FiscalPeriod', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Create temp table #BalanceAccount'
		CREATE TABLE #BalanceAccount
			(
			Account nvarchar(50) COLLATE DATABASE_DEFAULT,
			BalanceYN bit
			)

	SET @Step = 'Create temp table #Entity_Book_FiscalYear'
		IF OBJECT_ID(N'TempDB.dbo.#Entity_Book_FiscalYear', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Entity_Book_FiscalYear
					(
					[Entity_MemberKey] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [int],
					[StartFiscalYear] [int]
					)
			END

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
					[Segment01] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment02] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment03] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment04] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment05] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment06] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment07] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment08] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment09] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment10] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment11] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment12] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment13] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment14] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment15] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment16] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment17] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment18] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment19] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment20] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[JournalDate] [date],
					[TransactionDate] [date],
					[PostedDate] [date],
					[PostedStatus] [int],
					[PostedBy] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Customer] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Supplier] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] [nchar](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Book] [float],
					[ValueCredit_Book] [float],
					[Currency_Group] [nchar](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Group] [float],
					[ValueCredit_Group] [float],
					[Currency_Transaction] [nchar](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Transaction] [float],
					[ValueCredit_Transaction] [float],
					[SourceModule] [nvarchar](20) COLLATE DATABASE_DEFAULT,
					[SourceModuleReference] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[SourceCounter] [bigint],
					[SourceGUID] [uniqueidentifier]
					)
			END

	SET @Step = 'Insert into #BalanceAccount'
		IF @DebugBM & 16 > 0 SELECT [Step] = 'Before ' + @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

		INSERT INTO #BalanceAccount
			(
			Account,
			BalanceYN
			)
		SELECT
			Account = [Label],
			BalanceYN = [TimeBalance]
		FROM
			pcDATA_REM..S_DS_Account
		WHERE
			RNodeType = 'L'

								--delete		dspsource01.sergey_test.dbo.FiscalPeriod;
								--INSERT INTO dspsource01.sergey_test.dbo.FiscalPeriod (FiscalYear, FiscalPeriod, YearMonth)	SELECT FiscalYear, FiscalPeriod, YearMonth  FROM #FiscalPeriod 
								--delete		dspsource01.sergey_test.dbo.BalanceAccount;
								--INSERT INTO dspsource01.sergey_test.dbo.BalanceAccount SELECT *  FROM #BalanceAccount 

	SET @Step = 'Insert GL transactions into temp table #Journal'
		IF @SequenceBM & 1 > 0
			BEGIN
				IF @DebugBM & 16 > 0 SELECT [Step] = 'Before inserting rows into #Journal', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				SET @Step = 'Journal_Entity_Cursor'
					TRUNCATE TABLE #Entity_Book_FiscalYear

					INSERT INTO #Entity_Book_FiscalYear
						(
						[Entity_MemberKey],
						[Book],
						[FiscalYear],
						[StartFiscalYear]
						)
					SELECT DISTINCT
						[Entity_MemberKey] = @Entity_MemberKey,
						[Book] = @Book,
						[FiscalYear] = [FiscalYear],
						[StartFiscalYear] = MIN([FiscalYear])
					FROM
						#FiscalPeriod
					GROUP BY
						[FiscalYear]

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Entity_Book_FiscalYear', * FROM #Entity_Book_FiscalYear
					
					IF CURSOR_STATUS('global','Journal_Entity_Cursor') >= -1 DEALLOCATE Journal_Entity_Cursor
					DECLARE Journal_Entity_Cursor CURSOR FOR
			
						SELECT DISTINCT
							[Entity_MemberKey],
							[Book],
							[FiscalYear],
							[StartFiscalYear]
						FROM
							#Entity_Book_FiscalYear
						ORDER BY
							[Entity_MemberKey],
							[Book],
							[FiscalYear]

						OPEN Journal_Entity_Cursor
						FETCH NEXT FROM Journal_Entity_Cursor INTO @Entity_MemberKey, @Book, @FiscalYear, @StartFiscalYear

						WHILE @@FETCH_STATUS = 0
							BEGIN
								SELECT
									@EntityID = E.EntityID,
									@Currency = EB.Currency
								FROM
									pcINTEGRATOR_Data.dbo.Entity E
									INNER JOIN pcINTEGRATOR_Data.dbo.Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
								WHERE
									E.InstanceID = @InstanceID AND
									E.VersionID = @VersionID AND
									E.MemberKey = @Entity_MemberKey AND
									E.SelectYN <> 0

							
								IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@StartFiscalYear] = @StartFiscalYear

--								EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriodString = @FiscalPeriodString, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID

--								IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth

								--Fill temp table #Segment
								--TRUNCATE TABLE #Segment
								--INSERT INTO #Segment
								--	(
								--	SourceCode,
								--	SegmentNo,
								--	DimensionName
								--	)
								--SELECT 
								--	JSN.SourceCode,
								--	JSN.SegmentNo,
								--	D.DimensionName
								--FROM
								--	pcINTEGRATOR_Data.dbo.Journal_SegmentNo JSN
								--	LEFT JOIN Dimension D ON D.DimensionID = JSN.DimensionID
								--WHERE
								--	JSN.InstanceID = @InstanceID AND
								--	VersionID = @VersionID AND
								--	EntityID = @EntityID AND
								--	Book = @Book

								--IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment ORDER BY SegmentNo

								--Set variable @SQLSegment
								--SELECT @SegmentNo = -1, @SQLSegment = ''
								--WHILE @SegmentNo < 20
								--	BEGIN
								--		SET @SegmentNo = @SegmentNo + 1
								--		IF @SegmentNo = 0
								--			SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'GLD.[' + SourceCode + ']' ELSE '''''' END) + ',' FROM #Segment
								--		ELSE
								--			SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @SegmentNo) + '] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'GLD.[' + SourceCode + ']' ELSE '''''' END) + ',' FROM #Segment
								--	END

								--IF @DebugBM & 2 > 0 PRINT @SQLSegment
								
								--IF @DebugBM & 2 > 0 PRINT @SQLStatement
								--IF  @LinkedServer IS NOT NULL EXEC [spGet_Connection] @LinkedServer = @LinkedServer
								--EXEC (@SQLStatement)

								IF @DebugBM & 2 > 0 
									SELECT
										[@JobID] = @JobID,
										[@ProcedureID] = @ProcedureID,
										[@InstanceID] = @InstanceID,
										[@Entity_MemberKey] = @Entity_MemberKey,
										[@SQLSegment] = @SQLSegment,
										[@Currency] = @Currency,
										[@SourceDatabase] = @SourceDatabase,
										[@Owner] = @Owner,
										[@Entity_MemberKey] = @Entity_MemberKey,
										[@Book] = @Book,
										[@FiscalYear] = @FiscalYear


										--Fill temp table #Journal
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
--						[Segment02],
						[Segment03],
						[JournalDate],
						[TransactionDate],
						[PostedDate],
						[PostedStatus],
						[PostedBy],
						[Source],
						[Scenario],
						[Customer],
						[Supplier],
						[Description_Head],
						[Description_Line],
						[Currency_Book],
						[ValueDebit_Book],
						[ValueCredit_Book],
						[Currency_Transaction],
						[ValueDebit_Transaction],
						[ValueCredit_Transaction],
						[SourceModule],
						[SourceModuleReference],
						[SourceCounter],
						[SourceGUID]
						)
					SELECT
						[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
						[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
						[Entity] = ''' + @Entity_MemberKey + ''',
						[Book] = ''' + @Book + ''',
						[FiscalYear] = FP.[FiscalYear],
						[FiscalPeriod] = CASE WHEN GL.[source] = ''BF'' THEN 0 ELSE FP.[FiscalPeriod] END,
						[JournalSequence] = GL.[journal_id],
						[JournalNo] = CONVERT(nvarchar(50), GL.[transaction_number]),
						[JournalLine] = GL.[sequence_number],
						[YearMonth] = FP.[YearMonth],
						[TransactionTypeBM] = 1,
						[BalanceYN] = ISNULL(BA.[BalanceYN], 0),
						[Account] = SUBSTRING(GL.[account_number], 1, 4) + ''-'' + SUBSTRING(GL.[account_number], 5, 4),
						[Segment01] = ISNULL(CONVERT(nvarchar(50), SUBSTRING(GL.[account_number], 9, 4)), ''''),
--						[Segment02] = ISNULL(CONVERT(nvarchar(50), [IL].[product_group_id]), ''''),
						[Segment03] = ISNULL(CONVERT(nvarchar(50), AR.[salesrep_id]), ''''),
						[JournalDate] = CONVERT(date, GL.[transaction_date]),
						[TransactionDate] = CONVERT(date, GL.[transaction_date]),
						[PostedDate] = CONVERT(date, GL.[date_last_modified]),
						[PostedStatus] = CASE WHEN GL.[approved] = ''Y'' THEN 1 ELSE 0 END,
						[PostedBy] = GL.[last_maintained_by],
						[Source] = ''' + @SourceTypeName + ''',
						[Scenario] = ''ACTUAL'',
						[Customer] = CONVERT(nvarchar(50), AR.[customer_id]),
						[Supplier] = CONVERT(nvarchar(50), AP.[vendor_id]),
						[Description_Head] = NULL,
						[Description_Line] = GL.[Description],
						[Currency_Book] = ''' + @Currency + ''',
						[ValueDebit_Book] = CASE WHEN GL.[amount] > 0 THEN GL.[amount] ELSE 0 END,
						[ValueCredit_Book] = CASE WHEN GL.[amount] < 0 THEN GL.[amount] * -1 ELSE 0 END,
						[Currency_Transaction] = NULL,
						[ValueDebit_Transaction] = NULL,
						[ValueCredit_Transaction] = NULL,
						[SourceModule] = GL.[journal_id],
						[SourceModuleReference] = GL.[source],
						[SourceCounter] = GL.[gl_uid],
						[SourceGUID] = NULL
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[GL] GL
						INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GL.[year_for_period] AND FP.[FiscalPeriod] = GL.[period]
						LEFT JOIN #BalanceAccount BA ON BA.Account = SUBSTRING(GL.[account_number], 1, 4) + ''-'' + SUBSTRING(GL.[account_number], 5, 4)
						LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[invoice_hdr] AR ON GL.[journal_id] = ''SJ'' AND CONVERT(varchar(255), AR.[invoice_no]) = GL.[source]
						LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[apinv_hdr] AP ON GL.[journal_id] = ''PJ'' AND CONVERT(varchar(255), AP.[voucher_no]) = GL.[source]
					WHERE
								GL.[company_no] = ''' + @Entity_MemberKey + ''' AND
								GL.[year_for_period] = ' + CONVERT(nvarchar(10), @FiscalYear) 
								/*+ 
								 CASE WHEN @MaxSourceCounter IS NULL THEN ''
										ELSE ' AND GL.[gl_uid] > ' + CAST(@MaxSourceCounter AS VARCHAR(255))
										END;*/



										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										IF  @LinkedServer IS NOT NULL EXEC [spGet_Connection] @LinkedServer = @LinkedServer
										EXEC(@SQLStatement)
-- ****************** SEGA: hardcoded for a short time **********************

										--UPDATE dspsource01.sergey_test.dbo.FiscalPeriod
										--SET 
										--	   [JobID]				= ISNULL(@JobID, @ProcedureID)
										--	  ,[InstanceID]			= @InstanceID
										--	  ,[Entity]				= @Entity_MemberKey
										--	  ,[Book]				= @Book
										--	  ,[Source]				= @SourceTypeName
										--	  ,[Currency_Book]		= @Currency
										--	  ,[company_no]			= @Entity_MemberKey
										--	  ,[year_for_period]	= @FiscalYear
 
 /*
										IF OBJECT_ID(N'TempDB.dbo.##JournalGlobal', N'U') IS NULL
													SELECT * INTO ##JournalGlobal FROM #Journal WHERE 1=0;
													ELSE TRUNCATE TABLE ##JournalGlobal;
										exec start_job_and_wait @job_name = 'REMichel_SSIS';
										--IF (SELECT COUNT(1) FROM #Journal) = 0
										--	ALTER TABLE ##JournalGlobal SWITCH TO #Journal;
										--	ELSE 
										IF @DebugBM & 2 > 0 PRINT CONVERT(TIME(7), GETDATE());
										INSERT INTO #Journal WITH (TABLOCK) SELECT * FROM ##JournalGlobal;
										SET @Selected = @Selected + @@ROWCOUNT
										SELECT @Selected
										TRUNCATE TABLE ##JournalGlobal;
										IF @DebugBM & 2 > 0 PRINT CONVERT(TIME(7), GETDATE());
*/										
-- ***************** SEGA: below is original code *****************
										--IF @DebugBM & 2 > 0 PRINT CONVERT(TIME(7), GETDATE());
										--EXEC (@SQLStatement)
										--SET @Selected = @Selected + @@ROWCOUNT
										--SELECT @Selected
										--IF @DebugBM & 2 > 0 PRINT CONVERT(TIME(7), GETDATE());
-- ***************************************************************

								FETCH NEXT FROM Journal_Entity_Cursor INTO @Entity_MemberKey, @Book, @FiscalYear, @StartFiscalYear
							END

						CLOSE Journal_Entity_Cursor
						DEALLOCATE Journal_Entity_Cursor
			END

	SET @Step = 'Return rows'
		IF @CalledYN = 0 OR @DebugBM & 8 > 0
			BEGIN
				SELECT TempTable = '#Journal', * FROM #Journal ORDER BY FiscalYear, FiscalPeriod, Account, Segment01, Segment02
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #FiscalPeriod
		DROP TABLE #Segment
		DROP TABLE #BalanceAccount
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #Journal
				DROP TABLE #Entity_Book_FiscalYear
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
