SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_OpeningBalance_New]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@SequenceBM int = 0, --2 = Called from SP holding #Journal filled with transactions
	@JournalTable nvarchar(100) = NULL,
	@SaveToJournalYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000635,
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
EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Journal_OpeningBalance] @UserID='-10',@InstanceID='603',@VersionID='1095',@Book='GL',@Entity_MemberKey='Honematic',@FiscalYear='2022',@SaveToJournalYN=0, @DebugBM = 2
EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Journal_OpeningBalance_New] @UserID=-10, @InstanceID=672, @VersionID=1132, @Book='GL',@Entity_MemberKey='AAH',@FiscalYear='2021',@SaveToJournalYN=0, @DebugBM = 2

EXEC pcINTEGRATOR..[spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 572, @VersionID = 1080, @Entity_MemberKey = 'BR01',
@Book = 'Main', @FiscalYear = 2020, @SaveToJournalYN=1, @DebugBM = 15

EXEC spIU_DC_Journal_OpeningBalance @Book='MAIN_CSI',@Debug='1',@Entity_MemberKey='159491IP',@FiscalYear='2021',
@InstanceID='548',@JobID='29582',@JournalTable='[pcETL_CST].[dbo].[Journal]',
@SequenceBM='0',@UserID='-10',@VersionID='1061',@SaveToJournalYN=1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Journal_OpeningBalance',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "Entity_MemberKey",  "TValue": "52982"},
		{"TKey" : "Book",  "TValue": "CBN_Main"}
		]',
	@Debug = 1

EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '52982', @Book = 'CBN_Main', @Debug = 1
EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '16', @Book = 'GL', @Debug = 1
EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '1', @Book = 'GL', @StartFiscalYear = 2019, @Debug = 1
EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 428, @VersionID = 1001, @Entity_MemberKey = '1', @Book = 'GL', @StartFiscalYear = 2001, @FiscalYear = 2018, @Debug = 1
EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 448, @VersionID = 1018, @Entity_MemberKey = '1', @Book = 'GL', @StartFiscalYear = 2019, @FiscalYear = 2019, @Debug = 1
EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @Entity_MemberKey = 'ASF', @Book = 'MAIN', @StartFiscalYear = 2018, @FiscalYear = 2018, @Debug = 1

EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @Entity_MemberKey = 'R510', @Book = 'MAIN', @FiscalYear = 2020, @Debug = 1
EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 476, @VersionID = 1029, @Entity_MemberKey = '1001', @Book = 'MAIN', @FiscalYear = 2020, @DebugBM = 2

EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '52982A', @Book = 'OB_MAIN', @FiscalYear = 2021, @DebugBM = 2
EXEC [spIU_DC_Journal_OpeningBalance] @UserID = -10, @InstanceID = 515, @VersionID = 1064, @Entity_MemberKey = 'REM', @Book = 'GL', @FiscalYear = 2020, @SaveToJournalYN=1, @DebugBM = 2

EXEC [spIU_DC_Journal_OpeningBalance] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
--	@YearMonth int,
	@SQLStatement nvarchar(max),
	@EntityID int,
	@PYNI_B float,
	@Currency nchar(3),
	@Account_RE nvarchar(50),     -- Added by KEHa and JaWo in New for testing

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert opening balances into #Journal/Journal.',
			@MandatoryParameter = 'Entity_MemberKey|Book|FiscalYear' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]. Implemented [spGet_JournalTable].'
		IF @Version = '2.0.2.2148' SET @Description = 'Enhanced debugging. Fixing bugs for running standalone. Introduce PYNI_B calculation, Previous Year Net Income.'
		IF @Version = '2.0.3.2151' SET @Description = 'Updated datatypes in temp table #Journal.'
		IF @Version = '2.0.3.2152' SET @Description = 'Loop FiscalYears and FiscalPeriods independent of Entity and Book.'
		IF @Version = '2.0.3.2153' SET @Description = 'Removed parameter @StartFiscalYear.'
		IF @Version = '2.0.3.2154' SET @Description = 'Handle variable set of segments when creating OB_ADJ rows.'
		IF @Version = '2.1.0.2157' SET @Description = 'Handle variable FiscalYearStartMonth within same Instance.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2172' SET @Description = 'Handle source = MANUAL. Added parameter @SaveToJournalYN.'
		IF @Version = '2.1.1.2173' SET @Description = 'Modify INSERT query for #FiscalYearMonth.'
		IF @Version = '2.1.2.2179' SET @Description = 'Remove references to manually entries. Inserted by another routine (spSet_Journal_OP_ManAdj).'
		IF @Version = '2.1.2.2180' SET @Description = 'Changed to INNER JOIN clause for OB_ERP (OB_ADJ should only be created when OB_ERP exists).'
		IF @Version = '2.1.2.2187' SET @Description = 'Added DELETE query for existing OB_JRN (for @Entity_MemberKey, @Book, @FiscalYear and FiscalPeriod=0).'
		IF @Version = '2.1.2.2197' SET @Description = 'Modified how to fill cursor table #FiscalYearMonth, (Fixed an issue for first year).'
		IF @Version = '2.1.2.2199' SET @Description = 'Special case for #FiscalYear table, @InstanceID = 603, @VersionID = 1095, @Entity_MemberKey = Honematic, @Book = GL, @FiscalYear = 2022, Group by PostedStatus'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		SELECT @EntityID = EntityID FROM Entity WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND MemberKey = @Entity_MemberKey
		SELECT @Currency = Currency FROM Entity_Book WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND EntityID = @EntityID AND Book = @Book

		-- Added by KEHa and JaWo in New for testing
		SELECT @Account_RE = LTRIM(RTRIM(EPV.[EntityPropertyValue]))
		FROM  [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV 
		WHERE EPV.[InstanceID] = @InstanceID AND EPV.[VersionID] = @VersionID AND EPV.[EntityID] = @EntityID AND EPV.[EntityPropertyTypeID] = -10 AND EPV.[SelectYN] <> 0


		IF @DebugBM & 2 > 0 SELECT [@InstanceID] = @InstanceID, [@EntityID] = @EntityID, [@JournalTable] = @JournalTable, [@Account_RE] = @Account_RE

	SET @Step = 'Create temp table #SegmentNo'
		SELECT
			[Account]   = MAX(CASE WHEN SegmentNo =  0 THEN 1 ELSE 0 END),
			[Segment01] = MAX(CASE WHEN SegmentNo =  1 THEN 1 ELSE 0 END),
			[Segment02] = MAX(CASE WHEN SegmentNo =  2 THEN 1 ELSE 0 END),
			[Segment03] = MAX(CASE WHEN SegmentNo =  3 THEN 1 ELSE 0 END),
			[Segment04] = MAX(CASE WHEN SegmentNo =  4 THEN 1 ELSE 0 END),
			[Segment05] = MAX(CASE WHEN SegmentNo =  5 THEN 1 ELSE 0 END),
			[Segment06] = MAX(CASE WHEN SegmentNo =  6 THEN 1 ELSE 0 END),
			[Segment07] = MAX(CASE WHEN SegmentNo =  7 THEN 1 ELSE 0 END),
			[Segment08] = MAX(CASE WHEN SegmentNo =  8 THEN 1 ELSE 0 END),
			[Segment09] = MAX(CASE WHEN SegmentNo =  9 THEN 1 ELSE 0 END),
			[Segment10] = MAX(CASE WHEN SegmentNo = 10 THEN 1 ELSE 0 END),
			[Segment11] = MAX(CASE WHEN SegmentNo = 11 THEN 1 ELSE 0 END),
			[Segment12] = MAX(CASE WHEN SegmentNo = 12 THEN 1 ELSE 0 END),
			[Segment13] = MAX(CASE WHEN SegmentNo = 13 THEN 1 ELSE 0 END),
			[Segment14] = MAX(CASE WHEN SegmentNo = 14 THEN 1 ELSE 0 END),
			[Segment15] = MAX(CASE WHEN SegmentNo = 15 THEN 1 ELSE 0 END),
			[Segment16] = MAX(CASE WHEN SegmentNo = 16 THEN 1 ELSE 0 END),
			[Segment17] = MAX(CASE WHEN SegmentNo = 17 THEN 1 ELSE 0 END),
			[Segment18] = MAX(CASE WHEN SegmentNo = 18 THEN 1 ELSE 0 END),
			[Segment19] = MAX(CASE WHEN SegmentNo = 19 THEN 1 ELSE 0 END),
			[Segment20] = MAX(CASE WHEN SegmentNo = 20 THEN 1 ELSE 0 END)
		INTO
			#SegmentNo
		FROM
			[pcINTEGRATOR].[dbo].[Journal_SegmentNo]
		WHERE
			[InstanceID] = @InstanceID AND
			[EntityID] = @EntityID AND
			[Book] = @Book AND
			[BalanceAdjYN] <> 0 AND
			[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#SegmentNo', * FROM #SegmentNo

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
					[PostedStatus] [bit],
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

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

		IF @InstanceID = 603 AND @VersionID = 1095 AND @Entity_MemberKey = 'Honematic' AND @Book = 'GL' AND @FiscalYear = 2022
			INSERT INTO #FiscalPeriod
				(
				[FiscalYear],
				[FiscalPeriod],
				[YearMonth]
				)
			SELECT [FiscalYear] = 2022, [FiscalPeriod] = 0, [YearMonth] = 202112
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 1, [YearMonth] = 202112
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 2, [YearMonth] = 202201
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 3, [YearMonth] = 202202
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 4, [YearMonth] = 202203
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 5, [YearMonth] = 202204
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 6, [YearMonth] = 202205
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 7, [YearMonth] = 202206
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 8, [YearMonth] = 202207
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 9, [YearMonth] = 202208
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 10, [YearMonth] = 202209
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 11, [YearMonth] = 202210
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 12, [YearMonth] = 202211
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 13, [YearMonth] = 202212
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 14, [YearMonth] = 202212
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 15, [YearMonth] = 202212
		ELSE
			EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @FiscalYear = @FiscalYear, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod

	SET @Step = 'Create and fill temp table #FiscalYearMonth'
		CREATE TABLE #FiscalYearMonth (Entity nvarchar(50) COLLATE DATABASE_DEFAULT, Book nvarchar(50) COLLATE DATABASE_DEFAULT, FiscalYear int, YearMonth int)

		IF @SequenceBM & 2 > 0
			INSERT INTO #FiscalYearMonth
				(
				Entity,
				Book,
				FiscalYear,
				YearMonth
				)
			SELECT
				J.Entity,
				J.Book,
				FiscalYear = @FiscalYear,
				YearMonth = MIN(FP.YearMonth)
			FROM
				#Journal J
				INNER JOIN #FiscalPeriod FP ON FP.FiscalYear = @FiscalYear AND FP.FiscalPeriod = 0
			WHERE
				J.InstanceID = @InstanceID AND
				J.FiscalYear BETWEEN @FiscalYear - 1 AND @FiscalYear AND
				J.[Scenario] = 'ACTUAL' AND
				J.[TransactionTypeBM] & 7 > 0 AND
				J.[PostedStatus] <> 0
			GROUP BY
				J.Entity,
				J.Book
		ELSE
			SET @SQLStatement = '
				INSERT INTO #FiscalYearMonth
					(
					Entity,
					Book,
					FiscalYear,
					YearMonth
					)
				SELECT
					J.Entity,
					J.Book,
					FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) + ',
					YearMonth = MIN(FP.YearMonth)
				FROM
					' + @JournalTable + ' J
					INNER JOIN #FiscalPeriod FP ON FP.FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND FP.FiscalPeriod = 0
				WHERE
					J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
					J.FiscalYear BETWEEN ' + CONVERT(nvarchar(15), @FiscalYear - 1) +  ' AND ' + CONVERT(nvarchar(15), @FiscalYear) +  ' AND
					J.[Scenario] = ''ACTUAL'' AND
					J.[TransactionTypeBM] & 7 > 0 AND
					J.[PostedStatus] <> 0
				GROUP BY
					J.Entity,
					J.Book'

			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalYearMonth', * FROM #FiscalYearMonth ORDER BY Entity, Book, FiscalYear

	SET @Step = 'Run FiscalYear_Cursor'
		IF CURSOR_STATUS('global','FiscalYear_Cursor') >= -1 DEALLOCATE FiscalYear_Cursor
		DECLARE FiscalYear_Cursor CURSOR FOR

		SELECT DISTINCT
			FiscalYear
		FROM
			#FiscalYearMonth
		ORDER BY
			FiscalYear

		OPEN FiscalYear_Cursor
		FETCH NEXT FROM FiscalYear_Cursor INTO @FiscalYear

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@FiscalYear] = @FiscalYear
				
	SET @Step = 'Insert opening balances (OB_JRN) into temp table #Journal'
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
						)'
-- Changed by KeHa and JaWo in New for testing
				SET @SQLStatement = @SQLStatement + '
					SELECT
						[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
						[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
						[Entity] = ''' + @Entity_MemberKey + ''',
						[Book] = ''' + @Book + ''',
						[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ',
						[FiscalPeriod] = 0,
						[JournalSequence] = ''OB_JRN'',
						[JournalNo] = ''0'',
						[JournalLine] = 0,
						[YearMonth] = MAX(FYM.[YearMonth]),
						[TransactionTypeBM] = 2,
						[BalanceYN] = 1,
						[Account] = CASE WHEN SN.[Account] = 1 THEN CASE WHEN J.Account = ''CYNI_B'' THEN ''' + @Account_RE + ''' ELSE J.[Account] END ELSE '''' END,
						[Segment01] = CASE WHEN SN.[Segment01] = 1 THEN J.[Segment01] ELSE '''' END,
						[Segment02] = CASE WHEN SN.[Segment02] = 1 THEN J.[Segment02] ELSE '''' END,
						[Segment03] = CASE WHEN SN.[Segment03] = 1 THEN J.[Segment03] ELSE '''' END,
						[Segment04] = CASE WHEN SN.[Segment04] = 1 THEN J.[Segment04] ELSE '''' END,
						[Segment05] = CASE WHEN SN.[Segment05] = 1 THEN J.[Segment05] ELSE '''' END,
						[Segment06] = CASE WHEN SN.[Segment06] = 1 THEN J.[Segment06] ELSE '''' END,
						[Segment07] = CASE WHEN SN.[Segment07] = 1 THEN J.[Segment07] ELSE '''' END,
						[Segment08] = CASE WHEN SN.[Segment08] = 1 THEN J.[Segment08] ELSE '''' END,
						[Segment09] = CASE WHEN SN.[Segment09] = 1 THEN J.[Segment09] ELSE '''' END,
						[Segment10] = CASE WHEN SN.[Segment10] = 1 THEN J.[Segment10] ELSE '''' END,
						[Segment11] = CASE WHEN SN.[Segment11] = 1 THEN J.[Segment11] ELSE '''' END,
						[Segment12] = CASE WHEN SN.[Segment12] = 1 THEN J.[Segment12] ELSE '''' END,
						[Segment13] = CASE WHEN SN.[Segment13] = 1 THEN J.[Segment13] ELSE '''' END,
						[Segment14] = CASE WHEN SN.[Segment14] = 1 THEN J.[Segment14] ELSE '''' END,
						[Segment15] = CASE WHEN SN.[Segment15] = 1 THEN J.[Segment15] ELSE '''' END,
						[Segment16] = CASE WHEN SN.[Segment16] = 1 THEN J.[Segment16] ELSE '''' END,
						[Segment17] = CASE WHEN SN.[Segment17] = 1 THEN J.[Segment17] ELSE '''' END,
						[Segment18] = CASE WHEN SN.[Segment18] = 1 THEN J.[Segment18] ELSE '''' END,
						[Segment19] = CASE WHEN SN.[Segment19] = 1 THEN J.[Segment19] ELSE '''' END,
						[Segment20] = CASE WHEN SN.[Segment20] = 1 THEN J.[Segment20] ELSE '''' END,
						[JournalDate] = LEFT(MAX(FYM.[YearMonth]), 4) + ''-'' + RIGHT(MAX(FYM.[YearMonth]), 2) + ''-01'',
						[TransactionDate] = LEFT(MAX(FYM.[YearMonth]), 4) + ''-'' + RIGHT(MAX(FYM.[YearMonth]), 2) + ''-01'',
						[PostedDate] = LEFT(MAX(FYM.[YearMonth]), 4) + ''-'' + RIGHT(MAX(FYM.[YearMonth]), 2) + ''-01'',
						[PostedStatus] = J.[PostedStatus],
						[PostedBy] = '''',
						[Source] = ''BR'',
						[Scenario] = ''ACTUAL'',
						[Description_Head] = ''Opening Balance'',
						[Description_Line] = ''Opening Balance'',
						[Currency_Book] = ''' + @Currency + ''',
						[ValueDebit_Book] = ROUND(CASE WHEN SUM([ValueDebit_Book] - [ValueCredit_Book]) > 0 THEN SUM([ValueDebit_Book] - [ValueCredit_Book]) ELSE 0 END, 4),
						[ValueCredit_Book] = ROUND(CASE WHEN SUM([ValueDebit_Book] - [ValueCredit_Book]) < 0 THEN -1 * SUM([ValueDebit_Book] - [ValueCredit_Book]) ELSE 0 END, 4)
					FROM'
-- CHanged by KeHa and JaWo in New for testing
				SET @SQLStatement = @SQLStatement + '
						' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
						INNER JOIN #FiscalYearMonth FYM ON FYM.Entity = J.Entity AND FYM.Book = J.Book AND FYM.FiscalYear = ' + CONVERT(nvarchar(10), @FiscalYear) + '
						LEFT JOIN #SegmentNo SN ON 1 = 1
					WHERE
						J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
						J.[Entity] = ''' + @Entity_MemberKey + ''' AND
						J.[Book] = ''' + @Book + ''' AND
						J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear - 1) + ' AND
						J.[TransactionTypeBM] & 3 > 0 AND
						J.[BalanceYN] <> 0 AND
						J.[Scenario] = ''ACTUAL'' AND
						J.[Currency_Book] = ''' + @Currency + '''
					GROUP BY
						CASE WHEN SN.[Account] = 1 THEN CASE WHEN J.Account = ''CYNI_B'' THEN ''' + @Account_RE + ''' ELSE J.[Account] END ELSE '''' END,
						CASE WHEN SN.[Segment01] = 1 THEN J.[Segment01] ELSE '''' END,
						CASE WHEN SN.[Segment02] = 1 THEN J.[Segment02] ELSE '''' END,
						CASE WHEN SN.[Segment03] = 1 THEN J.[Segment03] ELSE '''' END,
						CASE WHEN SN.[Segment04] = 1 THEN J.[Segment04] ELSE '''' END,
						CASE WHEN SN.[Segment05] = 1 THEN J.[Segment05] ELSE '''' END,
						CASE WHEN SN.[Segment06] = 1 THEN J.[Segment06] ELSE '''' END,
						CASE WHEN SN.[Segment07] = 1 THEN J.[Segment07] ELSE '''' END,
						CASE WHEN SN.[Segment08] = 1 THEN J.[Segment08] ELSE '''' END,
						CASE WHEN SN.[Segment09] = 1 THEN J.[Segment09] ELSE '''' END,
						CASE WHEN SN.[Segment10] = 1 THEN J.[Segment10] ELSE '''' END,
						CASE WHEN SN.[Segment11] = 1 THEN J.[Segment11] ELSE '''' END,
						CASE WHEN SN.[Segment12] = 1 THEN J.[Segment12] ELSE '''' END,
						CASE WHEN SN.[Segment13] = 1 THEN J.[Segment13] ELSE '''' END,
						CASE WHEN SN.[Segment14] = 1 THEN J.[Segment14] ELSE '''' END,
						CASE WHEN SN.[Segment15] = 1 THEN J.[Segment15] ELSE '''' END,
						CASE WHEN SN.[Segment16] = 1 THEN J.[Segment16] ELSE '''' END,
						CASE WHEN SN.[Segment17] = 1 THEN J.[Segment17] ELSE '''' END,
						CASE WHEN SN.[Segment18] = 1 THEN J.[Segment18] ELSE '''' END,
						CASE WHEN SN.[Segment19] = 1 THEN J.[Segment19] ELSE '''' END,
						CASE WHEN SN.[Segment20] = 1 THEN J.[Segment20] ELSE '''' END,
						J.[PostedStatus]
					HAVING
						ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 4) <> 0.0'

				IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Add OB_JRN rows to #Journal'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Add OB_JRN rows to #Journal', 
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement
				
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT

				IF @DebugBM & 32 > 0 Select * from #Journal Order By Account Desc
				
	SET @Step = 'Calculate PYNI_B'
		SET @SQLStatement = '
			SELECT
				@InternalVariable = -1.0 * ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 4)
			FROM
				#Journal J
			WHERE
				J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				J.[Entity] = ''' + @Entity_MemberKey + ''' AND
				J.[Book] = ''' + @Book + ''' AND
				J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
				J.[FiscalPeriod] = 0 AND
				J.[TransactionTypeBM] & 19 > 0 AND
				J.[BalanceYN] <> 0 AND
				J.[Scenario] = ''ACTUAL'' AND
				J.[Currency_Book] = ''' + @Currency + ''' AND
				J.[Account] NOT IN (''CYNI_B'', ''PYNI_B'') AND
				J.[PostedStatus] <> 0
			HAVING
				ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 4) <> 0.0'

		EXEC sp_executesql @SQLStatement, N'@InternalVariable float OUT', @InternalVariable = @PYNI_B OUT

		IF @DebugBM & 2 > 0 SELECT [@PYNI_B] = @PYNI_B

		IF @PYNI_B <> 0.0
			BEGIN
				SET @SQLStatement = '
					DELETE J
					FROM
						#Journal J
					WHERE
						J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
						J.[Entity] = ''' + @Entity_MemberKey + ''' AND
						J.[Book] = ''' + @Book + ''' AND
						J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
						J.[FiscalPeriod] = 0 AND
						J.[TransactionTypeBM] & 3 > 0 AND
						J.[BalanceYN] <> 0 AND
						J.[Scenario] = ''ACTUAL'' AND
						J.[Account] IN (''CYNI_B'', ''PYNI_B'') AND
						J.[Currency_Book] = ''' + @Currency + ''''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

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
						)'

				SET @SQLStatement = @SQLStatement + '
					SELECT
						[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
						[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
						[Entity] = FYM.[Entity],
						[Book] = FYM.[Book],
						[FiscalYear] = FYM.[FiscalYear],
						[FiscalPeriod] = 0,
						[JournalSequence] = ''OB_JRN'',
						[JournalNo] = ''0'',
						[JournalLine] = 0,
						[YearMonth] = FYM.[YearMonth],
						[TransactionTypeBM] = 2,
						[BalanceYN] = 1,
						[Account] = ''PYNI_B'',
						[Segment01] = '''',
						[Segment02] = '''',
						[Segment03] = '''',
						[Segment04] = '''',
						[Segment05] = '''',
						[Segment06] = '''',
						[Segment07] = '''',
						[Segment08] = '''',
						[Segment09] = '''',
						[Segment10] = '''',
						[Segment11] = '''',
						[Segment12] = '''',
						[Segment13] = '''',
						[Segment14] = '''',
						[Segment15] = '''',
						[Segment16] = '''',
						[Segment17] = '''',
						[Segment18] = '''',
						[Segment19] = '''',
						[Segment20] = '''',
						[JournalDate] = LEFT(FYM.[YearMonth], 4) + ''-'' + RIGHT(FYM.[YearMonth], 2) + ''-01'',
						[TransactionDate] = LEFT(FYM.[YearMonth], 4) + ''-'' + RIGHT(FYM.[YearMonth], 2) + ''-01'',
						[PostedDate] = LEFT(FYM.[YearMonth], 4) + ''-'' + RIGHT(FYM.[YearMonth], 2) + ''-01'',
						[PostedStatus] = 1,
						[PostedBy] = '''',
						[Source] = ''BR'',
						[Scenario] = ''ACTUAL'',
						[Description_Head] = ''Opening Balance'',
						[Description_Line] = ''Opening Balance'',
						[Currency_Book] = ''' + @Currency + ''',
						[ValueDebit_Book] = ' + STR(CASE WHEN @PYNI_B > 0.0 THEN @PYNI_B ELSE 0.0 END, 25, 4) + ',
						[ValueCredit_Book] = ' + STR(CASE WHEN @PYNI_B < 0.0 THEN -1.0 * @PYNI_B ELSE 0.0 END, 25, 4) + '
					FROM
						#FiscalYearMonth FYM 
					WHERE
						FYM.[Entity] = ''' + @Entity_MemberKey + ''' AND 
						FYM.[Book] = ''' + @Book + ''' AND 
						FYM.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Insert opening balances (OB_ADJ) into temp table #Journal'
		IF @DebugBM & 2 > 0
			SELECT
				[@JobID] = @JobID,
				[@ProcedureID] = @ProcedureID,
				[@InstanceID] = @InstanceID,
				[@Entity_MemberKey] = @Entity_MemberKey,
				[@Book] = @Book,
				[@FiscalYear] = @FiscalYear,
--				[@YearMonth] = @YearMonth,
				[@Currency] = @Currency,
				[@SequenceBM] = @SequenceBM,
				[@JournalTable] = @JournalTable
									
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
						[Book] = ''' + @Book + ''',
						[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ',
						[FiscalPeriod] = 0,
						[JournalSequence] = ''OB_ADJ'',
						[JournalNo] = ''0'',
						[JournalLine] = 0,
						[YearMonth] = MAX(Account.[YearMonth]),
						[TransactionTypeBM] = 2,
						[BalanceYN] = 1,
						[Account] = OB_TOT.[Account],
						[Segment01] = OB_TOT.[Segment01],
						[Segment02] = OB_TOT.[Segment02],
						[Segment03] = OB_TOT.[Segment03],
						[Segment04] = OB_TOT.[Segment04],
						[Segment05] = OB_TOT.[Segment05],
						[Segment06] = OB_TOT.[Segment06],
						[Segment07] = OB_TOT.[Segment07],
						[Segment08] = OB_TOT.[Segment08],
						[Segment09] = OB_TOT.[Segment09],
						[Segment10] = OB_TOT.[Segment10],
						[Segment11] = OB_TOT.[Segment11],
						[Segment12] = OB_TOT.[Segment12],
						[Segment13] = OB_TOT.[Segment13],
						[Segment14] = OB_TOT.[Segment14],
						[Segment15] = OB_TOT.[Segment15],
						[Segment16] = OB_TOT.[Segment16],
						[Segment17] = OB_TOT.[Segment17],
						[Segment18] = OB_TOT.[Segment18],
						[Segment19] = OB_TOT.[Segment19],
						[Segment20] = OB_TOT.[Segment20],
						[JournalDate] = LEFT(MAX(Account.[YearMonth]), 4) + ''-'' + RIGHT(MAX(Account.[YearMonth]), 2) + ''-01'',
						[TransactionDate] = LEFT(MAX(Account.[YearMonth]), 4) + ''-'' + RIGHT(MAX(Account.[YearMonth]), 2) + ''-01'',
						[PostedDate] = LEFT(MAX(Account.[YearMonth]), 4) + ''-'' + RIGHT(MAX(Account.[YearMonth]), 2) + ''-01'',
						[PostedStatus] = 1,
						[PostedBy] = '''',
						[Source] = ''BR'',
						[Scenario] = ''ACTUAL'',
						[Description_Head] = ''Opening Balance'',
						[Description_Line] = ''Opening Balance'',
						[Currency_Book] = ''' + @Currency + ''',
						[ValueDebit_Book] = ROUND(CASE WHEN ISNULL(SUM(OB_JRN.[Book]), 0.0) - ISNULL(SUM(OB_ERP.[Book]), 0.0) < 0 THEN -1 * (ISNULL(SUM(OB_JRN.[Book]), 0.0) - ISNULL(SUM(OB_ERP.[Book]), 0.0)) ELSE 0 END, 4),
						[ValueCredit_Book] = ROUND(CASE WHEN ISNULL(SUM(OB_JRN.[Book]), 0.0) - ISNULL(SUM(OB_ERP.[Book]), 0.0) > 0 THEN ISNULL(SUM(OB_JRN.[Book]), 0.0) - ISNULL(SUM(OB_ERP.[Book]), 0.0) ELSE 0 END, 4)
					FROM'
-- Added by KEHa and JaWo in New for testing
				SET @SQLStatement = @SQLStatement + '
						(
						SELECT DISTINCT
							[Account] = J.[Account],
							--[YearMonth] = FYM.[YearMonth]
							[YearMonth] = ISNULL(FYM.[YearMonth], J.[YearMonth])
						FROM
							' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
							--INNER JOIN #FiscalYearMonth FYM ON FYM.Entity = J.Entity AND FYM.Book = J.Book AND FYM.FiscalYear = J.FiscalYear
							LEFT JOIN #FiscalYearMonth FYM ON FYM.Entity = J.Entity AND FYM.Book = J.Book AND FYM.FiscalYear = J.FiscalYear
						WHERE
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							J.[Entity] = ''' + @Entity_MemberKey + ''' AND
							J.[Book] = ''' + @Book + ''' AND
							J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
							[FiscalPeriod] = 0 AND
							[JournalSequence] = ''OB_ERP'' AND
							[JournalNo] = ''0'' AND
							[JournalLine] = 0 AND
							[TransactionTypeBM] & 4 > 0 AND
							[Currency_Book] = ''' + @Currency + ''' AND
							[BalanceYN] = 1
						) Account'

				SET @SQLStatement = @SQLStatement + '
						INNER JOIN
						(
						SELECT DISTINCT
							[Account] = CASE WHEN SN.[Account] = 1 THEN J.[Account] ELSE '''' END,
							[Segment01] = CASE WHEN SN.[Segment01] = 1 THEN J.[Segment01] ELSE '''' END,
							[Segment02] = CASE WHEN SN.[Segment02] = 1 THEN J.[Segment02] ELSE '''' END,
							[Segment03] = CASE WHEN SN.[Segment03] = 1 THEN J.[Segment03] ELSE '''' END,
							[Segment04] = CASE WHEN SN.[Segment04] = 1 THEN J.[Segment04] ELSE '''' END,
							[Segment05] = CASE WHEN SN.[Segment05] = 1 THEN J.[Segment05] ELSE '''' END,
							[Segment06] = CASE WHEN SN.[Segment06] = 1 THEN J.[Segment06] ELSE '''' END,
							[Segment07] = CASE WHEN SN.[Segment07] = 1 THEN J.[Segment07] ELSE '''' END,
							[Segment08] = CASE WHEN SN.[Segment08] = 1 THEN J.[Segment08] ELSE '''' END,
							[Segment09] = CASE WHEN SN.[Segment09] = 1 THEN J.[Segment09] ELSE '''' END,
							[Segment10] = CASE WHEN SN.[Segment10] = 1 THEN J.[Segment10] ELSE '''' END,
							[Segment11] = CASE WHEN SN.[Segment11] = 1 THEN J.[Segment11] ELSE '''' END,
							[Segment12] = CASE WHEN SN.[Segment12] = 1 THEN J.[Segment12] ELSE '''' END,
							[Segment13] = CASE WHEN SN.[Segment13] = 1 THEN J.[Segment13] ELSE '''' END,
							[Segment14] = CASE WHEN SN.[Segment14] = 1 THEN J.[Segment14] ELSE '''' END,
							[Segment15] = CASE WHEN SN.[Segment15] = 1 THEN J.[Segment15] ELSE '''' END,
							[Segment16] = CASE WHEN SN.[Segment16] = 1 THEN J.[Segment16] ELSE '''' END,
							[Segment17] = CASE WHEN SN.[Segment17] = 1 THEN J.[Segment17] ELSE '''' END,
							[Segment18] = CASE WHEN SN.[Segment18] = 1 THEN J.[Segment18] ELSE '''' END,
							[Segment19] = CASE WHEN SN.[Segment19] = 1 THEN J.[Segment19] ELSE '''' END,
							[Segment20] = CASE WHEN SN.[Segment20] = 1 THEN J.[Segment20] ELSE '''' END
						FROM
							' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
							LEFT JOIN #SegmentNo SN ON 1 = 1
						WHERE
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							[Entity] = ''' + @Entity_MemberKey + ''' AND
							[Book] = ''' + @Book + ''' AND
							[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
							[FiscalPeriod] = 0 AND
							[JournalSequence] = ''OB_ERP'' AND
							[JournalNo] = ''0'' AND
							[JournalLine] = 0 AND
							[TransactionTypeBM] & 4 > 0 AND
							[Currency_Book] = ''' + @Currency + ''' AND
							[BalanceYN] = 1'

				SET @SQLStatement = @SQLStatement + '

						UNION SELECT DISTINCT
							[Account] = CASE WHEN SN.[Account] = 1 THEN J.[Account] ELSE '''' END,
							[Segment01] = CASE WHEN SN.[Segment01] = 1 THEN J.[Segment01] ELSE '''' END,
							[Segment02] = CASE WHEN SN.[Segment02] = 1 THEN J.[Segment02] ELSE '''' END,
							[Segment03] = CASE WHEN SN.[Segment03] = 1 THEN J.[Segment03] ELSE '''' END,
							[Segment04] = CASE WHEN SN.[Segment04] = 1 THEN J.[Segment04] ELSE '''' END,
							[Segment05] = CASE WHEN SN.[Segment05] = 1 THEN J.[Segment05] ELSE '''' END,
							[Segment06] = CASE WHEN SN.[Segment06] = 1 THEN J.[Segment06] ELSE '''' END,
							[Segment07] = CASE WHEN SN.[Segment07] = 1 THEN J.[Segment07] ELSE '''' END,
							[Segment08] = CASE WHEN SN.[Segment08] = 1 THEN J.[Segment08] ELSE '''' END,
							[Segment09] = CASE WHEN SN.[Segment09] = 1 THEN J.[Segment09] ELSE '''' END,
							[Segment10] = CASE WHEN SN.[Segment10] = 1 THEN J.[Segment10] ELSE '''' END,
							[Segment11] = CASE WHEN SN.[Segment11] = 1 THEN J.[Segment11] ELSE '''' END,
							[Segment12] = CASE WHEN SN.[Segment12] = 1 THEN J.[Segment12] ELSE '''' END,
							[Segment13] = CASE WHEN SN.[Segment13] = 1 THEN J.[Segment13] ELSE '''' END,
							[Segment14] = CASE WHEN SN.[Segment14] = 1 THEN J.[Segment14] ELSE '''' END,
							[Segment15] = CASE WHEN SN.[Segment15] = 1 THEN J.[Segment15] ELSE '''' END,
							[Segment16] = CASE WHEN SN.[Segment16] = 1 THEN J.[Segment16] ELSE '''' END,
							[Segment17] = CASE WHEN SN.[Segment17] = 1 THEN J.[Segment17] ELSE '''' END,
							[Segment18] = CASE WHEN SN.[Segment18] = 1 THEN J.[Segment18] ELSE '''' END,
							[Segment19] = CASE WHEN SN.[Segment19] = 1 THEN J.[Segment19] ELSE '''' END,
							[Segment20] = CASE WHEN SN.[Segment20] = 1 THEN J.[Segment20] ELSE '''' END
						FROM
							#Journal J
							LEFT JOIN #SegmentNo SN ON 1 = 1
						WHERE
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							[Entity] = ''' + @Entity_MemberKey + ''' AND
							[Book] = ''' + @Book + ''' AND
							[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
							[FiscalPeriod] = 0 AND
							[JournalSequence] = ''OB_JRN'' AND
							[JournalNo] = ''0'' AND
							[JournalLine] = 0 AND
							[TransactionTypeBM] & 2 > 0 AND
							[Currency_Book] = ''' + @Currency + ''' AND
							[BalanceYN] = 1 AND
							J.[PostedStatus] <> 0
						) OB_TOT ON OB_TOT.[Account] = Account.[Account]'

					SET @SQLStatement = @SQLStatement + '
						LEFT JOIN
						(
						SELECT
							[Account] = CASE WHEN SN.[Account] = 1 THEN J.[Account] ELSE '''' END,
							[Segment01] = CASE WHEN SN.[Segment01] = 1 THEN J.[Segment01] ELSE '''' END,
							[Segment02] = CASE WHEN SN.[Segment02] = 1 THEN J.[Segment02] ELSE '''' END,
							[Segment03] = CASE WHEN SN.[Segment03] = 1 THEN J.[Segment03] ELSE '''' END,
							[Segment04] = CASE WHEN SN.[Segment04] = 1 THEN J.[Segment04] ELSE '''' END,
							[Segment05] = CASE WHEN SN.[Segment05] = 1 THEN J.[Segment05] ELSE '''' END,
							[Segment06] = CASE WHEN SN.[Segment06] = 1 THEN J.[Segment06] ELSE '''' END,
							[Segment07] = CASE WHEN SN.[Segment07] = 1 THEN J.[Segment07] ELSE '''' END,
							[Segment08] = CASE WHEN SN.[Segment08] = 1 THEN J.[Segment08] ELSE '''' END,
							[Segment09] = CASE WHEN SN.[Segment09] = 1 THEN J.[Segment09] ELSE '''' END,
							[Segment10] = CASE WHEN SN.[Segment10] = 1 THEN J.[Segment10] ELSE '''' END,
							[Segment11] = CASE WHEN SN.[Segment11] = 1 THEN J.[Segment11] ELSE '''' END,
							[Segment12] = CASE WHEN SN.[Segment12] = 1 THEN J.[Segment12] ELSE '''' END,
							[Segment13] = CASE WHEN SN.[Segment13] = 1 THEN J.[Segment13] ELSE '''' END,
							[Segment14] = CASE WHEN SN.[Segment14] = 1 THEN J.[Segment14] ELSE '''' END,
							[Segment15] = CASE WHEN SN.[Segment15] = 1 THEN J.[Segment15] ELSE '''' END,
							[Segment16] = CASE WHEN SN.[Segment16] = 1 THEN J.[Segment16] ELSE '''' END,
							[Segment17] = CASE WHEN SN.[Segment17] = 1 THEN J.[Segment17] ELSE '''' END,
							[Segment18] = CASE WHEN SN.[Segment18] = 1 THEN J.[Segment18] ELSE '''' END,
							[Segment19] = CASE WHEN SN.[Segment19] = 1 THEN J.[Segment19] ELSE '''' END,
							[Segment20] = CASE WHEN SN.[Segment20] = 1 THEN J.[Segment20] ELSE '''' END,
							[Book] = SUM([ValueDebit_Book] - [ValueCredit_Book])
						FROM
							' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
							LEFT JOIN #SegmentNo SN ON 1 = 1
						WHERE
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							[Entity] = ''' + @Entity_MemberKey + ''' AND
							[Book] = ''' + @Book + ''' AND
							[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
							[FiscalPeriod] = 0 AND
							[JournalSequence] = ''OB_ERP'' AND
							[JournalNo] = ''0'' AND
							[JournalLine] = 0 AND
							[TransactionTypeBM] & 4 > 0 AND
							[Currency_Book] = ''' + @Currency + ''' AND
							[BalanceYN] = 1
						GROUP BY
							CASE WHEN SN.[Account] = 1 THEN J.[Account] ELSE '''' END,
							CASE WHEN SN.[Segment01] = 1 THEN J.[Segment01] ELSE '''' END,
							CASE WHEN SN.[Segment02] = 1 THEN J.[Segment02] ELSE '''' END,
							CASE WHEN SN.[Segment03] = 1 THEN J.[Segment03] ELSE '''' END,
							CASE WHEN SN.[Segment04] = 1 THEN J.[Segment04] ELSE '''' END,
							CASE WHEN SN.[Segment05] = 1 THEN J.[Segment05] ELSE '''' END,
							CASE WHEN SN.[Segment06] = 1 THEN J.[Segment06] ELSE '''' END,
							CASE WHEN SN.[Segment07] = 1 THEN J.[Segment07] ELSE '''' END,
							CASE WHEN SN.[Segment08] = 1 THEN J.[Segment08] ELSE '''' END,
							CASE WHEN SN.[Segment09] = 1 THEN J.[Segment09] ELSE '''' END,
							CASE WHEN SN.[Segment10] = 1 THEN J.[Segment10] ELSE '''' END,
							CASE WHEN SN.[Segment11] = 1 THEN J.[Segment11] ELSE '''' END,
							CASE WHEN SN.[Segment12] = 1 THEN J.[Segment12] ELSE '''' END,
							CASE WHEN SN.[Segment13] = 1 THEN J.[Segment13] ELSE '''' END,
							CASE WHEN SN.[Segment14] = 1 THEN J.[Segment14] ELSE '''' END,
							CASE WHEN SN.[Segment15] = 1 THEN J.[Segment15] ELSE '''' END,
							CASE WHEN SN.[Segment16] = 1 THEN J.[Segment16] ELSE '''' END,
							CASE WHEN SN.[Segment17] = 1 THEN J.[Segment17] ELSE '''' END,
							CASE WHEN SN.[Segment18] = 1 THEN J.[Segment18] ELSE '''' END,
							CASE WHEN SN.[Segment19] = 1 THEN J.[Segment19] ELSE '''' END,
							CASE WHEN SN.[Segment20] = 1 THEN J.[Segment20] ELSE '''' END
						) OB_ERP ON	OB_ERP.[Account] = OB_TOT.[Account] AND
									OB_ERP.[Segment01] = OB_TOT.[Segment01] AND
									OB_ERP.[Segment02] = OB_TOT.[Segment02] AND
									OB_ERP.[Segment03] = OB_TOT.[Segment03] AND
									OB_ERP.[Segment04] = OB_TOT.[Segment04] AND
									OB_ERP.[Segment05] = OB_TOT.[Segment05] AND
									OB_ERP.[Segment06] = OB_TOT.[Segment06] AND
									OB_ERP.[Segment07] = OB_TOT.[Segment07] AND
									OB_ERP.[Segment08] = OB_TOT.[Segment08] AND
									OB_ERP.[Segment09] = OB_TOT.[Segment09] AND
									OB_ERP.[Segment10] = OB_TOT.[Segment10] AND
									OB_ERP.[Segment11] = OB_TOT.[Segment11] AND
									OB_ERP.[Segment12] = OB_TOT.[Segment12] AND
									OB_ERP.[Segment13] = OB_TOT.[Segment13] AND
									OB_ERP.[Segment14] = OB_TOT.[Segment14] AND
									OB_ERP.[Segment15] = OB_TOT.[Segment15] AND
									OB_ERP.[Segment16] = OB_TOT.[Segment16] AND
									OB_ERP.[Segment17] = OB_TOT.[Segment17] AND
									OB_ERP.[Segment18] = OB_TOT.[Segment18] AND
									OB_ERP.[Segment19] = OB_TOT.[Segment19] AND
									OB_ERP.[Segment20] = OB_TOT.[Segment20]'

					SET @SQLStatement = @SQLStatement + '
						LEFT JOIN
						(
						SELECT
							[Account] = CASE WHEN SN.[Account] = 1 THEN J.[Account] ELSE '''' END,
							[Segment01] = CASE WHEN SN.[Segment01] = 1 THEN J.[Segment01] ELSE '''' END,
							[Segment02] = CASE WHEN SN.[Segment02] = 1 THEN J.[Segment02] ELSE '''' END,
							[Segment03] = CASE WHEN SN.[Segment03] = 1 THEN J.[Segment03] ELSE '''' END,
							[Segment04] = CASE WHEN SN.[Segment04] = 1 THEN J.[Segment04] ELSE '''' END,
							[Segment05] = CASE WHEN SN.[Segment05] = 1 THEN J.[Segment05] ELSE '''' END,
							[Segment06] = CASE WHEN SN.[Segment06] = 1 THEN J.[Segment06] ELSE '''' END,
							[Segment07] = CASE WHEN SN.[Segment07] = 1 THEN J.[Segment07] ELSE '''' END,
							[Segment08] = CASE WHEN SN.[Segment08] = 1 THEN J.[Segment08] ELSE '''' END,
							[Segment09] = CASE WHEN SN.[Segment09] = 1 THEN J.[Segment09] ELSE '''' END,
							[Segment10] = CASE WHEN SN.[Segment10] = 1 THEN J.[Segment10] ELSE '''' END,
							[Segment11] = CASE WHEN SN.[Segment11] = 1 THEN J.[Segment11] ELSE '''' END,
							[Segment12] = CASE WHEN SN.[Segment12] = 1 THEN J.[Segment12] ELSE '''' END,
							[Segment13] = CASE WHEN SN.[Segment13] = 1 THEN J.[Segment13] ELSE '''' END,
							[Segment14] = CASE WHEN SN.[Segment14] = 1 THEN J.[Segment14] ELSE '''' END,
							[Segment15] = CASE WHEN SN.[Segment15] = 1 THEN J.[Segment15] ELSE '''' END,
							[Segment16] = CASE WHEN SN.[Segment16] = 1 THEN J.[Segment16] ELSE '''' END,
							[Segment17] = CASE WHEN SN.[Segment17] = 1 THEN J.[Segment17] ELSE '''' END,
							[Segment18] = CASE WHEN SN.[Segment18] = 1 THEN J.[Segment18] ELSE '''' END,
							[Segment19] = CASE WHEN SN.[Segment19] = 1 THEN J.[Segment19] ELSE '''' END,
							[Segment20] = CASE WHEN SN.[Segment20] = 1 THEN J.[Segment20] ELSE '''' END,
							[Book] = SUM([ValueDebit_Book] - [ValueCredit_Book])
						FROM
							#Journal J
							LEFT JOIN #SegmentNo SN ON 1 = 1
						WHERE
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							[Entity] = ''' + @Entity_MemberKey + ''' AND
							[Book] = ''' + @Book + ''' AND
							[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
							[FiscalPeriod] = 0 AND
							[JournalSequence] = ''OB_JRN'' AND
							[JournalNo] = ''0'' AND
							[JournalLine] = 0 AND
							[TransactionTypeBM] & 2 > 0 AND
							[Currency_Book] = ''' + @Currency + ''' AND
							[BalanceYN] = 1 AND
							J.[PostedStatus] <> 0
						GROUP BY
							CASE WHEN SN.[Account] = 1 THEN J.[Account] ELSE '''' END,
							CASE WHEN SN.[Segment01] = 1 THEN J.[Segment01] ELSE '''' END,
							CASE WHEN SN.[Segment02] = 1 THEN J.[Segment02] ELSE '''' END,
							CASE WHEN SN.[Segment03] = 1 THEN J.[Segment03] ELSE '''' END,
							CASE WHEN SN.[Segment04] = 1 THEN J.[Segment04] ELSE '''' END,
							CASE WHEN SN.[Segment05] = 1 THEN J.[Segment05] ELSE '''' END,
							CASE WHEN SN.[Segment06] = 1 THEN J.[Segment06] ELSE '''' END,
							CASE WHEN SN.[Segment07] = 1 THEN J.[Segment07] ELSE '''' END,
							CASE WHEN SN.[Segment08] = 1 THEN J.[Segment08] ELSE '''' END,
							CASE WHEN SN.[Segment09] = 1 THEN J.[Segment09] ELSE '''' END,
							CASE WHEN SN.[Segment10] = 1 THEN J.[Segment10] ELSE '''' END,
							CASE WHEN SN.[Segment11] = 1 THEN J.[Segment11] ELSE '''' END,
							CASE WHEN SN.[Segment12] = 1 THEN J.[Segment12] ELSE '''' END,
							CASE WHEN SN.[Segment13] = 1 THEN J.[Segment13] ELSE '''' END,
							CASE WHEN SN.[Segment14] = 1 THEN J.[Segment14] ELSE '''' END,
							CASE WHEN SN.[Segment15] = 1 THEN J.[Segment15] ELSE '''' END,
							CASE WHEN SN.[Segment16] = 1 THEN J.[Segment16] ELSE '''' END,
							CASE WHEN SN.[Segment17] = 1 THEN J.[Segment17] ELSE '''' END,
							CASE WHEN SN.[Segment18] = 1 THEN J.[Segment18] ELSE '''' END,
							CASE WHEN SN.[Segment19] = 1 THEN J.[Segment19] ELSE '''' END,
							CASE WHEN SN.[Segment20] = 1 THEN J.[Segment20] ELSE '''' END
						) OB_JRN ON	OB_JRN.[Account] = OB_TOT.[Account] AND
									OB_JRN.[Segment01] = OB_TOT.[Segment01] AND
									OB_JRN.[Segment02] = OB_TOT.[Segment02] AND
									OB_JRN.[Segment03] = OB_TOT.[Segment03] AND
									OB_JRN.[Segment04] = OB_TOT.[Segment04] AND
									OB_JRN.[Segment05] = OB_TOT.[Segment05] AND
									OB_JRN.[Segment06] = OB_TOT.[Segment06] AND
									OB_JRN.[Segment07] = OB_TOT.[Segment07] AND
									OB_JRN.[Segment08] = OB_TOT.[Segment08] AND
									OB_JRN.[Segment09] = OB_TOT.[Segment09] AND
									OB_JRN.[Segment10] = OB_TOT.[Segment10] AND
									OB_JRN.[Segment11] = OB_TOT.[Segment11] AND
									OB_JRN.[Segment12] = OB_TOT.[Segment12] AND
									OB_JRN.[Segment13] = OB_TOT.[Segment13] AND
									OB_JRN.[Segment14] = OB_TOT.[Segment14] AND
									OB_JRN.[Segment15] = OB_TOT.[Segment15] AND
									OB_JRN.[Segment16] = OB_TOT.[Segment16] AND
									OB_JRN.[Segment17] = OB_TOT.[Segment17] AND
									OB_JRN.[Segment18] = OB_TOT.[Segment18] AND
									OB_JRN.[Segment19] = OB_TOT.[Segment19] AND
									OB_JRN.[Segment20] = OB_TOT.[Segment20]'

				SET @SQLStatement = @SQLStatement + '
					GROUP BY
						OB_TOT.[Account],
						OB_TOT.[Segment01],
						OB_TOT.[Segment02],
						OB_TOT.[Segment03],
						OB_TOT.[Segment04],
						OB_TOT.[Segment05],
						OB_TOT.[Segment06],
						OB_TOT.[Segment07],
						OB_TOT.[Segment08],
						OB_TOT.[Segment09],
						OB_TOT.[Segment10],
						OB_TOT.[Segment11],
						OB_TOT.[Segment12],
						OB_TOT.[Segment13],
						OB_TOT.[Segment14],
						OB_TOT.[Segment15],
						OB_TOT.[Segment16],
						OB_TOT.[Segment17],
						OB_TOT.[Segment18],
						OB_TOT.[Segment19],
						OB_TOT.[Segment20]
					HAVING
						ROUND(ISNULL(SUM(OB_JRN.[Book]), 0.0) - ISNULL(SUM(OB_ERP.[Book]), 0.0), 4) <> 0.0'

				IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Add OB_ADJ rows to #Journal'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Add OB_ADJ rows to #Journal', 
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement

				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT

				FETCH NEXT FROM FiscalYear_Cursor INTO @FiscalYear
			END

		CLOSE FiscalYear_Cursor
		DEALLOCATE FiscalYear_Cursor	

	SET @Step = 'Save To Journal'
		IF @SaveToJournalYN <> 0
			BEGIN
				--Delete already existing rows from [Journal]
				SET @SQLStatement = '
					DELETE J
					FROM
						' + @JournalTable + ' J
						INNER JOIN 
							(
							SELECT DISTINCT
								[InstanceID],
								[Entity],
								[Book],
								[JournalSequence],
								[FiscalYear],
								[FiscalPeriod]
							FROM
								#Journal
							) DJ ON 
								DJ.[InstanceID] = J.[InstanceID] AND 
								DJ.[Entity] = J.[Entity] AND 
								DJ.[Book] = J.[Book] AND
								(DJ.[JournalSequence] = J.[JournalSequence] OR J.[JournalSequence] = ''OB_ADJ'') AND 
								DJ.[FiscalYear] = J.[FiscalYear] AND 
								DJ.[FiscalPeriod] = J.[FiscalPeriod]
					WHERE
						J.[TransactionTypeBM] & 3 > 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Deleted = @Deleted + @@ROWCOUNT


				--Delete already existing rows from [Journal] where JournalSequence = 'OB_JRN'
				SET @SQLStatement = '
					DELETE J
					FROM
						' + @JournalTable + ' J
					WHERE
						J.[TransactionTypeBM] & 3 > 0 AND
						J.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND 
						J.[Entity] = ''' + @Entity_MemberKey + ''' AND 
						J.[Book] = ''' + @Book + ''' AND
						J.[JournalSequence] = ''OB_JRN'' AND 
						J.[FiscalYear] = ' +  CONVERT(NVARCHAR(15), @FiscalYear) + ' AND 
						J.[FiscalPeriod] = 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Deleted = @Deleted + @@ROWCOUNT

				--Fill Journal table'
				SET @SQLStatement = '
					INSERT INTO ' + @JournalTable + '
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
						[Customer],
						[Supplier],
						[Description_Head],
						[Description_Line],
						[Currency_Book],
						[ValueDebit_Book],
						[ValueCredit_Book],
						[Currency_Group],
						[ValueDebit_Group],
						[ValueCredit_Group],
						[Currency_Transaction],
						[ValueDebit_Transaction],
						[ValueCredit_Transaction],
						[SourceModule],
						[SourceModuleReference],
						[SourceCounter],
						[SourceGUID],
						[Inserted],
						[InsertedBy]
						)
					SELECT
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
						[TransactionTypeBM] = ISNULL([TransactionTypeBM], 2),
						[BalanceYN] = ISNULL([BalanceYN], 1),
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
						[Customer],
						[Supplier],
						[Description_Head],
						[Description_Line],
						[Currency_Book],
						[ValueDebit_Book],
						[ValueCredit_Book],
						[Currency_Group],
						[ValueDebit_Group],
						[ValueCredit_Group],
						[Currency_Transaction],
						[ValueDebit_Transaction],
						[ValueCredit_Transaction],
						[SourceModule],
						[SourceModuleReference],
						[SourceCounter],
						[SourceGUID],
						[Inserted] = GetDate(),
						[InsertedBy] = suser_name()
					FROM
						#Journal'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Return rows'
		IF @CalledYN = 0 AND @SaveToJournalYN = 0
			BEGIN
				SELECT * FROM #Journal ORDER BY [InstanceID], [Entity], [Book], [FiscalYear], [FiscalPeriod], [JournalSequence], [JournalNo], [JournalLine], [Account]
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #SegmentNo
		DROP TABLE #FiscalYearMonth
		IF @CalledYN = 0 DROP TABLE #Journal

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
